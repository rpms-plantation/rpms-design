#!/usr/bin/env bash
# Block creation of application source files in the design-only repo.
# Exit 0 = allow, Exit 2 = block (message on stderr sent to Claude).
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Block application source code files
BLOCKED_PATTERN='\.(java|kt|kts|scala|py|ts|tsx|js|jsx|vue|svelte|go|rs|rb|cs|swift|dart|groovy)$'
if echo "$FILE_PATH" | grep -qiE "$BLOCKED_PATTERN"; then
  # Allow TypeScript ONLY in api-contracts/ (OpenAPI generators may produce .ts types)
  if echo "$FILE_PATH" | grep -q "api-contracts/"; then
    exit 0
  fi
  echo "BLOCKED: Cannot create application source file '$FILE_PATH' in rpms-design. This repo is for design artifacts only (SQL, YAML, Markdown, HTML, Mermaid). Application code belongs in rpms-mod-* or rpms-platform repos." >&2
  exit 2
fi

# Block build/config files that belong in implementation repos
BUILD_PATTERN='(pom\.xml|build\.gradle|package\.json|Dockerfile|docker-compose|Makefile|Cargo\.toml|go\.mod|settings\.gradle|\.github/workflows/)' 
if echo "$FILE_PATH" | grep -qiE "$BUILD_PATTERN"; then
  echo "BLOCKED: Cannot create build/config file '$FILE_PATH' in rpms-design. Build files belong in rpms-mod-* or rpms-platform repos." >&2
  exit 2
fi

exit 0
