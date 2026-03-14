-- ============================================================================
-- RUBBER PLANTATION MANAGEMENT SYSTEM
-- Module 4: WORKFORCE MANAGEMENT
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for worker registration, employment lifecycle,
--              roles & skills, team/gang organization, field assignment,
--              contract & payroll structures, training, certifications,
--              health & safety, next-of-kin, document management,
--              and biometric/IoT integration.
--
-- Dependencies:
--   Module 1: plantation, division, field
--   Module 3: tapping_task (tapper_id FK resolved here), iot_device
--
-- NOTE: This module introduces the `worker` table which is the entity
--       referenced by tapper_id across Modules 3, 5, and 6.
-- ============================================================================


-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Worker Category / Role Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_worker_category (
    category_code   VARCHAR(30)     PRIMARY KEY,
    category_name   VARCHAR(100)    NOT NULL,
    category_group  VARCHAR(30)     NOT NULL
                                    CHECK (category_group IN (
                                        'FIELD', 'FACTORY', 'ADMINISTRATIVE',
                                        'MANAGEMENT', 'TECHNICAL', 'SUPPORT'
                                    )),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_worker_category (category_code, category_name, category_group, description) VALUES
    ('TAPPER',          'Rubber Tapper',                'FIELD',            'Primary tapping worker — taps and collects field latex'),
    ('TAPPER_SENIOR',   'Senior Tapper / Lead Tapper',  'FIELD',            'Experienced tapper who leads a tapping gang'),
    ('FIELD_COLLECTOR', 'Latex Collector',               'FIELD',            'Collects latex from cups and transports to collection point'),
    ('FIELD_MAINT',     'Field Maintenance Worker',      'FIELD',            'Weeding, manuring, spraying, road clearing'),
    ('NURSERY_WORKER',  'Nursery Worker',                'FIELD',            'Nursery planting, budding, maintenance'),
    ('PEST_CONTROL',    'Pest & Disease Control Worker', 'FIELD',            'Disease scouting, chemical application, treatment'),
    ('HARVESTER',       'Timber / Replanting Worker',    'FIELD',            'Felling, clearing, replanting operations'),
    ('FACTORY_OPS',     'Factory Operator',              'FACTORY',          'Latex processing, sheet making, smoking, packing'),
    ('QUALITY_INSP',    'Quality Inspector',             'FACTORY',          'DRC testing, latex grading, quality checks'),
    ('DRIVER',          'Driver / Transport',            'SUPPORT',          'Vehicle driver — latex transport, personnel'),
    ('MECHANIC',        'Mechanic / Equipment Tech',     'TECHNICAL',        'Vehicle and equipment maintenance'),
    ('CLERK',           'Administrative Clerk',          'ADMINISTRATIVE',   'Record keeping, data entry, filing'),
    ('CONDUCTOR',       'Field Conductor / Supervisor',  'MANAGEMENT',       'Supervises a division or group of fields'),
    ('ASST_MANAGER',    'Assistant Manager',             'MANAGEMENT',       'Division-level management'),
    ('MANAGER',         'Estate Manager',                'MANAGEMENT',       'Overall plantation management');

-- ----------------------------------------------------------------------------
-- 1.2 Employment Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_employment_type (
    employment_type_code VARCHAR(20)    PRIMARY KEY,
    employment_type_name VARCHAR(100)   NOT NULL,
    description          VARCHAR(500),
    is_active            BOOLEAN        NOT NULL DEFAULT TRUE
);

INSERT INTO lu_employment_type (employment_type_code, employment_type_name, description) VALUES
    ('PERMANENT',   'Permanent / Regular',              'Full-time regular employee with benefits'),
    ('CONTRACT',    'Contract Worker',                  'Fixed-term contract employment'),
    ('DAILY_WAGE',  'Daily Wage / Casual',              'Paid per day of work — no fixed contract'),
    ('SEASONAL',    'Seasonal Worker',                  'Employed for specific seasons (e.g., tapping, replanting)'),
    ('PIECE_RATE',  'Piece Rate / Output-Based',        'Paid based on output (kg latex, trees tapped)'),
    ('TRAINEE',     'Trainee / Apprentice',             'Under training program before becoming regular');

-- ----------------------------------------------------------------------------
-- 1.3 Worker Status Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_worker_status (
    status_code     VARCHAR(20)     PRIMARY KEY,
    status_name     VARCHAR(100)    NOT NULL,
    is_active_duty  BOOLEAN         NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_worker_status (status_code, status_name, is_active_duty, description) VALUES
    ('ACTIVE',          'Active / On Duty',         TRUE,   'Currently employed and working'),
    ('ON_LEAVE',        'On Approved Leave',        FALSE,  'On sanctioned leave (annual, sick, maternity, etc.)'),
    ('SUSPENDED',       'Suspended',                FALSE,  'Temporarily suspended pending investigation'),
    ('TRAINING',        'Under Training',           TRUE,   'Active but in training program'),
    ('PROBATION',       'On Probation',             TRUE,   'Within probation period'),
    ('TRANSFERRED',     'Transferred Out',          FALSE,  'Transferred to another plantation'),
    ('RESIGNED',        'Resigned',                 FALSE,  'Voluntarily left employment'),
    ('TERMINATED',      'Terminated',               FALSE,  'Employment terminated by management'),
    ('RETIRED',         'Retired',                  FALSE,  'Retired from service'),
    ('DECEASED',        'Deceased',                 FALSE,  'Worker deceased');

-- ----------------------------------------------------------------------------
-- 1.4 Skill / Competency Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_skill (
    skill_code      VARCHAR(30)     PRIMARY KEY,
    skill_name      VARCHAR(200)    NOT NULL,
    skill_category  VARCHAR(30)     NOT NULL
                                    CHECK (skill_category IN (
                                        'TAPPING', 'FIELD_OPS', 'NURSERY',
                                        'FACTORY', 'MACHINERY', 'SAFETY',
                                        'QUALITY', 'SUPERVISORY', 'IT', 'OTHER'
                                    )),
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_skill (skill_code, skill_name, skill_category) VALUES
    ('TAP_S2',          'Half-Spiral Tapping (S/2)',            'TAPPING'),
    ('TAP_S4',          'Quarter-Spiral Tapping (S/4)',         'TAPPING'),
    ('TAP_HIGH_PANEL',  'High Panel Tapping',                   'TAPPING'),
    ('TAP_STIMULANT',   'Ethephon Stimulant Application',       'TAPPING'),
    ('BUDDING',         'Bud Grafting / Budding',               'NURSERY'),
    ('MARCOTTING',      'Marcotting / Air Layering',            'NURSERY'),
    ('CHAINSAW',        'Chainsaw Operation',                   'MACHINERY'),
    ('TRACTOR',         'Tractor / Vehicle Operation',          'MACHINERY'),
    ('SPRAYING',        'Chemical Spraying (Certified)',         'FIELD_OPS'),
    ('MANURING',        'Fertilizer Application',               'FIELD_OPS'),
    ('DRC_TESTING',     'DRC / Latex Quality Testing',          'QUALITY'),
    ('FIRST_AID',       'First Aid Certification',              'SAFETY'),
    ('FIRE_SAFETY',     'Fire Safety Training',                 'SAFETY'),
    ('FACTORY_OPS',     'Latex Processing Operations',          'FACTORY'),
    ('TEAM_LEAD',       'Team Leadership / Supervision',        'SUPERVISORY'),
    ('NFC_MOBILE',      'NFC Scanning & Mobile App Usage',      'IT');

-- ----------------------------------------------------------------------------
-- 1.5 Proficiency Level Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_proficiency_level (
    level_code      VARCHAR(20)     PRIMARY KEY,
    level_name      VARCHAR(50)     NOT NULL,
    level_score     INT             NOT NULL CHECK (level_score BETWEEN 1 AND 5),
    description     VARCHAR(200)
);

INSERT INTO lu_proficiency_level (level_code, level_name, level_score, description) VALUES
    ('NOVICE',          'Novice',           1,  'Basic awareness, needs supervision'),
    ('BEGINNER',        'Beginner',         2,  'Can perform with guidance'),
    ('COMPETENT',       'Competent',        3,  'Independently capable'),
    ('PROFICIENT',      'Proficient',       4,  'High quality, can train others'),
    ('EXPERT',          'Expert',           5,  'Master level, can innovate and lead');

-- ----------------------------------------------------------------------------
-- 1.6 Leave Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_leave_type (
    leave_type_code VARCHAR(20)     PRIMARY KEY,
    leave_type_name VARCHAR(100)    NOT NULL,
    is_paid         BOOLEAN         NOT NULL DEFAULT TRUE,
    max_days_per_year INT,
    requires_medical_cert BOOLEAN   NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_leave_type (leave_type_code, leave_type_name, is_paid, max_days_per_year, requires_medical_cert) VALUES
    ('ANNUAL',      'Annual Leave',             TRUE,   14,     FALSE),
    ('SICK',        'Sick Leave',               TRUE,   14,     TRUE),
    ('CASUAL',      'Casual Leave',             TRUE,   7,      FALSE),
    ('MATERNITY',   'Maternity Leave',          TRUE,   84,     TRUE),
    ('PATERNITY',   'Paternity Leave',          TRUE,   7,      FALSE),
    ('INJURY',      'Work Injury Leave',        TRUE,   NULL,   TRUE),
    ('UNPAID',      'Unpaid Leave',             FALSE,  30,     FALSE),
    ('COMPASSION',  'Compassionate Leave',      TRUE,   5,      FALSE),
    ('TRAINING',    'Training Leave',           TRUE,   NULL,   FALSE),
    ('PUBLIC_HOL',  'Public Holiday',           TRUE,   NULL,   FALSE);

-- ----------------------------------------------------------------------------
-- 1.7 Relationship Type Lookup (for next-of-kin)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_relationship_type (
    relationship_code VARCHAR(20)    PRIMARY KEY,
    relationship_name VARCHAR(50)    NOT NULL,
    is_active         BOOLEAN        NOT NULL DEFAULT TRUE
);

INSERT INTO lu_relationship_type (relationship_code, relationship_name) VALUES
    ('SPOUSE',      'Spouse'),
    ('CHILD',       'Child'),
    ('PARENT',      'Parent'),
    ('SIBLING',     'Sibling'),
    ('GUARDIAN',    'Guardian'),
    ('OTHER',       'Other');

-- ----------------------------------------------------------------------------
-- 1.8 Document Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_document_type (
    doc_type_code   VARCHAR(30)     PRIMARY KEY,
    doc_type_name   VARCHAR(100)    NOT NULL,
    is_mandatory    BOOLEAN         NOT NULL DEFAULT FALSE,
    validity_months INT,            -- NULL = no expiry
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_document_type (doc_type_code, doc_type_name, is_mandatory, validity_months) VALUES
    ('NIC',             'National ID Card',                 TRUE,   NULL),
    ('PASSPORT',        'Passport',                         FALSE,  120),
    ('WORK_PERMIT',     'Work Permit / Visa',               FALSE,  12),
    ('DRIVING_LIC',     'Driving License',                  FALSE,  60),
    ('MEDICAL_CERT',    'Medical Fitness Certificate',       TRUE,   12),
    ('POLICE_CLEAR',    'Police Clearance',                 FALSE,  12),
    ('BANK_DETAILS',    'Bank Account Details',             TRUE,   NULL),
    ('TAX_REG',         'Tax Registration / TIN',           FALSE,  NULL),
    ('PHOTO',           'Passport-Size Photo',              TRUE,   NULL),
    ('CONTRACT',        'Employment Contract Copy',         TRUE,   NULL),
    ('SPRAY_CERT',      'Chemical Handling Certificate',     FALSE,  24),
    ('CHAINSAW_CERT',   'Chainsaw Operator Certificate',     FALSE,  24),
    ('FIRST_AID_CERT',  'First Aid Certificate',             FALSE,  24);

-- ----------------------------------------------------------------------------
-- 1.9 Pay Component Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_pay_component (
    component_code  VARCHAR(30)     PRIMARY KEY,
    component_name  VARCHAR(100)    NOT NULL,
    component_type  VARCHAR(20)     NOT NULL
                                    CHECK (component_type IN (
                                        'EARNING', 'DEDUCTION', 'ALLOWANCE', 
                                        'BONUS', 'STATUTORY'
                                    )),
    is_taxable      BOOLEAN         NOT NULL DEFAULT TRUE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

INSERT INTO lu_pay_component (component_code, component_name, component_type, is_taxable) VALUES
    ('BASIC_SALARY',    'Basic Salary',                 'EARNING',      TRUE),
    ('DAILY_WAGE',      'Daily Wage',                   'EARNING',      TRUE),
    ('PIECE_RATE_PAY',  'Piece Rate / Output Pay',      'EARNING',      TRUE),
    ('OVERTIME',        'Overtime Pay',                 'EARNING',      TRUE),
    ('LATEX_INCENTIVE', 'Latex Yield Incentive',        'BONUS',        TRUE),
    ('QUALITY_BONUS',   'Tapping Quality Bonus',        'BONUS',        TRUE),
    ('ATTENDANCE_BONUS','Attendance Bonus',             'BONUS',        TRUE),
    ('HOUSING_ALLOW',   'Housing Allowance',            'ALLOWANCE',    FALSE),
    ('TRANSPORT_ALLOW', 'Transport Allowance',          'ALLOWANCE',    FALSE),
    ('RAIN_ALLOW',      'Rainy Day Allowance',          'ALLOWANCE',    FALSE),
    ('EPF_DEDUCTION',   'EPF / Provident Fund',         'STATUTORY',    FALSE),
    ('ETF_DEDUCTION',   'ETF / Employment Trust',       'STATUTORY',    FALSE),
    ('TAX_PAYE',        'Income Tax (PAYE)',            'STATUTORY',    FALSE),
    ('LOAN_DEDUCTION',  'Loan Repayment Deduction',     'DEDUCTION',    FALSE),
    ('ADVANCE_DEDUCT',  'Salary Advance Deduction',     'DEDUCTION',    FALSE);

-- ----------------------------------------------------------------------------
-- 1.10 Training Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_training_type (
    training_type_code VARCHAR(30)   PRIMARY KEY,
    training_type_name VARCHAR(200)  NOT NULL,
    category           VARCHAR(30)   NOT NULL
                                     CHECK (category IN (
                                         'INDUCTION', 'TAPPING', 'SAFETY', 'TECHNICAL',
                                         'QUALITY', 'SUPERVISORY', 'REFRESHER', 'OTHER'
                                     )),
    typical_duration_days INT,
    is_mandatory       BOOLEAN       NOT NULL DEFAULT FALSE,
    description        VARCHAR(500),
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE
);

INSERT INTO lu_training_type (training_type_code, training_type_name, category, typical_duration_days, is_mandatory) VALUES
    ('INDUCTION',       'New Employee Induction',               'INDUCTION',    2,  TRUE),
    ('TAP_BASIC',       'Basic Tapping Training',               'TAPPING',      14, TRUE),
    ('TAP_ADVANCED',    'Advanced Tapping Techniques',          'TAPPING',      7,  FALSE),
    ('TAP_HIGH_PANEL',  'High Panel Tapping Training',          'TAPPING',      5,  FALSE),
    ('STIMULANT_APP',   'Ethephon Stimulant Application',       'TECHNICAL',    2,  FALSE),
    ('CHEMICAL_SAFETY', 'Chemical Handling & Safety',           'SAFETY',       2,  TRUE),
    ('FIRST_AID',       'Basic First Aid Training',             'SAFETY',       1,  TRUE),
    ('FIRE_DRILL',      'Fire Safety & Evacuation Drill',       'SAFETY',       1,  TRUE),
    ('SNAKE_AWARE',     'Snake Awareness & First Response',      'SAFETY',       1,  FALSE),
    ('MR_TRAINING',     'AR/MR Tapping Quality Training',        'TECHNICAL',    3,  FALSE),
    ('MOBILE_APP',      'Mobile App & NFC Scanning Training',    'TECHNICAL',    1,  FALSE),
    ('DRC_TESTING',     'DRC & Latex Quality Testing',           'QUALITY',      3,  FALSE),
    ('SUPERVISOR',      'Supervisory Skills Development',        'SUPERVISORY',  5,  FALSE),
    ('REFRESH_TAP',     'Annual Tapping Refresher',              'REFRESHER',    2,  TRUE);


-- ============================================================================
-- SECTION 2: WORKER — the core workforce entity
-- ============================================================================

CREATE TABLE worker (
    worker_id           SERIAL          PRIMARY KEY,
    
    -- Identification
    employee_code       VARCHAR(30)     NOT NULL UNIQUE,
    first_name          VARCHAR(100)    NOT NULL,
    last_name           VARCHAR(100)    NOT NULL,
    full_name           VARCHAR(200)    GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    
    -- Personal
    date_of_birth       DATE,
    gender              VARCHAR(10)     CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
    national_id         VARCHAR(50),
    passport_number     VARCHAR(50),
    nationality         VARCHAR(100),
    ethnicity           VARCHAR(100),
    marital_status      VARCHAR(20)     CHECK (marital_status IN (
                                            'SINGLE', 'MARRIED', 'WIDOWED', 'DIVORCED'
                                        )),
    blood_group         VARCHAR(5)      CHECK (blood_group IN (
                                            'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
                                        )),
    
    -- Contact
    mobile_phone        VARCHAR(20),
    alternate_phone     VARCHAR(20),
    email               VARCHAR(200),
    permanent_address   TEXT,
    current_address     TEXT,
    
    -- Employment
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    category_code       VARCHAR(30)     NOT NULL REFERENCES lu_worker_category(category_code),
    employment_type_code VARCHAR(20)    NOT NULL REFERENCES lu_employment_type(employment_type_code),
    
    -- Status
    worker_status       VARCHAR(20)     NOT NULL DEFAULT 'PROBATION'
                                        REFERENCES lu_worker_status(status_code),
    
    -- Dates
    hire_date           DATE            NOT NULL,
    probation_end_date  DATE,
    confirmation_date   DATE,
    termination_date    DATE,
    
    -- Reporting
    reports_to_id       INT             REFERENCES worker(worker_id),
    
    -- Assignment
    primary_field_id    INT             REFERENCES field(field_id),
    assigned_gang_id    INT,            -- FK to gang table below
    
    -- Compensation
    base_pay_amount     NUMERIC(12,2),
    pay_currency        VARCHAR(3)      DEFAULT 'LKR',  -- ISO currency
    pay_frequency       VARCHAR(20)     CHECK (pay_frequency IN (
                                            'DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY'
                                        )),
    bank_name           VARCHAR(200),
    bank_account_no     VARCHAR(50),
    bank_branch         VARCHAR(200),
    
    -- Biometric / IoT
    biometric_id        VARCHAR(100),   -- Fingerprint or face recognition ID
    nfc_badge_uid       VARCHAR(100),   -- NFC wearable badge for attendance
    gps_wearable_uid    VARCHAR(100),   -- Assigned GPS band
    
    -- Photo
    photo_url           VARCHAR(1000),
    
    -- Metadata
    remarks             TEXT,
    
    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100)
);

CREATE INDEX idx_worker_plantation ON worker(plantation_id);
CREATE INDEX idx_worker_division ON worker(division_id);
CREATE INDEX idx_worker_category ON worker(category_code);
CREATE INDEX idx_worker_status ON worker(worker_status);
CREATE INDEX idx_worker_emp_type ON worker(employment_type_code);
CREATE INDEX idx_worker_field ON worker(primary_field_id);
CREATE INDEX idx_worker_reports_to ON worker(reports_to_id);
CREATE INDEX idx_worker_hire_date ON worker(hire_date);
CREATE INDEX idx_worker_name ON worker(full_name);
CREATE INDEX idx_worker_biometric ON worker(biometric_id) WHERE biometric_id IS NOT NULL;
CREATE INDEX idx_worker_nfc ON worker(nfc_badge_uid) WHERE nfc_badge_uid IS NOT NULL;

COMMENT ON TABLE worker IS 
    'Core workforce entity — every employee, tapper, supervisor, and manager. '
    'This is the record referenced by tapper_id in Module 3 (tapping_task) '
    'and worker_id in Modules 5 and 6.';


-- ============================================================================
-- SECTION 3: GANG / TEAM — tapper gangs assigned to fields
-- ============================================================================

CREATE TABLE gang (
    gang_id             SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    
    gang_code           VARCHAR(30)     NOT NULL,
    gang_name           VARCHAR(100),
    
    -- Leader
    leader_worker_id    INT             REFERENCES worker(worker_id),
    
    -- Assignment
    primary_field_id    INT             REFERENCES field(field_id),
    secondary_field_ids INT[],          -- Additional fields this gang covers
    
    -- Size
    target_size         INT             CHECK (target_size > 0),
    current_size        INT             DEFAULT 0 CHECK (current_size >= 0),
    
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISBANDED')),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_gang_code UNIQUE (plantation_id, gang_code)
);

-- Add FK from worker back to gang
ALTER TABLE worker ADD CONSTRAINT fk_worker_gang 
    FOREIGN KEY (assigned_gang_id) REFERENCES gang(gang_id);

CREATE INDEX idx_gang_plantation ON gang(plantation_id);
CREATE INDEX idx_gang_field ON gang(primary_field_id);
CREATE INDEX idx_gang_leader ON gang(leader_worker_id);

COMMENT ON TABLE gang IS 
    'Tapper gangs / teams — groups of workers assigned to specific fields. '
    'Each gang has a leader and covers one or more fields.';


-- ============================================================================
-- SECTION 4: WORKER SKILL MATRIX
-- ============================================================================

CREATE TABLE worker_skill (
    skill_id            SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    skill_code          VARCHAR(30)     NOT NULL REFERENCES lu_skill(skill_code),
    proficiency_level   VARCHAR(20)     NOT NULL REFERENCES lu_proficiency_level(level_code),
    
    assessed_date       DATE            NOT NULL,
    assessed_by         VARCHAR(100),
    next_assessment_date DATE,
    
    -- Certification
    is_certified        BOOLEAN         NOT NULL DEFAULT FALSE,
    certification_number VARCHAR(50),
    certification_expiry DATE,
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_worker_skill UNIQUE (worker_id, skill_code)
);

CREATE INDEX idx_ws_worker ON worker_skill(worker_id);
CREATE INDEX idx_ws_skill ON worker_skill(skill_code);
CREATE INDEX idx_ws_cert_expiry ON worker_skill(certification_expiry) WHERE is_certified = TRUE;

COMMENT ON TABLE worker_skill IS 
    'Skill competency matrix — each worker''s skills with proficiency level and certification status.';


-- ============================================================================
-- SECTION 5: WORKER FIELD ASSIGNMENT HISTORY
-- Tracks which worker was assigned to which field and when
-- ============================================================================

CREATE TABLE worker_field_assignment (
    assignment_id       SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    field_id            INT             NOT NULL REFERENCES field(field_id),
    gang_id             INT             REFERENCES gang(gang_id),
    
    assignment_type     VARCHAR(20)     NOT NULL
                                        CHECK (assignment_type IN ('PRIMARY', 'SECONDARY', 'TEMPORARY', 'RELIEF')),
    
    effective_from      DATE            NOT NULL,
    effective_to        DATE,
    
    assigned_by         VARCHAR(100),
    reason              VARCHAR(500),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_worker_field_active UNIQUE (worker_id, field_id, effective_from)
);

CREATE INDEX idx_wfa_worker ON worker_field_assignment(worker_id);
CREATE INDEX idx_wfa_field ON worker_field_assignment(field_id);
CREATE INDEX idx_wfa_gang ON worker_field_assignment(gang_id);
CREATE INDEX idx_wfa_dates ON worker_field_assignment(effective_from, effective_to);

COMMENT ON TABLE worker_field_assignment IS 
    'Historical record of field assignments per worker — supports reassignment tracking and audit.';


-- ============================================================================
-- SECTION 6: WORKER STATUS CHANGE LOG
-- ============================================================================

CREATE TABLE worker_status_change_log (
    log_id              SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    
    change_date         DATE            NOT NULL,
    from_status         VARCHAR(20)     REFERENCES lu_worker_status(status_code),
    to_status           VARCHAR(20)     NOT NULL REFERENCES lu_worker_status(status_code),
    
    reason              TEXT,
    effective_date      DATE            NOT NULL,
    changed_by          VARCHAR(100),
    
    -- For transfers
    from_plantation_id  INT             REFERENCES plantation(plantation_id),
    to_plantation_id    INT             REFERENCES plantation(plantation_id),
    
    -- Blockchain audit
    blockchain_tx_hash  VARCHAR(128),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wscl_worker ON worker_status_change_log(worker_id);
CREATE INDEX idx_wscl_date ON worker_status_change_log(change_date);

COMMENT ON TABLE worker_status_change_log IS 
    'Immutable audit trail of all employment status changes — hiring, transfers, terminations, etc.';


-- ============================================================================
-- SECTION 7: NEXT OF KIN / DEPENDENTS
-- ============================================================================

CREATE TABLE worker_next_of_kin (
    kin_id              SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    
    kin_name            VARCHAR(200)    NOT NULL,
    relationship_code   VARCHAR(20)     NOT NULL REFERENCES lu_relationship_type(relationship_code),
    date_of_birth       DATE,
    national_id         VARCHAR(50),
    mobile_phone        VARCHAR(20),
    address             TEXT,
    
    is_emergency_contact BOOLEAN        NOT NULL DEFAULT FALSE,
    is_beneficiary      BOOLEAN         NOT NULL DEFAULT FALSE,
    beneficiary_pct     NUMERIC(5,2)    CHECK (beneficiary_pct BETWEEN 0 AND 100),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_nok_worker ON worker_next_of_kin(worker_id);
CREATE INDEX idx_nok_emergency ON worker_next_of_kin(is_emergency_contact) WHERE is_emergency_contact = TRUE;

COMMENT ON TABLE worker_next_of_kin IS 
    'Next-of-kin, emergency contacts, and beneficiary records per worker.';


-- ============================================================================
-- SECTION 8: WORKER DOCUMENTS
-- ============================================================================

CREATE TABLE worker_document (
    document_id         SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    doc_type_code       VARCHAR(30)     NOT NULL REFERENCES lu_document_type(doc_type_code),
    
    document_number     VARCHAR(100),
    issued_date         DATE,
    expiry_date         DATE,
    issuing_authority   VARCHAR(200),
    
    file_url            VARCHAR(1000),
    file_name           VARCHAR(200),
    file_size_bytes     BIGINT,
    
    is_verified         BOOLEAN         NOT NULL DEFAULT FALSE,
    verified_by         VARCHAR(100),
    verified_at         TIMESTAMPTZ,
    
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'EXPIRED', 'REVOKED', 'PENDING_VERIFICATION')),
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_doc_worker ON worker_document(worker_id);
CREATE INDEX idx_doc_type ON worker_document(doc_type_code);
CREATE INDEX idx_doc_expiry ON worker_document(expiry_date) WHERE status = 'ACTIVE';

COMMENT ON TABLE worker_document IS 
    'Worker documents — IDs, certificates, contracts, medical certs. Tracks expiry for compliance alerts.';


-- ============================================================================
-- SECTION 9: LEAVE / ABSENCE MANAGEMENT
-- ============================================================================

CREATE TABLE worker_leave (
    leave_id            SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    leave_type_code     VARCHAR(20)     NOT NULL REFERENCES lu_leave_type(leave_type_code),
    
    leave_start_date    DATE            NOT NULL,
    leave_end_date      DATE            NOT NULL,
    total_days          INT             NOT NULL CHECK (total_days > 0),
    
    reason              TEXT,
    
    -- Approval chain
    approval_status     VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                                        CHECK (approval_status IN (
                                            'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'
                                        )),
    approved_by         INT             REFERENCES worker(worker_id),
    approved_at         TIMESTAMPTZ,
    rejection_reason    TEXT,
    
    -- Medical
    medical_cert_url    VARCHAR(1000),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT chk_leave_dates CHECK (leave_end_date >= leave_start_date)
);

CREATE INDEX idx_leave_worker ON worker_leave(worker_id);
CREATE INDEX idx_leave_type ON worker_leave(leave_type_code);
CREATE INDEX idx_leave_dates ON worker_leave(leave_start_date, leave_end_date);
CREATE INDEX idx_leave_status ON worker_leave(approval_status);

COMMENT ON TABLE worker_leave IS 
    'Leave applications with approval workflow — supports all leave types and medical certification.';


-- ============================================================================
-- SECTION 10: LEAVE BALANCE
-- ============================================================================

CREATE TABLE worker_leave_balance (
    balance_id          SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    leave_type_code     VARCHAR(20)     NOT NULL REFERENCES lu_leave_type(leave_type_code),
    balance_year        INT             NOT NULL,
    
    entitled_days       NUMERIC(5,1)    NOT NULL DEFAULT 0,
    taken_days          NUMERIC(5,1)    NOT NULL DEFAULT 0,
    pending_days        NUMERIC(5,1)    NOT NULL DEFAULT 0,
    remaining_days      NUMERIC(5,1)    GENERATED ALWAYS AS (entitled_days - taken_days - pending_days) STORED,
    carried_forward     NUMERIC(5,1)    NOT NULL DEFAULT 0,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_leave_balance UNIQUE (worker_id, leave_type_code, balance_year)
);

CREATE INDEX idx_lb_worker ON worker_leave_balance(worker_id);
CREATE INDEX idx_lb_year ON worker_leave_balance(balance_year);

COMMENT ON TABLE worker_leave_balance IS 
    'Annual leave entitlement and consumption tracking per worker per leave type.';


-- ============================================================================
-- SECTION 11: TRAINING RECORDS
-- ============================================================================

CREATE TABLE worker_training (
    training_id         SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    training_type_code  VARCHAR(30)     NOT NULL REFERENCES lu_training_type(training_type_code),
    
    training_title      VARCHAR(200),
    start_date          DATE            NOT NULL,
    end_date            DATE,
    duration_days       INT,
    
    trainer_name        VARCHAR(200),
    training_location   VARCHAR(200),
    training_method     VARCHAR(30)     CHECK (training_method IN (
                                            'CLASSROOM', 'FIELD_PRACTICAL', 'ON_JOB',
                                            'VR_SIMULATION', 'MR_TRAINING', 'E_LEARNING', 'HYBRID'
                                        )),
    
    -- Assessment
    assessment_score    NUMERIC(5,2),
    passed              BOOLEAN,
    certificate_number  VARCHAR(50),
    certificate_expiry  DATE,
    certificate_url     VARCHAR(1000),
    
    -- Cost
    training_cost       NUMERIC(12,2),
    currency_code       VARCHAR(3)      DEFAULT 'LKR',
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wt_worker ON worker_training(worker_id);
CREATE INDEX idx_wt_type ON worker_training(training_type_code);
CREATE INDEX idx_wt_dates ON worker_training(start_date, end_date);
CREATE INDEX idx_wt_cert_expiry ON worker_training(certificate_expiry) WHERE certificate_expiry IS NOT NULL;

COMMENT ON TABLE worker_training IS 
    'Complete training history — classroom, field, VR/MR simulation, e-learning. Includes assessment and certification.';


-- ============================================================================
-- SECTION 12: WORKER PAY STRUCTURE
-- Defines pay components per worker (template for payroll generation)
-- ============================================================================

CREATE TABLE worker_pay_structure (
    pay_structure_id    SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    component_code      VARCHAR(30)     NOT NULL REFERENCES lu_pay_component(component_code),
    
    amount              NUMERIC(12,2)   NOT NULL,
    currency_code       VARCHAR(3)      DEFAULT 'LKR',
    frequency           VARCHAR(20)     NOT NULL
                                        CHECK (frequency IN ('PER_DAY', 'PER_MONTH', 'PER_KG', 'PER_TREE', 'ONE_TIME')),
    
    effective_from      DATE            NOT NULL,
    effective_to        DATE,
    
    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_worker_pay_comp UNIQUE (worker_id, component_code, effective_from)
);

CREATE INDEX idx_wps_worker ON worker_pay_structure(worker_id);
CREATE INDEX idx_wps_component ON worker_pay_structure(component_code);
CREATE INDEX idx_wps_dates ON worker_pay_structure(effective_from, effective_to);

COMMENT ON TABLE worker_pay_structure IS 
    'Pay component structure per worker — basic salary, piece rates, allowances, deductions with effective dating.';


-- ============================================================================
-- SECTION 13: WORKER HEALTH & SAFETY INCIDENT
-- ============================================================================

CREATE TABLE worker_safety_incident (
    incident_id         SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    field_id            INT             REFERENCES field(field_id),
    
    incident_date       DATE            NOT NULL,
    incident_time       TIME,
    
    incident_type       VARCHAR(30)     NOT NULL
                                        CHECK (incident_type IN (
                                            'INJURY', 'NEAR_MISS', 'SNAKE_BITE',
                                            'CHEMICAL_EXPOSURE', 'FALL', 'CUT_WOUND',
                                            'EQUIPMENT_ACCIDENT', 'HEAT_STROKE',
                                            'INSECT_STING', 'VEHICLE_ACCIDENT', 'OTHER'
                                        )),
    severity            VARCHAR(20)     NOT NULL
                                        CHECK (severity IN ('MINOR', 'MODERATE', 'SERIOUS', 'FATAL')),
    
    description         TEXT            NOT NULL,
    body_part_affected  VARCHAR(100),
    
    -- First aid / Treatment
    first_aid_given     BOOLEAN         NOT NULL DEFAULT FALSE,
    hospital_referral   BOOLEAN         NOT NULL DEFAULT FALSE,
    hospital_name       VARCHAR(200),
    days_lost           INT             DEFAULT 0,
    
    -- Investigation
    root_cause          TEXT,
    corrective_action   TEXT,
    investigated_by     VARCHAR(100),
    investigation_date  DATE,
    
    -- Reporting
    reported_to_authority BOOLEAN       NOT NULL DEFAULT FALSE,
    authority_report_ref VARCHAR(100),
    
    photo_urls          TEXT[],
    
    -- Witnesses
    witness_names       TEXT,
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_safety_worker ON worker_safety_incident(worker_id);
CREATE INDEX idx_safety_plantation ON worker_safety_incident(plantation_id);
CREATE INDEX idx_safety_date ON worker_safety_incident(incident_date);
CREATE INDEX idx_safety_type ON worker_safety_incident(incident_type);
CREATE INDEX idx_safety_severity ON worker_safety_incident(severity);

COMMENT ON TABLE worker_safety_incident IS 
    'Occupational health & safety incident records — injuries, near misses, investigations, corrective actions.';


-- ============================================================================
-- SECTION 14: VIEWS
-- ============================================================================

-- 14.1 Worker Full Profile
CREATE OR REPLACE VIEW vw_worker_profile AS
SELECT
    w.worker_id,
    w.employee_code,
    w.full_name,
    w.gender,
    w.date_of_birth,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, w.date_of_birth))::INT AS age,
    w.nationality,
    w.mobile_phone,
    
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    
    wc.category_name    AS role,
    wc.category_group   AS role_group,
    et.employment_type_name,
    ws.status_name      AS current_status,
    ws.is_active_duty,
    
    w.hire_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, w.hire_date))::INT AS years_of_service,
    
    f.field_code        AS primary_field,
    g.gang_code,
    g.gang_name,
    
    mgr.full_name       AS reports_to,
    
    w.base_pay_amount,
    w.pay_currency,
    w.pay_frequency,
    w.biometric_id      IS NOT NULL AS has_biometric,
    w.nfc_badge_uid     IS NOT NULL AS has_nfc_badge

FROM worker w
JOIN plantation p ON p.plantation_id = w.plantation_id
LEFT JOIN division d ON d.division_id = w.division_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
JOIN lu_employment_type et ON et.employment_type_code = w.employment_type_code
JOIN lu_worker_status ws ON ws.status_code = w.worker_status
LEFT JOIN field f ON f.field_id = w.primary_field_id
LEFT JOIN gang g ON g.gang_id = w.assigned_gang_id
LEFT JOIN worker mgr ON mgr.worker_id = w.reports_to_id;


-- 14.2 Gang Roster
CREATE OR REPLACE VIEW vw_gang_roster AS
SELECT
    g.gang_id,
    g.gang_code,
    g.gang_name,
    p.plantation_code,
    d.division_code,
    f.field_code        AS primary_field,
    ldr.full_name       AS gang_leader,
    g.target_size,
    g.current_size,
    
    COUNT(w.worker_id)                                          AS actual_members,
    COUNT(w.worker_id) FILTER (WHERE ws.is_active_duty = TRUE)  AS active_members,
    
    STRING_AGG(DISTINCT wc.category_name, ', ')                 AS roles_in_gang

FROM gang g
JOIN plantation p ON p.plantation_id = g.plantation_id
LEFT JOIN division d ON d.division_id = g.division_id
LEFT JOIN field f ON f.field_id = g.primary_field_id
LEFT JOIN worker ldr ON ldr.worker_id = g.leader_worker_id
LEFT JOIN worker w ON w.assigned_gang_id = g.gang_id
LEFT JOIN lu_worker_status ws ON ws.status_code = w.worker_status
LEFT JOIN lu_worker_category wc ON wc.category_code = w.category_code
WHERE g.status = 'ACTIVE'
GROUP BY g.gang_id, g.gang_code, g.gang_name, p.plantation_code, 
         d.division_code, f.field_code, ldr.full_name, g.target_size, g.current_size;


-- 14.3 Expiring Documents Alert
CREATE OR REPLACE VIEW vw_expiring_documents AS
SELECT
    w.employee_code,
    w.full_name,
    p.plantation_code,
    dt.doc_type_name,
    wd.document_number,
    wd.expiry_date,
    (wd.expiry_date - CURRENT_DATE) AS days_until_expiry,
    CASE
        WHEN wd.expiry_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN wd.expiry_date <= CURRENT_DATE + 30 THEN 'EXPIRING_SOON'
        WHEN wd.expiry_date <= CURRENT_DATE + 90 THEN 'DUE_FOR_RENEWAL'
        ELSE 'OK'
    END AS alert_level
FROM worker_document wd
JOIN worker w ON w.worker_id = wd.worker_id
JOIN plantation p ON p.plantation_id = w.plantation_id
JOIN lu_document_type dt ON dt.doc_type_code = wd.doc_type_code
WHERE wd.status = 'ACTIVE'
  AND wd.expiry_date IS NOT NULL
  AND wd.expiry_date <= CURRENT_DATE + 90
ORDER BY wd.expiry_date ASC;


-- 14.4 Skill Gap Analysis
CREATE OR REPLACE VIEW vw_skill_gap_analysis AS
SELECT
    p.plantation_code,
    wc.category_name    AS role,
    ls.skill_name,
    ls.skill_category,
    
    COUNT(DISTINCT w.worker_id)                                         AS total_workers_in_role,
    COUNT(DISTINCT wsk.worker_id)                                       AS workers_with_skill,
    COUNT(DISTINCT w.worker_id) - COUNT(DISTINCT wsk.worker_id)         AS skill_gap,
    
    ROUND(AVG(pl.level_score) FILTER (WHERE pl.level_score IS NOT NULL), 1) AS avg_proficiency,
    
    COUNT(DISTINCT wsk.worker_id) FILTER (WHERE wsk.is_certified = TRUE) AS certified_count,
    COUNT(DISTINCT wsk.worker_id) FILTER (WHERE wsk.certification_expiry < CURRENT_DATE) AS expired_certs

FROM worker w
JOIN plantation p ON p.plantation_id = w.plantation_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
CROSS JOIN lu_skill ls
LEFT JOIN worker_skill wsk ON wsk.worker_id = w.worker_id AND wsk.skill_code = ls.skill_code
LEFT JOIN lu_proficiency_level pl ON pl.level_code = wsk.proficiency_level
WHERE w.worker_status IN ('ACTIVE', 'PROBATION', 'TRAINING')
  AND ls.skill_category = wc.category_group
GROUP BY p.plantation_code, wc.category_name, ls.skill_name, ls.skill_category
HAVING COUNT(DISTINCT w.worker_id) - COUNT(DISTINCT wsk.worker_id) > 0
ORDER BY skill_gap DESC;


-- ============================================================================
-- SECTION 15: TRIGGER FUNCTIONS
-- ============================================================================

-- 15.1 Auto-update timestamps
CREATE TRIGGER trg_worker_updated
    BEFORE UPDATE ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_gang_updated
    BEFORE UPDATE ON gang
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_skill_updated
    BEFORE UPDATE ON worker_skill
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_doc_updated
    BEFORE UPDATE ON worker_document
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_leave_updated
    BEFORE UPDATE ON worker_leave
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_lb_updated
    BEFORE UPDATE ON worker_leave_balance
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_training_updated
    BEFORE UPDATE ON worker_training
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_pay_updated
    BEFORE UPDATE ON worker_pay_structure
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_safety_updated
    BEFORE UPDATE ON worker_safety_incident
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- 15.2 Auto-log worker status changes
CREATE OR REPLACE FUNCTION fn_log_worker_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.worker_status IS DISTINCT FROM NEW.worker_status THEN
        INSERT INTO worker_status_change_log 
            (worker_id, change_date, from_status, to_status, effective_date, changed_by)
        VALUES 
            (NEW.worker_id, CURRENT_DATE, OLD.worker_status, NEW.worker_status, CURRENT_DATE, NEW.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_worker_status_change
    AFTER UPDATE OF worker_status ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_log_worker_status_change();

-- 15.3 Auto-update gang current_size
CREATE OR REPLACE FUNCTION fn_sync_gang_size()
RETURNS TRIGGER AS $$
DECLARE
    v_old_gang INT;
    v_new_gang INT;
BEGIN
    v_old_gang := COALESCE(OLD.assigned_gang_id, -1);
    v_new_gang := COALESCE(NEW.assigned_gang_id, -1);
    
    IF v_old_gang IS DISTINCT FROM v_new_gang THEN
        -- Decrement old gang
        IF OLD.assigned_gang_id IS NOT NULL THEN
            UPDATE gang SET current_size = GREATEST(current_size - 1, 0), updated_at = NOW()
            WHERE gang_id = OLD.assigned_gang_id;
        END IF;
        -- Increment new gang
        IF NEW.assigned_gang_id IS NOT NULL THEN
            UPDATE gang SET current_size = current_size + 1, updated_at = NOW()
            WHERE gang_id = NEW.assigned_gang_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_gang_size
    AFTER UPDATE OF assigned_gang_id ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_sync_gang_size();

-- Also handle INSERT/DELETE for gang size
CREATE OR REPLACE FUNCTION fn_gang_size_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assigned_gang_id IS NOT NULL THEN
        UPDATE gang SET current_size = current_size + 1, updated_at = NOW()
        WHERE gang_id = NEW.assigned_gang_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gang_size_insert
    AFTER INSERT ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_gang_size_on_insert();

-- 15.4 Auto-update leave balance when leave is approved
CREATE OR REPLACE FUNCTION fn_update_leave_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.approval_status = 'APPROVED' AND OLD.approval_status != 'APPROVED' THEN
        UPDATE worker_leave_balance 
        SET taken_days = taken_days + NEW.total_days,
            pending_days = GREATEST(pending_days - NEW.total_days, 0),
            updated_at = NOW()
        WHERE worker_id = NEW.worker_id 
          AND leave_type_code = NEW.leave_type_code
          AND balance_year = EXTRACT(YEAR FROM NEW.leave_start_date);
    END IF;
    IF NEW.approval_status = 'PENDING' AND OLD.approval_status != 'PENDING' THEN
        UPDATE worker_leave_balance 
        SET pending_days = pending_days + NEW.total_days,
            updated_at = NOW()
        WHERE worker_id = NEW.worker_id 
          AND leave_type_code = NEW.leave_type_code
          AND balance_year = EXTRACT(YEAR FROM NEW.leave_start_date);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_leave_balance
    AFTER UPDATE OF approval_status ON worker_leave
    FOR EACH ROW EXECUTE FUNCTION fn_update_leave_balance();


-- ============================================================================
-- SECTION 16: PERMISSIONS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON worker, gang, worker_skill, worker_field_assignment,
    worker_status_change_log, worker_next_of_kin, worker_document, worker_leave,
    worker_leave_balance, worker_training, worker_pay_structure, 
    worker_safety_incident TO plantation_manager;

GRANT SELECT ON lu_worker_category, lu_employment_type, lu_worker_status, lu_skill,
    lu_proficiency_level, lu_leave_type, lu_relationship_type, lu_document_type,
    lu_pay_component, lu_training_type TO plantation_manager;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;


-- ============================================================================
-- END OF MODULE 4: WORKFORCE MANAGEMENT
-- ============================================================================
