-- ============================================================================
-- V6_002 — Module 6 (Attendance Management) — CREATE INDEX statements
-- Source: database/module-6-attendance/attendance_management_ddl.sql
-- ============================================================================

CREATE INDEX idx_att_loc_plantation ON attendance_location(plantation_id);
CREATE INDEX idx_att_loc_geofence ON attendance_location USING GIST(geofence_center);
CREATE INDEX idx_att_loc_polygon ON attendance_location USING GIST(geofence_polygon);

CREATE INDEX idx_att_worker ON daily_attendance(worker_id);
CREATE INDEX idx_att_plantation ON daily_attendance(plantation_id);
CREATE INDEX idx_att_date ON daily_attendance(attendance_date);
CREATE INDEX idx_att_status ON daily_attendance(attendance_status);
CREATE INDEX idx_att_shift ON daily_attendance(shift_code);
CREATE INDEX idx_att_worker_date ON daily_attendance(worker_id, attendance_date);
CREATE INDEX idx_att_date_status ON daily_attendance(attendance_date, attendance_status);
CREATE INDEX idx_att_checkin_gps ON daily_attendance USING GIST(check_in_gps_point);
CREATE INDEX idx_att_checkout_gps ON daily_attendance USING GIST(check_out_gps_point);
CREATE INDEX idx_att_late ON daily_attendance(is_late) WHERE is_late = TRUE;
CREATE INDEX idx_att_overtime ON daily_attendance(has_overtime) WHERE has_overtime = TRUE;
CREATE INDEX idx_att_anomaly ON daily_attendance(ai_anomaly_flag) WHERE ai_anomaly_flag = TRUE;
CREATE INDEX idx_att_leave ON daily_attendance(leave_id) WHERE leave_id IS NOT NULL;
CREATE INDEX idx_att_regularized ON daily_attendance(is_regularized) WHERE is_regularized = TRUE;

CREATE INDEX idx_scan_worker ON attendance_scan_log(worker_id);
CREATE INDEX idx_scan_timestamp ON attendance_scan_log(scan_timestamp);
CREATE INDEX idx_scan_worker_date ON attendance_scan_log(worker_id, scan_timestamp);
CREATE INDEX idx_scan_type ON attendance_scan_log(scan_type);
CREATE INDEX idx_scan_method ON attendance_scan_log(method_code);
CREATE INDEX idx_scan_location ON attendance_scan_log(location_id);
CREATE INDEX idx_scan_gps ON attendance_scan_log USING GIST(gps_point);
CREATE INDEX idx_scan_verified ON attendance_scan_log(is_verified) WHERE is_verified = FALSE;

CREATE INDEX idx_reg_attendance ON attendance_regularization(attendance_id);
CREATE INDEX idx_reg_status ON attendance_regularization(approval_status);
CREATE INDEX idx_reg_requested_by ON attendance_regularization(requested_by);

CREATE INDEX idx_roster_worker ON worker_shift_roster(worker_id);
CREATE INDEX idx_roster_date ON worker_shift_roster(roster_date);
CREATE INDEX idx_roster_plantation ON worker_shift_roster(plantation_id);
CREATE INDEX idx_roster_shift ON worker_shift_roster(shift_code);

CREATE INDEX idx_mas_worker ON monthly_attendance_summary(worker_id);
CREATE INDEX idx_mas_period ON monthly_attendance_summary(summary_year, summary_month);
CREATE INDEX idx_mas_plantation ON monthly_attendance_summary(plantation_id);

CREATE INDEX idx_pda_plantation ON plantation_daily_attendance(plantation_id);
CREATE INDEX idx_pda_date ON plantation_daily_attendance(snapshot_date);
