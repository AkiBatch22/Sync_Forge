# Ruby learning notes from SyncForge

## Classes and objects

Classes bundle state and behavior. `Clients::ErpClient` stores a base URI in `initialize` and exposes `upsert`. Each client instance can point at a different ERP URL, which makes tests deterministic without global configuration.

ActiveRecord classes such as `Customer < ApplicationRecord` add database-backed attributes, queries, associations, validations, and transactions. `Customer.find_by(external_id: ...)` returns a model or `nil`; `find_by!` raises when absence should terminate control flow.

## Modules and namespaces

Modules group names and share behavior. `Transformers::CustomerTransformer` avoids colliding with other `CustomerTransformer` constants. `ErpFailureSimulation` is an `ActiveSupport::Concern` included by both ERP controllers, so the failure policy has one implementation.

## Hashes and symbols

Ruby hashes carry transformed payloads:

```ruby
{ external_id: "CRM-CUST-1", country_code: "IN" }
```

`external_id:` is a symbol key. Incoming JSON usually has string keys, so `BaseTransformer#fetch!` accepts either string or symbol keys. Calling `to_json` serializes the hash for HTTP.

## Blocks

Blocks are behavior passed to methods. `Net::HTTP.start(...) { |http| http.request(request) }` guarantees the connection is scoped to the block. `WebHookEvent.find_or_create_by!(...) do |event| ... end` initializes fields only for a new row.

## Enumerable

Arrays and relations use `Enumerable`-style operations. Metrics convert durations with `map(&:to_f)`, sort them, use `sum`, and select a percentile by index. Seed generation uses `500.times.map` to build a reusable company array.

## Exceptions and rescue

Exceptions model outcomes that change retry policy. `SyncProcessor` rescues `IntegrationErrors::RecoverableError`, persists `RETRYING`, then re-raises for Sidekiq. It rescues terminal integration errors separately, persists `FAILED`, and does not re-raise. Rescue ordering matters because subclasses must be handled before a broad parent.

## ActiveRecord

Models provide object-relational mapping, but database constraints remain essential. `validates :external_id, uniqueness: true` provides a useful message; the unique index prevents concurrent inserts. `belongs_to`, `has_one`, and `has_many` declare relationships backed by foreign keys in the migration.

Scopes remain composable: `SyncJob.failed.where(destination: "erp").order(created_at: :desc)`. Avoid loading rows when PostgreSQL can aggregate them with `count`, `sum`, or `group`.

## Service objects

`WebhookIngestor`, `SyncProcessor`, transformers, the ERP client, and rate limiter each own one coherent responsibility. Their `call` or domain method keeps controllers thin and makes dependencies injectable in specs. A service object is useful when it names business behavior; it is not a goal by itself.

## Sidekiq workers

`SyncWorker` includes `Sidekiq::Job`. The queue stores a small scalar job ID rather than an ActiveRecord object. On execution, the worker reloads durable state, which avoids stale serialized objects. Retry timing is explicit, retry exhaustion persists a terminal event, and `SyncProcessor` ensures only recoverable exceptions reach Sidekiq.
