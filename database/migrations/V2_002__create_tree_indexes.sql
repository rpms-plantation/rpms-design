-- ============================================================================
-- V2_002 — Module 2 (Tree Records & Tracking) — CREATE INDEX statements
-- Source: database/module-2-tree-records/tree_records_tracking_ddl.sql
-- ============================================================================

CREATE INDEX idx_tree_row_field ON tree_row(field_id);
CREATE INDEX idx_tree_row_geom ON tree_row USING GIST(row_line);

CREATE INDEX idx_tree_plantation ON tree(plantation_id);
CREATE INDEX idx_tree_field ON tree(field_id);
CREATE INDEX idx_tree_row ON tree(row_id);
CREATE INDEX idx_tree_clone ON tree(clone_id);
CREATE INDEX idx_tree_status ON tree(tree_status);
CREATE INDEX idx_tree_health ON tree(health_rating);
CREATE INDEX idx_tree_gps ON tree USING GIST(gps_point);
CREATE INDEX idx_tree_planting_year ON tree(planting_year);
CREATE INDEX idx_tree_tapping_panel ON tree(current_panel) WHERE current_panel IS NOT NULL;

CREATE INDEX idx_tree_tag_tree ON tree_tag(tree_id);
CREATE INDEX idx_tree_tag_uid ON tree_tag(tag_uid);
CREATE INDEX idx_tree_tag_active ON tree_tag(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_growth_tree ON tree_growth_measurement(tree_id);
CREATE INDEX idx_growth_param ON tree_growth_measurement(parameter_code);
CREATE INDEX idx_growth_date ON tree_growth_measurement(measurement_date);
CREATE INDEX idx_growth_tree_date ON tree_growth_measurement(tree_id, measurement_date);

CREATE INDEX idx_panel_tree ON tree_panel_history(tree_id);
CREATE INDEX idx_panel_status ON tree_panel_history(status);
CREATE INDEX idx_panel_opened ON tree_panel_history(opened_date);

CREATE INDEX idx_inspection_tree ON tree_health_inspection(tree_id);
CREATE INDEX idx_inspection_date ON tree_health_inspection(inspection_date);
CREATE INDEX idx_inspection_disease ON tree_health_inspection(disease_detected) WHERE disease_detected = TRUE;
CREATE INDEX idx_inspection_rating ON tree_health_inspection(health_rating);

CREATE INDEX idx_disease_inc_tree ON tree_disease_incident(tree_id);
CREATE INDEX idx_disease_inc_disease ON tree_disease_incident(disease_id);
CREATE INDEX idx_disease_inc_date ON tree_disease_incident(detected_date);
CREATE INDEX idx_disease_inc_status ON tree_disease_incident(status);
CREATE INDEX idx_disease_inc_severity ON tree_disease_incident(severity);

CREATE INDEX idx_treatment_tree ON tree_treatment_record(tree_id);
CREATE INDEX idx_treatment_incident ON tree_treatment_record(incident_id);
CREATE INDEX idx_treatment_date ON tree_treatment_record(treatment_date);
CREATE INDEX idx_treatment_type ON tree_treatment_record(treatment_code);
CREATE INDEX idx_treatment_outcome ON tree_treatment_record(outcome);

CREATE INDEX idx_mortality_tree ON tree_mortality_record(tree_id);
CREATE INDEX idx_mortality_cause ON tree_mortality_record(cause_code);
CREATE INDEX idx_mortality_date ON tree_mortality_record(mortality_date);

CREATE INDEX idx_status_log_tree ON tree_status_change_log(tree_id);
CREATE INDEX idx_status_log_date ON tree_status_change_log(change_date);
CREATE INDEX idx_status_log_to ON tree_status_change_log(to_status);

CREATE INDEX idx_census_field ON tree_census_summary(field_id);
CREATE INDEX idx_census_year ON tree_census_summary(census_year);
