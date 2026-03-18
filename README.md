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

## TODO

* [x] avatar
* [x] sync API
* [x] basic fuzzy search
* [x] save a note/bookmark
* [x] pre-cache bookmarks in /cache
* [ ] per-user SQLite full-text search?
* [ ] PDF OCR with tesseract?
* [ ] email address verification

## License

AGPL-3.0

Icons are licensed Creative Commons Zero 1.0 Universal.
