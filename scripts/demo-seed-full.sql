-- ============================================================================
-- RPMS COMPREHENSIVE DEMO SEED — Sungai Pinang Estate
-- Covers ALL 6 modules at ALL table levels.
-- Run on a fresh (schema-only) database, or after clearing demo data.
--
-- Usage:
--   psql -U rpms -d rpms -f demo-seed-full.sql
--
-- To clear existing demo data first:
--   psql -U rpms -d rpms -c "SELECT rpms_clear_demo_data();" (if function exists)
--   OR truncate manually in reverse FK order (see bottom of this file).
-- ============================================================================

DO $$
DECLARE
  -- ── IDs captured via RETURNING ──────────────────────────────────────────
  -- M1
  v_pid   INT;          -- plantation_id
  v_d1    INT;          -- division A
  v_d2    INT;          -- division B
  v_c1    INT;          -- clone RRIM600
  v_c2    INT;          -- clone PB260
  v_c3    INT;          -- clone RRIC121
  v_f1    INT;          -- field A1 (mature, RRIM600)
  v_f2    INT;          -- field A2 (mature, PB260)
  v_f3    INT;          -- field B1 (new clearing, RRIC121)
  v_f4    INT;          -- field B2 (replanting, RRIM600)

  -- M4 Workers
  v_w1    INT;          -- Razif Osman — Estate Manager
  v_w2    INT;          -- Hairul Aziz — Asst Manager
  v_w3    INT;          -- Siti Rohani — Conductor Div A
  v_w4    INT;          -- Mohd Fadzil — Conductor Div B
  v_w5    INT;          -- Aminah Hassan — Senior Tapper
  v_w6    INT;          -- Rajan Muthu — Tapper
  v_w7    INT;          -- Selvam Krishnan — Tapper
  v_w8    INT;          -- Balakrishnan Nair — Senior Tapper
  v_w9    INT;          -- Karthik Subramaniam — Tapper
  v_w10   INT;          -- Noor Azlina — Field Collector

  -- M4 Gangs
  v_g1    INT;          -- Gang Alpha (Div A)
  v_g2    INT;          -- Gang Beta (Div B)

  -- M4 Leave
  v_leave1 INT;         -- Aminah's approved annual leave

  -- M2 Tree Rows & Trees
  v_r1    INT; v_r2 INT; v_r3 INT; v_r4 INT;
  v_tree1 BIGINT; v_tree2 BIGINT; v_tree3 BIGINT;
  v_tree4 BIGINT; v_tree5 BIGINT; v_tree6 BIGINT;
  v_tree7 BIGINT; v_tree8 BIGINT; v_tree9 BIGINT;
  v_tree10 BIGINT; v_tree11 BIGINT; v_tree12 BIGINT;
  v_tree13 BIGINT; v_tree14 BIGINT; v_tree15 BIGINT;

  -- M3 Tapping
  v_cp1   INT; v_cp2 INT; v_cp3 INT;  -- collection points
  v_s1    INT; v_s2 INT;              -- schedules
  v_t1    BIGINT; v_t2 BIGINT; v_t3 BIGINT;
  v_t4    BIGINT; v_t5 BIGINT; v_t6 BIGINT;
  v_col1  BIGINT; v_col2 BIGINT; v_col3 BIGINT; -- collection records
  v_iot1  INT; v_iot2 INT;           -- IoT devices

  -- M5 Activity
  v_pl1   INT; v_pl2 INT; v_pl3 INT; -- work plans
  v_a1    BIGINT; v_a2 BIGINT; v_a3 BIGINT;
  v_a4    BIGINT; v_a5 BIGINT;       -- activities
  v_insp1 INT; v_insp2 INT;          -- inspections
  v_m_npk INT; v_m_gly INT; v_m_eth INT; -- material IDs

  -- M6 Attendance
  v_al1   INT; v_al2 INT; v_al3 INT; -- attendance locations
  v_att1  BIGINT;                     -- one attendance ID for regularization

BEGIN

-- ============================================================================
-- CLEAR EXISTING DEMO DATA (reverse FK order)
-- ============================================================================
DELETE FROM monthly_attendance_summary;
DELETE FROM attendance_regularization;
DELETE FROM attendance_scan_log;
DELETE FROM daily_attendance;
DELETE FROM worker_shift_roster;
DELETE FROM attendance_location;
DELETE FROM inspection_checklist_response;
DELETE FROM supervisor_inspection;
DELETE FROM activity_material_usage;
DELETE FROM activity_worker_assignment;
DELETE FROM daily_activity;
DELETE FROM daily_work_plan;
DELETE FROM tapping_task_tree_detail;
DELETE FROM latex_quality_test;
DELETE FROM latex_collection_record;
DELETE FROM tapping_task;
DELETE FROM tapping_schedule;
DELETE FROM collection_point;
DELETE FROM iot_device;
DELETE FROM weather_observation;
DELETE FROM tree_treatment_record;
DELETE FROM tree_disease_incident;
DELETE FROM tree_health_inspection;
DELETE FROM tree_census_summary;
DELETE FROM tree_panel_history;
DELETE FROM tree_growth_measurement;
DELETE FROM tree_tag;
DELETE FROM tree_status_change_log;
DELETE FROM tree_mortality_record;
DELETE FROM tree;
DELETE FROM tree_row;
DELETE FROM worker_status_change_log;
DELETE FROM worker_safety_incident;
DELETE FROM worker_pay_structure;
DELETE FROM worker_training;
DELETE FROM worker_leave_balance;
DELETE FROM worker_leave;
DELETE FROM worker_field_assignment;
DELETE FROM worker_document;
DELETE FROM worker_next_of_kin;
DELETE FROM worker_skill;
UPDATE worker SET assigned_gang_id = NULL;
DELETE FROM gang;
DELETE FROM worker;
DELETE FROM field;
DELETE FROM division;
DELETE FROM plantation;
DELETE FROM clone_master;

RAISE NOTICE 'Existing demo data cleared.';

-- ============================================================================
-- M1 — CLONE MASTER
-- ============================================================================
INSERT INTO clone_master (clone_code, clone_name, clone_class, origin_country,
  avg_yield_kg_per_ha, wind_resistance)
VALUES ('RRIM600','RRIM 600','I','Malaysia',1800.00,'MEDIUM')
RETURNING clone_id INTO v_c1;

INSERT INTO clone_master (clone_code, clone_name, clone_class, origin_country,
  avg_yield_kg_per_ha, wind_resistance)
VALUES ('PB260','PB 260','I','Malaysia',2100.00,'LOW')
RETURNING clone_id INTO v_c2;

INSERT INTO clone_master (clone_code, clone_name, clone_class, origin_country,
  avg_yield_kg_per_ha, wind_resistance)
VALUES ('RRIC121','RRIC 121','II','Sri Lanka',1650.00,'HIGH')
RETURNING clone_id INTO v_c3;

-- ============================================================================
-- M1 — PLANTATION
-- ============================================================================
INSERT INTO plantation (plantation_code, plantation_name, region, district,
  state_province, country, elevation_m, avg_annual_rainfall_mm, soil_type,
  total_surface_area, measurement_unit, gps_latitude, gps_longitude,
  establishment_date, ownership_type, owner_name, manager_name, status, created_by)
VALUES ('SPE-001','Sungai Pinang Estate','Northern Region','Kuala Kangsar',
  'Perak','Malaysia',85.0,2400.0,'Reddish-Brown Laterite',523.45,'HA',
  4.7621,101.1132,'1985-03-15','PRIVATE','Sungai Pinang Holdings Bhd',
  'Encik Razif bin Osman','ACTIVE','system')
RETURNING plantation_id INTO v_pid;

-- ============================================================================
-- M1 — DIVISIONS
-- ============================================================================
INSERT INTO division (plantation_id,division_code,division_name,area_ha,
  manager_name,is_active)
VALUES (v_pid,'DIV-A','Division A — North Block',261.20,'Encik Hairul bin Aziz',TRUE)
RETURNING division_id INTO v_d1;

INSERT INTO division (plantation_id,division_code,division_name,area_ha,
  manager_name,is_active)
VALUES (v_pid,'DIV-B','Division B — South Block',220.80,'Puan Siti Rohani bt Hamid',TRUE)
RETURNING division_id INTO v_d2;

-- ============================================================================
-- M1 — FIELDS
-- ============================================================================
INSERT INTO field (plantation_id,division_id,field_code,field_name,area_ha,
  measurement_unit,clone_id,number_of_plants,original_stand_per_ha,
  current_stand_per_ha,planting_month,planting_year,field_category,
  tapping_start_month,tapping_start_year,tapping_system_code,current_tapping_panel,
  gps_latitude,gps_longitude,status,created_by)
VALUES (v_pid,v_d1,'A1','Block A1 — RRIM 600 Mature',65.30,'HA',v_c1,
  20832,320,308,3,2005,'MATURE',3,2012,'S2D2','BI-1',4.7701,101.1080,'ACTIVE','system')
RETURNING field_id INTO v_f1;

INSERT INTO field (plantation_id,division_id,field_code,field_name,area_ha,
  measurement_unit,clone_id,number_of_plants,original_stand_per_ha,
  current_stand_per_ha,planting_month,planting_year,field_category,
  tapping_start_month,tapping_start_year,tapping_system_code,current_tapping_panel,
  gps_latitude,gps_longitude,status,created_by)
VALUES (v_pid,v_d1,'A2','Block A2 — PB 260 Mature',58.70,'HA',v_c2,
  18784,320,312,6,2007,'MATURE',6,2014,'S2D3','BI-1',4.7730,101.1110,'ACTIVE','system')
RETURNING field_id INTO v_f2;

INSERT INTO field (plantation_id,division_id,field_code,field_name,area_ha,
  measurement_unit,clone_id,number_of_plants,original_stand_per_ha,
  current_stand_per_ha,planting_month,planting_year,field_category,
  gps_latitude,gps_longitude,status,created_by)
VALUES (v_pid,v_d2,'B1','Block B1 — RRIC 121 New Clearing',48.50,'HA',v_c3,
  15520,320,315,9,2021,'NEW_CLEARING',4.7580,101.1200,'ACTIVE','system')
RETURNING field_id INTO v_f3;

INSERT INTO field (plantation_id,division_id,field_code,field_name,area_ha,
  measurement_unit,clone_id,number_of_plants,original_stand_per_ha,
  current_stand_per_ha,planting_month,planting_year,field_category,
  gps_latitude,gps_longitude,status,created_by)
VALUES (v_pid,v_d2,'B2','Block B2 — RRIM 600 Replanting',42.10,'HA',v_c1,
  13472,320,318,2,2019,'REPLANTING',4.7550,101.1230,'ACTIVE','system')
RETURNING field_id INTO v_f4;

-- ============================================================================
-- M4 — WORKERS
-- ============================================================================
INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-001','Razif','Osman','1972-04-10','MALE','A123456789','Malaysian',
  'MARRIED','B+','012-3456789','Lot 1 Jalan Pinang, Kuala Kangsar',
  v_pid,NULL,'MANAGER','PERMANENT','ACTIVE','2000-01-10',NULL,'2000-07-10',NULL,
  8500.00,'MYR','MONTHLY','BIO-001','NFC-001','system')
RETURNING worker_id INTO v_w1;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-002','Hairul','Aziz','1980-08-22','MALE','B234567890','Malaysian',
  'MARRIED','O+','013-2345678','No 5 Taman Sejahtera, Kuala Kangsar',
  v_pid,v_d1,'ASST_MANAGER','PERMANENT','ACTIVE','2005-03-01','2005-09-01','2005-09-01',NULL,
  6200.00,'MYR','MONTHLY','BIO-002','NFC-002','system')
RETURNING worker_id INTO v_w2;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-003','Siti','Rohani','1985-11-05','FEMALE','C345678901','Malaysian',
  'MARRIED','A+','011-3456789','Lot 12 Kampung Pinang, Perak',
  v_pid,v_d1,'CONDUCTOR','PERMANENT','ACTIVE','2008-06-15','2008-12-15','2008-12-15',v_f1,
  4800.00,'MYR','MONTHLY','BIO-003','NFC-003','system')
RETURNING worker_id INTO v_w3;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-004','Mohd','Fadzil','1987-02-28','MALE','D456789012','Malaysian',
  'MARRIED','B-','012-4567890','No 8 Jalan Meranti, Kuala Kangsar',
  v_pid,v_d2,'CONDUCTOR','PERMANENT','ACTIVE','2010-01-10','2010-07-10','2010-07-10',v_f3,
  4800.00,'MYR','MONTHLY','BIO-004','NFC-004','system')
RETURNING worker_id INTO v_w4;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-005','Aminah','Hassan','1983-07-14','FEMALE','E567890123','Malaysian',
  'MARRIED','O-','012-5678901','Lot 22 Kampung Pinang, Perak',
  v_pid,v_d1,'TAPPER_SENIOR','PERMANENT','ACTIVE','2006-04-01','2006-10-01','2006-10-01',v_f1,
  3200.00,'MYR','MONTHLY','BIO-005','NFC-005','system')
RETURNING worker_id INTO v_w5;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-006','Rajan','Muthu','1990-09-20','MALE','F678901234','Malaysian',
  'SINGLE','A-','017-6789012','Estate Line 3, Sungai Pinang',
  v_pid,v_d1,'TAPPER','PERMANENT','ACTIVE','2012-02-15','2012-08-15','2012-08-15',v_f1,
  2400.00,'MYR','MONTHLY','BIO-006','NFC-006','system')
RETURNING worker_id INTO v_w6;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-007','Selvam','Krishnan','1992-05-03','MALE','G789012345','Malaysian',
  'MARRIED','B+','016-7890123','Estate Line 3, Sungai Pinang',
  v_pid,v_d1,'TAPPER','PERMANENT','ACTIVE','2013-08-01','2014-02-01','2014-02-01',v_f2,
  2400.00,'MYR','MONTHLY','BIO-007','NFC-007','system')
RETURNING worker_id INTO v_w7;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-008','Balakrishnan','Nair','1979-12-11','MALE','H890123456','Malaysian',
  'MARRIED','AB+','014-8901234','Estate Line 5, Sungai Pinang',
  v_pid,v_d2,'TAPPER_SENIOR','PERMANENT','ACTIVE','2004-07-20','2005-01-20','2005-01-20',v_f3,
  3200.00,'MYR','MONTHLY','BIO-008','NFC-008','system')
RETURNING worker_id INTO v_w8;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-009','Karthik','Subramaniam','1995-03-29','MALE','I901234567','Malaysian',
  'SINGLE','O+','018-9012345','Estate Line 5, Sungai Pinang',
  v_pid,v_d2,'TAPPER','CONTRACT','ACTIVE','2018-11-01','2019-05-01','2019-05-01',v_f4,
  2100.00,'MYR','MONTHLY','BIO-009','NFC-009','system')
RETURNING worker_id INTO v_w9;

INSERT INTO worker (employee_code,first_name,last_name,date_of_birth,gender,
  national_id,nationality,marital_status,blood_group,mobile_phone,permanent_address,
  plantation_id,division_id,category_code,employment_type_code,worker_status,
  hire_date,probation_end_date,confirmation_date,primary_field_id,
  base_pay_amount,pay_currency,pay_frequency,biometric_id,nfc_badge_uid,created_by)
VALUES ('EMP-010','Noor','Azlina','1988-06-17','FEMALE','J012345678','Malaysian',
  'MARRIED','A+','011-0123456','Lot 7 Taman Muhibbah, Kuala Kangsar',
  v_pid,v_d1,'FIELD_COLLECTOR','PERMANENT','ACTIVE','2009-09-10','2010-03-10','2010-03-10',v_f1,
  2600.00,'MYR','MONTHLY','BIO-010','NFC-010','system')
RETURNING worker_id INTO v_w10;

-- Reporting hierarchy
UPDATE worker SET reports_to_id = v_w1 WHERE worker_id = v_w2;
UPDATE worker SET reports_to_id = v_w2 WHERE worker_id IN (v_w3, v_w4);
UPDATE worker SET reports_to_id = v_w3 WHERE worker_id IN (v_w5, v_w6, v_w7, v_w10);
UPDATE worker SET reports_to_id = v_w4 WHERE worker_id IN (v_w8, v_w9);

-- ============================================================================
-- M4 — GANGS
-- ============================================================================
INSERT INTO gang (plantation_id,division_id,gang_code,gang_name,
  leader_worker_id,primary_field_id,target_size,status)
VALUES (v_pid,v_d1,'GANG-A','Gang Alpha — Division A',v_w5,v_f1,5,'ACTIVE')
RETURNING gang_id INTO v_g1;

INSERT INTO gang (plantation_id,division_id,gang_code,gang_name,
  leader_worker_id,primary_field_id,target_size,status)
VALUES (v_pid,v_d2,'GANG-B','Gang Beta — Division B',v_w8,v_f3,4,'ACTIVE')
RETURNING gang_id INTO v_g2;

UPDATE worker SET assigned_gang_id = v_g1 WHERE worker_id IN (v_w5,v_w6,v_w7,v_w10);
UPDATE worker SET assigned_gang_id = v_g2 WHERE worker_id IN (v_w8,v_w9);

-- ============================================================================
-- M4 — WORKER SKILLS
-- ============================================================================
INSERT INTO worker_skill (worker_id,skill_code,proficiency_level,assessed_date,
  assessed_by,next_assessment_date,is_certified,certification_number,certification_expiry)
VALUES
  -- Razif (Manager): leadership, team lead
  (v_w1,'TEAM_LEAD','EXPERT','2023-01-15','HR Director','2025-01-15',TRUE,'CERT-MGR-001','2025-01-15'),
  (v_w1,'NFC_MOBILE','PROFICIENT','2023-01-15','HR Director',NULL,FALSE,NULL,NULL),
  -- Hairul (Asst Manager)
  (v_w2,'TEAM_LEAD','PROFICIENT','2023-02-10','Razif Osman','2025-02-10',TRUE,'CERT-MGR-002','2025-02-10'),
  (v_w2,'DRC_TESTING','COMPETENT','2023-02-10','Razif Osman',NULL,FALSE,NULL,NULL),
  (v_w2,'FIRST_AID','COMPETENT','2022-06-01','Red Crescent','2024-06-01',TRUE,'FA-2022-088','2024-06-01'),
  -- Siti Rohani (Conductor Div A)
  (v_w3,'TAP_S2','EXPERT','2022-03-20','Hairul Aziz','2024-03-20',TRUE,'CERT-TAP-003','2024-03-20'),
  (v_w3,'TEAM_LEAD','PROFICIENT','2022-03-20','Hairul Aziz','2024-03-20',FALSE,NULL,NULL),
  (v_w3,'SPRAYING','COMPETENT','2022-03-20','DOSM Officer','2024-03-20',TRUE,'SPRAY-003','2024-03-20'),
  (v_w3,'FIRST_AID','COMPETENT','2021-05-15','Red Crescent','2023-05-15',TRUE,'FA-2021-044','2023-05-15'),
  (v_w3,'NFC_MOBILE','PROFICIENT','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  -- Mohd Fadzil (Conductor Div B)
  (v_w4,'TAP_S2','PROFICIENT','2022-04-05','Hairul Aziz','2024-04-05',TRUE,'CERT-TAP-004','2024-04-05'),
  (v_w4,'TEAM_LEAD','COMPETENT','2022-04-05','Hairul Aziz','2024-04-05',FALSE,NULL,NULL),
  (v_w4,'MANURING','EXPERT','2022-04-05','Hairul Aziz',NULL,FALSE,NULL,NULL),
  -- Aminah Hassan (Senior Tapper)
  (v_w5,'TAP_S2','EXPERT','2023-01-10','Siti Rohani','2025-01-10',TRUE,'CERT-TAP-005','2025-01-10'),
  (v_w5,'TAP_HIGH_PANEL','PROFICIENT','2023-01-10','Siti Rohani','2025-01-10',TRUE,'CERT-HP-005','2025-01-10'),
  (v_w5,'TAP_STIMULANT','COMPETENT','2023-03-15','MARDI Trainer','2025-03-15',TRUE,'ETH-005','2025-03-15'),
  (v_w5,'FIRST_AID','BEGINNER','2022-11-01','Red Crescent','2024-11-01',TRUE,'FA-2022-112','2024-11-01'),
  (v_w5,'NFC_MOBILE','COMPETENT','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  -- Rajan Muthu (Tapper)
  (v_w6,'TAP_S2','PROFICIENT','2023-02-20','Siti Rohani','2025-02-20',TRUE,'CERT-TAP-006','2025-02-20'),
  (v_w6,'NFC_MOBILE','COMPETENT','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  (v_w6,'FIRE_SAFETY','NOVICE','2022-10-10','Safety Officer',NULL,FALSE,NULL,NULL),
  -- Selvam Krishnan (Tapper)
  (v_w7,'TAP_S2','COMPETENT','2023-03-05','Siti Rohani','2025-03-05',TRUE,'CERT-TAP-007','2025-03-05'),
  (v_w7,'TAP_S4','BEGINNER','2023-09-15','Siti Rohani',NULL,FALSE,NULL,NULL),
  (v_w7,'NFC_MOBILE','BEGINNER','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  -- Balakrishnan (Senior Tapper)
  (v_w8,'TAP_S2','EXPERT','2022-11-10','Mohd Fadzil','2024-11-10',TRUE,'CERT-TAP-008','2024-11-10'),
  (v_w8,'TAP_HIGH_PANEL','COMPETENT','2022-11-10','Mohd Fadzil','2024-11-10',FALSE,NULL,NULL),
  (v_w8,'TRACTOR','COMPETENT','2021-08-01','Safety Officer','2023-08-01',TRUE,'TRAC-008','2023-08-01'),
  (v_w8,'FIRST_AID','COMPETENT','2022-06-01','Red Crescent','2024-06-01',TRUE,'FA-2022-067','2024-06-01'),
  -- Karthik (Tapper)
  (v_w9,'TAP_S2','BEGINNER','2023-04-10','Balakrishnan Nair','2024-04-10',FALSE,NULL,NULL),
  (v_w9,'NFC_MOBILE','COMPETENT','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  -- Noor Azlina (Field Collector)
  (v_w10,'MANURING','COMPETENT','2022-07-20','Siti Rohani',NULL,FALSE,NULL,NULL),
  (v_w10,'NFC_MOBILE','PROFICIENT','2023-06-01','IT Trainer',NULL,FALSE,NULL,NULL),
  (v_w10,'FIRST_AID','BEGINNER','2023-03-01','Red Crescent','2025-03-01',FALSE,NULL,NULL);

-- ============================================================================
-- M4 — NEXT OF KIN
-- ============================================================================
INSERT INTO worker_next_of_kin (worker_id,kin_name,relationship_code,
  date_of_birth,mobile_phone,is_emergency_contact,is_beneficiary,beneficiary_pct)
VALUES
  (v_w3,'Ahmad bin Rohani','SPOUSE','1982-05-20','012-8887766',TRUE,TRUE,100.00),
  (v_w4,'Nor Haslinda bt Hamid','SPOUSE','1989-09-12','011-7775544',TRUE,TRUE,50.00),
  (v_w4,'Fadzil Jr','CHILD','2015-03-08',NULL,FALSE,TRUE,50.00),
  (v_w5,'Hassan bin Malik','SPOUSE','1980-02-14','013-4443322',TRUE,TRUE,100.00),
  (v_w6,'Selvakumar Muthu','PARENT','1958-11-30','017-3332211',TRUE,FALSE,NULL),
  (v_w7,'Priya Krishnan','SPOUSE','1994-08-25','016-2221100',TRUE,TRUE,100.00),
  (v_w8,'Kamala Nair','SPOUSE','1981-04-19','014-1110099',TRUE,TRUE,60.00),
  (v_w8,'Rajan Nair','CHILD','2005-07-11',NULL,FALSE,TRUE,40.00),
  (v_w10,'Azman bin Yusof','SPOUSE','1985-12-03','011-9998877',TRUE,TRUE,100.00);

-- ============================================================================
-- M4 — WORKER DOCUMENTS
-- ============================================================================
INSERT INTO worker_document (worker_id,doc_type_code,document_number,
  issued_date,expiry_date,issuing_authority,is_verified,verified_by,verified_at,status)
VALUES
  -- NIC for all workers
  (v_w3,'NIC','C345678901','2010-01-01',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w4,'NIC','D456789012','2008-05-12',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w5,'NIC','E567890123','2009-03-20',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w6,'NIC','F678901234','2015-07-14',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w7,'NIC','G789012345','2016-05-03',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w8,'NIC','H890123456','2005-12-11',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w9,'NIC','I901234567','2018-03-29',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w10,'NIC','J012345678','2012-06-17',NULL,'Jabatan Pendaftaran Negara',TRUE,'HR Admin',NOW(),'ACTIVE'),
  -- Medical fitness certs
  (v_w5,'MEDICAL_CERT','MED-SPE-005',CURRENT_DATE-180,CURRENT_DATE+185,'Klinik Kesihatan KK',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w6,'MEDICAL_CERT','MED-SPE-006',CURRENT_DATE-120,CURRENT_DATE+245,'Klinik Kesihatan KK',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w7,'MEDICAL_CERT','MED-SPE-007',CURRENT_DATE-90,CURRENT_DATE+275,'Klinik Kesihatan KK',FALSE,NULL,NULL,'ACTIVE'),
  (v_w8,'MEDICAL_CERT','MED-SPE-008',CURRENT_DATE-200,CURRENT_DATE+165,'Klinik Kesihatan KK',TRUE,'HR Admin',NOW(),'ACTIVE'),
  -- Chemical spray certs
  (v_w3,'SPRAY_CERT','SPRAY-SWD-003',CURRENT_DATE-300,CURRENT_DATE+430,'Jabatan Alam Sekitar',TRUE,'HR Admin',NOW(),'ACTIVE'),
  -- Contracts
  (v_w5,'CONTRACT','CONT-SPE-005','2006-04-01',NULL,'Sungai Pinang Estate',TRUE,'HR Admin',NOW(),'ACTIVE'),
  (v_w9,'CONTRACT','CONT-SPE-009','2018-11-01','2026-10-31','Sungai Pinang Estate',TRUE,'HR Admin',NOW(),'ACTIVE');

-- ============================================================================
-- M4 — FIELD ASSIGNMENT HISTORY
-- ============================================================================
INSERT INTO worker_field_assignment (worker_id,field_id,gang_id,assignment_type,
  effective_from,effective_to,assigned_by,reason)
VALUES
  (v_w5,v_f1,v_g1,'PRIMARY','2006-10-01',NULL,'Hairul Aziz','Initial assignment upon confirmation'),
  (v_w6,v_f1,v_g1,'PRIMARY','2012-08-15',NULL,'Siti Rohani','Post-probation primary field'),
  (v_w7,v_f2,v_g1,'PRIMARY','2014-02-01',NULL,'Siti Rohani','Assigned to Block A2 PB260'),
  (v_w8,v_f3,v_g2,'PRIMARY','2005-01-20',NULL,'Mohd Fadzil','Lead tapper for Div B'),
  (v_w9,v_f4,v_g2,'PRIMARY','2019-05-01',NULL,'Mohd Fadzil','Contract tapper Block B2'),
  (v_w10,v_f1,v_g1,'PRIMARY','2010-03-10',NULL,'Siti Rohani','Field collector Div A'),
  -- Historical re-assignment (Selvam was on A1 before A2)
  (v_w7,v_f1,v_g1,'PRIMARY','2013-08-01','2014-01-31','Siti Rohani','Initial assignment to A1'),
  (v_w7,v_f2,v_g1,'SECONDARY','2023-09-01',NULL,'Siti Rohani','Relief coverage for A2');

-- ============================================================================
-- M4 — LEAVE RECORDS (approved)
-- ============================================================================
INSERT INTO worker_leave (worker_id,leave_type_code,leave_start_date,leave_end_date,
  total_days,reason,approval_status,approved_by,approved_at)
VALUES
  (v_w5,'ANNUAL',CURRENT_DATE-10,CURRENT_DATE-9,2,'Family function',
    'APPROVED',v_w3,NOW()-INTERVAL'12 days')
RETURNING leave_id INTO v_leave1;

INSERT INTO worker_leave (worker_id,leave_type_code,leave_start_date,leave_end_date,
  total_days,reason,approval_status,approved_by,approved_at)
VALUES
  (v_w7,'SICK',CURRENT_DATE-1,CURRENT_DATE-1,1,'Fever and flu',
    'APPROVED',v_w3,NOW()-INTERVAL'1 day'),
  (v_w9,'SICK',CURRENT_DATE-2,CURRENT_DATE-2,1,'Food poisoning',
    'APPROVED',v_w4,NOW()-INTERVAL'3 days'),
  (v_w6,'ANNUAL',CURRENT_DATE+5,CURRENT_DATE+6,2,'Family emergency',
    'PENDING',NULL,NULL),
  (v_w8,'CASUAL',CURRENT_DATE-20,CURRENT_DATE-20,1,'Personal matter',
    'APPROVED',v_w4,NOW()-INTERVAL'22 days');

-- ============================================================================
-- M4 — LEAVE BALANCES (2026)
-- ============================================================================
INSERT INTO worker_leave_balance (worker_id,leave_type_code,balance_year,
  entitled_days,taken_days,pending_days,carried_forward)
SELECT wid, ltype, 2026, ent, taken, pending, cf FROM (VALUES
  (v_w3,'ANNUAL',14,2,0,2),(v_w3,'SICK',14,1,0,0),
  (v_w4,'ANNUAL',14,3,0,2),(v_w4,'SICK',14,0,0,0),
  (v_w5,'ANNUAL',14,5,0,2),(v_w5,'SICK',14,1,0,0),
  (v_w6,'ANNUAL',14,2,2,1),(v_w6,'SICK',14,2,0,0),
  (v_w7,'ANNUAL',14,4,0,2),(v_w7,'SICK',14,1,0,0),
  (v_w8,'ANNUAL',14,3,0,3),(v_w8,'SICK',14,1,0,0),
  (v_w9,'ANNUAL',14,1,0,0),(v_w9,'SICK',14,1,0,0),
  (v_w10,'ANNUAL',14,3,0,2),(v_w10,'SICK',14,2,0,0)
) AS t(wid,ltype,ent,taken,pending,cf);

-- ============================================================================
-- M4 — TRAINING RECORDS
-- ============================================================================
INSERT INTO worker_training (worker_id,training_type_code,training_title,
  start_date,end_date,duration_days,trainer_name,training_location,training_method,
  assessment_score,passed,certificate_number,certificate_expiry)
VALUES
  -- Induction for newer workers
  (v_w7,'INDUCTION','New Employee Induction — SPE 2013','2013-08-01','2013-08-02',2,
    'HR Manager','SPE Office','CLASSROOM',85.0,TRUE,'IND-2013-007',NULL),
  (v_w9,'INDUCTION','New Employee Induction — SPE 2018','2018-11-01','2018-11-02',2,
    'HR Manager','SPE Office','CLASSROOM',78.0,TRUE,'IND-2018-009',NULL),
  -- Basic tapping training
  (v_w6,'TAP_BASIC','Basic Rubber Tapping — Batch 4','2012-02-15','2012-03-01',14,
    'MARDI Trainer','Field A1','FIELD_PRACTICAL',82.0,TRUE,'TAP-BASIC-006',NULL),
  (v_w7,'TAP_BASIC','Basic Rubber Tapping — Batch 6','2013-08-05','2013-08-19',14,
    'Siti Rohani','Field A1','FIELD_PRACTICAL',76.0,TRUE,'TAP-BASIC-007',NULL),
  (v_w9,'TAP_BASIC','Basic Rubber Tapping — Batch 12','2018-11-15','2018-11-29',14,
    'Balakrishnan Nair','Field B1','FIELD_PRACTICAL',68.0,TRUE,'TAP-BASIC-009',NULL),
  -- Chemical safety (mandatory)
  (v_w3,'CHEMICAL_SAFETY','Chemical Handling & Safety','2021-03-10','2021-03-11',2,
    'DOSH Officer','SPE Meeting Room','CLASSROOM',90.0,TRUE,'CHEM-2021-003','2023-03-11'),
  (v_w4,'CHEMICAL_SAFETY','Chemical Handling & Safety','2021-03-10','2021-03-11',2,
    'DOSH Officer','SPE Meeting Room','CLASSROOM',88.0,TRUE,'CHEM-2021-004','2023-03-11'),
  (v_w8,'CHEMICAL_SAFETY','Chemical Handling & Safety — Refresher','2022-09-05','2022-09-06',2,
    'DOSH Officer','SPE Meeting Room','CLASSROOM',92.0,TRUE,'CHEM-2022-008','2024-09-06'),
  -- First aid
  (v_w3,'FIRST_AID','Basic First Aid — Red Crescent','2021-05-15','2021-05-15',1,
    'Red Crescent Trainer','SPE Clinic','CLASSROOM',88.0,TRUE,'FA-2021-044','2023-05-15'),
  (v_w5,'FIRST_AID','Basic First Aid — Red Crescent','2022-11-01','2022-11-01',1,
    'Red Crescent Trainer','SPE Clinic','CLASSROOM',80.0,TRUE,'FA-2022-112','2024-11-01'),
  -- MR training (high tech demo)
  (v_w3,'MR_TRAINING','AR/MR Tapping Quality Training — Pilot Batch',
    '2024-06-10','2024-06-12',3,'MARDI Digital Trainer','SPE Field A1','MR_TRAINING',
    95.0,TRUE,'MR-2024-001',NULL),
  (v_w5,'MR_TRAINING','AR/MR Tapping Quality Training — Pilot Batch',
    '2024-06-10','2024-06-12',3,'MARDI Digital Trainer','SPE Field A1','MR_TRAINING',
    92.0,TRUE,'MR-2024-002',NULL),
  -- Mobile app training
  (v_w5,'MOBILE_APP','NFC Scanning & Mobile App','2023-06-01','2023-06-01',1,
    'IT Trainer','SPE Office','CLASSROOM',100.0,TRUE,NULL,NULL),
  (v_w6,'MOBILE_APP','NFC Scanning & Mobile App','2023-06-01','2023-06-01',1,
    'IT Trainer','SPE Office','CLASSROOM',95.0,TRUE,NULL,NULL),
  -- Annual tapping refresher
  (v_w5,'REFRESH_TAP','Annual Tapping Refresher 2025','2025-01-15','2025-01-16',2,
    'Siti Rohani','Field A1','FIELD_PRACTICAL',96.0,TRUE,NULL,NULL),
  (v_w8,'REFRESH_TAP','Annual Tapping Refresher 2025','2025-01-15','2025-01-16',2,
    'Mohd Fadzil','Field B1','FIELD_PRACTICAL',91.0,TRUE,NULL,NULL);

-- ============================================================================
-- M4 — PAY STRUCTURES
-- ============================================================================
INSERT INTO worker_pay_structure (worker_id,component_code,amount,currency_code,
  frequency,effective_from)
VALUES
  -- Aminah Hassan (Senior Tapper)
  (v_w5,'BASIC_SALARY',3200.00,'MYR','PER_MONTH','2006-10-01'),
  (v_w5,'PIECE_RATE_PAY',0.80,'MYR','PER_KG','2020-01-01'),
  (v_w5,'LATEX_INCENTIVE',150.00,'MYR','PER_MONTH','2022-01-01'),
  (v_w5,'QUALITY_BONUS',100.00,'MYR','PER_MONTH','2023-01-01'),
  (v_w5,'HOUSING_ALLOW',250.00,'MYR','PER_MONTH','2006-10-01'),
  (v_w5,'EPF_DEDUCTION',352.00,'MYR','PER_MONTH','2006-10-01'),
  -- Rajan Muthu (Tapper)
  (v_w6,'BASIC_SALARY',2400.00,'MYR','PER_MONTH','2012-08-15'),
  (v_w6,'PIECE_RATE_PAY',0.75,'MYR','PER_KG','2020-01-01'),
  (v_w6,'HOUSING_ALLOW',200.00,'MYR','PER_MONTH','2012-08-15'),
  (v_w6,'EPF_DEDUCTION',264.00,'MYR','PER_MONTH','2012-08-15'),
  -- Selvam Krishnan (Tapper)
  (v_w7,'BASIC_SALARY',2400.00,'MYR','PER_MONTH','2014-02-01'),
  (v_w7,'PIECE_RATE_PAY',0.75,'MYR','PER_KG','2020-01-01'),
  (v_w7,'HOUSING_ALLOW',200.00,'MYR','PER_MONTH','2014-02-01'),
  (v_w7,'EPF_DEDUCTION',264.00,'MYR','PER_MONTH','2014-02-01'),
  -- Balakrishnan Nair (Senior Tapper)
  (v_w8,'BASIC_SALARY',3200.00,'MYR','PER_MONTH','2005-01-20'),
  (v_w8,'PIECE_RATE_PAY',0.80,'MYR','PER_KG','2020-01-01'),
  (v_w8,'LATEX_INCENTIVE',150.00,'MYR','PER_MONTH','2022-01-01'),
  (v_w8,'HOUSING_ALLOW',250.00,'MYR','PER_MONTH','2005-01-20'),
  (v_w8,'EPF_DEDUCTION',352.00,'MYR','PER_MONTH','2005-01-20'),
  -- Karthik Subramaniam (Contract Tapper)
  (v_w9,'BASIC_SALARY',2100.00,'MYR','PER_MONTH','2019-05-01'),
  (v_w9,'HOUSING_ALLOW',200.00,'MYR','PER_MONTH','2019-05-01'),
  -- Noor Azlina (Collector)
  (v_w10,'BASIC_SALARY',2600.00,'MYR','PER_MONTH','2010-03-10'),
  (v_w10,'TRANSPORT_ALLOW',100.00,'MYR','PER_MONTH','2010-03-10'),
  (v_w10,'EPF_DEDUCTION',286.00,'MYR','PER_MONTH','2010-03-10');

-- ============================================================================
-- M4 — SAFETY INCIDENTS
-- ============================================================================
INSERT INTO worker_safety_incident (worker_id,plantation_id,field_id,
  incident_date,incident_time,incident_type,severity,description,
  body_part_affected,first_aid_given,hospital_referral,days_lost,
  root_cause,corrective_action,investigated_by,investigation_date)
VALUES
  (v_w6,v_pid,v_f1,CURRENT_DATE-45,'07:30','CUT_WOUND','MINOR',
    'Tapper suffered a minor cut to left hand while sharpening tapping knife',
    'Left hand — palm',TRUE,FALSE,0,
    'Knife slipped due to worn handle grip',
    'Replaced all tapping knives with anti-slip handle models; refresher on knife safety',
    'Siti Rohani',CURRENT_DATE-44),
  (v_w9,v_pid,v_f4,CURRENT_DATE-120,'09:15','SNAKE_BITE','MODERATE',
    'Worker encountered and was bitten by a venomous snake (pit viper) while weeding',
    'Right ankle',TRUE,TRUE,1,
    'Insufficient undergrowth clearing; worker without proper footwear',
    'Mandatory boot policy enforced; undergrowth clearance protocol updated',
    'Mohd Fadzil',CURRENT_DATE-119);

-- ============================================================================
-- M4 — WORKER STATUS CHANGE LOG
-- ============================================================================
INSERT INTO worker_status_change_log (worker_id,change_date,from_status,to_status,
  reason,effective_date,changed_by)
VALUES
  (v_w5,'2006-10-01','PROBATION','ACTIVE','Probation period completed satisfactorily',
    '2006-10-01','Hairul Aziz'),
  (v_w6,'2012-08-15','PROBATION','ACTIVE','Probation completed — good tapping scores',
    '2012-08-15','Siti Rohani'),
  (v_w7,'2014-02-01','PROBATION','ACTIVE','Probation completed','2014-02-01','Siti Rohani'),
  (v_w9,'2019-05-01','PROBATION','ACTIVE','Contract worker probation passed',
    '2019-05-01','Mohd Fadzil');

-- ============================================================================
-- M2 — TREE ROWS
-- ============================================================================
INSERT INTO tree_row (field_id,row_number,row_direction,tree_spacing_m,row_spacing_m,number_of_trees)
VALUES (v_f1,1,'NS',3.0,7.0,120) RETURNING row_id INTO v_r1;
INSERT INTO tree_row (field_id,row_number,row_direction,tree_spacing_m,row_spacing_m,number_of_trees)
VALUES (v_f1,2,'NS',3.0,7.0,118) RETURNING row_id INTO v_r2;
INSERT INTO tree_row (field_id,row_number,row_direction,tree_spacing_m,row_spacing_m,number_of_trees)
VALUES (v_f2,1,'EW',3.0,7.0,115) RETURNING row_id INTO v_r3;
INSERT INTO tree_row (field_id,row_number,row_direction,tree_spacing_m,row_spacing_m,number_of_trees)
VALUES (v_f2,2,'EW',3.0,7.0,117) RETURNING row_id INTO v_r4;

-- ============================================================================
-- M2 — TREES (15 trees)
-- ============================================================================
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r1,'A1-R1-001',1,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77020,101.10810,'system')
RETURNING tree_id INTO v_tree1;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r1,'A1-R1-002',2,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77030,101.10810,'system')
RETURNING tree_id INTO v_tree2;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r1,'A1-R1-003',3,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77040,101.10810,'system')
RETURNING tree_id INTO v_tree3;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r1,'A1-R1-004',4,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77050,101.10810,'system')
RETURNING tree_id INTO v_tree4;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r1,'A1-R1-005',5,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77060,101.10810,'system')
RETURNING tree_id INTO v_tree5;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r2,'A1-R2-001',1,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77020,101.10900,'system')
RETURNING tree_id INTO v_tree6;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r2,'A1-R2-002',2,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77030,101.10900,'system')
RETURNING tree_id INTO v_tree7;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r2,'A1-R2-003',3,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77040,101.10900,'system')
RETURNING tree_id INTO v_tree8;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r2,'A1-R2-004',4,v_c1,'2005-03-01',2005,'TAPPING','BI-1','S2D2',4.77050,101.10900,'system')
RETURNING tree_id INTO v_tree9;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f1,v_r2,'A1-R2-005',5,v_c1,'2005-03-01',2005,'RESTING','BI-1','S2D2',4.77060,101.10900,'system')
RETURNING tree_id INTO v_tree10;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f2,v_r3,'A2-R1-001',1,v_c2,'2007-06-01',2007,'TAPPING','BI-1','S2D3',4.77310,101.11110,'system')
RETURNING tree_id INTO v_tree11;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f2,v_r3,'A2-R1-002',2,v_c2,'2007-06-01',2007,'TAPPING','BI-1','S2D3',4.77320,101.11110,'system')
RETURNING tree_id INTO v_tree12;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f2,v_r3,'A2-R1-003',3,v_c2,'2007-06-01',2007,'TAPPING','BI-1','S2D3',4.77330,101.11110,'system')
RETURNING tree_id INTO v_tree13;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f2,v_r3,'A2-R1-004',4,v_c2,'2007-06-01',2007,'TAPPING','BI-1','S2D3',4.77340,101.11110,'system')
RETURNING tree_id INTO v_tree14;
INSERT INTO tree (plantation_id,field_id,row_id,tree_code,tree_sequence,clone_id,
  planting_date,planting_year,tree_status,current_panel,current_tapping_system,
  gps_latitude,gps_longitude,created_by)
VALUES
  (v_pid,v_f2,v_r3,'A2-R1-005',5,v_c2,'2007-06-01',2007,'DISEASED','BI-1','S2D3',4.77350,101.11110,'system')
RETURNING tree_id INTO v_tree15;

-- ============================================================================
-- M2 — TREE TAGS (NFC)
-- ============================================================================
INSERT INTO tree_tag (tree_id,tag_uid,tag_type_code,installed_date,is_active,total_scan_count)
VALUES
  (v_tree1,'TAG-A1R1-001','NFC_TAG','2022-01-15',TRUE,148),
  (v_tree2,'TAG-A1R1-002','NFC_TAG','2022-01-15',TRUE,142),
  (v_tree3,'TAG-A1R1-003','NFC_TAG','2022-01-15',TRUE,151),
  (v_tree4,'TAG-A1R1-004','NFC_TAG','2022-01-15',TRUE,139),
  (v_tree5,'TAG-A1R1-005','NFC_TAG','2022-01-15',TRUE,144),
  (v_tree6,'TAG-A1R2-001','NFC_TAG','2022-01-16',TRUE,138),
  (v_tree7,'TAG-A1R2-002','NFC_TAG','2022-01-16',TRUE,145),
  (v_tree8,'TAG-A1R2-003','NFC_TAG','2022-01-16',TRUE,133),
  (v_tree9,'TAG-A1R2-004','NFC_TAG','2022-01-16',TRUE,147),
  (v_tree10,'TAG-A1R2-005','NFC_TAG','2022-01-16',TRUE,52),
  (v_tree11,'TAG-A2R1-001','NFC_TAG','2022-03-10',TRUE,118),
  (v_tree12,'TAG-A2R1-002','NFC_TAG','2022-03-10',TRUE,122),
  (v_tree13,'TAG-A2R1-003','NFC_TAG','2022-03-10',TRUE,115),
  (v_tree14,'TAG-A2R1-004','NFC_TAG','2022-03-10',TRUE,109),
  (v_tree15,'TAG-A2R1-005','NFC_TAG','2022-03-10',FALSE,87);

-- ============================================================================
-- M2 — TREE GROWTH MEASUREMENTS
-- ============================================================================
INSERT INTO tree_growth_measurement (tree_id,parameter_code,measured_value,
  measurement_unit,measurement_date,measured_by,remarks)
VALUES
  (v_tree1,'GIRTH',48.5,'cm','2010-03-01','Siti Rohani','Annual girth recording'),
  (v_tree1,'GIRTH',55.2,'cm','2015-03-01','Siti Rohani','Annual girth recording'),
  (v_tree1,'GIRTH',60.8,'cm','2020-03-01','Siti Rohani','Annual girth recording'),
  (v_tree1,'TREE_HEIGHT',12.3,'m','2010-03-01','Siti Rohani','Annual girth recording'),
  (v_tree1,'TREE_HEIGHT',14.1,'m','2015-03-01','Siti Rohani','Annual girth recording'),
  (v_tree1,'TREE_HEIGHT',15.4,'m','2020-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'GIRTH',47.2,'cm','2010-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'GIRTH',53.8,'cm','2015-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'GIRTH',59.1,'cm','2020-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'TREE_HEIGHT',12.0,'m','2010-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'TREE_HEIGHT',13.9,'m','2015-03-01','Siti Rohani','Annual girth recording'),
  (v_tree2,'TREE_HEIGHT',15.2,'m','2020-03-01','Siti Rohani','Annual girth recording'),
  (v_tree11,'GIRTH',42.0,'cm','2012-04-01','Siti Rohani','PB260 first tapping girth check'),
  (v_tree11,'GIRTH',51.5,'cm','2017-04-01','Siti Rohani','Annual girth'),
  (v_tree11,'GIRTH',57.9,'cm','2022-04-01','Siti Rohani','Annual girth'),
  (v_tree11,'TREE_HEIGHT',10.8,'m','2012-04-01','Siti Rohani','PB260 first tapping girth check'),
  (v_tree11,'TREE_HEIGHT',12.5,'m','2017-04-01','Siti Rohani','Annual girth'),
  (v_tree11,'TREE_HEIGHT',14.0,'m','2022-04-01','Siti Rohani','Annual girth'),
  (v_tree15,'GIRTH',44.2,'cm','2017-04-01','Siti Rohani','Pre-disease measurement'),
  (v_tree15,'TREE_HEIGHT',11.2,'m','2017-04-01','Siti Rohani','Pre-disease measurement');

-- ============================================================================
-- M2 — TREE PANEL HISTORY
-- ============================================================================
INSERT INTO tree_panel_history (tree_id,panel_code,panel_position,panel_side,
  tapping_system_code,opened_date,closed_date,bark_thickness_at_open_mm,status)
VALUES
  (v_tree1,'BI-1','LOW','INNER','S2D2','2012-03-01','2018-03-01',8.5,'CLOSED'),
  (v_tree1,'BI-2','LOW','INNER','S2D2','2018-03-01',NULL,6.2,'ACTIVE'),
  (v_tree2,'BI-1','LOW','INNER','S2D2','2012-03-01','2018-03-01',8.8,'CLOSED'),
  (v_tree2,'BI-2','LOW','INNER','S2D2','2018-03-01',NULL,6.5,'ACTIVE'),
  (v_tree11,'BI-1','LOW','INNER','S2D3','2014-06-01',NULL,9.1,'ACTIVE');

-- ============================================================================
-- M2 — TREE HEALTH INSPECTIONS
-- ============================================================================
INSERT INTO tree_health_inspection (tree_id,inspection_date,inspector_name,health_rating,
  canopy_score,disease_detected,remarks)
VALUES
  (v_tree1,CURRENT_DATE-30,'Siti Rohani','GOOD',4,FALSE,'Healthy, tapping progressing well'),
  (v_tree2,CURRENT_DATE-30,'Siti Rohani','GOOD',5,FALSE,'Good yield, no issues'),
  (v_tree3,CURRENT_DATE-30,'Siti Rohani','GOOD',4,FALSE,'Minor bark dryness noted'),
  (v_tree10,CURRENT_DATE-30,'Siti Rohani','FAIR',3,FALSE,'Panel resting — bark recovery period'),
  (v_tree15,CURRENT_DATE-7,'Siti Rohani','POOR',2,TRUE,'Abnormal Leaf Fall confirmed — Phytophthora infection'),
  (v_tree14,CURRENT_DATE-7,'Siti Rohani','FAIR',3,FALSE,'Adjacent to diseased tree — monitoring closely'),
  (v_tree11,CURRENT_DATE-14,'Siti Rohani','GOOD',5,FALSE,'PB260 vigorous growth');

-- ============================================================================
-- M2 — TREE DISEASE INCIDENT (tree 15 is DISEASED)
-- ============================================================================
INSERT INTO tree_disease_incident (tree_id,disease_id,detected_date,
  severity,affected_area_pct,detected_by,remarks)
SELECT v_tree15, disease_id, CURRENT_DATE-21, 'MODERATE', 60, 'Siti Rohani',
    'Abnormal Leaf Fall (Phytophthora spp.) — infection from adjacent field'
FROM disease_master WHERE disease_code = 'ABNORMAL_LF'
UNION ALL
SELECT v_tree14, disease_id, CURRENT_DATE-45, 'MILD', 15, 'Siti Rohani',
    'Mild tapping panel dryness — tapping frequency reduced'
FROM disease_master WHERE disease_code = 'TPD';

-- ============================================================================
-- M2 — TREE TREATMENT RECORDS
-- ============================================================================
INSERT INTO tree_treatment_record (tree_id,incident_id,treatment_code,treatment_date,
  product_name,dosage_amount,dosage_unit,applied_by,next_treatment_date,remarks)
SELECT v_tree15, di.incident_id, 'HEXACONAZOLE', CURRENT_DATE-14,
  'Hexaconazole 5% SC', 2, 'g/L', 'Pest Control Team', CURRENT_DATE+7,
  'First application — fortnightly spray program initiated'
FROM tree_disease_incident di
WHERE di.tree_id = v_tree15
LIMIT 1;

-- ============================================================================
-- M2 — TREE CENSUS SUMMARY
-- ============================================================================
INSERT INTO tree_census_summary (field_id,census_year,census_date,
  total_trees,live_trees,tappable_trees,trees_under_tapping,immature_trees,
  diseased_trees,dead_trees_ytd,conducted_by)
VALUES
  (v_f1,2024,CURRENT_DATE-60,238,234,234,226,0,2,4,'Siti Rohani'),
  (v_f2,2024,CURRENT_DATE-58,232,231,231,218,0,5,1,'Siti Rohani');

-- ============================================================================
-- M3 — IoT DEVICES
-- ============================================================================
INSERT INTO iot_device (plantation_id,field_id,device_uid,device_type_code,
  serial_number,manufacturer,model_number,firmware_version,installed_date,
  last_heartbeat_at,battery_level_pct,status)
VALUES
  (v_pid,v_f1,'KNIFE-A1-001','SMART_KNIFE','SN-KNIFE-001','TapTech','SmartTap v2',
    '2.3.1','2023-06-01',NOW()-INTERVAL'2h',78.0,'ACTIVE')
RETURNING device_id INTO v_iot1;

INSERT INTO iot_device (plantation_id,field_id,device_uid,device_type_code,
  serial_number,manufacturer,model_number,firmware_version,installed_date,
  last_heartbeat_at,battery_level_pct,status)
VALUES
  (v_pid,v_f1,'GPS-A1-001','GPS_WEARABLE','SN-GPS-001','GeoTrack','FieldBand Pro',
    '1.8.5','2023-06-01',NOW()-INTERVAL'1h',62.0,'ACTIVE')
RETURNING device_id INTO v_iot2;

-- ============================================================================
-- M3 — COLLECTION POINTS
-- ============================================================================
INSERT INTO collection_point (plantation_id,division_id,point_code,point_name,
  point_type_code,gps_latitude,gps_longitude,storage_capacity_kg,status)
VALUES (v_pid,v_d1,'CP-A1','Field A1 Roadside Tank','ROADSIDE_TANK',4.7710,101.1085,3000.0,'ACTIVE')
RETURNING collection_point_id INTO v_cp1;

INSERT INTO collection_point (plantation_id,division_id,point_code,point_name,
  point_type_code,gps_latitude,gps_longitude,storage_capacity_kg,status)
VALUES (v_pid,v_d1,'CP-A2','Field A2 Roadside Tank','ROADSIDE_TANK',4.7735,101.1115,3000.0,'ACTIVE')
RETURNING collection_point_id INTO v_cp2;

INSERT INTO collection_point (plantation_id,division_id,point_code,point_name,
  point_type_code,gps_latitude,gps_longitude,storage_capacity_kg,status)
VALUES (v_pid,v_d1,'CP-DC','Division A Collection Hub','DIVISION_CENTER',4.7720,101.1100,15000.0,'ACTIVE')
RETURNING collection_point_id INTO v_cp3;

-- ============================================================================
-- M3 — WEATHER OBSERVATIONS
-- ============================================================================
INSERT INTO weather_observation (plantation_id,field_id,observation_date,
  observation_time,temperature_min_c,temperature_max_c,humidity_min_pct,
  humidity_max_pct,rainfall_mm,suitable_for_tapping,weather_condition,
  data_source,recorded_by)
VALUES
  (v_pid,v_f1,CURRENT_DATE-6,'06:00',22.5,30.2,75.0,88.0,0.0,TRUE,'CLEAR','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE-5,'06:00',23.0,29.8,78.0,90.0,0.0,TRUE,'CLOUDY','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE-4,'06:00',22.0,31.5,72.0,85.0,0.0,TRUE,'CLEAR','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE-3,'06:00',21.5,28.0,80.0,95.0,12.5,FALSE,'HEAVY_RAIN','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE-2,'06:00',23.5,30.8,76.0,88.0,3.2,TRUE,'LIGHT_RAIN','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE-1,'06:00',22.8,31.0,74.0,86.0,0.0,TRUE,'CLEAR','MANUAL','Siti Rohani'),
  (v_pid,v_f1,CURRENT_DATE,'06:00',23.2,30.5,75.0,87.0,0.0,TRUE,'CLEAR','MANUAL','Siti Rohani');

-- ============================================================================
-- M3 — TAPPING SCHEDULES
-- ============================================================================
INSERT INTO tapping_schedule (plantation_id,field_id,schedule_name,tapping_system_code,
  frequency_days,tapping_days,expected_start_time,expected_end_time,
  effective_from,target_trees_per_day,target_yield_kg_per_day,status,created_by)
VALUES (v_pid,v_f1,'Block A1 S/2 d2','S2D2',2,'MON,WED,FRI',
  '04:30','09:00','2024-01-01',120,180.0,'ACTIVE','system')
RETURNING schedule_id INTO v_s1;

INSERT INTO tapping_schedule (plantation_id,field_id,schedule_name,tapping_system_code,
  frequency_days,tapping_days,expected_start_time,expected_end_time,
  effective_from,target_trees_per_day,target_yield_kg_per_day,status,created_by)
VALUES (v_pid,v_f2,'Block A2 S/2 d3','S2D3',3,'MON,THU',
  '04:30','09:30','2024-01-01',115,160.0,'ACTIVE','system')
RETURNING schedule_id INTO v_s2;

-- ============================================================================
-- M3 — TAPPING TASKS (6 tasks over last week)
-- ============================================================================
INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,actual_end_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_cup_lump_kg,total_yield_kg,
  weather_temp_c,weather_humidity_pct,weather_condition,
  tapping_quality_score,supervisor_verified,verified_by,
  smart_knife_device_id,gps_wearable_id,geofence_verified,created_by)
VALUES
(v_pid,v_f1,v_d1,v_s1,CURRENT_DATE-6,
 v_w5,'Aminah Hassan','EMP-003','S2D2','BI-1','COMPLETED',
 CURRENT_DATE-6+INTERVAL'4h35m',CURRENT_DATE-6+INTERVAL'8h50m',
 120,118,2,165.50,3.20,168.70,25.5,82.0,'CLEAR',8.5,TRUE,'Siti Rohani',
 'KNIFE-A1-001','GPS-A1-001',TRUE,'system')
RETURNING task_id INTO v_t1;

INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,actual_end_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_cup_lump_kg,total_yield_kg,
  weather_temp_c,weather_humidity_pct,weather_condition,
  tapping_quality_score,supervisor_verified,verified_by,created_by)
VALUES
(v_pid,v_f1,v_d1,v_s1,CURRENT_DATE-4,
 v_w6,'Rajan Muthu','EMP-003','S2D2','BI-1','COMPLETED',
 CURRENT_DATE-4+INTERVAL'4h40m',CURRENT_DATE-4+INTERVAL'9h05m',
 120,115,5,158.30,2.80,161.10,26.0,80.0,'CLOUDY',7.8,TRUE,'Siti Rohani','system')
RETURNING task_id INTO v_t2;

INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,actual_end_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_cup_lump_kg,total_yield_kg,
  weather_temp_c,weather_humidity_pct,weather_condition,
  tapping_quality_score,supervisor_verified,verified_by,created_by)
VALUES
(v_pid,v_f2,v_d1,v_s2,CURRENT_DATE-3,
 v_w7,'Selvam Krishnan','EMP-003','S2D3','BI-1','COMPLETED',
 CURRENT_DATE-3+INTERVAL'4h30m',CURRENT_DATE-3+INTERVAL'9h15m',
 115,112,3,148.40,2.10,150.50,25.0,85.0,'CLEAR',8.2,TRUE,'Siti Rohani','system')
RETURNING task_id INTO v_t3;

INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,actual_end_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_cup_lump_kg,total_yield_kg,
  weather_temp_c,weather_humidity_pct,weather_condition,
  tapping_quality_score,supervisor_verified,created_by)
VALUES
(v_pid,v_f1,v_d1,v_s1,CURRENT_DATE-2,
 v_w8,'Balakrishnan Nair','EMP-003','S2D2','BI-1','PARTIAL',
 CURRENT_DATE-2+INTERVAL'4h45m',CURRENT_DATE-2+INTERVAL'7h20m',
 120,68,52,89.20,1.50,90.70,27.0,92.0,'LIGHT_RAIN',7.0,FALSE,'system')
RETURNING task_id INTO v_t4;

INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,actual_end_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_cup_lump_kg,total_yield_kg,
  weather_temp_c,weather_humidity_pct,weather_condition,
  tapping_quality_score,supervisor_verified,verified_by,created_by)
VALUES
(v_pid,v_f1,v_d1,v_s1,CURRENT_DATE-1,
 v_w5,'Aminah Hassan','EMP-003','S2D2','BI-1','COMPLETED',
 CURRENT_DATE-1+INTERVAL'4h32m',CURRENT_DATE-1+INTERVAL'8h48m',
 120,120,0,172.80,3.60,176.40,24.5,79.0,'CLEAR',9.2,TRUE,'Siti Rohani','system')
RETURNING task_id INTO v_t5;

INSERT INTO tapping_task (plantation_id,field_id,division_id,schedule_id,task_date,
  tapper_id,tapper_name,assigned_by,tapping_system_code,panel_code,status,
  actual_start_time,total_trees_assigned,trees_tapped,trees_skipped,
  total_latex_kg,total_yield_kg,weather_temp_c,weather_humidity_pct,weather_condition,
  supervisor_verified,created_by)
VALUES
(v_pid,v_f2,v_d1,v_s2,CURRENT_DATE,
 v_w9,'Karthik Subramaniam','EMP-004','S2D3','BI-1','IN_PROGRESS',
 CURRENT_DATE+INTERVAL'4h38m',115,62,0,84.10,84.10,25.5,81.0,'CLEAR',FALSE,'system')
RETURNING task_id INTO v_t6;

-- ============================================================================
-- M3 — TAPPING TASK TREE DETAIL (per-tree NFC scan for task 1)
-- ============================================================================
INSERT INTO tapping_task_tree_detail (task_id,tree_id,tag_uid,scanned_at,
  was_tapped,latex_volume_ml,panel_code,cut_angle_deg,bark_shaving_mm)
VALUES
  (v_t1,v_tree1,'TAG-A1R1-001',CURRENT_DATE-6+INTERVAL'4h40m',TRUE,580,'BI-1',31.5,0.18),
  (v_t1,v_tree2,'TAG-A1R1-002',CURRENT_DATE-6+INTERVAL'4h43m',TRUE,540,'BI-1',30.8,0.19),
  (v_t1,v_tree3,'TAG-A1R1-003',CURRENT_DATE-6+INTERVAL'4h46m',TRUE,610,'BI-1',29.5,0.17),
  (v_t1,v_tree4,'TAG-A1R1-004',CURRENT_DATE-6+INTERVAL'4h49m',TRUE,475,'BI-1',32.1,0.20),
  (v_t1,v_tree5,'TAG-A1R1-005',CURRENT_DATE-6+INTERVAL'4h52m',TRUE,520,'BI-1',30.2,0.18),
  (v_t1,v_tree6,'TAG-A1R2-001',CURRENT_DATE-6+INTERVAL'5h10m',TRUE,590,'BI-1',31.0,0.19),
  (v_t1,v_tree7,'TAG-A1R2-002',CURRENT_DATE-6+INTERVAL'5h13m',TRUE,480,'BI-1',30.5,0.17),
  (v_t1,v_tree8,'TAG-A1R2-003',CURRENT_DATE-6+INTERVAL'5h16m',TRUE,560,'BI-1',31.8,0.20),
  (v_t1,v_tree9,'TAG-A1R2-004',CURRENT_DATE-6+INTERVAL'5h19m',TRUE,530,'BI-1',29.9,0.18),
  (v_t1,v_tree10,'TAG-A1R2-005',CURRENT_DATE-6+INTERVAL'5h22m',FALSE,NULL,'BI-1',NULL,NULL);

-- ============================================================================
-- M3 — LATEX COLLECTION RECORDS (one per completed tapping task)
-- ============================================================================
INSERT INTO latex_collection_record (task_id,plantation_id,field_id,collection_date,
  collection_time,collector_name,latex_grade_code,gross_weight_kg,container_weight_kg,
  net_weight_kg,drc_pct,collection_point_id)
VALUES
  (v_t1,v_pid,v_f1,CURRENT_DATE-6,CURRENT_DATE-6+INTERVAL'9h',
    'Noor Azlina','FIELD_LATEX',171.20,5.70,165.50,32.5,v_cp1)
RETURNING collection_id INTO v_col1;

INSERT INTO latex_collection_record (task_id,plantation_id,field_id,collection_date,
  collection_time,collector_name,latex_grade_code,gross_weight_kg,container_weight_kg,
  net_weight_kg,drc_pct,collection_point_id)
VALUES
  (v_t2,v_pid,v_f1,CURRENT_DATE-4,CURRENT_DATE-4+INTERVAL'9h10m',
    'Noor Azlina','FIELD_LATEX',163.80,5.50,158.30,31.8,v_cp1)
RETURNING collection_id INTO v_col2;

INSERT INTO latex_collection_record (task_id,plantation_id,field_id,collection_date,
  collection_time,collector_name,latex_grade_code,gross_weight_kg,container_weight_kg,
  net_weight_kg,drc_pct,collection_point_id)
VALUES
  (v_t3,v_pid,v_f2,CURRENT_DATE-3,CURRENT_DATE-3+INTERVAL'9h20m',
    'Noor Azlina','FIELD_LATEX',153.90,5.50,148.40,33.1,v_cp2)
RETURNING collection_id INTO v_col3;

-- ============================================================================
-- M3 — LATEX QUALITY TESTS (DRC test per collection record)
-- ============================================================================
INSERT INTO latex_quality_test (collection_id,parameter_code,tested_value,
  unit_of_measure,is_within_spec,test_date,tested_by,test_method,test_location)
VALUES
  (v_col1,'DRC',32.5,'%',TRUE,CURRENT_DATE-6,'Siti Rohani','METROLAC','FIELD'),
  (v_col2,'DRC',31.8,'%',TRUE,CURRENT_DATE-4,'Siti Rohani','METROLAC','FIELD'),
  (v_col3,'DRC',33.1,'%',TRUE,CURRENT_DATE-3,'Siti Rohani','METROLAC','FIELD');

-- ============================================================================
-- M5 — MATERIAL IDs (look up from seeded master data)
-- ============================================================================
SELECT material_id INTO v_m_npk FROM material_master WHERE material_code = 'NPK_12_14_12';
SELECT material_id INTO v_m_gly FROM material_master WHERE material_code = 'GLYPHOSATE';
SELECT material_id INTO v_m_eth FROM material_master WHERE material_code = 'ETHEPHON_2.5';

-- ============================================================================
-- M5 — DAILY WORK PLANS
-- ============================================================================
INSERT INTO daily_work_plan (plantation_id,division_id,plan_date,plan_name,
  planned_by,status,total_activities_planned,total_activities_completed,
  total_workers_deployed,completion_rate_pct,weather_forecast,created_by)
VALUES (v_pid,v_d1,CURRENT_DATE-5,'Division A — Fertilizer Application Day',
  v_w3,'COMPLETED',2,2,4,100.0,'Cloudy, suitable for field work','system')
RETURNING plan_id INTO v_pl1;

INSERT INTO daily_work_plan (plantation_id,division_id,plan_date,plan_name,
  planned_by,status,total_activities_planned,total_activities_completed,
  total_workers_deployed,completion_rate_pct,weather_forecast,created_by)
VALUES (v_pid,v_d2,CURRENT_DATE-2,'Division B — Weed & Pest Control',
  v_w4,'IN_PROGRESS',2,1,3,50.0,'Partly cloudy','system')
RETURNING plan_id INTO v_pl2;

INSERT INTO daily_work_plan (plantation_id,division_id,plan_date,plan_name,
  planned_by,status,total_activities_planned,total_activities_completed,
  total_workers_deployed,completion_rate_pct,weather_forecast,created_by)
VALUES (v_pid,v_d1,CURRENT_DATE,'Division A — Field Monitoring & Stimulant',
  v_w3,'IN_PROGRESS',2,0,3,0.0,'Clear, excellent field conditions','system')
RETURNING plan_id INTO v_pl3;

-- ============================================================================
-- M5 — DAILY ACTIVITIES
-- ============================================================================
INSERT INTO daily_activity (plan_id,plantation_id,field_id,division_id,activity_date,
  activity_type_code,category_code,activity_description,assigned_worker_id,assigned_gang_id,
  status,priority_code,planned_start_time,planned_end_time,
  actual_start_time,actual_end_time,actual_duration_hours,
  workers_deployed,target_quantity,actual_quantity,quantity_unit,completion_pct,
  start_gps_lat,start_gps_lon,
  supervisor_id,supervisor_verified,verified_at,created_by)
VALUES
(v_pl1,v_pid,v_f1,v_d1,CURRENT_DATE-5,
  'MANURE_INORGANIC','MANURING','NPK 12:14:12 Application — Block A1, 400kg/ha rate',
  v_w5,v_g1,'COMPLETED','MEDIUM','07:00','14:00',
  CURRENT_DATE-5+INTERVAL'7h05m',CURRENT_DATE-5+INTERVAL'13h45m',6.67,
  2,26.12,26.12,'HECTARE',100.0,4.7701,101.1080,
  v_w3,TRUE,CURRENT_DATE-5+INTERVAL'14h','system')
RETURNING activity_id INTO v_a1;

INSERT INTO daily_activity (plan_id,plantation_id,field_id,division_id,activity_date,
  activity_type_code,category_code,activity_description,assigned_worker_id,assigned_gang_id,
  status,priority_code,planned_start_time,planned_end_time,
  actual_start_time,actual_end_time,actual_duration_hours,
  workers_deployed,target_quantity,actual_quantity,quantity_unit,completion_pct,
  start_gps_lat,start_gps_lon,
  supervisor_id,supervisor_verified,verified_at,created_by)
VALUES
(v_pl1,v_pid,v_f2,v_d1,CURRENT_DATE-5,
  'MANURE_INORGANIC','MANURING','NPK 12:14:12 Application — Block A2, 400kg/ha rate',
  v_w7,v_g1,'COMPLETED','MEDIUM','07:00','15:00',
  CURRENT_DATE-5+INTERVAL'7h10m',CURRENT_DATE-5+INTERVAL'14h55m',7.75,
  2,23.48,23.48,'HECTARE',100.0,4.7730,101.1110,
  v_w3,TRUE,CURRENT_DATE-5+INTERVAL'15h10m','system')
RETURNING activity_id INTO v_a2;

INSERT INTO daily_activity (plan_id,plantation_id,field_id,division_id,activity_date,
  activity_type_code,category_code,activity_description,assigned_worker_id,assigned_gang_id,
  status,priority_code,planned_start_time,planned_end_time,
  actual_start_time,actual_end_time,actual_duration_hours,
  workers_deployed,target_quantity,actual_quantity,quantity_unit,completion_pct,
  start_gps_lat,start_gps_lon,
  supervisor_id,supervisor_verified,created_by)
VALUES
(v_pl2,v_pid,v_f3,v_d2,CURRENT_DATE-2,
  'CIRCLE_WEEDING','FIELD_MAINT','Circle Weeding Around Trees — Block B1, Rows 1-8',
  v_w9,v_g2,'IN_PROGRESS','HIGH','07:30',NULL,
  CURRENT_DATE-2+INTERVAL'7h35m',NULL,NULL,
  1,480,220,'TREE',45.8,4.7580,101.1200,
  v_w4,FALSE,'system')
RETURNING activity_id INTO v_a3;

INSERT INTO daily_activity (plan_id,plantation_id,field_id,division_id,activity_date,
  activity_type_code,category_code,activity_description,assigned_worker_id,assigned_gang_id,
  status,priority_code,planned_start_time,planned_end_time,
  actual_start_time,actual_end_time,actual_duration_hours,
  workers_deployed,target_quantity,actual_quantity,quantity_unit,completion_pct,
  start_gps_lat,start_gps_lon,
  supervisor_id,supervisor_verified,verified_at,created_by)
VALUES
(v_pl2,v_pid,v_f4,v_d2,CURRENT_DATE-2,
  'SPRAY_HERBICIDE','SPRAYING','Inter-row Herbicide Spray — Block B2 (Glyphosate)',
  v_w8,v_g2,'COMPLETED','MEDIUM','08:00','13:00',
  CURRENT_DATE-2+INTERVAL'8h05m',CURRENT_DATE-2+INTERVAL'12h50m',4.75,
  1,42.1,42.1,'HECTARE',100.0,4.7550,101.1230,
  v_w4,TRUE,CURRENT_DATE-2+INTERVAL'13h30m','system')
RETURNING activity_id INTO v_a4;

INSERT INTO daily_activity (plan_id,plantation_id,field_id,division_id,activity_date,
  activity_type_code,category_code,activity_description,assigned_worker_id,assigned_gang_id,
  status,priority_code,planned_start_time,planned_end_time,
  actual_start_time,actual_end_time,actual_duration_hours,
  workers_deployed,target_quantity,actual_quantity,quantity_unit,completion_pct,
  start_gps_lat,start_gps_lon,
  supervisor_id,supervisor_verified,created_by)
VALUES
(v_pl3,v_pid,v_f1,v_d1,CURRENT_DATE,
  'ETHEPHON_APP','STIMULATION','Ethephon Stimulant Application — Block A1, Panel BI-2 trees',
  v_w6,v_g1,'IN_PROGRESS','HIGH','07:00',NULL,
  CURRENT_DATE+INTERVAL'7h05m',NULL,NULL,
  2,120,45,'TREE',37.5,4.7701,101.1080,
  v_w3,FALSE,'system')
RETURNING activity_id INTO v_a5;

-- ============================================================================
-- M5 — ACTIVITY WORKER ASSIGNMENTS (multi-worker activities)
-- ============================================================================
INSERT INTO activity_worker_assignment (activity_id,worker_id,role_in_activity,
  check_in_time,check_out_time,hours_worked,individual_quantity,quantity_unit)
VALUES
  -- Activity 1 (Fertilizer A1): Aminah (lead) + Noor (helper)
  (v_a1,v_w5,'LEAD',CURRENT_DATE-5+INTERVAL'7h05m',CURRENT_DATE-5+INTERVAL'13h45m',6.67,16.0,'HECTARE'),
  (v_a1,v_w10,'WORKER',CURRENT_DATE-5+INTERVAL'7h10m',CURRENT_DATE-5+INTERVAL'13h40m',6.50,10.12,'HECTARE'),
  -- Activity 2 (Fertilizer A2): Selvam (lead) + Rajan (helper)
  (v_a2,v_w7,'LEAD',CURRENT_DATE-5+INTERVAL'7h10m',CURRENT_DATE-5+INTERVAL'14h55m',7.75,12.0,'HECTARE'),
  (v_a2,v_w6,'WORKER',CURRENT_DATE-5+INTERVAL'7h15m',CURRENT_DATE-5+INTERVAL'14h50m',7.58,11.48,'HECTARE'),
  -- Activity 4 (Herbicide): Balakrishnan (solo)
  (v_a4,v_w8,'LEAD',CURRENT_DATE-2+INTERVAL'8h05m',CURRENT_DATE-2+INTERVAL'12h50m',4.75,42.1,'HECTARE'),
  -- Activity 5 (Ethephon today): Rajan (lead) + Selvam (worker)
  (v_a5,v_w6,'LEAD',CURRENT_DATE+INTERVAL'7h05m',NULL,NULL,28.0,'TREE'),
  (v_a5,v_w7,'WORKER',CURRENT_DATE+INTERVAL'7h10m',NULL,NULL,17.0,'TREE');

-- ============================================================================
-- M5 — MATERIAL USAGE (chemicals & fertilizers consumed)
-- ============================================================================
INSERT INTO activity_material_usage (activity_id,material_id,planned_quantity,
  actual_quantity,quantity_unit,unit_cost,total_cost,currency_code,
  application_rate,batch_number)
VALUES
  -- NPK for A1 fertilizer (400kg/ha × 26.12ha = 10,448kg)
  (v_a1,v_m_npk,10448.0,10320.0,'KG',1.80,18576.00,'MYR','400kg/ha','NPK-2026-B001'),
  -- NPK for A2 fertilizer (400kg/ha × 23.48ha = 9,392kg)
  (v_a2,v_m_npk,9392.0,9280.0,'KG',1.80,16704.00,'MYR','400kg/ha','NPK-2026-B001'),
  -- Glyphosate for B2 herbicide (3L/ha × 42.1ha = 126.3L)
  (v_a4,v_m_gly,126.3,124.0,'L',18.50,2294.00,'MYR','3L/ha','GLY-2026-A012'),
  -- Ethephon stimulant (1.5ml/tree × 120 trees = 180ml)
  (v_a5,v_m_eth,180.0,67.5,'ML',0.45,30.38,'MYR','1.5ml/tree','ETH-2026-C005');

-- ============================================================================
-- M5 — SUPERVISOR INSPECTIONS
-- ============================================================================
INSERT INTO supervisor_inspection (plantation_id,division_id,field_id,activity_id,
  inspector_id,inspection_date,inspection_time,inspection_type,overall_rating,
  gps_latitude,gps_longitude,findings,corrective_actions,follow_up_date)
VALUES
(v_pid,v_d1,v_f1,v_a1,v_w3,CURRENT_DATE-5,CURRENT_DATE-5+INTERVAL'10h',
  'POST_ACTIVITY',4,4.7701,101.1080,
  'NPK application completed as per plan. Fertilizer distribution uniform. '
  'Two rows near drainage had slightly low coverage.',
  'Re-apply 5kg NPK to drainage-side rows during next visit.',
  CURRENT_DATE+7)
RETURNING inspection_id INTO v_insp1;

INSERT INTO supervisor_inspection (plantation_id,division_id,field_id,activity_id,
  inspector_id,inspection_date,inspection_time,inspection_type,overall_rating,
  gps_latitude,gps_longitude,findings,corrective_actions,follow_up_date)
VALUES
(v_pid,v_d1,v_f1,NULL,v_w3,CURRENT_DATE-1,CURRENT_DATE-1+INTERVAL'9h',
  'QUALITY_AUDIT',5,4.7710,101.1080,
  'Tapping quality excellent (tapping_task '||v_t5||'). All cuts within 30-degree tolerance. '
  'Bark consumption well within annual budget. Aminah performed at top level.',
  NULL,NULL)
RETURNING inspection_id INTO v_insp2;

-- ============================================================================
-- M5 — INSPECTION CHECKLIST RESPONSES
-- ============================================================================
INSERT INTO inspection_checklist_response (inspection_id,item_code,yes_no_value,
  rating_value)
VALUES
  -- Post-activity inspection for fertilizer (inspection 1)
  (v_insp1,'MANURE_APPLIED',TRUE,NULL),
  (v_insp1,'MANURE_PLACEMENT',NULL,4),
  (v_insp1,'WEED_FREE',NULL,3),
  (v_insp1,'DRAIN_CLEAR',NULL,4),
  -- Quality audit for tapping (inspection 2)
  (v_insp2,'CUT_ANGLE_OK',TRUE,NULL),
  (v_insp2,'CUT_DEPTH_OK',TRUE,NULL),
  (v_insp2,'BARK_CONSUMPTION_OK',TRUE,NULL),
  (v_insp2,'PANEL_MARKING_OK',TRUE,NULL),
  (v_insp2,'CUP_POSITION_OK',TRUE,NULL);

-- ============================================================================
-- M6 — ATTENDANCE LOCATIONS
-- ============================================================================
INSERT INTO attendance_location (plantation_id,division_id,location_code,location_name,
  location_type,geofence_radius_m,gps_latitude,gps_longitude,status)
VALUES (v_pid,v_d1,'MUSTER-A','Division A Muster Point','MUSTER_POINT',
  150.0,4.7695,101.1075,'ACTIVE')
RETURNING location_id INTO v_al1;

INSERT INTO attendance_location (plantation_id,division_id,location_code,location_name,
  location_type,geofence_radius_m,gps_latitude,gps_longitude,status)
VALUES (v_pid,v_d2,'MUSTER-B','Division B Muster Point','MUSTER_POINT',
  150.0,4.7560,101.1190,'ACTIVE')
RETURNING location_id INTO v_al2;

INSERT INTO attendance_location (plantation_id,location_code,location_name,
  location_type,geofence_radius_m,gps_latitude,gps_longitude,status)
VALUES (v_pid,'GATE-MAIN','Main Estate Gate','GATE',50.0,4.7650,101.1050,'ACTIVE')
RETURNING location_id INTO v_al3;

-- ============================================================================
-- M6 — SHIFT ROSTERS (7 days, 9 workers)
-- ============================================================================
INSERT INTO worker_shift_roster (worker_id,plantation_id,roster_date,shift_code,
  is_rest_day,assigned_field_id,assigned_gang_id,created_by)
SELECT wid, v_pid, rdate,
  CASE WHEN cat IN ('TAPPER','TAPPER_SENIOR','FIELD_COLLECTOR') THEN 'TAPPING_AM'
       WHEN cat IN ('MANAGER','ASST_MANAGER') THEN 'OFFICE'
       ELSE 'FIELD_DAY' END,
  (EXTRACT(DOW FROM rdate) IN (0,6)),  -- rest on weekend (Sun=0, Sat=6)
  fld, gng, 'system'
FROM (VALUES
  (v_w2,NULL,NULL,'ASST_MANAGER'),
  (v_w3,v_f1,v_g1,'CONDUCTOR'),
  (v_w4,v_f3,v_g2,'CONDUCTOR'),
  (v_w5,v_f1,v_g1,'TAPPER_SENIOR'),
  (v_w6,v_f1,v_g1,'TAPPER'),
  (v_w7,v_f2,v_g1,'TAPPER'),
  (v_w8,v_f3,v_g2,'TAPPER_SENIOR'),
  (v_w9,v_f4,v_g2,'TAPPER'),
  (v_w10,v_f1,v_g1,'FIELD_COLLECTOR')
) AS wlist(wid,fld,gng,cat)
CROSS JOIN generate_series(CURRENT_DATE-6, CURRENT_DATE+1, '1 day'::interval) AS rdate;

-- ============================================================================
-- M6 — DAILY ATTENDANCE (last 6 completed days)
-- ============================================================================
INSERT INTO daily_attendance (worker_id,plantation_id,division_id,attendance_date,
  shift_code,attendance_status,check_in_time,check_out_time,check_in_method,
  check_in_location_id,is_late,primary_activity_id,created_by)
SELECT wid, v_pid, div_id, adate,
  CASE WHEN cat IN ('TAPPER','TAPPER_SENIOR','FIELD_COLLECTOR') THEN 'TAPPING_AM'
       WHEN cat IN ('ASST_MANAGER') THEN 'OFFICE'
       ELSE 'FIELD_DAY' END,
  CASE WHEN wid=v_w9 AND adate::date=CURRENT_DATE-2 THEN 'ABSENT_UA'
       WHEN wid=v_w7 AND adate::date=CURRENT_DATE-1 THEN 'ABSENT_SL'
       ELSE 'PRESENT' END,
  CASE WHEN (wid=v_w9 AND adate::date=CURRENT_DATE-2)
            OR (wid=v_w7 AND adate::date=CURRENT_DATE-1) THEN NULL
       WHEN cat IN ('TAPPER','TAPPER_SENIOR') THEN (adate+INTERVAL'4h35m')::timestamptz
       WHEN cat='FIELD_COLLECTOR'             THEN (adate+INTERVAL'5h00m')::timestamptz
       ELSE                                        (adate+INTERVAL'7h10m')::timestamptz END,
  CASE WHEN (wid=v_w9 AND adate::date=CURRENT_DATE-2)
            OR (wid=v_w7 AND adate::date=CURRENT_DATE-1) THEN NULL
       WHEN cat IN ('TAPPER','TAPPER_SENIOR') THEN (adate+INTERVAL'12h15m')::timestamptz
       WHEN cat='FIELD_COLLECTOR'             THEN (adate+INTERVAL'13h30m')::timestamptz
       ELSE                                        (adate+INTERVAL'17h00m')::timestamptz END,
  'NFC_BADGE',
  CASE WHEN div_id=v_d1 THEN v_al1 ELSE v_al2 END,
  FALSE,
  NULL,
  'system'
FROM (VALUES
  (v_w2,v_d1,'ASST_MANAGER'),(v_w3,v_d1,'CONDUCTOR'),(v_w4,v_d2,'CONDUCTOR'),
  (v_w5,v_d1,'TAPPER_SENIOR'),(v_w6,v_d1,'TAPPER'),(v_w7,v_d1,'TAPPER'),
  (v_w8,v_d2,'TAPPER_SENIOR'),(v_w9,v_d2,'TAPPER'),(v_w10,v_d1,'FIELD_COLLECTOR')
) AS wlist(wid,div_id,cat)
CROSS JOIN generate_series(CURRENT_DATE-6, CURRENT_DATE-1, '1 day'::interval) AS adate;

-- Capture one attendance ID for the regularization example
SELECT attendance_id INTO v_att1
FROM daily_attendance
WHERE worker_id=v_w9 AND attendance_date=CURRENT_DATE-2
LIMIT 1;

-- ============================================================================
-- M6 — ATTENDANCE SCAN LOG (raw check-in events)
-- ============================================================================
INSERT INTO attendance_scan_log (worker_id,plantation_id,scan_timestamp,
  scan_type,method_code,location_id,device_id,nfc_badge_uid,is_verified)
SELECT wid, v_pid, (adate+INTERVAL'4h35m')::timestamptz,
  'IN','NFC_BADGE',
  CASE WHEN div_id=v_d1 THEN v_al1 ELSE v_al2 END,
  'READER-01', badge, TRUE
FROM (VALUES
  (v_w5,v_d1,'NFC-005'),(v_w6,v_d1,'NFC-006'),(v_w7,v_d1,'NFC-007'),
  (v_w8,v_d2,'NFC-008'),(v_w9,v_d2,'NFC-009'),(v_w10,v_d1,'NFC-010')
) AS wlist(wid,div_id,badge)
CROSS JOIN generate_series(CURRENT_DATE-6, CURRENT_DATE-1, '1 day'::interval) AS adate
WHERE NOT (wid=v_w9 AND adate::date=CURRENT_DATE-2)
  AND NOT (wid=v_w7 AND adate::date=CURRENT_DATE-1);

-- Check-OUT events for tappers
INSERT INTO attendance_scan_log (worker_id,plantation_id,scan_timestamp,
  scan_type,method_code,location_id,device_id,nfc_badge_uid,is_verified)
SELECT wid, v_pid, (adate+INTERVAL'12h15m')::timestamptz,
  'OUT','NFC_BADGE',
  CASE WHEN div_id=v_d1 THEN v_al1 ELSE v_al2 END,
  'READER-01', badge, TRUE
FROM (VALUES
  (v_w5,v_d1,'NFC-005'),(v_w6,v_d1,'NFC-006'),(v_w8,v_d2,'NFC-008')
) AS wlist(wid,div_id,badge)
CROSS JOIN generate_series(CURRENT_DATE-6, CURRENT_DATE-1, '1 day'::interval) AS adate;

-- ============================================================================
-- M6 — ATTENDANCE REGULARIZATION
-- (Karthik's unexplained absence — submitted for correction)
-- ============================================================================
INSERT INTO attendance_regularization (attendance_id,original_status,corrected_status,
  reason_code,justification,requested_by,approval_status)
VALUES
  (v_att1,'ABSENT_UA','ABSENT_CL','MEDICAL_EMERGENCY',
    'Worker was attending to family emergency. Informal verbal notice was given to supervisor.',
    v_w4,'PENDING');

-- ============================================================================
-- M6 — OVERTIME (stored on daily_attendance row)
-- ============================================================================
UPDATE daily_attendance
SET has_overtime        = TRUE,
    overtime_hours      = 1.5,
    overtime_type_code  = 'OT_NORMAL',
    overtime_approved   = TRUE,
    overtime_approved_by = v_w3,
    remarks             = 'Extended tapping to complete daily target after weather delay'
WHERE worker_id = v_w5
  AND attendance_date = CURRENT_DATE-4;

-- ============================================================================
-- M6 — MONTHLY ATTENDANCE SUMMARY (June 2026)
-- ============================================================================
INSERT INTO monthly_attendance_summary (worker_id,plantation_id,summary_month,
  summary_year,calendar_days,working_days,days_present,days_late,days_absent_paid,
  days_absent_unpaid,days_holiday,days_rest,days_on_leave,
  total_work_hours,total_overtime_hours,payable_days,eligible_for_attendance_bonus)
VALUES
  (v_w5,v_pid,6,2026,30,26,26,0,0,0,1,3,0,202.8,3.0,26,TRUE),
  (v_w6,v_pid,6,2026,30,26,25,1,0,0,1,3,0,194.5,0.0,25,FALSE),
  (v_w7,v_pid,6,2026,30,26,24,0,2,0,1,3,2,186.0,0.0,26,FALSE),
  (v_w8,v_pid,6,2026,30,26,26,0,0,0,1,3,0,202.8,4.5,26,TRUE),
  (v_w9,v_pid,6,2026,30,26,25,0,1,0,1,3,1,192.0,0.0,26,FALSE),
  (v_w10,v_pid,6,2026,30,26,26,0,0,0,1,3,0,202.8,0.0,26,TRUE);

-- ============================================================================
-- Done
-- ============================================================================
RAISE NOTICE '=========================================================';
RAISE NOTICE 'RPMS FULL DEMO SEED COMPLETED SUCCESSFULLY';
RAISE NOTICE '=========================================================';
RAISE NOTICE 'plantation_id=%, division_a=%, division_b=%', v_pid, v_d1, v_d2;
RAISE NOTICE 'fields: A1=%, A2=%, B1=%, B2=%', v_f1, v_f2, v_f3, v_f4;
RAISE NOTICE 'workers: w1=%(Mgr) w2=%(AMgr) w3=%(Cond) w4=%(Cond) w5=%(Sr.Tap) w6=%(Tap) w7=%(Tap) w8=%(Sr.Tap) w9=%(Tap) w10=%(Collector)',
  v_w1,v_w2,v_w3,v_w4,v_w5,v_w6,v_w7,v_w8,v_w9,v_w10;
RAISE NOTICE 'gangs: Alpha=%, Beta=%', v_g1, v_g2;
RAISE NOTICE 'trees: 15 trees seeded (% to %)', v_tree1, v_tree15;
RAISE NOTICE 'tasks: % to % (6 tapping tasks)', v_t1, v_t6;
RAISE NOTICE '---------------------------------------------------------';
RAISE NOTICE 'MODULE COVERAGE:';
RAISE NOTICE '  M1 plantation, division, field, clone_master';
RAISE NOTICE '  M2 tree, tree_row, tree_tag, tree_growth_measurement,';
RAISE NOTICE '     tree_panel_history, tree_health_inspection,';
RAISE NOTICE '     tree_disease_incident, tree_treatment_record,';
RAISE NOTICE '     tree_census_summary';
RAISE NOTICE '  M3 collection_point, iot_device, tapping_schedule,';
RAISE NOTICE '     tapping_task (6), tapping_task_tree_detail,';
RAISE NOTICE '     latex_collection_record (3), latex_quality_test (3),';
RAISE NOTICE '     weather_observation (7 days)';
RAISE NOTICE '  M4 worker (10), gang (2), worker_skill (33 entries),';
RAISE NOTICE '     worker_next_of_kin, worker_document, worker_leave,';
RAISE NOTICE '     worker_leave_balance, worker_field_assignment,';
RAISE NOTICE '     worker_training, worker_pay_structure,';
RAISE NOTICE '     worker_safety_incident, worker_status_change_log';
RAISE NOTICE '  M5 daily_work_plan (3), daily_activity (5),';
RAISE NOTICE '     activity_worker_assignment (7), activity_material_usage (4),';
RAISE NOTICE '     supervisor_inspection (2),';
RAISE NOTICE '     inspection_checklist_response (9)';
RAISE NOTICE '  M6 attendance_location (3), worker_shift_roster (63),';
RAISE NOTICE '     daily_attendance (54), attendance_scan_log (54+),';
RAISE NOTICE '     attendance_regularization (1), overtime_record (1),';
RAISE NOTICE '     monthly_attendance_summary (6 workers, Jun 2026)';
RAISE NOTICE '=========================================================';

END $$;

