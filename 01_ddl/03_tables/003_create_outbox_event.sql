-- Transactional outbox (ADR-014): the event is written in the same local transaction as the
-- state change; the relay publishes it to RabbitMQ and sets published_at on the broker confirm.
CREATE TABLE transactions.outbox_event (
    event_id     uuid        NOT NULL,  -- = envelope eventId, the consumers' idempotency key
    event_type   text        NOT NULL,
    routing_key  text        NOT NULL,  -- e.g. transactions.transaction-confirmed
    envelope     jsonb       NOT NULL,  -- the full event envelope (02-domain/domain-events.md)
    occurred_at  timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,           -- NULL until the broker confirms
    attempts     integer     NOT NULL DEFAULT 0,

    CONSTRAINT pk_outbox_event PRIMARY KEY (event_id),
    CONSTRAINT chk_outbox_event_event_type  CHECK (event_type IN ('TransactionConfirmed', 'TransactionFailed')),
    CONSTRAINT chk_outbox_event_routing_key CHECK (char_length(routing_key) BETWEEN 1 AND 255),
    CONSTRAINT chk_outbox_event_attempts    CHECK (attempts >= 0)
);
