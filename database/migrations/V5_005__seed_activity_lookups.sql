-- ============================================================================
-- V5_005 — Module 5 (Daily Activity Monitoring) — Seed lookup data
-- Source: database/module-5-daily-activity/daily_activity_monitoring_ddl.sql
-- ============================================================================

INSERT INTO lu_activity_category (category_code, category_name, display_order, description) VALUES
    ('TAPPING',         'Tapping & Latex Collection',       1,  'Rubber tapping and latex collection — detail in Module 3'),
    ('FIELD_MAINT',     'Field Maintenance',                2,  'Weeding, clearing, drain maintenance, path upkeep'),
    ('MANURING',        'Manuring & Fertilizer Application',3,  'Chemical and organic fertilizer application'),
    ('SPRAYING',        'Pest & Disease Spraying',          4,  'Chemical spraying, fungicide, herbicide application'),
    ('NURSERY_OPS',     'Nursery Operations',               5,  'Nursery planting, budding, maintenance, dispatch'),
    ('REPLANTING',      'Replanting & New Planting',        6,  'Felling, clearing, lining, holing, planting'),
    ('STIMULATION',     'Stimulant Application',            7,  'Ethephon and other yield stimulant application'),
    ('HARVESTING',      'Timber Harvesting',                8,  'Felling, logging, and timber extraction'),
    ('ROAD_MAINT',      'Road & Drain Maintenance',         9,  'Estate road repair, culvert clearing, drainage'),
    ('FACTORY_OPS',     'Factory / Processing',             10, 'Latex processing, sheet making, smoking, packing'),
    ('TRANSPORT',       'Transport & Logistics',            11, 'Latex transport, material delivery, personnel'),
    ('INFRASTRUCTURE',  'Infrastructure & Building',        12, 'Building maintenance, water supply, electricity'),
    ('ADMIN',           'Administrative Work',              13, 'Office work, record keeping, meetings'),
    ('INSPECTION',      'Supervisory Inspection',           14, 'Field checks, quality audits, compliance walks'),
    ('OTHER',           'Other / Miscellaneous',            15, 'Any activity not classified above');

INSERT INTO lu_activity_type (activity_type_code, activity_type_name, category_code, requires_materials, unit_of_measure, standard_duration_hours) VALUES
    -- Field Maintenance
    ('WEEDING_MANUAL',      'Manual Weeding (Slashing)',            'FIELD_MAINT',  FALSE,  'HECTARE',  6),
    ('WEEDING_CHEMICAL',    'Chemical Weeding (Herbicide)',         'FIELD_MAINT',  TRUE,   'HECTARE',  4),
    ('CIRCLE_WEEDING',      'Circle Weeding Around Trees',          'FIELD_MAINT',  FALSE,  'TREE',     6),
    ('DRAIN_CLEARING',      'Drain / Waterway Clearing',            'FIELD_MAINT',  FALSE,  'METER',    6),
    ('PATH_CLEARING',       'Tapping Path Clearing',                'FIELD_MAINT',  FALSE,  'HECTARE',  5),
    ('COVER_CROP_MAINT',    'Cover Crop Maintenance',               'FIELD_MAINT',  FALSE,  'HECTARE',  5),
    -- Manuring
    ('MANURE_INORGANIC',    'Inorganic Fertilizer Application',     'MANURING',     TRUE,   'HECTARE',  5),
    ('MANURE_ORGANIC',      'Organic Manure Application',           'MANURING',     TRUE,   'HECTARE',  6),
    ('MANURE_ROCKPHOS',     'Rock Phosphate Application',           'MANURING',     TRUE,   'HECTARE',  5),
    ('MANURE_YOUNG',        'Young Rubber Manuring',                'MANURING',     TRUE,   'TREE',     6),
    -- Spraying
    ('SPRAY_FUNGICIDE',     'Fungicide Spraying',                   'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_HERBICIDE',     'Herbicide Application',                'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_INSECTICIDE',   'Insecticide Spraying',                 'SPRAYING',     TRUE,   'HECTARE',  4),
    ('SPRAY_ABNORMAL_LF',   'Abnormal Leaf Fall Spraying (Aerial)', 'SPRAYING',     TRUE,   'HECTARE',  2),
    -- Nursery
    ('NURSERY_SEEDING',     'Nursery Seed Planting',                'NURSERY_OPS',  TRUE,   'COUNT',    6),
    ('NURSERY_BUDDING',     'Bud Grafting',                         'NURSERY_OPS',  TRUE,   'COUNT',    6),
    ('NURSERY_WATERING',    'Nursery Watering',                     'NURSERY_OPS',  FALSE,  'COUNT',    3),
    ('NURSERY_DISPATCH',    'Plant Dispatch to Field',              'NURSERY_OPS',  FALSE,  'COUNT',    4),
    -- Replanting
    ('FELLING',             'Tree Felling (Old Rubber)',             'REPLANTING',   TRUE,   'TREE',     6),
    ('CLEARING',            'Land Clearing Post-Felling',           'REPLANTING',   FALSE,  'HECTARE',  8),
    ('LINING_HOLING',       'Lining & Holing for Planting',         'REPLANTING',   FALSE,  'TREE',     6),
    ('NEW_PLANTING',        'New Planting / Replanting',            'REPLANTING',   TRUE,   'TREE',     6),
    -- Stimulation
    ('ETHEPHON_APP',        'Ethephon Stimulant Application',       'STIMULATION',  TRUE,   'TREE',     5),
    -- Road & Infrastructure
    ('ROAD_GRADING',        'Road Grading / Leveling',              'ROAD_MAINT',   FALSE,  'METER',    6),
    ('CULVERT_REPAIR',      'Culvert / Bridge Repair',              'ROAD_MAINT',   TRUE,   'COUNT',    6),
    ('BUILDING_MAINT',      'Building Maintenance',                 'INFRASTRUCTURE',TRUE,  'COUNT',    8),
    -- Factory
    ('SHEET_MAKING',        'Latex Sheet Making',                   'FACTORY_OPS',  TRUE,   'KG',       8),
    ('SMOKING',             'Sheet Smoking',                        'FACTORY_OPS',  TRUE,   'KG',       8),
    ('CREPE_PROCESSING',    'Crepe Rubber Processing',              'FACTORY_OPS',  TRUE,   'KG',       8),
    -- Transport
    ('LATEX_TRANSPORT',     'Latex Transport to Factory',           'TRANSPORT',    FALSE,  'TRIP',     4),
    ('MATERIAL_DELIVERY',   'Material / Input Delivery',            'TRANSPORT',    FALSE,  'TRIP',     4),
    -- Inspection
    ('FIELD_INSPECTION',    'Field / Block Inspection',             'INSPECTION',   FALSE,  'HECTARE',  3),
    ('TAP_QUALITY_AUDIT',   'Tapping Quality Audit',                'INSPECTION',   FALSE,  'TREE',     3),
    ('NURSERY_INSPECTION',  'Nursery Inspection',                   'INSPECTION',   FALSE,  'COUNT',    2);

INSERT INTO lu_activity_status (status_code, status_name, is_terminal, display_order) VALUES
    ('PLANNED',         'Planned',              FALSE,  1),
    ('ASSIGNED',        'Assigned',             FALSE,  2),
    ('IN_PROGRESS',     'In Progress',          FALSE,  3),
    ('COMPLETED',       'Completed',            TRUE,   4),
    ('PARTIAL',         'Partially Completed',  TRUE,   5),
    ('CANCELLED',       'Cancelled',            TRUE,   6),
    ('POSTPONED',       'Postponed',            FALSE,  7),
    ('BLOCKED',         'Blocked / On Hold',    FALSE,  8);

INSERT INTO lu_activity_priority (priority_code, priority_name, priority_level, color_hex) VALUES
    ('CRITICAL',    'Critical',     5,  '#EF4444'),
    ('HIGH',        'High',         4,  '#F97316'),
    ('MEDIUM',      'Medium',       3,  '#EAB308'),
    ('LOW',         'Low',          2,  '#22C55E'),
    ('ROUTINE',     'Routine',      1,  '#6B7280');

INSERT INTO material_master (material_code, material_name, material_category, default_unit, is_hazardous) VALUES
    ('NPK_12_14_12',   'NPK 12:14:12 Fertilizer',         'FERTILIZER',       'KG',   FALSE),
    ('UREA',           'Urea (46% N)',                     'FERTILIZER',       'KG',   FALSE),
    ('ROCKPHOS',       'Rock Phosphate',                   'FERTILIZER',       'KG',   FALSE),
    ('DOLOMITE',       'Dolomite Limestone',               'FERTILIZER',       'KG',   FALSE),
    ('GLYPHOSATE',     'Glyphosate Herbicide',             'HERBICIDE',        'L',    TRUE),
    ('PARAQUAT',       'Paraquat Herbicide',               'HERBICIDE',        'L',    TRUE),
    ('MANCOZEB',       'Mancozeb Fungicide',               'FUNGICIDE',        'KG',   TRUE),
    ('HEXACONAZOLE',   'Hexaconazole Fungicide',           'FUNGICIDE',        'L',    TRUE),
    ('TRIDEMORPH',     'Tridemorph Fungicide',             'FUNGICIDE',        'L',    TRUE),
    ('FIPRONIL',       'Fipronil Insecticide',             'INSECTICIDE',      'L',    TRUE),
    ('ETHEPHON_2.5',   'Ethephon 2.5% Stimulant',          'STIMULANT',        'L',    TRUE),
    ('POLYBAG_PLANT',  'Polybag Seedling',                 'PLANTING_MATERIAL','PIECE',FALSE),
    ('STUMP_PLANT',    'Budded Stump',                     'PLANTING_MATERIAL','PIECE',FALSE),
    ('DIESEL',         'Diesel Fuel',                      'FUEL',             'L',    FALSE),
    ('TAP_KNIFE',      'Tapping Knife Blade',              'EQUIPMENT',        'PIECE',FALSE);

INSERT INTO lu_inspection_checklist_item (item_code, item_name, category_code, check_type) VALUES
    ('CUT_ANGLE_OK',        'Tapping cut angle within 30° tolerance',       'TAPPING',      'YES_NO'),
    ('CUT_DEPTH_OK',        'Cut depth not exceeding 1.5mm from cambium',   'TAPPING',      'YES_NO'),
    ('BARK_CONSUMPTION_OK', 'Bark consumption within standard',             'TAPPING',      'YES_NO'),
    ('PANEL_MARKING_OK',    'Panel boundaries clearly marked',              'TAPPING',      'YES_NO'),
    ('CUP_POSITION_OK',     'Collection cup properly positioned',           'TAPPING',      'YES_NO'),
    ('WEED_FREE',           'Field free of weed growth',                    'FIELD_MAINT',  'RATING_1_5'),
    ('DRAIN_CLEAR',         'Drains and waterways clear',                   'FIELD_MAINT',  'RATING_1_5'),
    ('PATH_ACCESSIBLE',     'Tapping paths accessible',                     'FIELD_MAINT',  'YES_NO'),
    ('MANURE_APPLIED',      'Fertilizer applied at correct rate',           'MANURING',     'YES_NO'),
    ('MANURE_PLACEMENT',    'Fertilizer placed in correct zone',            'MANURING',     'RATING_1_5'),
    ('SPRAY_COVERAGE',      'Spray coverage adequate',                      'SPRAYING',     'RATING_1_5'),
    ('SPRAY_PPE',           'Workers wearing correct PPE',                  'SPRAYING',     'YES_NO'),
    ('NURSERY_HEALTH',      'Nursery plants healthy',                       'NURSERY_OPS',  'RATING_1_5'),
    ('SURVIVAL_RATE',       'Planting survival rate check',                 'REPLANTING',   'NUMERIC'),
    ('ROAD_CONDITION',      'Road surface condition',                       'ROAD_MAINT',   'RATING_1_5');
