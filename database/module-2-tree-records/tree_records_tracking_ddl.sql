-- ============================================================================
-- RUBBER PLANTATION MANAGEMENT SYSTEM
-- Module 2: TREE RECORDS AND TRACKING
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for individual tree registration, health monitoring,
--              growth measurement, bark assessment, disease tracking, treatment
--              records, mortality logging, and IoT/NFC tag integration.
-- 
-- Dependencies: Module 1 (Plantation Field Records) must be installed first.
--   Referenced tables: plantation, division, field, clone_master,
--                      lu_measurement_unit, lu_tapping_system
-- ============================================================================

-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Tree Status Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tree_status (
    status_code     VARCHAR(20)     PRIMARY KEY,
    status_name     VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    is_tappable     BOOLEAN         NOT NULL DEFAULT FALSE,
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_tree_status (status_code, status_name, is_tappable, display_order, description) VALUES
    ('SEEDLING',    'Seedling',                 FALSE,  1,  'Recently planted seedling, less than 6 months'),
    ('IMMATURE',    'Immature / Growing',       FALSE,  2,  'Growing tree, not yet reached tappable girth'),
    ('TAPPABLE',    'Tappable / Mature',        TRUE,   3,  'Reached minimum girth (≥50cm), ready for tapping'),
    ('TAPPING',     'Under Active Tapping',     TRUE,   4,  'Currently being tapped for latex'),
    ('RESTING',     'Resting / Tapping Holiday', FALSE, 5,  'Temporarily rested from tapping (wintering, stress)'),
    ('DISEASED',    'Diseased (Not Tapping)',   FALSE,  6,  'Removed from tapping due to disease'),
    ('WIND_DAMAGE', 'Wind Damaged',             FALSE,  7,  'Partially or fully damaged by wind'),
    ('DEAD',        'Dead',                     FALSE,  8,  'Tree is dead — logged for mortality records'),
    ('REMOVED',     'Removed / Felled',         FALSE,  9,  'Physically removed from the field');

COMMENT ON TABLE lu_tree_status IS 'Lifecycle status of individual rubber trees';

-- ----------------------------------------------------------------------------
-- 1.2 Tree Health Rating Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_health_rating (
    rating_code     VARCHAR(10)     PRIMARY KEY,
    rating_name     VARCHAR(50)     NOT NULL,
    rating_score    INT             NOT NULL CHECK (rating_score BETWEEN 1 AND 5),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_health_rating (rating_code, rating_name, rating_score, description) VALUES
    ('EXCELLENT',   'Excellent',    5,  'Vigorous growth, no visible issues, full canopy'),
    ('GOOD',        'Good',         4,  'Healthy with minor cosmetic issues'),
    ('FAIR',        'Fair',         3,  'Some stress indicators — reduced canopy, minor bark issues'),
    ('POOR',        'Poor',         2,  'Significant stress — thinning canopy, bark disease, low yield'),
    ('CRITICAL',    'Critical',     1,  'Severe condition — major disease, structural damage, near death');

-- ----------------------------------------------------------------------------
-- 1.3 Disease / Pest Master
-- ----------------------------------------------------------------------------
CREATE TABLE disease_master (
    disease_id      SERIAL          PRIMARY KEY,
    disease_code    VARCHAR(30)     NOT NULL UNIQUE,
    disease_name    VARCHAR(200)    NOT NULL,
    disease_type    VARCHAR(30)     NOT NULL 
                                    CHECK (disease_type IN (
                                        'FUNGAL', 'BACTERIAL', 'VIRAL', 
                                        'PEST', 'PHYSIOLOGICAL', 'NUTRIENT_DEFICIENCY', 'OTHER'
                                    )),
    causal_agent    VARCHAR(200),                   -- e.g., Phytophthora palmivora
    affected_part   VARCHAR(100),                   -- BARK, LEAF, ROOT, PANEL, WHOLE_TREE
    severity_class  VARCHAR(20)     CHECK (severity_class IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    symptoms        TEXT,
    recommended_treatment TEXT,
    is_notifiable   BOOLEAN         NOT NULL DEFAULT FALSE,  -- Must be reported to authorities
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO disease_master (disease_code, disease_name, disease_type, causal_agent, affected_part, severity_class, symptoms) VALUES
    ('TPD',         'Tapping Panel Dryness',                'PHYSIOLOGICAL', NULL,                           'PANEL',    'HIGH',     'Partial or complete cessation of latex flow on tapping cut'),
    ('WHITE_ROOT',  'White Root Disease',                   'FUNGAL',        'Rigidoporus microporus',       'ROOT',     'CRITICAL', 'Yellowing leaves, die-back, white mycelial fans on roots'),
    ('BROWN_ROOT',  'Brown Root Disease',                   'FUNGAL',        'Phellinus noxius',             'ROOT',     'CRITICAL', 'Browning and hardening of roots, gradual canopy thinning'),
    ('PINK_DISEASE','Pink Disease',                         'FUNGAL',        'Corticium salmonicolor',       'BARK',     'MEDIUM',   'Pinkish-white encrustation on branches, bark cracking'),
    ('ABNORMAL_LF', 'Abnormal Leaf Fall',                   'FUNGAL',        'Phytophthora spp.',            'LEAF',     'HIGH',     'Premature and severe defoliation during wet season'),
    ('POWDERY_MLW', 'Powdery Mildew',                       'FUNGAL',        'Oidium heveae',                'LEAF',     'MEDIUM',   'White powdery coating on young leaves, leaf distortion'),
    ('BARK_ROT',    'Bark Rot / Black Stripe',              'FUNGAL',        'Phytophthora palmivora',       'PANEL',    'HIGH',     'Black necrotic streaks on tapping panel, bark rot'),
    ('TERMITE',     'Termite Attack',                       'PEST',          'Coptotermes spp.',             'BARK',     'MEDIUM',   'Mud tubes on trunk, hollowed internal wood'),
    ('SHOT_HOLE',   'Shot Hole Disease',                    'FUNGAL',        'Drechslera heveae',            'LEAF',     'LOW',      'Small circular holes with brown margins on mature leaves'),
    ('NUTRIENT_N',  'Nitrogen Deficiency',                  'NUTRIENT_DEFICIENCY', NULL,                     'LEAF',     'LOW',      'Uniform yellowing of older leaves, stunted growth');

COMMENT ON TABLE disease_master IS 'Master catalog of rubber tree diseases, pests, and physiological disorders';

-- ----------------------------------------------------------------------------
-- 1.4 Treatment Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_treatment_type (
    treatment_code  VARCHAR(30)     PRIMARY KEY,
    treatment_name  VARCHAR(200)    NOT NULL,
    treatment_class VARCHAR(30)     NOT NULL 
                                    CHECK (treatment_class IN (
                                        'FUNGICIDE', 'INSECTICIDE', 'HERBICIDE', 
                                        'FERTILIZER', 'STIMULANT', 'WOUND_CARE',
                                        'SURGICAL', 'BIOLOGICAL', 'OTHER'
                                    )),
    application_method VARCHAR(100),  -- SPRAY, DRENCH, INJECTION, PAINT, GRANULAR
    description     VARCHAR(500),
    safety_notes    TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_treatment_type (treatment_code, treatment_name, treatment_class, application_method) VALUES
    ('TRIDEMORPH',      'Tridemorph Application',       'FUNGICIDE',    'PAINT/SPRAY'),
    ('HEXACONAZOLE',    'Hexaconazole Application',     'FUNGICIDE',    'SPRAY'),
    ('SULPHUR_DUST',    'Sulphur Dusting',              'FUNGICIDE',    'DUSTING'),
    ('ETHEPHON',        'Ethephon Stimulation',          'STIMULANT',    'PAINT'),
    ('BORDEAUX_PASTE',  'Bordeaux Paste Application',    'WOUND_CARE',   'PAINT'),
    ('NPK_FERT',       'NPK Fertilizer Application',   'FERTILIZER',   'GRANULAR'),
    ('UREA',           'Urea Application',             'FERTILIZER',   'GRANULAR'),
    ('ROOT_SURGERY',   'Root Surgery & Removal',        'SURGICAL',     'MANUAL'),
    ('BIO_CONTROL',    'Trichoderma Biological Control','BIOLOGICAL',   'SOIL_APPLICATION'),
    ('FIPRONIL',       'Fipronil Termite Treatment',    'INSECTICIDE',  'INJECTION');

-- ----------------------------------------------------------------------------
-- 1.5 Growth Parameter Lookup (what gets measured)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_growth_parameter (
    parameter_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    unit_of_measure VARCHAR(30)     NOT NULL,   -- cm, mm, m, count, %
    description     VARCHAR(500),
    min_threshold   NUMERIC(10,2),              -- Below this = concern
    max_threshold   NUMERIC(10,2),              -- Above this = concern
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_growth_parameter (parameter_code, parameter_name, unit_of_measure, description, min_threshold) VALUES
    ('GIRTH',           'Trunk Girth at 150cm',         'cm',       'Circumference measured at 150cm from ground (bud union)', 50),
    ('BARK_THICKNESS',  'Virgin Bark Thickness',        'mm',       'Bark thickness on untapped panel', NULL),
    ('BARK_RENEWAL',    'Renewed Bark Thickness',        'mm',       'Bark thickness on previously tapped (renewed) panel', NULL),
    ('TREE_HEIGHT',     'Tree Height',                  'm',        'Total height from ground to crown apex', NULL),
    ('CANOPY_DIAMETER', 'Canopy Diameter',              'm',        'Maximum canopy spread', NULL),
    ('BRANCH_COUNT',    'Primary Branch Count',         'count',    'Number of primary branches from trunk', NULL),
    ('BARK_CONSUMPTION','Bark Consumption Percentage',   '%',        'Percentage of total bark consumed by tapping', NULL),
    ('LATEX_YIELD',     'Single Tree Latex Yield',       'ml',       'Volume of latex per single tapping', NULL);

-- ----------------------------------------------------------------------------
-- 1.6 IoT Tag Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tag_type (
    tag_type_code   VARCHAR(20)     PRIMARY KEY,
    tag_type_name   VARCHAR(100)    NOT NULL,
    technology      VARCHAR(50)     NOT NULL,   -- NFC, RFID, QR, BLE_BEACON
    read_range_m    NUMERIC(6,2),               -- Effective read range in meters
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_tag_type (tag_type_code, tag_type_name, technology, read_range_m) VALUES
    ('NFC_TAG',     'NFC Tree Tag',             'NFC',          0.05),
    ('RFID_UHF',    'UHF RFID Tag',             'RFID',         10.00),
    ('RFID_HF',     'HF RFID Tag',              'RFID',         1.00),
    ('QR_PLATE',    'QR Code Metal Plate',       'QR',           NULL),
    ('BLE_BEACON',  'Bluetooth Low Energy Beacon','BLE_BEACON',  30.00);

-- ----------------------------------------------------------------------------
-- 1.7 Mortality Cause Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_mortality_cause (
    cause_code      VARCHAR(30)     PRIMARY KEY,
    cause_name      VARCHAR(200)    NOT NULL,
    cause_category  VARCHAR(30)     NOT NULL 
                                    CHECK (cause_category IN (
                                        'DISEASE', 'WEATHER', 'PEST', 'HUMAN', 
                                        'NATURAL', 'UNKNOWN'
                                    )),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_mortality_cause (cause_code, cause_name, cause_category) VALUES
    ('WIND_FALL',       'Wind Throw / Toppling',        'WEATHER'),
    ('LIGHTNING',       'Lightning Strike',             'WEATHER'),
    ('DROUGHT',         'Drought Stress Death',         'WEATHER'),
    ('WHITE_ROOT_MORT', 'White Root Disease Mortality',  'DISEASE'),
    ('BROWN_ROOT_MORT', 'Brown Root Disease Mortality',  'DISEASE'),
    ('BARK_ROT_MORT',   'Severe Bark Rot / Panel Death','DISEASE'),
    ('TERMITE_MORT',    'Severe Termite Damage',        'PEST'),
    ('OVER_TAPPING',    'Death from Over-Exploitation',  'HUMAN'),
    ('ACCIDENTAL',      'Accidental Damage (Machinery)','HUMAN'),
    ('AGE_SENESCENCE',  'Natural Senescence / Old Age',  'NATURAL'),
    ('UNKNOWN',         'Unknown / Undetermined',        'UNKNOWN');


-- ============================================================================
-- SECTION 2: TREE ROW — the master record for every row of trees
-- (Optional organizational level between field and individual tree)
-- ============================================================================

CREATE TABLE tree_row (
    row_id              SERIAL          PRIMARY KEY,
    field_id            INT             NOT NULL REFERENCES field(field_id),
    row_number          INT             NOT NULL CHECK (row_number > 0),
    row_direction       VARCHAR(10)     CHECK (row_direction IN ('NS', 'EW', 'NE_SW', 'NW_SE')),
    tree_spacing_m      NUMERIC(5,2),   -- Spacing between trees within the row
    row_spacing_m       NUMERIC(5,2),   -- Spacing between this row and the next
    number_of_trees     INT             CHECK (number_of_trees >= 0),
    
    -- Spatial
    row_line            GEOMETRY(LineString, 4326),  -- GPS line of the row
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    
    CONSTRAINT uq_row_in_field UNIQUE (field_id, row_number)
);

CREATE INDEX idx_tree_row_field ON tree_row(field_id);
CREATE INDEX idx_tree_row_geom ON tree_row USING GIST(row_line);

COMMENT ON TABLE tree_row IS 'Row-level organization within a field — groups trees planted in a line';


-- ============================================================================
-- SECTION 3: TREE — the individual tree master record
-- This is the CORE entity of the module
-- ============================================================================

CREATE TABLE tree (
    tree_id             BIGSERIAL       PRIMARY KEY,
    
    -- Hierarchy: Plantation → Division → Field → Row → Tree
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    row_id              INT             REFERENCES tree_row(row_id),
    
    -- Identification
    tree_code           VARCHAR(50)     NOT NULL,   -- e.g., F01-R05-T023
    tree_sequence       INT,                        -- Position within row (1, 2, 3...)
    
    -- Clone
    clone_id            INT             NOT NULL REFERENCES clone_master(clone_id),
    is_budded           BOOLEAN         NOT NULL DEFAULT TRUE,
    rootstock_clone_id  INT             REFERENCES clone_master(clone_id),  -- For budded trees
    
    -- Planting
    planting_date       DATE,
    planting_year       INT             NOT NULL CHECK (planting_year BETWEEN 1900 AND 2100),
    planting_method     VARCHAR(30)     CHECK (planting_method IN (
                                            'BUD_GRAFT', 'STUMP', 'POLYBAG', 
                                            'DIRECT_SEED', 'MARCOT'
                                        )),
    nursery_source_id   INT             REFERENCES nursery(nursery_id),
    
    -- Current Status
    tree_status         VARCHAR(20)     NOT NULL DEFAULT 'SEEDLING' 
                                        REFERENCES lu_tree_status(status_code),
    health_rating       VARCHAR(10)     REFERENCES lu_health_rating(rating_code),
    
    -- Current Measurements (denormalized for quick access)
    current_girth_cm    NUMERIC(8,2),           -- Latest girth at 150cm
    current_bark_mm     NUMERIC(6,2),           -- Latest bark thickness
    bark_consumption_pct NUMERIC(5,2)           CHECK (bark_consumption_pct BETWEEN 0 AND 100),
    
    -- Tapping Info (for trees under tapping)
    tapping_start_date  DATE,
    current_panel       VARCHAR(20),            -- e.g., BI-1, BO-1, HI-1
    current_tapping_system VARCHAR(20)          REFERENCES lu_tapping_system(tapping_system_code),
    panels_exhausted    INT             DEFAULT 0 CHECK (panels_exhausted >= 0),
    
    -- Spatial / IoT
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),
    
    -- Mortality (populated only if tree dies/removed)
    mortality_date      DATE,
    mortality_cause_code VARCHAR(30)    REFERENCES lu_mortality_cause(cause_code),
    mortality_remarks   TEXT,
    
    -- Metadata
    remarks             TEXT,
    photo_url           VARCHAR(1000),          -- Latest photo of the tree
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),
    
    CONSTRAINT uq_tree_code UNIQUE (plantation_id, tree_code),
    CONSTRAINT chk_mortality_fields CHECK (
        (tree_status NOT IN ('DEAD', 'REMOVED'))
        OR (mortality_date IS NOT NULL)
    )
);

CREATE INDEX idx_tree_plantation ON tree(plantation_id);
CREATE INDEX idx_tree_field ON tree(field_id);
CREATE INDEX idx_tree_row ON tree(row_id);
CREATE INDEX idx_tree_clone ON tree(clone_id);
CREATE INDEX idx_tree_status ON tree(tree_status);
CREATE INDEX idx_tree_health ON tree(health_rating);
CREATE INDEX idx_tree_gps ON tree USING GIST(gps_point);
CREATE INDEX idx_tree_planting_year ON tree(planting_year);
CREATE INDEX idx_tree_tapping_panel ON tree(current_panel) WHERE current_panel IS NOT NULL;

COMMENT ON TABLE tree IS 
    'Individual rubber tree master record — the core entity for tree-level tracking. '
    'Each tree belongs to a field and optionally a row, has a clone identity, and '
    'progresses through lifecycle statuses from seedling to mature/tapping to eventual mortality.';


-- ============================================================================
-- SECTION 4: TREE IoT / NFC TAG REGISTRATION
-- Links physical tags to trees for field scanning
-- ============================================================================

CREATE TABLE tree_tag (
    tag_id              BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    tag_uid             VARCHAR(100)    NOT NULL UNIQUE,     -- Unique tag identifier (NFC UID, RFID EPC, QR data)
    tag_type_code       VARCHAR(20)     NOT NULL REFERENCES lu_tag_type(tag_type_code),
    
    -- Lifecycle
    installed_date      DATE            NOT NULL,
    installed_by        VARCHAR(100),
    deactivated_date    DATE,
    deactivation_reason VARCHAR(200),
    
    -- Status
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    last_scanned_at     TIMESTAMPTZ,
    last_scanned_by     VARCHAR(100),
    total_scan_count    INT             NOT NULL DEFAULT 0,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tree_tag_tree ON tree_tag(tree_id);
CREATE INDEX idx_tree_tag_uid ON tree_tag(tag_uid);
CREATE INDEX idx_tree_tag_active ON tree_tag(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE tree_tag IS 
    'NFC/RFID/QR tags physically attached to trees. '
    'Enables mobile scanning for instant tree identification in the field.';


-- ============================================================================
-- SECTION 5: TREE GROWTH MEASUREMENTS
-- Periodic girth, bark, height measurements over time
-- ============================================================================

CREATE TABLE tree_growth_measurement (
    measurement_id      BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    parameter_code      VARCHAR(30)     NOT NULL REFERENCES lu_growth_parameter(parameter_code),
    measured_value      NUMERIC(10,2)   NOT NULL,
    measurement_unit    VARCHAR(30)     NOT NULL,   -- Mirrors lu_growth_parameter.unit_of_measure
    
    measurement_date    DATE            NOT NULL,
    measurement_method  VARCHAR(30)     CHECK (measurement_method IN (
                                            'MANUAL_TAPE', 'DIGITAL_CALIPER', 
                                            'LASER_RANGEFINDER', 'DRONE_LIDAR',
                                            'MOBILE_APP_PHOTO', 'IOT_SENSOR'
                                        )),
    
    -- Is this value below/above threshold?
    is_below_threshold  BOOLEAN,
    is_above_threshold  BOOLEAN,
    
    measured_by         VARCHAR(100),
    remarks             TEXT,
    photo_url           VARCHAR(1000),  -- Photo evidence of measurement
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_growth_tree ON tree_growth_measurement(tree_id);
CREATE INDEX idx_growth_param ON tree_growth_measurement(parameter_code);
CREATE INDEX idx_growth_date ON tree_growth_measurement(measurement_date);
CREATE INDEX idx_growth_tree_date ON tree_growth_measurement(tree_id, measurement_date);

COMMENT ON TABLE tree_growth_measurement IS 
    'Time-series growth data for each tree — girth, bark thickness, height, canopy, yield, etc.';


-- ============================================================================
-- SECTION 6: BARK PANEL HISTORY
-- Tracks panel-by-panel tapping progression for each tree
-- ============================================================================

CREATE TABLE tree_panel_history (
    panel_history_id    BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    panel_code          VARCHAR(20)     NOT NULL,   -- BI-1, BO-1, BI-2, BO-2, HI-1, HO-1, etc.
    panel_position      VARCHAR(10)     NOT NULL    -- LOW (B), HIGH (H)
                                        CHECK (panel_position IN ('LOW', 'HIGH')),
    panel_side          VARCHAR(10)     NOT NULL    -- INNER (I), OUTER (O)
                                        CHECK (panel_side IN ('INNER', 'OUTER')),
    
    -- Tapping system used on this panel
    tapping_system_code VARCHAR(20)     REFERENCES lu_tapping_system(tapping_system_code),
    
    -- Duration
    opened_date         DATE            NOT NULL,
    closed_date         DATE,
    
    -- Bark condition at close
    bark_thickness_at_open_mm  NUMERIC(6,2),
    bark_thickness_at_close_mm NUMERIC(6,2),
    bark_consumption_pct       NUMERIC(5,2)    CHECK (bark_consumption_pct BETWEEN 0 AND 100),
    
    -- Performance
    avg_daily_yield_ml  NUMERIC(10,2),
    total_tapping_days  INT,
    
    -- Status
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'CLOSED', 'RESTING', 'DAMAGED')),
    
    -- Panel-specific issues
    has_tpd             BOOLEAN         NOT NULL DEFAULT FALSE,  -- Tapping Panel Dryness
    has_bark_rot        BOOLEAN         NOT NULL DEFAULT FALSE,
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_tree_panel UNIQUE (tree_id, panel_code)
);

CREATE INDEX idx_panel_tree ON tree_panel_history(tree_id);
CREATE INDEX idx_panel_status ON tree_panel_history(status);
CREATE INDEX idx_panel_opened ON tree_panel_history(opened_date);

COMMENT ON TABLE tree_panel_history IS 
    'Complete tapping panel history per tree. Tracks the sequential use of bark panels '
    '(BI-1 → BO-1 → BI-2 → BO-2 → HI-1 → HO-1 etc.), bark consumption, and panel-specific issues.';


-- ============================================================================
-- SECTION 7: TREE HEALTH INSPECTION
-- Periodic health assessments conducted in the field
-- ============================================================================

CREATE TABLE tree_health_inspection (
    inspection_id       BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    inspection_date     DATE            NOT NULL,
    inspector_name      VARCHAR(100)    NOT NULL,
    inspection_method   VARCHAR(30)     CHECK (inspection_method IN (
                                            'VISUAL', 'INSTRUMENT', 'DRONE_IMAGE',
                                            'AI_PHOTO_ANALYSIS', 'LAB_TEST'
                                        )),
    
    -- Overall Assessment
    health_rating       VARCHAR(10)     NOT NULL REFERENCES lu_health_rating(rating_code),
    
    -- Component Scores (1-5 each)
    canopy_score        INT             CHECK (canopy_score BETWEEN 1 AND 5),
    trunk_score         INT             CHECK (trunk_score BETWEEN 1 AND 5),
    bark_score          INT             CHECK (bark_score BETWEEN 1 AND 5),
    root_zone_score     INT             CHECK (root_zone_score BETWEEN 1 AND 5),
    
    -- Observations
    leaf_condition      VARCHAR(30)     CHECK (leaf_condition IN (
                                            'FULL_CANOPY', 'PARTIAL_DEFOLIATION', 
                                            'HEAVY_DEFOLIATION', 'WINTERING', 'REFOLIATION'
                                        )),
    latex_flow_status   VARCHAR(30)     CHECK (latex_flow_status IN (
                                            'NORMAL', 'REDUCED', 'NO_FLOW', 'EXCESSIVE', 'NOT_TAPPED'
                                        )),
    
    -- Disease Detection
    disease_detected    BOOLEAN         NOT NULL DEFAULT FALSE,
    primary_disease_id  INT             REFERENCES disease_master(disease_id),
    disease_severity    VARCHAR(20)     CHECK (disease_severity IN ('MILD', 'MODERATE', 'SEVERE')),
    
    -- AI-assisted fields
    ai_analysis_score   NUMERIC(5,2),           -- Gen AI photo analysis confidence score (0-100)
    ai_analysis_notes   TEXT,                    -- AI-generated observation summary
    
    -- Evidence
    photo_urls          TEXT[],                  -- Array of photo URLs for this inspection
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inspection_tree ON tree_health_inspection(tree_id);
CREATE INDEX idx_inspection_date ON tree_health_inspection(inspection_date);
CREATE INDEX idx_inspection_disease ON tree_health_inspection(disease_detected) WHERE disease_detected = TRUE;
CREATE INDEX idx_inspection_rating ON tree_health_inspection(health_rating);

COMMENT ON TABLE tree_health_inspection IS 
    'Periodic health assessments for individual trees — supports visual, instrument, drone, and AI-assisted inspection methods.';


-- ============================================================================
-- SECTION 8: TREE DISEASE INCIDENT
-- Detailed disease/pest occurrence records
-- ============================================================================

CREATE TABLE tree_disease_incident (
    incident_id         BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    disease_id          INT             NOT NULL REFERENCES disease_master(disease_id),
    
    -- Discovery
    detected_date       DATE            NOT NULL,
    detected_by         VARCHAR(100),
    detection_method    VARCHAR(30)     CHECK (detection_method IN (
                                            'VISUAL_FIELD', 'HEALTH_INSPECTION', 
                                            'AI_IMAGE_ANALYSIS', 'LAB_CONFIRMATION',
                                            'IOT_SENSOR', 'TAPPER_REPORT'
                                        )),
    
    -- Severity & Spread
    severity            VARCHAR(20)     NOT NULL CHECK (severity IN ('MILD', 'MODERATE', 'SEVERE', 'TERMINAL')),
    affected_area_pct   NUMERIC(5,2)    CHECK (affected_area_pct BETWEEN 0 AND 100),
    spread_risk         VARCHAR(20)     CHECK (spread_risk IN ('LOW', 'MEDIUM', 'HIGH')),
    
    -- Linked inspection (if discovered during an inspection)
    inspection_id       BIGINT          REFERENCES tree_health_inspection(inspection_id),
    
    -- Resolution
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'UNDER_TREATMENT', 'RESOLVED', 'CHRONIC', 'FATAL')),
    resolved_date       DATE,
    resolution_notes    TEXT,
    
    -- Impact
    caused_tapping_stop BOOLEAN         NOT NULL DEFAULT FALSE,
    tapping_stop_date   DATE,
    tapping_resume_date DATE,
    
    -- Evidence
    photo_urls          TEXT[],
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_disease_inc_tree ON tree_disease_incident(tree_id);
CREATE INDEX idx_disease_inc_disease ON tree_disease_incident(disease_id);
CREATE INDEX idx_disease_inc_date ON tree_disease_incident(detected_date);
CREATE INDEX idx_disease_inc_status ON tree_disease_incident(status);
CREATE INDEX idx_disease_inc_severity ON tree_disease_incident(severity);

COMMENT ON TABLE tree_disease_incident IS 
    'Individual disease/pest occurrences per tree with severity tracking, treatment linkage, and tapping impact.';


-- ============================================================================
-- SECTION 9: TREE TREATMENT RECORD
-- Treatments applied to individual trees (linked to disease incidents)
-- ============================================================================

CREATE TABLE tree_treatment_record (
    treatment_id        BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    -- Link to disease (optional — some treatments are preventive)
    incident_id         BIGINT          REFERENCES tree_disease_incident(incident_id),
    
    treatment_code      VARCHAR(30)     NOT NULL REFERENCES lu_treatment_type(treatment_code),
    treatment_date      DATE            NOT NULL,
    
    -- Dosage
    product_name        VARCHAR(200),
    dosage_amount       NUMERIC(10,3),
    dosage_unit         VARCHAR(30),            -- ml, g, kg, L
    concentration_pct   NUMERIC(5,2),
    
    -- Application
    application_area    VARCHAR(50),            -- PANEL, TRUNK, ROOT_ZONE, CANOPY, FULL_TREE
    applied_by          VARCHAR(100)    NOT NULL,
    application_duration_min INT,
    
    -- Follow-up
    next_treatment_date DATE,
    treatment_round     INT             DEFAULT 1,  -- 1st, 2nd, 3rd application
    
    -- Outcome (filled later)
    outcome             VARCHAR(30)     CHECK (outcome IN (
                                            'EFFECTIVE', 'PARTIALLY_EFFECTIVE', 
                                            'INEFFECTIVE', 'PENDING', 'ADVERSE_REACTION'
                                        )),
    outcome_assessed_date DATE,
    outcome_notes       TEXT,
    
    -- Cost
    treatment_cost      NUMERIC(12,2),
    currency_code       VARCHAR(3)      DEFAULT 'USD',
    
    photo_url           VARCHAR(1000),
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_treatment_tree ON tree_treatment_record(tree_id);
CREATE INDEX idx_treatment_incident ON tree_treatment_record(incident_id);
CREATE INDEX idx_treatment_date ON tree_treatment_record(treatment_date);
CREATE INDEX idx_treatment_type ON tree_treatment_record(treatment_code);
CREATE INDEX idx_treatment_outcome ON tree_treatment_record(outcome);

COMMENT ON TABLE tree_treatment_record IS 
    'All chemical, biological, and surgical treatments applied to trees — linked to disease incidents when curative.';


-- ============================================================================
-- SECTION 10: TREE MORTALITY RECORD
-- Detailed record when a tree dies or is removed
-- ============================================================================

CREATE TABLE tree_mortality_record (
    mortality_id        BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id) UNIQUE,
    
    mortality_date      DATE            NOT NULL,
    cause_code          VARCHAR(30)     NOT NULL REFERENCES lu_mortality_cause(cause_code),
    
    -- Linked disease incident (if disease caused death)
    incident_id         BIGINT          REFERENCES tree_disease_incident(incident_id),
    
    -- Tree state at death
    age_at_death_years  INT,
    girth_at_death_cm   NUMERIC(8,2),
    was_tappable        BOOLEAN,
    last_panel_used     VARCHAR(20),
    
    -- Removal / Replacement
    tree_removed        BOOLEAN         NOT NULL DEFAULT FALSE,
    removal_date        DATE,
    replacement_planted BOOLEAN         NOT NULL DEFAULT FALSE,
    replacement_tree_id BIGINT          REFERENCES tree(tree_id),
    replacement_date    DATE,
    
    -- Investigation
    investigated_by     VARCHAR(100),
    investigation_notes TEXT,
    photo_urls          TEXT[],
    
    -- Economic impact
    estimated_yield_loss_kg NUMERIC(10,2),
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    reported_by         VARCHAR(100)
);

CREATE INDEX idx_mortality_tree ON tree_mortality_record(tree_id);
CREATE INDEX idx_mortality_cause ON tree_mortality_record(cause_code);
CREATE INDEX idx_mortality_date ON tree_mortality_record(mortality_date);

COMMENT ON TABLE tree_mortality_record IS 
    'Detailed mortality record — one per dead/removed tree — with cause analysis, economic impact, and replacement tracking.';


-- ============================================================================
-- SECTION 11: TREE STATUS CHANGE LOG (Audit Trail)
-- Every status transition is logged
-- ============================================================================

CREATE TABLE tree_status_change_log (
    log_id              BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    
    change_date         DATE            NOT NULL,
    from_status         VARCHAR(20)     REFERENCES lu_tree_status(status_code),
    to_status           VARCHAR(20)     NOT NULL REFERENCES lu_tree_status(status_code),
    
    reason              TEXT,
    changed_by          VARCHAR(100),
    
    -- Optional blockchain anchor
    blockchain_tx_hash  VARCHAR(128),   -- Hash of the transaction on blockchain (if enabled)
    blockchain_block_no BIGINT,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_status_log_tree ON tree_status_change_log(tree_id);
CREATE INDEX idx_status_log_date ON tree_status_change_log(change_date);
CREATE INDEX idx_status_log_to ON tree_status_change_log(to_status);

COMMENT ON TABLE tree_status_change_log IS 
    'Immutable audit log of every tree status transition. Supports optional blockchain anchoring for tamper-proof records.';


-- ============================================================================
-- SECTION 12: FIELD-LEVEL TREE CENSUS SUMMARY
-- Periodic summary counts per field (supports the field-level view)
-- ============================================================================

CREATE TABLE tree_census_summary (
    census_id           SERIAL          PRIMARY KEY,
    field_id            INT             NOT NULL REFERENCES field(field_id),
    
    census_date         DATE            NOT NULL,
    census_year         INT             NOT NULL,
    
    -- Counts
    total_trees         INT             NOT NULL CHECK (total_trees >= 0),
    live_trees          INT             NOT NULL CHECK (live_trees >= 0),
    tappable_trees      INT             NOT NULL CHECK (tappable_trees >= 0),
    trees_under_tapping INT             NOT NULL CHECK (trees_under_tapping >= 0),
    immature_trees      INT             NOT NULL CHECK (immature_trees >= 0),
    diseased_trees      INT             NOT NULL CHECK (diseased_trees >= 0),
    dead_trees_ytd      INT             NOT NULL DEFAULT 0,
    
    -- Derived metrics
    mortality_rate_pct  NUMERIC(5,2),
    tapping_utilization_pct NUMERIC(5,2),   -- trees_under_tapping / tappable_trees * 100
    stand_per_ha        NUMERIC(8,2),       -- live_trees / field area
    
    -- Average growth
    avg_girth_cm        NUMERIC(8,2),
    min_girth_cm        NUMERIC(8,2),
    max_girth_cm        NUMERIC(8,2),
    
    conducted_by        VARCHAR(100),
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_census_field_date UNIQUE (field_id, census_date)
);

CREATE INDEX idx_census_field ON tree_census_summary(field_id);
CREATE INDEX idx_census_year ON tree_census_summary(census_year);

COMMENT ON TABLE tree_census_summary IS 
    'Periodic field-level tree census — aggregated counts, mortality rates, and growth statistics.';


-- ============================================================================
-- SECTION 13: VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 13.1 Tree Full Profile View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tree_profile AS
SELECT
    t.tree_id,
    t.tree_code,
    p.plantation_code,
    p.plantation_name,
    f.field_code,
    f.field_name,
    tr.row_number,
    t.tree_sequence,
    
    cm.clone_code,
    cm.clone_name,
    cm.clone_class,
    
    ts.status_name      AS current_status,
    ts.is_tappable,
    hr.rating_name      AS health_rating,
    hr.rating_score     AS health_score,
    
    t.planting_year,
    t.planting_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, COALESCE(t.planting_date, MAKE_DATE(t.planting_year, 1, 1))))::INT AS tree_age_years,
    
    t.current_girth_cm,
    t.current_bark_mm,
    t.bark_consumption_pct,
    
    t.current_panel,
    tps.tapping_system_name AS current_tapping_system,
    t.tapping_start_date,
    t.panels_exhausted,
    
    t.gps_latitude,
    t.gps_longitude,
    t.mortality_date,
    mc.cause_name       AS mortality_cause

FROM tree t
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN field f ON f.field_id = t.field_id
LEFT JOIN tree_row tr ON tr.row_id = t.row_id
JOIN clone_master cm ON cm.clone_id = t.clone_id
JOIN lu_tree_status ts ON ts.status_code = t.tree_status
LEFT JOIN lu_health_rating hr ON hr.rating_code = t.health_rating
LEFT JOIN lu_tapping_system tps ON tps.tapping_system_code = t.current_tapping_system
LEFT JOIN lu_mortality_cause mc ON mc.cause_code = t.mortality_cause_code;


-- ----------------------------------------------------------------------------
-- 13.2 Field Tree Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_field_tree_summary AS
SELECT
    f.field_id,
    p.plantation_code,
    f.field_code,
    f.field_name,
    cm.clone_code,
    f.area_ha,
    
    COUNT(t.tree_id)                                                            AS total_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status NOT IN ('DEAD', 'REMOVED'))    AS live_trees,
    COUNT(t.tree_id) FILTER (WHERE ts.is_tappable = TRUE)                       AS tappable_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status = 'TAPPING')                   AS trees_tapping,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status = 'DISEASED')                  AS diseased_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status IN ('DEAD', 'REMOVED'))        AS dead_removed_trees,
    
    ROUND(AVG(t.current_girth_cm), 2)                                           AS avg_girth_cm,
    ROUND(AVG(t.bark_consumption_pct), 2)                                       AS avg_bark_consumption_pct,
    
    CASE WHEN f.area_ha > 0 
         THEN ROUND(COUNT(t.tree_id) FILTER (WHERE t.tree_status NOT IN ('DEAD','REMOVED')) / f.area_ha, 0)
         ELSE NULL 
    END AS live_stand_per_ha

FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
LEFT JOIN tree t ON t.field_id = f.field_id
LEFT JOIN lu_tree_status ts ON ts.status_code = t.tree_status
GROUP BY f.field_id, p.plantation_code, f.field_code, f.field_name, cm.clone_code, f.area_ha;


-- ----------------------------------------------------------------------------
-- 13.3 Disease Hotspot View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_disease_hotspot AS
SELECT
    p.plantation_code,
    f.field_code,
    dm.disease_code,
    dm.disease_name,
    dm.disease_type,
    dm.severity_class      AS disease_severity_class,
    
    COUNT(di.incident_id)                                                   AS total_incidents,
    COUNT(di.incident_id) FILTER (WHERE di.status = 'ACTIVE')              AS active_incidents,
    COUNT(di.incident_id) FILTER (WHERE di.status = 'UNDER_TREATMENT')     AS under_treatment,
    COUNT(di.incident_id) FILTER (WHERE di.severity = 'SEVERE')            AS severe_count,
    COUNT(di.incident_id) FILTER (WHERE di.caused_tapping_stop = TRUE)     AS tapping_stopped_count,
    
    MIN(di.detected_date) AS earliest_detection,
    MAX(di.detected_date) AS latest_detection

FROM tree_disease_incident di
JOIN tree t ON t.tree_id = di.tree_id
JOIN field f ON f.field_id = t.field_id
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN disease_master dm ON dm.disease_id = di.disease_id
WHERE di.status IN ('ACTIVE', 'UNDER_TREATMENT')
GROUP BY p.plantation_code, f.field_code, dm.disease_code, dm.disease_name, dm.disease_type, dm.severity_class
ORDER BY active_incidents DESC;


-- ----------------------------------------------------------------------------
-- 13.4 Mortality Analysis View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mortality_analysis AS
SELECT
    p.plantation_code,
    f.field_code,
    cm.clone_code,
    mc.cause_name,
    mc.cause_category,
    
    COUNT(mr.mortality_id)                  AS total_deaths,
    ROUND(AVG(mr.age_at_death_years), 1)   AS avg_age_at_death,
    ROUND(AVG(mr.girth_at_death_cm), 1)    AS avg_girth_at_death,
    SUM(mr.estimated_yield_loss_kg)         AS total_yield_loss_kg,
    
    COUNT(mr.mortality_id) FILTER (WHERE mr.replacement_planted = TRUE) AS trees_replaced,
    
    MIN(mr.mortality_date) AS earliest_death,
    MAX(mr.mortality_date) AS latest_death

FROM tree_mortality_record mr
JOIN tree t ON t.tree_id = mr.tree_id
JOIN field f ON f.field_id = t.field_id
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN clone_master cm ON cm.clone_id = t.clone_id
JOIN lu_mortality_cause mc ON mc.cause_code = mr.cause_code
GROUP BY p.plantation_code, f.field_code, cm.clone_code, mc.cause_name, mc.cause_category
ORDER BY total_deaths DESC;


-- ============================================================================
-- SECTION 14: TRIGGER FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 14.1 Auto-update updated_at
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_tree_updated 
    BEFORE UPDATE ON tree 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_tree_tag_updated 
    BEFORE UPDATE ON tree_tag 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_panel_history_updated 
    BEFORE UPDATE ON tree_panel_history 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_disease_incident_updated 
    BEFORE UPDATE ON tree_disease_incident 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_treatment_record_updated 
    BEFORE UPDATE ON tree_treatment_record 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_disease_master_updated 
    BEFORE UPDATE ON disease_master 
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- 14.2 Auto-populate GPS point from lat/lon on tree
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tree_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tree_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON tree
    FOR EACH ROW EXECUTE FUNCTION fn_tree_sync_gps_point();

-- ----------------------------------------------------------------------------
-- 14.3 Auto-log tree status changes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_log_tree_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.tree_status IS DISTINCT FROM NEW.tree_status THEN
        INSERT INTO tree_status_change_log (tree_id, change_date, from_status, to_status, changed_by)
        VALUES (NEW.tree_id, CURRENT_DATE, OLD.tree_status, NEW.tree_status, NEW.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tree_status_change_log
    AFTER UPDATE OF tree_status ON tree
    FOR EACH ROW EXECUTE FUNCTION fn_log_tree_status_change();

-- ----------------------------------------------------------------------------
-- 14.4 Auto-update tree's denormalized girth from measurements
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_tree_girth()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parameter_code = 'GIRTH' THEN
        UPDATE tree 
        SET current_girth_cm = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    ELSIF NEW.parameter_code = 'BARK_THICKNESS' THEN
        UPDATE tree 
        SET current_bark_mm = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    ELSIF NEW.parameter_code = 'BARK_CONSUMPTION' THEN
        UPDATE tree 
        SET bark_consumption_pct = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_tree_girth
    AFTER INSERT ON tree_growth_measurement
    FOR EACH ROW EXECUTE FUNCTION fn_sync_tree_girth();

-- ----------------------------------------------------------------------------
-- 14.5 Auto-update tag scan metadata
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_increment_tag_scan()
RETURNS TRIGGER AS $$
BEGIN
    -- This would be called by application layer on scan events
    -- Example: UPDATE tree_tag SET last_scanned_at = NOW() WHERE tag_uid = ?
    NEW.total_scan_count = COALESCE(OLD.total_scan_count, 0) + 
        CASE WHEN NEW.last_scanned_at IS DISTINCT FROM OLD.last_scanned_at THEN 1 ELSE 0 END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tag_scan_count
    BEFORE UPDATE OF last_scanned_at ON tree_tag
    FOR EACH ROW EXECUTE FUNCTION fn_increment_tag_scan();


-- ============================================================================
-- SECTION 15: PERMISSIONS
-- ============================================================================

-- Extend existing roles with tree module permissions
GRANT SELECT, INSERT, UPDATE ON tree, tree_row, tree_tag, tree_growth_measurement, 
    tree_panel_history, tree_health_inspection, tree_disease_incident, 
    tree_treatment_record, tree_mortality_record, tree_status_change_log,
    tree_census_summary TO plantation_manager;

GRANT SELECT ON disease_master, lu_tree_status, lu_health_rating, lu_treatment_type, 
    lu_growth_parameter, lu_tag_type, lu_mortality_cause TO plantation_manager;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;

-- Admin gets everything
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;


-- ============================================================================
-- END OF MODULE 2: TREE RECORDS AND TRACKING
-- ============================================================================
