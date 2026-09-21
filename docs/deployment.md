# SyncForge deployment

The CI/CD workflow in `.github/workflows/ci.yml` has five gated stages:

1. `test` provisions PostgreSQL and Redis, prepares the test database, and runs RSpec.
2. `lint` runs RuboCop.
3. `container` proves that the minimized, non-root production image builds.
4. `publish` pushes `sha-<commit>`, `latest` on the default branch, and version-tag images to GHCR.
5. `deploy` optionally migrates and rolls out the immutable SHA image over SSH, then requires `/health` to succeed.

Pull requests execute only validation. Pushes to `main` and tags matching `v*` publish images. Deployment occurs only for `main` when the repository variable `DEPLOY_ENABLED` is exactly `true`.

## Production host prerequisites

The deployment host must already have Docker Engine, Docker Compose v2, SSH access, and sufficient persistent disk. Installing those components is deliberately outside this repository and should be handled by infrastructure automation or an administrator.

Create the deployment directory and a private `production.env` based on `deploy/production.env.example`. Do not commit this file.

```bash
mkdir -p /opt/syncforge
cd /opt/syncforge
cp production.env.example production.env
chmod 600 production.env
```

Generate independent secrets, for example with the built image's `bin/rails secret`. `POSTGRES_PASSWORD`, `SECRET_KEY_BASE`, and `CRM_WEBHOOK_SECRET` must not share a value.

## GitHub configuration

Create a protected GitHub Environment named `production`, ideally with required reviewers. Configure:

Repository/environment variables:

- `DEPLOY_ENABLED=true`
- `DEPLOY_PATH=/opt/syncforge`

Environment secrets:

- `DEPLOY_HOST`: server hostname or IP
- `DEPLOY_USER`: restricted SSH deployment user
- `DEPLOY_SSH_KEY`: private key for that user
- `GHCR_PAT`: token with `read:packages` for the deployment host

The normal workflow uses the built-in `GITHUB_TOKEN` to publish packages. The separate read-only package token is sent over SSH stdin so the remote Docker client can pull a private image.

## Manual deployment

Copy `deploy/docker-compose.production.yml` and `production.env` to the host, then run:

```bash
export SYNCFORGE_IMAGE=ghcr.io/OWNER/syncforge:sha-COMMIT
docker compose --env-file production.env -f docker-compose.production.yml pull
docker compose --env-file production.env -f docker-compose.production.yml run --rm migrate
docker compose --env-file production.env -f docker-compose.production.yml up -d --remove-orphans
curl --fail http://127.0.0.1:3000/health
```

Migrations are a one-shot gate and complete before web/worker startup. They must remain backward-compatible with the currently running version for zero-downtime upgrades.

## Rollback

Select the preceding immutable `sha-*` image, then repeat the pull and `up` commands:

```bash
export SYNCFORGE_IMAGE=ghcr.io/OWNER/syncforge:sha-PREVIOUS
docker compose --env-file production.env -f docker-compose.production.yml pull
docker compose --env-file production.env -f docker-compose.production.yml up -d --remove-orphans
curl --fail http://127.0.0.1:3000/health
```

Application rollback does not automatically reverse database migrations. Use forward-compatible migrations and a tested corrective migration instead of destructive automatic rollback.

## Production boundaries

The supplied Compose topology is appropriate for a portfolio deployment or a single-host internal service. A real production system should use managed PostgreSQL/Redis, encrypted backups with restore tests, TLS termination, centralized secrets, log/metric shipping, alerting, image vulnerability scanning, and a multi-host scheduler when availability requirements justify it.
