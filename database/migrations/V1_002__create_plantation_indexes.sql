-- ============================================================================
-- V1_002 — Module 1 (Plantation Field Records) — CREATE INDEX statements
-- Source: database/module-1-field-records/plantation_field_records_ddl.sql
-- ============================================================================

CREATE INDEX idx_plantation_region ON plantation(region, district);
CREATE INDEX idx_plantation_status ON plantation(status);
CREATE INDEX idx_plantation_gps ON plantation USING GIST(gps_point);
CREATE INDEX idx_plantation_boundary ON plantation USING GIST(boundary_polygon);

CREATE INDEX idx_land_use_plantation ON plantation_land_use(plantation_id);

CREATE INDEX idx_field_plantation ON field(plantation_id);
CREATE INDEX idx_field_category ON field(field_category);
CREATE INDEX idx_field_clone ON field(clone_id);
CREATE INDEX idx_field_planting ON field(planting_year, planting_month);
CREATE INDEX idx_field_boundary ON field USING GIST(field_boundary);
CREATE INDEX idx_field_status ON field(status);

CREATE INDEX idx_lifecycle_field ON field_lifecycle_history(field_id);
CREATE INDEX idx_lifecycle_event_date ON field_lifecycle_history(event_date);

CREATE INDEX idx_nursery_plantation ON nursery(plantation_id);
CREATE INDEX idx_nursery_type ON nursery(nursery_type_code);

CREATE INDEX idx_nursery_clone_nursery ON nursery_clone_distribution(nursery_id);
CREATE INDEX idx_nursery_clone_clone ON nursery_clone_distribution(clone_id);

CREATE INDEX idx_snapshot_plantation ON annual_area_snapshot(plantation_id);
