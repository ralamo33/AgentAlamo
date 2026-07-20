---
name: read
description: Read, explore, and search code using the dedicated Read, Glob, and Grep tools instead of shell commands. Use this whenever you need to find files, search file contents, understand a codebase, trace how something works, locate a definition, or inspect a file — i.e. any task that starts with "where is", "how does", "find", "look at", "show me", "search for", or "understand". Reach for it BEFORE running bash for exploration, so you avoid cat/head/tail/grep/rg/find/sed/awk and the permission prompts they trigger.
---

# Read

Explore and search with the dedicated tools. They're sandboxed, auto-approved, and don't interrupt the user with permission prompts. Shell equivalents (`cat`, `head`, `tail`, `grep`, `rg`, `find`, `sed`, `awk`, and piped chains) do the same job slower and force the user to approve each call.

## The mapping

| You want to… | Use | Not |
|---|---|---|
| Find files by name/path | **Glob** (`**/*.py`, `src/**/*.tsx`) | `find`, `ls -R` |
| Search file contents | **Grep** (regex, `-A`/`-B` context, `type` filter) | `grep`, `rg`, `awk` |
| Read a file | **Read** (whole file, or `offset`/`limit`) | `cat`, `head`, `tail`, `sed -n` |

## How to work

1. **Start broad, then narrow.** Glob to find candidate files, Grep to locate the relevant lines, Read to see them in context. Chain the tools, not shell pipes.
2. **Read the whole file** unless it's huge. Don't `head` the first 20 lines with an `offset` guess — you'll miss context and re-read anyway.
3. **Let Grep do the filtering.** It takes regex, path globs, file-type filters, and surrounding-line context. You rarely need to post-process its output.
4. **Batch independent lookups.** Fire off several Glob/Grep/Read calls in one turn when they don't depend on each other.

## When shell is still right

Bash is the right tool for *running* things — tests, builds, git, package managers, scripts. This skill is about *reading and searching*, where the dedicated tools win. If you catch yourself reaching for `cat`/`grep`/`find` to inspect the code, switch to Read/Grep/Glob.
