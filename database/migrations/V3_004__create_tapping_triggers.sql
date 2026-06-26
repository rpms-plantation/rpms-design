-- ============================================================================
-- V3_004 — Module 3 (Tapping Task Monitoring) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
-- Prerequisite: fn_update_timestamp() must already exist (created in V1_004).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update timestamps (reuses fn_update_timestamp from Module 1)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_tapping_schedule_updated
    BEFORE UPDATE ON tapping_schedule
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_tapping_task_updated
    BEFORE UPDATE ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_collection_updated
    BEFORE UPDATE ON latex_collection_record
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_collection_point_updated
    BEFORE UPDATE ON collection_point
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_iot_device_updated
    BEFORE UPDATE ON iot_device
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS point on tapping task
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_task_sync_gps_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_gps_lat IS NOT NULL AND NEW.start_gps_lon IS NOT NULL THEN
        NEW.start_gps_point = ST_SetSRID(ST_MakePoint(NEW.start_gps_lon, NEW.start_gps_lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_task_gps_sync
    BEFORE INSERT OR UPDATE OF start_gps_lat, start_gps_lon ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_task_sync_gps_point();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS point on collection point
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_coll_point_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_coll_point_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON collection_point
    FOR EACH ROW EXECUTE FUNCTION fn_coll_point_sync_gps();

-- ----------------------------------------------------------------------------
-- Auto-calculate yield_per_tree and total_yield on task completion
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_task_yield_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('COMPLETED', 'PARTIAL') AND NEW.trees_tapped > 0 THEN
        NEW.total_yield_kg = COALESCE(NEW.total_latex_kg, 0)
                           + COALESCE(NEW.total_cup_lump_kg, 0)
                           + COALESCE(NEW.total_tree_lace_kg, 0);
        NEW.yield_per_tree_g = ROUND((NEW.total_yield_kg / NEW.trees_tapped) * 1000, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_task_yield
    BEFORE INSERT OR UPDATE OF total_latex_kg, total_cup_lump_kg, total_tree_lace_kg, trees_tapped ON tapping_task
    FOR EACH ROW EXECUTE FUNCTION fn_calc_task_yield_metrics();

-- ----------------------------------------------------------------------------
-- Auto-calculate dry rubber + net weight on collection record
-- FIX vs. source DDL: net_weight_kg must be recalculated BEFORE dry_rubber_kg
-- is derived from it. The source DDL computes dry_rubber_kg first, using
-- whatever (possibly NULL/garbage) net_weight_kg the client sent, then
-- overwrites net_weight_kg afterward — so dry_rubber_kg is always computed
-- from the wrong value. Reordered here so net_weight_kg is correct first.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_dry_rubber()
RETURNS TRIGGER AS $$
BEGIN
    NEW.net_weight_kg = COALESCE(NEW.gross_weight_kg, 0) - COALESCE(NEW.container_weight_kg, 0);
    IF NEW.drc_pct IS NOT NULL THEN
        NEW.dry_rubber_kg = ROUND(NEW.net_weight_kg * NEW.drc_pct / 100, 3);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_dry_rubber
    BEFORE INSERT OR UPDATE OF gross_weight_kg, container_weight_kg, drc_pct ON latex_collection_record
    FOR EACH ROW EXECUTE FUNCTION fn_calc_dry_rubber();

-- ----------------------------------------------------------------------------
-- Auto-flag quality test out-of-spec
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_quality_spec()
RETURNS TRIGGER AS $$
DECLARE
    v_min NUMERIC;
    v_max NUMERIC;
BEGIN
    SELECT min_acceptable, max_acceptable
    INTO v_min, v_max
    FROM lu_quality_parameter
    WHERE parameter_code = NEW.parameter_code;

    IF v_min IS NOT NULL AND v_max IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value >= v_min AND NEW.tested_value <= v_max);
        IF NOT NEW.is_within_spec THEN
            IF NEW.tested_value < v_min THEN
                NEW.deviation_pct = ROUND(((v_min - NEW.tested_value) / v_min) * 100, 2);
            ELSE
                NEW.deviation_pct = ROUND(((NEW.tested_value - v_max) / v_max) * 100, 2);
            END IF;
        ELSE
            NEW.deviation_pct = 0;
        END IF;
    ELSIF v_min IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value >= v_min);
    ELSIF v_max IS NOT NULL THEN
        NEW.is_within_spec = (NEW.tested_value <= v_max);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_quality_spec
    BEFORE INSERT OR UPDATE OF tested_value ON latex_quality_test
    FOR EACH ROW EXECUTE FUNCTION fn_check_quality_spec();
