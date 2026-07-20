## Repositories

- All repositories live in `~/Workspace/`. When a repository is referenced by name, it refers to `~/Workspace/<name>/`.
- To discover available repositories, run `ls ~/Workspace/`.
- When running python tests and mypy use `uv run ...` commands
- Write the bare minimum number of comments. Do not write comments.

## Code references
When referencing code, use a single line number, not a range: `path/to/file.py:89`, not `path/to/file.py:89-105`. Line ranges break clickable-link detection in the terminal.

## Plan Mode

- Default to TDD, start by making the test, confirm it fails, then at the end confirm it passes.

## UI Code

- Use the `Text` component instead of `<p>` or `<span>` HTML elements in TypeScript UI code.

## Scripts

- When writing scripts that store data, perserve the data with a short file path and print the file path at end of execution.

## Running Commands

- Use simple `pnpm run <script>` and `uv run <command>` invocations. Do not add `NODE_OPTIONS`, pipe chains, `grep` filters, `head`, `2>&1`, or other shell complexity. Run the command as-is and read the full output.

## Tool Usage

- ALWAYS: use the dedicated tools: Glob (find files), Grep (search content), Read (read files). Do not use `grep`, `rg`, `find`, `cat`, `head`, `tail`, `sed`, `awk`, or piped shell commands for these tasks. These dedicated tools are sandboxed, auto-approved, and easier to review.
- NEVER use git stash
- When spawning subagents (Agent tool), always include in the prompt: "Use the Read tool to read files, Glob to find files, and Grep to search content. Do NOT use cat, head, tail, grep, rg, find, or any bash equivalents for these tasks."
- Explore agents (and any exploration/search subagent) should follow the `read` skill: use the dedicated Read, Glob, and Grep tools for all file reading and searching, never shell equivalents.

## After a session

- When a working session wraps up, suggest running the `improve` skill (`/improve`). It reviews the session, proposes safe permission allow-rules for commands that made the user re-approve, and captures the user's feedback into CLAUDE.md or the relevant skill — so the next session has less friction. Only a suggestion; the user decides.
