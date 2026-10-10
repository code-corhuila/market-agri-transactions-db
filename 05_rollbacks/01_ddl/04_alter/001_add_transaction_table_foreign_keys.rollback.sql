ALTER TABLE transactions.idempotency_key
    DROP CONSTRAINT IF EXISTS fk_idempotency_key_transaction;

ALTER TABLE transactions.ledger_entry
    DROP CONSTRAINT IF EXISTS fk_ledger_entry_transaction;
