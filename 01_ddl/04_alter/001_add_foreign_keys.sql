-- Foreign keys inside the transactions schema only. Nothing here is deleted physically
-- (append-only, NFR-021), so RESTRICT makes an accidental DELETE fail.
ALTER TABLE transactions.ledger_entry
    ADD CONSTRAINT fk_ledger_entry_payment_transaction
    FOREIGN KEY (transaction_id) REFERENCES transactions.payment_transaction (id) ON DELETE RESTRICT;

ALTER TABLE transactions.idempotency_key
    ADD CONSTRAINT fk_idempotency_key_payment_transaction
    FOREIGN KEY (transaction_id) REFERENCES transactions.payment_transaction (id) ON DELETE RESTRICT;
