-- ============================================================================
-- V5_003 — Module 5 (Daily Activity Monitoring) — CREATE VIEW statements
-- Source: database/module-5-daily-activity/daily_activity_monitoring_ddl.sql
-- Prerequisite: V4 (Module 4 — worker, gang, lu_worker_category) must have
-- already run (vw_worker_daily_productivity joins lu_worker_category).
-- ============================================================================

-- 3.1 Daily Activity Dashboard
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


-- 3.2 Category-wise Activity Analysis
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


-- 3.3 Material Consumption Report
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


-- 3.4 Worker Productivity View
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
