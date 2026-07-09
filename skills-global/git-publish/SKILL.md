---
name: git-publish
description: Publish completed work as a PR. Use when the user says "publish", "ship it", "create a PR", "open a PR", "push this up", "git-publish", or indicates a feature is done and ready for review.
---

# Git Publish

## Flow

1. **Detect state.** Run `git status` and `git log`. Determine what's staged, committed, pushed. Identify the parent branch (`main` or whatever the repo uses).

2. **Read the diff.** `git diff <parent>...HEAD` (plus any unstaged/staged changes). This is the full scope of work.

3. **Stage, commit, push.** Only do what's needed based on current state. If pre-commit hooks block, skip them with `--no-verify`. Create branch if needed: `ryan/<two-or-three-descriptive-words>` (e.g., `ryan/auth-agent-role`).

4. **Assess complexity.** If the diff touches too many unrelated concerns or would be hard to review as one PR, tell the user you recommend splitting and wait for their response. If they agree, use the `pr-splitter` skill.

5. **Create PR.** Use the `pr-description` skill to generate the title and body, then `gh pr create`.
