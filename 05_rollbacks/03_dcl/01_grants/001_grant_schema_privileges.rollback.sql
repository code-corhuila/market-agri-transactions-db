ALTER DEFAULT PRIVILEGES IN SCHEMA transactions REVOKE SELECT, INSERT, UPDATE ON TABLES FROM transactions_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA transactions REVOKE SELECT ON TABLES FROM transactions_reader;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA transactions FROM transactions_writer, transactions_reader;
REVOKE USAGE ON SCHEMA transactions FROM transactions_writer, transactions_reader;
