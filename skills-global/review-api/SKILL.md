---
name: review-api
description: Automated code review pipeline that diffs local changes against main, finds bugs and logical errors via TDD (writes failing tests then fixes code), runs and fixes all affected tests, runs and fixes mypy errors, and produces a complexity report with exact file/line locations. Use this skill whenever the user says "review my code", "review api", "check my changes", "find bugs", "review branch", "run review", "code review", "check for bugs in my changes", or wants a thorough automated review of their working branch before merging. Also trigger when the user asks to "review and fix" their code, wants TDD-based bug detection, or asks for a complexity/readability audit of changed files.
---

# Review API

A six-phase automated code review pipeline that operates exclusively on files changed relative to `main`. Each phase builds on the previous one, so run them in order.

## Phase 1: Gather the Diff

Identify every file changed on the current branch relative to `main`. This is the foundation — all subsequent phases scope their work to these files only.

```bash
git diff --name-only main...HEAD
git diff --name-only          # unstaged changes
git diff --name-only --cached # staged changes
```

Merge these three lists and deduplicate. Filter to only files that still exist on disk (ignore deleted files). Store this as `CHANGED_FILES` — a list you'll reference throughout.

Read every file in `CHANGED_FILES` so you have full context for the phases that follow. Also read the unified diff (`git diff main...HEAD` plus `git diff` for uncommitted changes) so you can see exactly what changed line-by-line.

## Phase 2: Bug Hunt with TDD

For each file in `CHANGED_FILES`, analyze the diff for:

- Off-by-one errors, boundary conditions
- Null/None handling gaps
- Race conditions or ordering assumptions
- Incorrect boolean logic
- Missing error handling at system boundaries (external APIs, user input, DB queries)
- Type mismatches or wrong return types
- Security issues (SQL injection, XSS, command injection, path traversal)
- Resource leaks (unclosed connections, file handles)
- Incorrect use of mutable default arguments

When you find a suspected bug:

1. **Write a failing test first** that reproduces the bug. Place it in the appropriate test file for the module. If no test file exists, create one following the project's existing test naming conventions (look at the test directory structure).
2. **Run the test** to confirm it fails — this validates your understanding of the bug.
3. **Fix the code** to make the test pass.
4. **Run the test again** to confirm the fix works.

Use `uv run pytest <test_file>::<test_name> -x` to run individual tests. The `-x` flag stops on first failure so you get fast feedback.

If after analysis you find no bugs, that's a valid outcome — say so and move on. Do not invent problems.

## Phase 3: Run Affected Tests

Find and run all existing tests that cover the changed files. The goal is to catch regressions introduced by the changes (including any fixes from Phase 2).

Strategy for finding related tests:
- Look for test files that import from changed modules
- Look for test files whose names correspond to changed files (e.g., `foo.py` → `test_foo.py`)
- Check for test files in `tests/` directories that mirror the source structure

```bash
uv run pytest <relevant_test_files> -x -v
```

If any tests fail:
1. Read the failure output carefully
2. Determine if the failure is caused by the branch's changes or was pre-existing
3. Fix failures caused by the branch's changes
4. Re-run until all affected tests pass

If the project has no tests at all, note this in the final report and skip to Phase 4.

## Phase 4: Mypy Type Checking

Run mypy on every changed Python file:

```bash
uv run mypy <changed_file_1> <changed_file_2> ...
```

If the project has a `mypy.ini`, `setup.cfg`, or `pyproject.toml` with mypy configuration, mypy will pick it up automatically.

For each mypy error:
1. Read the error and the offending line
2. Fix the type issue in the source code — prefer accurate types over `# type: ignore` suppressions
3. Re-run mypy on that file to confirm the fix

Only suppress with `# type: ignore[specific-code]` when the type system genuinely can't express the correct type (e.g., dynamic metaclass patterns). Never use bare `# type: ignore`.

If there are pre-existing mypy errors in unchanged lines, note them in the report but do not fix them — stay scoped to the diff.

## Phase 5: Stabilization Loop

Mypy fixes can introduce test regressions, and test fixes can introduce new type errors. This phase ensures both are green simultaneously.

1. Re-run all affected tests from Phase 3:
   ```bash
   uv run pytest <relevant_test_files> -x -v
   ```
2. Re-run mypy on all changed files:
   ```bash
   uv run mypy <changed_files>
   ```
3. If either fails, fix the failures and go back to step 1.

Keep looping until both tests and mypy pass cleanly on the same codebase state. If you've looped 5 times without convergence, stop — report what's still broken in the final report and flag it for the developer. Something deeper is likely wrong and human judgment is needed.

## Phase 6: Complexity & Readability Report

Read through every file in `CHANGED_FILES` one more time, focusing on the changed regions. Identify code that is overly complex or hard to understand:

- Functions longer than ~40 lines
- Deeply nested logic (3+ levels of indentation)
- Complex boolean expressions or conditionals
- God functions that do too many things
- Unclear variable or function names
- Magic numbers or unexplained constants
- Dense one-liners that sacrifice readability for brevity
- Duplicated logic across the changed files
- Functions with too many parameters (5+)
- Missing or misleading type hints that make the code harder to follow

Do not fix these — just report them. The developer should decide what to refactor.

### Report Format

**Numbering:** Assign every finding that requires a human decision a unique, sequential number, counting continuously across the entire report (do not restart per section). Prefix each finding heading with `[N]`. This lets the developer reply by number, e.g. "1. fix it, 3. skip". Auto-fixed items that need no decision (tests you already fixed, mypy errors you already resolved) do not get a number — only surface the count. Any bug you could NOT fix, any complexity concern, and any remaining/pre-existing issue you are flagging DOES get a number. At the end of the report, note the total count, e.g. "Findings requiring your input: 1–7".

Output the final report using this exact structure:

```
# Code Review Report

## Summary
<1-2 sentence overview: how many files reviewed, bugs found/fixed, tests fixed, mypy errors fixed>

## Bugs Found & Fixed
<For each bug:>
### [N] <short description>
- **File:** `path/to/file.py:line_number`
- **Issue:** <what was wrong>
- **Test:** `path/to/test_file.py::test_name`
- **Fix:** <what you changed>

<If no bugs found, say "No bugs found in the changed code.">

## Test Results
- **Tests run:** <count>
- **Initially failing:** <count>
- **Fixed:** <list of test names and what was wrong>
- **Status:** All passing ✓ / <N> still failing

## Mypy Results
- **Errors found:** <count>
- **Fixed:** <count>
- **Remaining (pre-existing):** <count, if any>

## Stabilization
- **Loops required:** <count>
- **Outcome:** Converged ✓ / Did not converge after 5 attempts

## Complexity & Readability Concerns

<For each concern:>
### [N] <short description>
- **File:** `path/to/file.py:line_number`
- **Lines:** <start>-<end>
- **Issue:** <what makes this code complex or confusing>
- **Suggestion:** <brief recommendation>

<If no concerns, say "No significant complexity issues found.">

---
**Findings requiring your input:** <first>–<last> (or "none"). Reply by number to tell me how to handle each, e.g. "1. fix it, 3. skip".
```

Stick to this structure so the output is scannable. Use exact file paths and line numbers everywhere — the developer should be able to jump directly to each location.
