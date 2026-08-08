---
name: review-api-python-canvas
description: Same automated Python code review pipeline as review-api-python (diff vs main, TDD bug hunt, affected tests, mypy, stabilization loop, complexity audit) but delivers the final report as an interactive Canvas webpage instead of terminal text. Use when the user says "review my code in canvas", "review api canvas", "canvas review", "review python and show me a page", "interactive review", or otherwise wants to click through and respond to review findings in a browser rather than reply by number in the terminal.
allowed-tools: Bash(cat ${CLAUDE_SKILL_DIR}/../review-api-python/SKILL.md)
---

# Review API (Python) → Canvas

Runs the full `review-api-python` pipeline, then renders the report as an interactive HTML page through `canvas` so the user can annotate individual findings and reply in the browser.

## Phase A: Run the review

Follow the pipeline below in full — Phases 1 through 6, including the numbering rules for findings.

!`cat ${CLAUDE_SKILL_DIR}/../review-api-python/SKILL.md`

Two changes to it:

- **Do not print the final markdown report to the terminal.** Hold the report content and go to Phase B. Everything the report format specifies (summary, bugs, test results, mypy results, stabilization, complexity concerns, sequential `[N]` numbering across the whole report) still applies — it becomes the content of the page.
- Ignore the YAML frontmatter block at the top of the inlined pipeline; it belongs to the source skill, not to this one.

## Phase B: Render the report to Canvas

Invoke the `canvas` skill with the Skill tool, passing the report content as the argument so it delegates HTML generation to a `canvas-html` subagent and then drives the `canvas open` / `canvas update` loop.

The page must follow the HTML rules in the `canvas` skill (they gate the layout audit), plus these report-specific requirements:

- **One card per numbered finding.** Each `[N]` finding gets its own container element so the user can annotate it in isolation. Do not merge findings into a single block or list.
- **Finding number is the heading.** Lead each card with `[N] <short description>` so browser feedback maps unambiguously back to a finding.
- **File paths are clickable-friendly.** Render each location as a single `path/to/file.py:line` in a `<span class="mono">` — one line number, never a range.
- **Auto-fixed work is summary-only.** Bugs already fixed, tests already repaired, and mypy errors already resolved appear as counts in the summary sections, not as annotatable cards. Only findings that need a decision get cards.
- **Sections in report order:** Summary, Bugs Found & Fixed, Test Results, Mypy Results, Stabilization, Complexity & Readability Concerns.
- **Close with the decision prompt** — total finding range and a note that the user can annotate any card directly or type an overall message.

## Phase C: Act on browser feedback

Each `canvas open` / `canvas update` call blocks and returns a `prompts` array. Every prompt carries a `selector` and `text` identifying the card the user annotated — resolve that back to its finding number.

1. Apply the requested changes for each annotated finding.
2. Re-run the affected tests and mypy for anything you touched, per the stabilization rules in `review-api-python`.
3. Regenerate the HTML with updated statuses on each card (fixed / skipped / unchanged) and call `canvas update <name> <path>`.
4. Repeat until the session returns `status: "ended"` or `status: "confirmed"`.

When the session ends, summarize in the terminal what changed as a result of the browser round-trips — that summary is the only terminal output this skill produces.
