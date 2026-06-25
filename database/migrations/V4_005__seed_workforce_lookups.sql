-- ============================================================================
-- V4_005 — Module 4 (Workforce Management) — Seed lookup data
-- Source: database/module-4-workforce/workforce_management_ddl.sql
-- ============================================================================

INSERT INTO lu_worker_category (category_code, category_name, category_group, description) VALUES
    ('TAPPER',          'Rubber Tapper',                'FIELD',            'Primary tapping worker — taps and collects field latex'),
    ('TAPPER_SENIOR',   'Senior Tapper / Lead Tapper',  'FIELD',            'Experienced tapper who leads a tapping gang'),
    ('FIELD_COLLECTOR', 'Latex Collector',               'FIELD',            'Collects latex from cups and transports to collection point'),
    ('FIELD_MAINT',     'Field Maintenance Worker',      'FIELD',            'Weeding, manuring, spraying, road clearing'),
    ('NURSERY_WORKER',  'Nursery Worker',                'FIELD',            'Nursery planting, budding, maintenance'),
    ('PEST_CONTROL',    'Pest & Disease Control Worker', 'FIELD',            'Disease scouting, chemical application, treatment'),
    ('HARVESTER',       'Timber / Replanting Worker',    'FIELD',            'Felling, clearing, replanting operations'),
    ('FACTORY_OPS',     'Factory Operator',              'FACTORY',          'Latex processing, sheet making, smoking, packing'),
    ('QUALITY_INSP',    'Quality Inspector',             'FACTORY',          'DRC testing, latex grading, quality checks'),
    ('DRIVER',          'Driver / Transport',            'SUPPORT',          'Vehicle driver — latex transport, personnel'),
    ('MECHANIC',        'Mechanic / Equipment Tech',     'TECHNICAL',        'Vehicle and equipment maintenance'),
    ('CLERK',           'Administrative Clerk',          'ADMINISTRATIVE',   'Record keeping, data entry, filing'),
    ('CONDUCTOR',       'Field Conductor / Supervisor',  'MANAGEMENT',       'Supervises a division or group of fields'),
    ('ASST_MANAGER',    'Assistant Manager',             'MANAGEMENT',       'Division-level management'),
    ('MANAGER',         'Estate Manager',                'MANAGEMENT',       'Overall plantation management');

INSERT INTO lu_employment_type (employment_type_code, employment_type_name, description) VALUES
    ('PERMANENT',   'Permanent / Regular',              'Full-time regular employee with benefits'),
    ('CONTRACT',    'Contract Worker',                  'Fixed-term contract employment'),
    ('DAILY_WAGE',  'Daily Wage / Casual',              'Paid per day of work — no fixed contract'),
    ('SEASONAL',    'Seasonal Worker',                  'Employed for specific seasons (e.g., tapping, replanting)'),
    ('PIECE_RATE',  'Piece Rate / Output-Based',        'Paid based on output (kg latex, trees tapped)'),
    ('TRAINEE',     'Trainee / Apprentice',             'Under training program before becoming regular');

INSERT INTO lu_worker_status (status_code, status_name, is_active_duty, description) VALUES
    ('ACTIVE',          'Active / On Duty',         TRUE,   'Currently employed and working'),
    ('ON_LEAVE',        'On Approved Leave',        FALSE,  'On sanctioned leave (annual, sick, maternity, etc.)'),
    ('SUSPENDED',       'Suspended',                FALSE,  'Temporarily suspended pending investigation'),
    ('TRAINING',        'Under Training',           TRUE,   'Active but in training program'),
    ('PROBATION',       'On Probation',             TRUE,   'Within probation period'),
    ('TRANSFERRED',     'Transferred Out',          FALSE,  'Transferred to another plantation'),
    ('RESIGNED',        'Resigned',                 FALSE,  'Voluntarily left employment'),
    ('TERMINATED',      'Terminated',               FALSE,  'Employment terminated by management'),
    ('RETIRED',         'Retired',                  FALSE,  'Retired from service'),
    ('DECEASED',        'Deceased',                 FALSE,  'Worker deceased');

INSERT INTO lu_skill (skill_code, skill_name, skill_category) VALUES
    ('TAP_S2',          'Half-Spiral Tapping (S/2)',            'TAPPING'),
    ('TAP_S4',          'Quarter-Spiral Tapping (S/4)',         'TAPPING'),
    ('TAP_HIGH_PANEL',  'High Panel Tapping',                   'TAPPING'),
    ('TAP_STIMULANT',   'Ethephon Stimulant Application',       'TAPPING'),
    ('BUDDING',         'Bud Grafting / Budding',               'NURSERY'),
    ('MARCOTTING',      'Marcotting / Air Layering',            'NURSERY'),
    ('CHAINSAW',        'Chainsaw Operation',                   'MACHINERY'),
    ('TRACTOR',         'Tractor / Vehicle Operation',          'MACHINERY'),
    ('SPRAYING',        'Chemical Spraying (Certified)',         'FIELD_OPS'),
    ('MANURING',        'Fertilizer Application',               'FIELD_OPS'),
    ('DRC_TESTING',     'DRC / Latex Quality Testing',          'QUALITY'),
    ('FIRST_AID',       'First Aid Certification',              'SAFETY'),
    ('FIRE_SAFETY',     'Fire Safety Training',                 'SAFETY'),
    ('FACTORY_OPS',     'Latex Processing Operations',          'FACTORY'),
    ('TEAM_LEAD',       'Team Leadership / Supervision',        'SUPERVISORY'),
    ('NFC_MOBILE',      'NFC Scanning & Mobile App Usage',      'IT');

INSERT INTO lu_proficiency_level (level_code, level_name, level_score, description) VALUES
    ('NOVICE',          'Novice',           1,  'Basic awareness, needs supervision'),
    ('BEGINNER',        'Beginner',         2,  'Can perform with guidance'),
    ('COMPETENT',       'Competent',        3,  'Independently capable'),
    ('PROFICIENT',      'Proficient',       4,  'High quality, can train others'),
    ('EXPERT',          'Expert',           5,  'Master level, can innovate and lead');

INSERT INTO lu_leave_type (leave_type_code, leave_type_name, is_paid, max_days_per_year, requires_medical_cert) VALUES
    ('ANNUAL',      'Annual Leave',             TRUE,   14,     FALSE),
    ('SICK',        'Sick Leave',               TRUE,   14,     TRUE),
    ('CASUAL',      'Casual Leave',             TRUE,   7,      FALSE),
    ('MATERNITY',   'Maternity Leave',          TRUE,   84,     TRUE),
    ('PATERNITY',   'Paternity Leave',          TRUE,   7,      FALSE),
    ('INJURY',      'Work Injury Leave',        TRUE,   NULL,   TRUE),
    ('UNPAID',      'Unpaid Leave',             FALSE,  30,     FALSE),
    ('COMPASSION',  'Compassionate Leave',      TRUE,   5,      FALSE),
    ('TRAINING',    'Training Leave',           TRUE,   NULL,   FALSE),
    ('PUBLIC_HOL',  'Public Holiday',           TRUE,   NULL,   FALSE);

INSERT INTO lu_relationship_type (relationship_code, relationship_name) VALUES
    ('SPOUSE',      'Spouse'),
    ('CHILD',       'Child'),
    ('PARENT',      'Parent'),
    ('SIBLING',     'Sibling'),
    ('GUARDIAN',    'Guardian'),
    ('OTHER',       'Other');

INSERT INTO lu_document_type (doc_type_code, doc_type_name, is_mandatory, validity_months) VALUES
    ('NIC',             'National ID Card',                 TRUE,   NULL),
    ('PASSPORT',        'Passport',                         FALSE,  120),
    ('WORK_PERMIT',     'Work Permit / Visa',               FALSE,  12),
    ('DRIVING_LIC',     'Driving License',                  FALSE,  60),
    ('MEDICAL_CERT',    'Medical Fitness Certificate',       TRUE,   12),
    ('POLICE_CLEAR',    'Police Clearance',                 FALSE,  12),
    ('BANK_DETAILS',    'Bank Account Details',             TRUE,   NULL),
    ('TAX_REG',         'Tax Registration / TIN',           FALSE,  NULL),
    ('PHOTO',           'Passport-Size Photo',              TRUE,   NULL),
    ('CONTRACT',        'Employment Contract Copy',         TRUE,   NULL),
    ('SPRAY_CERT',      'Chemical Handling Certificate',     FALSE,  24),
    ('CHAINSAW_CERT',   'Chainsaw Operator Certificate',     FALSE,  24),
    ('FIRST_AID_CERT',  'First Aid Certificate',             FALSE,  24);

INSERT INTO lu_pay_component (component_code, component_name, component_type, is_taxable) VALUES
    ('BASIC_SALARY',    'Basic Salary',                 'EARNING',      TRUE),
    ('DAILY_WAGE',      'Daily Wage',                   'EARNING',      TRUE),
    ('PIECE_RATE_PAY',  'Piece Rate / Output Pay',      'EARNING',      TRUE),
    ('OVERTIME',        'Overtime Pay',                 'EARNING',      TRUE),
    ('LATEX_INCENTIVE', 'Latex Yield Incentive',        'BONUS',        TRUE),
    ('QUALITY_BONUS',   'Tapping Quality Bonus',        'BONUS',        TRUE),
    ('ATTENDANCE_BONUS','Attendance Bonus',             'BONUS',        TRUE),
    ('HOUSING_ALLOW',   'Housing Allowance',            'ALLOWANCE',    FALSE),
    ('TRANSPORT_ALLOW', 'Transport Allowance',          'ALLOWANCE',    FALSE),
    ('RAIN_ALLOW',      'Rainy Day Allowance',          'ALLOWANCE',    FALSE),
    ('EPF_DEDUCTION',   'EPF / Provident Fund',         'STATUTORY',    FALSE),
    ('ETF_DEDUCTION',   'ETF / Employment Trust',       'STATUTORY',    FALSE),
    ('TAX_PAYE',        'Income Tax (PAYE)',            'STATUTORY',    FALSE),
    ('LOAN_DEDUCTION',  'Loan Repayment Deduction',     'DEDUCTION',    FALSE),
    ('ADVANCE_DEDUCT',  'Salary Advance Deduction',     'DEDUCTION',    FALSE);

INSERT INTO lu_training_type (training_type_code, training_type_name, category, typical_duration_days, is_mandatory) VALUES
    ('INDUCTION',       'New Employee Induction',               'INDUCTION',    2,  TRUE),
    ('TAP_BASIC',       'Basic Tapping Training',               'TAPPING',      14, TRUE),
    ('TAP_ADVANCED',    'Advanced Tapping Techniques',          'TAPPING',      7,  FALSE),
    ('TAP_HIGH_PANEL',  'High Panel Tapping Training',          'TAPPING',      5,  FALSE),
    ('STIMULANT_APP',   'Ethephon Stimulant Application',       'TECHNICAL',    2,  FALSE),
    ('CHEMICAL_SAFETY', 'Chemical Handling & Safety',           'SAFETY',       2,  TRUE),
    ('FIRST_AID',       'Basic First Aid Training',             'SAFETY',       1,  TRUE),
    ('FIRE_DRILL',      'Fire Safety & Evacuation Drill',       'SAFETY',       1,  TRUE),
    ('SNAKE_AWARE',     'Snake Awareness & First Response',      'SAFETY',       1,  FALSE),
    ('MR_TRAINING',     'AR/MR Tapping Quality Training',        'TECHNICAL',    3,  FALSE),
    ('MOBILE_APP',      'Mobile App & NFC Scanning Training',    'TECHNICAL',    1,  FALSE),
    ('DRC_TESTING',     'DRC & Latex Quality Testing',           'QUALITY',      3,  FALSE),
    ('SUPERVISOR',      'Supervisory Skills Development',        'SUPERVISORY',  5,  FALSE),
    ('REFRESH_TAP',     'Annual Tapping Refresher',              'REFRESHER',    2,  TRUE);