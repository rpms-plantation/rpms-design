-- ============================================================================
-- V1_001 — Module 1 (Plantation Field Records) — CREATE TABLE statements
-- Source: database/module-1-field-records/plantation_field_records_ddl.sql
-- Prerequisite: V0 platform migration must have already created the
-- `postgis` and `uuid-ossp` extensions (owned by rpms-platform).
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

-- ----------------------------------------------------------------------------
-- 1.4 Field Category Lookup (for Immature sub-classification)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_field_category (
    category_code   VARCHAR(20)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

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

COMMENT ON TABLE nursery_clone_distribution IS 'Clone-wise distribution of plants in each nursery';

-- ============================================================================
-- SECTION 9: ANNUAL AREA SNAPSHOT
-- Captures a point-in-time snapshot of all area allocations for reporting
-- ============================================================================

CREATE TABLE annual_area_snapshot (
    snapshot_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    snapshot_year       INT             NOT NULL,
    snapshot_date        DATE            NOT NULL,

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

COMMENT ON TABLE annual_area_snapshot IS
    'Yearly snapshot of area breakdown for historical reporting and compliance';
