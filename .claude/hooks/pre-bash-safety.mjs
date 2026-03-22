#!/usr/bin/env node
// Block destructive bash commands in the design repo.
// Exit 0 = allow, Exit 2 = block.

const input = [];
process.stdin.on("data", (chunk) => input.push(chunk));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input.join(""));
    const cmd = data.tool_input?.command || "";
    if (!cmd) process.exit(0);

    // Block rm -rf
    if (/rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive)\s/.test(cmd)) {
      process.stderr.write(
        `BLOCKED: 'rm -rf' is not allowed. Use 'git restore' to revert changes ` +
          `or 'git clean' to remove untracked files.\n`
      );
      process.exit(2);
    }

    // Block force push
    if (/git\s+push.*--force|git\s+push.*-f\b/.test(cmd)) {
      process.stderr.write(
        `BLOCKED: Force push is not allowed on rpms-design. ` +
          `Use normal push or create a PR.\n`
      );
      process.exit(2);
    }

    // Block git reset --hard
    if (/git\s+reset\s+--hard/.test(cmd)) {
      process.stderr.write(
        `BLOCKED: 'git reset --hard' is not allowed. ` +
          `Use 'git stash' or 'git restore' for safer alternatives.\n`
      );
      process.exit(2);
    }

    // Block deleting existing design artifacts
    if (/rm\s.*\.(sql|html|mermaid|md|yaml|yml|avsc)\b/.test(cmd)) {
      process.stderr.write(
        `BLOCKED: Cannot delete design artifacts. These files are version-controlled ` +
          `deliverables. Use 'git restore' if you need to revert changes.\n`
      );
      process.exit(2);
    }

    process.exit(0);
  } catch {
    process.exit(0);
  }
});
