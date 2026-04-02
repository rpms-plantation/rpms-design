# Design Keycloak Realm & Permissions

Generate the Keycloak realm configuration and role-permission matrix for RPMS.

## Step 1 — Load references

1. Read CLAUDE.md for the role list: `SYSTEM_ADMIN`, `ESTATE_MANAGER`, `DIVISION_CONDUCTOR`, `FIELD_SUPERVISOR`, `TAPPER`, `COLLECTOR`, `CLERK`
2. Read each module's OpenAPI spec (if available) to enumerate all endpoints
3. Read each module's DDL to understand which entities each role interacts with

## Step 2 — Define the role hierarchy

```
SYSTEM_ADMIN          ← full access to everything
├── ESTATE_MANAGER    ← full access within their plantation(s)
│   ├── DIVISION_CONDUCTOR  ← access within their division(s)
│   │   ├── FIELD_SUPERVISOR  ← access within their field(s)
│   │   │   ├── TAPPER          ← own tasks, own attendance, own trees
│   │   │   └── COLLECTOR       ← collection records, quality tests
│   │   └── CLERK              ← data entry, reports within division
```

## Step 3 — Generate the permission matrix

Create a matrix mapping every API endpoint to allowed roles:

```markdown
| Endpoint | Method | SYSTEM_ADMIN | ESTATE_MGR | DIV_CONDUCTOR | FIELD_SUPER | TAPPER | COLLECTOR | CLERK |
|----------|--------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| /api/plantation/plantations | GET | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| /api/plantation/plantations | POST | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| /api/plantation/plantations/{id} | PUT | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ... |
```

### Permission principles:
- **Data isolation**: Users see only data for their assigned plantation/division/field
- **Read-wide, write-narrow**: Most roles can read broadly; write access is restricted to their scope
- **TAPPER**: Can only interact with their own assigned tasks, their own attendance, scan tree tags
- **FIELD_SUPERVISOR**: Can assign tasks, approve attendance, inspect activities within their field(s)
- **DIVISION_CONDUCTOR**: Can manage all fields within their division, approve leave, view division reports
- **ESTATE_MANAGER**: Full control within their plantation, manage workforce, approve transfers
- **SYSTEM_ADMIN**: Cross-plantation access, system configuration, user management
- **CLERK**: Data entry and report generation, no approval authority
- **COLLECTOR**: Latex collection records, quality testing, weigh-bridge data

## Step 4 — Generate Keycloak realm JSON skeleton

Output a realm configuration including:
- Realm name: `rpms`
- Client: `rpms-web` (Angular dashboard — public client, PKCE)
- Client: `rpms-mobile` (Android app — public client, PKCE)
- Client: `rpms-api-gateway` (confidential client — service account)
- Roles: realm-level roles matching the hierarchy above
- Custom JWT claims: `plantation_id`, `division_id`, `field_ids[]` for data isolation
- Token lifespan: access=15min, refresh=8hrs (field workers need long sessions)

## Step 5 — Output

Write to:
- `docs/security/keycloak-realm-design.md` — the full permission matrix and design rationale
- `docs/security/rpms-realm.json` — Keycloak realm export skeleton (importable)
