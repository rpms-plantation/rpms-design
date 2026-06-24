#!/usr/bin/env bash
# Block edits to finalized DDL files and accepted ADRs.
# DDL corrections should go through Flyway migrations, not DDL edits.
# Accepted ADRs should never be modified — create a new superseding ADR instead.
# Exit 0 = allow, Exit 2 = block.
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Block edits to finalized DDL files
if echo "$FILE_PATH" | grep -qE 'database/module-[0-9].*_ddl\.sql$'; then
  echo "BLOCKED: Cannot modify finalized DDL file '$FILE_PATH'. DDL files are the finalized schema. To make corrections, create a new Flyway migration script in database/migrations/ with the appropriate module prefix (V1_xxx through V6_xxx)." >&2
  exit 2
fi

# Block edits to accepted ADRs (ADR-001 through ADR-006 are accepted)
if echo "$FILE_PATH" | grep -qE 'architecture-decisions/ADR-00[1-6]'; then
  echo "BLOCKED: Cannot modify accepted ADR '$FILE_PATH'. Accepted ADRs are immutable records. To change a decision, create a new ADR (e.g., ADR-007) that supersedes the existing one." >&2
  exit 2
fi

exit 0
