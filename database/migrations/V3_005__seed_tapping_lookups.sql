-- ============================================================================
-- V3_005 — Module 3 (Tapping Task Monitoring) — Seed lookup data
-- Source: database/module-3-tapping-task/tapping_task_monitoring_ddl.sql
-- ============================================================================

INSERT INTO lu_tapping_task_status (status_code, status_name, is_terminal, display_order, description) VALUES
    ('SCHEDULED',       'Scheduled',                FALSE,  1,  'Task created and assigned, not yet started'),
    ('IN_PROGRESS',     'In Progress',              FALSE,  2,  'Tapper has started tapping the assigned block'),
    ('COMPLETED',       'Completed',                TRUE,   3,  'All assigned trees tapped, latex collected'),
    ('PARTIAL',         'Partially Completed',      TRUE,   4,  'Some trees tapped — rest skipped due to rain, injury, etc.'),
    ('CANCELLED',       'Cancelled',                TRUE,   5,  'Task cancelled before execution'),
    ('RAIN_STOPPED',    'Stopped by Rain',          TRUE,   6,  'Tapping halted mid-task due to rainfall'),
    ('NO_SHOW',         'Tapper No-Show',           TRUE,   7,  'Assigned tapper did not report for the task'),
    ('REASSIGNED',      'Reassigned',               FALSE,  8,  'Task transferred to a different tapper');

INSERT INTO lu_latex_grade (grade_code, grade_name, drc_range_min, drc_range_max, description) VALUES
    ('FIELD_LATEX',     'Field Latex',              28.00,  36.00,  'Fresh latex collected directly from tapping — standard grade'),
    ('HIGH_DRC',        'High DRC Latex',           36.00,  45.00,  'Concentrated or high-quality field latex'),
    ('CUP_LUMP',        'Cup Lump',                 45.00,  55.00,  'Coagulated latex in collection cups'),
    ('TREE_LACE',       'Tree Lace / Bark Scrap',   55.00,  70.00,  'Dried latex strips on bark surface'),
    ('EARTH_SCRAP',     'Earth Scrap',              40.00,  55.00,  'Latex that dripped to ground and coagulated'),
    ('USS',             'Unsmoked Sheet (USS)',      NULL,   NULL,   'Sheet rubber processed from field latex'),
    ('RSS',             'Ribbed Smoked Sheet (RSS)', NULL,   NULL,   'Smoked and graded sheet rubber'),
    ('REJECT',          'Reject / Contaminated',     NULL,   NULL,   'Contaminated or substandard latex');

INSERT INTO lu_tapping_skip_reason (reason_code, reason_name, reason_category) VALUES
    ('RAIN_MORNING',    'Morning Rainfall',                     'WEATHER'),
    ('RAIN_DURING',     'Rainfall During Tapping',              'WEATHER'),
    ('HEAVY_WIND',      'Heavy Wind / Storm',                   'WEATHER'),
    ('WET_PANEL',       'Panel Too Wet (Dew / Overnight Rain)', 'WEATHER'),
    ('WINTERING',       'Trees Wintering (Defoliation)',        'TREE_CONDITION'),
    ('TPD_AFFECTED',    'Tapping Panel Dryness',                'TREE_CONDITION'),
    ('BARK_DISEASE',    'Active Bark Disease',                  'TREE_CONDITION'),
    ('REST_DAY',        'Scheduled Rest / Tapping Holiday',     'OPERATIONAL'),
    ('STIMULANT_WAIT',  'Post-Stimulant Waiting Period',        'OPERATIONAL'),
    ('TAPPER_SICK',     'Tapper Sick Leave',                    'TAPPER'),
    ('TAPPER_ABSENT',   'Tapper Absent Without Leave',          'TAPPER'),
    ('TAPPER_INJURY',   'Tapper Injured During Work',           'TAPPER'),
    ('PUBLIC_HOLIDAY',  'Public Holiday',                       'HOLIDAY'),
    ('ESTATE_HOLIDAY',  'Estate / Plantation Holiday',          'HOLIDAY'),
    ('EQUIPMENT_FAIL',  'Equipment Failure',                    'OPERATIONAL'),
    ('OTHER',           'Other Reason',                         'OTHER');

INSERT INTO lu_collection_point_type (point_type_code, point_type_name) VALUES
    ('FIELD_STATION',   'Field Collection Station'),
    ('ROADSIDE_TANK',   'Roadside Bulking Tank'),
    ('DIVISION_CENTER', 'Division Collection Center'),
    ('FACTORY_GATE',    'Factory Receiving Point'),
    ('WEIGHBRIDGE',     'Weighbridge Station');

INSERT INTO lu_quality_parameter (parameter_code, parameter_name, unit_of_measure, min_acceptable, max_acceptable) VALUES
    ('DRC',             'Dry Rubber Content',           '%',        28.00,  45.00),
    ('TSC',             'Total Solid Content',          '%',        30.00,  48.00),
    ('NH3',             'Ammonia Content',              '%',        0.20,   0.70),
    ('VFA',             'Volatile Fatty Acid (VFA)',    'mEq',      NULL,   0.05),
    ('MST',             'Mechanical Stability Time',    'seconds',  600,    NULL),
    ('PH',              'pH Level',                     'pH',       6.50,   7.50),
    ('VISCOSITY',       'Mooney Viscosity',             'MU',       NULL,   NULL),
    ('DIRT_CONTENT',    'Dirt Content',                 '%',        NULL,   0.05),
    ('TEMPERATURE',     'Latex Temperature at Collection','°C',    NULL,   35.00),
    ('COLOR',           'Visual Color Assessment',      'grade',    NULL,   NULL);

INSERT INTO lu_iot_device_type (device_type_code, device_type_name, category) VALUES
    ('SMART_KNIFE',     'Smart Tapping Knife',          'TAPPING_TOOL'),
    ('RAIN_GAUGE',      'IoT Rain Gauge',               'WEATHER_SENSOR'),
    ('TEMP_HUMIDITY',   'Temperature & Humidity Sensor', 'WEATHER_SENSOR'),
    ('FLOW_METER',      'Latex Flow Meter',              'COLLECTION'),
    ('DIGITAL_SCALE',   'Digital Collection Scale',      'COLLECTION'),
    ('GPS_WEARABLE',    'GPS Wearable Band / Watch',     'WEARABLE'),
    ('BLE_GEOFENCE',    'BLE Geofence Beacon',           'GEOFENCE');
