# Deploying RPMS to GCP (demo)

> This repo is design-only (see `CLAUDE.md`) and doesn't hold deployment
> scripts. The actual build/create/deploy/start/stop/teardown automation for
> the GCP demo lives in **`rpms-platform/infra/gcp-demo/`** (sibling repo),
> since that's where the project's infra tooling belongs — it already hosts
> `docker-compose.full.yml`, which the demo scripts build on directly.

## What it is

A single GCP VM running the full stack via Docker Compose — 6 module
backends + Angular shell + Postgres/Kafka/Keycloak/Redis/MinIO — built from
source (`RELEASE_BRANCH` in `rpms-platform/infra/gcp-demo/.env`, currently
`main` since no dedicated release branch exists yet) via GitHub. No
Kubernetes, no managed services, no custom Dockerfiles — chosen deliberately
for minimal setup/teardown effort over a prototype/demo, not production
readiness.

See `rpms-platform/infra/gcp-demo/README.md` for the full runbook:
one-time GCP service-account setup, then `./up.sh` to build+deploy, and
`./start.sh` / `./stop.sh` / `./teardown.sh` for day-to-day lifecycle and
guaranteed-clean resource deletion.
