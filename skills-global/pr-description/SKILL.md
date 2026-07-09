---
name: pr-description
description: Generate a PR title and description. Use whenever creating or editing a PR description, including from git-publish and pr-splitter. Triggers on "write a PR description", "describe this PR", "pr description", or any context where a PR needs a title and body.
---

# PR Description

Do NOT ask the user what the description should be. Autonomously read the diff (`git diff main...HEAD`), understand the full scope of changes, and generate the title and body yourself.

## Title

The PR title. 2-5 words, short sentence fragment. (e.g., "Add Auth Agent Role")

## Body

```
## Motivation
<Two sentences on why this change exists.>

## Description
<Two sentences on the overall approach.>

## Review Suggestion
<GitHub URL links to the files & line ranges containing key business logic, and the key e2e test that proves it works. Use the format: https://github.com/<owner>/<repo>/blob/<branch>/<file>#L<start>-L<end>>
```

## Applying

Use `gh pr edit <pr-number> --title "<title>" --body "<body>"` or `gh pr create --title "<title>" --body "<body>"`.
