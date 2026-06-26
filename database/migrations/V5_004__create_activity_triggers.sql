-- ============================================================================
-- V5_004 — Module 5 (Daily Activity Monitoring) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-5-daily-activity/daily_activity_monitoring_ddl.sql
-- Prerequisite: fn_update_timestamp() must already exist (created in V1_004).
--
-- Fix applied vs. the source DDL (see rpms-design CLAUDE.md / session notes):
--   1. The source DDL's trigger on supervisor_inspection (Section 11.6) calls
--      fn_coll_point_sync_gps() — a function owned by Module 3 (collection_point
--      GPS sync). It happens to share the same NEW.gps_latitude/gps_longitude/
--      gps_point column names so it would not error at runtime (Module 3's
--      migration runs first), but it makes Module 5's schema silently depend on
--      Module 3 owning a function it never declares — a single-writer/module-
--      ownership violation. Fixed by giving Module 5 its own
--      fn_insp_sync_gps() with identical logic.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update timestamps (reuses fn_update_timestamp from Module 1)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_daily_plan_updated
    BEFORE UPDATE ON daily_work_plan
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_daily_activity_updated
    BEFORE UPDATE ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_supervisor_insp_updated
    BEFORE UPDATE ON supervisor_inspection
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_material_master_updated
    BEFORE UPDATE ON material_master
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS point from lat/lon on daily_activity
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_activity_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_gps_lat IS NOT NULL AND NEW.start_gps_lon IS NOT NULL THEN
        NEW.start_gps_point = ST_SetSRID(ST_MakePoint(NEW.start_gps_lon, NEW.start_gps_lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_activity_gps_sync
    BEFORE INSERT OR UPDATE OF start_gps_lat, start_gps_lon ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_activity_sync_gps();

-- ----------------------------------------------------------------------------
-- Auto-calculate completion percentage / duration / man-days
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_completion_pct()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.target_quantity IS NOT NULL AND NEW.target_quantity > 0 AND NEW.actual_quantity IS NOT NULL THEN
        NEW.completion_pct = LEAST(ROUND((NEW.actual_quantity / NEW.target_quantity) * 100, 2), 100);
    END IF;
    IF NEW.actual_start_time IS NOT NULL AND NEW.actual_end_time IS NOT NULL THEN
        NEW.actual_duration_hours = ROUND(EXTRACT(EPOCH FROM (NEW.actual_end_time - NEW.actual_start_time)) / 3600, 2);
    END IF;
    IF NEW.workers_deployed IS NOT NULL AND NEW.actual_duration_hours IS NOT NULL THEN
        NEW.man_days = ROUND(NEW.workers_deployed * NEW.actual_duration_hours / 8.0, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_completion
    BEFORE INSERT OR UPDATE OF target_quantity, actual_quantity, actual_start_time, actual_end_time, workers_deployed ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_calc_completion_pct();

-- ----------------------------------------------------------------------------
-- Auto-calculate material variance
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_material_variance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.planned_quantity IS NOT NULL AND NEW.planned_quantity > 0 THEN
        NEW.variance_pct = ROUND(((NEW.actual_quantity - NEW.planned_quantity) / NEW.planned_quantity) * 100, 2);
    END IF;
    IF NEW.unit_cost IS NOT NULL THEN
        NEW.total_cost = ROUND(NEW.actual_quantity * NEW.unit_cost, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_material_variance
    BEFORE INSERT OR UPDATE OF planned_quantity, actual_quantity, unit_cost ON activity_material_usage
    FOR EACH ROW EXECUTE FUNCTION fn_calc_material_variance();

-- ----------------------------------------------------------------------------
-- Auto-update daily work plan summary counts
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_plan_counts()
RETURNS TRIGGER AS $$
DECLARE
    v_plan_id INT;
BEGIN
    v_plan_id := COALESCE(NEW.plan_id, OLD.plan_id);
    IF v_plan_id IS NOT NULL THEN
        UPDATE daily_work_plan SET
            total_activities_planned = (
                SELECT COUNT(*) FROM daily_activity WHERE plan_id = v_plan_id
            ),
            total_activities_completed = (
                SELECT COUNT(*) FROM daily_activity WHERE plan_id = v_plan_id AND status IN ('COMPLETED', 'PARTIAL')
            ),
            total_workers_deployed = (
                SELECT COALESCE(SUM(workers_deployed), 0) FROM daily_activity WHERE plan_id = v_plan_id
            ),
            completion_rate_pct = (
                SELECT CASE WHEN COUNT(*) > 0
                    THEN ROUND(COUNT(*) FILTER (WHERE status = 'COMPLETED') * 100.0 / COUNT(*), 2)
                    ELSE 0 END
                FROM daily_activity WHERE plan_id = v_plan_id
            ),
            updated_at = NOW()
        WHERE plan_id = v_plan_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_plan_counts_insert
    AFTER INSERT ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_sync_plan_counts();

CREATE TRIGGER trg_sync_plan_counts_update
    AFTER UPDATE OF status ON daily_activity
    FOR EACH ROW EXECUTE FUNCTION fn_sync_plan_counts();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS on photo evidence
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_photo_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_photo_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON activity_photo_evidence
    FOR EACH ROW EXECUTE FUNCTION fn_photo_sync_gps();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS on supervisor_inspection (Module 5's own function — see
-- fix note above; do not reuse Module 3's fn_coll_point_sync_gps)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_insp_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insp_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON supervisor_inspection
    FOR EACH ROW EXECUTE FUNCTION fn_insp_sync_gps();
