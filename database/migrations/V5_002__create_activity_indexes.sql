-- ============================================================================
-- V5_002 — Module 5 (Daily Activity Monitoring) — CREATE INDEX statements
-- Source: database/module-5-daily-activity/daily_activity_monitoring_ddl.sql
-- ============================================================================

CREATE INDEX idx_plan_plantation ON daily_work_plan(plantation_id);
CREATE INDEX idx_plan_date ON daily_work_plan(plan_date);
CREATE INDEX idx_plan_status ON daily_work_plan(status);

CREATE INDEX idx_activity_plan ON daily_activity(plan_id);
CREATE INDEX idx_activity_plantation ON daily_activity(plantation_id);
CREATE INDEX idx_activity_field ON daily_activity(field_id);
CREATE INDEX idx_activity_date ON daily_activity(activity_date);
CREATE INDEX idx_activity_type ON daily_activity(activity_type_code);
CREATE INDEX idx_activity_category ON daily_activity(category_code);
CREATE INDEX idx_activity_worker ON daily_activity(assigned_worker_id);
CREATE INDEX idx_activity_gang ON daily_activity(assigned_gang_id);
CREATE INDEX idx_activity_status ON daily_activity(status);
CREATE INDEX idx_activity_priority ON daily_activity(priority_code);
CREATE INDEX idx_activity_supervisor ON daily_activity(supervisor_id);
CREATE INDEX idx_activity_date_status ON daily_activity(activity_date, status);
CREATE INDEX idx_activity_gps ON daily_activity USING GIST(start_gps_point);
CREATE INDEX idx_activity_route ON daily_activity USING GIST(gps_route);
CREATE INDEX idx_activity_tapping ON daily_activity(tapping_task_id) WHERE tapping_task_id IS NOT NULL;
CREATE INDEX idx_activity_anomaly ON daily_activity(ai_anomaly_flag) WHERE ai_anomaly_flag = TRUE;

CREATE INDEX idx_awa_activity ON activity_worker_assignment(activity_id);
CREATE INDEX idx_awa_worker ON activity_worker_assignment(worker_id);

CREATE INDEX idx_amu_activity ON activity_material_usage(activity_id);
CREATE INDEX idx_amu_material ON activity_material_usage(material_id);

CREATE INDEX idx_photo_activity ON activity_photo_evidence(activity_id);
CREATE INDEX idx_photo_type ON activity_photo_evidence(photo_type);
CREATE INDEX idx_photo_gps ON activity_photo_evidence USING GIST(gps_point);
CREATE INDEX idx_photo_ai ON activity_photo_evidence(ai_analyzed) WHERE ai_analyzed = TRUE;

CREATE INDEX idx_insp_plantation ON supervisor_inspection(plantation_id);
CREATE INDEX idx_insp_field ON supervisor_inspection(field_id);
CREATE INDEX idx_insp_activity ON supervisor_inspection(activity_id);
CREATE INDEX idx_insp_inspector ON supervisor_inspection(inspector_id);
CREATE INDEX idx_insp_date ON supervisor_inspection(inspection_date);
CREATE INDEX idx_insp_type ON supervisor_inspection(inspection_type);
CREATE INDEX idx_insp_gps ON supervisor_inspection USING GIST(gps_point);

CREATE INDEX idx_icr_inspection ON inspection_checklist_response(inspection_id);
CREATE INDEX idx_icr_item ON inspection_checklist_response(item_code);

CREATE INDEX idx_summary_plantation ON daily_activity_summary(plantation_id);
CREATE INDEX idx_summary_date ON daily_activity_summary(summary_date);
