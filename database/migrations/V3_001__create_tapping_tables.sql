-- ============================================================================
-- V3_001 — Module 3 (Tapping Task Monitoring) — CREATE TABLE statements
-- Source: database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
-- Prerequisite: V1 (Module 1 — plantation, division, field, lu_tapping_system)
-- and V2 (Module 2 — tree) must have already run.
--
-- Fixes applied vs. the source DDL (see rpms-design CLAUDE.md / session notes):
--   1. `collection_point` is created BEFORE `latex_collection_record` (the
--      source DDL defines them in the opposite order — Section 5 before
--      Section 6 — even though latex_collection_record.collection_point_id
--      references collection_point. Reordered here so the FK resolves.
--   2. `iot_sensor_reading` is PARTITION BY RANGE (reading_timestamp), but
--      PostgreSQL requires the partition key to be part of the primary key.
--      The source DDL declares PRIMARY KEY (reading_id) alone; fixed here to
--      PRIMARY KEY (reading_id, reading_timestamp).
--   3. fn_calc_dry_rubber() (see V3_004) computed dry_rubber_kg from
--      net_weight_kg BEFORE recalculating net_weight_kg, so it always used
--      a stale/NULL value. Fixed by reordering the two assignments.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Tapping Task Status Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tapping_task_status (
    status_code     VARCHAR(20)     PRIMARY KEY,
    status_name     VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_terminal     BOOLEAN         NOT NULL DEFAULT FALSE,
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.2 Latex Grade / Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_latex_grade (
    grade_code      VARCHAR(20)     PRIMARY KEY,
    grade_name      VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    drc_range_min   NUMERIC(5,2),
    drc_range_max   NUMERIC(5,2),
    price_premium_pct NUMERIC(5,2)  DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.3 Tapping Cancellation / Skip Reason Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tapping_skip_reason (
    reason_code     VARCHAR(30)     PRIMARY KEY,
    reason_name     VARCHAR(200)    NOT NULL,
    reason_category VARCHAR(30)     NOT NULL
                                    CHECK (reason_category IN (
                                        'WEATHER', 'TREE_CONDITION', 'TAPPER',
                                        'OPERATIONAL', 'HOLIDAY', 'OTHER'
                                    )),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.4 Collection Point Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_collection_point_type (
    point_type_code VARCHAR(20)     PRIMARY KEY,
    point_type_name VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.5 Quality Check Parameter Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_quality_parameter (
    parameter_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    unit_of_measure VARCHAR(30)     NOT NULL,
    min_acceptable  NUMERIC(10,2),
    max_acceptable  NUMERIC(10,2),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.6 IoT Device Type Lookup (for tapping-specific devices)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_iot_device_type (
    device_type_code VARCHAR(20)    PRIMARY KEY,
    device_type_name VARCHAR(100)   NOT NULL,
    category        VARCHAR(30)     NOT NULL
                                    CHECK (category IN (
                                        'TAPPING_TOOL', 'WEATHER_SENSOR',
                                        'COLLECTION', 'WEARABLE', 'GEOFENCE'
                                    )),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);


-- ============================================================================
-- SECTION 2: TAPPING SCHEDULE — defines the recurring tapping calendar
-- ============================================================================

CREATE TABLE tapping_schedule (
    schedule_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),

    schedule_name       VARCHAR(100),
    tapping_system_code VARCHAR(20)     NOT NULL REFERENCES lu_tapping_system(tapping_system_code),

    frequency_days      INT             NOT NULL CHECK (frequency_days BETWEEN 1 AND 7),
    tapping_days        VARCHAR(50),

    expected_start_time TIME            NOT NULL DEFAULT '04:30:00',
    expected_end_time   TIME            NOT NULL DEFAULT '09:00:00',

    effective_from      DATE            NOT NULL,
    effective_to        DATE,

    target_trees_per_day INT,
    target_yield_kg_per_day NUMERIC(10,2),

    rain_cutoff_mm      NUMERIC(6,2)    DEFAULT 5.0,
    min_dry_hours       NUMERIC(4,1)    DEFAULT 3.0,

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'COMPLETED')),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),

    CONSTRAINT uq_schedule_field UNIQUE (field_id, effective_from)
);

COMMENT ON TABLE tapping_schedule IS
    'Recurring tapping calendar per field — defines frequency, time windows, targets, and weather policies.';


-- ============================================================================
-- SECTION 3: TAPPING TASK — the daily operational task unit
-- One task = one tapper x one field x one day
-- ============================================================================

CREATE TABLE tapping_task (
    task_id             BIGSERIAL       PRIMARY KEY,

    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    division_id         INT             REFERENCES division(division_id),
    schedule_id         INT             REFERENCES tapping_schedule(schedule_id),

    task_date           DATE            NOT NULL,
    tapper_id           INT,
    tapper_name         VARCHAR(200),
    assigned_by         VARCHAR(100),
    assigned_at         TIMESTAMPTZ,

    tapping_system_code VARCHAR(20)     NOT NULL REFERENCES lu_tapping_system(tapping_system_code),
    panel_code          VARCHAR(20),

    status              VARCHAR(20)     NOT NULL DEFAULT 'SCHEDULED'
                                        REFERENCES lu_tapping_task_status(status_code),

    actual_start_time   TIMESTAMPTZ,
    actual_end_time     TIMESTAMPTZ,
    start_gps_lat       NUMERIC(10,7),
    start_gps_lon       NUMERIC(10,7),
    start_gps_point     GEOMETRY(Point, 4326),
    end_gps_lat         NUMERIC(10,7),
    end_gps_lon         NUMERIC(10,7),

    total_trees_assigned INT            CHECK (total_trees_assigned >= 0),
    trees_tapped        INT             DEFAULT 0 CHECK (trees_tapped >= 0),
    trees_skipped       INT             DEFAULT 0 CHECK (trees_skipped >= 0),
    trees_with_tpd      INT             DEFAULT 0 CHECK (trees_with_tpd >= 0),
    trees_dry_panel     INT             DEFAULT 0 CHECK (trees_dry_panel >= 0),

    total_latex_kg      NUMERIC(10,3)   DEFAULT 0,
    total_cup_lump_kg   NUMERIC(10,3)   DEFAULT 0,
    total_tree_lace_kg  NUMERIC(10,3)   DEFAULT 0,
    total_yield_kg      NUMERIC(10,3)   DEFAULT 0,
    yield_per_tree_g    NUMERIC(10,2),

    avg_drc_pct         NUMERIC(5,2),

    skip_reason_code    VARCHAR(30)     REFERENCES lu_tapping_skip_reason(reason_code),
    skip_remarks        TEXT,

    weather_temp_c      NUMERIC(5,1),
    weather_humidity_pct NUMERIC(5,1),
    weather_rainfall_mm NUMERIC(6,2),
    weather_condition   VARCHAR(30)     CHECK (weather_condition IN (
                                            'CLEAR', 'CLOUDY', 'LIGHT_RAIN',
                                            'HEAVY_RAIN', 'DRIZZLE', 'FOG', 'WINDY'
                                        )),

    smart_knife_device_id VARCHAR(50),
    gps_wearable_id     VARCHAR(50),
    geofence_verified   BOOLEAN         DEFAULT FALSE,

    tapping_quality_score NUMERIC(3,1)  CHECK (tapping_quality_score BETWEEN 0 AND 10),
    cut_angle_deviation_deg NUMERIC(4,1),
    bark_consumption_note VARCHAR(100),

    supervisor_verified BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_by         VARCHAR(100),
    verified_at         TIMESTAMPTZ,

    ai_yield_prediction_kg NUMERIC(10,3),
    ai_quality_flags    TEXT,

    blockchain_tx_hash  VARCHAR(128),

    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

COMMENT ON TABLE tapping_task IS
    'Daily tapping task — one per tapper per field per day. Central operational record '
    'connecting schedule, tapper, field, yield, quality, weather, and IoT data.';


-- ============================================================================
-- SECTION 4: TAPPING TASK TREE DETAIL (optional tree-level granularity)
-- ============================================================================

CREATE TABLE tapping_task_tree_detail (
    detail_id           BIGSERIAL       PRIMARY KEY,
    task_id             BIGINT          NOT NULL REFERENCES tapping_task(task_id),
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    tag_uid             VARCHAR(100),
    scanned_at          TIMESTAMPTZ,

    was_tapped          BOOLEAN         NOT NULL DEFAULT TRUE,
    skip_reason_code    VARCHAR(30)     REFERENCES lu_tapping_skip_reason(reason_code),

    latex_volume_ml     NUMERIC(8,2),
    cup_lump_g          NUMERIC(8,2),

    panel_code          VARCHAR(20),
    cut_length_cm       NUMERIC(6,2),
    cut_depth_mm        NUMERIC(4,2),
    cut_angle_deg       NUMERIC(4,1),
    bark_shaving_mm     NUMERIC(4,2),

    photo_url           VARCHAR(1000),
    ai_cut_quality_score NUMERIC(3,1)   CHECK (ai_cut_quality_score BETWEEN 0 AND 10),
    ai_observations     TEXT,

    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_task_tree UNIQUE (task_id, tree_id)
);

COMMENT ON TABLE tapping_task_tree_detail IS
    'Optional tree-level tapping detail — populated via NFC scanning during tapping. '
    'Captures per-tree yield, cut geometry, panel info, and AI-assessed quality.';


-- ============================================================================
-- SECTION 6 (moved before Section 5): COLLECTION POINT
-- Physical locations where latex is received — created before
-- latex_collection_record because that table FKs into this one.
-- ============================================================================

CREATE TABLE collection_point (
    collection_point_id SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),

    point_code          VARCHAR(30)     NOT NULL,
    point_name          VARCHAR(200)    NOT NULL,
    point_type_code     VARCHAR(20)     NOT NULL REFERENCES lu_collection_point_type(point_type_code),

    division_id         INT             REFERENCES division(division_id),
    gps_latitude        NUMERIC(10,7),
    gps_longitude        NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    storage_capacity_kg NUMERIC(10,2),
    has_weighbridge     BOOLEAN         NOT NULL DEFAULT FALSE,
    has_drc_testing     BOOLEAN         NOT NULL DEFAULT FALSE,

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE')),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_collection_point UNIQUE (plantation_id, point_code)
);

COMMENT ON TABLE collection_point IS
    'Physical latex collection and weighing stations — field stations, roadside tanks, factory gates.';


-- ============================================================================
-- SECTION 5 (moved after Section 6): LATEX COLLECTION RECORD
-- Tracks each physical latex collection from field to collection point
-- ============================================================================

CREATE TABLE latex_collection_record (
    collection_id       BIGSERIAL       PRIMARY KEY,

    task_id             BIGINT          REFERENCES tapping_task(task_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),

    collection_date     DATE            NOT NULL,
    collection_time     TIMESTAMPTZ,
    collector_name      VARCHAR(200),

    latex_grade_code    VARCHAR(20)     NOT NULL REFERENCES lu_latex_grade(grade_code),
    gross_weight_kg     NUMERIC(10,3)   NOT NULL CHECK (gross_weight_kg > 0),
    container_weight_kg NUMERIC(10,3)   DEFAULT 0,
    net_weight_kg       NUMERIC(10,3)   NOT NULL CHECK (net_weight_kg > 0),
    volume_liters       NUMERIC(10,3),

    drc_pct             NUMERIC(5,2),
    dry_rubber_kg       NUMERIC(10,3),

    collection_point_id INT             REFERENCES collection_point(collection_point_id),

    digital_scale_id    VARCHAR(50),
    auto_weighed        BOOLEAN         DEFAULT FALSE,

    transport_batch_id  VARCHAR(50),
    transport_vehicle   VARCHAR(50),

    photo_url           VARCHAR(1000),

    blockchain_tx_hash  VARCHAR(128),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100)
);

COMMENT ON TABLE latex_collection_record IS
    'Physical latex collection records — weights, DRC, grades, and provenance chain from field to collection point.';


-- ============================================================================
-- SECTION 7: LATEX QUALITY TEST
-- ============================================================================

CREATE TABLE latex_quality_test (
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

COMMENT ON TABLE latex_quality_test IS
    'Quality test results for collected latex — DRC, ammonia, pH, VFA, etc. Linked to collection records.';


-- ============================================================================
-- SECTION 8: IoT DEVICE REGISTRY (tapping-specific devices)
-- ============================================================================

CREATE TABLE iot_device (
    device_id           SERIAL          PRIMARY KEY,

    device_uid          VARCHAR(100)    NOT NULL UNIQUE,
    device_name         VARCHAR(200),
    device_type_code    VARCHAR(20)     NOT NULL REFERENCES lu_iot_device_type(device_type_code),

    plantation_id       INT             REFERENCES plantation(plantation_id),
    field_id            INT             REFERENCES field(field_id),
    assigned_tapper_id  INT,

    manufacturer        VARCHAR(100),
    model_number        VARCHAR(100),
    firmware_version    VARCHAR(50),
    serial_number       VARCHAR(100),

    gps_latitude        NUMERIC(10,7),
    gps_longitude        NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE', 'LOST', 'DECOMMISSIONED')),
    battery_level_pct   NUMERIC(5,2),
    last_heartbeat_at   TIMESTAMPTZ,

    installed_date      DATE,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE iot_device IS
    'Registry of all IoT devices used for tapping operations — smart knives, rain gauges, scales, GPS wearables.';


-- ============================================================================
-- SECTION 9: IoT SENSOR READING (telemetry data)
-- FIX: composite PRIMARY KEY (reading_id, reading_timestamp) — PostgreSQL
-- requires the partition column to be part of the primary key on a
-- partitioned table. The source DDL declares PRIMARY KEY (reading_id) alone.
-- ============================================================================

CREATE TABLE iot_sensor_reading (
    reading_id          BIGSERIAL       NOT NULL,
    device_id           INT             NOT NULL REFERENCES iot_device(device_id),

    reading_timestamp   TIMESTAMPTZ     NOT NULL,

    temperature_c       NUMERIC(5,1),
    humidity_pct        NUMERIC(5,1),
    rainfall_mm         NUMERIC(6,2),
    wind_speed_kmh      NUMERIC(5,1),

    cut_count           INT,
    avg_cut_angle_deg   NUMERIC(4,1),
    avg_cut_depth_mm    NUMERIC(4,2),
    vibration_score     NUMERIC(4,2),

    weight_kg           NUMERIC(10,3),
    flow_rate_ml_min    NUMERIC(8,2),

    gps_latitude        NUMERIC(10,7),
    gps_longitude        NUMERIC(10,7),
    step_count          INT,
    heart_rate_bpm      INT,

    battery_level_pct   NUMERIC(5,2),
    signal_strength_dbm INT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    PRIMARY KEY (reading_id, reading_timestamp)
) PARTITION BY RANGE (reading_timestamp);

-- Monthly partitions (create as needed — example for 2026)
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

COMMENT ON TABLE iot_sensor_reading IS
    'High-volume telemetry data from IoT devices — partitioned by month for performance. '
    'Covers weather sensors, smart tapping knives, scales, and GPS wearables.';


-- ============================================================================
-- SECTION 10: WEATHER OBSERVATION (field-level daily weather)
-- ============================================================================

CREATE TABLE weather_observation (
    observation_id      SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             REFERENCES field(field_id),

    observation_date    DATE            NOT NULL,
    observation_time    TIME,

    temperature_min_c   NUMERIC(5,1),
    temperature_max_c   NUMERIC(5,1),
    humidity_min_pct    NUMERIC(5,1),
    humidity_max_pct    NUMERIC(5,1),
    rainfall_mm         NUMERIC(6,2)    DEFAULT 0,
    wind_speed_max_kmh  NUMERIC(5,1),
    weather_condition   VARCHAR(30),

    data_source         VARCHAR(30)     CHECK (data_source IN (
                                            'IOT_SENSOR', 'MANUAL', 'WEATHER_API',
                                            'RAIN_GAUGE', 'WEATHER_STATION'
                                        )),
    iot_device_id       INT             REFERENCES iot_device(device_id),

    suitable_for_tapping BOOLEAN,

    recorded_by         VARCHAR(100),
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_weather_field_date UNIQUE (plantation_id, field_id, observation_date)
);

COMMENT ON TABLE weather_observation IS
    'Daily weather records per field or plantation — used to correlate with yield and tapping decisions.';


-- ============================================================================
-- SECTION 11: TAPPER PERFORMANCE SUMMARY (daily rollup)
-- ============================================================================

CREATE TABLE tapper_performance_daily (
    performance_id      BIGSERIAL       PRIMARY KEY,

    tapper_id           INT             NOT NULL,
    tapper_name         VARCHAR(200),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    performance_date    DATE            NOT NULL,

    tasks_assigned      INT             NOT NULL DEFAULT 0,
    tasks_completed     INT             NOT NULL DEFAULT 0,
    tasks_partial        INT            NOT NULL DEFAULT 0,
    tasks_cancelled     INT             NOT NULL DEFAULT 0,

    total_trees_tapped  INT             NOT NULL DEFAULT 0,
    total_trees_skipped INT             NOT NULL DEFAULT 0,

    total_yield_kg      NUMERIC(10,3)   DEFAULT 0,
    avg_yield_per_tree_g NUMERIC(10,2),

    avg_tapping_quality_score NUMERIC(3,1),
    avg_cut_angle_deviation   NUMERIC(4,1),

    total_tapping_minutes INT,
    avg_trees_per_hour  NUMERIC(6,1),

    reported_on_time    BOOLEAN,
    start_time_actual   TIMESTAMPTZ,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_tapper_daily UNIQUE (tapper_id, performance_date)
);

COMMENT ON TABLE tapper_performance_daily IS
    'Daily roll-up of tapper performance metrics — yield, quality, speed, and attendance.';


-- ============================================================================
-- SECTION 12: FIELD YIELD SUMMARY (daily rollup per field)
-- ============================================================================

CREATE TABLE field_yield_daily (
    yield_id            BIGSERIAL       PRIMARY KEY,

    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    yield_date          DATE            NOT NULL,

    total_tappers       INT             NOT NULL DEFAULT 0,
    total_trees_tapped  INT             NOT NULL DEFAULT 0,
    tappable_trees      INT,

    field_latex_kg      NUMERIC(10,3)   DEFAULT 0,
    cup_lump_kg         NUMERIC(10,3)   DEFAULT 0,
    tree_lace_kg        NUMERIC(10,3)   DEFAULT 0,
    total_wet_yield_kg  NUMERIC(10,3)   DEFAULT 0,

    avg_drc_pct         NUMERIC(5,2),
    total_dry_rubber_kg NUMERIC(10,3),

    yield_per_tree_g    NUMERIC(10,2),
    yield_per_ha_kg     NUMERIC(10,2),

    rainfall_mm         NUMERIC(6,2),
    weather_condition   VARCHAR(30),

    clone_code          VARCHAR(30),
    tree_age_years      INT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_field_yield_date UNIQUE (field_id, yield_date)
);

COMMENT ON TABLE field_yield_daily IS
    'Daily field-level yield summary with clone and weather context for analytics and reporting.';
