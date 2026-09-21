# SyncForge debugging exercises

All scenarios use synthetic data. For each incident, state the user impact, find evidence using the operational endpoints/logs/database, form a hypothesis, and propose a safe remediation.

1. **Duplicate webhook:** The CRM delivers the same `external_event_id` from two concurrent processes. Confirm how many webhook and sync rows exist and identify both idempotency defenses.
2. **HTTP 429:** Set ERP failure mode to `rate_limit`. Trace the job timeline and determine whether the worker retries immediately or waits.
3. **Stuck queued job:** A job remains `QUEUED` for ten minutes. Use `/health`, Sidekiq process state, Redis connectivity, and queue names to isolate the cause.
4. **Missing email:** Generate an invalid customer payload. Explain why it is terminal, where the reason appears, and why replay without correcting source data is ineffective.
5. **Bad authentication:** Simulate `unauthorized`. Verify error classification and make the case for or against automatic retry.
6. **Redis unavailable:** Stop Redis. Compare webhook acceptance, queueing, health, and rate-limiter behavior. Identify the deliberate fail-open tradeoff.
7. **High p95 latency:** Create several slow completed jobs. Compare average and p95 metrics and list likely bottlenecks across queue wait, transformation, ERP latency, and database time.
8. **Intermittent HTTP 500:** Simulate server errors for several attempts, then restore `none`. Follow `attempt_count`, state changes, backoff, and eventual outcome.
