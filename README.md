# market-agri-transactions-db

PostgreSQL schema and Liquibase migrations for the **transactions** domain of Marketplace Agrícola Huila.

This repository owns the `transactions` schema, its domain roles, grants, and migrations. The PostgreSQL
instance, persistent volume, and `transactions_app` login belong to `market-agri-infra` (Anexo J,
ADR-010). The API connects as `transactions_app`; it does not own or run schema migrations (ADR-011).

Governance, ADRs and the data model live in
[`market-agri-docs`](https://github.com/code-corhuila/market-agri-docs): see
[ADR-010](https://github.com/code-corhuila/market-agri-docs/blob/main/05-architecture/decisions/records/ADR-010-data-isolation.md)
(data isolation: one instance, one schema per domain) and
[ADR-011](https://github.com/code-corhuila/market-agri-docs/blob/main/05-architecture/decisions/records/ADR-011-migrations-liquibase.md)
(migrations with Liquibase, only in the `-db` repository).

## Layout

```
changelog/changelog-master.yaml   Liquibase entry point
01_ddl/                           schema and future structural changes
02_dml/                           data migrations
03_dcl/                           transactions_reader/writer roles and grants
04_tcl/                           transaction control and recovery scripts
05_rollbacks/                     rollback SQL mirroring forward changes
deploy/compose.yml                deliberate Liquibase runner, included by infra
.github/workflows/db-ci.yml       rebuild, isolation, full rollback, and rebuild
```

## Rules

1. Domain objects live in `transactions`; only the Liquibase control tables live in `public`.
2. Every SQL changeset has a rollback file under the matching `05_rollbacks/` path. Never edit an
   applied changeset; make corrections in a new changeset.
3. `transactions_app` receives `transactions_writer`; the application login and its secret are created
   by infra, never stored here. No transaction-domain role receives privileges on another schema.
4. `transactions_writer` has no `DELETE`, on purpose (same rule as `market-agri-catalog-db`): payments and
   ledger entries are append-only, and a state change is an `UPDATE` or a new row. A changeset that needs to
   delete data runs as the migration user, not as `transactions_app`.
5. Keep database deployment separate from API startup. Migrate first, then deploy the API.

## B2 tables

| Table | Purpose | Main constraints |
|---|---|---|
| `payment_transaction` | Payment lifecycle and purchase snapshots | `PENDING`, `CONFIRMED`, or `FAILED`; positive quantity and `amount_cents`; unique Stripe references when present |
| `ledger_entry` | Append-only debit or credit entries for a payment | Positive `amount_cents`; restrictive FK to `payment_transaction` |
| `idempotency_key` | Request fingerprint and stored response for safe retries | Primary key `(owner_id, key_value)`; restrictive FK to `payment_transaction` |
| `outbox_event` | Durable `TransactionConfirmed` / `TransactionFailed` messages for the relay | JSON payload; unpublished-event and aggregate indexes |

Money is stored as integer COP cents (ADR-012). Payment and ledger rows are retained; status
changes update the payment row, while ledger entries and outbox events are appended.

## Run it

From `market-agri-infra`, after the transactions include and environment variable are configured:

```bash
docker compose --env-file env/dev.env --profile tooling config
docker compose --env-file env/dev.env run --rm transactions-db-migrate
docker compose --env-file env/dev.env run --rm transactions-db-migrate status --verbose
docker compose --env-file env/dev.env run --rm transactions-db-migrate rollback-count 1
```

## Branching

Work enters `develop` through a child branch and Pull Request. Promotion to `qa` and `main` follows the
project Git guide and uses re-application with `cherry-pick -x`; do not merge permanent branches.
