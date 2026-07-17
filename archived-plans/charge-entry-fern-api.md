# Plan: Charge Entry & Claim Preview Fern API Definitions

## Context

The ER "Charge Ingestion milestone 2" calls for a new `charge_entry` API to replace `charge_capture`, adding universal claim support (professional + institutional), cleaner field organization, and dedicated status transition endpoints. This plan covers only the Fern definition changes needed to generate a preview link.

## Summary of Changes

| Action | File | Purpose |
|--------|------|---------|
| Modify | `fern/definition/commons.yml` | Add `ChargeEntryId` and `ClaimPreviewId` UUID types |
| Create | `fern/definition/charge-entry/v1/__package__.yml` | New charge entry service with 7 endpoints |
| Create | `fern/definition/claim-preview/v1/__package__.yml` | Internal claim preview GET/UPDATE API |

## Key Design Decisions

1. **`ChargeEntryData` extends `EncounterDeepOptional`** and adds universal/institutional fields (health_care_code_information, attending_provider, admission_hour, etc.). This reuses ~150 lines of deeply-optional types. The inherited `schema_instances` field still exists but is documented as unused (top-level `metadata` is canonical). The inherited `service_lines` uses `ServiceLineCreateOptional` (no `revenue_code`) -- acceptable for initial launch.

2. **Activate/deactivate are endpoints within the charge-entry service**, not a separate service file.

3. **Activate uses `literal<"billable">`** following the pattern in `fern/definition/claim-actions/v1/__package__.yml:107`.

4. **Reuse types from charge-capture via import** for `Hl7MessageType`, `ChargeCaptureError`, `ChargeCapturePostBilledChange`. Define new `ChargeEntryStatus` and `ChargeEntryDeactivateStatus` enums locally.

5. **Claim preview API** uses `audiences: [v1]` only (no `external`) to keep it internal.

---

## File 1: `fern/definition/commons.yml` (Modify)

Add after existing charge capture ID types:

```yaml
ChargeEntryId: uuid
ClaimPreviewId: uuid
```

## File 2: `fern/definition/charge-entry/v1/__package__.yml` (Create)

### Imports
```yaml
imports:
  commons: ../../commons.yml
  encounters: ../../encounters/v4/__package__.yml
  encounter-provider: ../../encounter-providers/v2/__package__.yml
  service-lines: ../../service-lines/v2/__package__.yml
  individual: ../../individual.yml
  billing-notes: ../../billing-notes/v2/__package__.yml
  claim-submission: ../../claim-submission/v1/__package__.yml
  guarantor: ../../guarantor/v1/__package__.yml
  custom-schemas: ../../custom-schemas/v1/__package__.yml
  claims: ../../claims.yml
  charge-capture: ../../charge-capture/v1/__package__.yml
  hi: ../../health-care-code-information/v1/__package__.yml
  x12: ../../x12/v1/__package__.yml
  tags: ../../tags.yml
```

### Service: base-path `/api/charge_entries/v1`, audiences `[external, v1]`, availability `in-development`

### Endpoints (7 total)

| Endpoint | Method | Path | Key difference from charge_capture |
|----------|--------|------|-----------------------------------|
| `create` | POST | `""` | Uses `ChargeEntryData` (universal shape), adds `submission_expectation` top-level field |
| `update` | PATCH | `/{charge_entry_id}` | **No `status` field** -- status changes only via activate/deactivate |
| `get` | GET | `/{charge_entry_id}` | Same pattern |
| `getAll` | GET | `""` | Same filters + `submission_expectation` filter. Omit ranked_sort params for initial launch |
| `activate` | POST | `/{charge_entry_id}/activate` | Request: `{ status: literal<"billable"> }`. 422 if already billable |
| `deactivate` | POST | `/{charge_entry_id}/deactivate` | Request: `{ status: ChargeEntryDeactivateStatus }`. 422 if already in that status |
| `updatePostBilledChanges` | PATCH | `/changes` | Reuses `charge-capture.ChargeCapturePostBilledChange` |

### Create request fields
- `data: ChargeEntryData` (required)
- `charge_external_id: string` (required)
- `patient_external_id: string` (required)
- `status: ChargeEntryStatus` (required)
- `submission_expectation: optional<encounters.EncounterSubmissionExpectation>` (defaults to TARGET_PROFESSIONAL)
- `originating_system: optional<string>`
- `claim_creation_category: optional<string>`
- `ehr_source_url: optional<string>`
- `attachment_external_document_ids: optional<list<string>>`
- `metadata: optional<list<custom-schemas.SchemaInstance>>`
- `hl7_message_type: optional<charge-capture.Hl7MessageType>`

### Update request fields
Same as create but all optional, and **no `status` field**.

### Types

**`ChargeEntryData`** -- extends `encounters.EncounterDeepOptional`, adds:
- `health_care_code_information: optional<hi.HealthCareCodeInformationCreate>`
- Institutional fields (all `availability: in-development`, all optional): `attending_provider`, `admission_hour`, `admission_type_code`, `admission_source_code`, `discharge_hour`, `discharge_status`, `operating_provider`, `other_operating_provider`, `type_of_bill`, `accident_state_or_province_code`
- Uses deeply-optional provider types (e.g., `encounter-provider.RenderingProviderUpdateWithOptionalAddress`) for institutional providers to match the pattern of all data fields being optional

**`ChargeEntry`** (response) -- properties:
- `id: commons.ChargeEntryId`
- `status: ChargeEntryStatus`
- `charge_entry_data: ChargeEntryData`
- `date_of_service: optional<date>`
- `patient_external_id: commons.PatientExternalId`
- `charge_external_id: string`
- `ehr_source_url: optional<string>`
- `originating_system: optional<string>`
- `claim_creation_category: optional<string>`
- `submission_expectation: optional<encounters.EncounterSubmissionExpectation>`
- `metadata: optional<list<custom-schemas.SchemaInstance>>`
- `error: optional<charge-capture.ChargeCaptureError>`
- `updates: list<charge-capture.ChargeCapturePostBilledChange>`
- `claim_creation_id: optional<commons.ChargeCaptureClaimCreationId>`

**`ChargeEntryStatus`** -- enum: PLANNED, NOT_BILLABLE, BILLABLE, ABORTED, ENTERED_IN_ERROR (same values as ChargeCaptureStatus)

**`ChargeEntryDeactivateStatus`** -- enum: PLANNED, NOT_BILLABLE, ABORTED, ENTERED_IN_ERROR (excludes BILLABLE)

**`ChargeEntryPage`** -- extends `commons.ResourcePage`, properties: `items: list<ChargeEntry>`, `item_count: integer`

**`ChargeEntrySortField`** -- enum: `created_at`, `date_of_service`

**`ChargeExternalIdConflictErrorMessage`** + error `ChargeExternalIdConflictError` (409) -- defined locally

## File 3: `fern/definition/claim-preview/v1/__package__.yml` (Create)

### Service: base-path `/api/claim_previews/v1`, audiences `[v1]` (internal only), availability `in-development`

### Endpoints

| Endpoint | Method | Path |
|----------|--------|------|
| `get` | GET | `/{claim_preview_id}` |
| `update` | PATCH | `/{claim_preview_id}` |

### Types

**`ClaimPreview`** -- properties:
- `id: commons.ClaimPreviewId`
- `bundle_id: commons.ChargeCaptureClaimCreationId`
- `data: optional<charge-entry.ChargeEntryData>`
- `created_at: datetime`
- `updated_at: datetime`

---

## Verification

1. Run `fern check` to validate all type references resolve
2. Run fern preview to generate the preview link
3. Verify no circular imports between charge-entry, charge-capture, and claim-preview

## Not in scope (future work)

- Deprecating existing `charge_capture` endpoints
- Moving bundle APIs (`charge-capture-bundles`) to internal-only
- Adding `create-from-pre-encounter` to charge-entry
- Adding `findByMetadata` to charge-entry
- Adding `UniversalServiceLineCreateOptional` with `revenue_code` support
- Adding ranked_sort query params to getAll
