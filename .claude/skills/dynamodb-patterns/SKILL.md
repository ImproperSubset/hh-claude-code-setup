---
name: dynamodb-patterns
description: >
  DynamoDB operational patterns — transactions, conditional writes, TTL, BatchWrite, counters,
  retry logic, and eventual convergence. Use when writing or reviewing code that reads from or
  writes to DynamoDB, including TransactWriteItems, BatchWriteCommand, ConditionExpression,
  TTL handling, counter updates, or error handling for DynamoDB operations. Also use when
  someone encounters TransactionCanceledException, UnprocessedItems, ConditionalCheckFailedException,
  or counter drift issues.
user-invocable: true
---

# DynamoDB Operational Patterns

These patterns prevent the mistakes that keep recurring: counter drift from non-atomic
operations, silent data loss from unhandled UnprocessedItems, and over-engineering that
adds transactions where TTL or best-effort would suffice.

## Step 1: Read project files first

Before writing or reviewing DynamoDB code, check:

1. **`CLAUDE-patterns.md`** — established DynamoDB patterns for this project (key conventions,
   sentinel ordering, retry patterns, atomic counter rules)
2. **`CLAUDE-decisions.md`** — schema decisions and rationale (single-table design, entity
   types, TTL strategy)
3. **`~/.brain/systems/dynamodb-atomic-patterns.md`** — cross-project transaction patterns

The project files document specific patterns that have been validated. Follow them rather
than reinventing.

---

## Transactions (`TransactWriteItems`)

### When to Use

Use transactions when **any** of these apply:
- Two or more items must succeed or fail together
- A write depends on the current state of another item
- Failure mid-sequence would leave orphaned or inconsistent data

Use a **single conditional write** when only one item is being modified.

### When NOT to Use

Do NOT demand transactions when:
- The write fan-out exceeds 100 items (transaction hard limit)
- Idempotency is enforced at a different layer (e.g., a creation-lock item)
- Partial write failure is recoverable by retry or self-healing
- Best-effort writes with TTL as safety net are acceptable

### Structure

```typescript
await ddb.send(new TransactWriteCommand({
  ClientRequestToken: idempotencyKey,
  TransactItems: [
    { Put: { TableName, Item, ConditionExpression: 'attribute_not_exists(PK)' } },
    { Update: { TableName, Key, UpdateExpression: 'SET postCount = postCount + :one',
                ConditionExpression: 'attribute_exists(PK)',
                ExpressionAttributeValues: { ':one': 1 } } },
    { ConditionCheck: { TableName, Key,
                        ConditionExpression: '#status = :active',
                        ExpressionAttributeNames: { '#status': 'status' },
                        ExpressionAttributeValues: { ':active': 'active' } } },
  ],
}));
```

- `ConditionCheck` asserts read-state without modifying the item
- `ClientRequestToken` makes the transaction idempotent (valid for 10 minutes)
- Use `ReturnValuesOnConditionCheckFailure: ALL_OLD` to get actual item state on failure

### Handling `TransactionCanceledException`

```typescript
catch (error: unknown) {
  if (error instanceof Error && error.name === 'TransactionCanceledException') {
    const reasons = (error as any).CancellationReasons;
    reasons?.forEach((reason: any, i: number) => {
      if (reason.Code === 'ConditionalCheckFailed') {
        console.error(`Item ${i} condition failed`, reason.Item);
      }
    });
  }
  throw error;
}
```

Always inspect `CancellationReasons` — the array matches `TransactItems` order.

### Idempotency via `ClientRequestToken`

- Must be unique per logical operation (derive from request ID or content hash)
- DynamoDB deduplicates for 10 minutes — same token = same result, no re-execution
- Always use when the caller might retry (API Gateway, Step Functions, SQS)

### Limits

- **100 items** max per transaction, **25 per table**
- All items must be **distinct** — no two operations on the same item
- **4 MB** total request size

---

## Counter + Item Atomicity

Counter fields (e.g., `memberCount`) and the item they count MUST be in the same
`TransactWriteCommand`. Never BatchWrite-delete items then separately update the counter —
partial failures cause counter drift that's invisible and hard to repair.

```typescript
// CORRECT — atomic
await client.send(new TransactWriteCommand({
  TransactItems: [
    { Delete: { TableName: TABLE, Key: membershipKey } },
    { Update: { TableName: TABLE, Key: groupKey,
                UpdateExpression: 'SET memberCount = memberCount - :one',
                ExpressionAttributeValues: { ':one': 1 } } },
  ],
}));

// WRONG — counter drifts if UpdateCommand fails
await chunkedBatchWrite(client, TABLE, deleteRequests);
await client.send(new UpdateCommand({ ... memberCount - N ... }));
```

---

## BatchWrite (`BatchWriteCommand`)

### When to Use

- Item count may exceed the 100-item transaction limit
- You need throughput, not atomicity (1x WCU vs 2x for transactions)
- Idempotency is enforced at a different layer
- Partial failure is recoverable by retrying `UnprocessedItems`

### Key Differences from Transactions

| | TransactWriteItems | BatchWriteCommand |
|---|---|---|
| Atomicity | All-or-nothing | Best-effort, partial success possible |
| ConditionExpression | Supported per item | **NOT supported** |
| Max items | 100 | 25 per call (chainable) |
| Cost | 2x WCU per item | 1x WCU per item |

### Retry Pattern

```typescript
const MAX_RETRIES = 3;
for (let i = 0; i < items.length; i += 25) {
  let requestItems = { [tableName]: items.slice(i, i + 25) };
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    const result = await client.send(new BatchWriteCommand({
      RequestItems: requestItems,
    }));
    const unprocessed = result.UnprocessedItems?.[tableName];
    if (!unprocessed?.length) break;
    if (attempt === MAX_RETRIES) return internalServerError('BatchWrite exhausted');
    requestItems = { [tableName]: unprocessed };
    await new Promise(r => setTimeout(r, 100 * Math.pow(4, attempt)));
  }
}
```

Return `internalServerError` on exhaustion — never silently return partial data.

### Sentinel-Last Ordering

When deleting related items across multiple BatchWrite chunks, place the sentinel/index
item **last** in the array. Chunks are not transactional across calls — if chunk N fails,
chunks N+1..M are skipped. If the sentinel is deleted in an early chunk but later chunks
fail, the operation becomes non-retryable because the sentinel no longer exists to discover
remaining items.

```typescript
const deleteRequests = [
  ...childItems.map(key => ({ DeleteRequest: { Key: key } })),
  { DeleteRequest: { Key: sentinelKey } }, // LAST — survives partial failure
];
await chunkedBatchWrite(client, table, deleteRequests);
```

---

## TTL and Eventual Deletion

- Deletion lags up to **48 hours** after TTL timestamp
- **Application code must filter expired items** — don't assume DynamoDB has deleted them
- TTL deletions don't consume WCU and replicate to GSIs/streams

```typescript
// CORRECT — filter in application code or query
FilterExpression: '#ttl > :now'
// Or in application logic:
if (item.ttl && item.ttl <= Math.floor(Date.now() / 1000)) {
  return notFound('Item expired');
}
```

### TTL=0 as Logical Delete

Setting `ttl = 0` is valid for immediate logical expiry. Cheaper than `DeleteCommand` when
multiple items need "deletion" atomically — set TTL in one transaction, let DynamoDB sweep
later. Do NOT flag this as a bug.

---

## Eventual Convergence Patterns

These are **intentional architecture**, not bugs.

### Best-Effort + TTL Safety Net

```typescript
await ddb.send(new TransactWriteCommand({ TransactItems: [...] })); // must succeed
try { await ddb.send(new PutCommand({ Item: indexRow })); }         // best-effort
catch (e) { console.warn('Best-effort index write failed:', e); }
```

Correct when the auxiliary item is a convenience (index, cache), not a source of truth.

### Fire-and-Forget TTL Refresh

```typescript
void refreshTTL(itemKey, newTTL).catch(() => {});
```

Correct when the TTL runway (e.g., 90 days) is orders of magnitude longer than the
refresh interval.

### Anti-Pattern: Over-Engineering Consistency

Ask: **what happens if this auxiliary write fails?** If the answer is "TTL cleans it up"
or "the next read handles it," best-effort is the correct choice.

---

## Conditional Writes

Always use `ConditionExpression` on writes that assume item state:

```typescript
await ddb.send(new PutCommand({
  TableName, Item: post,
  ConditionExpression: 'attribute_not_exists(PK)',
}));
```

Exception: `BatchWriteCommand` cannot use `ConditionExpression` — enforce idempotency at a
different layer (e.g., a conditional-put lock item written before the batch begins).

---

## Common Anti-Patterns

### Sequential writes with manual rollback
Two+ independent writes where a catch block tries to undo the first on failure.
Fix: single `TransactWriteItems`.

### Unguarded deletes in catch blocks
Delete operations in error handlers without verifying the item was created by this request.
Fix: rollback logic belongs inside the transaction.

### Not inspecting `CancellationReasons`
Catching `TransactionCanceledException` without reading the array loses information about
which condition failed. Always inspect it.

---

## Review Checklist

Flag as **CRITICAL/HIGH**:
- Multiple independent writes that should be a single `TransactWriteItems`
- Counter update separate from the item mutation it counts
- Rollback logic in catch blocks using separate write calls
- Writes missing `ConditionExpression` when they assume item state
- Not inspecting `CancellationReasons` on `TransactionCanceledException`
- Not handling/retrying `UnprocessedItems` from BatchWrite
- Sentinel/index item not last in BatchWrite arrays
- Queries that don't filter for expired TTL items
- Transactions missing `ReturnValuesOnConditionCheckFailure: 'ALL_OLD'` on condition-bearing items

**Do NOT flag** as bugs:
- `ttl = 0` instead of `DeleteCommand` — intentional eventual deletion
- Best-effort writes after a main transaction — TTL/self-healing handles failure
- Fire-and-forget writes with long TTL runways — occasional misses by design
- `BatchWriteCommand` without `ConditionExpression` — DynamoDB limitation
- Items still present after TTL — deletion lags up to 48 hours
