-- One on-platform payment for a quantity of a product (api-contract §4.4, TransactionView, I-06).
-- `transaction` is an SQL keyword, hence the name. No foreign keys here: they go in 04_alter.
CREATE TABLE transactions.payment_transaction (
    id                     uuid          NOT NULL,  -- the id the saga reserved with (I-03): never generated here
    conversation_id        uuid          NOT NULL,  -- owned by chat: an id, never a foreign key (Anexo A, rule 8)
    product_id             uuid          NOT NULL,  -- owned by catalog
    buyer_id               uuid          NOT NULL,  -- owned by auth
    producer_id            uuid          NOT NULL,  -- owned by auth
    product_name           text          NOT NULL,  -- snapshots taken at creation (D-C31)
    buyer_name             text          NOT NULL,
    producer_name          text          NOT NULL,
    quantity               numeric(12,2) NOT NULL,  -- bought (D-C7)
    unit                   text          NOT NULL,
    unit_price_cents       bigint        NOT NULL,  -- frozen by the reservation (ADR-029)
    amount_cents           bigint        NOT NULL,  -- round_half_up(quantity × unit_price_cents), computed once (D-C11)
    status                 text          NOT NULL DEFAULT 'PENDING',
    payment_method         text,                    -- from the provider's result; NULL while PENDING (ADR-019)
    gateway_transaction_id text,                    -- the provider's payment id, set with the result (ADR-019)
    expires_at             timestamptz   NOT NULL,  -- end of the checkout; the expiry job settles it after this
    created_at             timestamptz   NOT NULL DEFAULT now(),
    updated_at             timestamptz   NOT NULL DEFAULT now(),
    confirmed_at           timestamptz,
    failed_at              timestamptz,

    CONSTRAINT pk_payment_transaction PRIMARY KEY (id),
    CONSTRAINT chk_payment_transaction_product_name_length  CHECK (char_length(btrim(product_name)) BETWEEN 1 AND 150),
    CONSTRAINT chk_payment_transaction_buyer_name_length    CHECK (char_length(btrim(buyer_name)) BETWEEN 1 AND 150),
    CONSTRAINT chk_payment_transaction_producer_name_length CHECK (char_length(btrim(producer_name)) BETWEEN 1 AND 150),
    CONSTRAINT chk_payment_transaction_quantity_positive    CHECK (quantity > 0),
    CONSTRAINT chk_payment_transaction_unit                 CHECK (unit IN (
        'KILOGRAMO', 'LIBRA', 'ARROBA', 'BULTO', 'CANASTA',
        'CAJA', 'DOCENA', 'MANOJO', 'LITRO', 'UNIDAD')),
    CONSTRAINT chk_payment_transaction_unit_price_cents_range CHECK (unit_price_cents BETWEEN 1 AND 999999999999),
    CONSTRAINT chk_payment_transaction_amount_cents_positive  CHECK (amount_cents > 0),
    CONSTRAINT chk_payment_transaction_status               CHECK (status IN ('PENDING', 'CONFIRMED', 'FAILED')),
    -- Each state carries exactly its own timestamp; CONFIRMED and FAILED are terminal (AGGR-INV-005).
    CONSTRAINT chk_payment_transaction_status_timestamps    CHECK (
           (status = 'PENDING'   AND confirmed_at IS NULL     AND failed_at IS NULL)
        OR (status = 'CONFIRMED' AND confirmed_at IS NOT NULL AND failed_at IS NULL)
        OR (status = 'FAILED'    AND failed_at IS NOT NULL    AND confirmed_at IS NULL)),
    CONSTRAINT chk_payment_transaction_payment_method       CHECK (payment_method IN (
        'CARD', 'NEQUI', 'PSE', 'BANCOLOMBIA_TRANSFER', 'OTHER')),
    CONSTRAINT chk_payment_transaction_pending_has_no_method CHECK (status <> 'PENDING' OR payment_method IS NULL),
    -- A confirmation always comes from a provider payment (E-43 or the expiry job's query).
    CONSTRAINT chk_payment_transaction_confirmed_has_gateway_id CHECK (status <> 'CONFIRMED' OR gateway_transaction_id IS NOT NULL),
    CONSTRAINT chk_payment_transaction_gateway_id_length    CHECK (char_length(gateway_transaction_id) BETWEEN 1 AND 64),
    CONSTRAINT chk_payment_transaction_expires_after_creation CHECK (expires_at > created_at)
);
