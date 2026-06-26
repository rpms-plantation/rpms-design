-- ============================================================================
-- V3_002 — Module 3 (Tapping Task Monitoring) — CREATE INDEX statements
-- Source: database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
-- ============================================================================

CREATE INDEX idx_schedule_plantation ON tapping_schedule(plantation_id);
CREATE INDEX idx_schedule_field ON tapping_schedule(field_id);
CREATE INDEX idx_schedule_status ON tapping_schedule(status);

CREATE INDEX idx_task_plantation ON tapping_task(plantation_id);
CREATE INDEX idx_task_field ON tapping_task(field_id);
CREATE INDEX idx_task_date ON tapping_task(task_date);
CREATE INDEX idx_task_tapper ON tapping_task(tapper_id) WHERE tapper_id IS NOT NULL;
CREATE INDEX idx_task_status ON tapping_task(status);
CREATE INDEX idx_task_schedule ON tapping_task(schedule_id);
CREATE INDEX idx_task_field_date ON tapping_task(field_id, task_date);
CREATE INDEX idx_task_gps ON tapping_task USING GIST(start_gps_point);
CREATE INDEX idx_task_date_status ON tapping_task(task_date, status);

CREATE INDEX idx_task_tree_task ON tapping_task_tree_detail(task_id);
CREATE INDEX idx_task_tree_tree ON tapping_task_tree_detail(tree_id);
CREATE INDEX idx_task_tree_date ON tapping_task_tree_detail(scanned_at);

CREATE INDEX idx_coll_point_plantation ON collection_point(plantation_id);
CREATE INDEX idx_coll_point_gps ON collection_point USING GIST(gps_point);

CREATE INDEX idx_collection_task ON latex_collection_record(task_id);
CREATE INDEX idx_collection_field ON latex_collection_record(field_id);
CREATE INDEX idx_collection_date ON latex_collection_record(collection_date);
CREATE INDEX idx_collection_grade ON latex_collection_record(latex_grade_code);
CREATE INDEX idx_collection_point ON latex_collection_record(collection_point_id);
CREATE INDEX idx_collection_batch ON latex_collection_record(transport_batch_id);

CREATE INDEX idx_quality_collection ON latex_quality_test(collection_id);
CREATE INDEX idx_quality_param ON latex_quality_test(parameter_code);
CREATE INDEX idx_quality_date ON latex_quality_test(test_date);
CREATE INDEX idx_quality_spec ON latex_quality_test(is_within_spec) WHERE is_within_spec = FALSE;

CREATE INDEX idx_iot_device_plantation ON iot_device(plantation_id);
CREATE INDEX idx_iot_device_field ON iot_device(field_id);
CREATE INDEX idx_iot_device_type ON iot_device(device_type_code);
CREATE INDEX idx_iot_device_status ON iot_device(status);
CREATE INDEX idx_iot_device_gps ON iot_device USING GIST(gps_point);

CREATE INDEX idx_sensor_device ON iot_sensor_reading(device_id);
CREATE INDEX idx_sensor_timestamp ON iot_sensor_reading(reading_timestamp);
CREATE INDEX idx_sensor_device_time ON iot_sensor_reading(device_id, reading_timestamp);

CREATE INDEX idx_weather_plantation ON weather_observation(plantation_id);
CREATE INDEX idx_weather_date ON weather_observation(observation_date);
CREATE INDEX idx_weather_field ON weather_observation(field_id);

CREATE INDEX idx_perf_tapper ON tapper_performance_daily(tapper_id);
CREATE INDEX idx_perf_date ON tapper_performance_daily(performance_date);
CREATE INDEX idx_perf_plantation ON tapper_performance_daily(plantation_id);

CREATE INDEX idx_field_yield_plantation ON field_yield_daily(plantation_id);
CREATE INDEX idx_field_yield_field ON field_yield_daily(field_id);
CREATE INDEX idx_field_yield_date ON field_yield_daily(yield_date);
CREATE INDEX idx_field_yield_clone ON field_yield_daily(clone_code);
