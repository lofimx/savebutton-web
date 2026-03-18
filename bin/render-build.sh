#!/usr/bin/env bash

# Exit on error
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean

# If you have a paid instance type, we recommend moving
# database migrations like this one from the build command
# to the pre-deploy command:
bin/rails db:migrate

# Load Solid gem schemas (cache, queue, cable) into the shared database.
# On the free tier, all database roles share one DATABASE_URL. After db:migrate
# marks the database as 'production' in ar_internal_metadata, Rails blocks
# schema:load as a "destructive" action. DISABLE_DATABASE_ENVIRONMENT_CHECK=1
# bypasses this, since we're only creating new tables (not dropping the database).
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:cache || true
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:queue || true
DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails db:schema:load:cable || true
