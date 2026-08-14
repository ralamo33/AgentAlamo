---
name: tdd
description: Test-driven development for small-mid features and bugfixes.
---

# TDD

Red. Green. Done.

Target 1-4 tests per change, not one per function. The goal is confidence that the flow works end-to-end, not coverage. Every test past the ones needed to pin down the behavior is a cost — more to maintain, more to read, more noise around the change that actually matters.

## Flow

1. **Propose 1-4 tests** that verify the happy path and any genuinely load-bearing edge case (a documented error condition, a boundary the code explicitly branches on) end-to-end. Describe each in one sentence. User confirms or adjusts.
2. **Write the tests first.** Before writing, check for a repo-local test-writing / test-conventions skill (e.g. `.claude/skills/test-writing/`) and follow it — it defines the repo's fixtures, isolation, parametrization, and helper-extraction style. Run them. They must fail. If a test passes before implementation, it's testing nothing — escalate to the user.
3. **Implement until green.** Minimal changes to pass each test. Run tests after each change.
4. **If a test won't pass after reasonable effort, stop and escalate.** Explain what you tried and what's blocking.

## What not to do

- Don't write a separate unit test for every private helper, branch, or pure function touched along the way — if the 1-4 end-to-end tests exercise it, that's enough.
- Don't chase 100% coverage. A change with one well-chosen integration test beats ten shallow ones that each restate the happy path with a different input.
- If you catch yourself proposing more than 4 tests, stop and ask whether the extra ones are covering distinct behavior or just padding — cut anything that's the latter.

## Sub-agent usage

An orchestrator agent can delegate TDD work by spawning a sub-agent with this skill path in the prompt:

```
Read the TDD skill at <path-to-tdd/SKILL.md> and follow its workflow.
Task: <description>
Escalate back to me if tests won't fail when they should or won't pass after reasonable effort.
```
