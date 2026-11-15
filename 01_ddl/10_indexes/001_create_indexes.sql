-- Each index names the query or rule it serves (Anexo A, rule 3). The tables are new and empty,
-- so CONCURRENTLY is not needed.

-- E-42: a buyer's purchases and a producer's sales, newest first
CREATE INDEX idx_payment_transaction_buyer_id_created_at
    ON transactions.payment_transaction (buyer_id, created_at DESC, id);
CREATE INDEX idx_payment_transaction_producer_id_created_at
    ON transactions.payment_transaction (producer_id, created_at DESC, id);

-- I-06 row 3: one payment in progress per conversation (TRANSACTION_IN_PROGRESS)
CREATE UNIQUE INDEX uq_payment_transaction_pending_conversation
    ON transactions.payment_transaction (conversation_id) WHERE status = 'PENDING';

-- ADR-019: one provider payment confirms at most one transaction
CREATE UNIQUE INDEX uq_payment_transaction_gateway_transaction_id
    ON transactions.payment_transaction (gateway_transaction_id) WHERE gateway_transaction_id IS NOT NULL;

-- ADR-019 expiry job: payments still PENDING after their checkout expired
CREATE INDEX idx_payment_transaction_pending_expires_at
    ON transactions.payment_transaction (expires_at) WHERE status = 'PENDING';

-- AGGR-INV-006: exactly one ledger entry per transaction; also the foreign key index
CREATE UNIQUE INDEX uq_ledger_entry_transaction_id
    ON transactions.ledger_entry (transaction_id);

-- Foreign key column (rule 3)
CREATE INDEX idx_idempotency_key_transaction_id
    ON transactions.idempotency_key (transaction_id);

-- Relay tick: unpublished events in order (FOR UPDATE SKIP LOCKED)
CREATE INDEX idx_outbox_event_unpublished
    ON transactions.outbox_event (occurred_at) WHERE published_at IS NULL;
