CREATE INDEX idx_payment_transaction_buyer_created_at
    ON transactions.payment_transaction (buyer_id, created_at DESC);

CREATE INDEX idx_payment_transaction_producer_created_at
    ON transactions.payment_transaction (producer_id, created_at DESC);

CREATE UNIQUE INDEX idx_payment_transaction_stripe_session_id
    ON transactions.payment_transaction (stripe_session_id)
    WHERE stripe_session_id IS NOT NULL;

CREATE UNIQUE INDEX idx_payment_transaction_stripe_payment_intent_id
    ON transactions.payment_transaction (stripe_payment_intent_id)
    WHERE stripe_payment_intent_id IS NOT NULL;

CREATE INDEX idx_ledger_entry_transaction_id
    ON transactions.ledger_entry (transaction_id);

CREATE INDEX idx_idempotency_key_transaction_id
    ON transactions.idempotency_key (transaction_id);

CREATE INDEX idx_outbox_event_unpublished
    ON transactions.outbox_event (available_at, occurred_at)
    WHERE published_at IS NULL;

CREATE INDEX idx_outbox_event_aggregate
    ON transactions.outbox_event (aggregate_type, aggregate_id, occurred_at);
