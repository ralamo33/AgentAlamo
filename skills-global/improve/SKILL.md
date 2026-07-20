---
name: improve
description: Review the session that just happened and turn it into durable improvements to the AgentAlamo config — add safe permission allow-rules for commands that triggered a prompt, and capture the user's in-session feedback into CLAUDE.md, a skill, or a new skill. Use this at the END of a working session, or whenever the user says "improve", "run improve", "tighten up the config", "stop asking me for permission on X", "remember this for next time", "capture that feedback", or reflects that they had to correct you or re-approve the same commands repeatedly. This is the self-improvement pass for the agent's own setup, not for the product code.
---

# Improve

Turn the session that just happened into durable config changes so the next session is smoother. Two axes:

1. **Permissions** — commands that made the user click "approve" but are safe to auto-allow.
2. **Feedback** — corrections and preferences the user voiced, captured somewhere they'll persist.

Everything here is a *proposal → user approves → you apply* loop. Never edit config silently; the whole point is the user staying in control of what their agent is allowed to do and how it behaves.

## Step 1 — Scan the session

Run the scanner. It finds the current session's transcript, diffs the commands that ran against the current allowlist, and pulls out user messages that read like feedback:

```bash
python3 ~/Workspace/AgentAlamo/skills-global/improve/scripts/scan_session.py
```

Default target is the newest transcript for the current working directory, compared against `~/Workspace/AgentAlamo/claude-settings.json` (the file `setup.sh` symlinks to `~/.claude/settings.json` — the real source of truth). Pass `--transcript <path>` to review a specific session. The scanner prints a summary and saves a full JSON report to `/tmp/`; read that report for the complete list.

The scanner is a *candidate finder*, not a decision-maker. Its suggested rules and feedback flags are starting points — your judgment in the next steps is what makes this safe.

## Step 2 — Decide which permissions are safe to add

A command shows up as a candidate because it ran but no existing allow-rule covered it — meaning the user got prompted. The question is only whether it's safe to *stop* prompting for it.

Add a rule when the command is read-only, idempotent, or scoped to this workspace, and prompting for it is pure friction: linters, type-checkers, formatters, test runners, build tools, status/inspection commands, package-manager read operations.

Do **not** add a rule — leave the prompt in place — when the command can destroy data, mutate state outside the repo, reach the network to publish, touch secrets, or run with elevated privileges. `rm`, `chmod`, `ln`, `mv`, `kill`, `curl`/`wget` that POST, `ssh`, `kubectl`, cloud CLIs that write — these stay behind a prompt no matter how many times they showed up. If a command was genuinely dangerous and the user hesitated, propose adding it to the settings `deny` list instead.

Watch the scanner's suggested rule — it's a heuristic and sometimes wrong:
- **Compound commands** (heredocs, `for ...; do`, `set -e; ...`) surface with useless heads like `Bash(for *)` or `Bash(set *)`. Don't propose those. Pull out the actual tool the user cares about, or skip it.
- **Right the width.** `Bash(tsc *)` is a good generalization; `Bash(git *)` may be too broad if it would sweep in `git push`/`git reset`. Match the granularity already used in the allowlist — read it first to stay consistent (e.g. it allows `git log *`, `git diff *` but not a blanket `git *` in the intended spots).

## Step 3 — Turn feedback into something durable

The scanner flags user turns containing corrective language ("no, don't…", "actually…", "always…", "use X instead", "from now on…"). Read each in its surrounding context in the transcript — a keyword match isn't feedback until you understand what the user was reacting to. A one-off "no, the other file" is not a durable preference; "stop adding comments" is.

For each real, generalizable preference, decide where it belongs so it actually takes effect next time:

- **`~/Workspace/AgentAlamo/CLAUDE.md`** — cross-cutting rules about how you should work everywhere (style, tooling defaults, what tools to use). This is loaded every session.
- **An existing skill** — if the feedback is about a workflow a skill already owns (e.g. how PRs get described, how reviews run), fix it at the source. Find the skill in `skills-global/` or `skills-local/`.
- **A new skill** — if the feedback describes a repeatable workflow that has no home yet, note it and offer to run `/skill-creator`.

Generalize past the specific instance, and preserve the *why* — a rule the user understands the reason for survives; a bare command gets ignored. Don't restate what CLAUDE.md or a skill already says.

## Step 4 — Present one summary, apply what's approved

Show everything in a single digest so the user can approve in one pass:

```
Permissions to add (safe, currently prompting):
  + Bash(tsc *)        — ran 3×, type-checking
  + Bash(vitest *)     — ran 2×, test runner
Left as prompts (not auto-safe):
  · Bash(rm *)         — destructive
Feedback captured:
  → CLAUDE.md: "prefer ripgrep-free Grep tool" (you re-corrected this twice)
  → pr-description skill: stop including the test plan section
```

Let the user accept, drop, or edit items. Then apply the approved ones: edit the `permissions.allow` array in `~/Workspace/AgentAlamo/claude-settings.json` (keep it alphabetical-ish and grouped like the existing entries; don't introduce duplicates), and make the approved CLAUDE.md / skill edits. Because these files are symlinked from the repo, changes are live immediately and version-controlled — mention that the user can review the diff with `git diff` and commit when ready. Don't commit for them unless asked.

If nothing is worth changing, say so plainly rather than inventing changes — a clean session is a valid outcome.
