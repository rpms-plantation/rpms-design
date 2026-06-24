-- ============================================================================
-- V1_004 — Module 1 (Plantation Field Records) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-1-field-records/plantation_field_records_ddl.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update updated_at timestamp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_plantation_updated
    BEFORE UPDATE ON plantation
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_field_updated
    BEFORE UPDATE ON field
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_nursery_updated
    BEFORE UPDATE ON nursery
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_clone_master_updated
    BEFORE UPDATE ON clone_master
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_nursery_clone_dist_updated
    BEFORE UPDATE ON nursery_clone_distribution
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_land_use_updated
    BEFORE UPDATE ON plantation_land_use
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS point from lat/lon
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_plantation_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON plantation
    FOR EACH ROW EXECUTE FUNCTION fn_sync_gps_point();

-- ----------------------------------------------------------------------------
-- Validation — Ensure only one MOTHERBUD nursery per plantation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_motherbud_limit()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.nursery_type_code = 'MOTHERBUD' AND NEW.status = 'ACTIVE' THEN
        IF EXISTS (
            SELECT 1 FROM nursery
            WHERE plantation_id = NEW.plantation_id
              AND nursery_type_code = 'MOTHERBUD'
              AND status = 'ACTIVE'
              AND nursery_id != COALESCE(NEW.nursery_id, -1)
        ) THEN
            RAISE EXCEPTION 'Only one active Motherbud Wood Garden is allowed per plantation (plantation_id: %)', NEW.plantation_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_motherbud
    BEFORE INSERT OR UPDATE ON nursery
    FOR EACH ROW EXECUTE FUNCTION fn_validate_motherbud_limit();
