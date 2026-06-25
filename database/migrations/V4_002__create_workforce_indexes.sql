-- ============================================================================
-- V4_002 — Module 4 (Workforce Management) — CREATE INDEX statements
-- Source: database/module-4-workforce/workforce_management_ddl.sql
-- ============================================================================

CREATE INDEX idx_worker_plantation ON worker(plantation_id);
CREATE INDEX idx_worker_division ON worker(division_id);
CREATE INDEX idx_worker_category ON worker(category_code);
CREATE INDEX idx_worker_status ON worker(worker_status);
CREATE INDEX idx_worker_emp_type ON worker(employment_type_code);
CREATE INDEX idx_worker_field ON worker(primary_field_id);
CREATE INDEX idx_worker_reports_to ON worker(reports_to_id);
CREATE INDEX idx_worker_hire_date ON worker(hire_date);
CREATE INDEX idx_worker_name ON worker(full_name);
CREATE INDEX idx_worker_biometric ON worker(biometric_id) WHERE biometric_id IS NOT NULL;
CREATE INDEX idx_worker_nfc ON worker(nfc_badge_uid) WHERE nfc_badge_uid IS NOT NULL;

CREATE INDEX idx_gang_plantation ON gang(plantation_id);
CREATE INDEX idx_gang_field ON gang(primary_field_id);
CREATE INDEX idx_gang_leader ON gang(leader_worker_id);

CREATE INDEX idx_ws_worker ON worker_skill(worker_id);
CREATE INDEX idx_ws_skill ON worker_skill(skill_code);
CREATE INDEX idx_ws_cert_expiry ON worker_skill(certification_expiry) WHERE is_certified = TRUE;

CREATE INDEX idx_wfa_worker ON worker_field_assignment(worker_id);
CREATE INDEX idx_wfa_field ON worker_field_assignment(field_id);
CREATE INDEX idx_wfa_gang ON worker_field_assignment(gang_id);
CREATE INDEX idx_wfa_dates ON worker_field_assignment(effective_from, effective_to);

CREATE INDEX idx_wscl_worker ON worker_status_change_log(worker_id);
CREATE INDEX idx_wscl_date ON worker_status_change_log(change_date);

CREATE INDEX idx_nok_worker ON worker_next_of_kin(worker_id);
CREATE INDEX idx_nok_emergency ON worker_next_of_kin(is_emergency_contact) WHERE is_emergency_contact = TRUE;

CREATE INDEX idx_doc_worker ON worker_document(worker_id);
CREATE INDEX idx_doc_type ON worker_document(doc_type_code);
CREATE INDEX idx_doc_expiry ON worker_document(expiry_date) WHERE status = 'ACTIVE';

CREATE INDEX idx_leave_worker ON worker_leave(worker_id);
CREATE INDEX idx_leave_type ON worker_leave(leave_type_code);
CREATE INDEX idx_leave_dates ON worker_leave(leave_start_date, leave_end_date);
CREATE INDEX idx_leave_status ON worker_leave(approval_status);

CREATE INDEX idx_lb_worker ON worker_leave_balance(worker_id);
CREATE INDEX idx_lb_year ON worker_leave_balance(balance_year);

CREATE INDEX idx_wt_worker ON worker_training(worker_id);
CREATE INDEX idx_wt_type ON worker_training(training_type_code);
CREATE INDEX idx_wt_dates ON worker_training(start_date, end_date);
CREATE INDEX idx_wt_cert_expiry ON worker_training(certificate_expiry) WHERE certificate_expiry IS NOT NULL;

CREATE INDEX idx_wps_worker ON worker_pay_structure(worker_id);
CREATE INDEX idx_wps_component ON worker_pay_structure(component_code);
CREATE INDEX idx_wps_dates ON worker_pay_structure(effective_from, effective_to);

CREATE INDEX idx_safety_worker ON worker_safety_incident(worker_id);
CREATE INDEX idx_safety_plantation ON worker_safety_incident(plantation_id);
CREATE INDEX idx_safety_date ON worker_safety_incident(incident_date);
CREATE INDEX idx_safety_type ON worker_safety_incident(incident_type);
CREATE INDEX idx_safety_severity ON worker_safety_incident(severity);