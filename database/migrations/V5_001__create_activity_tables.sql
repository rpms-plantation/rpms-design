-- ============================================================================
-- V5_001 — Module 5 (Daily Activity Monitoring) — CREATE TABLE statements
-- Source: database/module-5-daily-activity/daily_activity_monitoring_ddl.sql
-- Prerequisite: V1 (Module 1 — plantation, division, field, nursery), V4
-- (Module 4 — worker, gang) must have already run. Module 3 (tapping_task)
-- is referenced by ID only (tapping_task_id) — no FK, no hard dependency.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Activity Category Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_activity_category (
    category_code   VARCHAR(30)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.2 Activity Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_activity_type (
    activity_type_code  VARCHAR(40)     PRIMARY KEY,
    activity_type_name  VARCHAR(200)    NOT NULL,
    category_code       VARCHAR(30)     NOT NULL REFERENCES lu_activity_category(category_code),

    requires_field      BOOLEAN         NOT NULL DEFAULT TRUE,
    requires_materials  BOOLEAN         NOT NULL DEFAULT FALSE,
    requires_photo      BOOLEAN         NOT NULL DEFAULT FALSE,
    requires_gps        BOOLEAN         NOT NULL DEFAULT TRUE,

    standard_duration_hours NUMERIC(4,1),
    unit_of_measure     VARCHAR(30),

    description         VARCHAR(500),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE lu_activity_type IS
    'Specific plantation activity types — each linked to a category and defining measurement unit, material needs, and standard durations.';

-- ----------------------------------------------------------------------------
-- 1.3 Activity Status Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_activity_status (
    status_code     VARCHAR(20)     PRIMARY KEY,
    status_name     VARCHAR(100)    NOT NULL,
    is_terminal     BOOLEAN         NOT NULL DEFAULT FALSE,
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.4 Activity Priority Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_activity_priority (
    priority_code   VARCHAR(10)     PRIMARY KEY,
    priority_name   VARCHAR(50)     NOT NULL,
    priority_level  INT             NOT NULL CHECK (priority_level BETWEEN 1 AND 5),
    color_hex       VARCHAR(7),
    description     VARCHAR(200),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.5 Material / Input Master
-- ----------------------------------------------------------------------------
CREATE TABLE material_master (
    material_id     SERIAL          PRIMARY KEY,
    material_code   VARCHAR(30)     NOT NULL UNIQUE,
    material_name   VARCHAR(200)    NOT NULL,
    material_category VARCHAR(30)   NOT NULL
                                    CHECK (material_category IN (
                                        'FERTILIZER', 'HERBICIDE', 'FUNGICIDE',
                                        'INSECTICIDE', 'STIMULANT', 'PLANTING_MATERIAL',
                                        'FUEL', 'EQUIPMENT', 'CONSUMABLE', 'OTHER'
                                    )),
    default_unit    VARCHAR(20)     NOT NULL,
    unit_cost       NUMERIC(12,2),
    currency_code   VARCHAR(3)      DEFAULT 'LKR',

    is_hazardous    BOOLEAN         NOT NULL DEFAULT FALSE,
    safety_data_url VARCHAR(1000),

    min_stock_level NUMERIC(10,2),

    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE material_master IS
    'Catalog of all materials and inputs used in plantation activities — fertilizers, chemicals, planting materials, fuel, equipment.';

-- ----------------------------------------------------------------------------
-- 1.6 Inspection Checklist Item Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_inspection_checklist_item (
    item_code       VARCHAR(30)     PRIMARY KEY,
    item_name       VARCHAR(200)    NOT NULL,
    category_code   VARCHAR(30)     NOT NULL REFERENCES lu_activity_category(category_code),
    check_type      VARCHAR(20)     NOT NULL
                                    CHECK (check_type IN ('YES_NO', 'RATING_1_5', 'NUMERIC', 'TEXT')),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ============================================================================
-- SECTION 2: DAILY WORK PLAN
-- ============================================================================
CREATE TABLE daily_work_plan (
    plan_id             SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),

    plan_date           DATE            NOT NULL,
    plan_name           VARCHAR(200),

    planned_by          INT             REFERENCES worker(worker_id),
    planned_at          TIMESTAMPTZ,

    status              VARCHAR(20)     NOT NULL DEFAULT 'DRAFT'
                                        CHECK (status IN ('DRAFT', 'PUBLISHED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),

    weather_forecast    VARCHAR(200),
    suitable_for_field_work BOOLEAN     DEFAULT TRUE,

    total_activities_planned INT        DEFAULT 0,
    total_activities_completed INT      DEFAULT 0,
    total_workers_deployed INT          DEFAULT 0,
    completion_rate_pct NUMERIC(5,2),

    ai_suggested_priorities TEXT,

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),

    CONSTRAINT uq_daily_plan UNIQUE (plantation_id, division_id, plan_date)
);

COMMENT ON TABLE daily_work_plan IS
    'Top-level daily work plan per plantation/division — acts as a container for all activities planned for a single day.';

-- ============================================================================
-- SECTION 3: DAILY ACTIVITY — CORE entity
-- ============================================================================
CREATE TABLE daily_activity (
    activity_id         BIGSERIAL       PRIMARY KEY,

    plan_id             INT             REFERENCES daily_work_plan(plan_id),

    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    field_id            INT             REFERENCES field(field_id),
    nursery_id          INT             REFERENCES nursery(nursery_id),

    activity_type_code  VARCHAR(40)     NOT NULL REFERENCES lu_activity_type(activity_type_code),
    category_code       VARCHAR(30)     NOT NULL REFERENCES lu_activity_category(category_code),
    activity_description TEXT,

    activity_date       DATE            NOT NULL,
    assigned_worker_id  INT             REFERENCES worker(worker_id),
    assigned_gang_id    INT             REFERENCES gang(gang_id),
    assigned_by         INT             REFERENCES worker(worker_id),

    priority_code       VARCHAR(10)     NOT NULL DEFAULT 'MEDIUM'
                                        REFERENCES lu_activity_priority(priority_code),
    planned_start_time  TIME,
    planned_end_time    TIME,
    planned_duration_hours NUMERIC(4,1),

    status              VARCHAR(20)     NOT NULL DEFAULT 'PLANNED'
                                        REFERENCES lu_activity_status(status_code),

    actual_start_time   TIMESTAMPTZ,
    actual_end_time     TIMESTAMPTZ,
    actual_duration_hours NUMERIC(5,2),

    workers_deployed    INT             DEFAULT 1 CHECK (workers_deployed >= 0),
    man_days            NUMERIC(6,2),

    target_quantity     NUMERIC(12,2),
    actual_quantity     NUMERIC(12,2),
    quantity_unit       VARCHAR(30),
    completion_pct      NUMERIC(5,2)    CHECK (completion_pct BETWEEN 0 AND 100),

    -- Cross-reference to Module 3 (for tapping activities only) — ID reference
    -- only, no FK (M5 does not own/depend on M3's schema per single-writer rule)
    tapping_task_id     BIGINT,

    start_gps_lat       NUMERIC(10,7),
    start_gps_lon       NUMERIC(10,7),
    start_gps_point     GEOMETRY(Point, 4326),
    end_gps_lat         NUMERIC(10,7),
    end_gps_lon         NUMERIC(10,7),
    gps_route           GEOMETRY(LineString, 4326),

    weather_condition   VARCHAR(30),
    rainfall_mm         NUMERIC(6,2),

    cancel_reason       TEXT,
    postponed_to_date   DATE,

    supervisor_id       INT             REFERENCES worker(worker_id),
    supervisor_verified BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_at         TIMESTAMPTZ,
    supervisor_remarks  TEXT,

    ai_anomaly_flag     BOOLEAN         DEFAULT FALSE,
    ai_anomaly_reason   TEXT,
    ai_efficiency_score NUMERIC(5,2),

    photo_urls          TEXT[],

    remarks             TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

COMMENT ON TABLE daily_activity IS
    'Core operational activity record — covers ALL plantation work types with GPS tracking, '
    'material usage linkage, supervisor verification, and AI anomaly detection.';

-- ============================================================================
-- SECTION 4: ACTIVITY WORKER ASSIGNMENT
-- ============================================================================
CREATE TABLE activity_worker_assignment (
    assignment_id       BIGSERIAL       PRIMARY KEY,
    activity_id         BIGINT          NOT NULL REFERENCES daily_activity(activity_id),
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),

    role_in_activity    VARCHAR(30)     CHECK (role_in_activity IN (
                                            'LEAD', 'WORKER', 'HELPER', 'SUPERVISOR', 'TRAINEE'
                                        )),

    check_in_time       TIMESTAMPTZ,
    check_out_time      TIMESTAMPTZ,
    hours_worked        NUMERIC(4,2),

    individual_quantity NUMERIC(10,2),
    quantity_unit       VARCHAR(30),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_activity_worker UNIQUE (activity_id, worker_id)
);

COMMENT ON TABLE activity_worker_assignment IS
    'Individual worker assignments within a multi-person activity — tracks individual check-in/out and output.';

-- ============================================================================
-- SECTION 5: ACTIVITY MATERIAL USAGE
-- ============================================================================
CREATE TABLE activity_material_usage (
    usage_id            BIGSERIAL       PRIMARY KEY,
    activity_id         BIGINT          NOT NULL REFERENCES daily_activity(activity_id),
    material_id         INT             NOT NULL REFERENCES material_master(material_id),

    planned_quantity    NUMERIC(10,3),
    actual_quantity     NUMERIC(10,3)   NOT NULL CHECK (actual_quantity >= 0),
    quantity_unit       VARCHAR(20)     NOT NULL,

    unit_cost           NUMERIC(12,2),
    total_cost          NUMERIC(12,2),
    currency_code       VARCHAR(3)      DEFAULT 'LKR',

    batch_number        VARCHAR(50),
    store_issue_ref     VARCHAR(50),

    concentration_pct   NUMERIC(5,2),
    application_rate    VARCHAR(50),

    variance_pct        NUMERIC(6,2),
    variance_reason     TEXT,

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE activity_material_usage IS
    'Materials and inputs consumed during each activity — fertilizers, chemicals, fuel, equipment with variance tracking.';

-- ============================================================================
-- SECTION 6: ACTIVITY PHOTO EVIDENCE
-- ============================================================================
CREATE TABLE activity_photo_evidence (
    photo_id            BIGSERIAL       PRIMARY KEY,
    activity_id         BIGINT          NOT NULL REFERENCES daily_activity(activity_id),

    photo_url           VARCHAR(1000)   NOT NULL,
    thumbnail_url       VARCHAR(1000),

    photo_type          VARCHAR(30)     NOT NULL
                                        CHECK (photo_type IN (
                                            'BEFORE', 'DURING', 'AFTER', 'ISSUE',
                                            'EQUIPMENT', 'MATERIAL', 'WEATHER', 'OTHER'
                                        )),

    captured_at         TIMESTAMPTZ     NOT NULL,
    captured_by         INT             REFERENCES worker(worker_id),

    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    ai_analyzed         BOOLEAN         DEFAULT FALSE,
    ai_analysis_result  JSONB,
    ai_confidence_score NUMERIC(5,2),
    ai_flagged_issues   TEXT[],

    caption             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE activity_photo_evidence IS
    'Geo-tagged photo evidence per activity — before/during/after shots with AI-powered analysis results stored as JSONB.';

-- ============================================================================
-- SECTION 7: SUPERVISOR INSPECTION
-- ============================================================================
CREATE TABLE supervisor_inspection (
    inspection_id       SERIAL          PRIMARY KEY,

    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    field_id            INT             REFERENCES field(field_id),
    activity_id         BIGINT          REFERENCES daily_activity(activity_id),

    inspector_id        INT             NOT NULL REFERENCES worker(worker_id),
    inspection_date     DATE            NOT NULL,
    inspection_time     TIMESTAMPTZ,

    inspection_type     VARCHAR(30)     NOT NULL
                                        CHECK (inspection_type IN (
                                            'ROUTINE', 'SPOT_CHECK', 'QUALITY_AUDIT',
                                            'SAFETY_WALK', 'POST_ACTIVITY', 'COMPLAINT'
                                        )),

    overall_rating      INT             NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),

    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),

    ar_assisted         BOOLEAN         NOT NULL DEFAULT FALSE,
    ar_device_id        VARCHAR(50),

    ai_summary          TEXT,

    findings            TEXT,
    corrective_actions  TEXT,
    follow_up_date      DATE,
    follow_up_completed BOOLEAN         DEFAULT FALSE,

    photo_urls          TEXT[],

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE supervisor_inspection IS
    'Supervisor field inspections — routine, spot checks, quality audits with checklist scoring, AR-assisted, and AI summary generation.';

-- ============================================================================
-- SECTION 8: INSPECTION CHECKLIST RESPONSE
-- ============================================================================
CREATE TABLE inspection_checklist_response (
    response_id         SERIAL          PRIMARY KEY,
    inspection_id       INT             NOT NULL REFERENCES supervisor_inspection(inspection_id),
    item_code           VARCHAR(30)     NOT NULL REFERENCES lu_inspection_checklist_item(item_code),

    yes_no_value        BOOLEAN,
    rating_value        INT             CHECK (rating_value BETWEEN 1 AND 5),
    numeric_value        NUMERIC(10,2),
    text_value           TEXT,

    remarks             TEXT,
    photo_url            VARCHAR(1000),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_inspection_item UNIQUE (inspection_id, item_code)
);

COMMENT ON TABLE inspection_checklist_response IS
    'Individual checklist item responses within a supervisor inspection — yes/no, ratings, numerics, or text.';

-- ============================================================================
-- SECTION 9: DAILY ACTIVITY SUMMARY (end-of-day rollup)
-- ============================================================================
CREATE TABLE daily_activity_summary (
    summary_id          SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    summary_date        DATE            NOT NULL,

    total_planned       INT             NOT NULL DEFAULT 0,
    total_completed     INT             NOT NULL DEFAULT 0,
    total_partial       INT             NOT NULL DEFAULT 0,
    total_cancelled     INT             NOT NULL DEFAULT 0,
    total_postponed     INT             NOT NULL DEFAULT 0,

    total_workers_deployed INT          DEFAULT 0,
    total_man_days      NUMERIC(8,2)    DEFAULT 0,

    tapping_area_ha     NUMERIC(10,2)   DEFAULT 0,
    maintenance_area_ha NUMERIC(10,2)   DEFAULT 0,
    manuring_area_ha    NUMERIC(10,2)   DEFAULT 0,
    spraying_area_ha    NUMERIC(10,2)   DEFAULT 0,
    nursery_plants      INT             DEFAULT 0,
    replanting_trees    INT             DEFAULT 0,

    total_material_cost NUMERIC(12,2)   DEFAULT 0,
    currency_code       VARCHAR(3)      DEFAULT 'LKR',

    avg_inspection_rating NUMERIC(3,1),
    activities_with_anomalies INT       DEFAULT 0,

    weather_condition   VARCHAR(30),
    rainfall_mm         NUMERIC(6,2),
    field_work_hours_lost NUMERIC(4,1)  DEFAULT 0,

    overall_completion_pct NUMERIC(5,2),

    ai_daily_summary    TEXT,
    ai_recommendations  TEXT,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_daily_summary UNIQUE (plantation_id, division_id, summary_date)
);

COMMENT ON TABLE daily_activity_summary IS
    'End-of-day rollup of all activities per plantation/division with workforce, output, cost, quality, and AI insights.';
