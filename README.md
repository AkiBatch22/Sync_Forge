# SyncForge

SyncForge is a Rails API portfolio project that models a reliable SaaS integration: synthetic customer and company records arrive from a CRM as signed webhooks, are durably queued, transformed, and delivered over HTTP to a logically separate ERP API. It emphasizes the operational concerns that turn a CRUD integration into a dependable system.

> All included seed records, generated events, companies, people, emails, and failures are synthetic.

## Architecture

```mermaid
flowchart LR
    CRM[Synthetic CRM] -->|HMAC webhook| API[Webhook API]
    API --> PG[(PostgreSQL)]
    API -->|job ID| Redis[(Redis / Sidekiq)]
    Redis --> Worker[SyncWorker]
    Worker --> Transform[Customer / Company transformer]
    Transform --> Limit[Redis rate limiter]
    Limit -->|HTTP + correlation ID| ERP[ERP API]
    ERP --> ERPDB[(ERP tables in PostgreSQL)]
    Worker --> Timeline[SyncEvent timeline]
```

The ERP endpoints live in the same Rails repository for easy demonstration, but the sync path treats them as a remote service: `SyncWorker` can only reach them through `Clients::ErpClient` over HTTP. It never writes an `ErpCustomer` or `ErpCompany` directly.

## Stack and data model

- Ruby 4.0.7, Rails 8.1 API mode, PostgreSQL 18
- Sidekiq 8 and Redis 8
- RSpec, FactoryBot, Faker, WebMock, and RuboCop
- Docker Compose and GitHub Actions
- CRM: `Company`, `Customer`
- Ingestion/operations: `WebhookEvent`, `SyncJob`, `SyncEvent`
- ERP: `ErpCompany`, `ErpCustomer`

Foreign keys protect relationships; unique indexes protect CRM external IDs, ERP external IDs, webhook delivery IDs, and the one-job-per-webhook invariant. Query indexes cover correlation IDs, statuses, destinations, entities, and event time.

## Webhook lifecycle

1. `POST /api/v1/webhooks/crm` verifies `X-SyncForge-Signature` using HMAC-SHA256 over the raw body.
2. Middleware accepts a valid `X-Correlation-ID` UUID or generates one, returns it, and makes it available to controllers.
3. The controller validates the event/entity combination and delegates to `WebhookIngestor`.
4. The ingestor persists a `WebhookEvent`, `SyncJob`, and initial `SyncEvent`, then enqueues only the job ID.
5. `SyncWorker` loads the source record (falling back to the event snapshot), transforms it, checks the ERP request budget, and calls the ERP over HTTP.
6. Every state transition is recorded in PostgreSQL. Recoverable failures are re-raised to Sidekiq; non-recoverable failures finish immediately as `FAILED`.

The request never performs synchronization inline and normally returns `202 Accepted` quickly.

## Transformations and validation

`Transformers::CustomerTransformer` combines names, renames email/phone fields, maps country names to ISO-like codes, maps status values, and validates required email/country data. `Transformers::CompanyTransformer` performs the equivalent company mapping. Transformation rules do not live in controllers or the worker.

## Idempotency

At-least-once webhook delivery means duplicates are normal. SyncForge uses two layers:

- The Ruby lookup returns the existing webhook quickly and avoids unnecessary database exceptions.
- A unique PostgreSQL index on `external_event_id` closes the race where two app processes both pass that lookup. `RecordNotUnique` is recovered as a duplicate response.

A unique index on `sync_jobs.webhook_event_id` and the worker's `SUCCEEDED` guard prevent duplicate completed execution. Both application checks and database constraints are required: the first gives clear behavior and speed; only the second remains correct under concurrency.

## Retries, backoff, and failure simulation

Recoverable errors are `ExternalApiTimeout`, `RateLimitError`, and `TemporaryServiceUnavailable`. They use Sidekiq retry with exponential delay; a 429 honors `Retry-After`. `InvalidPayloadError`, `AuthenticationError`, `UnsupportedEntityError`, and `DataValidationError` are terminal and are not blindly retried. Exhausted retries mark the job failed and add a `retry_exhausted` timeline event.

Set `ERP_FAILURE_MODE`, or in development/test send `X-Failure-Mode`, to one of:

- `none` (default)
- `timeout`
- `rate_limit` (429)
- `server_error` (500)
- `unauthorized` (401)
- `invalid_request` (400)

Failure is never random by default.

## Rate limiting

`DestinationRateLimiter` uses a Redis counter per destination and minute to enforce 100 ERP requests/minute across all workers. Once exhausted, work raises a rate-limit error and is rescheduled instead of hammering ERP. Redis is appropriate because increments are atomic, fast, shared, and naturally expiring. The current v1 policy fails open if Redis is unavailable and emits a structured warning; this preserves data flow but may temporarily exceed the partner limit. A stricter production integration could fail closed.

## Correlation IDs and logging

`X-Correlation-ID` flows through the HTTP response, `WebhookEvent`, `SyncJob`, every `SyncEvent`, Sidekiq arguments (via the job record), outbound ERP headers, and JSON logs. Structured log fields include timestamp, level, service, event, message, correlation/job/webhook IDs, and customer ID where relevant. The code uses Rails logging rather than `puts` for application diagnostics.

## Operational APIs

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/v1/webhooks/crm` | Accept a signed CRM event |
| GET | `/api/v1/syncs` | List/filter jobs by `status`, `destination`, `entity_type` |
| GET | `/api/v1/syncs/:id` | Job detail plus timeline |
| GET | `/api/v1/syncs/:id/events` | Timeline only |
| GET | `/api/v1/syncs/failed` | Failed jobs |
| POST | `/api/v1/syncs/:id/replay` | Replay a non-successful job |
| GET | `/api/v1/metrics` | PostgreSQL-derived operational metrics |
| GET | `/health` | Rails, PostgreSQL, Redis, Sidekiq status |
| POST/PUT/GET | `/erp/v1/customers...` | Fake ERP customer API |
| POST/PUT | `/erp/v1/companies...` | Fake ERP company API |

Metrics include totals, success/failure/retry rates, average and p95 duration, status/failure groupings, processed events, and synced records. Version 1 intentionally uses PostgreSQL queries rather than Prometheus.

## Run with Docker

Docker is the supported local workflow; PostgreSQL and Redis need not be installed on the host.

```bash
docker compose up --build
docker compose exec web bundle exec rails db:seed
curl http://localhost:3000/health
```

Run verification:

```bash
docker compose run --rm -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://syncforge:syncforge@postgres:5432/syncforge_test \
  web bundle exec rails db:prepare
docker compose run --rm -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://syncforge:syncforge@postgres:5432/syncforge_test \
  web bundle exec rspec
docker compose run --rm web bundle exec rubocop
docker compose config
```

Generate 100 synthetic events (5% duplicates, 2% invalid payloads):

```bash
docker compose exec web ruby scripts/generate_webhook_events.rb --count=100 --duplicates=0.05 --invalid=0.02
```

Signed webhook example:

```bash
body='{"external_event_id":"demo-1","event_type":"customer.created","entity_type":"customer","entity_external_id":"CRM-CUST-DEMO","payload":{"external_id":"CRM-CUST-DEMO","first_name":"Ada","last_name":"Lovelace","email":"ada@example.test","country":"India","status":"active"}}'
signature=$(printf %s "$body" | openssl dgst -sha256 -hmac development-secret -hex | awk '{print $2}')
curl -i http://localhost:3000/api/v1/webhooks/crm \
  -H 'Content-Type: application/json' \
  -H "X-SyncForge-Signature: sha256=$signature" \
  -H "X-Correlation-ID: $(uuidgen)" \
  --data "$body"
```

## Testing and CI/CD

The RSpec suite includes model unit tests plus request, service, worker, and integration examples covering signed and invalid webhooks, duplicate delivery, correlation propagation, both transformers, successful and invalid syncs, timeouts, 429, 500, authentication, retryable/non-retryable handling, repeated attempts, retry exhaustion, replay rules, timelines, metrics, health degradation, and rate limiting.

GitHub Actions runs RSpec and RuboCop, builds the production Docker target, and—after all gates pass on `main` or a `v*` tag—publishes immutable SHA-tagged images to GitHub Container Registry. Production deployment is opt-in and environment-protected. See [`docs/deployment.md`](docs/deployment.md) for required secrets, server preparation, rollout, health verification, and rollback.

## Limitations and future improvements

- ERP is logically separated, not independently deployed; extracting it would make network isolation more realistic.
- Rate limiting uses a fixed window and fails open during Redis outages; a Lua token bucket and configurable fail policy would be stronger.
- No authentication protects operational APIs in this portfolio version.
- Metrics query raw operational tables and have no retention/aggregation strategy.
- Country mapping is intentionally small and should use a maintained ISO dataset in production.
- Payload schema versions, dead-letter tooling, encryption policy, tenant isolation, tracing, and Prometheus/OpenTelemetry are future work.
- The app processes one entity per event; production bulk sync would need checkpointing and partial-success semantics.

## Interview talking points

Be ready to explain why uniqueness must be enforced in PostgreSQL, why HTTP is retained between the worker and fake ERP, why errors are classified before retry, how correlation survives the async boundary, why rate limiting is shared in Redis, and what at-least-once delivery implies. Also discuss the deliberate tradeoffs above rather than presenting this demo as production-complete.

More repository-specific Ruby guidance is in [`docs/ruby_learning_notes.md`](docs/ruby_learning_notes.md). Practice incidents are in [`docs/debugging_exercises.md`](docs/debugging_exercises.md) with separate [`solutions`](docs/debugging_solutions.md).
