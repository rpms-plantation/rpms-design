-- ============================================================================
-- V4_001 — Module 4 (Workforce Management) — CREATE TABLE statements
-- Source: database/module-4-workforce/workforce_management_ddl.sql
-- Prerequisite: V1 (Module 1 — plantation, division, field) must have already run.
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

-- ----------------------------------------------------------------------------
-- 1.2 Employment Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_employment_type (
    employment_type_code VARCHAR(20)    PRIMARY KEY,
    employment_type_name VARCHAR(100)   NOT NULL,
    description          VARCHAR(500),
    is_active            BOOLEAN        NOT NULL DEFAULT TRUE
);

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

-- ----------------------------------------------------------------------------
-- 1.5 Proficiency Level Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_proficiency_level (
    level_code      VARCHAR(20)     PRIMARY KEY,
    level_name      VARCHAR(50)     NOT NULL,
    level_score     INT             NOT NULL CHECK (level_score BETWEEN 1 AND 5),
    description     VARCHAR(200)
);

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

-- ----------------------------------------------------------------------------
-- 1.7 Relationship Type Lookup (for next-of-kin)
-- ----------------------------------------------------------------------------
CREATE TABLE lu_relationship_type (
    relationship_code VARCHAR(20)    PRIMARY KEY,
    relationship_name VARCHAR(50)    NOT NULL,
    is_active         BOOLEAN        NOT NULL DEFAULT TRUE
);

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


-- ============================================================================
-- SECTION 2: WORKER — the core workforce entity
-- ============================================================================

CREATE TABLE worker (
    worker_id           SERIAL          PRIMARY KEY,

    -- Identification
    employee_code       VARCHAR(30)     NOT NULL UNIQUE,
    first_name          VARCHAR(100)    NOT NULL,
    last_name            VARCHAR(100)    NOT NULL,
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
    issued_date          DATE,
    expiry_date          DATE,
    issuing_authority    VARCHAR(200),

    file_url             VARCHAR(1000),
    file_name            VARCHAR(200),
    file_size_bytes      BIGINT,

    is_verified          BOOLEAN        NOT NULL DEFAULT FALSE,
    verified_by          VARCHAR(100),
    verified_at          TIMESTAMPTZ,

    status               VARCHAR(20)    NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'EXPIRED', 'REVOKED', 'PENDING_VERIFICATION')),

    remarks              TEXT,
    created_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

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
    remaining_days       NUMERIC(5,1)    GENERATED ALWAYS AS (entitled_days - taken_days - pending_days) STORED,
    carried_forward     NUMERIC(5,1)    NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_leave_balance UNIQUE (worker_id, leave_type_code, balance_year)
);

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

    trainer_name         VARCHAR(200),
    training_location    VARCHAR(200),
    training_method      VARCHAR(30)    CHECK (training_method IN (
                                            'CLASSROOM', 'FIELD_PRACTICAL', 'ON_JOB',
                                            'VR_SIMULATION', 'MR_TRAINING', 'E_LEARNING', 'HYBRID'
                                        )),

    -- Assessment
    assessment_score    NUMERIC(5,2),
    passed               BOOLEAN,
    certificate_number   VARCHAR(50),
    certificate_expiry   DATE,
    certificate_url       VARCHAR(1000),

    -- Cost
    training_cost        NUMERIC(12,2),
    currency_code        VARCHAR(3)     DEFAULT 'LKR',

    remarks               TEXT,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

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

    amount               NUMERIC(12,2)  NOT NULL,
    currency_code        VARCHAR(3)     DEFAULT 'LKR',
    frequency             VARCHAR(20)   NOT NULL
                                        CHECK (frequency IN ('PER_DAY', 'PER_MONTH', 'PER_KG', 'PER_TREE', 'ONE_TIME')),

    effective_from       DATE           NOT NULL,
    effective_to         DATE,

    remarks               TEXT,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_worker_pay_comp UNIQUE (worker_id, component_code, effective_from)
);

COMMENT ON TABLE worker_pay_structure IS
    'Pay component structure per worker — basic salary, piece rates, allowances, deductions with effective dating.';


-- ============================================================================
-- SECTION 13: WORKER HEALTH & SAFETY INCIDENT
-- ============================================================================

CREATE TABLE worker_safety_incident (
    incident_id          SERIAL         PRIMARY KEY,
    worker_id            INT            NOT NULL REFERENCES worker(worker_id),
    plantation_id        INT            NOT NULL REFERENCES plantation(plantation_id),
    field_id             INT            REFERENCES field(field_id),

    incident_date        DATE           NOT NULL,
    incident_time        TIME,

    incident_type        VARCHAR(30)    NOT NULL
                                        CHECK (incident_type IN (
                                            'INJURY', 'NEAR_MISS', 'SNAKE_BITE',
                                            'CHEMICAL_EXPOSURE', 'FALL', 'CUT_WOUND',
                                            'EQUIPMENT_ACCIDENT', 'HEAT_STROKE',
                                            'INSECT_STING', 'VEHICLE_ACCIDENT', 'OTHER'
                                        )),
    severity              VARCHAR(20)   NOT NULL
                                        CHECK (severity IN ('MINOR', 'MODERATE', 'SERIOUS', 'FATAL')),

    description           TEXT          NOT NULL,
    body_part_affected     VARCHAR(100),

    -- First aid / Treatment
    first_aid_given        BOOLEAN      NOT NULL DEFAULT FALSE,
    hospital_referral       BOOLEAN     NOT NULL DEFAULT FALSE,
    hospital_name            VARCHAR(200),
    days_lost                INT        DEFAULT 0,

    -- Investigation
    root_cause                TEXT,
    corrective_action          TEXT,
    investigated_by             VARCHAR(100),
    investigation_date           DATE,

    -- Reporting
    reported_to_authority         BOOLEAN  NOT NULL DEFAULT FALSE,
    authority_report_ref           VARCHAR(100),

    photo_urls                      TEXT[],

    -- Witnesses
    witness_names                    TEXT,

    created_at                        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE worker_safety_incident IS
    'Occupational health & safety incident records — injuries, near misses, investigations, corrective actions.';