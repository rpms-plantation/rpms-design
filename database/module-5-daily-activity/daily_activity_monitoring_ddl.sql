-- ============================================================================
-- RUBBER PLANTATION MANAGEMENT SYSTEM
-- Module 5: DAILY ACTIVITY MONITORING
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for daily activity planning, task assignment across
--              all plantation operations (not just tapping), work progress
--              tracking, material/input usage, supervisor inspections, photo
--              evidence, GPS route tracking, daily work summaries, and
--              AI-powered anomaly detection.
--
-- Scope: While Module 3 focuses on tapping-specific tasks, this module covers
--        ALL plantation activities: field maintenance (weeding, manuring,
--        spraying), nursery operations, replanting, road maintenance, factory
--        work, infrastructure upkeep, and general estate tasks.
--
-- Dependencies:
--   Module 1: plantation, division, field, nursery
--   Module 3: tapping_task (cross-reference for tapping activities)
--   Module 4: worker, gang
-- ============================================================================


-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Activity Category Lookup (broad groupings)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_activity_category (
    category_code   VARCHAR(30)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    description     VARCHAR(500),
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_activity_category (category_code, category_name, display_order, description) VALUES
    ('TAPPING',         'Tapping & Latex Collection',       1,  'Rubber tapping and latex collection — detail in Module 3'),
    ('FIELD_MAINT',     'Field Maintenance',                2,  'Weeding, clearing, drain maintenance, path upkeep'),
    ('MANURING',        'Manuring & Fertilizer Application',3,  'Chemical and organic fertilizer application'),
    ('SPRAYING',        'Pest & Disease Spraying',          4,  'Chemical spraying, fungicide, herbicide application'),
    ('NURSERY_OPS',     'Nursery Operations',               5,  'Nursery planting, budding, maintenance, dispatch'),
    ('REPLANTING',      'Replanting & New Planting',        6,  'Felling, clearing, lining, holing, planting'),
    ('STIMULATION',     'Stimulant Application',            7,  'Ethephon and other yield stimulant application'),
    ('HARVESTING',      'Timber Harvesting',                8,  'Felling, logging, and timber extraction'),
    ('ROAD_MAINT',      'Road & Drain Maintenance',         9,  'Estate road repair, culvert clearing, drainage'),
    ('FACTORY_OPS',     'Factory / Processing',             10, 'Latex processing, sheet making, smoking, packing'),
    ('TRANSPORT',       'Transport & Logistics',            11, 'Latex transport, material delivery, personnel'),
    ('INFRASTRUCTURE',  'Infrastructure & Building',        12, 'Building maintenance, water supply, electricity'),
    ('ADMIN',           'Administrative Work',              13, 'Office work, record keeping, meetings'),
    ('INSPECTION',      'Supervisory Inspection',           14, 'Field checks, quality audits, compliance walks'),
    ('OTHER',           'Other / Miscellaneous',            15, 'Any activity not classified above');

-- ----------------------------------------------------------------------------
-- 1.2 Activity Type Lookup (specific task types within categories)
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
    unit_of_measure     VARCHAR(30),    -- What is measured: HECTARE, TREE, KG, METER, TRIP, COUNT
    
    description         VARCHAR(500),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_activity_type (activity_type_code, activity_type_name, category_code, requires_materials, unit_of_measure, standard_duration_hours) VALUES
    -- Field Maintenance
    ('WEEDING_MANUAL',      'Manual Weeding (Slashing)',            'FIELD_MAINT',  FALSE,  'HECTARE',  6),
    ('WEEDING_CHEMICAL',    'Chemical Weeding (Herbicide)',         'FIELD_MAINT',  TRUE,   'HECTARE',  4),
    ('CIRCLE_WEEDING',      'Circle Weeding Around Trees',          'FIELD_MAINT',  FALSE,  'TREE',     6),
    ('DRAIN_CLEARING',      'Drain / Waterway Clearing',            'FIELD_MAINT',  FALSE,  'METER',    6),
    ('PATH_CLEARING',       'Tapping Path Clearing',                'FIELD_MAINT',  FALSE,  'HECTARE',  5),
    ('COVER_CROP_MAINT',    'Cover Crop Maintenance',               'FIELD_MAINT',  FALSE,  'HECTARE',  5),
    -- Manuring
    ('MANURE_INORGANIC',    'Inorganic Fertilizer Application',     'MANURING',     TRUE,   'HECTARE',  5),
    ('MANURE_ORGANIC',      'Organic Manure Application',           'MANURING',     TRUE,   'HECTARE',  6),
    ('MANURE_ROCKPHOS',     'Rock Phosphate Application',           'MANURING',     TRUE,   'HECTARE',  5),
    ('MANURE_YOUNG',        'Young Rubber Manuring',                'MANURING',     TRUE,   'TREE',     6),
    -- Spraying
    ('SPRAY_FUNGICIDE',     'Fungicide Spraying',                   'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_HERBICIDE',     'Herbicide Application',                'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_INSECTICIDE',   'Insecticide Spraying',                 'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_ABNORMAL_LF',   'Abnormal Leaf Fall Spraying (Aerial)', 'SPRAYING',     TRUE,   'HECTARE',  2),
    -- Nursery
    ('NURSERY_SEEDING',     'Nursery Seed Planting',                'NURSERY_OPS',  TRUE,   'COUNT',    6),
    ('NURSERY_BUDDING',     'Bud Grafting',                         'NURSERY_OPS',  TRUE,   'COUNT',    6),
    ('NURSERY_WATERING',    'Nursery Watering',                     'NURSERY_OPS',  FALSE,  'COUNT',    3),
    ('NURSERY_DISPATCH',    'Plant Dispatch to Field',              'NURSERY_OPS',  FALSE,  'COUNT',    4),
    -- Replanting
    ('FELLING',             'Tree Felling (Old Rubber)',             'REPLANTING',   TRUE,   'TREE',     6),
    ('CLEARING',            'Land Clearing Post-Felling',           'REPLANTING',   FALSE,  'HECTARE',  8),
    ('LINING_HOLING',       'Lining & Holing for Planting',         'REPLANTING',   FALSE,  'TREE',     6),
    ('NEW_PLANTING',        'New Planting / Replanting',            'REPLANTING',   TRUE,   'TREE',     6),
    -- Stimulation
    ('ETHEPHON_APP',        'Ethephon Stimulant Application',       'STIMULATION',  TRUE,   'TREE',     5),
    -- Road & Infrastructure
    ('ROAD_GRADING',        'Road Grading / Leveling',              'ROAD_MAINT',   FALSE,  'METER',    6),
    ('CULVERT_REPAIR',      'Culvert / Bridge Repair',              'ROAD_MAINT',   TRUE,   'COUNT',    6),
    ('BUILDING_MAINT',      'Building Maintenance',                 'INFRASTRUCTURE',TRUE,  'COUNT',    8),
    -- Factory
    ('SHEET_MAKING',        'Latex Sheet Making',                   'FACTORY_OPS',  TRUE,   'KG',       8),
    ('SMOKING',             'Sheet Smoking',                        'FACTORY_OPS',  TRUE,   'KG',       8),
    ('CREPE_PROCESSING',    'Crepe Rubber Processing',              'FACTORY_OPS',  TRUE,   'KG',       8),
    -- Transport
    ('LATEX_TRANSPORT',     'Latex Transport to Factory',           'TRANSPORT',    FALSE,  'TRIP',     4),
    ('MATERIAL_DELIVERY',   'Material / Input Delivery',            'TRANSPORT',    FALSE,  'TRIP',     4),
    -- Inspection
    ('FIELD_INSPECTION',    'Field / Block Inspection',             'INSPECTION',   FALSE,  'HECTARE',  3),
    ('TAP_QUALITY_AUDIT',   'Tapping Quality Audit',                'INSPECTION',   FALSE,  'TREE',     3),
    ('NURSERY_INSPECTION',  'Nursery Inspection',                   'INSPECTION',   FALSE,  'COUNT',    2);

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

INSERT INTO lu_activity_status (status_code, status_name, is_terminal, display_order) VALUES
    ('PLANNED',         'Planned',              FALSE,  1),
    ('ASSIGNED',        'Assigned',             FALSE,  2),
    ('IN_PROGRESS',     'In Progress',          FALSE,  3),
    ('COMPLETED',       'Completed',            TRUE,   4),
    ('PARTIAL',         'Partially Completed',  TRUE,   5),
    ('CANCELLED',       'Cancelled',            TRUE,   6),
    ('POSTPONED',       'Postponed',            FALSE,  7),
    ('BLOCKED',         'Blocked / On Hold',    FALSE,  8);

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

INSERT INTO lu_activity_priority (priority_code, priority_name, priority_level, color_hex) VALUES
    ('CRITICAL',    'Critical',     5,  '#EF4444'),
    ('HIGH',        'High',         4,  '#F97316'),
    ('MEDIUM',      'Medium',       3,  '#EAB308'),
    ('LOW',         'Low',          2,  '#22C55E'),
    ('ROUTINE',     'Routine',      1,  '#6B7280');

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
    default_unit    VARCHAR(20)     NOT NULL,   -- KG, L, ML, PIECE, PACKET, BAG
    unit_cost       NUMERIC(12,2),
    currency_code   VARCHAR(3)      DEFAULT 'LKR',
    
    -- Safety
    is_hazardous    BOOLEAN         NOT NULL DEFAULT FALSE,
    safety_data_url VARCHAR(1000),
    
    min_stock_level NUMERIC(10,2),
    
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

INSERT INTO material_master (material_code, material_name, material_category, default_unit, is_hazardous) VALUES
    ('NPK_12_14_12',   'NPK 12:14:12 Fertilizer',         'FERTILIZER',       'KG',   FALSE),
    ('UREA',           'Urea (46% N)',                     'FERTILIZER',       'KG',   FALSE),
    ('ROCKPHOS',       'Rock Phosphate',                   'FERTILIZER',       'KG',   FALSE),
    ('DOLOMITE',       'Dolomite Limestone',               'FERTILIZER',       'KG',   FALSE),
    ('GLYPHOSATE',     'Glyphosate Herbicide',             'HERBICIDE',        'L',    TRUE),
    ('PARAQUAT',       'Paraquat Herbicide',               'HERBICIDE',        'L',    TRUE),
    ('MANCOZEB',       'Mancozeb Fungicide',               'FUNGICIDE',        'KG',   TRUE),
    ('HEXACONAZOLE',   'Hexaconazole Fungicide',           'FUNGICIDE',        'L',    TRUE),
    ('TRIDEMORPH',     'Tridemorph Fungicide',             'FUNGICIDE',        'L',    TRUE),
    ('FIPRONIL',       'Fipronil Insecticide',             'INSECTICIDE',      'L',    TRUE),
    ('ETHEPHON_2.5',   'Ethephon 2.5% Stimulant',          'STIMULANT',        'L',    TRUE),
    ('POLYBAG_PLANT',  'Polybag Seedling',                 'PLANTING_MATERIAL','PIECE',FALSE),
    ('STUMP_PLANT',    'Budded Stump',                     'PLANTING_MATERIAL','PIECE',FALSE),
    ('DIESEL',         'Diesel Fuel',                      'FUEL',             'L',    FALSE),
    ('TAP_KNIFE',      'Tapping Knife Blade',              'EQUIPMENT',        'PIECE',FALSE);

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

INSERT INTO lu_inspection_checklist_item (item_code, item_name, category_code, check_type) VALUES
    ('CUT_ANGLE_OK',        'Tapping cut angle within 30° tolerance',       'TAPPING',      'YES_NO'),
    ('CUT_DEPTH_OK',        'Cut depth not exceeding 1.5mm from cambium',   'TAPPING',      'YES_NO'),
    ('BARK_CONSUMPTION_OK', 'Bark consumption within standard',             'TAPPING',      'YES_NO'),
    ('PANEL_MARKING_OK',    'Panel boundaries clearly marked',              'TAPPING',      'YES_NO'),
    ('CUP_POSITION_OK',     'Collection cup properly positioned',           'TAPPING',      'YES_NO'),
    ('WEED_FREE',           'Field free of weed growth',                    'FIELD_MAINT',  'RATING_1_5'),
    ('DRAIN_CLEAR',         'Drains and waterways clear',                   'FIELD_MAINT',  'RATING_1_5'),
    ('PATH_ACCESSIBLE',     'Tapping paths accessible',                     'FIELD_MAINT',  'YES_NO'),
    ('MANURE_APPLIED',      'Fertilizer applied at correct rate',           'MANURING',     'YES_NO'),
    ('MANURE_PLACEMENT',    'Fertilizer placed in correct zone',            'MANURING',     'RATING_1_5'),
    ('SPRAY_COVERAGE',      'Spray coverage adequate',                      'SPRAYING',     'RATING_1_5'),
    ('SPRAY_PPE',           'Workers wearing correct PPE',                  'SPRAYING',     'YES_NO'),
    ('NURSERY_HEALTH',      'Nursery plants healthy',                       'NURSERY_OPS',  'RATING_1_5'),
    ('SURVIVAL_RATE',       'Planting survival rate check',                 'REPLANTING',   'NUMERIC'),
    ('ROAD_CONDITION',      'Road surface condition',                       'ROAD_MAINT',   'RATING_1_5');


-- ============================================================================
-- SECTION 2: DAILY WORK PLAN — the daily operational plan for a plantation
-- ============================================================================

CREATE TABLE daily_work_plan (
    plan_id             SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    
    plan_date           DATE            NOT NULL,
    plan_name           VARCHAR(200),
    
    -- Planning
    planned_by          INT             REFERENCES worker(worker_id),
    planned_at          TIMESTAMPTZ,
    
    -- Status
    status              VARCHAR(20)     NOT NULL DEFAULT 'DRAFT'
                                        CHECK (status IN ('DRAFT', 'PUBLISHED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    
    -- Weather context
    weather_forecast    VARCHAR(200),
    suitable_for_field_work BOOLEAN     DEFAULT TRUE,
    
    -- Summary (populated at end of day)
    total_activities_planned INT        DEFAULT 0,
    total_activities_completed INT      DEFAULT 0,
    total_workers_deployed INT          DEFAULT 0,
    completion_rate_pct NUMERIC(5,2),
    
    -- AI Planning
    ai_suggested_priorities TEXT,       -- AI-generated priority suggestions
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    
    CONSTRAINT uq_daily_plan UNIQUE (plantation_id, division_id, plan_date)
);

CREATE INDEX idx_plan_plantation ON daily_work_plan(plantation_id);
CREATE INDEX idx_plan_date ON daily_work_plan(plan_date);
CREATE INDEX idx_plan_status ON daily_work_plan(status);

COMMENT ON TABLE daily_work_plan IS 
    'Top-level daily work plan per plantation/division — acts as a container for all activities planned for a single day.';


-- ============================================================================
-- SECTION 3: DAILY ACTIVITY — individual activity records
-- This is the CORE entity of the module
-- ============================================================================

CREATE TABLE daily_activity (
    activity_id         BIGSERIAL       PRIMARY KEY,
    
    -- Plan context
    plan_id             INT             REFERENCES daily_work_plan(plan_id),
    
    -- Location
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    field_id            INT             REFERENCES field(field_id),
    nursery_id          INT             REFERENCES nursery(nursery_id),
    
    -- Activity Type
    activity_type_code  VARCHAR(40)     NOT NULL REFERENCES lu_activity_type(activity_type_code),
    category_code       VARCHAR(30)     NOT NULL REFERENCES lu_activity_category(category_code),
    activity_description TEXT,           -- Free text for additional context
    
    -- Assignment
    activity_date       DATE            NOT NULL,
    assigned_worker_id  INT             REFERENCES worker(worker_id),
    assigned_gang_id    INT             REFERENCES gang(gang_id),
    assigned_by         INT             REFERENCES worker(worker_id),
    
    -- Priority & Scheduling
    priority_code       VARCHAR(10)     NOT NULL DEFAULT 'MEDIUM'
                                        REFERENCES lu_activity_priority(priority_code),
    planned_start_time  TIME,
    planned_end_time    TIME,
    planned_duration_hours NUMERIC(4,1),
    
    -- Status
    status              VARCHAR(20)     NOT NULL DEFAULT 'PLANNED'
                                        REFERENCES lu_activity_status(status_code),
    
    -- Execution Tracking
    actual_start_time   TIMESTAMPTZ,
    actual_end_time     TIMESTAMPTZ,
    actual_duration_hours NUMERIC(5,2),
    
    -- Workforce
    workers_deployed    INT             DEFAULT 1 CHECK (workers_deployed >= 0),
    man_days            NUMERIC(6,2),   -- workers_deployed × hours / standard_day
    
    -- Output / Quantity
    target_quantity     NUMERIC(12,2),
    actual_quantity     NUMERIC(12,2),
    quantity_unit       VARCHAR(30),    -- HECTARE, TREE, KG, METER, TRIP, COUNT
    completion_pct      NUMERIC(5,2)    CHECK (completion_pct BETWEEN 0 AND 100),
    
    -- Cross-reference to Module 3 (for tapping activities only)
    tapping_task_id     BIGINT,         -- Links to tapping_task(task_id) if category = TAPPING
    
    -- GPS Tracking
    start_gps_lat       NUMERIC(10,7),
    start_gps_lon       NUMERIC(10,7),
    start_gps_point     GEOMETRY(Point, 4326),
    end_gps_lat         NUMERIC(10,7),
    end_gps_lon         NUMERIC(10,7),
    gps_route           GEOMETRY(LineString, 4326),  -- Full GPS trail during activity
    
    -- Weather at activity time
    weather_condition   VARCHAR(30),
    rainfall_mm         NUMERIC(6,2),
    
    -- Cancellation / Postponement
    cancel_reason       TEXT,
    postponed_to_date   DATE,
    
    -- Supervisor
    supervisor_id       INT             REFERENCES worker(worker_id),
    supervisor_verified BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_at         TIMESTAMPTZ,
    supervisor_remarks  TEXT,
    
    -- AI Analysis
    ai_anomaly_flag     BOOLEAN         DEFAULT FALSE,
    ai_anomaly_reason   TEXT,
    ai_efficiency_score NUMERIC(5,2),   -- 0-100 AI-estimated efficiency
    
    -- Evidence
    photo_urls          TEXT[],
    
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

CREATE INDEX idx_activity_plan ON daily_activity(plan_id);
CREATE INDEX idx_activity_plantation ON daily_activity(plantation_id);
CREATE INDEX idx_activity_field ON daily_activity(field_id);
CREATE INDEX idx_activity_date ON daily_activity(activity_date);
CREATE INDEX idx_activity_type ON daily_activity(activity_type_code);
CREATE INDEX idx_activity_category ON daily_activity(category_code);
CREATE INDEX idx_activity_worker ON daily_activity(assigned_worker_id);
CREATE INDEX idx_activity_gang ON daily_activity(assigned_gang_id);
CREATE INDEX idx_activity_status ON daily_activity(status);
CREATE INDEX idx_activity_priority ON daily_activity(priority_code);
CREATE INDEX idx_activity_supervisor ON daily_activity(supervisor_id);
CREATE INDEX idx_activity_date_status ON daily_activity(activity_date, status);
CREATE INDEX idx_activity_gps ON daily_activity USING GIST(start_gps_point);
CREATE INDEX idx_activity_route ON daily_activity USING GIST(gps_route);
CREATE INDEX idx_activity_tapping ON daily_activity(tapping_task_id) WHERE tapping_task_id IS NOT NULL;
CREATE INDEX idx_activity_anomaly ON daily_activity(ai_anomaly_flag) WHERE ai_anomaly_flag = TRUE;

COMMENT ON TABLE daily_activity IS 
    'Core operational activity record — covers ALL plantation work types with GPS tracking, '
    'material usage linkage, supervisor verification, and AI anomaly detection.';


-- ============================================================================
-- SECTION 4: ACTIVITY WORKER ASSIGNMENT
-- When multiple workers are assigned to a single activity
-- ============================================================================

CREATE TABLE activity_worker_assignment (
    assignment_id       BIGSERIAL       PRIMARY KEY,
    activity_id         BIGINT          NOT NULL REFERENCES daily_activity(activity_id),
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    
    role_in_activity    VARCHAR(30)     CHECK (role_in_activity IN (
                                            'LEAD', 'WORKER', 'HELPER', 'SUPERVISOR', 'TRAINEE'
                                        )),
    
    -- Individual tracking
    check_in_time       TIMESTAMPTZ,
    check_out_time      TIMESTAMPTZ,
    hours_worked        NUMERIC(4,2),
    
    -- Individual output (if tracked per person)
    individual_quantity NUMERIC(10,2),
    quantity_unit       VARCHAR(30),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_activity_worker UNIQUE (activity_id, worker_id)
);

CREATE INDEX idx_awa_activity ON activity_worker_assignment(activity_id);
CREATE INDEX idx_awa_worker ON activity_worker_assignment(worker_id);

COMMENT ON TABLE activity_worker_assignment IS 
    'Individual worker assignments within a multi-person activity — tracks individual check-in/out and output.';


-- ============================================================================
-- SECTION 5: ACTIVITY MATERIAL USAGE
-- Materials consumed during an activity
-- ============================================================================

CREATE TABLE activity_material_usage (
    usage_id            BIGSERIAL       PRIMARY KEY,
    activity_id         BIGINT          NOT NULL REFERENCES daily_activity(activity_id),
    material_id         INT             NOT NULL REFERENCES material_master(material_id),
    
    planned_quantity    NUMERIC(10,3),
    actual_quantity     NUMERIC(10,3)   NOT NULL CHECK (actual_quantity >= 0),
    quantity_unit       VARCHAR(20)     NOT NULL,
    
    -- Cost
    unit_cost           NUMERIC(12,2),
    total_cost          NUMERIC(12,2),
    currency_code       VARCHAR(3)      DEFAULT 'LKR',
    
    -- Traceability
    batch_number        VARCHAR(50),
    store_issue_ref     VARCHAR(50),    -- Material requisition reference
    
    -- Application details (for chemicals)
    concentration_pct   NUMERIC(5,2),
    application_rate    VARCHAR(50),    -- e.g., '2kg/ha', '3ml/tree'
    
    -- Variance
    variance_pct        NUMERIC(6,2),   -- (actual - planned) / planned * 100
    variance_reason     TEXT,
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_amu_activity ON activity_material_usage(activity_id);
CREATE INDEX idx_amu_material ON activity_material_usage(material_id);

COMMENT ON TABLE activity_material_usage IS 
    'Materials and inputs consumed during each activity — fertilizers, chemicals, fuel, equipment with variance tracking.';


-- ============================================================================
-- SECTION 6: ACTIVITY PHOTO EVIDENCE
-- Structured photo evidence with geo-tagging and AI analysis
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
    
    -- Geo-tagging
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),
    
    -- AI Photo Analysis
    ai_analyzed         BOOLEAN         DEFAULT FALSE,
    ai_analysis_result  JSONB,          -- Structured AI output (labels, issues, scores)
    ai_confidence_score NUMERIC(5,2),
    ai_flagged_issues   TEXT[],
    
    caption             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_photo_activity ON activity_photo_evidence(activity_id);
CREATE INDEX idx_photo_type ON activity_photo_evidence(photo_type);
CREATE INDEX idx_photo_gps ON activity_photo_evidence USING GIST(gps_point);
CREATE INDEX idx_photo_ai ON activity_photo_evidence(ai_analyzed) WHERE ai_analyzed = TRUE;

COMMENT ON TABLE activity_photo_evidence IS 
    'Geo-tagged photo evidence per activity — before/during/after shots with AI-powered analysis results stored as JSONB.';


-- ============================================================================
-- SECTION 7: SUPERVISOR INSPECTION
-- Field inspections linked to activities or standalone
-- ============================================================================

CREATE TABLE supervisor_inspection (
    inspection_id       SERIAL          PRIMARY KEY,
    
    -- Context
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    field_id            INT             REFERENCES field(field_id),
    activity_id         BIGINT          REFERENCES daily_activity(activity_id),
    
    -- Inspector
    inspector_id        INT             NOT NULL REFERENCES worker(worker_id),
    inspection_date     DATE            NOT NULL,
    inspection_time     TIMESTAMPTZ,
    
    -- Type
    inspection_type     VARCHAR(30)     NOT NULL
                                        CHECK (inspection_type IN (
                                            'ROUTINE', 'SPOT_CHECK', 'QUALITY_AUDIT',
                                            'SAFETY_WALK', 'POST_ACTIVITY', 'COMPLAINT'
                                        )),
    
    -- Overall Assessment
    overall_rating      INT             NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
    
    -- GPS
    gps_latitude        NUMERIC(10,7),
    gps_longitude       NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),
    
    -- AR / MR assisted
    ar_assisted         BOOLEAN         NOT NULL DEFAULT FALSE,
    ar_device_id        VARCHAR(50),
    
    -- AI
    ai_summary          TEXT,           -- AI-generated inspection summary from photos
    
    findings            TEXT,
    corrective_actions  TEXT,
    follow_up_date      DATE,
    follow_up_completed BOOLEAN         DEFAULT FALSE,
    
    photo_urls          TEXT[],
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_insp_plantation ON supervisor_inspection(plantation_id);
CREATE INDEX idx_insp_field ON supervisor_inspection(field_id);
CREATE INDEX idx_insp_activity ON supervisor_inspection(activity_id);
CREATE INDEX idx_insp_inspector ON supervisor_inspection(inspector_id);
CREATE INDEX idx_insp_date ON supervisor_inspection(inspection_date);
CREATE INDEX idx_insp_type ON supervisor_inspection(inspection_type);
CREATE INDEX idx_insp_gps ON supervisor_inspection USING GIST(gps_point);

COMMENT ON TABLE supervisor_inspection IS 
    'Supervisor field inspections — routine, spot checks, quality audits with checklist scoring, AR-assisted, and AI summary generation.';


-- ============================================================================
-- SECTION 8: INSPECTION CHECKLIST RESPONSE
-- Individual checklist items scored during an inspection
-- ============================================================================

CREATE TABLE inspection_checklist_response (
    response_id         SERIAL          PRIMARY KEY,
    inspection_id       INT             NOT NULL REFERENCES supervisor_inspection(inspection_id),
    item_code           VARCHAR(30)     NOT NULL REFERENCES lu_inspection_checklist_item(item_code),
    
    -- Response based on check_type
    yes_no_value        BOOLEAN,
    rating_value        INT             CHECK (rating_value BETWEEN 1 AND 5),
    numeric_value       NUMERIC(10,2),
    text_value          TEXT,
    
    remarks             TEXT,
    photo_url           VARCHAR(1000),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_inspection_item UNIQUE (inspection_id, item_code)
);

CREATE INDEX idx_icr_inspection ON inspection_checklist_response(inspection_id);
CREATE INDEX idx_icr_item ON inspection_checklist_response(item_code);

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
    
    -- Activity counts by status
    total_planned       INT             NOT NULL DEFAULT 0,
    total_completed     INT             NOT NULL DEFAULT 0,
    total_partial       INT             NOT NULL DEFAULT 0,
    total_cancelled     INT             NOT NULL DEFAULT 0,
    total_postponed     INT             NOT NULL DEFAULT 0,
    
    -- Workforce
    total_workers_deployed INT          DEFAULT 0,
    total_man_days      NUMERIC(8,2)    DEFAULT 0,
    
    -- Output by category
    tapping_area_ha     NUMERIC(10,2)   DEFAULT 0,
    maintenance_area_ha NUMERIC(10,2)   DEFAULT 0,
    manuring_area_ha    NUMERIC(10,2)   DEFAULT 0,
    spraying_area_ha    NUMERIC(10,2)   DEFAULT 0,
    nursery_plants      INT             DEFAULT 0,
    replanting_trees    INT             DEFAULT 0,
    
    -- Material costs
    total_material_cost NUMERIC(12,2)   DEFAULT 0,
    currency_code       VARCHAR(3)      DEFAULT 'LKR',
    
    -- Quality
    avg_inspection_rating NUMERIC(3,1),
    activities_with_anomalies INT       DEFAULT 0,
    
    -- Weather impact
    weather_condition   VARCHAR(30),
    rainfall_mm         NUMERIC(6,2),
    field_work_hours_lost NUMERIC(4,1)  DEFAULT 0,
    
    -- Completion rate
    overall_completion_pct NUMERIC(5,2),
    
    -- AI Insights
    ai_daily_summary    TEXT,           -- AI-generated end-of-day narrative
    ai_recommendations  TEXT,           -- AI-suggested priorities for next day
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_daily_summary UNIQUE (plantation_id, division_id, summary_date)
);

CREATE INDEX idx_summary_plantation ON daily_activity_summary(plantation_id);
CREATE INDEX idx_summary_date ON daily_activity_summary(summary_date);

COMMENT ON TABLE daily_activity_summary IS 
    'End-of-day rollup of all activities per plantation/division with workforce, output, cost, quality, and AI insights.';


-- ============================================================================
-- SECTION 10: VIEWS
-- ============================================================================

-- 10.1 Daily Activity Dashboard
CREATE OR REPLACE VIEW vw_activity_dashboard AS
SELECT
    da.activity_date,
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    f.field_code,
    
    ac.category_name,
    at.activity_type_name,
    ap.priority_name,
    ap.color_hex        AS priority_color,
    ast.status_name,
    
    w.full_name         AS assigned_worker,
    g.gang_name,
    
    da.planned_duration_hours,
    da.actual_duration_hours,
    da.target_quantity,
    da.actual_quantity,
    da.quantity_unit,
    da.completion_pct,
    da.workers_deployed,
    
    da.weather_condition,
    da.rainfall_mm,
    
    da.supervisor_verified,
    sup.full_name       AS supervisor_name,
    
    da.ai_anomaly_flag,
    da.ai_efficiency_score,
    
    ARRAY_LENGTH(da.photo_urls, 1)  AS photo_count

FROM daily_activity da
JOIN plantation p ON p.plantation_id = da.plantation_id
LEFT JOIN division d ON d.division_id = da.division_id
LEFT JOIN field f ON f.field_id = da.field_id
JOIN lu_activity_category ac ON ac.category_code = da.category_code
JOIN lu_activity_type at ON at.activity_type_code = da.activity_type_code
JOIN lu_activity_priority ap ON ap.priority_code = da.priority_code
JOIN lu_activity_status ast ON ast.status_code = da.status
LEFT JOIN worker w ON w.worker_id = da.assigned_worker_id
LEFT JOIN gang g ON g.gang_id = da.assigned_gang_id
LEFT JOIN worker sup ON sup.worker_id = da.supervisor_id
ORDER BY da.activity_date DESC, ap.priority_level DESC;


-- 10.2 Category-wise Activity Analysis
CREATE OR REPLACE VIEW vw_activity_category_analysis AS
SELECT
    p.plantation_code,
    da.activity_date,
    ac.category_name,
    
    COUNT(da.activity_id)                                               AS total_activities,
    COUNT(da.activity_id) FILTER (WHERE da.status = 'COMPLETED')       AS completed,
    COUNT(da.activity_id) FILTER (WHERE da.status = 'PARTIAL')         AS partial,
    COUNT(da.activity_id) FILTER (WHERE da.status = 'CANCELLED')       AS cancelled,
    
    ROUND(AVG(da.completion_pct), 1)                                    AS avg_completion_pct,
    SUM(da.workers_deployed)                                            AS total_workers,
    ROUND(SUM(da.man_days), 2)                                          AS total_man_days,
    ROUND(SUM(da.actual_quantity), 2)                                    AS total_output,
    
    COUNT(da.activity_id) FILTER (WHERE da.ai_anomaly_flag = TRUE)     AS anomalies

FROM daily_activity da
JOIN plantation p ON p.plantation_id = da.plantation_id
JOIN lu_activity_category ac ON ac.category_code = da.category_code
GROUP BY p.plantation_code, da.activity_date, ac.category_name
ORDER BY da.activity_date DESC, ac.category_name;


-- 10.3 Material Consumption Report
CREATE OR REPLACE VIEW vw_material_consumption AS
SELECT
    p.plantation_code,
    f.field_code,
    mm.material_code,
    mm.material_name,
    mm.material_category,
    at.activity_type_name,
    
    da.activity_date,
    amu.planned_quantity,
    amu.actual_quantity,
    amu.quantity_unit,
    amu.total_cost,
    amu.variance_pct,
    
    da.actual_quantity  AS area_or_trees_covered,
    da.quantity_unit    AS coverage_unit,
    
    CASE WHEN da.actual_quantity > 0 
         THEN ROUND(amu.actual_quantity / da.actual_quantity, 3)
         ELSE NULL 
    END AS application_rate_per_unit

FROM activity_material_usage amu
JOIN daily_activity da ON da.activity_id = amu.activity_id
JOIN plantation p ON p.plantation_id = da.plantation_id
LEFT JOIN field f ON f.field_id = da.field_id
JOIN material_master mm ON mm.material_id = amu.material_id
JOIN lu_activity_type at ON at.activity_type_code = da.activity_type_code
ORDER BY da.activity_date DESC, mm.material_category;


-- 10.4 Worker Productivity View
CREATE OR REPLACE VIEW vw_worker_daily_productivity AS
SELECT
    w.worker_id,
    w.employee_code,
    w.full_name,
    wc.category_name    AS role,
    da.activity_date,
    
    COUNT(da.activity_id)                                               AS activities_assigned,
    COUNT(da.activity_id) FILTER (WHERE da.status = 'COMPLETED')       AS activities_completed,
    ROUND(SUM(da.actual_duration_hours), 2)                             AS total_hours_worked,
    ROUND(SUM(da.actual_quantity), 2)                                    AS total_output,
    
    ROUND(AVG(da.completion_pct), 1)                                    AS avg_completion_pct,
    ROUND(AVG(da.ai_efficiency_score), 1)                               AS avg_ai_efficiency,
    
    COUNT(da.activity_id) FILTER (WHERE da.ai_anomaly_flag = TRUE)     AS anomalies,
    COUNT(da.activity_id) FILTER (WHERE da.supervisor_verified = TRUE)  AS supervisor_verified_count

FROM daily_activity da
JOIN worker w ON w.worker_id = da.assigned_worker_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
GROUP BY w.worker_id, w.employee_code, w.full_name, wc.category_name, da.activity_date
ORDER BY da.activity_date DESC, total_output DESC;


-- ============================================================================
-- SECTION 11: TRIGGER FUNCTIONS
-- ============================================================================

-- 11.1 Auto-update timestamps
CREATE TRIGGER trg_daily_plan_updated
    BEFORE UPDATE ON daily_work_plan
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_daily_activity_updated
    BEFORE UPDATE ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_supervisor_insp_updated
    BEFORE UPDATE ON supervisor_inspection
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_material_master_updated
    BEFORE UPDATE ON material_master
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- 11.2 Auto-populate GPS point from lat/lon on daily_activity
CREATE OR REPLACE FUNCTION fn_activity_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_gps_lat IS NOT NULL AND NEW.start_gps_lon IS NOT NULL THEN
        NEW.start_gps_point = ST_SetSRID(ST_MakePoint(NEW.start_gps_lon, NEW.start_gps_lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activity_gps_sync
    BEFORE INSERT OR UPDATE OF start_gps_lat, start_gps_lon ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_activity_sync_gps();

-- 11.3 Auto-calculate completion percentage
CREATE OR REPLACE FUNCTION fn_calc_completion_pct()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.target_quantity IS NOT NULL AND NEW.target_quantity > 0 AND NEW.actual_quantity IS NOT NULL THEN
        NEW.completion_pct = LEAST(ROUND((NEW.actual_quantity / NEW.target_quantity) * 100, 2), 100);
    END IF;
    IF NEW.actual_start_time IS NOT NULL AND NEW.actual_end_time IS NOT NULL THEN
        NEW.actual_duration_hours = ROUND(EXTRACT(EPOCH FROM (NEW.actual_end_time - NEW.actual_start_time)) / 3600, 2);
    END IF;
    IF NEW.workers_deployed IS NOT NULL AND NEW.actual_duration_hours IS NOT NULL THEN
        NEW.man_days = ROUND(NEW.workers_deployed * NEW.actual_duration_hours / 8.0, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_completion
    BEFORE INSERT OR UPDATE OF target_quantity, actual_quantity, actual_start_time, actual_end_time, workers_deployed ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_calc_completion_pct();

-- 11.4 Auto-calculate material variance
CREATE OR REPLACE FUNCTION fn_calc_material_variance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.planned_quantity IS NOT NULL AND NEW.planned_quantity > 0 THEN
        NEW.variance_pct = ROUND(((NEW.actual_quantity - NEW.planned_quantity) / NEW.planned_quantity) * 100, 2);
    END IF;
    IF NEW.unit_cost IS NOT NULL THEN
        NEW.total_cost = ROUND(NEW.actual_quantity * NEW.unit_cost, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_material_variance
    BEFORE INSERT OR UPDATE OF planned_quantity, actual_quantity, unit_cost ON activity_material_usage
    FOR EACH ROW EXECUTE FUNCTION fn_calc_material_variance();

-- 11.5 Auto-update daily work plan summary counts
CREATE OR REPLACE FUNCTION fn_sync_plan_counts()
RETURNS TRIGGER AS $$
DECLARE
    v_plan_id INT;
BEGIN
    v_plan_id := COALESCE(NEW.plan_id, OLD.plan_id);
    IF v_plan_id IS NOT NULL THEN
        UPDATE daily_work_plan SET
            total_activities_planned = (
                SELECT COUNT(*) FROM daily_activity WHERE plan_id = v_plan_id
            ),
            total_activities_completed = (
                SELECT COUNT(*) FROM daily_activity WHERE plan_id = v_plan_id AND status IN ('COMPLETED', 'PARTIAL')
            ),
            total_workers_deployed = (
                SELECT COALESCE(SUM(workers_deployed), 0) FROM daily_activity WHERE plan_id = v_plan_id
            ),
            completion_rate_pct = (
                SELECT CASE WHEN COUNT(*) > 0 
                    THEN ROUND(COUNT(*) FILTER (WHERE status = 'COMPLETED') * 100.0 / COUNT(*), 2)
                    ELSE 0 END
                FROM daily_activity WHERE plan_id = v_plan_id
            ),
            updated_at = NOW()
        WHERE plan_id = v_plan_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_plan_counts_insert
    AFTER INSERT ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_sync_plan_counts();

CREATE TRIGGER trg_sync_plan_counts_update
    AFTER UPDATE OF status ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_sync_plan_counts();

-- 11.6 Auto-populate GPS on photo evidence
CREATE OR REPLACE FUNCTION fn_photo_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_photo_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON activity_photo_evidence
    FOR EACH ROW EXECUTE FUNCTION fn_photo_sync_gps();

-- Same for supervisor_inspection
CREATE TRIGGER trg_insp_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON supervisor_inspection
    FOR EACH ROW EXECUTE FUNCTION fn_coll_point_sync_gps();


-- ============================================================================
-- SECTION 12: PERMISSIONS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON daily_work_plan, daily_activity, activity_worker_assignment,
    activity_material_usage, activity_photo_evidence, supervisor_inspection,
    inspection_checklist_response, daily_activity_summary, material_master TO plantation_manager;

GRANT SELECT ON lu_activity_category, lu_activity_type, lu_activity_status,
    lu_activity_priority, lu_inspection_checklist_item TO plantation_manager;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;


-- ============================================================================
-- END OF MODULE 5: DAILY ACTIVITY MONITORING
-- ============================================================================
