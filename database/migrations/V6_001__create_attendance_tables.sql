-- ============================================================================
-- V6_001 — Module 6 (Attendance Management) — CREATE TABLE statements
-- Source: database/module-6-attendance/attendance_management_ddl.sql
-- Prerequisite: V1 (Module 1 — plantation, division), V4 (Module 4 — worker,
-- gang, worker_leave) must have already run. Module 3 (iot_device) and
-- Module 5 (daily_activity) are referenced by ID only — no FK, no hard
-- dependency.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Attendance Status Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_attendance_status (
    status_code     VARCHAR(20)     PRIMARY KEY,
    status_name     VARCHAR(100)    NOT NULL,
    is_present      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_paid         BOOLEAN         NOT NULL DEFAULT TRUE,
    affects_bonus   BOOLEAN         NOT NULL DEFAULT FALSE,
    display_color   VARCHAR(7),
    description     VARCHAR(500),
    display_order   INT             NOT NULL DEFAULT 0,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE lu_attendance_status IS
    'Attendance status catalog with payroll flags (is_paid), bonus impact, and display colors for calendar views.';

-- ----------------------------------------------------------------------------
-- 1.2 Check-in Method Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_checkin_method (
    method_code     VARCHAR(20)     PRIMARY KEY,
    method_name     VARCHAR(100)    NOT NULL,
    reliability_score INT           NOT NULL CHECK (reliability_score BETWEEN 1 AND 5),
    requires_device BOOLEAN         NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.3 Shift Definition Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_shift (
    shift_code      VARCHAR(20)     PRIMARY KEY,
    shift_name      VARCHAR(100)    NOT NULL,
    start_time      TIME            NOT NULL,
    end_time        TIME            NOT NULL,
    break_minutes   INT             NOT NULL DEFAULT 0,
    work_hours      NUMERIC(4,2)    NOT NULL,
    grace_minutes   INT             NOT NULL DEFAULT 15,
    half_day_hours  NUMERIC(4,2),
    is_night_shift  BOOLEAN         NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE lu_shift IS
    'Shift definitions with start/end times, break duration, grace period for late arrival, and half-day threshold.';

-- ----------------------------------------------------------------------------
-- 1.4 Overtime Type Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_overtime_type (
    overtime_code   VARCHAR(20)     PRIMARY KEY,
    overtime_name   VARCHAR(100)    NOT NULL,
    multiplier      NUMERIC(4,2)    NOT NULL DEFAULT 1.5,
    max_hours_per_day NUMERIC(4,2),
    requires_approval BOOLEAN       NOT NULL DEFAULT TRUE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 1.5 Regularization Reason Lookup
-- ----------------------------------------------------------------------------
CREATE TABLE lu_regularization_reason (
    reason_code     VARCHAR(30)     PRIMARY KEY,
    reason_name     VARCHAR(200)    NOT NULL,
    auto_approve    BOOLEAN         NOT NULL DEFAULT FALSE,
    description     VARCHAR(500),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 2. Attendance Location / Muster Point
-- ----------------------------------------------------------------------------
CREATE TABLE attendance_location (
    location_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),

    location_code       VARCHAR(30)     NOT NULL,
    location_name       VARCHAR(200)    NOT NULL,
    location_type       VARCHAR(30)     NOT NULL
                                        CHECK (location_type IN (
                                            'MUSTER_POINT', 'GATE', 'FIELD_ENTRY',
                                            'FACTORY_GATE', 'OFFICE', 'NURSERY_GATE'
                                        )),

    -- Installed devices
    has_biometric       BOOLEAN         NOT NULL DEFAULT FALSE,
    has_nfc_reader      BOOLEAN         NOT NULL DEFAULT FALSE,
    has_qr_scanner      BOOLEAN         NOT NULL DEFAULT FALSE,
    iot_device_id       INT,            -- FK to iot_device (M3) if applicable

    -- Geofence
    geofence_radius_m   NUMERIC(8,2)    DEFAULT 50,
    geofence_center     GEOMETRY(Point, 4326),
    geofence_polygon    GEOMETRY(Polygon, 4326),

    -- GPS
    gps_latitude        NUMERIC(10,7),
    gps_longitude        NUMERIC(10,7),

    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE')),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_attendance_location UNIQUE (plantation_id, location_code)
);

COMMENT ON TABLE attendance_location IS
    'Physical muster/check-in points with biometric/NFC device registration and geofence boundaries for auto-detection.';

-- ----------------------------------------------------------------------------
-- 3. Daily Attendance — the core per-worker per-day record
-- ----------------------------------------------------------------------------
CREATE TABLE daily_attendance (
    attendance_id       BIGSERIAL       PRIMARY KEY,

    -- Worker & Context
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),

    attendance_date     DATE            NOT NULL,

    -- Shift
    shift_code          VARCHAR(20)     NOT NULL REFERENCES lu_shift(shift_code),

    -- Status
    attendance_status   VARCHAR(20)     NOT NULL DEFAULT 'PRESENT'
                                        REFERENCES lu_attendance_status(status_code),

    -- Check-in
    check_in_time       TIMESTAMPTZ,
    check_in_method     VARCHAR(20)     REFERENCES lu_checkin_method(method_code),
    check_in_location_id INT            REFERENCES attendance_location(location_id),
    check_in_gps_lat    NUMERIC(10,7),
    check_in_gps_lon    NUMERIC(10,7),
    check_in_gps_point  GEOMETRY(Point, 4326),
    check_in_device_id  VARCHAR(100),   -- Biometric scanner ID / NFC reader ID
    check_in_photo_url  VARCHAR(1000),  -- Face recognition capture

    -- Check-out
    check_out_time      TIMESTAMPTZ,
    check_out_method    VARCHAR(20)     REFERENCES lu_checkin_method(method_code),
    check_out_location_id INT           REFERENCES attendance_location(location_id),
    check_out_gps_lat   NUMERIC(10,7),
    check_out_gps_lon   NUMERIC(10,7),
    check_out_gps_point GEOMETRY(Point, 4326),

    -- Calculated Hours (auto-populated by trigger)
    gross_hours         NUMERIC(5,2),   -- check_out - check_in
    break_minutes       INT,
    net_work_hours      NUMERIC(5,2),   -- gross_hours - break

    -- Late / Early tracking
    is_late             BOOLEAN         DEFAULT FALSE,
    late_minutes        INT             DEFAULT 0,
    is_early_departure  BOOLEAN         DEFAULT FALSE,
    early_departure_min INT             DEFAULT 0,

    -- Overtime
    has_overtime        BOOLEAN         NOT NULL DEFAULT FALSE,
    overtime_hours       NUMERIC(4,2)    DEFAULT 0,
    overtime_type_code  VARCHAR(20)     REFERENCES lu_overtime_type(overtime_code),
    overtime_approved   BOOLEAN         DEFAULT FALSE,
    overtime_approved_by INT            REFERENCES worker(worker_id),

    -- Leave linkage (if absent on approved leave)
    leave_id            INT             REFERENCES worker_leave(leave_id),

    -- Activity linkage (what the worker did that day)
    primary_activity_id BIGINT,         -- FK to daily_activity (M5)

    -- Geofence verification
    geofence_entry_time TIMESTAMPTZ,
    geofence_exit_time  TIMESTAMPTZ,
    geofence_verified   BOOLEAN         DEFAULT FALSE,
    time_in_field_hours NUMERIC(5,2),   -- Total time within field geofence

    -- Regularization (if attendance was corrected after the fact)
    is_regularized      BOOLEAN         NOT NULL DEFAULT FALSE,
    regularization_id   INT,            -- FK to attendance_regularization

    -- AI analysis
    ai_anomaly_flag     BOOLEAN         DEFAULT FALSE,
    ai_anomaly_type     VARCHAR(50),    -- e.g., 'UNUSUAL_PATTERN', 'LOCATION_MISMATCH', 'BUDDY_PUNCHING'
    ai_confidence       NUMERIC(5,2),

    -- Blockchain
    blockchain_tx_hash  VARCHAR(128),

    remarks             TEXT,

    -- Audit
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT uq_daily_attendance UNIQUE (worker_id, attendance_date),
    CONSTRAINT chk_checkout_after_checkin CHECK (
        check_out_time IS NULL
        OR check_in_time IS NULL
        OR check_out_time >= check_in_time
    )
);

COMMENT ON TABLE daily_attendance IS
    'Core daily attendance record — one per worker per day. Captures check-in/out via biometric, NFC, GPS, '
    'or mobile app with geofence verification, auto-calculated hours, overtime, leave linkage, and AI anomaly detection.';

-- ----------------------------------------------------------------------------
-- 4. Attendance Raw Scan Log (immutable event log)
-- ----------------------------------------------------------------------------
CREATE TABLE attendance_scan_log (
    scan_id             BIGSERIAL       PRIMARY KEY,

    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),

    scan_timestamp      TIMESTAMPTZ     NOT NULL,
    scan_type           VARCHAR(10)     NOT NULL CHECK (scan_type IN ('IN', 'OUT', 'FIELD_IN', 'FIELD_OUT')),

    method_code         VARCHAR(20)     NOT NULL REFERENCES lu_checkin_method(method_code),
    location_id         INT             REFERENCES attendance_location(location_id),

    -- Raw capture data
    device_id           VARCHAR(100),
    biometric_match_score NUMERIC(5,2), -- 0-100 confidence
    nfc_badge_uid       VARCHAR(100),

    -- GPS
    gps_latitude        NUMERIC(10,7),
    gps_longitude        NUMERIC(10,7),
    gps_point           GEOMETRY(Point, 4326),
    gps_accuracy_m      NUMERIC(6,2),

    -- Photo (for face recognition)
    photo_url           VARCHAR(1000),
    face_match_score    NUMERIC(5,2),

    -- Verification
    is_verified         BOOLEAN         NOT NULL DEFAULT TRUE,
    rejection_reason    VARCHAR(200),   -- If scan was rejected (e.g., low biometric score)

    -- Anti-fraud
    is_duplicate        BOOLEAN         DEFAULT FALSE,
    previous_scan_id    BIGINT,         -- If flagged as duplicate, reference to earlier scan

    -- Blockchain
    blockchain_tx_hash  VARCHAR(128),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE attendance_scan_log IS
    'Immutable raw event log of every scan — biometric, NFC tap, GPS detection, QR scan. '
    'Multiple entries per worker per day possible (IN, OUT, FIELD_IN, FIELD_OUT). '
    'The daily_attendance table is derived from this log; the log itself is the audit source of truth.';

-- ----------------------------------------------------------------------------
-- 5. Attendance Regularization
-- ----------------------------------------------------------------------------
CREATE TABLE attendance_regularization (
    regularization_id   SERIAL          PRIMARY KEY,
    attendance_id       BIGINT          NOT NULL REFERENCES daily_attendance(attendance_id),

    -- What changed
    original_status     VARCHAR(20)     REFERENCES lu_attendance_status(status_code),
    corrected_status     VARCHAR(20)     NOT NULL REFERENCES lu_attendance_status(status_code),
    original_check_in   TIMESTAMPTZ,
    corrected_check_in  TIMESTAMPTZ,
    original_check_out  TIMESTAMPTZ,
    corrected_check_out TIMESTAMPTZ,

    -- Why
    reason_code         VARCHAR(30)     NOT NULL REFERENCES lu_regularization_reason(reason_code),
    justification       TEXT            NOT NULL,
    supporting_doc_url  VARCHAR(1000),

    -- Approval
    requested_by        INT             NOT NULL REFERENCES worker(worker_id),
    requested_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    approval_status     VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                                        CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approved_by         INT             REFERENCES worker(worker_id),
    approved_at         TIMESTAMPTZ,
    rejection_reason    TEXT,

    -- Blockchain
    blockchain_tx_hash  VARCHAR(128),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Add FK back from daily_attendance to regularization
ALTER TABLE daily_attendance ADD CONSTRAINT fk_att_regularization
    FOREIGN KEY (regularization_id) REFERENCES attendance_regularization(regularization_id);

COMMENT ON TABLE attendance_regularization IS
    'Attendance correction requests with full before/after data, approval workflow, and blockchain anchoring.';

-- ----------------------------------------------------------------------------
-- 6. Worker Shift Roster
-- ----------------------------------------------------------------------------
CREATE TABLE worker_shift_roster (
    roster_id           SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),

    roster_date         DATE            NOT NULL,
    shift_code          VARCHAR(20)     NOT NULL REFERENCES lu_shift(shift_code),

    is_rest_day         BOOLEAN         NOT NULL DEFAULT FALSE,
    is_holiday          BOOLEAN         NOT NULL DEFAULT FALSE,

    assigned_field_id   INT             REFERENCES field(field_id),
    assigned_gang_id    INT             REFERENCES gang(gang_id),

    remarks             TEXT,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_by          VARCHAR(100),

    CONSTRAINT uq_worker_roster UNIQUE (worker_id, roster_date)
);

COMMENT ON TABLE worker_shift_roster IS
    'Pre-assigned shift roster per worker per day — defines expected shift, rest days, holidays, and field assignment.';

-- ----------------------------------------------------------------------------
-- 7. Monthly Attendance Summary
-- ----------------------------------------------------------------------------
CREATE TABLE monthly_attendance_summary (
    summary_id          SERIAL          PRIMARY KEY,
    worker_id           INT             NOT NULL REFERENCES worker(worker_id),
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),

    summary_month       INT             NOT NULL CHECK (summary_month BETWEEN 1 AND 12),
    summary_year        INT             NOT NULL,

    -- Day counts
    calendar_days       INT             NOT NULL,
    working_days        INT             NOT NULL,
    days_present        INT             NOT NULL DEFAULT 0,
    days_half           INT             NOT NULL DEFAULT 0,
    days_late           INT             NOT NULL DEFAULT 0,
    days_early_out      INT             NOT NULL DEFAULT 0,
    days_absent_paid    INT             NOT NULL DEFAULT 0,
    days_absent_unpaid  INT             NOT NULL DEFAULT 0,
    days_holiday        INT             NOT NULL DEFAULT 0,
    days_rest           INT             NOT NULL DEFAULT 0,
    days_training       INT             NOT NULL DEFAULT 0,
    days_on_leave       INT             NOT NULL DEFAULT 0,

    -- Hours
    total_work_hours    NUMERIC(8,2)    DEFAULT 0,
    total_overtime_hours NUMERIC(8,2)   DEFAULT 0,
    total_ot_normal_hrs NUMERIC(8,2)    DEFAULT 0,
    total_ot_holiday_hrs NUMERIC(8,2)   DEFAULT 0,
    total_ot_night_hrs  NUMERIC(8,2)    DEFAULT 0,

    -- Derived payroll metrics
    payable_days        NUMERIC(6,1),   -- present + paid_leave + holiday + half*0.5
    attendance_rate_pct NUMERIC(5,2),   -- days_present / working_days * 100

    -- Bonuses eligibility
    eligible_for_attendance_bonus BOOLEAN DEFAULT FALSE,
    attendance_bonus_amount NUMERIC(12,2),

    -- Late / Anomaly
    total_late_minutes  INT             DEFAULT 0,
    total_anomalies     INT             DEFAULT 0,

    -- Geofence
    avg_time_in_field_hours NUMERIC(5,2),

    -- Sign-off
    verified_by         INT             REFERENCES worker(worker_id),
    verified_at         TIMESTAMPTZ,

    -- Blockchain
    blockchain_tx_hash  VARCHAR(128),

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_monthly_summary UNIQUE (worker_id, summary_year, summary_month)
);

COMMENT ON TABLE monthly_attendance_summary IS
    'Payroll-ready monthly attendance rollup — day counts, hours, overtime, attendance rate, bonus eligibility, and manager sign-off.';

-- ----------------------------------------------------------------------------
-- 8. Plantation Daily Attendance Snapshot
-- ----------------------------------------------------------------------------
CREATE TABLE plantation_daily_attendance (
    snapshot_id         SERIAL          PRIMARY KEY,
    plantation_id       INT             NOT NULL REFERENCES plantation(plantation_id),
    division_id         INT             REFERENCES division(division_id),
    snapshot_date       DATE            NOT NULL,

    -- Headcount
    total_workers       INT             NOT NULL DEFAULT 0,
    workers_present     INT             NOT NULL DEFAULT 0,
    workers_late        INT             NOT NULL DEFAULT 0,
    workers_half_day    INT             NOT NULL DEFAULT 0,
    workers_on_leave    INT             NOT NULL DEFAULT 0,
    workers_absent_ua   INT             NOT NULL DEFAULT 0,
    workers_holiday     INT             NOT NULL DEFAULT 0,
    workers_training    INT             NOT NULL DEFAULT 0,

    -- By category
    tappers_present     INT             DEFAULT 0,
    tappers_total       INT             DEFAULT 0,
    field_workers_present INT           DEFAULT 0,
    factory_workers_present INT         DEFAULT 0,

    -- Rates
    attendance_rate_pct NUMERIC(5,2),
    tapper_attendance_pct NUMERIC(5,2),

    -- Weather context
    weather_condition   VARCHAR(30),
    rainfall_mm         NUMERIC(6,2),

    -- AI Insights
    ai_pattern_alerts   TEXT,           -- AI-detected unusual patterns

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_plantation_daily_att UNIQUE (plantation_id, division_id, snapshot_date)
);

COMMENT ON TABLE plantation_daily_attendance IS
    'Plantation-level daily attendance snapshot — headcount, category breakdown, rates, and AI pattern alerts.';
