# AgentAlamo

Dotfiles and Claude Code config repo. Most of the interesting files here are gitignored, which changes how you have to search.

## Searching this repo

- ALWAYS pass `--no-ignore-files` to bash `grep`: `grep -rn --no-ignore-files "pat" path`. Claude Code injects a `grep` shim into the shell snapshot that execs bundled ugrep with `--ignore-files`, so a plain recursive search silently skips gitignored paths and reports nothing rather than erroring.
- These directories are gitignored and invisible to a plain `grep`, and they hold most of what you will be asked to edit: `scripts-local/`, `skills-local/`, `shell-config/`, `backup/`, `research/`, `archived-plans/`, and the root `CLAUDE-global.md`.
- `command grep -rn ...` also bypasses the shim but drops `--hidden`. Prefer `--no-ignore-files`.
- `respectGitignore: false` is set in `.claude/settings.json` so Grep and Glob should see the gitignored paths here. It is unverified whether that setting reaches those tools or only the `@` file picker, so if such a call comes back empty for a path you know exists, fall back to `grep -rn --no-ignore-files` rather than trusting the empty result.
- Glob and Grep are missing from some sessions entirely (`No such tool available: Grep`); Read always works. That is a harness-level toolset decision, not a permissions one — `claude-settings-global.json` allows both and nothing denies them, so no settings edit brings them back. Use `grep -rn --no-ignore-files "pat" path` to search and `find path -name "..."` to locate files, one plain command per call.

## Layout

- `claude-settings-global.json` — symlinked to `~/.claude/settings.json` by `setup.sh`.
- `CLAUDE-global.md` (root) — symlinked to `~/.claude/CLAUDE.md` by `setup.sh`; global instructions for every project. Repo-specific rules belong in this file instead.
- `scripts-local/`, `scripts-global/` — shell functions sourced from `shell-config/zshrc`.
- `skills-local/`, `skills-global/` — symlinked into `~/.claude/skills/` by `install.sh`.
