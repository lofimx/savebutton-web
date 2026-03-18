# ADR 0006: PostgreSQL with Native UUIDs

## Context

Kaya Server was initially built on SQLite for simplicity. SQLite has no native UUID type, which required workarounds throughout the codebase:

- Domain models (User, Anga, Bookmark, Meta, Text) each duplicated a `before_create :generate_uuid` callback using `SecureRandom.uuid`.
- ActiveStorage tables used SQLite-specific `randomblob(16)` expressions as column defaults.
- PaperTrail's `versions` table, generated with `id: :uuid`, failed at insert time because SQLite created the column as a bare `uuid` type with no auto-generation, resulting in `NOT NULL constraint failed: versions.id`.
- The schema dumper could not represent the `versions` table: `Unknown type 'uuid' for column 'id'`.

Additionally, Kaya's full-text search (ADR 0005) will benefit from PostgreSQL's `pg_trgm` extension for trigram-based fuzzy matching, replacing the current Ruby-level `amatch` gem for server-side search.

## Decision

Replace SQLite with PostgreSQL 17 as the database for all environments. Enable the `pgcrypto` extension and use native `uuid` primary keys with `gen_random_uuid()` as the database-level default. Remove all application-level UUID generation callbacks.

All tables will use `id: :uuid` primary keys. Foreign keys referencing UUID primary keys will use the `uuid` column type.

## Status

Proposed.

## Consequences

- UUID generation moves from application code to the database, eliminating five duplicated `generate_uuid` callbacks.
- PaperTrail and ActiveStorage work without SQLite-specific workarounds.
- `db/schema.rb` can represent all tables without errors.
- Future migrations use `id: :uuid` and `t.uuid` for foreign keys, with no manual setup required.
- PostgreSQL becomes a runtime dependency for development, test, and production.
- The `pg_trgm` extension becomes available for full-text search improvements.
- Existing SQLite development data is abandoned (no production data exists).
