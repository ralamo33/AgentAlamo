# Deprecated Component Mappings

When reviewing code, flag any import from a deprecated source and recommend the replacement.

## How to identify deprecated components at review time

These mappings are a starting point but the codebase evolves. Before flagging a component:
1. Check if the import path is from a known deprecated directory (listed below)
2. Grep for `@deprecated` in the imported file to confirm
3. Check `src/core/index.ts` for the canonical export

## Known deprecated directories

Any import from these paths should be flagged:
- `src/components/legacy-controlled/` - all files deprecated
- `src/components/legacy-forms/` - all files deprecated
- `src/components/modal/` - old modal system
- `src/components/Select/` - old select components

## Replacement map

| Deprecated Import | Replacement | Import From |
|---|---|---|
| `Container` | `PageContainer` | `@/core` |
| `Banner` | `Callout` | `@/core` |
| `Modal` from `@/components/modal/` | `Modal` | `@/core/modal` |
| `Select` from `@/components/Select/` | `Select` | `@/core/select` |
| `AsyncSelect` from `@/components/Select/` | `AsyncSelect` | `@/core/select` |
| `MultiSelect` from `@/components/Select/` | `MultiSelect` | `@/core/select` |
| `AsyncMultiSelect` from `@/components/Select/` | `AsyncMultiSelect` | `@/core/select` |
| `LegacyControlledSelect` | `FormSelect` | `@/core/form/components` |
| `LegacyControlledInput` | `FormInput` | `@/core/form/components` |
| `LegacyControlledCheckbox` | `FormCheckbox` | `@/core/form/components` |
| `LegacyControlledTextArea` | `FormTextArea` | `@/core/form/components` |
| `Input` (deprecated) | `Input` | `@/core` |
| `Popover` (deprecated) | `Popover` | `@/core` |

## Version disambiguation

When multiple versions of a component exist, prefer the one in `src/core/`. If multiple exist outside core:

- **Modal**: `src/components/modal/` (v1) < `src/components/modal-v2/` (v2) < `src/core/modal/` (v3, canonical)
- **Table**: `src/components/Table/` (old) < `src/components/table-v3/` (current for app-level tables)
- **Forms**: `src/components/legacy-controlled/` (old) < `src/components/legacy-forms/` (old) < `src/core/form/components/` (canonical)

General rule: if it exists in `src/core/`, use that version. If choosing between multiple non-core versions, prefer the higher version number or more recently created directory.
