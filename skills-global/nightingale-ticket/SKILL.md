---
name: nightingale-ticket
description: Create, update, or clean up Linear tickets (and weekly project updates) for the ClinOps - Nightingale project (team CLINOPS) following its Ticket Standards. Use whenever the user mentions a Nightingale or CLINOPS ticket, wants to file, split, cancel, retitle, relabel, or rewrite an issue, needs a parent/sub-ticket structure for a PR stack, asks for a ticket from a plan or Slack thread, or wants the weekly Nightingale project update, even if they never say "standards".
---

# Nightingale Tickets

Source of truth: the project description at https://linear.app/aitco/project/clinops-nightingale-c7464c5e6b9e. If it conflicts with this file, the project wins; tell the user.

## Flow: propose, then create

1. Draft every ticket as a **name + description pair** and show the full set with every field that varies by ticket: title, description, rigor label (with one-line reason), type label, milestone, parent, blocked-by, assignee, priority, and any `Module 1`/`Category`/`Workstream` labels. Also state the fixed defaults (Todo, current cycle N) so the user can override them. Do not call `save_issue` yet.
2. Wait for explicit approval. Edits to existing tickets follow the same rule: show the new title/description first.
3. Create or update, then list the resulting identifiers.

Linear tools are deferred: load them with ToolSearch first (`save_issue`, `list_cycles`, `list_milestones`, `list_issue_labels`).

## Title

Outcome-focused, e.g. "Refactor import-unit to store shift rules as JSON". No PR numbers, PR names, stack position, "fast follow", or Devin artifacts.

## Description

Three headings, always: **Why**, **What**, **Pass criteria**. Trivial tickets may compress them but not omit the intent.
- No ticket IDs inline (Linear's relation graph carries dependencies).
- No implementation steps, branching strategy, or Devin prompts.
- Parent tickets state goal and context and never list their children.
- Canceled tickets: say where the work went. Duplicates: mark and reference the canonical ticket via relation.

## Fields on every ticket

- Team `CLINOPS`, project `ClinOps: Nightingale`.
- Status **Todo**. Todo means "scheduled for the current cycle", so also set the current cycle (`list_cycles` for the CLINOPS team, `type: current`). Say in the proposal that the ticket will be Todo in cycle N, so the user can switch to Backlog.
- Rigor label (engineering tickets), mapped from the standards' meaning to the Linear label:

  | Meaning | Label |
  |---|---|
  | R0 non-implementation, scoping | `R0: N/A` |
  | R1 default, localized, existing patterns | `R2: Code Review` |
  | R2 critical paths, data integrity/models, rollout risk | `R3: Senior Review` |
  | R3 design-bearing, one-way doors | `R4: RFC Required` |

  `R1: AI Review` is Linear-only; use it only if the user asks. Propose a rigor with a one-line reason.
- One type label: `Feature`, `Bug`, `Refactor`, `Improvement`, or `Customer`. `Brainstorm` for tickets not ready to implement. There is no `Critical Path` label; do not create one.
- Milestone: pick the best fit from `list_milestones`, or say none fits.
- Parent: set when the ticket is one PR of a stack. Blocked-by only for true technical gates (B cannot start until A merges), never for parents. Remove blockers that are resolved.
- For Module 1 work, also propose `Module 1` plus one `Category` and one `Workstream` label if obvious.
- Never apply `!implement`, `!plan`, `!review`, `!triage`. Strip them from any ticket you touch.

## PR and ticket pairing

One PR per ticket, one ticket per PR. A stack gets a parent ticket plus one sub-ticket per PR. PR titles carry the identifier: `feat(CLINOPS-123): description`. PRs stay under ~200 meaningful lines (tests and generated code excluded); if bigger, propose splitting into sub-tickets.

## Statuses

Backlog (unscheduled), Todo (current cycle), In Progress, In Review (PR open), Done (merged and verified), Canceled (reason required), Duplicate (reference canonical).

## Weekly project update

For stakeholders one level up. Start with status: On Track / At Risk / Off Track. 150-200 words, outcomes not task lists, no ticket IDs, risks called out in their own sentence rather than buried. Show the draft; do not publish without approval.
