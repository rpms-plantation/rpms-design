-- ============================================================================
-- RUBBER PLANTATION MANAGEMENT SYSTEM
-- Module 3: TAPPING TASK MONITORING
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for tapping task assignment, scheduling, execution
--              tracking, latex yield collection, quality grading, IoT-assisted
--              monitoring, weather impact correlation, and performance analytics.
--
-- Dependencies:
--   Module 1 (Plantation Field Records):
--     plantation, division, field, clone_master, lu_tapping_system
--   Module 2 (Tree Records & Tracking):
--     tree, tree_panel_history, tree_tag
-- ============================================================================


-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
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

INSERT INTO lu_tapping_task_status (status_code, status_name, is_terminal, display_order, description) VALUES
    ('SCHEDULED',       'Scheduled',                FALSE,  1,  'Task created and assigned, not yet started'),
    ('IN_PROGRESS',     'In Progress',              FALSE,  2,  'Tapper has started tapping the assigned block'),
    ('COMPLETED',       'Completed',                TRUE,   3,  'All assigned trees tapped, latex collected'),
    ('PARTIAL',         'Partially Completed',      TRUE,   4,  'Some trees tapped — rest skipped due to rain, injury, etc.'),
    ('CANCELLED',       'Cancelled',                TRUE,   5,  'Task cancelled before execution'),
    ('RAIN_STOPPED',    'Stopped by Rain',          TRUE,   6,  'Tapping halted mid-task due to rainfall'),
    ('NO_SHOW',         'Tapper No-Show',           TRUE,   7,  'Assigned tapper did not report for the task'),
    ('REASSIGNED',      'Reassigned',               FALSE,  8,  'Task transferred to a different tapper');

-- ----------------------------------------------------------------------------
-- 1.2 Latex Grade / Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_latex_grade (
    grade_code      VARCHAR(20)     PRIMARY KEY,
    grade_name      VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    drc_range_min   NUMERIC(5,2),   -- Dry Rubber Content minimum %
    drc_range_max   NUMERIC(5,2),   -- Dry Rubber Content maximum %
    price_premium_pct NUMERIC(5,2)  DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_latex_grade (grade_code, grade_name, drc_range_min, drc_range_max, description) VALUES
    ('FIELD_LATEX',     'Field Latex',              28.00,  36.00,  'Fresh latex collected directly from tapping — standard grade'),
    ('HIGH_DRC',        'High DRC Latex',           36.00,  45.00,  'Concentrated or high-quality field latex'),
    ('CUP_LUMP',        'Cup Lump',                 45.00,  55.00,  'Coagulated latex in collection cups'),
    ('TREE_LACE',       'Tree Lace / Bark Scrap',   55.00,  70.00,  'Dried latex strips on bark surface'),
    ('EARTH_SCRAP',     'Earth Scrap',              40.00,  55.00,  'Latex that dripped to ground and coagulated'),
    ('USS',             'Unsmoked Sheet (USS)',      NULL,   NULL,   'Sheet rubber processed from field latex'),
    ('RSS',             'Ribbed Smoked Sheet (RSS)', NULL,   NULL,   'Smoked and graded sheet rubber'),
    ('REJECT',          'Reject / Contaminated',     NULL,   NULL,   'Contaminated or substandard latex');

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

INSERT INTO lu_tapping_skip_reason (reason_code, reason_name, reason_category) VALUES
    ('RAIN_MORNING',    'Morning Rainfall',                     'WEATHER'),
    ('RAIN_DURING',     'Rainfall During Tapping',              'WEATHER'),
    ('HEAVY_WIND',      'Heavy Wind / Storm',                   'WEATHER'),
    ('WET_PANEL',       'Panel Too Wet (Dew / Overnight Rain)', 'WEATHER'),
    ('WINTERING',       'Trees Wintering (Defoliation)',        'TREE_CONDITION'),
    ('TPD_AFFECTED',    'Tapping Panel Dryness',                'TREE_CONDITION'),
    ('BARK_DISEASE',    'Active Bark Disease',                  'TREE_CONDITION'),
    ('REST_DAY',        'Scheduled Rest / Tapping Holiday',     'OPERATIONAL'),
    ('STIMULANT_WAIT',  'Post-Stimulant Waiting Period',        'OPERATIONAL'),
    ('TAPPER_SICK',     'Tapper Sick Leave',                    'TAPPER'),
    ('TAPPER_ABSENT',   'Tapper Absent Without Leave',          'TAPPER'),
    ('TAPPER_INJURY',   'Tapper Injured During Work',           'TAPPER'),
    ('PUBLIC_HOLIDAY',  'Public Holiday',                       'HOLIDAY'),
    ('ESTATE_HOLIDAY',  'Estate / Plantation Holiday',          'HOLIDAY'),
    ('EQUIPMENT_FAIL',  'Equipment Failure',                    'OPERATIONAL'),
    ('OTHER',           'Other Reason',                         'OTHER');

-- ----------------------------------------------------------------------------
-- 1.4 Collection Point Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_collection_point_type (
    point_type_code VARCHAR(20)     PRIMARY KEY,
    point_type_name VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_collection_point_type (point_type_code, point_type_name) VALUES
    ('FIELD_STATION',   'Field Collection Station'),
    ('ROADSIDE_TANK',   'Roadside Bulking Tank'),
    ('DIVISION_CENTER', 'Division Collection Center'),
    ('FACTORY_GATE',    'Factory Receiving Point'),
    ('WEIGHBRIDGE',     'Weighbridge Station');

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

INSERT INTO lu_quality_parameter (parameter_code, parameter_name, unit_of_measure, min_acceptable, max_acceptable) VALUES
    ('DRC',             'Dry Rubber Content',           '%',        28.00,  45.00),
    ('TSC',             'Total Solid Content',          '%',        30.00,  48.00),
    ('NH3',             'Ammonia Content',              '%',        0.20,   0.70),
    ('VFA',             'Volatile Fatty Acid (VFA)',    'mEq',      NULL,   0.05),
    ('MST',             'Mechanical Stability Time',    'seconds',  600,    NULL),
    ('PH',              'pH Level',                     'pH',       6.50,   7.50),
    ('VISCOSITY',       'Mooney Viscosity',             'MU',       NULL,   NULL),
    ('DIRT_CONTENT',    'Dirt Content',                 '%',        NULL,   0.05),
    ('TEMPERATURE',     'Latex Temperature at Collection','°C',    NULL,   35.00),
    ('COLOR',           'Visual Color Assessment',      'grade',    NULL,   NULL);

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

INSERT INTO lu_iot_device_type (device_type_code, device_type_name, category) VALUES
    ('SMART_KNIFE',     'Smart Tapping Knife',          'TAPPING_TOOL'),
    ('RAIN_GAUGE',      'IoT Rain Gauge',               'WEATHER_SENSOR'),
    ('TEMP_HUMIDITY',   'Temperature & Humidity Sensor', 'WEATHER_SENSOR'),
    ('FLOW_METER',      'Latex Flow Meter',              'COLLECTION'),
    ('DIGITAL_SCALE',   'Digital Collection Scale',      'COLLECTION'),
    ('GPS_WEARABLE',    'GPS Wearable Band / Watch',     'WEARABLE'),
    ('BLE_GEOFENCE',    'BLE Geofence Beacon',           'GEOFENCE');


-- ============================================================================
-- SECTION 2: TAPPING SCHEDULE — defines the recurring tapping calendar
-- ============================================================================

CREATE TABLE tapping_schedule (
    schedule_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    
    -- Schedule Definition
    schedule_name       VARCHAR(100),
    tapping_system_code VARCHAR(20)     NOT NULL REFERENCES lu_tapping_system(tapping_system_code),
    
    -- Frequency (derived from tapping system, but explicitly stored for clarity)
    frequency_days      INT             NOT NULL CHECK (frequency_days BETWEEN 1 AND 7),
                                        -- d2=2, d3=3, d4=4
    tapping_days        VARCHAR(50),    -- e.g., 'MON,WED,FRI' or 'TUE,THU,SAT'
    
    -- Time Window
    expected_start_time TIME            NOT NULL DEFAULT '04:30:00',
    expected_end_time   TIME            NOT NULL DEFAULT '09:00:00',
    
    -- Validity
    effective_from      DATE            NOT NULL,
    effective_to        DATE,           -- NULL = ongoing
    
    -- Target
    target_trees_per_day INT,
    target_yield_kg_per_day NUMERIC(10,2),
    
    -- Rain policy
    rain_cutoff_mm      NUMERIC(6,2)    DEFAULT 5.0,   -- Cancel if rain exceeds this
    min_dry_hours       NUMERIC(4,1)    DEFAULT 3.0,   -- Min hours since last rain
    
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'COMPLETED')),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    
    CONSTRAINT uq_schedule_field UNIQUE (field_id, effective_from)
);

CREATE INDEX idx_schedule_plantation ON tapping_schedule(plantation_id);
CREATE INDEX idx_schedule_field ON tapping_schedule(field_id);
CREATE INDEX idx_schedule_status ON tapping_schedule(status);

COMMENT ON TABLE tapping_schedule IS 
    'Recurring tapping calendar per field — defines frequency, time windows, targets, and weather policies.';


-- ============================================================================
-- SECTION 3: TAPPING TASK — the daily operational task unit
-- One task = one tapper × one field × one day
-- ============================================================================

CREATE TABLE tapping_task (
    task_id             BIGSERIAL       PRIMARY KEY,
    
    -- Context
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    division_id         INT             REFERENCES division(division_id),
    schedule_id         INT             REFERENCES tapping_schedule(schedule_id),
    
    -- Assignment
    task_date           DATE            NOT NULL,
    tapper_id           INT,            -- FK to workforce module (Module 4) — nullable until assigned
    tapper_name         VARCHAR(200),   -- Denormalized for quick display
    assigned_by         VARCHAR(100),
    assigned_at         TIMESTAMPTZ,
    
    -- Tapping Configuration
    tapping_system_code VARCHAR(20)     NOT NULL REFERENCES lu_tapping_system(tapping_system_code),
    panel_code          VARCHAR(20),    -- Which panel to tap (e.g., BI-1)
    
    -- Execution Tracking
    status              VARCHAR(20)     NOT NULL DEFAULT 'SCHEDULED'
                                        REFERENCES lu_tapping_task_status(status_code),
    
    actual_start_time   TIMESTAMPTZ,
    actual_end_time     TIMESTAMPTZ,
    start_gps_lat       NUMERIC(10,7),
    start_gps_lon       NUMERIC(10,7),
    start_gps_point     GEOMETRY(Point, 4326),
    end_gps_lat         NUMERIC(10,7),
    end_gps_lon         NUMERIC(10,7),
    
    -- Tree Counts
    total_trees_assigned INT            CHECK (total_trees_assigned >= 0),
    trees_tapped        INT             DEFAULT 0 CHECK (trees_tapped >= 0),
    trees_skipped       INT             DEFAULT 0 CHECK (trees_skipped >= 0),
    trees_with_tpd      INT             DEFAULT 0 CHECK (trees_with_tpd >= 0),
    trees_dry_panel     INT             DEFAULT 0 CHECK (trees_dry_panel >= 0),
    
    -- Yield Summary (aggregated from collection records)
    total_latex_kg      NUMERIC(10,3)   DEFAULT 0,
    total_cup_lump_kg   NUMERIC(10,3)   DEFAULT 0,
    total_tree_lace_kg  NUMERIC(10,3)   DEFAULT 0,
    total_yield_kg      NUMERIC(10,3)   DEFAULT 0,
    yield_per_tree_g    NUMERIC(10,2),  -- Derived: total_yield / trees_tapped * 1000
    
    -- Quality
    avg_drc_pct         NUMERIC(5,2),
    
    -- Skip / Cancellation
    skip_reason_code    VARCHAR(30)     REFERENCES lu_tapping_skip_reason(reason_code),
    skip_remarks        TEXT,
    
    -- Weather at tapping time (from IoT sensors or manual entry)
    weather_temp_c      NUMERIC(5,1),
    weather_humidity_pct NUMERIC(5,1),
    weather_rainfall_mm NUMERIC(6,2),
    weather_condition   VARCHAR(30)     CHECK (weather_condition IN (
                                            'CLEAR', 'CLOUDY', 'LIGHT_RAIN', 
                                            'HEAVY_RAIN', 'DRIZZLE', 'FOG', 'WINDY'
                                        )),
    
    -- IoT Tracking
    smart_knife_device_id VARCHAR(50),  -- Smart tapping knife ID
    gps_wearable_id     VARCHAR(50),    -- GPS band worn by tapper
    geofence_verified   BOOLEAN         DEFAULT FALSE, -- Was tapper confirmed in field?
    
    -- Quality Assessment
    tapping_quality_score NUMERIC(3,1)  CHECK (tapping_quality_score BETWEEN 0 AND 10),
    cut_angle_deviation_deg NUMERIC(4,1), -- Deviation from ideal 30°
    bark_consumption_note VARCHAR(100),
    
    -- Supervisor
    supervisor_verified BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_by         VARCHAR(100),
    verified_at         TIMESTAMPTZ,
    
    -- AI Insights
    ai_yield_prediction_kg NUMERIC(10,3),
    ai_quality_flags    TEXT,           -- AI-generated quality observations
    
    -- Blockchain
    blockchain_tx_hash  VARCHAR(128),
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

CREATE INDEX idx_task_plantation ON tapping_task(plantation_id);
CREATE INDEX idx_task_field ON tapping_task(field_id);
CREATE INDEX idx_task_date ON tapping_task(task_date);
CREATE INDEX idx_task_tapper ON tapping_task(tapper_id) WHERE tapper_id IS NOT NULL;
CREATE INDEX idx_task_status ON tapping_task(status);
CREATE INDEX idx_task_schedule ON tapping_task(schedule_id);
CREATE INDEX idx_task_field_date ON tapping_task(field_id, task_date);
CREATE INDEX idx_task_gps ON tapping_task USING GIST(start_gps_point);
CREATE INDEX idx_task_date_status ON tapping_task(task_date, status);

COMMENT ON TABLE tapping_task IS 
    'Daily tapping task — one per tapper per field per day. Central operational record '
    'connecting schedule, tapper, field, yield, quality, weather, and IoT data.';


-- ============================================================================
-- SECTION 4: TAPPING TASK TREE DETAIL (optional tree-level granularity)
-- For plantations that track tapping at individual tree level via NFC scanning
-- ============================================================================

CREATE TABLE tapping_task_tree_detail (
    detail_id           BIGSERIAL       PRIMARY KEY,
    task_id             BIGINT          NOT NULL REFERENCES tapping_task(task_id),
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    -- NFC Scan
    tag_uid             VARCHAR(100),   -- Tag scanned on this tree
    scanned_at          TIMESTAMPTZ,
    
    -- Tapping Result
    was_tapped          BOOLEAN         NOT NULL DEFAULT TRUE,
    skip_reason_code    VARCHAR(30)     REFERENCES lu_tapping_skip_reason(reason_code),
    
    -- Yield per tree (if measured individually)
    latex_volume_ml     NUMERIC(8,2),
    cup_lump_g          NUMERIC(8,2),
    
    -- Panel / Quality
    panel_code          VARCHAR(20),
    cut_length_cm       NUMERIC(6,2),
    cut_depth_mm        NUMERIC(4,2),
    cut_angle_deg       NUMERIC(4,1),
    bark_shaving_mm     NUMERIC(4,2),   -- Bark consumed per cut
    
    -- AI Assessment
    photo_url           VARCHAR(1000),
    ai_cut_quality_score NUMERIC(3,1)   CHECK (ai_cut_quality_score BETWEEN 0 AND 10),
    ai_observations     TEXT,
    
    -- GPS
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_task_tree UNIQUE (task_id, tree_id)
);

CREATE INDEX idx_task_tree_task ON tapping_task_tree_detail(task_id);
CREATE INDEX idx_task_tree_tree ON tapping_task_tree_detail(tree_id);
CREATE INDEX idx_task_tree_date ON tapping_task_tree_detail(scanned_at);

COMMENT ON TABLE tapping_task_tree_detail IS 
    'Optional tree-level tapping detail — populated via NFC scanning during tapping. '
    'Captures per-tree yield, cut geometry, panel info, and AI-assessed quality.';


-- ============================================================================
-- SECTION 5: LATEX COLLECTION RECORD
-- Tracks each physical latex collection from field to collection point
-- ============================================================================

CREATE TABLE latex_collection_record (
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
    dry_rubber_kg       NUMERIC(10,3),  -- net_weight_kg * drc_pct / 100
    
    -- Collection Point
    collection_point_id INT             REFERENCES collection_point(collection_point_id),
    
    -- IoT / Scale
    digital_scale_id    VARCHAR(50),
    auto_weighed        BOOLEAN         DEFAULT FALSE,
    
    -- Transport
    transport_batch_id  VARCHAR(50),    -- Groups collections going to same destination
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

CREATE INDEX idx_collection_task ON latex_collection_record(task_id);
CREATE INDEX idx_collection_field ON latex_collection_record(field_id);
CREATE INDEX idx_collection_date ON latex_collection_record(collection_date);
CREATE INDEX idx_collection_grade ON latex_collection_record(latex_grade_code);
CREATE INDEX idx_collection_point ON latex_collection_record(collection_point_id);
CREATE INDEX idx_collection_batch ON latex_collection_record(transport_batch_id);

COMMENT ON TABLE latex_collection_record IS 
    'Physical latex collection records — weights, DRC, grades, and provenance chain from field to collection point.';


-- ============================================================================
-- SECTION 6: COLLECTION POINT — physical locations where latex is received
-- ============================================================================

CREATE TABLE collection_point (
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

CREATE INDEX idx_coll_point_plantation ON collection_point(plantation_id);
CREATE INDEX idx_coll_point_gps ON collection_point USING GIST(gps_point);

COMMENT ON TABLE collection_point IS 
    'Physical latex collection and weighing stations — field stations, roadside tanks, factory gates.';


-- ============================================================================
-- SECTION 7: LATEX QUALITY TEST
-- Lab or field quality testing of collected latex
-- ============================================================================

CREATE TABLE latex_quality_test (
    test_id             BIGSERIAL       PRIMARY KEY,
    collection_id       BIGINT          NOT NULL REFERENCES latex_collection_record(collection_id),
    
    parameter_code      VARCHAR(30)     NOT NULL REFERENCES lu_quality_parameter(parameter_code),
    tested_value        NUMERIC(10,4)   NOT NULL,
    unit_of_measure     VARCHAR(30)     NOT NULL,
    
    is_within_spec      BOOLEAN,        -- NULL if no spec defined
    deviation_pct       NUMERIC(6,2),   -- % deviation from acceptable range
    
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

CREATE INDEX idx_quality_collection ON latex_quality_test(collection_id);
CREATE INDEX idx_quality_param ON latex_quality_test(parameter_code);
CREATE INDEX idx_quality_date ON latex_quality_test(test_date);
CREATE INDEX idx_quality_spec ON latex_quality_test(is_within_spec) WHERE is_within_spec = FALSE;

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
    
    -- Assignment
    plantation_id       INT             REFERENCES plantation(plantation_id),
    field_id            INT             REFERENCES field(field_id),
    assigned_tapper_id  INT,            -- FK to workforce module
    
    -- Hardware
    manufacturer        VARCHAR(100),
    model_number        VARCHAR(100),
    firmware_version    VARCHAR(50),
    serial_number       VARCHAR(100),
    
    -- Location
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),
    
    -- Status
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE', 'LOST', 'DECOMMISSIONED')),
    battery_level_pct   NUMERIC(5,2),
    last_heartbeat_at   TIMESTAMPTZ,
    
    installed_date      DATE,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_iot_device_plantation ON iot_device(plantation_id);
CREATE INDEX idx_iot_device_field ON iot_device(field_id);
CREATE INDEX idx_iot_device_type ON iot_device(device_type_code);
CREATE INDEX idx_iot_device_status ON iot_device(status);
CREATE INDEX idx_iot_device_gps ON iot_device USING GIST(gps_point);

COMMENT ON TABLE iot_device IS 
    'Registry of all IoT devices used for tapping operations — smart knives, rain gauges, scales, GPS wearables.';


-- ============================================================================
-- SECTION 9: IoT SENSOR READING (telemetry data)
-- ============================================================================

CREATE TABLE iot_sensor_reading (
    reading_id          BIGSERIAL       PRIMARY KEY,
    device_id           INT             NOT NULL REFERENCES iot_device(device_id),
    
    reading_timestamp   TIMESTAMPTZ     NOT NULL,
    
    -- Weather readings
    temperature_c       NUMERIC(5,1),
    humidity_pct        NUMERIC(5,1),
    rainfall_mm         NUMERIC(6,2),
    wind_speed_kmh      NUMERIC(5,1),
    
    -- Tapping tool readings
    cut_count           INT,                    -- Number of cuts made (smart knife)
    avg_cut_angle_deg   NUMERIC(4,1),
    avg_cut_depth_mm    NUMERIC(4,2),
    vibration_score     NUMERIC(4,2),           -- Tool vibration (technique indicator)
    
    -- Collection readings
    weight_kg           NUMERIC(10,3),          -- Scale reading
    flow_rate_ml_min    NUMERIC(8,2),           -- Latex flow meter
    
    -- Wearable / Location
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    step_count          INT,
    heart_rate_bpm      INT,
    
    -- Meta
    battery_level_pct   NUMERIC(5,2),
    signal_strength_dbm INT,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (reading_timestamp);

-- Monthly partitions (create as needed — example for 2026)
CREATE TABLE iot_sensor_reading_2026_01 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE iot_sensor_reading_2026_02 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE iot_sensor_reading_2026_03 PARTITION OF iot_sensor_reading
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE INDEX idx_sensor_device ON iot_sensor_reading(device_id);
CREATE INDEX idx_sensor_timestamp ON iot_sensor_reading(reading_timestamp);
CREATE INDEX idx_sensor_device_time ON iot_sensor_reading(device_id, reading_timestamp);

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
    
    -- Conditions
    temperature_min_c   NUMERIC(5,1),
    temperature_max_c   NUMERIC(5,1),
    humidity_min_pct    NUMERIC(5,1),
    humidity_max_pct    NUMERIC(5,1),
    rainfall_mm         NUMERIC(6,2)    DEFAULT 0,
    wind_speed_max_kmh  NUMERIC(5,1),
    weather_condition   VARCHAR(30),
    
    -- Source
    data_source         VARCHAR(30)     CHECK (data_source IN (
                                            'IOT_SENSOR', 'MANUAL', 'WEATHER_API', 
                                            'RAIN_GAUGE', 'WEATHER_STATION'
                                        )),
    iot_device_id       INT             REFERENCES iot_device(device_id),
    
    -- Tapping impact
    suitable_for_tapping BOOLEAN,
    
    recorded_by         VARCHAR(100),
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_weather_field_date UNIQUE (plantation_id, field_id, observation_date)
);

CREATE INDEX idx_weather_plantation ON weather_observation(plantation_id);
CREATE INDEX idx_weather_date ON weather_observation(observation_date);
CREATE INDEX idx_weather_field ON weather_observation(field_id);

COMMENT ON TABLE weather_observation IS 
    'Daily weather records per field or plantation — used to correlate with yield and tapping decisions.';


-- ============================================================================
-- SECTION 11: TAPPER PERFORMANCE SUMMARY (daily rollup)
-- ============================================================================

CREATE TABLE tapper_performance_daily (
    performance_id      BIGSERIAL       PRIMARY KEY,
    
    tapper_id           INT             NOT NULL,   -- FK to workforce module
    tapper_name         VARCHAR(200),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    performance_date    DATE            NOT NULL,
    
    -- Task counts
    tasks_assigned      INT             NOT NULL DEFAULT 0,
    tasks_completed     INT             NOT NULL DEFAULT 0,
    tasks_partial       INT             NOT NULL DEFAULT 0,
    tasks_cancelled     INT             NOT NULL DEFAULT 0,
    
    -- Tree counts
    total_trees_tapped  INT             NOT NULL DEFAULT 0,
    total_trees_skipped INT             NOT NULL DEFAULT 0,
    
    -- Yield
    total_yield_kg      NUMERIC(10,3)   DEFAULT 0,
    avg_yield_per_tree_g NUMERIC(10,2),
    
    -- Quality
    avg_tapping_quality_score NUMERIC(3,1),
    avg_cut_angle_deviation   NUMERIC(4,1),
    
    -- Time
    total_tapping_minutes INT,
    avg_trees_per_hour  NUMERIC(6,1),
    
    -- Attendance
    reported_on_time    BOOLEAN,
    start_time_actual   TIMESTAMPTZ,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_tapper_daily UNIQUE (tapper_id, performance_date)
);

CREATE INDEX idx_perf_tapper ON tapper_performance_daily(tapper_id);
CREATE INDEX idx_perf_date ON tapper_performance_daily(performance_date);
CREATE INDEX idx_perf_plantation ON tapper_performance_daily(plantation_id);

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
    
    -- Tapping Activity
    total_tappers       INT             NOT NULL DEFAULT 0,
    total_trees_tapped  INT             NOT NULL DEFAULT 0,
    tappable_trees      INT,            -- For utilization calculation
    
    -- Yield by Type
    field_latex_kg      NUMERIC(10,3)   DEFAULT 0,
    cup_lump_kg         NUMERIC(10,3)   DEFAULT 0,
    tree_lace_kg        NUMERIC(10,3)   DEFAULT 0,
    total_wet_yield_kg  NUMERIC(10,3)   DEFAULT 0,
    
    -- DRC & Dry Rubber
    avg_drc_pct         NUMERIC(5,2),
    total_dry_rubber_kg NUMERIC(10,3),
    
    -- Per-unit metrics
    yield_per_tree_g    NUMERIC(10,2),
    yield_per_ha_kg     NUMERIC(10,2),
    
    -- Weather context
    rainfall_mm         NUMERIC(6,2),
    weather_condition   VARCHAR(30),
    
    -- Clone info (denormalized for analytics)
    clone_code          VARCHAR(30),
    tree_age_years      INT,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_field_yield_date UNIQUE (field_id, yield_date)
);

CREATE INDEX idx_field_yield_plantation ON field_yield_daily(plantation_id);
CREATE INDEX idx_field_yield_field ON field_yield_daily(field_id);
CREATE INDEX idx_field_yield_date ON field_yield_daily(yield_date);
CREATE INDEX idx_field_yield_clone ON field_yield_daily(clone_code);

COMMENT ON TABLE field_yield_daily IS 
    'Daily field-level yield summary with clone and weather context for analytics and reporting.';


-- ============================================================================
-- SECTION 13: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 13.1 Daily Tapping Dashboard View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tapping_dashboard_daily AS
SELECT
    t.task_date,
    p.plantation_code,
    p.plantation_name,
    f.field_code,
    f.field_name,
    cm.clone_code,
    
    ts.status_name          AS task_status,
    t.tapper_name,
    
    t.trees_tapped,
    t.trees_skipped,
    t.total_yield_kg,
    t.yield_per_tree_g,
    t.avg_drc_pct,
    
    t.tapping_quality_score,
    t.weather_condition,
    t.weather_rainfall_mm,
    
    t.geofence_verified,
    t.supervisor_verified,
    
    t.actual_start_time,
    t.actual_end_time,
    EXTRACT(EPOCH FROM (t.actual_end_time - t.actual_start_time))/60 AS duration_minutes,
    
    sr.reason_name          AS skip_reason

FROM tapping_task t
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN field f ON f.field_id = t.field_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
JOIN lu_tapping_task_status ts ON ts.status_code = t.status
LEFT JOIN lu_tapping_skip_reason sr ON sr.reason_code = t.skip_reason_code
ORDER BY t.task_date DESC, p.plantation_code, f.field_code;


-- ----------------------------------------------------------------------------
-- 13.2 Tapper Performance Ranking View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tapper_performance_ranking AS
SELECT
    tp.tapper_id,
    tp.tapper_name,
    p.plantation_code,
    
    COUNT(tp.performance_id)                    AS total_days_worked,
    SUM(tp.total_trees_tapped)                  AS total_trees_tapped,
    ROUND(AVG(tp.total_trees_tapped), 0)        AS avg_trees_per_day,
    
    ROUND(SUM(tp.total_yield_kg), 2)            AS total_yield_kg,
    ROUND(AVG(tp.avg_yield_per_tree_g), 2)      AS avg_yield_per_tree_g,
    
    ROUND(AVG(tp.avg_tapping_quality_score), 1)  AS avg_quality_score,
    ROUND(AVG(tp.avg_cut_angle_deviation), 1)    AS avg_angle_deviation,
    ROUND(AVG(tp.avg_trees_per_hour), 1)         AS avg_trees_per_hour,
    
    COUNT(*) FILTER (WHERE tp.reported_on_time = TRUE) AS on_time_days,
    ROUND(COUNT(*) FILTER (WHERE tp.reported_on_time = TRUE) * 100.0 / 
          NULLIF(COUNT(*), 0), 1) AS on_time_pct

FROM tapper_performance_daily tp
JOIN plantation p ON p.plantation_id = tp.plantation_id
GROUP BY tp.tapper_id, tp.tapper_name, p.plantation_code
ORDER BY total_yield_kg DESC;


-- ----------------------------------------------------------------------------
-- 13.3 Clone-wise Yield Analysis View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_clone_yield_analysis AS
SELECT
    fy.clone_code,
    p.plantation_code,
    fy.tree_age_years,
    
    COUNT(DISTINCT fy.field_id)                 AS fields_tapped,
    COUNT(fy.yield_id)                          AS tapping_days,
    
    ROUND(AVG(fy.total_wet_yield_kg), 2)        AS avg_daily_wet_yield_kg,
    ROUND(AVG(fy.total_dry_rubber_kg), 2)       AS avg_daily_dry_rubber_kg,
    ROUND(AVG(fy.yield_per_tree_g), 2)          AS avg_yield_per_tree_g,
    ROUND(AVG(fy.yield_per_ha_kg), 2)           AS avg_yield_per_ha_kg,
    ROUND(AVG(fy.avg_drc_pct), 2)               AS avg_drc_pct,
    
    ROUND(AVG(fy.rainfall_mm), 1)               AS avg_rainfall_mm,
    
    ROUND(CORR(fy.rainfall_mm, fy.total_wet_yield_kg)::NUMERIC, 3) 
                                                 AS rainfall_yield_correlation

FROM field_yield_daily fy
JOIN plantation p ON p.plantation_id = fy.plantation_id
WHERE fy.clone_code IS NOT NULL
GROUP BY fy.clone_code, p.plantation_code, fy.tree_age_years
ORDER BY avg_yield_per_tree_g DESC;


-- ----------------------------------------------------------------------------
-- 13.4 Weather Impact on Yield View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_weather_yield_correlation AS
SELECT
    wo.observation_date,
    p.plantation_code,
    f.field_code,
    
    wo.rainfall_mm,
    wo.temperature_max_c,
    wo.humidity_max_pct,
    wo.weather_condition,
    wo.suitable_for_tapping,
    
    fy.total_tappers,
    fy.total_trees_tapped,
    fy.total_wet_yield_kg,
    fy.total_dry_rubber_kg,
    fy.yield_per_tree_g,
    
    CASE 
        WHEN wo.rainfall_mm > 10 THEN 'Heavy Rain'
        WHEN wo.rainfall_mm > 5  THEN 'Moderate Rain'
        WHEN wo.rainfall_mm > 0  THEN 'Light Rain'
        ELSE 'Dry'
    END AS rain_category

FROM weather_observation wo
JOIN plantation p ON p.plantation_id = wo.plantation_id
LEFT JOIN field f ON f.field_id = wo.field_id
LEFT JOIN field_yield_daily fy 
    ON fy.field_id = wo.field_id AND fy.yield_date = wo.observation_date
ORDER BY wo.observation_date DESC;


-- ============================================================================
-- SECTION 14: TRIGGER FUNCTIONS
-- ============================================================================

-- 14.1 Auto-update timestamps
CREATE TRIGGER trg_tapping_schedule_updated
    BEFORE UPDATE ON tapping_schedule
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_tapping_task_updated
    BEFORE UPDATE ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_collection_updated
    BEFORE UPDATE ON latex_collection_record
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_collection_point_updated
    BEFORE UPDATE ON collection_point
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_iot_device_updated
    BEFORE UPDATE ON iot_device
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- 14.2 Auto-populate GPS point on tapping task
CREATE OR REPLACE FUNCTION fn_task_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_gps_lat IS NOT NULL AND NEW.start_gps_lon IS NOT NULL THEN
        NEW.start_gps_point = ST_SetSRID(ST_MakePoint(NEW.start_gps_lon, NEW.start_gps_lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_task_gps_sync
    BEFORE INSERT OR UPDATE OF start_gps_lat, start_gps_lon ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_task_sync_gps_point();

-- 14.3 Auto-populate GPS point on collection point
CREATE OR REPLACE FUNCTION fn_coll_point_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_coll_point_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON collection_point
    FOR EACH ROW EXECUTE FUNCTION fn_coll_point_sync_gps();

-- 14.4 Auto-calculate yield_per_tree and dry_rubber on task completion
CREATE OR REPLACE FUNCTION fn_calc_task_yield_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('COMPLETED', 'PARTIAL') AND NEW.trees_tapped > 0 THEN
        NEW.total_yield_kg = COALESCE(NEW.total_latex_kg, 0) 
                           + COALESCE(NEW.total_cup_lump_kg, 0) 
                           + COALESCE(NEW.total_tree_lace_kg, 0);
        NEW.yield_per_tree_g = ROUND((NEW.total_yield_kg / NEW.trees_tapped) * 1000, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_task_yield
    BEFORE INSERT OR UPDATE OF total_latex_kg, total_cup_lump_kg, total_tree_lace_kg, trees_tapped ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_calc_task_yield_metrics();

-- 14.5 Auto-calculate dry rubber on collection record
CREATE OR REPLACE FUNCTION fn_calc_dry_rubber()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.drc_pct IS NOT NULL AND NEW.net_weight_kg IS NOT NULL THEN
        NEW.dry_rubber_kg = ROUND(NEW.net_weight_kg * NEW.drc_pct / 100, 3);
    END IF;
    NEW.net_weight_kg = COALESCE(NEW.gross_weight_kg, 0) - COALESCE(NEW.container_weight_kg, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_dry_rubber
    BEFORE INSERT OR UPDATE OF gross_weight_kg, container_weight_kg, drc_pct ON latex_collection_record
    FOR EACH ROW EXECUTE FUNCTION fn_calc_dry_rubber();

-- 14.6 Auto-flag quality test out-of-spec
CREATE OR REPLACE FUNCTION fn_check_quality_spec()
RETURNS TRIGGER AS $$
DECLARE
    v_min NUMERIC;
    v_max NUMERIC;
BEGIN
    SELECT min_acceptable, max_acceptable 
    INTO v_min, v_max
    FROM lu_quality_parameter 
    WHERE parameter_code = NEW.parameter_code;
    
    IF v_min IS NOT NULL AND v_max IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value >= v_min AND NEW.tested_value <= v_max);
        IF NOT NEW.is_within_spec THEN
            IF NEW.tested_value < v_min THEN
                NEW.deviation_pct = ROUND(((v_min - NEW.tested_value) / v_min) * 100, 2);
            ELSE
                NEW.deviation_pct = ROUND(((NEW.tested_value - v_max) / v_max) * 100, 2);
            END IF;
        ELSE
            NEW.deviation_pct = 0;
        END IF;
    ELSIF v_min IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value >= v_min);
    ELSIF v_max IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value <= v_max);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_quality_spec
    BEFORE INSERT OR UPDATE OF tested_value ON latex_quality_test
    FOR EACH ROW EXECUTE FUNCTION fn_check_quality_spec();


-- ============================================================================
-- SECTION 15: PERMISSIONS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON tapping_schedule, tapping_task, tapping_task_tree_detail,
    latex_collection_record, collection_point, latex_quality_test, iot_device,
    iot_sensor_reading, weather_observation, tapper_performance_daily, 
    field_yield_daily TO plantation_manager;

GRANT SELECT ON lu_tapping_task_status, lu_latex_grade, lu_tapping_skip_reason,
    lu_collection_point_type, lu_quality_parameter, lu_iot_device_type TO plantation_manager;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;


-- ============================================================================
-- END OF MODULE 3: TAPPING TASK MONITORING
-- ============================================================================
