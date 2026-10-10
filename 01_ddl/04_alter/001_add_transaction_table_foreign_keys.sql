ALTER TABLE transactions.ledger_entry
    ADD CONSTRAINT fk_ledger_entry_transaction
    FOREIGN KEY (transaction_id)
    REFERENCES transactions.payment_transaction (id)
    ON DELETE RESTRICT;

ALTER TABLE transactions.idempotency_key
    ADD CONSTRAINT fk_idempotency_key_transaction
    FOREIGN KEY (transaction_id)
    REFERENCES transactions.payment_transaction (id)
    ON DELETE RESTRICT;
