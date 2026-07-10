---
name: refactor
description: Refactor changed code on the current branch. Reads the diff against main, finds simplifications, applies language conventions, and reuses existing repo patterns. Invoke explicitly with /refactor.
---

# Refactor

Analyze all code changed on the current branch and improve it by simplifying logic, applying language conventions, and reusing patterns already established in the repo.

## Flow

1. **Read the diff.** Run `git diff main...HEAD` to get the full scope of changes. Also check `git diff` and `git diff --cached` for any uncommitted work. This combined diff is your input.

2. **Identify the languages and files involved.** Note which languages are in play — this determines which conventions to apply.

3. **Scan the repo for existing patterns.** For each changed file, read sibling files and related modules to understand how the codebase already solves things. Look for:
   - Helper functions or utilities that already do what the new code does manually
   - Base classes, mixins, or shared abstractions the new code could extend
   - Naming conventions, error handling patterns, logging patterns
   - Recently added code (check `git log --oneline -20 -- <directory>`) that may have established new patterns the author hasn't seen yet

4. **Analyze the changes.** For each changed file, look for:
   - **Business logic simplification** — redundant conditionals, overly nested logic, verbose patterns that the language has concise idioms for
   - **Language conventions** — idiomatic style for the language (e.g., list comprehensions in Python, destructuring in JS/TS, pattern matching in Rust)
   - **Repo pattern reuse** — places where existing utilities, helpers, or abstractions should be used instead of reimplementing
   - **Dead code** — imports, variables, or functions added in the diff that are unused

5. **Apply or present.** Use judgment based on the size of the change:

   **Small changes (a few lines, same file):**
   - Simplifying a conditional
   - Replacing verbose code with an existing utility
   - Fixing naming to match conventions
   - Removing dead imports/variables

   Apply these directly. No need to ask.

   **Large changes (new patterns, new files, new classes, architectural shifts):**
   - Extracting a new shared abstraction
   - Restructuring how modules interact
   - Introducing a new pattern or replacing an existing one
   - Moving code between files

   Present these as findings. Explain what you found, why the change would help, and what it would look like. Let the user decide.

## What not to do

- Don't touch files outside the diff. The scope is the changed files only.
- Don't add comments, docstrings, or type annotations that weren't part of the original changes.
- Don't refactor working code just because you'd write it differently — only act on clear improvements (simpler, more idiomatic, reuses existing patterns).
- Don't suggest changes that alter behavior. Refactoring preserves functionality.
