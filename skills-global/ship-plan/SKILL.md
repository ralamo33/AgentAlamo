---
name: ship-plan
description: Take an approved plan from implementation all the way to a ready-to-publish PR — implement it following the project's own conventions, auto-review the diff, fix what the review finds, then pause for your go-ahead before publishing. Use this whenever the user has a plan (a file, a plan-mode output, or a described change) and wants it "shipped", "taken end to end", "implemented and reviewed", "done and put up for review", or asks to "run the full flow" / "implement, review, and ship this". Prefer this over invoking implement, review, or git-publish individually when the user wants the whole sequence in one go.
---

# Ship Plan

Drive a plan from code to a ready-to-publish PR in one flow: **implement → review → (pause) → publish**. Run implement and review autonomously. Only stop early on a hard failure or a decision the plan doesn't cover. Always stop before publishing and wait for the user.

## Request

$ARGUMENTS

If the argument is a file path, that file is the plan. If it's a description or a reference to a plan produced earlier in the conversation, use that. If there's no plan at all, ask for one — this skill executes plans, it doesn't invent them.

## Step 1 — Orient

Read the plan in full so you know the intended scope. Then figure out where you are:

```bash
git rev-parse --show-toplevel   # repo root; its basename is the project name
git status                       # what's already changed
```

The project name (e.g. `candid-api`, `candid-ui`) drives which skills you pick in the next steps.

## Step 2 — Implement (follow the project's conventions)

Projects carry their own rules — how the data layer is accessed, typing expectations, where tests go. A plan implemented against the wrong conventions is a plan that gets rejected in review. So before writing code, find the convention skill for this project.

Discover it by name: look for a skill whose name matches the project. Search these locations (use Glob/Read, not shell):
- `~/.claude/skills/<project>/`
- `~/Workspace/AgentAlamo/skills-local/<project>/`
- `~/Workspace/AgentAlamo/skills-global/<project>/`

The skill file is usually `SKILL.md` (occasionally `SKILLS.md`) — read whichever exists. If the project has a registered skill, invoke it with the Skill tool; otherwise read the convention file directly and follow it.

Then implement the plan step by step, applying those conventions. If no project convention skill exists, implement against the patterns already visible in the surrounding code and note in your final summary that no project skill was found.

Write tests as you go where the plan or project conventions call for it — you want the review step to find a working, tested change, not a first draft.

## Step 3 — Review (auto-select by diff)

Pick the review skill(s) that fit what you changed. Look at the diff's file types:

```bash
git diff --name-only main...HEAD
git diff --name-only            # unstaged
git diff --name-only --cached   # staged
```

Match those files to the installed `review-*` skills by reading their descriptions (they state what they cover — e.g. Python/API changes vs. candid-ui/React/CSS changes). Run every review skill whose scope the diff touches; a change spanning backend and frontend gets both. Invoke each via the Skill tool.

Apply the review's fixes yourself — this is a ship flow, not a report. The review skills already fix tests/types/lint autonomously; for the numbered findings they surface, fix the clear ones (real bugs, straightforward cleanups) without asking. Leave alone only findings that are genuine judgment calls or would expand scope beyond the plan — collect those for the handoff summary.

## Step 4 — Stop before publish

Do not publish on your own. Publishing is outward-facing and the user owns that call. Summarize and wait:

- What you implemented, mapped to the plan.
- Which project convention skill and which review skill(s) you used.
- What review found and what you fixed vs. deferred (with file:line for anything deferred).
- Anything you decided that the plan didn't specify.

Then ask whether to publish.

## Step 5 — Publish (only after the user says go)

On confirmation, hand off to the `git-publish` skill via the Skill tool. It handles branch/commit/push, PR splitting if needed, the PR description, and CI. Don't reimplement any of that here.

## When to stop early

Between Step 2 and Step 4, keep going without checking in — that autonomy is the point. Break out and ask the user only when:

- A step hard-fails and you can't fix it (build won't compile, review can't converge, a required tool is missing).
- The plan is ambiguous or silent on a decision that materially changes the implementation (a schema choice, an API contract, a data migration) — don't guess on something expensive to reverse.

A stumble you can recover from is not a reason to stop. A fork in the road the plan didn't anticipate is.
