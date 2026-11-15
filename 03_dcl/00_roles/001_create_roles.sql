-- NOLOGIN roles carry permissions. The transactions_app login and password belong to infra.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'transactions_reader') THEN
        CREATE ROLE transactions_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'transactions_writer') THEN
        CREATE ROLE transactions_writer NOLOGIN;
    END IF;
END
$$;
