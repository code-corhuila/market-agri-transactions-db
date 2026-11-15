-- What the producer is owed for a confirmed payment (D-C14), written in the same local
-- transaction as the confirmation. One per transaction (AGGR-INV-006, unique index in 10_indexes).
CREATE TABLE transactions.ledger_entry (
    id                 uuid        NOT NULL DEFAULT gen_random_uuid(),
    transaction_id     uuid        NOT NULL,
    producer_id        uuid        NOT NULL,  -- beneficiary, owned by auth: no foreign key
    gross_amount_cents bigint      NOT NULL,  -- = payment_transaction.amount_cents
    platform_fee_cents bigint      NOT NULL DEFAULT 0,  -- 0 in the MVP
    net_amount_cents   bigint      NOT NULL,
    status             text        NOT NULL DEFAULT 'PENDING_DISBURSEMENT',
    created_at         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_ledger_entry PRIMARY KEY (id),
    CONSTRAINT chk_ledger_entry_gross_amount_positive CHECK (gross_amount_cents > 0),
    CONSTRAINT chk_ledger_entry_platform_fee_range    CHECK (platform_fee_cents BETWEEN 0 AND gross_amount_cents),
    CONSTRAINT chk_ledger_entry_net_amount            CHECK (net_amount_cents = gross_amount_cents - platform_fee_cents),
    CONSTRAINT chk_ledger_entry_status                CHECK (status IN ('PENDING_DISBURSEMENT', 'DISBURSED'))
);
