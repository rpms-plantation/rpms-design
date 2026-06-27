-- ============================================================================
-- V6_003 — Module 6 (Attendance Management) — CREATE VIEW statements
-- Source: database/module-6-attendance/attendance_management_ddl.sql
-- ============================================================================

-- 3.1 Daily Attendance Dashboard
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


-- 3.2 Absenteeism Pattern Analysis
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


-- 3.3 Overtime Summary View
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


-- 3.4 Payroll-Ready Monthly View
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
