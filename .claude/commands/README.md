# .claude/commands/ — RPMS Design Repo Slash Commands

## Installation

Copy this entire folder into your `rpms-design` repository:

```bash
cp -r claude-commands/ /path/to/rpms-design/.claude/commands/
```

Your `.claude/` directory should then look like:

```
rpms-design/.claude/
├── settings.json              ← already exists (permissions + hooks)
├── hooks/                     ← already exists (guardrail scripts)
│   ├── pre-write-block-source-files.mjs
│   ├── pre-edit-protect-finalized.mjs
│   └── pre-bash-safety.mjs
└── commands/                  ← NEW — slash commands
    ├── review.md              → /review
    ├── api-contract.md        → /api-contract
    ├── avro-event.md          → /avro-event
    ├── flyway.md              → /flyway
    ├── adr.md                 → /adr
    ├── document.md            → /document
    ├── status.md              → /status
    ├── validate.md            → /validate
    ├── cross-refs.md          → /cross-refs
    ├── keycloak.md            → /keycloak
    ├── impact.md              → /impact
    ├── wireframe.md           → /wireframe
    └── next.md                → /next
```

## Command Reference

### Core Workflow Commands

| Command | Purpose | Example Usage |
|---------|---------|---------------|
| `/next` | Auto-detect and start the highest-priority task | Type `/next` — it scans the repo and begins work |
| `/status` | Full project status report across all artifacts | Type `/status` to see what's done and what's pending |
| `/review` | Review a design artifact for convention violations | `/review api-contracts/tree-service-openapi.yaml` |
| `/validate` | Cross-check all artifacts for consistency | Type `/validate` or `/validate M3` for one module |

### Generation Commands

| Command | Purpose | Output Location |
|---------|---------|-----------------|
| `/api-contract` | Generate OpenAPI 3.0 spec for a module | `api-contracts/{module}-service-openapi.yaml` |
| `/avro-event` | Generate Avro event schemas for a module | `api-contracts/events/{module}/` |
| `/flyway` | Split DDL into Flyway migration scripts | `database/migrations/V{N}_xxx` |
| `/adr` | Create a new Architecture Decision Record | `architecture/architecture-decisions/ADR-{NNN}-*.md` |
| `/keycloak` | Design Keycloak realm and permission matrix | `docs/security/` |
| `/wireframe` | Generate wireframe specifications for screens | `wireframes/module-{N}-*/` |

### Analysis Commands

| Command | Purpose | Output Location |
|---------|---------|-----------------|
| `/document` | Auto-generate README for a module's schema | `database/module-N-*/README.md` |
| `/cross-refs` | Analyze cross-module FK and event dependencies | `docs/dependencies/` |
| `/impact` | Blast radius analysis for a schema change | `docs/impact-analysis/` |

## How Slash Commands Work

In Claude Code, type `/` followed by the command name. The markdown file's contents become the prompt instructions. You can also append context:

```
/api-contract M3
/review api-contracts/tree-service-openapi.yaml
/impact add sustainability_score to tapping_task
/flyway M2
```

All commands follow the conventions defined in CLAUDE.md and enforce the rules from the hooks in settings.json.
