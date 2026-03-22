#!/usr/bin/env node
// Block edits to finalized DDL files and accepted ADRs.
// DDL corrections go through Flyway migrations. Accepted ADRs are immutable.
// Exit 0 = allow, Exit 2 = block.

const input = [];
process.stdin.on("data", (chunk) => input.push(chunk));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input.join(""));
    const filePath = data.tool_input?.file_path || data.tool_input?.path || "";
    if (!filePath) process.exit(0);

    // Normalize path separators for Windows compatibility
    const normalized = filePath.replace(/\\/g, "/");

    // Block edits to finalized DDL files
    if (/database\/module-\d.*_ddl\.sql$/.test(normalized)) {
      process.stderr.write(
        `BLOCKED: Cannot modify finalized DDL file '${filePath}'. ` +
          `DDL files are the finalized schema. To make corrections, create a new Flyway ` +
          `migration script in database/migrations/ with the appropriate module prefix ` +
          `(V1_xxx through V6_xxx).\n`
      );
      process.exit(2);
    }

    // Block edits to accepted ADRs (ADR-001 through ADR-006)
    if (/architecture-decisions\/ADR-00[1-6]/.test(normalized)) {
      process.stderr.write(
        `BLOCKED: Cannot modify accepted ADR '${filePath}'. ` +
          `Accepted ADRs are immutable records. To change a decision, create a new ADR ` +
          `(e.g., ADR-007) that supersedes the existing one.\n`
      );
      process.exit(2);
    }

    process.exit(0);
  } catch {
    process.exit(0);
  }
});
