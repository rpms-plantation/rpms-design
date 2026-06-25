-- ============================================================================
-- V4_003 — Module 4 (Workforce Management) — CREATE VIEW statements
-- Source: database/module-4-workforce/workforce_management_ddl.sql
-- ============================================================================

-- 14.1 Worker Full Profile
CREATE OR REPLACE VIEW vw_worker_profile AS
SELECT
    w.worker_id,
    w.employee_code,
    w.full_name,
    w.gender,
    w.date_of_birth,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, w.date_of_birth))::INT AS age,
    w.nationality,
    w.mobile_phone,

    p.plantation_code,
    p.plantation_name,
    d.division_code,

    wc.category_name    AS role,
    wc.category_group   AS role_group,
    et.employment_type_name,
    ws.status_name      AS current_status,
    ws.is_active_duty,

    w.hire_date,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, w.hire_date))::INT AS years_of_service,

    f.field_code        AS primary_field,
    g.gang_code,
    g.gang_name,

    mgr.full_name       AS reports_to,

    w.base_pay_amount,
    w.pay_currency,
    w.pay_frequency,
    w.biometric_id      IS NOT NULL AS has_biometric,
    w.nfc_badge_uid     IS NOT NULL AS has_nfc_badge

FROM worker w
JOIN plantation p ON p.plantation_id = w.plantation_id
LEFT JOIN division d ON d.division_id = w.division_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
JOIN lu_employment_type et ON et.employment_type_code = w.employment_type_code
JOIN lu_worker_status ws ON ws.status_code = w.worker_status
LEFT JOIN field f ON f.field_id = w.primary_field_id
LEFT JOIN gang g ON g.gang_id = w.assigned_gang_id
LEFT JOIN worker mgr ON mgr.worker_id = w.reports_to_id;


-- 14.2 Gang Roster
CREATE OR REPLACE VIEW vw_gang_roster AS
SELECT
    g.gang_id,
    g.gang_code,
    g.gang_name,
    p.plantation_code,
    d.division_code,
    f.field_code        AS primary_field,
    ldr.full_name       AS gang_leader,
    g.target_size,
    g.current_size,

    COUNT(w.worker_id)                                          AS actual_members,
    COUNT(w.worker_id) FILTER (WHERE ws.is_active_duty = TRUE)  AS active_members,

    STRING_AGG(DISTINCT wc.category_name, ', ')                 AS roles_in_gang

FROM gang g
JOIN plantation p ON p.plantation_id = g.plantation_id
LEFT JOIN division d ON d.division_id = g.division_id
LEFT JOIN field f ON f.field_id = g.primary_field_id
LEFT JOIN worker ldr ON ldr.worker_id = g.leader_worker_id
LEFT JOIN worker w ON w.assigned_gang_id = g.gang_id
LEFT JOIN lu_worker_status ws ON ws.status_code = w.worker_status
LEFT JOIN lu_worker_category wc ON wc.category_code = w.category_code
WHERE g.status = 'ACTIVE'
GROUP BY g.gang_id, g.gang_code, g.gang_name, p.plantation_code,
         d.division_code, f.field_code, ldr.full_name, g.target_size, g.current_size;


-- 14.3 Expiring Documents Alert
CREATE OR REPLACE VIEW vw_expiring_documents AS
SELECT
    w.employee_code,
    w.full_name,
    p.plantation_code,
    dt.doc_type_name,
    wd.document_number,
    wd.expiry_date,
    (wd.expiry_date - CURRENT_DATE) AS days_until_expiry,
    CASE
        WHEN wd.expiry_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN wd.expiry_date <= CURRENT_DATE + 30 THEN 'EXPIRING_SOON'
        WHEN wd.expiry_date <= CURRENT_DATE + 90 THEN 'DUE_FOR_RENEWAL'
        ELSE 'OK'
    END AS alert_level
FROM worker_document wd
JOIN worker w ON w.worker_id = wd.worker_id
JOIN plantation p ON p.plantation_id = w.plantation_id
JOIN lu_document_type dt ON dt.doc_type_code = wd.doc_type_code
WHERE wd.status = 'ACTIVE'
  AND wd.expiry_date IS NOT NULL
  AND wd.expiry_date <= CURRENT_DATE + 90
ORDER BY wd.expiry_date ASC;


-- 14.4 Skill Gap Analysis
CREATE OR REPLACE VIEW vw_skill_gap_analysis AS
SELECT
    p.plantation_code,
    wc.category_name    AS role,
    ls.skill_name,
    ls.skill_category,

    COUNT(DISTINCT w.worker_id)                                         AS total_workers_in_role,
    COUNT(DISTINCT wsk.worker_id)                                       AS workers_with_skill,
    COUNT(DISTINCT w.worker_id) - COUNT(DISTINCT wsk.worker_id)         AS skill_gap,

    ROUND(AVG(pl.level_score) FILTER (WHERE pl.level_score IS NOT NULL), 1) AS avg_proficiency,

    COUNT(DISTINCT wsk.worker_id) FILTER (WHERE wsk.is_certified = TRUE) AS certified_count,
    COUNT(DISTINCT wsk.worker_id) FILTER (WHERE wsk.certification_expiry < CURRENT_DATE) AS expired_certs

FROM worker w
JOIN plantation p ON p.plantation_id = w.plantation_id
JOIN lu_worker_category wc ON wc.category_code = w.category_code
CROSS JOIN lu_skill ls
LEFT JOIN worker_skill wsk ON wsk.worker_id = w.worker_id AND wsk.skill_code = ls.skill_code
LEFT JOIN lu_proficiency_level pl ON pl.level_code = wsk.proficiency_level
WHERE w.worker_status IN ('ACTIVE', 'PROBATION', 'TRAINING')
  AND ls.skill_category = wc.category_group
GROUP BY p.plantation_code, wc.category_name, ls.skill_name, ls.skill_category
HAVING COUNT(DISTINCT w.worker_id) - COUNT(DISTINCT wsk.worker_id) > 0
ORDER BY skill_gap DESC;