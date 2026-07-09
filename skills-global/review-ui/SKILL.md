---
name: review-ui
description: Code review pipeline for the candid-ui repository. Checks changed files for logical bugs, React best practices, CSS/styling issues (semantic tokens, shared component usage, deprecated component detection), runs ESLint and formatting, and produces a complexity report with exact file/line locations. Use this skill whenever the user says "review ui", "review candid-ui", "review my PR", "check my frontend changes", "review this branch", or wants a code review of candid-ui work. Also trigger when the user asks to check React code quality, CSS style review, or wants to audit their UI changes before merging.
---

# Review UI

A five-phase code review pipeline for the candid-ui repository. Every phase operates only on files changed relative to `main`.

Before starting, set your working directory to `~/Workspace/candid-ui/`.

## Phase 1: Gather the Diff

Identify every file changed on the current branch relative to `main`.

```bash
git diff --name-only main...HEAD
git diff --name-only
git diff --name-only --cached
```

Merge and deduplicate these lists. Filter to files that still exist on disk. Store this as `CHANGED_FILES` for the rest of the review.

Read every file in `CHANGED_FILES` in full. Also read the unified diff (`git diff main...HEAD` plus `git diff` for uncommitted changes) to see what changed line-by-line.

## Phase 2: Logic & Bug Review

Analyze the diff in each changed file for correctness issues:

- Off-by-one errors, boundary conditions
- Null/undefined handling gaps (especially in optional chaining, nullish coalescing)
- Incorrect boolean logic or inverted conditions
- Missing error handling at system boundaries (API calls, user input)
- Stale closures in callbacks or effects
- Incorrect dependency arrays (in useMemo, useCallback, React Query options)
- Race conditions in async operations (e.g., state updates after unmount)
- Wrong key props in lists (using index as key for reorderable lists)
- Type assertion abuse (`as` casts that hide real type mismatches)

For each bug found, report it with the exact file and line number. If the fix is straightforward, describe it. If the bug is subtle or arguable, explain your reasoning so the developer can assess.

## Phase 3: React Best Practices

Check changed files against candid-ui's React conventions. These aren't arbitrary rules — they reflect the team's architecture decisions and prevent real production issues.

### No useEffect

This is the most important rule in candid-ui. The codebase bans `useEffect` entirely. If you see one in changed code, flag it immediately.

- **Data fetching** should use React Query (`useQuery`, `useMutation`)
- **User interactions** should use event handlers
- **Reusable side effects** should use custom hooks
- Read `src/hooks/useMountEffect/useEffect.md` if you need to understand the rationale

The only exception is code inside `src/core/` (the design system library), where `useEffect` is occasionally necessary for low-level component plumbing.

### Other React patterns to check

- **Component composition over prop drilling** — if a component takes 8+ props that just pass through to children, suggest composition
- **Avoid inline function definitions in JSX** for callbacks that cause unnecessary re-renders — extract to `useCallback` or define outside the render
- **React Query usage** — mutations should use `onSuccess`/`onError` callbacks, not `.then()` chains. Query keys should be stable and descriptive.
- **Form handling** — forms should use `react-hook-form` with the core `Form*` components (FormInput, FormSelect, etc.), not manual state tracking
- **State management** — local state for UI state, React Query for server state, Zustand/Jotai for shared client state. Flag any `useState` + `useEffect` combos that are reinventing React Query.
- **Memoization** — `useMemo`/`useCallback` should have correct dependency arrays. Flag missing deps. Also flag unnecessary memoization (memoizing a string concatenation or a simple boolean is wasteful noise).

## Phase 4: CSS & Styling Review

Candid-ui uses Tailwind CSS v4 with a custom design token system (the "Vitals" design system). The styling philosophy is: use the minimum CSS to achieve the outcome, prefer shared components, and always reach for semantic tokens.

### Semantic tokens over raw values

The design tokens are defined in `src/core/theme.css`. When reviewing Tailwind classes in changed code:

- **Colors**: Prefer semantic tokens (`text-dark`, `text-muted`, `bg-surface-neutral`, `border-surface-dark`) over raw palette values (`text-gray-700`, `bg-gray-100`). Even if the semantic token maps to a slightly different shade, the semantic meaning is more important than the exact hex value — it keeps the UI consistent when tokens are updated.
- **Typography**: Prefer the named text tokens (`text-title-2`, `text-body-1`, `text-label`) over ad-hoc font-size + font-weight + line-height combos. The token system bundles these together for consistency.
- **Spacing, radius, shadows**: Use the design system values. Flag raw pixel values or arbitrary Tailwind values (e.g., `p-[13px]`) when a token would work.

### Shared component preference

Before writing custom markup with Tailwind classes, check whether a core component already handles it. The full set of shared components is exported from `src/core/index.ts`.

- Flag custom button-like elements → should use `Button` from `@/core`
- Flag custom modal markup → should use `Modal` from `@/core`
- Flag custom form inputs → should use `FormInput`, `FormSelect`, etc.
- Flag custom card wrappers → should use `Card` from `@/core`
- Flag custom tooltip implementations → should use `Tooltip` from `@/core`

When multiple shared components could work, prefer the one from `src/core/` over `src/components/`. Read `references/deprecated-components.md` for the full deprecation map and replacement guidance.

### Deprecated component detection

Check every import in changed files against the deprecated component list. Key signals:
- Any import from `src/components/legacy-controlled/` or `src/components/legacy-forms/`
- Any import from `src/components/modal/` (use `@/core/modal` instead)
- Any import from `src/components/Select/` (use `@/core/select` instead)
- Any file with `@deprecated` in its JSDoc

When flagging, include the specific replacement component and import path.

### Styling patterns

- Use `twJoin()` for composing classes, not `twMerge()` — this is enforced by ESLint but worth double-checking
- No CSS modules, styled-components, or inline `style={}` objects — everything should be Tailwind classes
- Minimal CSS: if the same visual result can be achieved with fewer utility classes, prefer the shorter version. Don't add classes that duplicate what a parent or shared component already provides.

## Phase 5: Lint, Format & Complexity Report

### Run ESLint and formatting

```bash
cd ~/Workspace/candid-ui && pnpm run lint 2>&1
cd ~/Workspace/candid-ui && pnpm run format:check 2>&1
```

Report any errors or warnings. For fixable issues, run:

```bash
cd ~/Workspace/candid-ui && pnpm run fix-me
```

Then re-run lint and format to confirm everything passes. If issues remain after auto-fix, report them individually with file and line number.

### Complexity & readability audit

Read through every file in `CHANGED_FILES` one final time, focusing on the changed regions. Flag code that is overly complex or confusing:

- Functions longer than ~40 lines
- Deeply nested logic (3+ levels of conditional/ternary nesting in JSX is especially hard to read)
- Complex boolean expressions or multi-condition ternaries
- Components doing too many things (fetching data, handling state, rendering complex UI all in one file)
- Unclear variable or function names
- Magic numbers or unexplained constants
- Dense one-liners that sacrifice readability
- Duplicated logic across changed files
- Components with 8+ props (consider composition)

Do not fix these — just report them so the developer can decide what to refactor.

### Report format

Output the final report using this structure:

```
# UI Code Review Report

## Summary
<1-2 sentence overview: files reviewed, issues found by category>

## Logic & Bugs
<For each issue:>
### <short description>
- **File:** `path/to/file.tsx:line_number`
- **Issue:** <what's wrong>
- **Suggested fix:** <how to fix it>

<If none: "No logic issues found.">

## React Best Practices
<For each issue:>
### <short description>
- **File:** `path/to/file.tsx:line_number`
- **Rule:** <which convention is violated>
- **Suggestion:** <what to do instead>

<If none: "All React patterns look good.">

## CSS & Styling
<For each issue:>
### <short description>
- **File:** `path/to/file.tsx:line_number`
- **Issue:** <what's wrong — raw color vs semantic token, deprecated component, missing shared component, etc.>
- **Replacement:** <specific token, component, or import to use instead>

<If none: "Styling follows conventions.">

## Lint & Format
- **ESLint errors:** <count>
- **Format issues:** <count>
- **Auto-fixed:** yes/no
- **Remaining issues:** <list with file:line if any>

## Complexity & Readability Concerns
<For each concern:>
### <short description>
- **File:** `path/to/file.tsx:line_number`
- **Lines:** <start>-<end>
- **Issue:** <what makes this code complex or confusing>
- **Suggestion:** <brief recommendation>

<If none: "No significant complexity issues found.">
```

Use exact file paths and line numbers throughout. The developer should be able to jump directly to each location.
