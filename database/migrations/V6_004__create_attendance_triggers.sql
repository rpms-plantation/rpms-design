-- ============================================================================
-- V6_004 — Module 6 (Attendance Management) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-6-attendance/attendance_management_ddl.sql
-- Prerequisite: fn_update_timestamp() must already exist (created in V1_004).
--
-- Fix applied vs. the source DDL (see rpms-design CLAUDE.md / session notes):
--   1. fn_calc_attendance_hours() in the source DDL nests late-arrival
--      detection (is_late / late_minutes) inside the same `IF check_in_time
--      IS NOT NULL AND check_out_time IS NOT NULL` block as the hours/overtime
--      calculation. That means a worker who checks in but hasn't checked out
--      yet (the normal state for most of the working day) never gets
--      is_late/late_minutes populated, defeating real-time late-arrival
--      alerts/dashboards — the entire point of capturing check-in events
--      independently via the two-tier scan_log -> daily_attendance flow.
--      Fixed by computing late detection in its own block keyed only on
--      check_in_time, and fetching all needed lu_shift columns (including
--      work_hours, previously re-queried twice) once at the top.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update timestamps (reuses fn_update_timestamp from Module 1)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_daily_attendance_updated
    BEFORE UPDATE ON daily_attendance
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_attendance_reg_updated
    BEFORE UPDATE ON attendance_regularization
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_attendance_loc_updated
    BEFORE UPDATE ON attendance_location
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_monthly_summary_updated
    BEFORE UPDATE ON monthly_attendance_summary
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-calculate hours, late, overtime (fixed — see note above)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calc_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_shift RECORD;
    v_expected_start TIMESTAMPTZ;
BEGIN
    SELECT break_minutes, grace_minutes, start_time, work_hours INTO v_shift
    FROM lu_shift WHERE shift_code = NEW.shift_code;

    -- Late detection: independent of checkout, so it fires as soon as
    -- check_in_time is recorded (the normal state for most of the shift).
    IF NEW.check_in_time IS NOT NULL AND v_shift.start_time IS NOT NULL THEN
        v_expected_start = (NEW.attendance_date + v_shift.start_time)::TIMESTAMPTZ;
        IF NEW.check_in_time > (v_expected_start + (COALESCE(v_shift.grace_minutes, 15) || ' minutes')::INTERVAL) THEN
            NEW.is_late = TRUE;
            NEW.late_minutes = EXTRACT(EPOCH FROM (NEW.check_in_time - v_expected_start))::INT / 60;
        ELSE
            NEW.is_late = FALSE;
            NEW.late_minutes = 0;
        END IF;
    END IF;

    IF NEW.check_in_time IS NOT NULL AND NEW.check_out_time IS NOT NULL THEN
        -- Gross hours
        NEW.gross_hours = ROUND(EXTRACT(EPOCH FROM (NEW.check_out_time - NEW.check_in_time)) / 3600, 2);

        NEW.break_minutes = COALESCE(NEW.break_minutes, COALESCE(v_shift.break_minutes, 0));
        NEW.net_work_hours = GREATEST(NEW.gross_hours - (NEW.break_minutes / 60.0), 0);

        -- Overtime detection
        IF NEW.net_work_hours > COALESCE(v_shift.work_hours, 8) THEN
            NEW.has_overtime = TRUE;
            NEW.overtime_hours = ROUND(NEW.net_work_hours - COALESCE(v_shift.work_hours, 8), 2);
        ELSE
            NEW.has_overtime = FALSE;
            NEW.overtime_hours = 0;
        END IF;
    END IF;

    -- Auto-populate GPS points
    IF NEW.check_in_gps_lat IS NOT NULL AND NEW.check_in_gps_lon IS NOT NULL THEN
        NEW.check_in_gps_point = ST_SetSRID(ST_MakePoint(NEW.check_in_gps_lon, NEW.check_in_gps_lat), 4326);
    END IF;
    IF NEW.check_out_gps_lat IS NOT NULL AND NEW.check_out_gps_lon IS NOT NULL THEN
        NEW.check_out_gps_point = ST_SetSRID(ST_MakePoint(NEW.check_out_gps_lon, NEW.check_out_gps_lat), 4326);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calc_attendance_hours
    BEFORE INSERT OR UPDATE OF check_in_time, check_out_time, shift_code ON daily_attendance
    FOR EACH ROW EXECUTE FUNCTION fn_calc_attendance_hours();

-- ----------------------------------------------------------------------------
-- Auto-populate GPS on scan log
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_scan_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.gps_point = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scan_gps_sync
    BEFORE INSERT ON attendance_scan_log
    FOR EACH ROW EXECUTE FUNCTION fn_scan_sync_gps();

-- ----------------------------------------------------------------------------
-- Auto-apply regularization to daily_attendance when approved
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_apply_regularization()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.approval_status = 'APPROVED' AND OLD.approval_status != 'APPROVED' THEN
        UPDATE daily_attendance SET
            attendance_status = COALESCE(NEW.corrected_status, attendance_status),
            check_in_time = COALESCE(NEW.corrected_check_in, check_in_time),
            check_out_time = COALESCE(NEW.corrected_check_out, check_out_time),
            is_regularized = TRUE,
            regularization_id = NEW.regularization_id,
            updated_at = NOW(),
            updated_by = 'REGULARIZATION_' || NEW.regularization_id
        WHERE attendance_id = NEW.attendance_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_regularization
    AFTER UPDATE OF approval_status ON attendance_regularization
    FOR EACH ROW EXECUTE FUNCTION fn_apply_regularization();

-- ----------------------------------------------------------------------------
-- Auto-populate geofence center on attendance_location
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_att_loc_sync_gps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL THEN
        NEW.geofence_center = ST_SetSRID(ST_MakePoint(NEW.gps_longitude, NEW.gps_latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_att_loc_gps_sync
    BEFORE INSERT OR UPDATE OF gps_latitude, gps_longitude ON attendance_location
    FOR EACH ROW EXECUTE FUNCTION fn_att_loc_sync_gps();
