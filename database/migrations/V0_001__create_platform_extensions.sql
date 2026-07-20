-- ============================================================================
-- RPMS — Rubber Plantation Management System
-- Migration: V0_001__create_platform_extensions.sql
-- Module:    Platform (rpms-platform) — shared database objects
-- Purpose:   Enable PostgreSQL extensions required by every module (M1-M6).
--            Must run before any V1-V6 migration — all module table
--            migrations declare this as a prerequisite.
-- Source:    database/module-1-field-records/plantation_field_records_ddl.sql
--            (lines 9-11 — extensions were declared once at the top of the
--            original monolithic DDL; module boundaries did not exist yet)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;           -- Spatial/GIS support (SRID 4326 geometry columns, M1/M2/M3/M6)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";       -- UUID generation
