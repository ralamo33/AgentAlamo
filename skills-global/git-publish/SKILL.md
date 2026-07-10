---
name: git-publish
description: Publish completed work as a PR. Use when the user says "publish", "ship it", "create a PR", "open a PR", "push this up", "git-publish", or indicates a feature is done and ready for review.
---

# Git Publish

## Flow

1. **Detect state.** Run `git status` and `git log`. Determine what's staged, committed, pushed. Identify the parent branch (`main` or whatever the repo uses).

2. **Read the diff.** `git diff <parent>...HEAD` (plus any unstaged/staged changes). This is the full scope of work.

3. **Stage, commit, push.** Only do what's needed based on current state. Create branch if needed: `ryan/<two-or-three-descriptive-words>` (e.g., `ryan/auth-agent-role`). Run pre-commit hooks normally — if they fail, read the errors, make the necessary edits to fix them, re-stage, and commit again. Do NOT use `--no-verify`.

4. **Assess complexity.** If the diff touches too many unrelated concerns or would be hard to review as one PR, tell the user you recommend splitting and wait for their response. If they agree, use the `pr-splitter` skill.

5. **Create PR.** Use the `pr-description` skill to generate the title and body, then `gh pr create`.

6. **Monitor CI.** After the PR is created, poll CI status every 30 seconds using `gh pr checks <pr-number> --watch` or `gh pr checks <pr-number>`. Keep polling until all checks complete or fail.
   - **Fixable failures** (lint errors, type errors, test failures in files you touched): fix the code, commit, and push. Then resume polling.
   - **Non-fixable failures** (infra issues like test pod crashes, flaky tests in unrelated files, CI runner timeouts): stop and notify the user with the failure details so they can take action.
