# Running RPMS Locally (Full Stack)

> Step-by-step instructions to bring up the **entire** RPMS application locally —
> infra, all 6 module backends, and the Angular shell — for manual end-to-end testing.
>
> For database-only setup (no app services), see [`local-database-setup.md`](local-database-setup.md).

---

## 0. Prerequisites

- **Docker Desktop** running
- **Java 21** (all backends)
- **Maven** (M1/M2/M4 — Spring Boot) and the **Maven wrapper** is fine for M3/M5/M6 (Quarkus)
- **Node.js 18+** and npm (shell + Angular libs)
- All 8 repos cloned as **sibling directories** under the same parent folder:

```
RPMS/
├── rpms-design
├── rpms-platform
├── rpms-mod-plantation     (M1 — Spring Boot, port 18081)
├── rpms-mod-tree           (M2 — Spring Boot, port 8082)
├── rpms-mod-tapping        (M3 — Quarkus,     port 8083)
├── rpms-mod-workforce      (M4 — Spring Boot, port 8084)
├── rpms-mod-activity       (M5 — Quarkus,     port 8085)
├── rpms-mod-attendance     (M6 — Quarkus,     port 8086)
└── rpms-shell-web          (Angular shell,    port 4200)
```

Module backends must be started in **dependency order** (M1 → M2 → M4 → M3 → M5 → M6) the
first time a fresh database is seeded, but for normal local dev with an already-seeded DB,
start order doesn't matter — just get them all running before opening the shell.

---

## 1. Start infrastructure (Docker)

From `rpms-platform`:

```bash
cd rpms-platform/infra/docker
docker compose -p rpms-full -f docker-compose.full.yml up -d
```

> The `-p rpms-full` project name matters — it must match whatever project name the
> stack was originally brought up with, or Compose won't recognize the existing
> containers/volumes as "its own" and may try to **recreate** them (which can wipe a
> running Postgres if its volume mapping differs from what you expect). If you're not
> sure what project name is already in use, check first: `docker inspect <container> --format '{{index .Config.Labels "com.docker.compose.project"}}'`.

This brings up Postgres (5432), Kafka (9092), Schema Registry (8081), Keycloak (8180),
Redis (6379), MinIO (9000/9001), pgAdmin, and Kafdrop.

```bash
docker ps
```

Wait for `rpms-postgres`, `rpms-kafka`, `rpms-redis`, `rpms-minio`, `rpms-schema-registry`
to show `healthy`. **`rpms-keycloak`'s health check is flaky and often shows
`unhealthy`/`health: starting` even when it's fully up** — verify it directly instead:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8180/realms/rpms
# 200 means Keycloak is actually ready, ignore the container's reported health
```

`rpms-pgadmin` crash-looping is a known, unrelated issue — ignore it, it's not required
for the app to run.

If the database schema isn't seeded yet, follow
[`local-database-setup.md`](local-database-setup.md) first.

---

## 2. Build and start each backend

Each module backend has a prebuilt artifact after the first build — subsequent runs just
need step (b). On Windows, **always check for and kill a stale process before
restarting** (stale locked jars cause confusing build failures):

```bash
jps -l        # find any leftover java processes
# kill any stale `*-service.jar` or `quarkus-run.jar` process before rebuilding
```

### M1 — plantation-service (Spring Boot, port 18081)

```bash
cd rpms-mod-plantation/backend
mvn clean package -DskipTests        # (a) build — only needed after code changes
java -jar target/plantation-service.jar   # (b) run
```

### M2 — tree-service (Spring Boot, port 8082)

```bash
cd rpms-mod-tree/backend
mvn clean package -DskipTests
java -jar target/tree-service.jar
```

### M4 — workforce-service (Spring Boot, port 8084)

```bash
cd rpms-mod-workforce/backend
mvn clean package -DskipTests
java -jar target/workforce-service.jar
```

### M3 — tapping-service (Quarkus, port 8083)

```bash
cd rpms-mod-tapping/backend
./mvnw clean package -DskipTests
java -jar target/quarkus-app/quarkus-run.jar
```

### M5 — activity-service (Quarkus, port 8085)

```bash
cd rpms-mod-activity/backend
./mvnw clean package -DskipTests
java -jar target/quarkus-app/quarkus-run.jar
```

### M6 — attendance-service (Quarkus, port 8086)

```bash
cd rpms-mod-attendance/backend
./mvnw clean package -DskipTests
java -jar target/quarkus-app/quarkus-run.jar
```

Each will log a line like `Started ... Application in N.NN seconds` (Spring) or
`... started in N.Ns. Listening on: http://0.0.0.0:PORT` (Quarkus) when ready.

Run each in its own terminal (or background process) — they all need to stay up
simultaneously.

---

## 3. Build and run the Angular shell

The 6 module Angular libraries are consumed by the shell via local `file:` dependencies
pointing at each module's built `dist/` output. Build each one first if `dist/` is missing
or stale:

```bash
cd rpms-mod-plantation/angular-lib && npx ng build mod-plantation
cd rpms-mod-tree/angular-lib       && npx ng build mod-tree
cd rpms-mod-tapping/angular-lib    && npx ng build mod-tapping
cd rpms-mod-workforce/angular-lib  && npx ng build mod-workforce
cd rpms-mod-activity/angular-lib   && npx ng build mod-activity
cd rpms-mod-attendance/angular-lib && npx ng build mod-attendance
```

Then start the shell:

```bash
cd rpms-shell-web
npm install     # re-links local file: deps if any dist/ changed
npm start       # ng serve --port 4200
```

> ⚠️ **If you rebuilt a module's `dist/` and the shell still shows old behavior**, `npm
> install` does NOT always re-copy an unchanged-version `file:` dependency. Force it:
> ```bash
> rm -rf node_modules/@rpms/mod-<module>
> npm install
> rm -rf .angular/cache
> npm start
> ```
> Also confirm `.npmrc` has `install-links=true` and that `node_modules/@rpms/*` are real
> directories, not symlinks (`ls -la node_modules/@rpms/`) — symlinked local deps break
> Angular's dev-server module resolution and surface as cryptic `NG0203`/`NG0200` DI
> errors that look like application bugs.

---

## 4. Log in and test

Open **http://localhost:4200**.

| User | Password | Role |
|---|---|---|
| `claude.smoketest` | `SmokeTest123!` | Provisioned smoke-test account, full access |

All 6 modules' routes are mounted in the shell nav — plantations, trees, workers/gangs,
tapping tasks/latex collections, daily activities/inspections, and attendance
(daily attendance, locations, scan log, regularizations, shift rosters, monthly summaries,
plantation snapshots, analytics).

---

## Quick reference — ports

| Service | Port |
|---|---|
| plantation-service (M1) | 18081 |
| tree-service (M2) | 8082 |
| tapping-service (M3) | 8083 |
| workforce-service (M4) | 8084 |
| activity-service (M5) | 8085 |
| attendance-service (M6) | 8086 |
| Angular shell | 4200 |
| Postgres | 5432 |
| Kafka | 9092 |
| Schema Registry | 8081 |
| Keycloak | 8180 |
| Redis | 6379 |
| MinIO | 9000 / 9001 |

---

## Shutting everything down

Stop things in the reverse order you started them: shell → backends → infra.

```bash
# 1. Stop the shell: Ctrl+C in its terminal, or find/kill the process on port 4200
netstat -ano | grep ":4200" | grep LISTENING   # note the PID in the last column
taskkill //PID <pid> //F                        # Windows
# kill <pid>                                    # macOS/Linux

# 2. Stop each backend the same way, by port:
for port in 18081 8082 8083 8084 8085 8086; do
  netstat -ano | grep ":$port " | grep LISTENING
done
# then taskkill //PID <pid> //F (or kill <pid>) for each one found

# 3. Stop infra (data preserved in volumes — does NOT wipe Postgres/Keycloak data):
cd rpms-platform/infra/docker
docker compose -p rpms-full -f docker-compose.full.yml stop
```

> **Don't use `jps -l` to find the backend PIDs on Windows** — it also lists unrelated
> JVM processes (e.g. an IDE's Java language server) and can be misleading. Matching by
> the port the service listens on (as above) is unambiguous. Also note: `docker compose
> ... stop` (not `down -v`) is intentional — it stops containers without touching the
> named volumes, so Postgres/Keycloak data survives a stop/start cycle. Never run `down
> -v` on this stack unless you specifically intend to wipe the dev database.

To fully verify everything is down:

```bash
docker ps                                       # should show no rpms-* containers
for port in 4200 18081 8082 8083 8084 8085 8086 8180 5432; do
  netstat -ano | grep ":$port " | grep LISTENING && echo "still up: $port"
done
```
