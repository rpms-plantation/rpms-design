#!/usr/bin/env node
// Block creation of application source files in the design-only repo.
// Exit 0 = allow, Exit 2 = block (stderr message sent to Claude).

const input = [];
process.stdin.on("data", (chunk) => input.push(chunk));
process.stdin.on("end", () => {
  try {
    const data = JSON.parse(input.join(""));
    const filePath = data.tool_input?.file_path || data.tool_input?.path || "";
    if (!filePath) process.exit(0);

    // Block application source code files
    const blockedExts =
      /\.(java|kt|kts|scala|py|ts|tsx|js|jsx|vue|svelte|go|rs|rb|cs|swift|dart|groovy)$/i;
    if (blockedExts.test(filePath)) {
      // Allow TypeScript only inside api-contracts/ (OpenAPI generators may produce .ts types)
      if (filePath.includes("api-contracts/")) process.exit(0);
      process.stderr.write(
        `BLOCKED: Cannot create application source file '${filePath}' in rpms-design. ` +
          `This repo is for design artifacts only (SQL, YAML, Markdown, HTML, Mermaid). ` +
          `Application code belongs in rpms-mod-* or rpms-platform repos.\n`
      );
      process.exit(2);
    }

    // Block build/config files that belong in implementation repos
    const buildPatterns =
      /(pom\.xml|build\.gradle|package\.json|Dockerfile|docker-compose|Makefile|Cargo\.toml|go\.mod|settings\.gradle|\.github[/\\]workflows[/\\])/i;
    if (buildPatterns.test(filePath)) {
      process.stderr.write(
        `BLOCKED: Cannot create build/config file '${filePath}' in rpms-design. ` +
          `Build files belong in rpms-mod-* or rpms-platform repos.\n`
      );
      process.exit(2);
    }

    process.exit(0);
  } catch {
    process.exit(0);
  }
});
