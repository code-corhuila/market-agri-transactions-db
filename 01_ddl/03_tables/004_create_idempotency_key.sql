-- The database half of idempotent creation (P-9.3, D-C35): I-06 inserts the payment and its
-- key in ONE transaction; a repeated key rolls back and answers 200 with the original payment.
-- Same design as catalog's table, in this schema (Annex J: each _app writes only its schema).
CREATE TABLE transactions.idempotency_key (
    owner_id       uuid        NOT NULL,  -- JWT sub of the caller (the saga's service token)
    key_value      text        NOT NULL,  -- the Idempotency-Key header (= transactionId for I-06)
    transaction_id uuid        NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_idempotency_key PRIMARY KEY (owner_id, key_value),
    CONSTRAINT chk_idempotency_key_key_value_length CHECK (char_length(key_value) BETWEEN 8 AND 128)
);
