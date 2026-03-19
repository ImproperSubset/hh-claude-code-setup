# Testing Discipline

These rules apply to all projects. They exist because Claude repeatedly ships untested features, dismisses test failures, and silently weakens tests to make them pass.

## New features need tests

Every new function, endpoint, or behavior change needs test coverage. Work is NOT done until tests exist and pass.

**Before writing implementation code**, state what tests you plan to write. This makes it visible when you're about to skip testing. If you can't articulate what to test, you don't understand the feature well enough to implement it.

**Do NOT** claim work is complete and then add tests as a follow-up. The tests are part of the work.

## Failing tests mean something is wrong

Investigate every failure. Do not move on until you understand why it failed.

**Do NOT** dismiss failures as "flaky" or "pre-existing" without evidence. The evidence is: run the failing test on the base branch. If it fails there too, it's pre-existing — track it. If it only fails on your branch, you broke it.

**Do NOT** dismiss intermittent failures as acceptable. A test that sometimes fails is a test that's detecting a real problem — either in the code (timing, race condition) or in the test (insufficient waits, bad assumptions). Both need fixing.

## Never weaken tests to make them pass

**Do NOT** add try/catch around assertions to degrade gracefully. A test that can't run should fail, not silently pass. False confidence is worse than a visible failure.

**Do NOT** delete or disable tests to make the suite green.

**If a failure requires infrastructure changes** (IAM policy, CDK deploy, env config), make those changes. Don't paper over the failure in test code.

## Before claiming work is done

Walk through this checklist:

1. What new functions/behaviors did I add? Do they have tests?
2. Did I run the test suite? What failed?
3. For each failure: did I investigate the root cause, or did I dismiss it?
4. Are there tests I weakened or skipped? Why?

If you can't answer these honestly, you're not done.
