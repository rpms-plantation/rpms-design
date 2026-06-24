-- ============================================================================
-- V1_003 — Module 1 (Plantation Field Records) — CREATE VIEW statements
-- Source: database/module-1-field-records/plantation_field_records_ddl.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Plantation Area Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_plantation_area_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    p.plantation_name,
    p.total_surface_area,
    p.measurement_unit,

    -- Planted area from fields
    COALESCE(SUM(CASE WHEN f.field_category = 'MATURE' THEN f.area_ha END), 0) AS mature_area,
    COALESCE(SUM(CASE WHEN f.field_category IN ('NEW_CLEARING', 'REPLANTING') THEN f.area_ha END), 0) AS immature_area,
    COALESCE(SUM(f.area_ha), 0) AS total_field_area,

    -- Nursery area
    COALESCE(n.total_nursery_area, 0) AS total_nursery_area,

    -- Non-planted areas
    COALESCE(lu.building_area, 0)       AS building_infra_area,
    COALESCE(lu.road_area, 0)           AS road_area,
    COALESCE(lu.swap_area, 0)           AS swap_area,
    COALESCE(lu.rocky_area, 0)          AS rocky_area,
    COALESCE(lu.uncultivated_area, 0)   AS uncultivated_area,
    COALESCE(lu.hvc_area, 0)            AS hvc_conservation_area,
    COALESCE(lu.water_area, 0)          AS water_bodies_area,
    COALESCE(lu.misc_area, 0)           AS miscellaneous_area

FROM plantation p

LEFT JOIN field f ON f.plantation_id = p.plantation_id AND f.status = 'ACTIVE'

LEFT JOIN (
    SELECT plantation_id, COALESCE(SUM(area_ha), 0) AS total_nursery_area
    FROM nursery WHERE status = 'ACTIVE'
    GROUP BY plantation_id
) n ON n.plantation_id = p.plantation_id

LEFT JOIN (
    SELECT
        plantation_id,
        SUM(CASE WHEN land_use_code = 'BUILDING'       THEN area_value END) AS building_area,
        SUM(CASE WHEN land_use_code = 'ROAD'            THEN area_value END) AS road_area,
        SUM(CASE WHEN land_use_code = 'SWAP'            THEN area_value END) AS swap_area,
        SUM(CASE WHEN land_use_code = 'ROCKY'           THEN area_value END) AS rocky_area,
        SUM(CASE WHEN land_use_code = 'UNCULTIVATED'    THEN area_value END) AS uncultivated_area,
        SUM(CASE WHEN land_use_code = 'HVC'             THEN area_value END) AS hvc_area,
        SUM(CASE WHEN land_use_code = 'WATER'           THEN area_value END) AS water_area,
        SUM(CASE WHEN land_use_code = 'MISC'            THEN area_value END) AS misc_area
    FROM plantation_land_use
    GROUP BY plantation_id
) lu ON lu.plantation_id = p.plantation_id

GROUP BY p.plantation_id, p.plantation_code, p.plantation_name,
         p.total_surface_area, p.measurement_unit,
         n.total_nursery_area,
         lu.building_area, lu.road_area, lu.swap_area, lu.rocky_area,
         lu.uncultivated_area, lu.hvc_area, lu.water_area, lu.misc_area;

-- ----------------------------------------------------------------------------
-- Clone-wise Distribution Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_clone_distribution_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    p.plantation_name,
    cm.clone_code,
    cm.clone_name,
    cm.clone_class,
    f.field_category,
    COUNT(f.field_id)               AS number_of_fields,
    SUM(f.area_ha)                  AS total_area_ha,
    SUM(f.number_of_plants)         AS total_plants,
    MIN(f.planting_year)            AS earliest_planting_year,
    MAX(f.planting_year)            AS latest_planting_year
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
WHERE f.status = 'ACTIVE'
GROUP BY p.plantation_id, p.plantation_code, p.plantation_name,
         cm.clone_code, cm.clone_name, cm.clone_class, f.field_category
ORDER BY p.plantation_code, cm.clone_code, f.field_category;

-- ----------------------------------------------------------------------------
-- Nursery Clone Summary View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_nursery_clone_summary AS
SELECT
    p.plantation_id,
    p.plantation_code,
    n.nursery_id,
    n.nursery_code,
    n.nursery_name,
    nt.nursery_type_name,
    cm.clone_code,
    cm.clone_name,
    ncd.number_of_plants,
    ncd.survival_rate_pct,
    ncd.record_date
FROM nursery_clone_distribution ncd
JOIN nursery n ON n.nursery_id = ncd.nursery_id
JOIN lu_nursery_type nt ON nt.nursery_type_code = n.nursery_type_code
JOIN plantation p ON p.plantation_id = n.plantation_id
JOIN clone_master cm ON cm.clone_id = ncd.clone_id
WHERE n.status = 'ACTIVE'
ORDER BY p.plantation_code, n.nursery_code, cm.clone_code;

-- ----------------------------------------------------------------------------
-- Immature Fields Detail View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_immature_fields AS
SELECT
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    f.field_code,
    f.field_name,
    fc.category_name       AS field_type,
    cm.clone_code,
    cm.clone_name,
    f.area_ha,
    f.number_of_plants,
    f.planting_month,
    f.planting_year,
    -- Calculated age in years
    EXTRACT(YEAR FROM AGE(
        CURRENT_DATE,
        MAKE_DATE(f.planting_year, COALESCE(f.planting_month, 1), 1)
    )) AS age_years
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
JOIN lu_field_category fc ON fc.category_code = f.field_category
LEFT JOIN division d ON d.division_id = f.division_id
WHERE f.field_category IN ('NEW_CLEARING', 'REPLANTING')
  AND f.status = 'ACTIVE'
ORDER BY p.plantation_code, f.planting_year, f.field_code;

-- ----------------------------------------------------------------------------
-- Mature Fields Detail View
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mature_fields AS
SELECT
    p.plantation_code,
    p.plantation_name,
    d.division_code,
    f.field_code,
    f.field_name,
    cm.clone_code,
    cm.clone_name,
    f.area_ha,
    f.number_of_plants,
    f.current_stand_per_ha,
    f.planting_month,
    f.planting_year,
    f.tapping_start_month,
    f.tapping_start_year,
    ts.tapping_system_name,
    ts.frequency_notation,
    f.current_tapping_panel,
    -- Calculated tapping age
    EXTRACT(YEAR FROM AGE(
        CURRENT_DATE,
        MAKE_DATE(f.tapping_start_year, COALESCE(f.tapping_start_month, 1), 1)
    )) AS tapping_age_years
FROM field f
JOIN plantation p ON p.plantation_id = f.plantation_id
JOIN clone_master cm ON cm.clone_id = f.clone_id
LEFT JOIN division d ON d.division_id = f.division_id
LEFT JOIN lu_tapping_system ts ON ts.tapping_system_code = f.tapping_system_code
WHERE f.field_category = 'MATURE'
  AND f.status = 'ACTIVE'
ORDER BY p.plantation_code, f.tapping_start_year, f.field_code;
