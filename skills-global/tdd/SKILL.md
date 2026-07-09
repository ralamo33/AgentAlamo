---
name: tdd
description: Test-driven development for small-mid features and bugfixes.
---

# TDD

Red. Green. Done.

## Flow

1. **Propose 1-3 integration tests** that verify the happy path end-to-end. Describe each in one sentence. User confirms or adjusts.
2. **Write the tests first.** Run them. They must fail. If a test passes before implementation, it's testing nothing — escalate to the user.
3. **Implement until green.** Minimal changes to pass each test. Run tests after each change.
4. **If a test won't pass after reasonable effort, stop and escalate.** Explain what you tried and what's blocking.

## Sub-agent usage

An orchestrator agent can delegate TDD work by spawning a sub-agent with this skill path in the prompt:

```
Read the TDD skill at <path-to-tdd/SKILL.md> and follow its workflow.
Task: <description>
Escalate back to me if tests won't fail when they should or won't pass after reasonable effort.
```
