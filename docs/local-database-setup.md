# Local Database Setup Guide

> Step-by-step instructions for running the RPMS database locally using Docker.

---

## Prerequisites

- **Docker Desktop** installed and running ([download](https://www.docker.com/products/docker-desktop/))
- **Git** (to clone the repo)
- The `rpms-design` repo cloned locally

---

## Step 1 — Start the PostgreSQL Container

We use the `timescale/timescaledb-ha:pg18` image which bundles PostgreSQL 18, PostGIS, TimescaleDB, and pgvector in a single container.

```bash
docker run -d --name rpms-db ^
  -p 5432:5432 ^
  -e POSTGRES_USER=rpms ^
  -e POSTGRES_PASSWORD=rpms123 ^
  -e POSTGRES_DB=rpms ^
  -v rpms-pgdata:/var/lib/postgresql/data ^
  timescale/timescaledb-ha:pg18
```

> **Note for macOS/Linux:** Replace `^` with `\` for line continuation.

Wait ~30 seconds for initialization, then verify:

```bash
docker ps
```

You should see `rpms-db` with status `Up`.

---

## Step 2 — Enable Extensions

Connect to the database:

```bash
docker exec -it rpms-db psql -U rpms -d rpms
```

Run the following SQL:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS vector;
```

Verify all extensions are loaded:

```sql
SELECT extname, extversion FROM pg_extension
WHERE extname IN ('postgis', 'uuid-ossp', 'timescaledb', 'vector');
```

You should see all four listed. Type `\q` to exit psql.

---

## Step 3 — Copy DDL Files into the Container

From the root of your cloned `rpms-design` repo:

```bash
docker cp database/module-1-field-records/plantation_field_records_ddl.sql rpms-db:/tmp/
docker cp database/module-2-tree-records/tree_records_tracking_ddl.sql rpms-db:/tmp/
docker cp database/module-3-tapping-task/tapping_task_monitoring_ddl.sql rpms-db:/tmp/
docker cp database/module-4-workforce/workforce_management_ddl.sql rpms-db:/tmp/
docker cp database/module-5-daily-activity/daily_activity_monitoring_ddl.sql rpms-db:/tmp/
docker cp database/module-6-attendance/attendance_management_ddl.sql rpms-db:/tmp/
```

---

## Step 4 — Execute DDL Scripts

Scripts must run in module dependency order. M1 first (no dependencies), then M2, M3, M4, M5, M6.

```bash
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/plantation_field_records_ddl.sql
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/tree_records_tracking_ddl.sql
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/tapping_task_monitoring_ddl.sql
```

### M3 Fix — Required After Running tapping_task_monitoring_ddl.sql

The M3 DDL has two known bugs that cause partial failure:

1. **Table ordering bug:** `latex_collection_record` references `collection_point`, but `collection_point` is defined after it in the DDL. PostgreSQL cannot create a foreign key to a table that doesn't exist yet, so `collection_point`, `latex_collection_record`, and `latex_quality_test` all fail to create.

2. **Partitioned table PK bug:** `iot_sensor_reading` defines `reading_id BIGSERIAL PRIMARY KEY` with `PARTITION BY RANGE (reading_timestamp)`. PostgreSQL requires the partition column to be included in the primary key for partitioned tables.

After running the M3 DDL (which partially succeeds), run the fix script below. Save the following as `m3-fix.sql` and copy it into the container:

```bash
docker cp m3-fix.sql rpms-db:/tmp/
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/m3-fix.sql
```

<details>
<summary><strong>m3-fix.sql</strong> (click to expand)</summary>

```sql
-- ============================================================================
-- RPMS Module 3 — FIX SCRIPT
-- Fixes two bugs in tapping_task_monitoring_ddl.sql:
--   1. Table ordering: collection_point must be created before latex_collection_record
--   2. iot_sensor_reading PRIMARY KEY must include the partition column
--
-- Run AFTER the original DDL (which partially succeeded).
-- This script creates the missing tables, indexes, triggers, and partitions.
-- ============================================================================

-- ============================================================================
-- FIX 1: Create collection_point FIRST (was Section 6, needed before Section 5)
-- ============================================================================

CREATE TABLE IF NOT EXISTS collection_point (
    collection_point_id SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),

    point_code          VARCHAR(30)     NOT NULL,
    point_name          VARCHAR(200)    NOT NULL,
    point_type_code     VARCHAR(20)     NOT NULL REFERENCES lu_collection_point_type(point_type_code),

    -- Location
    division_id         INT             REFERENCES division(division_id),
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    -- Capacity
    storage_capacity_kg NUMERIC(10,2),
    has_weighbridge     BOOLEAN         NOT NULL DEFAULT FALSE,
    has_drc_testing     BOOLEAN         NOT NULL DEFAULT FALSE,

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE')),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_collection_point UNIQUE (plantation_id, point_code)
);

CREATE INDEX IF NOT EXISTS idx_coll_point_plantation ON collection_point(plantation_id);
CREATE INDEX IF NOT EXISTS idx_coll_point_gps ON collection_point USING GIST(gps_point);


-- ============================================================================
-- FIX 2: Create latex_collection_record (failed due to missing collection_point)
-- ============================================================================

CREATE TABLE IF NOT EXISTS latex_collection_record (
    collection_id       BIGSERIAL       PRIMARY KEY,

    -- Source
    task_id             BIGINT          REFERENCES tapping_task(task_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),

    -- Collection Details
    collection_date     DATE            NOT NULL,
    collection_time     TIMESTAMPTZ,
    collector_name      VARCHAR(200),

    -- Latex Type & Quantity
    latex_grade_code    VARCHAR(20)     NOT NULL REFERENCES lu_latex_grade(grade_code),
    gross_weight_kg     NUMERIC(10,3)   NOT NULL CHECK (gross_weight_kg > 0),
    container_weight_kg NUMERIC(10,3)   DEFAULT 0,
    net_weight_kg       NUMERIC(10,3)   NOT NULL CHECK (net_weight_kg > 0),
    volume_liters       NUMERIC(10,3),

    -- DRC
    drc_pct             NUMERIC(5,2),
    dry_rubber_kg       NUMERIC(10,3),

    -- Collection Point
    collection_point_id INT             REFERENCES collection_point(collection_point_id),

    -- IoT / Scale
    digital_scale_id    VARCHAR(50),
    auto_weighed        BOOLEAN         DEFAULT FALSE,

    -- Transport
    transport_batch_id  VARCHAR(50),
    transport_vehicle   VARCHAR(50),

    -- Evidence
    photo_url           VARCHAR(1000),

    -- Blockchain provenance
    blockchain_tx_hash  VARCHAR(128),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_collection_task ON latex_collection_record(task_id);
CREATE INDEX IF NOT EXISTS idx_collection_field ON latex_collection_record(field_id);
CREATE INDEX IF NOT EXISTS idx_collection_date ON latex_collection_record(collection_date);
CREATE INDEX IF NOT EXISTS idx_collection_grade ON latex_collection_record(latex_grade_code);
CREATE INDEX IF NOT EXISTS idx_collection_point ON latex_collection_record(collection_point_id);
CREATE INDEX IF NOT EXISTS idx_collection_batch ON latex_collection_record(transport_batch_id);


-- ============================================================================
-- FIX 3: Create latex_quality_test (failed due to missing latex_collection_record)
-- ============================================================================

CREATE TABLE IF NOT EXISTS latex_quality_test (
    test_id             BIGSERIAL       PRIMARY KEY,
    collection_id       BIGINT          NOT NULL REFERENCES latex_collection_record(collection_id),

    parameter_code      VARCHAR(30)     NOT NULL REFERENCES lu_quality_parameter(parameter_code),
    tested_value        NUMERIC(10,4)   NOT NULL,
    unit_of_measure     VARCHAR(30)     NOT NULL,

    is_within_spec      BOOLEAN,
    deviation_pct       NUMERIC(6,2),

    test_date           DATE            NOT NULL,
    test_time           TIME,
    tested_by           VARCHAR(100),
    test_method         VARCHAR(50)     CHECK (test_method IN (
                                            'METROLAC', 'OVEN_DRY', 'HYDROMETER',
                                            'PH_METER', 'TITRATION', 'IOT_SENSOR',
                                            'VISUAL', 'LAB_ANALYSIS'
                                        )),
    test_location       VARCHAR(50)     CHECK (test_location IN (
                                            'FIELD', 'COLLECTION_POINT', 'FACTORY_LAB',
                                            'EXTERNAL_LAB'
                                        )),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quality_collection ON latex_quality_test(collection_id);
CREATE INDEX IF NOT EXISTS idx_quality_param ON latex_quality_test(parameter_code);
CREATE INDEX IF NOT EXISTS idx_quality_date ON latex_quality_test(test_date);
CREATE INDEX IF NOT EXISTS idx_quality_spec ON latex_quality_test(is_within_spec) WHERE is_within_spec = FALSE;


-- ============================================================================
-- FIX 4: Create iot_sensor_reading with COMPOSITE PRIMARY KEY
-- Partition key (reading_timestamp) must be part of the PK.
-- ============================================================================

CREATE TABLE IF NOT EXISTS iot_sensor_reading (
    reading_id          BIGSERIAL       NOT NULL,
    device_id           INT             NOT NULL REFERENCES iot_device(device_id),

    reading_timestamp   TIMESTAMPTZ     NOT NULL,

    -- Weather readings
    temperature_c       NUMERIC(5,1),
    humidity_pct        NUMERIC(5,1),
    rainfall_mm         NUMERIC(6,2),
    wind_speed_kmh      NUMERIC(5,1),

    -- Tapping tool readings
    cut_count           INT,
    avg_cut_angle_deg   NUMERIC(4,1),
    avg_cut_depth_mm    NUMERIC(4,2),
    vibration_score     NUMERIC(4,2),

    -- Collection readings
    weight_kg           NUMERIC(10,3),
    flow_rate_ml_min    NUMERIC(8,2),

    -- Wearable / Location
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    step_count          INT,
    heart_rate_bpm      INT,

    -- Meta
    battery_level_pct   NUMERIC(5,2),
    signal_strength_dbm INT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Composite PK includes partition column (required by PostgreSQL)
    PRIMARY KEY (reading_id, reading_timestamp)

) PARTITION BY RANGE (reading_timestamp);

-- Monthly partitions for 2026
CREATE TABLE iot_sensor_reading_2026_01 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE iot_sensor_reading_2026_02 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE iot_sensor_reading_2026_03 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE iot_sensor_reading_2026_04 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE iot_sensor_reading_2026_05 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE iot_sensor_reading_2026_06 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE iot_sensor_reading_2026_07 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE iot_sensor_reading_2026_08 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE iot_sensor_reading_2026_09 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE iot_sensor_reading_2026_10 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE iot_sensor_reading_2026_11 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE iot_sensor_reading_2026_12 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX idx_sensor_device ON iot_sensor_reading(device_id);
CREATE INDEX idx_sensor_timestamp ON iot_sensor_reading(reading_timestamp);
CREATE INDEX idx_sensor_device_time ON iot_sensor_reading(device_id, reading_timestamp);


-- ============================================================================
-- FIX 5: Recreate triggers that failed due to missing tables
-- ============================================================================

-- Auto-calculate dry_rubber_kg from DRC
CREATE OR REPLACE FUNCTION fn_calc_dry_rubber()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.drc_pct IS NOT NULL AND NEW.net_weight_kg IS NOT NULL THEN
        NEW.dry_rubber_kg := ROUND(NEW.net_weight_kg * NEW.drc_pct / 100, 3);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_dry_rubber
    BEFORE INSERT OR UPDATE OF drc_pct, net_weight_kg ON latex_collection_record
    FOR EACH ROW EXECUTE FUNCTION fn_calc_dry_rubber();

-- Auto-flag out-of-spec quality tests
CREATE OR REPLACE FUNCTION fn_flag_quality_spec()
RETURNS TRIGGER AS $$
DECLARE
    v_min NUMERIC;
    v_max NUMERIC;
BEGIN
    SELECT min_acceptable, max_acceptable INTO v_min, v_max
    FROM lu_quality_parameter
    WHERE parameter_code = NEW.parameter_code;

    IF v_min IS NOT NULL AND v_max IS NOT NULL THEN
        NEW.is_within_spec := (NEW.tested_value BETWEEN v_min AND v_max);
        IF NOT NEW.is_within_spec THEN
            IF NEW.tested_value < v_min THEN
                NEW.deviation_pct := ROUND(((v_min - NEW.tested_value) / v_min) * 100, 2);
            ELSE
                NEW.deviation_pct := ROUND(((NEW.tested_value - v_max) / v_max) * 100, 2);
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_flag_quality_spec
    BEFORE INSERT OR UPDATE ON latex_quality_test
    FOR EACH ROW EXECUTE FUNCTION fn_flag_quality_spec();


-- ============================================================================
-- FIX 6: Grant permissions on the new tables
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tapping_admin') THEN
        GRANT ALL PRIVILEGES ON collection_point, latex_collection_record,
            latex_quality_test, iot_sensor_reading TO tapping_admin;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tapping_manager') THEN
        GRANT SELECT, INSERT, UPDATE ON collection_point, latex_collection_record,
            latex_quality_test, iot_sensor_reading TO tapping_manager;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tapping_reader') THEN
        GRANT SELECT ON collection_point, latex_collection_record,
            latex_quality_test, iot_sensor_reading TO tapping_reader;
    END IF;
END $$;
```

</details>

Expected output after running the fix:

```
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE TABLE
CREATE INDEX (x6)
CREATE TABLE
CREATE INDEX (x4)
CREATE TABLE
CREATE TABLE (x12 partitions)
CREATE INDEX (x3)
CREATE FUNCTION
CREATE TRIGGER
CREATE FUNCTION
CREATE TRIGGER
DO
```

Now continue with M4, M5, M6:

```bash
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/workforce_management_ddl.sql
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/daily_activity_monitoring_ddl.sql
docker exec -it rpms-db psql -U rpms -d rpms -f /tmp/attendance_management_ddl.sql
```

---

## Step 5 — Verify Everything

```bash
docker exec -it rpms-db psql -U rpms -d rpms
```

### Count Tables

```sql
-- Core + lookup tables (expect ~99)
SELECT count(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
```

### Count Views

```sql
-- Expect 25
SELECT count(*) AS total_views
FROM information_schema.views
WHERE table_schema = 'public';
```

### Count Triggers

```sql
-- Expect 30 trigger names (some fire on multiple events)
SELECT count(DISTINCT trigger_name) AS total_triggers
FROM information_schema.triggers
WHERE trigger_schema = 'public';
```

### Verify PostGIS Geometry Columns

```sql
SELECT f_table_name, f_geometry_column, srid, type
FROM geometry_columns
ORDER BY f_table_name;
```

### Verify Lookup Seed Data

```sql
SELECT 'lu_field_category' AS tbl, count(*) FROM lu_field_category
UNION ALL SELECT 'lu_tapping_system', count(*) FROM lu_tapping_system
UNION ALL SELECT 'lu_tree_status', count(*) FROM lu_tree_status
UNION ALL SELECT 'lu_worker_category', count(*) FROM lu_worker_category
UNION ALL SELECT 'lu_attendance_status', count(*) FROM lu_attendance_status
UNION ALL SELECT 'clone_master', count(*) FROM clone_master
ORDER BY tbl;
```

### Verify Partitions

```sql
-- iot_sensor_reading should have 12 monthly partitions
SELECT count(*) AS partition_count
FROM pg_inherits
WHERE inhparent = 'iot_sensor_reading'::regclass;
```

### Verify Extensions

```sql
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('postgis', 'uuid-ossp', 'timescaledb', 'vector');
```

### Test a View

```sql
SELECT * FROM vw_plantation_area_summary LIMIT 5;
```

Type `\q` to exit psql.

---

## Connecting from GUI Tools

You can connect using **pgAdmin**, **DBeaver**, **IntelliJ Database Tool**, or any PostgreSQL client:

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `rpms` |
| Username | `rpms` |
| Password | `rpms123` |

---

## Container Management

```bash
# Stop the container (data preserved in volume)
docker stop rpms-db

# Start it again later
docker start rpms-db

# View logs if something goes wrong
docker logs rpms-db

# Open a bash shell inside the container
docker exec -it rpms-db bash

# Open psql directly
docker exec -it rpms-db psql -U rpms -d rpms
```

### Fresh Start (wipe everything)

```bash
docker stop rpms-db
docker rm rpms-db
docker volume rm rpms-pgdata
```

Then re-run from Step 1.

---

## Running All DDLs in One Command

If you want to set up from scratch in a single pass (after copying all files):

```bash
docker exec -it rpms-db bash -c "
  psql -U rpms -d rpms -c 'CREATE EXTENSION IF NOT EXISTS postgis;' &&
  psql -U rpms -d rpms -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";' &&
  psql -U rpms -d rpms -c 'CREATE EXTENSION IF NOT EXISTS timescaledb;' &&
  psql -U rpms -d rpms -c 'CREATE EXTENSION IF NOT EXISTS vector;' &&
  psql -U rpms -d rpms -f /tmp/plantation_field_records_ddl.sql &&
  psql -U rpms -d rpms -f /tmp/tree_records_tracking_ddl.sql &&
  psql -U rpms -d rpms -f /tmp/tapping_task_monitoring_ddl.sql &&
  psql -U rpms -d rpms -f /tmp/m3-fix.sql &&
  psql -U rpms -d rpms -f /tmp/workforce_management_ddl.sql &&
  psql -U rpms -d rpms -f /tmp/daily_activity_monitoring_ddl.sql &&
  psql -U rpms -d rpms -f /tmp/attendance_management_ddl.sql
"
```

The `&&` ensures each script only runs if the previous one succeeded.

---

## Known Issues in DDL Scripts

### M3: tapping_task_monitoring_ddl.sql (requires m3-fix.sql)

**Bug 1 — Table ordering:** `latex_collection_record` (Section 5) references `collection_point` via foreign key, but `collection_point` (Section 6) is defined after it. This causes `collection_point`, `latex_collection_record`, and `latex_quality_test` to fail to create.

**Fix in original DDL:** Move Section 6 (collection_point) before Section 5 (latex_collection_record).

**Bug 2 — Partitioned table PK:** `iot_sensor_reading` defines `reading_id BIGSERIAL PRIMARY KEY` with `PARTITION BY RANGE (reading_timestamp)`. PostgreSQL requires the partition column to be included in the primary key.

**Fix in original DDL:** Change from:

```sql
CREATE TABLE iot_sensor_reading (
    reading_id          BIGSERIAL       PRIMARY KEY,
    ...
) PARTITION BY RANGE (reading_timestamp);
```

To:

```sql
CREATE TABLE iot_sensor_reading (
    reading_id          BIGSERIAL       NOT NULL,
    ...
    PRIMARY KEY (reading_id, reading_timestamp)
) PARTITION BY RANGE (reading_timestamp);
```

Until the original DDL is fixed, always run `m3-fix.sql` immediately after `tapping_task_monitoring_ddl.sql`.

**Bug 3 — wrong column names in `fn_flag_quality_spec()`:** The fix script's trigger function originally selected `acceptable_min, acceptable_max` from `lu_quality_parameter`, but the actual DDL names those columns `min_acceptable`/`max_acceptable`. Inserting any row into `latex_quality_test` fails with `column "acceptable_min" does not exist` until this is corrected (already fixed in the `m3-fix.sql` above).

---

## Database Summary After Full Setup

```
PostgreSQL:         18 + PostGIS + TimescaleDB + pgvector
Core Tables:        60
Lookup Tables:      39  (pre-seeded with rubber plantation domain data)
Views:              25  (dashboards, analytics, alerts, payroll-ready)
Triggers:           30  (auto-calc, auto-sync, GPS, audit logging)
Partitions:         12  (iot_sensor_reading monthly — 2026)
Geometry Columns:   15+ (Point, LineString, Polygon — SRID 4326)
SRID:               4326 (WGS 84) on all spatial columns
```
