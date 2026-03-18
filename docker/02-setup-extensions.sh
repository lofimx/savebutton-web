#!/bin/bash
set -e

# Enable PostgreSQL extensions on all kaya production databases.
# This script runs once when the Postgres container is first initialized.
# It must sort after production.sql (which creates the additional databases).

for db in kaya_production kaya_production_cache kaya_production_queue kaya_production_cable; do
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS pgcrypto;
EOSQL
done

# pg_trgm is only needed on the primary database (for full-text search).
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "kaya_production" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
EOSQL
