---
name: pr-monitor
description: Continuously monitor the GitHub PR for the current branch — poll CI and review comments on a recurring schedule, fix mechanical failures autonomously, escalate design-level feedback, and keep watching until the PR is green or merged. Only ever acts on the checked-out branch's own PR. Use when the user says "monitor the PR", "watch the PR", "keep the PR green", "babysit the PR", "poll CI", "watch for CI failures", "fix the PR", "address comments", "fix CI", "pr-monitor", "handle the review feedback", or "make CI pass".
---

# PR Monitor

Watches a GitHub PR on a recurring schedule. On each pass it reads CI results and review comments, fixes what it can autonomously, escalates the rest, and keeps monitoring until the PR is green or merged.

## Step 1: Identify the PR

Only ever monitor the PR for the branch that is currently checked out. Do not accept or act on a PR number, URL, or branch name — ignore any such argument and resolve the PR from the current branch:

```bash
gh pr view --json number,url,headRefName,state,mergeable
```

If the current branch has no PR, tell the user and stop — do not go looking for another PR to monitor. This skill never touches other people's PRs or any branch other than the one you're on.

Record `PR_NUMBER`. All fixes and pushes stay on the current branch.

## Step 2: Gather feedback

Run these in parallel:

**PR comments:**
```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments --paginate
gh api repos/{owner}/{repo}/issues/{number}/comments --paginate
```

**CI check results:**
```bash
gh pr checks {number}
```

**Current diff** (to understand what the PR changes):
```bash
git diff main...HEAD
```

Track which comments and check runs you've already handled so later passes don't re-process the same feedback.

## Step 3: Triage feedback

Split everything into two buckets:

**Mechanical** — fix autonomously:
- Failed CI checks (mypy errors, test failures, lint)
- Comments requesting simple code changes (typo fixes, naming a variable, adding a missing import, fixing a type annotation)
- Comments pointing out a clear bug

**Transient** — re-run, don't fix:
- Infrastructure/runner failures (self-hosted runner died, container/exec errors, `exit code 143`/SIGTERM, node lost, pod evicted)
- Timeouts and network blips (image pull failures, registry/artifact upload errors, DNS, "internal error occurred")
- Failures whose logs show no test assertion, mypy error, or lint violation — the job never reached your code, or died mid-run in code this PR doesn't touch
- A run cancelled as a side effect of a sibling job's infra death

These will almost always go green on a re-run. Re-run them (see Step 4), don't try to "fix" code that isn't broken.

**Design-level** — ask the user:
- Refactoring suggestions, architecture changes
- "Should we use X pattern instead?"
- Comments questioning the overall approach
- Requests that would significantly change the scope of the PR

Present design-level feedback to the user as a numbered list. Ask which ones to address and how. Do not block monitoring on this — keep polling CI while you wait, and apply the user's answers on a later pass.

For mechanical fixes, just fix them — no need to ask. For transient failures, just re-run them — no need to ask.

**How to tell mechanical from transient:** read the failure log before deciding. If it shows a test assertion, mypy error, or lint violation in files this PR touches → mechanical, fix it. If it shows runner/container/network/timeout errors, or the same job passes on other shards while a few die with identical infra errors → transient, re-run it. When genuinely ambiguous, re-run once first (cheap); if it fails the same way a second time, treat it as mechanical and investigate.

## Step 4: Fix issues

Read the relevant files and make the fixes. For CI failures:

- **Test failures:** Read the failure output, understand what broke, fix the code (not the test, unless the test itself is wrong).
- **Mypy errors:** Fix type annotations. Prefer accurate types over `# type: ignore`.
- **Lint errors:** Apply the required formatting/style fixes.

To read failure logs from a specific check run:
```bash
gh run view {run_id} --log-failed
```

For PR comment feedback (mechanical items + any design-level items the user approved):
- Read the comment, understand the request, read the surrounding code, make the change.

**Re-running transient failures.** For jobs triaged as transient (Step 3), re-run the failed jobs instead of editing code:

```bash
# A run must be completed before its failed jobs can be re-run. If it's still
# in progress, wait for the next pass. If infra deaths cancelled it, that counts
# as completed and you can re-run now.
gh run view {run_id} --json status,conclusion --jq '{status,conclusion}'
gh run rerun {run_id} --failed        # re-runs only the failed jobs (+ their dependents)
```

Track how many times you've re-run each run. If the *same* jobs fail with the *same* infra signature after **2** re-runs, stop re-running — escalate to the user as persistently broken infra rather than looping forever. Never re-run a job whose log shows a real code failure; fix that instead.

After all *code* fixes, run a local verification:
```bash
uv run pytest <affected_test_files> -x -v
uv run mypy <changed_files>
```

Keep fixing until both pass locally.

## Step 5: Push

Commit the fixes, then detect whether to use Graphite or plain git:

```bash
gt log --short 2>/dev/null
```

If that succeeds (current branch is in a Graphite stack):
```bash
gt stack submit
```

Otherwise:
```bash
git push
```

## Step 6: Continuous monitoring

This skill is a standing monitor — it does not stop after one pass. After completing Steps 2–5, schedule the next check instead of ending.

**Choose the cadence by what you're waiting on:**
- CI actively running → re-check in ~90 seconds (checks flip state fast).
- All green, waiting on a human review → re-check in ~10–20 minutes.
- Nothing pending and no fixes in flight → ~20–30 minutes.

**How to schedule the next pass:**

- If this skill was launched via `/loop` (e.g. `/loop 5m /pr-monitor`), the loop handles re-invocation — just finish the current pass with a one-line status and let the loop fire again. In dynamic `/loop` mode, use `ScheduleWakeup` with a `delaySeconds` matched to the cadence above and re-pass the same `/pr-monitor` input.
- If launched directly (not under `/loop`), set up the recurring watch yourself with `ScheduleWakeup` (dynamic) or `CronCreate`, passing a prompt that re-runs `/pr-monitor`. Each pass re-resolves the PR from the current branch (Step 1), so if the branch changes, the monitor follows the new branch — or stops if that branch has no PR. Tell the user the cadence you chose and that recurring schedules auto-expire after 7 days.

**On each pass, evaluate exit conditions first:**
- **PR merged or closed** (`state` is `MERGED`/`CLOSED`): report and stop scheduling.
- **All checks pass and no unhandled comments:** report green. If the user only asked to get it green, stop scheduling; if they asked to keep watching, continue at the slow cadence.
- **A check failed:**
  - *Fixable* (test/mypy/lint failure in files this PR touches): run Steps 4–5, then schedule the next pass.
  - *Transient* (infra/runner failure, timeout, network blip, flaky test in unrelated code): re-run the failed jobs (Step 4, `gh run rerun {run_id} --failed`), then schedule the next pass to check the re-run. Only escalate to the user if the same jobs fail the same way after 2 re-runs.

Always end a pass with a short status line (PR number, check summary, what you did, when the next pass fires) so the user can follow along and interrupt if needed.
