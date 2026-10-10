CREATE TABLE transactions.payment_transaction (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id uuid NOT NULL,
    producer_id uuid NOT NULL,
    product_id uuid NOT NULL,
    product_name text NOT NULL,
    quantity numeric(12, 3) NOT NULL CHECK (quantity > 0),
    amount_cents bigint NOT NULL CHECK (amount_cents > 0),
    status text NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'CONFIRMED', 'FAILED')),
    stripe_session_id text,
    stripe_payment_intent_id text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transactions.ledger_entry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id uuid NOT NULL,
    entry_type text NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT')),
    amount_cents bigint NOT NULL CHECK (amount_cents > 0),
    description text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE transactions.idempotency_key (
    owner_id uuid NOT NULL,
    key_value text NOT NULL CHECK (length(key_value) BETWEEN 1 AND 255),
    request_hash text NOT NULL,
    transaction_id uuid NOT NULL,
    response_status smallint NOT NULL DEFAULT 201
        CHECK (response_status BETWEEN 100 AND 599),
    response_body jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_id, key_value)
);

CREATE TABLE transactions.outbox_event (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type text NOT NULL
        CHECK (event_type IN ('TransactionConfirmed', 'TransactionFailed')),
    payload jsonb NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    available_at timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz,
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    last_error text
);
