-- ============================================================================
-- V4_004 — Module 4 (Workforce Management) — CREATE FUNCTION + CREATE TRIGGER
-- Source: database/module-4-workforce/workforce_management_ddl.sql
-- Prerequisite: fn_update_timestamp() must already exist (created in V1_004).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Auto-update updated_at (reuses fn_update_timestamp from Module 1)
-- ----------------------------------------------------------------------------
CREATE TRIGGER trg_worker_updated
    BEFORE UPDATE ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_gang_updated
    BEFORE UPDATE ON gang
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_skill_updated
    BEFORE UPDATE ON worker_skill
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_doc_updated
    BEFORE UPDATE ON worker_document
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_leave_updated
    BEFORE UPDATE ON worker_leave
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_lb_updated
    BEFORE UPDATE ON worker_leave_balance
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_training_updated
    BEFORE UPDATE ON worker_training
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_worker_pay_updated
    BEFORE UPDATE ON worker_pay_structure
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_safety_updated
    BEFORE UPDATE ON worker_safety_incident
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ----------------------------------------------------------------------------
-- Auto-log worker status changes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_log_worker_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.worker_status IS DISTINCT FROM NEW.worker_status THEN
        INSERT INTO worker_status_change_log
            (worker_id, change_date, from_status, to_status, effective_date, changed_by)
        VALUES
            (NEW.worker_id, CURRENT_DATE, OLD.worker_status, NEW.worker_status, CURRENT_DATE, NEW.updated_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_worker_status_change
    AFTER UPDATE OF worker_status ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_log_worker_status_change();

-- ----------------------------------------------------------------------------
-- Auto-update gang current_size
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_gang_size()
RETURNS TRIGGER AS $$
DECLARE
    v_old_gang INT;
    v_new_gang INT;
BEGIN
    v_old_gang := COALESCE(OLD.assigned_gang_id, -1);
    v_new_gang := COALESCE(NEW.assigned_gang_id, -1);

    IF v_old_gang IS DISTINCT FROM v_new_gang THEN
        -- Decrement old gang
        IF OLD.assigned_gang_id IS NOT NULL THEN
            UPDATE gang SET current_size = GREATEST(current_size - 1, 0), updated_at = NOW()
            WHERE gang_id = OLD.assigned_gang_id;
        END IF;
        -- Increment new gang
        IF NEW.assigned_gang_id IS NOT NULL THEN
            UPDATE gang SET current_size = current_size + 1, updated_at = NOW()
            WHERE gang_id = NEW.assigned_gang_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_gang_size
    AFTER UPDATE OF assigned_gang_id ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_sync_gang_size();

-- Also handle INSERT/DELETE for gang size
CREATE OR REPLACE FUNCTION fn_gang_size_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assigned_gang_id IS NOT NULL THEN
        UPDATE gang SET current_size = current_size + 1, updated_at = NOW()
        WHERE gang_id = NEW.assigned_gang_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gang_size_insert
    AFTER INSERT ON worker
    FOR EACH ROW EXECUTE FUNCTION fn_gang_size_on_insert();

-- ----------------------------------------------------------------------------
-- Auto-update leave balance when leave is approved
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_leave_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.approval_status = 'APPROVED' AND OLD.approval_status != 'APPROVED' THEN
        UPDATE worker_leave_balance
        SET taken_days = taken_days + NEW.total_days,
            pending_days = GREATEST(pending_days - NEW.total_days, 0),
            updated_at = NOW()
        WHERE worker_id = NEW.worker_id
          AND leave_type_code = NEW.leave_type_code
          AND balance_year = EXTRACT(YEAR FROM NEW.leave_start_date);
    END IF;
    IF NEW.approval_status = 'PENDING' AND OLD.approval_status != 'PENDING' THEN
        UPDATE worker_leave_balance
        SET pending_days = pending_days + NEW.total_days,
            updated_at = NOW()
        WHERE worker_id = NEW.worker_id
          AND leave_type_code = NEW.leave_type_code
          AND balance_year = EXTRACT(YEAR FROM NEW.leave_start_date);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_leave_balance
    AFTER UPDATE OF approval_status ON worker_leave
    FOR EACH ROW EXECUTE FUNCTION fn_update_leave_balance();