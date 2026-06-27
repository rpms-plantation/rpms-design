-- ============================================================================
-- V6_005 — Module 6 (Attendance Management) — Seed lookup data
-- Source: database/module-6-attendance/attendance_management_ddl.sql
-- ============================================================================

INSERT INTO lu_attendance_status (status_code, status_name, is_present, is_paid, affects_bonus, display_color, display_order, description) VALUES
    ('PRESENT',         'Present',                  TRUE,   TRUE,   FALSE,  '#22C55E',  1,  'Worker reported and worked the full shift'),
    ('PRESENT_HALF',    'Present (Half Day)',        TRUE,   TRUE,   TRUE,   '#84CC16',  2,  'Worker present for half the shift only'),
    ('LATE',            'Present (Late Arrival)',    TRUE,   TRUE,   TRUE,   '#EAB308',  3,  'Arrived after grace period, worked the shift'),
    ('EARLY_OUT',       'Present (Early Departure)', TRUE,   TRUE,   TRUE,   '#F97316',  4,  'Left before shift end without approval'),
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

INSERT INTO lu_checkin_method (method_code, method_name, reliability_score, requires_device, description) VALUES
    ('BIOMETRIC_FP',    'Fingerprint Biometric',        5,  TRUE,   'Fingerprint scanner at muster point or gate'),
    ('BIOMETRIC_FACE',  'Facial Recognition',           5,  TRUE,   'Camera-based face recognition at entry'),
    ('NFC_BADGE',       'NFC Badge Tap',                4,  TRUE,   'NFC badge tapped on field reader or mobile device'),
    ('GPS_GEOFENCE',    'GPS Geofence Auto-Detect',     4,  TRUE,   'Auto check-in when GPS wearable enters field boundary'),
    ('MOBILE_APP',      'Mobile App Check-In',          3,  FALSE,  'Worker self-check-in via plantation mobile app'),
    ('QR_SCAN',         'QR Code Scan',                 3,  TRUE,   'Scan QR code at muster point via mobile camera'),
    ('SUPERVISOR',      'Supervisor Manual Entry',      2,  FALSE,  'Supervisor marks attendance on tablet or paper'),
    ('MUSTER_ROLL',     'Traditional Muster Roll',      1,  FALSE,  'Paper-based roll call at morning muster');

INSERT INTO lu_shift (shift_code, shift_name, start_time, end_time, break_minutes, work_hours, grace_minutes, half_day_hours) VALUES
    ('TAPPING_AM',      'Early Morning Tapping Shift',  '04:30',    '11:30',    30, 6.5,  15, 3.5),
    ('FIELD_DAY',       'Daytime Field Work Shift',     '07:00',    '16:00',    60, 8.0,  15, 4.0),
    ('FACTORY_DAY',     'Factory Day Shift',            '06:00',    '14:00',    30, 7.5,  10, 4.0),
    ('FACTORY_NIGHT',   'Factory Night Shift',          '22:00',    '06:00',    30, 7.5,  10, 4.0),
    ('OFFICE',          'Office / Admin Shift',         '08:00',    '17:00',    60, 8.0,  15, 4.0),
    ('NURSERY',         'Nursery Work Shift',           '06:30',    '14:30',    30, 7.5,  15, 4.0),
    ('SPLIT',           'Split Shift (Tapping + PM)',   '04:30',    '16:00',    180,8.0,  15, 4.0);

INSERT INTO lu_overtime_type (overtime_code, overtime_name, multiplier, max_hours_per_day) VALUES
    ('OT_NORMAL',       'Normal Overtime',          1.5,    4.0),
    ('OT_HOLIDAY',      'Holiday Overtime',         2.0,    8.0),
    ('OT_NIGHT',        'Night Shift Overtime',     2.0,    4.0),
    ('OT_EMERGENCY',    'Emergency Call-Out',       2.5,    NULL);

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
