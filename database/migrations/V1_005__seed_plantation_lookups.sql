-- ============================================================================
-- V1_005 — Module 1 (Plantation Field Records) — Seed lookup data
-- Source: database/module-1-field-records/plantation_field_records_ddl.sql
-- ============================================================================

INSERT INTO lu_measurement_unit (unit_code, unit_name, description) VALUES
    ('HA', 'Hectare', 'Used for large plantations'),
    ('AC', 'Acre',    'Used for small plantations');

INSERT INTO lu_land_use_type (land_use_code, land_use_name, parent_code, display_order, description) VALUES
    ('PLANTED',         'Total Planted Area',               NULL,           1,  'All areas with rubber plants'),
    ('BUILDING',        'Building & Infrastructure Area',   NULL,           2,  'Buildings, factories, offices, housing'),
    ('ROAD',            'Roads Surface Area',               NULL,           3,  'Internal and access roads'),
    ('SWAP',            'Swap Area',                        NULL,           4,  'Swamp/marshy land'),
    ('ROCKY',           'Rocky Area',                       NULL,           5,  'Rocky/stony unusable land'),
    ('UNCULTIVATED',    'Uncultivated Area',                NULL,           6,  'Uncultivated but potentially usable'),
    ('HVC',             'High Value Conservation Area',     NULL,           7,  'Forested and conservation zones'),
    ('WATER',           'Water Bodies',                     NULL,           8,  'Rivers, lakes, ponds, reservoirs'),
    ('MISC',            'Miscellaneous Area',               NULL,           9,  'Other unclassified areas'),
    -- Sub-types for Planted Area
    ('NURSERY',         'Nursery Area',                     'PLANTED',      10, 'Nursery sections'),
    ('IMMATURE',        'Immature / Young Area',            'PLANTED',      11, 'Planted but not yet tapping'),
    ('MATURE',          'Mature Area (Under Tapping)',      'PLANTED',      12, 'Actively producing rubber');

INSERT INTO lu_nursery_type (nursery_type_code, nursery_type_name, allows_multiple, description) VALUES
    ('MOTHERBUD',   'Motherbud Wood Garden',    FALSE,  'One per plantation - source of bud wood'),
    ('POLYBAG',     'Polybag Nursery',          TRUE,   'Polybag-raised seedlings/buddings'),
    ('GROUND',      'Ground Nursery',           TRUE,   'Direct ground-planted nursery');

INSERT INTO lu_field_category (category_code, category_name, description) VALUES
    ('NEW_CLEARING', 'New Clearing',  'Freshly cleared land planted for the first time'),
    ('REPLANTING',   'Replanting',    'Previously mature area replanted with new trees'),
    ('MATURE',       'Mature',        'Trees under active tapping');

INSERT INTO lu_tapping_system (tapping_system_code, tapping_system_name, frequency_notation) VALUES
    ('S2D2',  'Half Spiral - Alternate Day',     'S/2 d2'),
    ('S2D3',  'Half Spiral - Third Daily',        'S/2 d3'),
    ('S2D4',  'Half Spiral - Fourth Daily',       'S/2 d4'),
    ('S4D2',  'Quarter Spiral - Alternate Day',   'S/4 d2');
