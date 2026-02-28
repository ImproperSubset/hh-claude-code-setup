---
name: dynamodb-patterns
description: DynamoDB patterns, anti-patterns, and design philosophy. Use when writing or reviewing code that uses DynamoDB — transactions, conditional writes, TTL, BatchWrite, eventual convergence, and best-effort patterns.
user-invocable: true
---

# DynamoDB Patterns and Best Practices

## Design Philosophy

DynamoDB is not a relational database. Two principles govern correct usage:

1. **Design for access patterns, not data structure.** Every key, index, and item shape exists to serve a specific query. If you can't name the access pattern, you don't need the item.
2. **Embrace eventual convergence.** Not every operation needs ACID atomicity. DynamoDB provides TTL, conditional writes, and idempotent operations as building blocks for systems that converge to correct state over time — even when individual writes fail.

---

## Transactions (`TransactWriteItems`)

### When to Use

Use transactions when **any** of these apply:
- Two or more items must succeed or fail together
- A write depends on the current state of another item
- Failure mid-sequence would leave orphaned or inconsistent data

Use a **single conditional write** when:
- Only one item is being modified
- The condition is on the same item being written

### When NOT to Use

Do NOT demand transactions when:
- The write fan-out exceeds 100 items (transaction hard limit)
- Idempotency is enforced at a different layer (e.g., a creation-lock item)
- Partial write failure is recoverable by retry or self-healing
- Best-effort writes with TTL as safety net are acceptable

### Structure

A single `TransactWriteItems` call can mix operations:

```typescript
await ddb.send(new TransactWriteCommand({
  ClientRequestToken: idempotencyKey, // prevents duplicate execution
  TransactItems: [
    {
      Put: {
        TableName: 'Posts',
        Item: newPost,
        ConditionExpression: 'attribute_not_exists(PK)',
      },
    },
    {
      Update: {
        TableName: 'Users',
        Key: { PK: userId },
        UpdateExpression: 'SET postCount = postCount + :one',
        ConditionExpression: 'attribute_exists(PK)',
        ExpressionAttributeValues: { ':one': 1 },
      },
    },
    {
      ConditionCheck: {
        TableName: 'Servers',
        Key: { PK: serverId },
        ConditionExpression: '#status = :active',
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: { ':active': 'active' },
      },
    },
  ],
}));
```

Key points:
- `ConditionCheck` asserts read-state without modifying the item
- `ClientRequestToken` makes the transaction idempotent (valid for 10 minutes)
- All items must be in the same AWS region

### Handling `TransactionCanceledException`

When any condition fails, the entire transaction is rolled back. Inspect `CancellationReasons` to determine which item failed:

```typescript
catch (error: unknown) {
  if (error instanceof Error && error.name === 'TransactionCanceledException') {
    const reasons = (error as any).CancellationReasons;
    // Array matches TransactItems order — index 0 = first item, etc.
    reasons?.forEach((reason: any, i: number) => {
      if (reason.Code === 'ConditionalCheckFailed') {
        console.error(`Item ${i} condition failed`, reason.Item);
      }
    });
  }
  throw error;
}
```

Use `ReturnValuesOnConditionCheckFailure: ALL_OLD` on individual operations to get the actual item state in the cancellation reason, enabling smart conflict resolution.

### Idempotency via `ClientRequestToken`

- Must be unique per logical operation (e.g., derive from request ID or content hash)
- DynamoDB deduplicates for 10 minutes — same token = same result, no re-execution
- Always use when the caller might retry (API Gateway, Step Functions, SQS)

### Limits

- **100 items** maximum per transaction
- **25 items per table** maximum
- All items must be **distinct** — no two operations on the same item
- **4 MB** total request size

---

## BatchWrite (`BatchWriteCommand`)

### When BatchWrite Is the Right Choice

Use `BatchWriteCommand` instead of `TransactWriteItems` when:
- The item count may exceed the 100-item transaction limit
- You need throughput, not atomicity — BatchWrite is cheaper and faster
- Idempotency is enforced at a different layer (e.g., a conditional-put lock item written before the batch)
- Partial failure is recoverable by retrying `UnprocessedItems`

### Key Differences from Transactions

| | TransactWriteItems | BatchWriteCommand |
|---|---|---|
| Atomicity | All-or-nothing | Best-effort, partial success possible |
| ConditionExpression | Supported per item | **NOT supported** (DynamoDB limitation) |
| Max items | 100 | 25 per call (but chainable) |
| Cost | 2x WCU per item | 1x WCU per item |
| UnprocessedItems | N/A (atomic) | Must handle and retry |

### Correct BatchWrite Pattern

```typescript
// Chunk into groups of 25 (BatchWrite limit per call)
for (let i = 0; i < items.length; i += 25) {
  const batch = items.slice(i, i + 25);
  const result = await ddb.send(new BatchWriteCommand({
    RequestItems: { [tableName]: batch },
  }));
  // MUST handle unprocessed items — DynamoDB may throttle
  if (result.UnprocessedItems?.[tableName]?.length) {
    // Retry with exponential backoff
  }
}
```

### Anti-Pattern: Treating BatchWrite Like a Transaction

```typescript
// BAD — no ConditionExpression support, no atomicity guarantee
// If you need atomicity, use TransactWriteItems instead
await ddb.send(new BatchWriteCommand({ ... }));
// Assuming all items were written — some may be in UnprocessedItems!
```

---

## TTL and Eventual Deletion

### How DynamoDB TTL Works

- DynamoDB's TTL process runs as a background sweep — **deletion can lag up to 48 hours** after the TTL timestamp passes
- Items with expired TTL are still physically present and returned by queries until DynamoDB sweeps them
- TTL deletions do not consume write capacity units
- TTL deletes are replicated to GSIs and streams

### Application-Level TTL Checks Are Required

Because TTL deletion lags, **application code must filter expired items**:

```typescript
// CORRECT — check TTL in application code
const item = result.Item;
if (item.ttl && item.ttl <= Math.floor(Date.now() / 1000)) {
  return notFound('Item expired');
}

// WRONG — assuming DynamoDB has already deleted expired items
const item = result.Item; // May still exist hours after TTL!
return item;
```

### TTL=0 as Logical Delete

Setting `ttl = 0` (epoch zero = 1970-01-01) is a valid pattern for immediate logical expiry. The item is logically dead but physically present until DynamoDB sweeps it. This is cheaper and simpler than `DeleteCommand` when:
- You want DynamoDB to handle physical cleanup asynchronously
- Multiple items need "deletion" in a transaction (set TTL on all of them atomically, let DynamoDB sweep later)
- You want TTL deletion to appear in DynamoDB Streams for downstream processing

### Anti-Pattern: Flagging TTL-Based Deletion as a Bug

```typescript
// This is CORRECT — not a bug
// Setting ttl=0 instead of deleting the item
await ddb.send(new TransactWriteCommand({
  TransactItems: items.map(key => ({
    Update: {
      Key: key,
      UpdateExpression: 'SET #ttl = :zero',
      ExpressionAttributeNames: { '#ttl': 'ttl' },
      ExpressionAttributeValues: { ':zero': 0 },
    },
  })),
}));
// DynamoDB will physically delete these items eventually (up to 48h)
```

Do NOT flag this as "items not being deleted" — this is the intended design.

---

## Eventual Convergence Patterns

These patterns are **intentional architecture**, not bugs. They appear when immediate consistency is too expensive or impossible, and the system is designed to converge to correct state over time.

### Best-Effort + TTL Safety Net

Write an auxiliary item best-effort. If the write fails, TTL on the item (or lack of the item) ensures the system converges:

```typescript
// Main transaction — must succeed
await ddb.send(new TransactWriteCommand({ TransactItems: [...] }));

// Auxiliary write — best-effort, TTL is the safety net
try {
  await ddb.send(new PutCommand({ Item: indexRow }));
} catch (e) {
  // Log but don't fail — DynamoDB TTL will clean up if needed
  console.warn('Best-effort index write failed:', e);
}
```

This is correct when:
- The auxiliary item is a convenience (index, cache) not a source of truth
- TTL ensures stale or missing auxiliary items self-correct
- The system does not depend on the auxiliary item being immediately present

### Fire-and-Forget TTL Refresh

When items have long TTL runways (e.g., 90 days), a single missed refresh is invisible:

```typescript
// Fire-and-forget — do NOT await
void refreshTTL(itemKey, newTTL).catch(() => {});
// Lambda may terminate before this completes — that's OK
// The 90-day runway means one missed refresh is invisible
```

This is correct when:
- The TTL runway is orders of magnitude longer than the refresh interval
- Losing one refresh out of many is statistically insignificant
- The caller should not block on a non-critical write

### Self-Healing via Periodic Operations

Design operations that prune stale state as a side effect of normal work:

```typescript
// On each user activity, also clean up stale references
for (const postId of livingPostIds) {
  const exists = await checkPostExists(postId);
  if (!exists) {
    staleIds.push(postId);
  }
}
if (staleIds.length > 0) {
  await removeStaleIds(userId, staleIds);
}
```

This is correct when:
- The periodic operation runs frequently enough relative to the staleness window
- Stale references cause no harm between cleanups (e.g., a failed lookup is retried or skipped)
- The cleanup is idempotent

### Anti-Pattern: Demanding Immediate Consistency Everywhere

```typescript
// BAD — over-engineering: transactional delete of a cache/index row
// when TTL would clean it up automatically
await ddb.send(new TransactWriteCommand({
  TransactItems: [
    { Delete: { Key: mainItem } },
    { Delete: { Key: cacheItem } },  // TTL handles this — no transaction needed
  ],
}));
```

Not every related write needs to be in the same transaction. Ask: **what happens if this auxiliary write fails?** If the answer is "TTL cleans it up" or "the next read handles it," best-effort is the correct choice.

---

## Conditional Writes

### Always Use ConditionExpression When Assuming State

```typescript
// BAD — overwrites if item already exists
await ddb.send(new PutCommand({ TableName: 'Posts', Item: post }));

// GOOD — fails fast if item exists
await ddb.send(new PutCommand({
  TableName: 'Posts',
  Item: post,
  ConditionExpression: 'attribute_not_exists(PK)',
}));
```

### Exception: BatchWrite Cannot Use ConditionExpression

`BatchWriteCommand` does not support `ConditionExpression` — this is a DynamoDB limitation, not a code defect. When using BatchWrite, enforce idempotency at a different layer (e.g., a conditional-put lock item written before the batch begins).

---

## Common Anti-Patterns

### Sequential writes with manual rollback

```typescript
// BAD — partial state if step 2 fails
await ddb.send(new PutCommand({ TableName: 'Posts', Item: post }));
try {
  await ddb.send(new UpdateCommand({ TableName: 'Users', ... }));
} catch {
  // "rollback" — but what if THIS fails too?
  await ddb.send(new DeleteCommand({ TableName: 'Posts', Key: postKey }));
}
```

Fix: Use `TransactWriteItems` with both operations.

### Unguarded deletes in catch blocks

```typescript
// BAD — deletes without checking if the item was actually created in this request
catch (error) {
  await ddb.send(new DeleteCommand({ TableName: 'Posts', Key: postKey }));
}
```

Fix: Rollback logic belongs inside the transaction, not in separate error handlers.

### Not inspecting `CancellationReasons`

```typescript
// BAD — loses information about which condition failed
catch (error) {
  if (error.name === 'TransactionCanceledException') {
    throw new Error('Transaction failed');
  }
}
```

Fix: Always inspect `CancellationReasons` to provide meaningful error messages and enable smart retry logic.

---

## Review Checklist

When reviewing DynamoDB code, flag as **CRITICAL/HIGH**:
- Multiple independent write calls that should be a single `TransactWriteItems`
- Rollback logic in catch blocks using separate write calls
- Write operations missing `ConditionExpression` when they assume item state (exception: `BatchWriteCommand` which doesn't support it)
- `TransactWriteItems` callers that don't inspect `CancellationReasons` on failure
- Sequential create-then-update patterns that leave partial state on failure
- Queries that don't filter for expired TTL items

**Do NOT flag** as bugs:
- Setting `ttl = 0` instead of calling `DeleteCommand` — this is intentional eventual deletion
- Best-effort writes after a main transaction — if TTL or self-healing handles failure
- Fire-and-forget writes with long TTL runways — occasional misses are by design
- `BatchWriteCommand` without `ConditionExpression` — it's a DynamoDB limitation, not a defect
- Items still present after their TTL — DynamoDB TTL deletion can lag up to 48 hours
