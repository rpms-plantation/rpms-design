-- ============================================================================
-- V2_004 — Module 2 (Tree Records & Tracking) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-2-tree-records/tree_records_tracking_ddl.sql
-- Prerequisite: fn_update_timestamp() must already exist (created in V1_004).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update updated_at (reuses fn_update_timestamp from Module 1)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_tree_updated
    BEFORE UPDATE ON tree
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_tree_tag_updated
    BEFORE UPDATE ON tree_tag
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_panel_history_updated
    BEFORE UPDATE ON tree_panel_history
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_disease_incident_updated
    BEFORE UPDATE ON tree_disease_incident
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_treatment_record_updated
    BEFORE UPDATE ON tree_treatment_record
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_disease_master_updated
    BEFORE UPDATE ON disease_master
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS point from lat/lon on tree
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_tree_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tree_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON tree
    FOR EACH ROW EXECUTE FUNCTION fn_tree_sync_gps_point();

-- ----------------------------------------------------------------------------
-- Auto-log tree status changes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_log_tree_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.tree_status IS DISTINCT FROM NEW.tree_status THEN
        INSERT INTO tree_status_change_log (tree_id, change_date, from_status, to_status, changed_by)
        VALUES (NEW.tree_id, CURRENT_DATE, OLD.tree_status, NEW.tree_status, NEW.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tree_status_change_log
    AFTER UPDATE OF tree_status ON tree
    FOR EACH ROW EXECUTE FUNCTION fn_log_tree_status_change();

-- ----------------------------------------------------------------------------
-- Auto-update tree's denormalized girth/bark from measurements
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_tree_girth()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parameter_code = 'GIRTH' THEN
        UPDATE tree
        SET current_girth_cm = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    ELSIF NEW.parameter_code = 'BARK_THICKNESS' THEN
        UPDATE tree
        SET current_bark_mm = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    ELSIF NEW.parameter_code = 'BARK_CONSUMPTION' THEN
        UPDATE tree
        SET bark_consumption_pct = NEW.measured_value,
            updated_at = NOW()
        WHERE tree_id = NEW.tree_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_tree_girth
    AFTER INSERT ON tree_growth_measurement
    FOR EACH ROW EXECUTE FUNCTION fn_sync_tree_girth();

-- ----------------------------------------------------------------------------
-- Auto-update tag scan metadata
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_increment_tag_scan()
RETURNS TRIGGER AS $$
BEGIN
    NEW.total_scan_count = COALESCE(OLD.total_scan_count, 0) +
        CASE WHEN NEW.last_scanned_at IS DISTINCT FROM OLD.last_scanned_at THEN 1 ELSE 0 END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tag_scan_count
    BEFORE UPDATE OF last_scanned_at ON tree_tag
    FOR EACH ROW EXECUTE FUNCTION fn_increment_tag_scan();
