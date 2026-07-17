# Plan: Standalone Authorizations Endpoint

## Context

Authorizations currently exist only as an embedded array on the Patient model (`fern/definition/patients/v1/__package__.yml:509`). This means users must create a patient record before they can add authorizations. The goal is to create a new standalone authorizations service so users can create and manage authorizations independently.

## Approach

Follow the tags service pattern (simplest CRUD service in the codebase) with an added `getHistory` endpoint. Reuse existing `ReadPatients`/`WritePatients` permissions. No patient link.

## Files to Create

### 1. `fern/definition/authorizations/v1/__package__.yml` — Fern API definition
- Endpoints: `get`, `getHistory`, `getAll`, `create`, `update`, `deactivate`
- Types: `MutableAuthorization` (same fields as existing `Authorization` in patients definition), `Authorization` (extends `BaseModel` + `MutableAuthorization` + `id`), `AuthorizationPage`, `AuthorizationUnit`
- Base path: `/authorizations/v1`

### 2. `src/services/authorizations/schema.ts` — Zod schema
- Mirror the authorization Zod object from `src/services/patients/schema.ts:110` with `id` field added
- Reuse `additionalPayerInformation`, `patientServiceFacility`, `period` from `utils/commonSchemas`
- Single `v1` schema version

### 3. `src/services/authorizations/store.ts` — Data access layer
- Follow `src/services/tags/store.ts` pattern
- Methods: `getById`, `getHistory`, `getAllPaginated`, `create`, `update`, `deactivate`
- `getHistory` uses `this.versionedAccess.getFullHistory(id)` (same as `src/services/appointments/store.ts:405`)
- Fire pub/sub events on create/update

### 4. `src/services/authorizations/routes.ts` — Route handlers
- Follow `src/services/tags/routes.ts` pattern
- `ReadPatients` for read endpoints, `WritePatients` for write endpoints

### 5. `src/pubsub/v2/events/authorizationEvents.ts` — Pub/sub events
- Follow `src/pubsub/v2/events/tagEvents.ts` pattern
- Topic prefix: `preencounter_authorization`, entity: `Authorization`

### 6. `src/services/authorizations/store.test.ts` — Tests
- Follow `src/services/tags/store.test.ts` pattern
- Test create+read, create+read all, create+update, history

## Files to Modify

### 7. `fern/definition/common.yml` — Add `AuthorizationId`
- Add `AuthorizationId` type with `type: uuid` (like `CoverageId` on line 44)

### 8. `src/database/CollectionName.ts` — Add collection
- Add `"authorization" = "authorization"` enum entry

### 9. `src/fern.ts` — Register service
- Import `createAuthorizationsService` from `services/authorizations/routes`
- Add `authorizations: { v1: { _root: createAuthorizationsService() } }` to `register()` call

### 10. `src/utils/test/createOrganization.ts` — Add to test helper
- Import `AuthorizationsStore`, instantiate it, and return it

## Execution Order

1. Write the test file (`store.test.ts`) first — confirm it fails
2. Add `AuthorizationId` to `fern/definition/common.yml`
3. Create `fern/definition/authorizations/v1/__package__.yml`
4. Run `pnpm fg` to generate TypeScript types
5. Add `"authorization"` to `CollectionName` enum
6. Create `schema.ts`, `store.ts`, `routes.ts`, `authorizationEvents.ts`
7. Register in `fern.ts`
8. Add to `createOrganization.ts` test helper
9. Confirm tests pass with `bun test src/services/authorizations/store.test.ts`
10. Run full type check: `pnpm build`

## Verification

- `bun test src/services/authorizations/store.test.ts` — unit tests pass
- `pnpm build` — TypeScript compiles without errors
