---
name: read
description: Read, explore, and search code using the dedicated Read, Glob, and Grep tools instead of shell commands — with the correct single-command fallback for sessions where Glob and Grep are missing. Use this whenever you need to find files, search file contents, understand a codebase, trace how something works, locate a definition, or inspect a file — i.e. any task that starts with "where is", "how does", "find", "look at", "show me", "search for", or "understand". Reach for it BEFORE running bash for exploration, so you avoid cat/head/tail/grep/rg/find/sed/awk and the permission prompts they trigger.
---

# Read

Explore and search with the dedicated tools. They're sandboxed, auto-approved, and don't interrupt the user with permission prompts. Shell equivalents (`cat`, `head`, `tail`, `grep`, `rg`, `find`, `sed`, `awk`, and piped chains) do the same job slower and force the user to approve each call.

## The mapping

| You want to… | Use | Fallback if the tool is absent | Never |
|---|---|---|---|
| Find files by name/path | **Glob** (`**/*.py`, `src/**/*.tsx`) | `find path -name "*.py"`, `ls -la path` | `ls -R`, piped chains |
| Search file contents | **Grep** (regex, `-A`/`-B` context, `type` filter) | `grep -rn --no-ignore-files "pat" path` | `rg`, `awk`, `grep \| grep` |
| Read a file | **Read** (whole file, or `offset`/`limit`) | none needed — Read is always available | `cat`, `head`, `tail`, `sed -n` |

## Check what you actually have

Glob and Grep are missing from some sessions; Read never is. A missing tool returns `No such tool available: Grep`, not a permission prompt.

This is not something settings can fix. `permissions.allow`/`deny` control *approval*, not *existence* — a denied tool still appears in the toolset and errors when invoked, while a missing one was never loaded at session start. Don't go editing `claude-settings-global.json` to chase it; it already allows both.

So: use Glob/Grep when they're there. When they aren't, drop to the fallback column above without narrating the discovery each time.

## How to work

1. **Start broad, then narrow.** Find candidate files, locate the relevant lines, then Read them in context. Chain the tools, not shell pipes.
2. **Read the whole file** unless it's huge. Don't `head` the first 20 lines with an `offset` guess — you'll miss context and re-read anyway.
3. **Let the search tool do the filtering.** Grep takes regex, path globs, file-type filters, and surrounding-line context. You rarely need to post-process its output.
4. **Batch independent lookups.** Fire off several calls in one turn when they don't depend on each other.

## Fallback rules

When you're on shell commands, the constraints from CLAUDE.md still bind — they're what keep the permission prompts down:

- **One plain command per Bash call.** No `&&`, no `;`, no pipes, no `$(...)`.
- **Always `--no-ignore-files` on `grep`.** The shell's `grep` is a ugrep shim run with `--ignore-files`, so a recursive search silently skips gitignored paths and reports nothing rather than erroring. In AgentAlamo that hides `scripts-local/`, `skills-local/`, `shell-config/`, `backup/`, `research/`, and `CLAUDE.md`.
- **Quote your globs.** This shell is zsh with `nomatch`: an unquoted `--include=*.sh` that matches nothing kills the whole command.
- **Never write a script to read or search.** No `python -c`, no heredoc, no node one-liner. A missing Grep is a reason to run `grep`, never a reason to write a program.

## When shell is still right

Bash is the right tool for *running* things — tests, builds, git, package managers, scripts. This skill is about *reading and searching*, where the dedicated tools win when present and a single plain command wins when they don't.
