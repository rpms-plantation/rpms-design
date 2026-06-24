-- ============================================================================
-- V2_001 — Module 2 (Tree Records & Tracking) — CREATE TABLE statements
-- Source: database/module-2-tree-records/tree_records_tracking_ddl.sql
-- Prerequisite: V1 (Module 1 — plantation, field, clone_master, nursery) must
-- have already run.
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
    causal_agent    VARCHAR(200),
    affected_part   VARCHAR(100),
    severity_class  VARCHAR(20)     CHECK (severity_class IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    symptoms        TEXT,
    recommended_treatment TEXT,
    is_notifiable   BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

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
    application_method VARCHAR(100),
    description     VARCHAR(500),
    safety_notes    TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.5 Growth Parameter Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_growth_parameter (
    parameter_code  VARCHAR(30)     PRIMARY KEY,
    parameter_name  VARCHAR(100)    NOT NULL,
    unit_of_measure VARCHAR(30)     NOT NULL,
    description     VARCHAR(500),
    min_threshold   NUMERIC(10,2),
    max_threshold   NUMERIC(10,2),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.6 IoT Tag Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_tag_type (
    tag_type_code   VARCHAR(20)     PRIMARY KEY,
    tag_type_name   VARCHAR(100)    NOT NULL,
    technology      VARCHAR(50)     NOT NULL,
    read_range_m    NUMERIC(6,2),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

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

-- ============================================================================
-- SECTION 2: TREE ROW
-- ============================================================================

CREATE TABLE tree_row (
    row_id              SERIAL          PRIMARY KEY,
    field_id            INT             NOT NULL REFERENCES field(field_id),
    row_number          INT             NOT NULL CHECK (row_number > 0),
    row_direction       VARCHAR(10)     CHECK (row_direction IN ('NS', 'EW', 'NE_SW', 'NW_SE')),
    tree_spacing_m      NUMERIC(5,2),
    row_spacing_m       NUMERIC(5,2),
    number_of_trees     INT             CHECK (number_of_trees >= 0),

    row_line            GEOMETRY(LineString, 4326),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),

    CONSTRAINT uq_row_in_field UNIQUE (field_id, row_number)
);

COMMENT ON TABLE tree_row IS 'Row-level organization within a field — groups trees planted in a line';

-- ============================================================================
-- SECTION 3: TREE
-- ============================================================================

CREATE TABLE tree (
    tree_id             BIGSERIAL       PRIMARY KEY,

    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    row_id              INT             REFERENCES tree_row(row_id),

    tree_code           VARCHAR(50)     NOT NULL,
    tree_sequence        INT,

    clone_id            INT             NOT NULL REFERENCES clone_master(clone_id),
    is_budded           BOOLEAN         NOT NULL DEFAULT TRUE,
    rootstock_clone_id  INT             REFERENCES clone_master(clone_id),

    planting_date       DATE,
    planting_year       INT             NOT NULL CHECK (planting_year BETWEEN 1900 AND 2100),
    planting_method     VARCHAR(30)     CHECK (planting_method IN (
                                            'BUD_GRAFT', 'STUMP', 'POLYBAG',
                                            'DIRECT_SEED', 'MARCOT'
                                        )),
    nursery_source_id   INT             REFERENCES nursery(nursery_id),

    tree_status         VARCHAR(20)     NOT NULL DEFAULT 'SEEDLING'
                                        REFERENCES lu_tree_status(status_code),
    health_rating       VARCHAR(10)     REFERENCES lu_health_rating(rating_code),

    current_girth_cm    NUMERIC(8,2),
    current_bark_mm     NUMERIC(6,2),
    bark_consumption_pct NUMERIC(5,2)           CHECK (bark_consumption_pct BETWEEN 0 AND 100),

    tapping_start_date  DATE,
    current_panel       VARCHAR(20),
    current_tapping_system VARCHAR(20)          REFERENCES lu_tapping_system(tapping_system_code),
    panels_exhausted    INT             DEFAULT 0 CHECK (panels_exhausted >= 0),

    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    mortality_date      DATE,
    mortality_cause_code VARCHAR(30)    REFERENCES lu_mortality_cause(cause_code),
    mortality_remarks   TEXT,

    remarks             TEXT,
    photo_url           VARCHAR(1000),

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

COMMENT ON TABLE tree IS
    'Individual rubber tree master record — the core entity for tree-level tracking. '
    'Each tree belongs to a field and optionally a row, has a clone identity, and '
    'progresses through lifecycle statuses from seedling to mature/tapping to eventual mortality.';

-- ============================================================================
-- SECTION 4: TREE IoT / NFC TAG REGISTRATION
-- ============================================================================

CREATE TABLE tree_tag (
    tag_id              BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    tag_uid             VARCHAR(100)    NOT NULL UNIQUE,
    tag_type_code       VARCHAR(20)     NOT NULL REFERENCES lu_tag_type(tag_type_code),

    installed_date      DATE            NOT NULL,
    installed_by        VARCHAR(100),
    deactivated_date    DATE,
    deactivation_reason VARCHAR(200),

    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    last_scanned_at     TIMESTAMPTZ,
    last_scanned_by     VARCHAR(100),
    total_scan_count    INT             NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_tag IS
    'NFC/RFID/QR tags physically attached to trees. '
    'Enables mobile scanning for instant tree identification in the field.';

-- ============================================================================
-- SECTION 5: TREE GROWTH MEASUREMENTS
-- ============================================================================

CREATE TABLE tree_growth_measurement (
    measurement_id      BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    parameter_code      VARCHAR(30)     NOT NULL REFERENCES lu_growth_parameter(parameter_code),
    measured_value      NUMERIC(10,2)   NOT NULL,
    measurement_unit    VARCHAR(30)     NOT NULL,

    measurement_date    DATE            NOT NULL,
    measurement_method  VARCHAR(30)     CHECK (measurement_method IN (
                                            'MANUAL_TAPE', 'DIGITAL_CALIPER',
                                            'LASER_RANGEFINDER', 'DRONE_LIDAR',
                                            'MOBILE_APP_PHOTO', 'IOT_SENSOR'
                                        )),

    is_below_threshold  BOOLEAN,
    is_above_threshold  BOOLEAN,

    measured_by         VARCHAR(100),
    remarks             TEXT,
    photo_url           VARCHAR(1000),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_growth_measurement IS
    'Time-series growth data for each tree — girth, bark thickness, height, canopy, yield, etc.';

-- ============================================================================
-- SECTION 6: BARK PANEL HISTORY
-- ============================================================================

CREATE TABLE tree_panel_history (
    panel_history_id    BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    panel_code          VARCHAR(20)     NOT NULL,
    panel_position       VARCHAR(10)     NOT NULL
                                        CHECK (panel_position IN ('LOW', 'HIGH')),
    panel_side           VARCHAR(10)     NOT NULL
                                        CHECK (panel_side IN ('INNER', 'OUTER')),

    tapping_system_code VARCHAR(20)     REFERENCES lu_tapping_system(tapping_system_code),

    opened_date         DATE            NOT NULL,
    closed_date         DATE,

    bark_thickness_at_open_mm  NUMERIC(6,2),
    bark_thickness_at_close_mm NUMERIC(6,2),
    bark_consumption_pct       NUMERIC(5,2)    CHECK (bark_consumption_pct BETWEEN 0 AND 100),

    avg_daily_yield_ml  NUMERIC(10,2),
    total_tapping_days  INT,

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'CLOSED', 'RESTING', 'DAMAGED')),

    has_tpd             BOOLEAN         NOT NULL DEFAULT FALSE,
    has_bark_rot        BOOLEAN         NOT NULL DEFAULT FALSE,

    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_tree_panel UNIQUE (tree_id, panel_code)
);

COMMENT ON TABLE tree_panel_history IS
    'Complete tapping panel history per tree. Tracks the sequential use of bark panels '
    '(BI-1 → BO-1 → BI-2 → BO-2 → HI-1 → HO-1 etc.), bark consumption, and panel-specific issues.';

-- ============================================================================
-- SECTION 7: TREE HEALTH INSPECTION
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

    health_rating       VARCHAR(10)     NOT NULL REFERENCES lu_health_rating(rating_code),

    canopy_score        INT             CHECK (canopy_score BETWEEN 1 AND 5),
    trunk_score         INT             CHECK (trunk_score BETWEEN 1 AND 5),
    bark_score          INT             CHECK (bark_score BETWEEN 1 AND 5),
    root_zone_score     INT             CHECK (root_zone_score BETWEEN 1 AND 5),

    leaf_condition      VARCHAR(30)     CHECK (leaf_condition IN (
                                            'FULL_CANOPY', 'PARTIAL_DEFOLIATION',
                                            'HEAVY_DEFOLIATION', 'WINTERING', 'REFOLIATION'
                                        )),
    latex_flow_status   VARCHAR(30)     CHECK (latex_flow_status IN (
                                            'NORMAL', 'REDUCED', 'NO_FLOW', 'EXCESSIVE', 'NOT_TAPPED'
                                        )),

    disease_detected    BOOLEAN         NOT NULL DEFAULT FALSE,
    primary_disease_id  INT             REFERENCES disease_master(disease_id),
    disease_severity    VARCHAR(20)     CHECK (disease_severity IN ('MILD', 'MODERATE', 'SEVERE')),

    ai_analysis_score   NUMERIC(5,2),
    ai_analysis_notes   TEXT,

    photo_urls          TEXT[],

    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_health_inspection IS
    'Periodic health assessments for individual trees — supports visual, instrument, drone, and AI-assisted inspection methods.';

-- ============================================================================
-- SECTION 8: TREE DISEASE INCIDENT
-- ============================================================================

CREATE TABLE tree_disease_incident (
    incident_id         BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),
    disease_id          INT             NOT NULL REFERENCES disease_master(disease_id),

    detected_date       DATE            NOT NULL,
    detected_by         VARCHAR(100),
    detection_method    VARCHAR(30)     CHECK (detection_method IN (
                                            'VISUAL_FIELD', 'HEALTH_INSPECTION',
                                            'AI_IMAGE_ANALYSIS', 'LAB_CONFIRMATION',
                                            'IOT_SENSOR', 'TAPPER_REPORT'
                                        )),

    severity            VARCHAR(20)     NOT NULL CHECK (severity IN ('MILD', 'MODERATE', 'SEVERE', 'TERMINAL')),
    affected_area_pct   NUMERIC(5,2)    CHECK (affected_area_pct BETWEEN 0 AND 100),
    spread_risk         VARCHAR(20)     CHECK (spread_risk IN ('LOW', 'MEDIUM', 'HIGH')),

    inspection_id       BIGINT          REFERENCES tree_health_inspection(inspection_id),

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'UNDER_TREATMENT', 'RESOLVED', 'CHRONIC', 'FATAL')),
    resolved_date       DATE,
    resolution_notes    TEXT,

    caused_tapping_stop BOOLEAN         NOT NULL DEFAULT FALSE,
    tapping_stop_date   DATE,
    tapping_resume_date DATE,

    photo_urls          TEXT[],

    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_disease_incident IS
    'Individual disease/pest occurrences per tree with severity tracking, treatment linkage, and tapping impact.';

-- ============================================================================
-- SECTION 9: TREE TREATMENT RECORD
-- ============================================================================

CREATE TABLE tree_treatment_record (
    treatment_id        BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    incident_id         BIGINT          REFERENCES tree_disease_incident(incident_id),

    treatment_code      VARCHAR(30)     NOT NULL REFERENCES lu_treatment_type(treatment_code),
    treatment_date      DATE            NOT NULL,

    product_name        VARCHAR(200),
    dosage_amount       NUMERIC(10,3),
    dosage_unit         VARCHAR(30),
    concentration_pct   NUMERIC(5,2),

    application_area    VARCHAR(50),
    applied_by          VARCHAR(100)    NOT NULL,
    application_duration_min INT,

    next_treatment_date DATE,
    treatment_round     INT             DEFAULT 1,

    outcome             VARCHAR(30)     CHECK (outcome IN (
                                            'EFFECTIVE', 'PARTIALLY_EFFECTIVE',
                                            'INEFFECTIVE', 'PENDING', 'ADVERSE_REACTION'
                                        )),
    outcome_assessed_date DATE,
    outcome_notes       TEXT,

    treatment_cost      NUMERIC(12,2),
    currency_code       VARCHAR(3)      DEFAULT 'USD',

    photo_url           VARCHAR(1000),
    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_treatment_record IS
    'All chemical, biological, and surgical treatments applied to trees — linked to disease incidents when curative.';

-- ============================================================================
-- SECTION 10: TREE MORTALITY RECORD
-- ============================================================================

CREATE TABLE tree_mortality_record (
    mortality_id        BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id) UNIQUE,

    mortality_date      DATE            NOT NULL,
    cause_code          VARCHAR(30)     NOT NULL REFERENCES lu_mortality_cause(cause_code),

    incident_id         BIGINT          REFERENCES tree_disease_incident(incident_id),

    age_at_death_years  INT,
    girth_at_death_cm   NUMERIC(8,2),
    was_tappable        BOOLEAN,
    last_panel_used     VARCHAR(20),

    tree_removed        BOOLEAN         NOT NULL DEFAULT FALSE,
    removal_date        DATE,
    replacement_planted BOOLEAN         NOT NULL DEFAULT FALSE,
    replacement_tree_id BIGINT          REFERENCES tree(tree_id),
    replacement_date    DATE,

    investigated_by     VARCHAR(100),
    investigation_notes TEXT,
    photo_urls          TEXT[],

    estimated_yield_loss_kg NUMERIC(10,2),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    reported_by         VARCHAR(100)
);

COMMENT ON TABLE tree_mortality_record IS
    'Detailed mortality record — one per dead/removed tree — with cause analysis, economic impact, and replacement tracking.';

-- ============================================================================
-- SECTION 11: TREE STATUS CHANGE LOG (Audit Trail)
-- ============================================================================

CREATE TABLE tree_status_change_log (
    log_id              BIGSERIAL       PRIMARY KEY,
    tree_id             BIGINT          NOT NULL REFERENCES tree(tree_id),

    change_date         DATE            NOT NULL,
    from_status         VARCHAR(20)     REFERENCES lu_tree_status(status_code),
    to_status           VARCHAR(20)     NOT NULL REFERENCES lu_tree_status(status_code),

    reason              TEXT,
    changed_by          VARCHAR(100),

    blockchain_tx_hash  VARCHAR(128),
    blockchain_block_no BIGINT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE tree_status_change_log IS
    'Immutable audit log of every tree status transition. Supports optional blockchain anchoring for tamper-proof records.';

-- ============================================================================
-- SECTION 12: FIELD-LEVEL TREE CENSUS SUMMARY
-- ============================================================================

CREATE TABLE tree_census_summary (
    census_id           SERIAL          PRIMARY KEY,
    field_id            INT             NOT NULL REFERENCES field(field_id),

    census_date         DATE            NOT NULL,
    census_year         INT             NOT NULL,

    total_trees         INT             NOT NULL CHECK (total_trees >= 0),
    live_trees          INT             NOT NULL CHECK (live_trees >= 0),
    tappable_trees      INT             NOT NULL CHECK (tappable_trees >= 0),
    trees_under_tapping INT             NOT NULL CHECK (trees_under_tapping >= 0),
    immature_trees      INT             NOT NULL CHECK (immature_trees >= 0),
    diseased_trees      INT             NOT NULL CHECK (diseased_trees >= 0),
    dead_trees_ytd      INT             NOT NULL DEFAULT 0,

    mortality_rate_pct  NUMERIC(5,2),
    tapping_utilization_pct NUMERIC(5,2),
    stand_per_ha        NUMERIC(8,2),

    avg_girth_cm        NUMERIC(8,2),
    min_girth_cm        NUMERIC(8,2),
    max_girth_cm        NUMERIC(8,2),

    conducted_by        VARCHAR(100),
    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_census_field_date UNIQUE (field_id, census_date)
);

COMMENT ON TABLE tree_census_summary IS
    'Periodic field-level tree census — aggregated counts, mortality rates, and growth statistics.';
