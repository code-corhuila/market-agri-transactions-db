-- HU-PLAT-006 · B2: the table rules of the transactions schema (06-data/models.md, ADR-014,
-- ADR-019, ADR-029, api-contract I-06 and E-43). Run by db-ci after the first update;
-- everything is rolled back at the end.
\set ON_ERROR_STOP on
BEGIN;

-- Fails the run unless the statement is refused by exactly the expected constraint.
CREATE FUNCTION pg_temp.expect_refused(stmt text, expected text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
    got text;
BEGIN
    EXECUTE stmt;
    RAISE EXCEPTION 'FAIL: accepted, % should refuse it: %', expected, stmt;
EXCEPTION WHEN check_violation OR unique_violation OR foreign_key_violation THEN
    GET STACKED DIAGNOSTICS got = CONSTRAINT_NAME;
    IF got IS DISTINCT FROM expected THEN
        RAISE EXCEPTION 'FAIL: refused by %, expected %: %', got, expected, stmt;
    END IF;
    RAISE NOTICE 'ok: % refuses it', expected;
END $$;

-- A valid PENDING payment for the given conversation; the other columns can be overridden.
CREATE FUNCTION pg_temp.payment(id uuid, conversation uuid, extra_cols text DEFAULT '',
                                extra_vals text DEFAULT '') RETURNS text
LANGUAGE sql AS $$
    SELECT format(
        'INSERT INTO transactions.payment_transaction (id, conversation_id, product_id, buyer_id,'
        ' producer_id, product_name, buyer_name, producer_name, quantity, unit, unit_price_cents,'
        ' amount_cents, expires_at%s) VALUES (%L, %L, gen_random_uuid(), gen_random_uuid(),'
        ' gen_random_uuid(), %L, %L, %L, 12.5, %L, 680000, 8500000, now() + interval ''30 minutes''%s)',
        extra_cols, id, conversation, 'Café pergamino seco', 'Carlos Pérez', 'Ana Ruiz', 'ARROBA',
        extra_vals);
$$;

-- 1. A valid PENDING payment is accepted with its defaults (AC1).
DO $$ BEGIN EXECUTE pg_temp.payment('00000000-0000-4000-8000-000000000001',
                                    'c0000000-0000-4000-8000-000000000001'); END $$;
DO $$ BEGIN
    IF (SELECT status FROM transactions.payment_transaction
        WHERE id = '00000000-0000-4000-8000-000000000001') <> 'PENDING' THEN
        RAISE EXCEPTION 'FAIL: status does not default to PENDING';
    END IF;
END $$;

-- 2. Money is positive (AC3, ADR-029).
SELECT pg_temp.expect_refused(replace(pg_temp.payment(gen_random_uuid(), gen_random_uuid()),
       '8500000', '0'), 'chk_payment_transaction_amount_cents_positive');
SELECT pg_temp.expect_refused(replace(pg_temp.payment(gen_random_uuid(), gen_random_uuid()),
       '680000', '0'), 'chk_payment_transaction_unit_price_cents_range');

-- 3. Status and its timestamp go together (AC5).
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', status, gateway_transaction_id', ', ''CONFIRMED'', ''9-1-1'''),
       'chk_payment_transaction_status_timestamps');
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', failed_at', ', now()'), 'chk_payment_transaction_status_timestamps');

-- 4. One PENDING payment per conversation (AC6, I-06 row 3); a settled one does not block.
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(),
       'c0000000-0000-4000-8000-000000000001'), 'uq_payment_transaction_pending_conversation');
UPDATE transactions.payment_transaction
   SET status = 'FAILED', failed_at = now(), payment_method = 'NEQUI'
 WHERE id = '00000000-0000-4000-8000-000000000001';
DO $$ BEGIN EXECUTE pg_temp.payment('00000000-0000-4000-8000-000000000002',
                                    'c0000000-0000-4000-8000-000000000001'); END $$;

-- 5. One Wompi payment confirms at most one transaction (AC7, ADR-019); NULLs do not collide.
UPDATE transactions.payment_transaction
   SET status = 'CONFIRMED', confirmed_at = now(), gateway_transaction_id = '1234-1610641025-49201',
       payment_method = 'CARD'
 WHERE id = '00000000-0000-4000-8000-000000000002';
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', status, confirmed_at, gateway_transaction_id, payment_method',
       ', ''CONFIRMED'', now(), ''1234-1610641025-49201'', ''CARD'''),
       'uq_payment_transaction_gateway_transaction_id');
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', status, confirmed_at', ', ''CONFIRMED'', now()'),
       'chk_payment_transaction_confirmed_has_gateway_id');

-- 6. The payment method is one of the five codes, and unknown while PENDING (AC8).
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', status, failed_at, payment_method', ', ''FAILED'', now(), ''BITCOIN'''),
       'chk_payment_transaction_payment_method');
SELECT pg_temp.expect_refused(pg_temp.payment(gen_random_uuid(), gen_random_uuid(),
       ', payment_method', ', ''CARD'''), 'chk_payment_transaction_pending_has_no_method');

-- 7. Ledger: one entry per transaction, net = gross − fee (AC2, AC4, AGGR-INV-006).
INSERT INTO transactions.ledger_entry (transaction_id, producer_id, gross_amount_cents,
                                       platform_fee_cents, net_amount_cents)
VALUES ('00000000-0000-4000-8000-000000000002', gen_random_uuid(), 8500000, 0, 8500000);
SELECT pg_temp.expect_refused(
    $q$INSERT INTO transactions.ledger_entry (transaction_id, producer_id, gross_amount_cents,
       platform_fee_cents, net_amount_cents) VALUES ('00000000-0000-4000-8000-000000000002',
       gen_random_uuid(), 8500000, 0, 8500000)$q$, 'uq_ledger_entry_transaction_id');
SELECT pg_temp.expect_refused(
    $q$INSERT INTO transactions.ledger_entry (transaction_id, producer_id, gross_amount_cents,
       platform_fee_cents, net_amount_cents) VALUES ('00000000-0000-4000-8000-000000000001',
       gen_random_uuid(), 8500000, 100, 8500000)$q$, 'chk_ledger_entry_net_amount');
DO $$ BEGIN
    IF (SELECT status FROM transactions.ledger_entry
        WHERE transaction_id = '00000000-0000-4000-8000-000000000002') <> 'PENDING_DISBURSEMENT' THEN
        RAISE EXCEPTION 'FAIL: ledger status does not default to PENDING_DISBURSEMENT';
    END IF;
END $$;
SELECT pg_temp.expect_refused(
    $q$INSERT INTO transactions.ledger_entry (transaction_id, producer_id, gross_amount_cents,
       platform_fee_cents, net_amount_cents) VALUES (gen_random_uuid(), gen_random_uuid(),
       8500000, 0, 8500000)$q$, 'fk_ledger_entry_payment_transaction');

-- 8. Idempotency key and outbox (AC1).
INSERT INTO transactions.idempotency_key (owner_id, key_value, transaction_id)
VALUES (gen_random_uuid(), '00000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000002');
SELECT pg_temp.expect_refused(
    $q$INSERT INTO transactions.idempotency_key (owner_id, key_value, transaction_id)
       VALUES (gen_random_uuid(), 'short', '00000000-0000-4000-8000-000000000002')$q$,
    'chk_idempotency_key_key_value_length');
INSERT INTO transactions.outbox_event (event_id, event_type, routing_key, envelope)
VALUES (gen_random_uuid(), 'TransactionConfirmed', 'transactions.transaction-confirmed', '{}');
SELECT pg_temp.expect_refused(
    $q$INSERT INTO transactions.outbox_event (event_id, event_type, routing_key, envelope)
       VALUES (gen_random_uuid(), 'ProductCreated', 'x', '{}')$q$, 'chk_outbox_event_event_type');

-- 9. No foreign key leaves the schema (AC9, Annex A rule 8) and transactions_app cannot
--    delete (AC10, append-only).
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint c JOIN pg_class t ON t.oid = c.conrelid
                 JOIN pg_namespace n ON n.oid = t.relnamespace
                 JOIN pg_class r ON r.oid = c.confrelid JOIN pg_namespace rn ON rn.oid = r.relnamespace
                WHERE c.contype = 'f' AND n.nspname = 'transactions' AND rn.nspname <> 'transactions') THEN
        RAISE EXCEPTION 'FAIL: a foreign key leaves the transactions schema';
    END IF;
    IF has_table_privilege('transactions_app', 'transactions.payment_transaction', 'DELETE') THEN
        RAISE EXCEPTION 'FAIL: transactions_app can delete payments';
    END IF;
    RAISE NOTICE 'ok: no cross-schema foreign key, no DELETE for transactions_app';
END $$;

ROLLBACK;
