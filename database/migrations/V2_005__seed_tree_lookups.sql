-- ============================================================================
-- V2_005 — Module 2 (Tree Records & Tracking) — Seed lookup data
-- Source: database/module-2-tree-records/tree_records_tracking_ddl.sql
-- ============================================================================

INSERT INTO lu_tree_status (status_code, status_name, is_tappable, display_order, description) VALUES
    ('SEEDLING',    'Seedling',                 FALSE,  1,  'Recently planted seedling, less than 6 months'),
    ('IMMATURE',    'Immature / Growing',       FALSE,  2,  'Growing tree, not yet reached tappable girth'),
    ('TAPPABLE',    'Tappable / Mature',        TRUE,   3,  'Reached minimum girth (>=50cm), ready for tapping'),
    ('TAPPING',     'Under Active Tapping',     TRUE,   4,  'Currently being tapped for latex'),
    ('RESTING',     'Resting / Tapping Holiday', FALSE, 5,  'Temporarily rested from tapping (wintering, stress)'),
    ('DISEASED',    'Diseased (Not Tapping)',   FALSE,  6,  'Removed from tapping due to disease'),
    ('WIND_DAMAGE', 'Wind Damaged',             FALSE,  7,  'Partially or fully damaged by wind'),
    ('DEAD',        'Dead',                     FALSE,  8,  'Tree is dead — logged for mortality records'),
    ('REMOVED',     'Removed / Felled',         FALSE,  9,  'Physically removed from the field');

INSERT INTO lu_health_rating (rating_code, rating_name, rating_score, description) VALUES
    ('EXCELLENT',   'Excellent',    5,  'Vigorous growth, no visible issues, full canopy'),
    ('GOOD',        'Good',         4,  'Healthy with minor cosmetic issues'),
    ('FAIR',        'Fair',         3,  'Some stress indicators — reduced canopy, minor bark issues'),
    ('POOR',        'Poor',         2,  'Significant stress — thinning canopy, bark disease, low yield'),
    ('CRITICAL',    'Critical',     1,  'Severe condition — major disease, structural damage, near death');

INSERT INTO disease_master (disease_code, disease_name, disease_type, causal_agent, affected_part, severity_class, symptoms) VALUES
    ('TPD',         'Tapping Panel Dryness',                'PHYSIOLOGICAL', NULL,                           'PANEL',    'HIGH',     'Partial or complete cessation of latex flow on tapping cut'),
    ('WHITE_ROOT',  'White Root Disease',                   'FUNGAL',        'Rigidoporus microporus',       'ROOT',     'CRITICAL', 'Yellowing leaves, die-back, white mycelial fans on roots'),
    ('BROWN_ROOT',  'Brown Root Disease',                   'FUNGAL',        'Phellinus noxius',             'ROOT',     'CRITICAL', 'Browning and hardening of roots, gradual canopy thinning'),
    ('PINK_DISEASE','Pink Disease',                         'FUNGAL',        'Corticium salmonicolor',       'BARK',     'MEDIUM',   'Pinkish-white encrustation on branches, bark cracking'),
    ('ABNORMAL_LF', 'Abnormal Leaf Fall',                   'FUNGAL',        'Phytophthora spp.',            'LEAF',     'HIGH',     'Premature and severe defoliation during wet season'),
    ('POWDERY_MLW', 'Powdery Mildew',                       'FUNGAL',        'Oidium heveae',                'LEAF',     'MEDIUM',   'White powdery coating on young leaves, leaf distortion'),
    ('BARK_ROT',    'Bark Rot / Black Stripe',              'FUNGAL',        'Phytophthora palmivora',       'PANEL',    'HIGH',     'Black necrotic streaks on tapping panel, bark rot'),
    ('TERMITE',     'Termite Attack',                       'PEST',          'Coptotermes spp.',             'BARK',     'MEDIUM',   'Mud tubes on trunk, hollowed internal wood'),
    ('SHOT_HOLE',   'Shot Hole Disease',                    'FUNGAL',        'Drechslera heveae',            'LEAF',     'LOW',      'Small circular holes with brown margins on mature leaves'),
    ('NUTRIENT_N',  'Nitrogen Deficiency',                  'NUTRIENT_DEFICIENCY', NULL,                     'LEAF',     'LOW',      'Uniform yellowing of older leaves, stunted growth');

INSERT INTO lu_treatment_type (treatment_code, treatment_name, treatment_class, application_method) VALUES
    ('TRIDEMORPH',      'Tridemorph Application',       'FUNGICIDE',    'PAINT/SPRAY'),
    ('HEXACONAZOLE',    'Hexaconazole Application',     'FUNGICIDE',    'SPRAY'),
    ('SULPHUR_DUST',    'Sulphur Dusting',              'FUNGICIDE',    'DUSTING'),
    ('ETHEPHON',        'Ethephon Stimulation',          'STIMULANT',    'PAINT'),
    ('BORDEAUX_PASTE',  'Bordeaux Paste Application',    'WOUND_CARE',   'PAINT'),
    ('NPK_FERT',       'NPK Fertilizer Application',   'FERTILIZER',   'GRANULAR'),
    ('UREA',           'Urea Application',             'FERTILIZER',   'GRANULAR'),
    ('ROOT_SURGERY',   'Root Surgery & Removal',        'SURGICAL',     'MANUAL'),
    ('BIO_CONTROL',    'Trichoderma Biological Control','BIOLOGICAL',   'SOIL_APPLICATION'),
    ('FIPRONIL',       'Fipronil Termite Treatment',    'INSECTICIDE',  'INJECTION');

INSERT INTO lu_growth_parameter (parameter_code, parameter_name, unit_of_measure, description, min_threshold) VALUES
    ('GIRTH',           'Trunk Girth at 150cm',         'cm',       'Circumference measured at 150cm from ground (bud union)', 50),
    ('BARK_THICKNESS',  'Virgin Bark Thickness',        'mm',       'Bark thickness on untapped panel', NULL),
    ('BARK_RENEWAL',    'Renewed Bark Thickness',        'mm',       'Bark thickness on previously tapped (renewed) panel', NULL),
    ('TREE_HEIGHT',     'Tree Height',                  'm',        'Total height from ground to crown apex', NULL),
    ('CANOPY_DIAMETER', 'Canopy Diameter',              'm',        'Maximum canopy spread', NULL),
    ('BRANCH_COUNT',    'Primary Branch Count',         'count',    'Number of primary branches from trunk', NULL),
    ('BARK_CONSUMPTION','Bark Consumption Percentage',   '%',        'Percentage of total bark consumed by tapping', NULL),
    ('LATEX_YIELD',     'Single Tree Latex Yield',       'ml',       'Volume of latex per single tapping', NULL);

INSERT INTO lu_tag_type (tag_type_code, tag_type_name, technology, read_range_m) VALUES
    ('NFC_TAG',     'NFC Tree Tag',             'NFC',          0.05),
    ('RFID_UHF',    'UHF RFID Tag',             'RFID',         10.00),
    ('RFID_HF',     'HF RFID Tag',              'RFID',         1.00),
    ('QR_PLATE',    'QR Code Metal Plate',       'QR',           NULL),
    ('BLE_BEACON',  'Bluetooth Low Energy Beacon','BLE_BEACON',  30.00);

INSERT INTO lu_mortality_cause (cause_code, cause_name, cause_category) VALUES
    ('WIND_FALL',       'Wind Throw / Toppling',        'WEATHER'),
    ('LIGHTNING',       'Lightning Strike',             'WEATHER'),
    ('DROUGHT',         'Drought Stress Death',         'WEATHER'),
    ('WHITE_ROOT_MORT', 'White Root Disease Mortality',  'DISEASE'),
    ('BROWN_ROOT_MORT', 'Brown Root Disease Mortality',  'DISEASE'),
    ('BARK_ROT_MORT',   'Severe Bark Rot / Panel Death','DISEASE'),
    ('TERMITE_MORT',    'Severe Termite Damage',        'PEST'),
    ('OVER_TAPPING',    'Death from Over-Exploitation',  'HUMAN'),
    ('ACCIDENTAL',      'Accidental Damage (Machinery)','HUMAN'),
    ('AGE_SENESCENCE',  'Natural Senescence / Old Age',  'NATURAL'),
    ('UNKNOWN',         'Unknown / Undetermined',        'UNKNOWN');
