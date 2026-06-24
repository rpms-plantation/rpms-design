-- ============================================================================
-- V2_003 — Module 2 (Tree Records & Tracking) — CREATE VIEW statements
-- Source: database/module-2-tree-records/tree_records_tracking_ddl.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tree Full Profile View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tree_profile AS
SELECT
    t.tree_id,
    t.tree_code,
    p.plantation_code,
    p.plantation_name,
    f.field_code,
    f.field_name,
    tr.row_number,
    t.tree_sequence,

    cm.clone_code,
    cm.clone_name,
    cm.clone_class,

    ts.status_name      AS current_status,
    ts.is_tappable,
    hr.rating_name      AS health_rating,
    hr.rating_score     AS health_score,

    t.planting_year,
    t.planting_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, COALESCE(t.planting_date, MAKE_DATE(t.planting_year, 1, 1))))::INT AS tree_age_years,

    t.current_girth_cm,
    t.current_bark_mm,
    t.bark_consumption_pct,

    t.current_panel,
    tps.tapping_system_name AS current_tapping_system,
    t.tapping_start_date,
    t.panels_exhausted,

    t.gps_latitude,
    t.gps_longitude,
    t.mortality_date,
    mc.cause_name       AS mortality_cause

FROM tree t
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN field f ON f.field_id = t.field_id
LEFT JOIN tree_row tr ON tr.row_id = t.row_id
JOIN clone_master cm ON cm.clone_id = t.clone_id
JOIN lu_tree_status ts ON ts.status_code = t.tree_status
LEFT JOIN lu_health_rating hr ON hr.rating_code = t.health_rating
LEFT JOIN lu_tapping_system tps ON tps.tapping_system_code = t.current_tapping_system
LEFT JOIN lu_mortality_cause mc ON mc.cause_code = t.mortality_cause_code;

-- ----------------------------------------------------------------------------
-- Field Tree Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_field_tree_summary AS
SELECT
    f.field_id,
    p.plantation_code,
    f.field_code,
    f.field_name,
    cm.clone_code,
    f.area_ha,

    COUNT(t.tree_id)                                                            AS total_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status NOT IN ('DEAD', 'REMOVED'))    AS live_trees,
    COUNT(t.tree_id) FILTER (WHERE ts.is_tappable = TRUE)                       AS tappable_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status = 'TAPPING')                   AS trees_tapping,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status = 'DISEASED')                  AS diseased_trees,
    COUNT(t.tree_id) FILTER (WHERE t.tree_status IN ('DEAD', 'REMOVED'))        AS dead_removed_trees,

    ROUND(AVG(t.current_girth_cm), 2)                                           AS avg_girth_cm,
    ROUND(AVG(t.bark_consumption_pct), 2)                                       AS avg_bark_consumption_pct,

    CASE WHEN f.area_ha > 0
         THEN ROUND(COUNT(t.tree_id) FILTER (WHERE t.tree_status NOT IN ('DEAD','REMOVED')) / f.area_ha, 0)
         ELSE NULL
    END AS live_stand_per_ha

FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
LEFT JOIN tree t ON t.field_id = f.field_id
LEFT JOIN lu_tree_status ts ON ts.status_code = t.tree_status
GROUP BY f.field_id, p.plantation_code, f.field_code, f.field_name, cm.clone_code, f.area_ha;

-- ----------------------------------------------------------------------------
-- Disease Hotspot View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_disease_hotspot AS
SELECT
    p.plantation_code,
    f.field_code,
    dm.disease_code,
    dm.disease_name,
    dm.disease_type,
    dm.severity_class      AS disease_severity_class,

    COUNT(di.incident_id)                                                   AS total_incidents,
    COUNT(di.incident_id) FILTER (WHERE di.status = 'ACTIVE')              AS active_incidents,
    COUNT(di.incident_id) FILTER (WHERE di.status = 'UNDER_TREATMENT')     AS under_treatment,
    COUNT(di.incident_id) FILTER (WHERE di.severity = 'SEVERE')            AS severe_count,
    COUNT(di.incident_id) FILTER (WHERE di.caused_tapping_stop = TRUE)     AS tapping_stopped_count,

    MIN(di.detected_date) AS earliest_detection,
    MAX(di.detected_date) AS latest_detection

FROM tree_disease_incident di
JOIN tree t ON t.tree_id = di.tree_id
JOIN field f ON f.field_id = t.field_id
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN disease_master dm ON dm.disease_id = di.disease_id
WHERE di.status IN ('ACTIVE', 'UNDER_TREATMENT')
GROUP BY p.plantation_code, f.field_code, dm.disease_code, dm.disease_name, dm.disease_type, dm.severity_class
ORDER BY active_incidents DESC;

-- ----------------------------------------------------------------------------
-- Mortality Analysis View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mortality_analysis AS
SELECT
    p.plantation_code,
    f.field_code,
    cm.clone_code,
    mc.cause_name,
    mc.cause_category,

    COUNT(mr.mortality_id)                  AS total_deaths,
    ROUND(AVG(mr.age_at_death_years), 1)   AS avg_age_at_death,
    ROUND(AVG(mr.girth_at_death_cm), 1)    AS avg_girth_at_death,
    SUM(mr.estimated_yield_loss_kg)         AS total_yield_loss_kg,

    COUNT(mr.mortality_id) FILTER (WHERE mr.replacement_planted = TRUE) AS trees_replaced,

    MIN(mr.mortality_date) AS earliest_death,
    MAX(mr.mortality_date) AS latest_death

FROM tree_mortality_record mr
JOIN tree t ON t.tree_id = mr.tree_id
JOIN field f ON f.field_id = t.field_id
JOIN plantation p ON p.plantation_id = t.plantation_id
JOIN clone_master cm ON cm.clone_id = t.clone_id
JOIN lu_mortality_cause mc ON mc.cause_code = mr.cause_code
GROUP BY p.plantation_code, f.field_code, cm.clone_code, mc.cause_name, mc.cause_category
ORDER BY total_deaths DESC;
