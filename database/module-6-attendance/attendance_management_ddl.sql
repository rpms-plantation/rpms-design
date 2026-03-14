-- ============================================================================
-- RUBBER PLANTATION MANAGEMENT SYSTEM
-- Module 6: ATTENDANCE MANAGEMENT
-- Database: PostgreSQL 15+ with PostGIS Extension
-- Version: 1.0
-- Description: Complete DDL for daily attendance capture via multiple methods
--              (biometric, NFC, GPS geofence, mobile app, manual), shift
--              management, overtime tracking, attendance regularization,
--              monthly summaries, payroll-ready calculations, absence pattern
--              detection, and integration with leave (M4) and activity (M5).
--
-- Dependencies:
--   Module 1: plantation, division, field
--   Module 3: iot_device (geofence beacons, GPS wearables)
--   Module 4: worker, gang, worker_leave, lu_leave_type, lu_worker_status
--   Module 5: daily_activity (cross-reference for attendance-activity link)
-- ============================================================================


-- ============================================================================
-- SECTION 1: LOOKUP / MASTER TABLES
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

INSERT INTO lu_attendance_status (status_code, status_name, is_present, is_paid, affects_bonus, display_color, display_order, description) VALUES
    ('PRESENT',         'Present',                  TRUE,   TRUE,   FALSE,  '#22C55E',  1,  'Worker reported and worked the full shift'),
    ('PRESENT_HALF',    'Present (Half Day)',        TRUE,   TRUE,   TRUE,   '#84CC16',  2,  'Worker present for half the shift only'),
    ('LATE',            'Present (Late Arrival)',    TRUE,   TRUE,   TRUE,   '#EAB308',  3,  'Arrived after grace period, worked the shift'),
    ('EARLY_OUT',       'Present (Early Departure)', TRUE,  TRUE,   TRUE,   '#F97316',  4,  'Left before shift end without approval'),
    ('ABSENT_UA',       'Absent (Unauthorized)',     FALSE,  FALSE,  TRUE,   '#EF4444',  5,  'Did not report and no approved leave'),
    ('ABSENT_AL',       'Absent (Annual Leave)',     FALSE,  TRUE,   FALSE,  '#60A5FA',  6,  'On approved annual leave'),
    ('ABSENT_SL',       'Absent (Sick Leave)',       FALSE,  TRUE,   FALSE,  '#A78BFA',  7,  'On approved sick leave'),
    ('ABSENT_CL',       'Absent (Casual Leave)',     FALSE,  TRUE,   FALSE,  '#22D3EE',  8,  'On approved casual leave'),
    ('ABSENT_ML',       'Absent (Maternity Leave)',  FALSE,  TRUE,   FALSE,  '#F472B6',  9,  'On approved maternity leave'),
    ('ABSENT_IL',       'Absent (Injury Leave)',     FALSE,  TRUE,   FALSE,  '#FB923C',  10, 'On approved work injury leave'),
    ('ABSENT_OL',       'Absent (Other Leave)',      FALSE,  TRUE,   FALSE,  '#94A3B8',  11, 'On other approved leave types'),
    ('HOLIDAY',         'Public / Estate Holiday',   FALSE,  TRUE,   FALSE,  '#2DD4BF',  12, 'Official holiday — no work required'),
    ('REST_DAY',        'Scheduled Rest Day',        FALSE,  FALSE,  FALSE,  '#6B7280',  13, 'Scheduled day off per roster'),
    ('SUSPENDED',       'Suspended',                 FALSE,  FALSE,  TRUE,   '#DC2626',  14, 'Under suspension — not permitted to work'),
    ('TRAINING',        'On Training',               TRUE,   TRUE,   FALSE,  '#8B5CF6',  15, 'Attending scheduled training program'),
    ('TRANSFERRED',     'Transferred Out',           FALSE,  FALSE,  FALSE,  '#9CA3AF',  16, 'No longer at this plantation');

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

INSERT INTO lu_checkin_method (method_code, method_name, reliability_score, requires_device, description) VALUES
    ('BIOMETRIC_FP',    'Fingerprint Biometric',        5,  TRUE,   'Fingerprint scanner at muster point or gate'),
    ('BIOMETRIC_FACE',  'Facial Recognition',           5,  TRUE,   'Camera-based face recognition at entry'),
    ('NFC_BADGE',       'NFC Badge Tap',                4,  TRUE,   'NFC badge tapped on field reader or mobile device'),
    ('GPS_GEOFENCE',    'GPS Geofence Auto-Detect',     4,  TRUE,   'Auto check-in when GPS wearable enters field boundary'),
    ('MOBILE_APP',      'Mobile App Check-In',          3,  FALSE,  'Worker self-check-in via plantation mobile app'),
    ('QR_SCAN',         'QR Code Scan',                 3,  TRUE,   'Scan QR code at muster point via mobile camera'),
    ('SUPERVISOR',      'Supervisor Manual Entry',      2,  FALSE,  'Supervisor marks attendance on tablet or paper'),
    ('MUSTER_ROLL',     'Traditional Muster Roll',      1,  FALSE,  'Paper-based roll call at morning muster');

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

INSERT INTO lu_shift (shift_code, shift_name, start_time, end_time, break_minutes, work_hours, grace_minutes, half_day_hours) VALUES
    ('TAPPING_AM',      'Early Morning Tapping Shift',  '04:30',    '11:30',    30, 6.5,  15, 3.5),
    ('FIELD_DAY',       'Daytime Field Work Shift',     '07:00',    '16:00',    60, 8.0,  15, 4.0),
    ('FACTORY_DAY',     'Factory Day Shift',            '06:00',    '14:00',    30, 7.5,  10, 4.0),
    ('FACTORY_NIGHT',   'Factory Night Shift',          '22:00',    '06:00',    30, 7.5,  10, 4.0),
    ('OFFICE',          'Office / Admin Shift',         '08:00',    '17:00',    60, 8.0,  15, 4.0),
    ('NURSERY',         'Nursery Work Shift',           '06:30',    '14:30',    30, 7.5,  15, 4.0),
    ('SPLIT',           'Split Shift (Tapping + PM)',   '04:30',    '16:00',    180,8.0,  15, 4.0);

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

INSERT INTO lu_overtime_type (overtime_code, overtime_name, multiplier, max_hours_per_day) VALUES
    ('OT_NORMAL',       'Normal Overtime',          1.5,    4.0),
    ('OT_HOLIDAY',      'Holiday Overtime',         2.0,    8.0),
    ('OT_NIGHT',        'Night Shift Overtime',     2.0,    4.0),
    ('OT_EMERGENCY',    'Emergency Call-Out',       2.5,    NULL);

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

INSERT INTO lu_regularization_reason (reason_code, reason_name, auto_approve) VALUES
    ('FORGOT_BADGE',        'Forgot NFC Badge / Biometric Failure',     FALSE),
    ('DEVICE_MALFUNCTION',  'Check-In Device Malfunction',              TRUE),
    ('FIELD_DIRECT',        'Went Directly to Field (Skipped Muster)',  FALSE),
    ('OFFICIAL_DUTY',       'On Official Duty Outside Plantation',      FALSE),
    ('SUPERVISOR_OVERRIDE', 'Supervisor Correction / Override',         FALSE),
    ('SYSTEM_ERROR',        'System Error / Data Loss',                 TRUE),
    ('RAIN_DELAY',          'Delayed Start Due to Rain',                TRUE),
    ('MEDICAL_EMERGENCY',   'Medical Emergency During Shift',           FALSE),
    ('OTHER',               'Other Reason',                             FALSE);


-- ============================================================================
-- SECTION 2: ATTENDANCE LOCATION / MUSTER POINT
-- Physical check-in points within a plantation
-- ============================================================================

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
    gps_longitude       NUMERIC(10,7),
    
    status              VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE'
                                        CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE')),
    
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    
    CONSTRAINT uq_attendance_location UNIQUE (plantation_id, location_code)
);

CREATE INDEX idx_att_loc_plantation ON attendance_location(plantation_id);
CREATE INDEX idx_att_loc_geofence ON attendance_location USING GIST(geofence_center);
CREATE INDEX idx_att_loc_polygon ON attendance_location USING GIST(geofence_polygon);

COMMENT ON TABLE attendance_location IS 
    'Physical muster/check-in points with biometric/NFC device registration and geofence boundaries for auto-detection.';


-- ============================================================================
-- SECTION 3: DAILY ATTENDANCE — the core per-worker per-day record
-- ============================================================================

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
    overtime_hours      NUMERIC(4,2)    DEFAULT 0,
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

CREATE INDEX idx_att_worker ON daily_attendance(worker_id);
CREATE INDEX idx_att_plantation ON daily_attendance(plantation_id);
CREATE INDEX idx_att_date ON daily_attendance(attendance_date);
CREATE INDEX idx_att_status ON daily_attendance(attendance_status);
CREATE INDEX idx_att_shift ON daily_attendance(shift_code);
CREATE INDEX idx_att_worker_date ON daily_attendance(worker_id, attendance_date);
CREATE INDEX idx_att_date_status ON daily_attendance(attendance_date, attendance_status);
CREATE INDEX idx_att_checkin_gps ON daily_attendance USING GIST(check_in_gps_point);
CREATE INDEX idx_att_late ON daily_attendance(is_late) WHERE is_late = TRUE;
CREATE INDEX idx_att_overtime ON daily_attendance(has_overtime) WHERE has_overtime = TRUE;
CREATE INDEX idx_att_anomaly ON daily_attendance(ai_anomaly_flag) WHERE ai_anomaly_flag = TRUE;
CREATE INDEX idx_att_leave ON daily_attendance(leave_id) WHERE leave_id IS NOT NULL;
CREATE INDEX idx_att_regularized ON daily_attendance(is_regularized) WHERE is_regularized = TRUE;

COMMENT ON TABLE daily_attendance IS 
    'Core daily attendance record — one per worker per day. Captures check-in/out via biometric, NFC, GPS, '
    'or mobile app with geofence verification, auto-calculated hours, overtime, leave linkage, and AI anomaly detection.';


-- ============================================================================
-- SECTION 4: ATTENDANCE RAW SCAN LOG (immutable event log)
-- Every scan event — supports multiple scans per day per worker
-- ============================================================================

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
    gps_longitude       NUMERIC(10,7),
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

CREATE INDEX idx_scan_worker ON attendance_scan_log(worker_id);
CREATE INDEX idx_scan_timestamp ON attendance_scan_log(scan_timestamp);
CREATE INDEX idx_scan_worker_date ON attendance_scan_log(worker_id, scan_timestamp);
CREATE INDEX idx_scan_type ON attendance_scan_log(scan_type);
CREATE INDEX idx_scan_method ON attendance_scan_log(method_code);
CREATE INDEX idx_scan_location ON attendance_scan_log(location_id);
CREATE INDEX idx_scan_gps ON attendance_scan_log USING GIST(gps_point);
CREATE INDEX idx_scan_verified ON attendance_scan_log(is_verified) WHERE is_verified = FALSE;

COMMENT ON TABLE attendance_scan_log IS 
    'Immutable raw event log of every scan — biometric, NFC tap, GPS detection, QR scan. '
    'Multiple entries per worker per day possible (IN, OUT, FIELD_IN, FIELD_OUT). '
    'The daily_attendance table is derived from this log; the log itself is the audit source of truth.';


-- ============================================================================
-- SECTION 5: ATTENDANCE REGULARIZATION
-- Corrections to attendance records with approval workflow
-- ============================================================================

CREATE TABLE attendance_regularization (
    regularization_id   SERIAL          PRIMARY KEY,
    attendance_id       BIGINT          NOT NULL REFERENCES daily_attendance(attendance_id),
    
    -- What changed
    original_status     VARCHAR(20)     REFERENCES lu_attendance_status(status_code),
    corrected_status    VARCHAR(20)     NOT NULL REFERENCES lu_attendance_status(status_code),
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

CREATE INDEX idx_reg_attendance ON attendance_regularization(attendance_id);
CREATE INDEX idx_reg_status ON attendance_regularization(approval_status);
CREATE INDEX idx_reg_requested_by ON attendance_regularization(requested_by);

COMMENT ON TABLE attendance_regularization IS 
    'Attendance correction requests with full before/after data, approval workflow, and blockchain anchoring.';


-- ============================================================================
-- SECTION 6: WORKER SHIFT ROSTER
-- Pre-assigned shift schedule per worker per period
-- ============================================================================

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

CREATE INDEX idx_roster_worker ON worker_shift_roster(worker_id);
CREATE INDEX idx_roster_date ON worker_shift_roster(roster_date);
CREATE INDEX idx_roster_plantation ON worker_shift_roster(plantation_id);
CREATE INDEX idx_roster_shift ON worker_shift_roster(shift_code);

COMMENT ON TABLE worker_shift_roster IS 
    'Pre-assigned shift roster per worker per day — defines expected shift, rest days, holidays, and field assignment.';


-- ============================================================================
-- SECTION 7: MONTHLY ATTENDANCE SUMMARY
-- Payroll-ready monthly rollup per worker
-- ============================================================================

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

CREATE INDEX idx_mas_worker ON monthly_attendance_summary(worker_id);
CREATE INDEX idx_mas_period ON monthly_attendance_summary(summary_year, summary_month);
CREATE INDEX idx_mas_plantation ON monthly_attendance_summary(plantation_id);

COMMENT ON TABLE monthly_attendance_summary IS 
    'Payroll-ready monthly attendance rollup — day counts, hours, overtime, attendance rate, bonus eligibility, and manager sign-off.';


-- ============================================================================
-- SECTION 8: PLANTATION DAILY ATTENDANCE SNAPSHOT
-- Estate-level daily aggregation
-- ============================================================================

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

CREATE INDEX idx_pda_plantation ON plantation_daily_attendance(plantation_id);
CREATE INDEX idx_pda_date ON plantation_daily_attendance(snapshot_date);

COMMENT ON TABLE plantation_daily_attendance IS 
    'Plantation-level daily attendance snapshot — headcount, category breakdown, rates, and AI pattern alerts.';


-- ============================================================================
-- SECTION 9: VIEWS
-- ============================================================================

-- 9.1 Daily Attendance Dashboard
CREATE OR REPLACE VIEW vw_attendance_dashboard AS
SELECT
    da.attendance_date,
    p.plantation_code,
    d.division_code,
    
    w.employee_code,
    w.full_name,
    wc.category_name    AS role,
    g.gang_code,
    
    sh.shift_name,
    sh.start_time       AS shift_start,
    sh.end_time         AS shift_end,
    
    ast.status_name     AS attendance_status,
    ast.display_color,
    ast.is_present,
    ast.is_paid,
    
    da.check_in_time,
    cm_in.method_name   AS check_in_method,
    da.check_out_time,
    
    da.net_work_hours,
    da.is_late,
    da.late_minutes,
    da.is_early_departure,
    
    da.has_overtime,
    da.overtime_hours,
    
    da.geofence_verified,
    da.time_in_field_hours,
    
    da.ai_anomaly_flag,
    da.ai_anomaly_type,
    
    da.is_regularized

FROM daily_attendance da
JOIN worker w ON w.worker_id = da.worker_id
JOIN plantation p ON p.plantation_id = da.plantation_id
LEFT JOIN division d ON d.division_id = da.division_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
LEFT JOIN gang g ON g.gang_id = w.assigned_gang_id
JOIN lu_shift sh ON sh.shift_code = da.shift_code
JOIN lu_attendance_status ast ON ast.status_code = da.attendance_status
LEFT JOIN lu_checkin_method cm_in ON cm_in.method_code = da.check_in_method
ORDER BY da.attendance_date DESC, p.plantation_code, w.employee_code;


-- 9.2 Absenteeism Pattern Analysis
CREATE OR REPLACE VIEW vw_absenteeism_patterns AS
SELECT
    w.worker_id,
    w.employee_code,
    w.full_name,
    p.plantation_code,
    wc.category_name    AS role,
    
    COUNT(*) FILTER (WHERE ast.is_present = FALSE AND da.attendance_status NOT IN ('HOLIDAY','REST_DAY','TRAINING'))
                                                        AS total_absent_days,
    COUNT(*) FILTER (WHERE da.attendance_status = 'ABSENT_UA')  AS unauthorized_absences,
    COUNT(*) FILTER (WHERE da.is_late = TRUE)                    AS late_days,
    
    -- Streak analysis
    MAX(consecutive_absent.streak)                              AS max_consecutive_absent,
    
    -- Day-of-week pattern
    MODE() WITHIN GROUP (ORDER BY EXTRACT(DOW FROM da.attendance_date))
        FILTER (WHERE da.attendance_status = 'ABSENT_UA')       AS most_common_absent_dow,
    
    -- Rates (last 30 days)
    ROUND(COUNT(*) FILTER (WHERE ast.is_present = TRUE) * 100.0 / 
          NULLIF(COUNT(*) FILTER (WHERE da.attendance_status NOT IN ('HOLIDAY','REST_DAY')), 0), 1) 
                                                                AS attendance_rate_30d

FROM daily_attendance da
JOIN worker w ON w.worker_id = da.worker_id
JOIN plantation p ON p.plantation_id = da.plantation_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
JOIN lu_attendance_status ast ON ast.status_code = da.attendance_status
LEFT JOIN LATERAL (
    SELECT MAX(cnt) AS streak FROM (
        SELECT COUNT(*) AS cnt FROM (
            SELECT attendance_date,
                   attendance_date - ROW_NUMBER() OVER (ORDER BY attendance_date)::INT AS grp
            FROM daily_attendance sub
            WHERE sub.worker_id = da.worker_id 
              AND sub.attendance_status = 'ABSENT_UA'
        ) grouped
        GROUP BY grp
    ) streaks
) consecutive_absent ON TRUE
WHERE da.attendance_date >= CURRENT_DATE - 30
GROUP BY w.worker_id, w.employee_code, w.full_name, p.plantation_code, wc.category_name, 
         consecutive_absent.streak
HAVING COUNT(*) FILTER (WHERE da.attendance_status = 'ABSENT_UA') > 0
ORDER BY unauthorized_absences DESC;


-- 9.3 Overtime Summary View
CREATE OR REPLACE VIEW vw_overtime_summary AS
SELECT
    w.employee_code,
    w.full_name,
    p.plantation_code,
    wc.category_name    AS role,
    
    da.attendance_date,
    sh.shift_name,
    ot.overtime_name,
    ot.multiplier,
    
    da.net_work_hours,
    da.overtime_hours,
    ROUND(da.overtime_hours * ot.multiplier, 2) AS ot_equivalent_hours,
    
    da.overtime_approved,
    appr.full_name      AS approved_by

FROM daily_attendance da
JOIN worker w ON w.worker_id = da.worker_id
JOIN plantation p ON p.plantation_id = da.plantation_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
JOIN lu_shift sh ON sh.shift_code = da.shift_code
LEFT JOIN lu_overtime_type ot ON ot.overtime_code = da.overtime_type_code
LEFT JOIN worker appr ON appr.worker_id = da.overtime_approved_by
WHERE da.has_overtime = TRUE
ORDER BY da.attendance_date DESC, da.overtime_hours DESC;


-- 9.4 Payroll-Ready Monthly View
CREATE OR REPLACE VIEW vw_payroll_attendance AS
SELECT
    mas.summary_year,
    mas.summary_month,
    p.plantation_code,
    
    w.employee_code,
    w.full_name,
    wc.category_name    AS role,
    et.employment_type_name,
    
    mas.working_days,
    mas.days_present,
    mas.days_half,
    mas.days_on_leave,
    mas.days_absent_unpaid,
    mas.days_holiday,
    
    mas.payable_days,
    mas.total_work_hours,
    mas.total_overtime_hours,
    mas.total_ot_normal_hrs,
    mas.total_ot_holiday_hrs,
    mas.total_ot_night_hrs,
    
    mas.attendance_rate_pct,
    mas.eligible_for_attendance_bonus,
    mas.attendance_bonus_amount,
    
    mas.verified_by IS NOT NULL AS is_verified

FROM monthly_attendance_summary mas
JOIN worker w ON w.worker_id = mas.worker_id
JOIN plantation p ON p.plantation_id = mas.plantation_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
JOIN lu_employment_type et ON et.employment_type_code = w.employment_type_code
ORDER BY mas.summary_year DESC, mas.summary_month DESC, p.plantation_code, w.employee_code;


-- ============================================================================
-- SECTION 10: TRIGGER FUNCTIONS
-- ============================================================================

-- 10.1 Auto-update timestamps
CREATE TRIGGER trg_daily_attendance_updated
    BEFORE UPDATE ON daily_attendance
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_attendance_reg_updated
    BEFORE UPDATE ON attendance_regularization
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_attendance_loc_updated
    BEFORE UPDATE ON attendance_location
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_monthly_summary_updated
    BEFORE UPDATE ON monthly_attendance_summary
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- 10.2 Auto-calculate hours, late, early departure
CREATE OR REPLACE FUNCTION fn_calc_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_shift RECORD;
    v_expected_start TIMESTAMPTZ;
BEGIN
    IF NEW.check_in_time IS NOT NULL AND NEW.check_out_time IS NOT NULL THEN
        -- Gross hours
        NEW.gross_hours = ROUND(EXTRACT(EPOCH FROM (NEW.check_out_time - NEW.check_in_time)) / 3600, 2);
        
        -- Get shift break
        SELECT break_minutes, grace_minutes, start_time INTO v_shift
        FROM lu_shift WHERE shift_code = NEW.shift_code;
        
        NEW.break_minutes = COALESCE(NEW.break_minutes, COALESCE(v_shift.break_minutes, 0));
        NEW.net_work_hours = GREATEST(NEW.gross_hours - (NEW.break_minutes / 60.0), 0);
        
        -- Late detection
        IF v_shift.start_time IS NOT NULL THEN
            v_expected_start = (NEW.attendance_date + v_shift.start_time)::TIMESTAMPTZ;
            IF NEW.check_in_time > (v_expected_start + (COALESCE(v_shift.grace_minutes, 15) || ' minutes')::INTERVAL) THEN
                NEW.is_late = TRUE;
                NEW.late_minutes = EXTRACT(EPOCH FROM (NEW.check_in_time - v_expected_start))::INT / 60;
            ELSE
                NEW.is_late = FALSE;
                NEW.late_minutes = 0;
            END IF;
        END IF;
        
        -- Overtime detection
        IF NEW.net_work_hours > COALESCE((SELECT work_hours FROM lu_shift WHERE shift_code = NEW.shift_code), 8) THEN
            NEW.has_overtime = TRUE;
            NEW.overtime_hours = ROUND(NEW.net_work_hours - 
                COALESCE((SELECT work_hours FROM lu_shift WHERE shift_code = NEW.shift_code), 8), 2);
        ELSE
            NEW.has_overtime = FALSE;
            NEW.overtime_hours = 0;
        END IF;
    END IF;
    
    -- Auto-populate GPS points
    IF NEW.check_in_gps_lat IS NOT NULL AND NEW.check_in_gps_lon IS NOT NULL THEN
        NEW.check_in_gps_point = ST_SetSRID(ST_MakePoint(NEW.check_in_gps_lon, NEW.check_in_gps_lat), 4326);
    END IF;
    IF NEW.check_out_gps_lat IS NOT NULL AND NEW.check_out_gps_lon IS NOT NULL THEN
        NEW.check_out_gps_point = ST_SetSRID(ST_MakePoint(NEW.check_out_gps_lon, NEW.check_out_gps_lat), 4326);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_attendance_hours
    BEFORE INSERT OR UPDATE OF check_in_time, check_out_time, shift_code ON daily_attendance
    FOR EACH ROW EXECUTE FUNCTION fn_calc_attendance_hours();

-- 10.3 Auto-populate GPS on scan log
CREATE OR REPLACE FUNCTION fn_scan_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scan_gps_sync
    BEFORE INSERT ON attendance_scan_log
    FOR EACH ROW EXECUTE FUNCTION fn_scan_sync_gps();

-- 10.4 Auto-apply regularization to daily_attendance when approved
CREATE OR REPLACE FUNCTION fn_apply_regularization()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.approval_status = 'APPROVED' AND OLD.approval_status != 'APPROVED' THEN
        UPDATE daily_attendance SET
            attendance_status = COALESCE(NEW.corrected_status, attendance_status),
            check_in_time = COALESCE(NEW.corrected_check_in, check_in_time),
            check_out_time = COALESCE(NEW.corrected_check_out, check_out_time),
            is_regularized = TRUE,
            regularization_id = NEW.regularization_id,
            updated_at = NOW(),
            updated_by = 'REGULARIZATION_' || NEW.regularization_id
        WHERE attendance_id = NEW.attendance_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_regularization
    AFTER UPDATE OF approval_status ON attendance_regularization
    FOR EACH ROW EXECUTE FUNCTION fn_apply_regularization();

-- 10.5 Auto-populate geofence center on attendance_location
CREATE OR REPLACE FUNCTION fn_att_loc_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.geofence_center = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_att_loc_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON attendance_location
    FOR EACH ROW EXECUTE FUNCTION fn_att_loc_sync_gps();


-- ============================================================================
-- SECTION 11: PERMISSIONS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON daily_attendance, attendance_scan_log, 
    attendance_regularization, worker_shift_roster, monthly_attendance_summary,
    plantation_daily_attendance, attendance_location TO plantation_manager;

GRANT SELECT ON lu_attendance_status, lu_checkin_method, lu_shift, lu_overtime_type,
    lu_regularization_reason TO plantation_manager;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO plantation_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO plantation_reader;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO plantation_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO plantation_admin;


-- ============================================================================
-- END OF MODULE 6: ATTENDANCE MANAGEMENT
-- ============================================================================
