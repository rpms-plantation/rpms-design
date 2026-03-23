-- ============================================================================
-- RPMS Module 3 — FIX SCRIPT
-- Fixes two bugs in tapping_task_monitoring_ddl.sql:
--   1. Table ordering: collection_point must be created before latex_collection_record
--   2. iot_sensor_reading PRIMARY KEY must include the partition column
--
-- Run AFTER the original DDL (which partially succeeded).
-- This script creates the missing tables and indexes.
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
division_id INT REFERENCES division (division_id),
gps_latitude NUMERIC(10, 7),
gps_longitude NUMERIC(10, 7),
gps_point GEOMETRY (Point, 4326),

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

CREATE INDEX IF NOT EXISTS idx_coll_point_plantation ON collection_point (plantation_id);

CREATE INDEX IF NOT EXISTS idx_coll_point_gps ON collection_point USING GIST (gps_point);

-- ============================================================================
-- FIX 2: Now create latex_collection_record (was Section 5, failed due to missing collection_point)
-- ============================================================================

CREATE TABLE IF NOT EXISTS latex_collection_record (
    collection_id       BIGSERIAL       PRIMARY KEY,

-- Source
task_id BIGINT REFERENCES tapping_task (task_id),
plantation_id INT NOT NULL REFERENCES plantation (plantation_id),
field_id INT NOT NULL REFERENCES field (field_id),

-- Collection Details
collection_date DATE NOT NULL,
collection_time TIMESTAMPTZ,
collector_name VARCHAR(200),

-- Latex Type & Quantity
latex_grade_code VARCHAR(20) NOT NULL REFERENCES lu_latex_grade (grade_code),
gross_weight_kg NUMERIC(10, 3) NOT NULL CHECK (gross_weight_kg > 0),
container_weight_kg NUMERIC(10, 3) DEFAULT 0,
net_weight_kg NUMERIC(10, 3) NOT NULL CHECK (net_weight_kg > 0),
volume_liters NUMERIC(10, 3),

-- DRC
drc_pct NUMERIC(5, 2),
dry_rubber_kg NUMERIC(10, 3),

-- Collection Point
collection_point_id INT REFERENCES collection_point (collection_point_id),

-- IoT / Scale
digital_scale_id VARCHAR(50),
auto_weighed BOOLEAN DEFAULT FALSE,

-- Transport
transport_batch_id VARCHAR(50), transport_vehicle VARCHAR(50),

-- Evidence
photo_url VARCHAR(1000),

-- Blockchain provenance
blockchain_tx_hash  VARCHAR(128),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_collection_task ON latex_collection_record (task_id);

CREATE INDEX IF NOT EXISTS idx_collection_field ON latex_collection_record (field_id);

CREATE INDEX IF NOT EXISTS idx_collection_date ON latex_collection_record (collection_date);

CREATE INDEX IF NOT EXISTS idx_collection_grade ON latex_collection_record (latex_grade_code);

CREATE INDEX IF NOT EXISTS idx_collection_point ON latex_collection_record (collection_point_id);

CREATE INDEX IF NOT EXISTS idx_collection_batch ON latex_collection_record (transport_batch_id);

-- ============================================================================
-- FIX 3: Now create latex_quality_test (was Section 7, failed due to missing latex_collection_record)
-- ============================================================================

CREATE TABLE IF NOT EXISTS latex_quality_test (
    test_id BIGSERIAL PRIMARY KEY,
    collection_id BIGINT NOT NULL REFERENCES latex_collection_record (collection_id),
    parameter_code VARCHAR(30) NOT NULL REFERENCES lu_quality_parameter (parameter_code),
    tested_value NUMERIC(10, 4) NOT NULL,
    unit_of_measure VARCHAR(30) NOT NULL,
    is_within_spec BOOLEAN,
    deviation_pct NUMERIC(6, 2),
    test_date DATE NOT NULL,
    test_time TIME,
    tested_by VARCHAR(100),
    test_method VARCHAR(50) CHECK (
        test_method IN (
            'METROLAC',
            'OVEN_DRY',
            'HYDROMETER',
            'PH_METER',
            'TITRATION',
            'IOT_SENSOR',
            'VISUAL',
            'LAB_ANALYSIS'
        )
    ),
    test_location VARCHAR(50) CHECK (
        test_location IN (
            'FIELD',
            'COLLECTION_POINT',
            'FACTORY_LAB',
            'EXTERNAL_LAB'
        )
    ),
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_quality_collection ON latex_quality_test (collection_id);

CREATE INDEX IF NOT EXISTS idx_quality_param ON latex_quality_test (parameter_code);

CREATE INDEX IF NOT EXISTS idx_quality_date ON latex_quality_test (test_date);

CREATE INDEX IF NOT EXISTS idx_quality_spec ON latex_quality_test (is_within_spec)
WHERE
    is_within_spec = FALSE;

-- ============================================================================
-- FIX 4: Create iot_sensor_reading with COMPOSITE PRIMARY KEY
-- The partition key (reading_timestamp) must be part of the PK.
-- ============================================================================


CREATE TABLE IF NOT EXISTS iot_sensor_reading (
    reading_id          BIGSERIAL       NOT NULL,
    device_id           INT             NOT NULL REFERENCES iot_device(device_id),
    
    reading_timestamp   TIMESTAMPTZ     NOT NULL,

-- Weather readings
temperature_c NUMERIC(5, 1),
humidity_pct NUMERIC(5, 1),
rainfall_mm NUMERIC(6, 2),
wind_speed_kmh NUMERIC(5, 1),

-- Tapping tool readings
cut_count INT,
avg_cut_angle_deg NUMERIC(4, 1),
avg_cut_depth_mm NUMERIC(4, 2),
vibration_score NUMERIC(4, 2),

-- Collection readings
weight_kg NUMERIC(10, 3),
flow_rate_ml_min NUMERIC(8, 2),

-- Wearable / Location
gps_latitude NUMERIC(10, 7),
gps_longitude NUMERIC(10, 7),
step_count INT,
heart_rate_bpm INT,

-- Meta
battery_level_pct NUMERIC(5, 2),
signal_strength_dbm INT,
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

-- FIXED: Composite PK includes partition column
PRIMARY KEY (reading_id, reading_timestamp)

) PARTITION BY RANGE (reading_timestamp);

-- Monthly partitions for 2026
CREATE TABLE iot_sensor_reading_2026_01 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-01-01') TO ('2026-02-01');

CREATE TABLE iot_sensor_reading_2026_02 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-02-01') TO ('2026-03-01');

CREATE TABLE iot_sensor_reading_2026_03 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE iot_sensor_reading_2026_04 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE iot_sensor_reading_2026_05 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE iot_sensor_reading_2026_06 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE iot_sensor_reading_2026_07 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE iot_sensor_reading_2026_08 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE iot_sensor_reading_2026_09 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-09-01') TO ('2026-10-01');

CREATE TABLE iot_sensor_reading_2026_10 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE iot_sensor_reading_2026_11 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE iot_sensor_reading_2026_12 PARTITION OF iot_sensor_reading FOR
VALUES
FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX idx_sensor_device ON iot_sensor_reading (device_id);

CREATE INDEX idx_sensor_timestamp ON iot_sensor_reading (reading_timestamp);

CREATE INDEX idx_sensor_device_time ON iot_sensor_reading (device_id, reading_timestamp);

-- ============================================================================
-- FIX 5: Recreate triggers that failed due to missing latex_collection_record
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
    SELECT acceptable_min, acceptable_max INTO v_min, v_max
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

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_count INT;
BEGIN
    -- Check all 4 fixed tables exist
    SELECT count(*) INTO v_count 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name IN ('collection_point', 'latex_collection_record', 'latex_quality_test', 'iot_sensor_reading');
    
    IF v_count = 4 THEN
        RAISE NOTICE '✅ All 4 fixed tables created successfully';
    ELSE
        RAISE WARNING '❌ Only % of 4 tables created — check errors above', v_count;
    END IF;

    -- Check triggers
    SELECT count(*) INTO v_count
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
      AND trigger_name IN ('trg_calc_dry_rubber', 'trg_flag_quality_spec');
    
    

    -- Check partition count
    SELECT count(*) INTO v_count
    FROM pg_inherits
    WHERE inhparent = 'iot_sensor_reading'::regclass;
    
    RAISE NOTICE '✅ iot_sensor_reading has % monthly partitions', v_count;
END $$;