---
name: eval-driven-dev
description: Eval-driven development — define realistic evaluation before writing implementation, then iterate until the eval passes. Use when the user wants to build a feature, fix a complex bug, or asks for "eval-driven", "test-first", "prove it works", or when the task is complex enough to benefit from upfront evaluation design. For complex tasks, sub-agents implement while the parent agent evaluates.
---

# Eval-Driven Dev

Eval first. Code second. Iterate until green.

## Flow

1. **Propose 3-5 eval strategies** specific to the task (e2e script, golden-file diff, integration test, behavioral snapshot, input matrix, interaction replay)
2. **User picks one**
3. **Build eval scaffolding** — test data, expected outputs, eval script. Run against stub to confirm it fails.
4. **Implement & iterate** — run eval after each change, fix what fails
5. **Complex tasks**: sub-agents implement, parent evaluates. Sub-agents don't see the eval.
