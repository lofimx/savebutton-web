# Kaya

## Prerequisites

* Ruby 3.4.8
* Postgres 17
* Docker: https://get.docker.com (Debian)
  * `curl -fsSL https://get.docker.com -o install-docker.sh`
  * `sh install-docker.sh --dry-run`
  * `sudo sh install-docker.sh`

## Kamal

Deploys to a standalone box are done via [Kamal](https://kamal-deploy.org/).

**Setup:**

```bash
# set your master key
vim config/master.key

# set your credentials
cat config/credentials.yml.example
rails credentials:edit

# set env vars
cp .env.example .env

# add yourself to docker users (in case you aren't)
sudo usermod -aG docker $USER
newgrp docker # or logout
```

**Deploy:**

```bash
# First deployment to a new server (and full redeploys)
source .env
kamal setup

# Updates to a deployment 
kamal deploy

# Get secrets 
kamal secrets print
# KAMAL_REGISTRY_PASSWORD=
# RAILS_MASTER_KEY=
# POSTGRES_PASSWORD=
```

## Docker

If you don't like Kamal or you don't have a fresh box to push to, you can deploy with Docker directly:

```bash
# Build and run locally
docker compose up --build

# Or just build + push to Docker Hub
docker compose build
docker login -u $YOUR_DOCKERHUB_USER
docker push $YOUR_DOCKERHUB_USER/kaya_server:latest
```

## Stripe

Save Button uses Stripe Checkout (hosted) for paid subscriptions and Stripe webhooks to keep local state in sync.

The Rails initializer reads four credentials at boot: `secret_key`, `webhook_signing_secret`, `basic_price_id`, `advanced_price_id`. If any are missing it logs `🟠 WARN: Stripe credentials incomplete (missing: …)` on boot, and the "Upgrade" button shows "Billing is not currently configured".

### One-time Stripe dashboard setup

Do this in both **Test Mode** (for dev) and **Live Mode** (for prod). Each mode has its own keys, products, prices, and webhook endpoints.

1. **Products + Prices** — Stripe → Products → "Add product":
   * Basic — recurring monthly — $3.00 → save the `price_…` ID
   * Advanced — recurring monthly — $6.00 → save the `price_…` ID
2. **Webhook endpoint (prod only)** — Stripe → Developers → Webhooks → "Add endpoint":
   * URL: `https://savebutton.com/webhooks/stripe`
   * Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_failed`
   * Reveal and save the signing secret (`whsec_…`)
3. **Customer Portal** — Stripe → Settings → Billing → Customer Portal. Enable plan changes, cancellation, invoice history. Set business info + return URL.

### Development (Stripe test mode)

Use per-environment credentials so dev never accidentally hits live Stripe:

```bash
bin/rails credentials:edit --environment development
```

```yaml
stripe:
  secret_key: sk_test_…
  webhook_signing_secret: whsec_…  # from the Stripe CLI, NOT the dashboard
  basic_price_id: price_…          # Test Mode
  advanced_price_id: price_…       # Test Mode
```

Rails creates `config/credentials/development.yml.enc` (commit) and `config/credentials/development.key` (gitignored). Forward webhooks to localhost with the Stripe CLI:

```bash
# one-time
brew install stripe/stripe-cli/stripe   # or apt; or download the binary
stripe login

# every dev session
stripe listen --forward-to localhost:3000/webhooks/stripe
```

The CLI prints a `whsec_…` on startup — that is the secret to put in development credentials, **not** the one from the dashboard (the CLI re-signs forwarded requests with its own secret). Test with card `4242 4242 4242 4242`, any future expiry, any CVC. Trigger `invoice.payment_failed` with `4000 0000 0000 0341`.

### Production (Stripe live mode)

```bash
bin/rails credentials:edit --environment production
```

```yaml
stripe:
  secret_key: sk_live_…
  webhook_signing_secret: whsec_…  # from the prod webhook endpoint created above
  basic_price_id: price_…          # Live Mode
  advanced_price_id: price_…       # Live Mode
```

Expose the decryption key to the running container — in `config/deploy.yml`:

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - RAILS_PRODUCTION_KEY
```

…and in `.kamal/secrets`:

```
RAILS_PRODUCTION_KEY=$(cat config/credentials/production.key)
```

### Verifying

```bash
# Should print true
bin/rails runner 'puts Rails.application.credentials.stripe&.dig(:basic_price_id).present?'

# Should print your Stripe account ID
bin/rails runner 'puts Stripe::Account.retrieve.id'
```

If either is wrong, check the boot log for the `🟠 WARN: Stripe credentials incomplete` line and confirm the right credentials file decrypted for the env.

## TODO

* [x] avatar
* [x] sync API
* [x] basic fuzzy search
* [x] save a bookmark/blurb
* [x] pre-cache bookmarks in /cache
* [ ] per-user SQLite full-text search?
* [ ] PDF OCR with tesseract?
* [ ] email address verification

## License

AGPL-3.0

Icons are licensed Creative Commons Zero 1.0 Universal.
