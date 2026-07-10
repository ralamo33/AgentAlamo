---
name: pr-splitter
description: Split a large PR into a stack of smaller, logically coherent Graphite PRs. Use this skill whenever the user wants to break up, split, decompose, or chunk a PR into smaller PRs, or when they mention splitting a PR with Graphite, or say things like "this PR is too big", "break this into smaller PRs", "stack this PR", "split this into a stack". Also trigger when the user pastes a PR URL and asks to split it, or says "gt split" or "graphite split".
---

# PR Splitter

Split a single large PR into a clean stack of smaller Graphite PRs, each representing a logical unit of work.

## Prerequisites

- Graphite CLI (`gt`) must be installed and authenticated
- The repo must have a PR (or local changes) ready to split
- `gh` CLI for GitHub operations

## Workflow

### Phase 1: Safety checks and planning

1. Run `git status` to check for uncommitted changes.
   - If there are unstaged or staged-but-uncommitted changes, tell the user and ask them to commit or stash before proceeding. Do not continue until the working tree is clean.

2. Identify the current branch name (`git branch --show-current`) and the base branch the PR targets.

3. Examine the full diff against the base branch to understand all changes:
   ```
   git diff <base-branch>...HEAD --stat
   git diff <base-branch>...HEAD
   ```

4. Group changed files into **logical units of work** — things like "add the data model," "wire up the API endpoint," "update the UI components," "add tests." The goal is that each sub-PR tells a coherent story and could be reviewed independently.

   **Critical rule: files are atomic.** Never split changes within a single file across multiple PRs. Every file goes into exactly one sub-PR.

   When grouping, think about dependency order — earlier PRs in the stack should contain foundational changes (models, types, utilities) that later PRs build on (API routes, UI, tests).

   If you're unsure whether something should be its own PR or merged with another, ask the user.

5. Present the plan to the user, along with the backup branch name and a permissions request:
   ```
   Here's how I'd split this:

   1. Add User Profile Model (3 files)
      - src/models/user_profile.py
      - src/models/__init__.py
      - alembic/versions/001_add_user_profile.py

   2. Create Profile API Endpoints (2 files)
      - src/routes/profile.py
      - src/routes/__init__.py

   3. Build Profile Settings UI (4 files)
      - src/components/ProfileSettings.tsx
      - src/components/ProfileAvatar.tsx
      - src/pages/settings.tsx
      - src/styles/profile.css

   Does this grouping look right? Want to move any files around?

   Before I start, I'll create a backup branch at `<current-branch>-backup`.
   I'd like permission to run `gt` and `git` commands freely so I don't
   have to ask for each one individually.
   ```

   Wait for the user to approve the plan and grant permissions before proceeding.

### Phase 2: Prepare and execute the split

6. Create a backup branch:
   ```
   git branch <current-branch>-backup
   ```

7. Check if the current branch is tracked by Graphite:
   ```
   gt ls
   ```
   If the branch isn't tracked, track it:
   ```
   gt track
   ```

8. Execute the split using Graphite.

   a. Identify the parent branch that the current branch is tracked against in Graphite (this is the base the stack will sit on).

   b. Untrack the original branch from Graphite so it's no longer part of the stack:
   ```
   gt untrack
   ```

   c. Check out the parent/base branch:
   ```
   git checkout <base-branch>
   ```

   d. For the **first** sub-PR, create a new Graphite branch tracked on the same parent the original branch had:
   ```
   gt create <branch-name> -m "<commit message>"
   ```
   Check out the relevant files from the original branch:
   ```
   git checkout <original-branch> -- <file-path-1> <file-path-2> ...
   git add .
   git commit --amend --no-edit
   ```

   e. For each subsequent sub-PR, repeat — Graphite will automatically stack it on top of the previous one:
   ```
   gt create <branch-name> -m "<commit message>"
   git checkout <original-branch> -- <file-path-1> <file-path-2> ...
   git add .
   git commit --amend --no-edit
   ```

   f. After all branches are created, submit the stack:
   ```
   gt submit --stack
   ```

### Phase 3: PR descriptions

9. For each PR in the stack, use the `pr-description` skill to generate the title and body, then update via:
   ```
   gh pr edit <pr-number> --title "<title>" --body "<description>"
   ```

10. Tell the user the split is complete. List each PR with its URL so they can review the stack.

## Error recovery

If anything goes wrong at any point:
1. Stop immediately and tell the user what happened.
2. Remind them the backup branch is `<current-branch>-backup` so they can recover manually.
