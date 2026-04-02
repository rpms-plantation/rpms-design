# Create Architecture Decision Record

Create a new ADR following the established format in `architecture/architecture-decisions/`.

## Step 1 — Gather information

Ask for the following (skip any already provided with the command):
1. **Decision title** — What architectural question is being decided? (e.g., "Use Redis for Tree Profile Caching")
2. **Context** — Why does this decision need to be made now? What problem are we solving?
3. **Options** — What alternatives were considered? (minimum 2, ideally 3–4)
4. **Recommendation** — Which option is preferred and why?

## Step 2 — Determine the next ADR number

Read the existing ADRs in `architecture/architecture-decisions/` to find the highest number. The new ADR gets the next sequential number.

Current accepted ADRs:
- ADR-001: PostgreSQL 16 + PostGIS + TimescaleDB + pgvector
- ADR-002: Spring Boot (CRUD) + Quarkus (high-throughput) hybrid
- ADR-003: Apache Kafka + Confluent Schema Registry (Avro)
- ADR-004: Angular 18 for web dashboard
- ADR-005: Kotlin Multiplatform for mobile
- ADR-006: Modular pluggable architecture with shared database

Check for any ADRs beyond 006 that may have been added since this list was written.

## Step 3 — Read an existing ADR for format reference

Read ADR-002 or ADR-003 as a structural template. These are the most detailed and well-formatted examples. Match their depth, section structure, and tone.

## Step 4 — Generate the ADR

Use this exact structure:

```markdown
# ADR-{NNN}: {Title}

- **Date**: {YYYY-MM-DD}
- **Status**: Proposed
- **Deciders**: RPMS Architecture Team
- **Consulted**: {relevant stakeholders}
- **Related**: {ADR-XXX references if applicable}

## Context and Problem Statement

{Detailed context — what problem are we solving, what are the constraints,
what makes this non-trivial. 2-4 paragraphs minimum. Be specific to RPMS.}

## Decision Drivers

1. **{Driver name}** — {One-line explanation}
2. ...
{5-8 drivers, numbered}

## Considered Options

1. **{Option 1 name}** — {One-line summary}
2. **{Option 2 name}** — {One-line summary}
3. **{Option 3 name}** — {One-line summary}

## Decision Outcome

**Chosen option: {Option name}**, because {concise rationale connecting back to decision drivers}.

### Confirmation

This decision will be confirmed successful if:
- {Measurable success criteria}
- ...

## Pros and Cons of the Options

### {Option 1 name} (Selected)

{Brief description of the option}

**Pros:**
- {Detailed pro with RPMS-specific justification}
- ...

**Cons:**
- {Detailed con with RPMS-specific impact}
- ...

### {Option 2 name}

{Same structure as above}

### {Option 3 name}

{Same structure as above}

## Decision Matrix

| Criterion (Weight) | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| {Criterion from drivers} | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| ... | ... | ... | ... |
| **Weighted Score** | **Highest** | **Mid** | **Low** |

## Consequences

### Positive
- {Concrete positive outcome for RPMS}
- ...

### Negative
- {Concrete negative outcome, with mitigation}
- ...

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| {Risk} | Low/Medium/High | Low/Medium/High | {Mitigation strategy} |
| ... | ... | ... | ... |

## Links

- **Related ADRs**: {links}
- **Design artifacts**: {links to relevant architecture docs}
- **External references**: {links to relevant documentation}
```

## Step 5 — Important rules

- Status is always `Proposed` for new ADRs (the team accepts it after review)
- NEVER modify existing accepted ADRs — if this decision supersedes one, add `Supersedes: ADR-XXX` to the header and note it in the old ADR's status
- Be specific to RPMS — reference actual table names, module numbers, service names, not generic examples
- Decision matrix must use the same criteria as the decision drivers
- Every con must include a mitigation strategy

## Step 6 — Output

Write to: `architecture/architecture-decisions/ADR-{NNN}-{kebab-case-title}.md`
