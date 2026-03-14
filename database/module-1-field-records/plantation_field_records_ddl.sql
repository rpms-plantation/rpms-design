-- ============================================================================
-- PLANTATION FIELD RECORDS MANAGEMENT SYSTEM
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for managing plantation land records, nurseries,
--              immature/mature fields, clone distribution, and spatial data.
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;           -- Spatial/GIS support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- UUID generation

-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Measurement Unit Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_measurement_unit (
    unit_code       VARCHAR(10)     PRIMARY KEY,
    unit_name       VARCHAR(50)     NOT NULL,
    description     VARCHAR(200),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_measurement_unit (unit_code, unit_name, description) VALUES
    ('HA', 'Hectare', 'Used for large plantations'),
    ('AC', 'Acre',    'Used for small plantations');

-- ----------------------------------------------------------------------------
-- 1.2 Land Use Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_land_use_type (
    land_use_code   VARCHAR(20)     PRIMARY KEY,
    land_use_name   VARCHAR(100)    NOT NULL,
    parent_code     VARCHAR(20)     REFERENCES lu_land_use_type(land_use_code),
    display_order   INT             NOT NULL DEFAULT 0,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_land_use_type (land_use_code, land_use_name, parent_code, display_order, description) VALUES
    ('PLANTED',         'Total Planted Area',               NULL,           1,  'All areas with rubber plants'),
    ('BUILDING',        'Building & Infrastructure Area',   NULL,           2,  'Buildings, factories, offices, housing'),
    ('ROAD',            'Roads Surface Area',               NULL,           3,  'Internal and access roads'),
    ('SWAP',            'Swap Area',                        NULL,           4,  'Swamp/marshy land'),
    ('ROCKY',           'Rocky Area',                       NULL,           5,  'Rocky/stony unusable land'),
    ('UNCULTIVATED',    'Uncultivated Area',                NULL,           6,  'Uncultivated but potentially usable'),
    ('HVC',             'High Value Conservation Area',     NULL,           7,  'Forested and conservation zones'),
    ('WATER',           'Water Bodies',                     NULL,           8,  'Rivers, lakes, ponds, reservoirs'),
    ('MISC',            'Miscellaneous Area',               NULL,           9,  'Other unclassified areas'),
    -- Sub-types for Planted Area
    ('NURSERY',         'Nursery Area',                     'PLANTED',      10, 'Nursery sections'),
    ('IMMATURE',        'Immature / Young Area',            'PLANTED',      11, 'Planted but not yet tapping'),
    ('MATURE',          'Mature Area (Under Tapping)',      'PLANTED',      12, 'Actively producing rubber');

-- ----------------------------------------------------------------------------
-- 1.3 Nursery Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_nursery_type (
    nursery_type_code   VARCHAR(20)     PRIMARY KEY,
    nursery_type_name   VARCHAR(100)    NOT NULL,
    allows_multiple     BOOLEAN         NOT NULL DEFAULT TRUE,
    description         VARCHAR(500),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_nursery_type (nursery_type_code, nursery_type_name, allows_multiple, description) VALUES
    ('MOTHERBUD',   'Motherbud Wood Garden',    FALSE,  'One per plantation - source of bud wood'),
    ('POLYBAG',     'Polybag Nursery',          TRUE,   'Polybag-raised seedlings/buddings'),
    ('GROUND',      'Ground Nursery',           TRUE,   'Direct ground-planted nursery');

-- ----------------------------------------------------------------------------
-- 1.4 Field Category Lookup (for Immature sub-classification)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_field_category (
    category_code   VARCHAR(20)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_field_category (category_code, category_name, description) VALUES
    ('NEW_CLEARING', 'New Clearing',  'Freshly cleared land planted for the first time'),
    ('REPLANTING',   'Replanting',    'Previously mature area replanted with new trees'),
    ('MATURE',       'Mature',        'Trees under active tapping');

-- ----------------------------------------------------------------------------
-- 1.5 Clone Master
-- ----------------------------------------------------------------------------
CREATE TABLE clone_master (
    clone_id        SERIAL          PRIMARY KEY,
    clone_code      VARCHAR(30)     NOT NULL UNIQUE,
    clone_name      VARCHAR(100)    NOT NULL,
    clone_class     VARCHAR(10)     CHECK (clone_class IN ('I', 'II', 'III')),
    parentage       VARCHAR(200),
    origin_country  VARCHAR(100),
    recommended_region VARCHAR(200),
    avg_yield_kg_per_ha NUMERIC(10,2),
    wind_resistance VARCHAR(20)     CHECK (wind_resistance IN ('HIGH', 'MEDIUM', 'LOW')),
    disease_resistance VARCHAR(500),
    remarks         TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE clone_master IS 'Master list of rubber clones (e.g., RRIM 600, PB 260, RRIC 121)';

-- ----------------------------------------------------------------------------
-- 1.6 Tapping System Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tapping_system (
    tapping_system_code VARCHAR(20)     PRIMARY KEY,
    tapping_system_name VARCHAR(100)    NOT NULL,
    description         VARCHAR(500),
    frequency_notation  VARCHAR(50),    -- e.g., S/2 d3, S/2 d4
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_tapping_system (tapping_system_code, tapping_system_name, frequency_notation) VALUES
    ('S2D2',  'Half Spiral - Alternate Day',     'S/2 d2'),
    ('S2D3',  'Half Spiral - Third Daily',        'S/2 d3'),
    ('S2D4',  'Half Spiral - Fourth Daily',       'S/2 d4'),
    ('S4D2',  'Quarter Spiral - Alternate Day',   'S/4 d2');


-- ============================================================================
-- SECTION 2: PLANTATION (ESTATE) MASTER
-- ============================================================================

CREATE TABLE plantation (
    plantation_id       SERIAL          PRIMARY KEY,
    plantation_code     VARCHAR(20)     NOT NULL UNIQUE,
    plantation_name     VARCHAR(200)    NOT NULL,
    
    -- Location & Classification
    region              VARCHAR(100),
    district            VARCHAR(100),
    state_province      VARCHAR(100),
    country             VARCHAR(100)    NOT NULL,
    elevation_m         NUMERIC(8,2),
    avg_annual_rainfall_mm NUMERIC(8,2),
    soil_type           VARCHAR(100),
    
    -- Area Summary
    total_surface_area      NUMERIC(12,4)   NOT NULL,
    measurement_unit        VARCHAR(10)     NOT NULL REFERENCES lu_measurement_unit(unit_code),
    
    -- GPS / Spatial
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),          -- Single reference point
    boundary_polygon    GEOMETRY(Polygon, 4326),         -- Plantation boundary
    
    -- Administrative
    establishment_date  DATE,
    ownership_type      VARCHAR(50)     CHECK (ownership_type IN ('PRIVATE', 'STATE', 'COOPERATIVE', 'JOINT_VENTURE')),
    owner_name          VARCHAR(200),
    manager_name        VARCHAR(200),
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE' 
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'DECOMMISSIONED')),
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

CREATE INDEX idx_plantation_region ON plantation(region, district);
CREATE INDEX idx_plantation_status ON plantation(status);
CREATE INDEX idx_plantation_gps ON plantation USING GIST(gps_point);
CREATE INDEX idx_plantation_boundary ON plantation USING GIST(boundary_polygon);

COMMENT ON TABLE plantation IS 'Master record for each plantation/estate';


-- ============================================================================
-- SECTION 3: LAND USE BREAKDOWN
-- Stores the area allocation for each non-planted land use type
-- ============================================================================

CREATE TABLE plantation_land_use (
    land_use_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    land_use_code       VARCHAR(20)     NOT NULL REFERENCES lu_land_use_type(land_use_code),
    area_value          NUMERIC(12,4)   NOT NULL CHECK (area_value >= 0),
    measurement_unit    VARCHAR(10)     NOT NULL REFERENCES lu_measurement_unit(unit_code),
    effective_date      DATE            NOT NULL DEFAULT CURRENT_DATE,
    remarks             TEXT,
    
    -- Spatial (optional polygon for each zone)
    zone_boundary       GEOMETRY(MultiPolygon, 4326),
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),
    
    CONSTRAINT uq_land_use_per_plantation UNIQUE (plantation_id, land_use_code, effective_date)
);

CREATE INDEX idx_land_use_plantation ON plantation_land_use(plantation_id);

COMMENT ON TABLE plantation_land_use IS 
    'Breakdown of total surface area into land use categories (building, roads, swap, rocky, HVC, water, misc, etc.)';


-- ============================================================================
-- SECTION 4: DIVISION / BLOCK STRUCTURE
-- Plantations are divided into Divisions, which contain Fields/Blocks
-- ============================================================================

CREATE TABLE division (
    division_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_code       VARCHAR(20)     NOT NULL,
    division_name       VARCHAR(100)    NOT NULL,
    area_ha             NUMERIC(12,4),
    manager_name        VARCHAR(200),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_division_code UNIQUE (plantation_id, division_code)
);

COMMENT ON TABLE division IS 'Divisions within a plantation (optional organizational level)';


-- ============================================================================
-- SECTION 5: FIELD / BLOCK — The core operational unit
-- Each field has a single clone, planting date, and transitions through
-- lifecycle stages: IMMATURE (new clearing / replanting) → MATURE
-- ============================================================================

CREATE TABLE field (
    field_id            SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    
    field_code          VARCHAR(30)     NOT NULL,
    field_name          VARCHAR(100),
    
    -- Area
    area_ha             NUMERIC(12,4)   NOT NULL CHECK (area_ha > 0),
    measurement_unit    VARCHAR(10)     NOT NULL REFERENCES lu_measurement_unit(unit_code),
    
    -- Clone & Planting
    clone_id            INT             NOT NULL REFERENCES clone_master(clone_id),
    number_of_plants    INT             NOT NULL CHECK (number_of_plants > 0),
    original_stand_per_ha INT,           -- Trees per hectare at planting
    current_stand_per_ha  INT,           -- Current surviving trees per hectare
    
    planting_month      INT             CHECK (planting_month BETWEEN 1 AND 12),
    planting_year       INT             NOT NULL CHECK (planting_year BETWEEN 1900 AND 2100),
    
    -- Lifecycle / Category
    field_category      VARCHAR(20)     NOT NULL REFERENCES lu_field_category(category_code),
                                        -- 'NEW_CLEARING', 'REPLANTING', 'MATURE'
    
    -- Maturity / Tapping Info (populated when field becomes MATURE)
    tapping_start_month INT             CHECK (tapping_start_month BETWEEN 1 AND 12),
    tapping_start_year  INT             CHECK (tapping_start_year BETWEEN 1900 AND 2100),
    tapping_system_code VARCHAR(20)     REFERENCES lu_tapping_system(tapping_system_code),
    current_tapping_panel VARCHAR(20),   -- e.g., BI-1, BO-1, HI-1
    
    -- Spatial
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    field_boundary      GEOMETRY(Polygon, 4326),
    
    -- Status
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'FALLOW', 'DECOMMISSIONED')),
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),
    
    CONSTRAINT uq_field_code UNIQUE (plantation_id, field_code),
    CONSTRAINT chk_tapping_after_planting CHECK (
        tapping_start_year IS NULL 
        OR tapping_start_year > planting_year 
        OR (tapping_start_year = planting_year AND tapping_start_month >= planting_month)
    )
);

CREATE INDEX idx_field_plantation ON field(plantation_id);
CREATE INDEX idx_field_category ON field(field_category);
CREATE INDEX idx_field_clone ON field(clone_id);
CREATE INDEX idx_field_planting ON field(planting_year, planting_month);
CREATE INDEX idx_field_boundary ON field USING GIST(field_boundary);
CREATE INDEX idx_field_status ON field(status);

COMMENT ON TABLE field IS 
    'Core operational unit - each field/block represents a contiguous planted area with a single clone and planting year.';


-- ============================================================================
-- SECTION 6: FIELD LIFECYCLE HISTORY
-- Tracks transitions: IMMATURE → MATURE, Replanting events, etc.
-- ============================================================================

CREATE TABLE field_lifecycle_history (
    history_id          SERIAL          PRIMARY KEY,
    field_id            INT             NOT NULL REFERENCES field(field_id),
    
    event_type          VARCHAR(30)     NOT NULL 
                                        CHECK (event_type IN (
                                            'PLANTED', 'OPENED_FOR_TAPPING', 
                                            'PANEL_CHANGE', 'SYSTEM_CHANGE',
                                            'FALLOW', 'REPLANTING_STARTED',
                                            'DECOMMISSIONED'
                                        )),
    event_date          DATE            NOT NULL,
    from_category       VARCHAR(20)     REFERENCES lu_field_category(category_code),
    to_category         VARCHAR(20)     REFERENCES lu_field_category(category_code),
    
    old_tapping_system  VARCHAR(20)     REFERENCES lu_tapping_system(tapping_system_code),
    new_tapping_system  VARCHAR(20)     REFERENCES lu_tapping_system(tapping_system_code),
    old_panel           VARCHAR(20),
    new_panel           VARCHAR(20),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100)
);

CREATE INDEX idx_lifecycle_field ON field_lifecycle_history(field_id);
CREATE INDEX idx_lifecycle_event_date ON field_lifecycle_history(event_date);

COMMENT ON TABLE field_lifecycle_history IS 'Audit trail of all field status transitions and tapping changes';


-- ============================================================================
-- SECTION 7: NURSERY
-- ============================================================================

CREATE TABLE nursery (
    nursery_id          SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    
    nursery_code        VARCHAR(30)     NOT NULL,
    nursery_name        VARCHAR(100),
    nursery_type_code   VARCHAR(20)     NOT NULL REFERENCES lu_nursery_type(nursery_type_code),
    
    area_ha             NUMERIC(12,4)   CHECK (area_ha >= 0),
    capacity_plants     INT,            -- Maximum plant capacity
    
    establishment_date  DATE,
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'CLOSED')),
    
    -- Spatial
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    nursery_boundary    GEOMETRY(Polygon, 4326),
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),
    
    CONSTRAINT uq_nursery_code UNIQUE (plantation_id, nursery_code)
);

CREATE INDEX idx_nursery_plantation ON nursery(plantation_id);
CREATE INDEX idx_nursery_type ON nursery(nursery_type_code);

COMMENT ON TABLE nursery IS 'Nursery units within a plantation (motherbud, polybag, ground)';


-- ============================================================================
-- SECTION 8: NURSERY CLONE DISTRIBUTION
-- Tracks clone-wise plant counts within each nursery
-- ============================================================================

CREATE TABLE nursery_clone_distribution (
    distribution_id     SERIAL          PRIMARY KEY,
    nursery_id          INT             NOT NULL REFERENCES nursery(nursery_id),
    clone_id            INT             NOT NULL REFERENCES clone_master(clone_id),
    
    number_of_plants    INT             NOT NULL CHECK (number_of_plants >= 0),
    rootstock_clone_id  INT             REFERENCES clone_master(clone_id),  -- For budded plants
    
    record_date         DATE            NOT NULL DEFAULT CURRENT_DATE,
    survival_rate_pct   NUMERIC(5,2)    CHECK (survival_rate_pct BETWEEN 0 AND 100),
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_nursery_clone_date UNIQUE (nursery_id, clone_id, record_date)
);

CREATE INDEX idx_nursery_clone_nursery ON nursery_clone_distribution(nursery_id);
CREATE INDEX idx_nursery_clone_clone ON nursery_clone_distribution(clone_id);

COMMENT ON TABLE nursery_clone_distribution IS 'Clone-wise distribution of plants in each nursery';


-- ============================================================================
-- SECTION 9: ANNUAL AREA SNAPSHOT
-- Captures a point-in-time snapshot of all area allocations for reporting
-- ============================================================================

CREATE TABLE annual_area_snapshot (
    snapshot_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    snapshot_year       INT             NOT NULL,
    snapshot_date       DATE            NOT NULL,
    
    total_surface_area          NUMERIC(12,4)   NOT NULL,
    total_planted_area          NUMERIC(12,4),
    total_building_infra_area   NUMERIC(12,4),
    total_road_area             NUMERIC(12,4),
    total_swap_area             NUMERIC(12,4),
    total_rocky_area            NUMERIC(12,4),
    total_uncultivated_area     NUMERIC(12,4),
    total_hvc_area              NUMERIC(12,4),
    total_water_bodies_area     NUMERIC(12,4),
    total_misc_area             NUMERIC(12,4),
    
    -- Planted area breakdown
    total_nursery_area          NUMERIC(12,4),
    total_immature_area         NUMERIC(12,4),
    total_mature_area           NUMERIC(12,4),
    
    measurement_unit    VARCHAR(10)     NOT NULL REFERENCES lu_measurement_unit(unit_code),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    
    CONSTRAINT uq_snapshot_year UNIQUE (plantation_id, snapshot_year)
);

CREATE INDEX idx_snapshot_plantation ON annual_area_snapshot(plantation_id);

COMMENT ON TABLE annual_area_snapshot IS 
    'Yearly snapshot of area breakdown for historical reporting and compliance';


-- ============================================================================
-- SECTION 10: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 10.1 Plantation Area Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_plantation_area_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    p.plantation_name,
    p.total_surface_area,
    p.measurement_unit,
    
    -- Planted area from fields
    COALESCE(SUM(CASE WHEN f.field_category = 'MATURE' THEN f.area_ha END), 0) AS mature_area,
    COALESCE(SUM(CASE WHEN f.field_category IN ('NEW_CLEARING', 'REPLANTING') THEN f.area_ha END), 0) AS immature_area,
    COALESCE(SUM(f.area_ha), 0) AS total_field_area,
    
    -- Nursery area
    COALESCE(n.total_nursery_area, 0) AS total_nursery_area,
    
    -- Non-planted areas
    COALESCE(lu.building_area, 0)       AS building_infra_area,
    COALESCE(lu.road_area, 0)           AS road_area,
    COALESCE(lu.swap_area, 0)           AS swap_area,
    COALESCE(lu.rocky_area, 0)          AS rocky_area,
    COALESCE(lu.uncultivated_area, 0)   AS uncultivated_area,
    COALESCE(lu.hvc_area, 0)            AS hvc_conservation_area,
    COALESCE(lu.water_area, 0)          AS water_bodies_area,
    COALESCE(lu.misc_area, 0)           AS miscellaneous_area
    
FROM plantation p

LEFT JOIN field f ON f.plantation_id = p.plantation_id AND f.status = 'ACTIVE'

LEFT JOIN (
    SELECT plantation_id, COALESCE(SUM(area_ha), 0) AS total_nursery_area
    FROM nursery WHERE status = 'ACTIVE'
    GROUP BY plantation_id
) n ON n.plantation_id = p.plantation_id

LEFT JOIN (
    SELECT
        plantation_id,
        SUM(CASE WHEN land_use_code = 'BUILDING'       THEN area_value END) AS building_area,
        SUM(CASE WHEN land_use_code = 'ROAD'            THEN area_value END) AS road_area,
        SUM(CASE WHEN land_use_code = 'SWAP'            THEN area_value END) AS swap_area,
        SUM(CASE WHEN land_use_code = 'ROCKY'           THEN area_value END) AS rocky_area,
        SUM(CASE WHEN land_use_code = 'UNCULTIVATED'    THEN area_value END) AS uncultivated_area,
        SUM(CASE WHEN land_use_code = 'HVC'             THEN area_value END) AS hvc_area,
        SUM(CASE WHEN land_use_code = 'WATER'           THEN area_value END) AS water_area,
        SUM(CASE WHEN land_use_code = 'MISC'            THEN area_value END) AS misc_area
    FROM plantation_land_use
    GROUP BY plantation_id
) lu ON lu.plantation_id = p.plantation_id

GROUP BY p.plantation_id, p.plantation_code, p.plantation_name, 
         p.total_surface_area, p.measurement_unit,
         n.total_nursery_area,
         lu.building_area, lu.road_area, lu.swap_area, lu.rocky_area,
         lu.uncultivated_area, lu.hvc_area, lu.water_area, lu.misc_area;


-- ----------------------------------------------------------------------------
-- 10.2 Clone-wise Distribution Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_clone_distribution_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    p.plantation_name,
    cm.clone_code,
    cm.clone_name,
    cm.clone_class,
    f.field_category,
    COUNT(f.field_id)               AS number_of_fields,
    SUM(f.area_ha)                  AS total_area_ha,
    SUM(f.number_of_plants)         AS total_plants,
    MIN(f.planting_year)            AS earliest_planting_year,
    MAX(f.planting_year)            AS latest_planting_year
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
WHERE f.status = 'ACTIVE'
GROUP BY p.plantation_id, p.plantation_code, p.plantation_name,
         cm.clone_code, cm.clone_name, cm.clone_class, f.field_category
ORDER BY p.plantation_code, cm.clone_code, f.field_category;


-- ----------------------------------------------------------------------------
-- 10.3 Nursery Clone Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_nursery_clone_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    n.nursery_id,
    n.nursery_code,
    n.nursery_name,
    nt.nursery_type_name,
    cm.clone_code,
    cm.clone_name,
    ncd.number_of_plants,
    ncd.survival_rate_pct,
    ncd.record_date
FROM nursery_clone_distribution ncd
JOIN nursery n ON n.nursery_id = ncd.nursery_id
JOIN lu_nursery_type nt ON nt.nursery_type_code = n.nursery_type_code
JOIN plantation p ON p.plantation_id = n.plantation_id
JOIN clone_master cm ON cm.clone_id = ncd.clone_id
WHERE n.status = 'ACTIVE'
ORDER BY p.plantation_code, n.nursery_code, cm.clone_code;


-- ----------------------------------------------------------------------------
-- 10.4 Immature Fields Detail View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_immature_fields AS
SELECT
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    f.field_code,
    f.field_name,
    fc.category_name       AS field_type,
    cm.clone_code,
    cm.clone_name,
    f.area_ha,
    f.number_of_plants,
    f.planting_month,
    f.planting_year,
    -- Calculated age in years
    EXTRACT(YEAR FROM AGE(
        CURRENT_DATE, 
        MAKE_DATE(f.planting_year, COALESCE(f.planting_month, 1), 1)
    )) AS age_years
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
JOIN lu_field_category fc ON fc.category_code = f.field_category
LEFT JOIN division d ON d.division_id = f.division_id
WHERE f.field_category IN ('NEW_CLEARING', 'REPLANTING')
  AND f.status = 'ACTIVE'
ORDER BY p.plantation_code, f.planting_year, f.field_code;


-- ----------------------------------------------------------------------------
-- 10.5 Mature Fields Detail View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mature_fields AS
SELECT
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    f.field_code,
    f.field_name,
    cm.clone_code,
    cm.clone_name,
    f.area_ha,
    f.number_of_plants,
    f.current_stand_per_ha,
    f.planting_month,
    f.planting_year,
    f.tapping_start_month,
    f.tapping_start_year,
    ts.tapping_system_name,
    ts.frequency_notation,
    f.current_tapping_panel,
    -- Calculated tapping age
    EXTRACT(YEAR FROM AGE(
        CURRENT_DATE,
        MAKE_DATE(f.tapping_start_year, COALESCE(f.tapping_start_month, 1), 1)
    )) AS tapping_age_years
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
LEFT JOIN division d ON d.division_id = f.division_id
LEFT JOIN lu_tapping_system ts ON ts.tapping_system_code = f.tapping_system_code
WHERE f.field_category = 'MATURE'
  AND f.status = 'ACTIVE'
ORDER BY p.plantation_code, f.tapping_start_year, f.field_code;


-- ============================================================================
-- SECTION 11: TRIGGER FUNCTIONS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all main tables
CREATE TRIGGER trg_plantation_updated 
    BEFORE UPDATE ON plantation 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_field_updated 
    BEFORE UPDATE ON field 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_nursery_updated 
    BEFORE UPDATE ON nursery 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_clone_master_updated 
    BEFORE UPDATE ON clone_master 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_nursery_clone_dist_updated 
    BEFORE UPDATE ON nursery_clone_distribution 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_land_use_updated 
    BEFORE UPDATE ON plantation_land_use 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();


-- ============================================================================
-- SECTION 12: AUTO-POPULATE GPS POINT FROM LAT/LON
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_plantation_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON plantation
    FOR EACH ROW EXECUTE FUNCTION fn_sync_gps_point();


-- ============================================================================
-- SECTION 13: VALIDATION — Ensure only one MOTHERBUD nursery per plantation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_validate_motherbud_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.nursery_type_code = 'MOTHERBUD' AND NEW.status = 'ACTIVE' THEN
        IF EXISTS (
            SELECT 1 FROM nursery 
            WHERE plantation_id = NEW.plantation_id 
              AND nursery_type_code = 'MOTHERBUD'
              AND status = 'ACTIVE'
              AND nursery_id != COALESCE(NEW.nursery_id, -1)
        ) THEN
            RAISE EXCEPTION 'Only one active Motherbud Wood Garden is allowed per plantation (plantation_id: %)', NEW.plantation_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_motherbud
    BEFORE INSERT OR UPDATE ON nursery
    FOR EACH ROW EXECUTE FUNCTION fn_validate_motherbud_limit();


-- ============================================================================
-- SECTION 14: ROLES & PERMISSIONS (example)
-- ============================================================================

-- Application roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'plantation_admin') THEN
        CREATE ROLE plantation_admin;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'plantation_manager') THEN
        CREATE ROLE plantation_manager;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'plantation_reader') THEN
        CREATE ROLE plantation_reader;
    END IF;
END $$;

-- Admin: full access
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;

-- Manager: read/write on data tables, read on lookups
GRANT SELECT, INSERT, UPDATE ON plantation, field, nursery, nursery_clone_distribution, 
    plantation_land_use, field_lifecycle_history, annual_area_snapshot, division TO plantation_manager;
GRANT SELECT ON lu_measurement_unit, lu_land_use_type, lu_nursery_type, 
    lu_field_category, lu_tapping_system, clone_master TO plantation_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;

-- Reader: read-only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;


-- ============================================================================
-- END OF DDL
-- ============================================================================
