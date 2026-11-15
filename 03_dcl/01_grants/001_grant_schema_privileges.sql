-- Permissions stay within the transactions schema (Anexo J.3).
GRANT USAGE ON SCHEMA transactions TO transactions_reader, transactions_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA transactions TO transactions_reader;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA transactions TO transactions_writer;

ALTER DEFAULT PRIVILEGES IN SCHEMA transactions GRANT SELECT ON TABLES TO transactions_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA transactions GRANT SELECT, INSERT, UPDATE ON TABLES TO transactions_writer;
