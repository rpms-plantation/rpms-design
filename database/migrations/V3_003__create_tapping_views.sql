-- ============================================================================
-- V3_003 — Module 3 (Tapping Task Monitoring) — CREATE VIEW statements
-- Source: database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
-- ============================================================================

-- 13.1 Daily Tapping Dashboard View
CREATE OR REPLACE VIEW vw_tapping_dashboard_daily AS
SELECT
    t.task_date,
    p.plantation_code,
    p.plantation_name,
    f.field_code,
    f.field_name,
    cm.clone_code,

    ts.status_name          AS task_status,
    t.tapper_name,

    t.trees_tapped,
    t.trees_skipped,
    t.total_yield_kg,
    t.yield_per_tree_g,
    t.avg_drc_pct,

    t.tapping_quality_score,
    t.weather_condition,
    t.weather_rainfall_mm,

    t.geofence_verified,
    t.supervisor_verified,

    t.actual_start_time,
    t.actual_end_time,
    EXTRACT(EPOCH FROM (t.actual_end_time - t.actual_start_time))/60 AS duration_minutes,

    sr.reason_name          AS skip_reason

FROM tapping_task t
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN field f ON f.field_id = t.field_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
JOIN lu_tapping_task_status ts ON ts.status_code = t.status
LEFT JOIN lu_tapping_skip_reason sr ON sr.reason_code = t.skip_reason_code
ORDER BY t.task_date DESC, p.plantation_code, f.field_code;


-- 13.2 Tapper Performance Ranking View
CREATE OR REPLACE VIEW vw_tapper_performance_ranking AS
SELECT
    tp.tapper_id,
    tp.tapper_name,
    p.plantation_code,

    COUNT(tp.performance_id)                    AS total_days_worked,
    SUM(tp.total_trees_tapped)                  AS total_trees_tapped,
    ROUND(AVG(tp.total_trees_tapped), 0)        AS avg_trees_per_day,

    ROUND(SUM(tp.total_yield_kg), 2)            AS total_yield_kg,
    ROUND(AVG(tp.avg_yield_per_tree_g), 2)      AS avg_yield_per_tree_g,

    ROUND(AVG(tp.avg_tapping_quality_score), 1)  AS avg_quality_score,
    ROUND(AVG(tp.avg_cut_angle_deviation), 1)    AS avg_angle_deviation,
    ROUND(AVG(tp.avg_trees_per_hour), 1)         AS avg_trees_per_hour,

    COUNT(*) FILTER (WHERE tp.reported_on_time = TRUE) AS on_time_days,
    ROUND(COUNT(*) FILTER (WHERE tp.reported_on_time = TRUE) * 100.0 /
          NULLIF(COUNT(*), 0), 1) AS on_time_pct

FROM tapper_performance_daily tp
JOIN plantation p ON p.plantation_id = tp.plantation_id
GROUP BY tp.tapper_id, tp.tapper_name, p.plantation_code
ORDER BY total_yield_kg DESC;


-- 13.3 Clone-wise Yield Analysis View
CREATE OR REPLACE VIEW vw_clone_yield_analysis AS
SELECT
    fy.clone_code,
    p.plantation_code,
    fy.tree_age_years,

    COUNT(DISTINCT fy.field_id)                 AS fields_tapped,
    COUNT(fy.yield_id)                          AS tapping_days,

    ROUND(AVG(fy.total_wet_yield_kg), 2)        AS avg_daily_wet_yield_kg,
    ROUND(AVG(fy.total_dry_rubber_kg), 2)       AS avg_daily_dry_rubber_kg,
    ROUND(AVG(fy.yield_per_tree_g), 2)          AS avg_yield_per_tree_g,
    ROUND(AVG(fy.yield_per_ha_kg), 2)           AS avg_yield_per_ha_kg,
    ROUND(AVG(fy.avg_drc_pct), 2)               AS avg_drc_pct,

    ROUND(AVG(fy.rainfall_mm), 1)               AS avg_rainfall_mm,

    ROUND(CORR(fy.rainfall_mm, fy.total_wet_yield_kg)::NUMERIC, 3)
                                                 AS rainfall_yield_correlation

FROM field_yield_daily fy
JOIN plantation p ON p.plantation_id = fy.plantation_id
WHERE fy.clone_code IS NOT NULL
GROUP BY fy.clone_code, p.plantation_code, fy.tree_age_years
ORDER BY avg_yield_per_tree_g DESC;


-- 13.4 Weather Impact on Yield View
CREATE OR REPLACE VIEW vw_weather_yield_correlation AS
SELECT
    wo.observation_date,
    p.plantation_code,
    f.field_code,

    wo.rainfall_mm,
    wo.temperature_max_c,
    wo.humidity_max_pct,
    wo.weather_condition,
    wo.suitable_for_tapping,

    fy.total_tappers,
    fy.total_trees_tapped,
    fy.total_wet_yield_kg,
    fy.total_dry_rubber_kg,
    fy.yield_per_tree_g,

    CASE
        WHEN wo.rainfall_mm > 10 THEN 'Heavy Rain'
        WHEN wo.rainfall_mm > 5  THEN 'Moderate Rain'
        WHEN wo.rainfall_mm > 0  THEN 'Light Rain'
        ELSE 'Dry'
    END AS rain_category

FROM weather_observation wo
JOIN plantation p ON p.plantation_id = wo.plantation_id
LEFT JOIN field f ON f.field_id = wo.field_id
LEFT JOIN field_yield_daily fy
    ON fy.field_id = wo.field_id AND fy.yield_date = wo.observation_date
ORDER BY wo.observation_date DESC;
