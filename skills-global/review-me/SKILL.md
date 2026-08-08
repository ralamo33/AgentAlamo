---
name: review-me
description: Language-agnostic code review of everything changed on the current branch. Scopes to the diff against the base branch, discovers the project's own test/type/lint commands instead of assuming a stack, auto-fixes mechanical failures (tests, types, lint, format), and reports bugs and complexity as numbered findings you answer by number. Use this whenever the user says "review me", "review my code", "review my changes", "review this branch", "review my PR", "check my changes", "find bugs in my diff", "code review", "run review", or wants a thorough pass over their working branch before merging. Also trigger when they ask for a readability or complexity audit of what they changed, or ask you to review and fix. Works in any repository and any language — reach for it even when the user names no stack.
---

# Review Me

A review pass over everything changed on the current branch. The scope is the diff and nothing else — untouched code is not your problem.

The split that governs the whole run: **fix what is mechanically verifiable, report what needs a decision.** A type error, a lint violation — the tool tells you unambiguously whether you fixed it, so fix it. A failing test with a non-obvious or several possible solutions, anything that requires deep research or analysis, a suspected bug or a function that's too long is a judgment call about intent, and guessing wrong there costs the user more than it saves. Number those and let them choose.

## Phase 1: Scope the diff

Find the base branch — don't assume `main`:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD
git branch --list main master develop
```

Then collect changed files from all three sources and merge them:

```bash
git diff --name-only <base>...HEAD
git diff --name-only            # unstaged
git diff --name-only --cached   # staged
```

Deduplicate, drop files that no longer exist on disk, and call the result `CHANGED_FILES`. Read every one in full, plus the unified diff (`git diff <base>...HEAD` and `git diff`), so you review the change in context rather than in isolation — most real bugs live in the seam between new code and the code it was dropped into.

If nothing changed, say so and stop.

## Phase 2: Discover the toolchain

Never guess the commands. Wrong invocations produce fake failures you then waste the run "fixing". Read the project's own manifest and use what it declares:

| Signal | Where the real commands live |
| --- | --- |
| `package.json` | `scripts` block; package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm) |
| `pyproject.toml` / `uv.lock` | `[tool.*]` sections; `uv run pytest`, `uv run mypy` when uv-managed |
| `Cargo.toml` | `cargo test`, `cargo clippy`, `cargo fmt --check` |
| `go.mod` | `go test ./...`, `go vet ./...` |
| `Makefile` / `Justfile` | the declared targets — usually the canonical entry point |
| `.github/workflows/` | what CI actually runs; the most reliable source when the others disagree |

Also read `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or a project-level skill if present. Those carry rules a linter can't enforce — banned APIs, required wrappers, where tests belong. Note anything the diff violates; it becomes a finding in Phase 3.

Record which of tests / type-check / lint / format this project actually has. Missing ones are skipped and noted, not improvised.

## Phase 3: Correctness review

Read the diff for real defects. Language-independent things that keep breaking:

- Off-by-one and boundary conditions
- Null/None/undefined paths the new code doesn't handle
- Inverted or short-circuiting boolean logic
- Missing error handling at boundaries — network, user input, database, filesystem
- Ordering and concurrency assumptions; state mutated after the owner is gone
- Injection and traversal risks from unvalidated input reaching a query, shell, path, or template
- Resource leaks — connections, handles, subscriptions, listeners never released
- Type escapes that hide a real mismatch (`as`, `cast`, `# type: ignore`, `any`, unchecked unwraps)
- Silent behavior changes to existing callers that the diff doesn't account for

Then check the diff against the conventions you found in Phase 2, and against what the neighboring files already do. A pattern reimplemented by hand when the repo already has a helper for it is worth flagging even though no tool complains.

Report each of these as a numbered finding with `file:line`. Don't fix them — including the obvious-looking ones. If the fix is genuinely one line and unambiguous, say exactly what it is so the user can accept it with a single reply. Finding nothing is a legitimate outcome; say so rather than manufacturing filler.

## Phase 4: Run the tooling and fix what fails

Run each discovered command, scoped to the changed files where the tool supports it and repo-wide where it doesn't:

1. **Tests** — the tests covering `CHANGED_FILES`. Find them by import, by name correspondence (`foo.py` → `test_foo.py`), and by mirrored directory structure. If they're hard to isolate, run the suite.
2. **Type check**
3. **Lint and format** — use the project's auto-fix target if it has one, then re-run to confirm clean.

Fix every failure the branch caused. Before fixing, check whether the failure predates the branch (`git stash` is off-limits — use `git worktree` or just read the base version of the file). Pre-existing failures get reported, not fixed; expanding into them makes the diff unreviewable.

Fix the source of the problem, not the signal. A type error means the types are wrong; a suppression comment leaves the bug and hides it. Suppress only when the type system genuinely can't express the truth, and always with a specific code (`# type: ignore[arg-type]`, `eslint-disable-next-line <rule>`), never bare.

Never edit a test to make it pass. A red test is a claim about intended behavior, and rewriting the claim to match the code destroys the only evidence that something is wrong. If a test looks wrong rather than the code, stop and make it a finding.

## Phase 5: Stabilize

Type fixes break tests; test fixes introduce type errors. Re-run every tool from Phase 4 and keep looping until they're all green on the same state of the tree.

Cap it at five loops. If it hasn't converged by then, the change likely has a deeper problem than a review pass can settle — stop, report exactly what's still red, and hand it back.

## Phase 6: Complexity and readability

One more read of the changed regions, looking for code that will be expensive to understand later:

- Functions well past ~50 lines, or doing several unrelated jobs
- Functions under 5 lines that are only called once
- Nesting three or more levels deep
- Conditionals dense enough that you had to trace them twice
- Names that don't say what the thing is
- Magic values with no explanation
- Logic duplicated across the changed files
- Long parameter lists (5+) that suggest a missing type
- Cleverness that costs more to read than the lines it saved

These are reports, never edits. Complexity is a taste call the author is better placed to make, and unrequested restructuring buries the real findings in noise.

## Report

Number every finding that needs a decision — sequentially, continuously across all sections, never restarting. Prefix each heading with `[N]` so the user can reply `"1. fix it, 3. skip"`. Work you already completed (tests repaired, types fixed, lint auto-fixed) is reported as counts only; it needs no decision, so it gets no number. Anything still broken does get one.

Use `path/to/file.ext:42` — a single line, never a range. Ranges break clickable-link detection in the terminal.

```
# Code Review

## Summary
<1-2 sentences: files reviewed, what was fixed, what needs a decision>

## Findings
<For each — bugs, convention violations, and anything unfixable, in that order:>
### [N] <short description>
- **File:** `path/to/file.ext:42`
- **Issue:** <what's wrong and why it matters>
- **Suggested fix:** <what to do about it>

<If none: "No correctness or convention issues found.">

## Fixed Automatically
- **Tests:** <count> run, <count> repaired — <one line each>
- **Types:** <count> errors fixed
- **Lint/format:** <count> fixed (<auto-fix command used>)
- **Skipped:** <tools this project doesn't have>
- **Stabilization:** converged in <N> loops / did not converge

## Pre-existing Issues (not fixed — outside this diff)
<file:line and a one-line description, or "none">

## Complexity & Readability
### [N] <short description>
- **File:** `path/to/file.ext:42`
- **Issue:** <what makes this hard to follow>
- **Suggestion:** <brief recommendation>

<If none: "No significant complexity issues found.">

---
**Findings requiring your input:** <first>–<last> (or "none"). Reply by number, e.g. "1. fix it, 3. skip".
```

Drop any section with nothing in it rather than printing an empty heading — the report should be short enough that every line earns its place.
