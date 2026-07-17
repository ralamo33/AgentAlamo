# Authorization Data Model

## `MutableAuthorization` (what users send on create/update)

These are the same fields from the existing patient-embedded `Authorization` type (`fern/definition/patients/v1/__package__.yml:584`):

| Field | Type | Required | Description |
|---|---|---|---|
| `payer_id` | `PayerId` | yes | Insurance payer identifier |
| `payer_name` | `string` | yes | Name of the payer |
| `additional_payer_information` | `AdditionalPayerInformation` | no | Availity payer IDs and names |
| `authorization_number` | `string` | yes | The authorization number |
| `cpt_code` | `string` | yes | CPT code for the authorization |
| `apply_for_all_cpt_codes` | `boolean` | no | Apply to all claims for this payer in the period |
| `no_prior_authorization_required` | `boolean` | no | Indicates prior auth isn't needed |
| `units` | `AuthorizationUnit` | yes | Either `VISIT` or `UNIT` |
| `quantity` | `integer` | no | Number of units authorized |
| `period` | `Period` (start/end dates) | no | Validity window |
| `notes` | `string` | no | Free text notes |
| `billing_provider_npi` | `string` | no | NPI of the billing provider this applies to |
| `service_facility` | `PatientServiceFacility` | no | Service facility this applies to |
| `dx_codes` | `set<string>` | no | Diagnosis codes this applies to |

## `Authorization` (what the API returns)

Extends `MutableAuthorization` and adds server-managed fields:

| Field | Type | Source |
|---|---|---|
| `id` | `AuthorizationId` (uuid) | Generated on create |
| `organization_id` | `OrganizationId` | From `BaseModel` — set by auth context |
| `version` | `integer` | From `BaseModel` — incremented on each update |
| `deactivated` | `boolean` | From `BaseModel` — set via deactivate endpoint |
| `updated_at` | `datetime` | From `BaseModel` — auto-set |
| `updating_user_id` | `UserId` | From `BaseModel` — from auth context |

## Key design decisions

- **Exact same fields as patient-embedded authorizations** — no new fields, no removed fields. Keeps the two representations consistent.
- **No `patient_id`** — fully independent, not linked to a patient record.
- **`AuthorizationId` uses `uuid` type** (like `CoverageId`) rather than `string` (like `TagId`) for stronger type safety.
- **Versioned with optimistic locking** — updates require the current version number in the URL path, consistent with all other resources in the API.

## Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/authorizations/v1` | Create a new authorization |
| `GET` | `/authorizations/v1/{id}` | Get an authorization by ID |
| `GET` | `/authorizations/v1/{id}/history` | Get full version history |
| `GET` | `/authorizations/v1` | List all (paginated, query params: `limit`, `page_token`) |
| `PUT` | `/authorizations/v1/{id}/{version}` | Update an authorization |
| `DELETE` | `/authorizations/v1/{id}/{version}` | Deactivate an authorization |

## Permissions

- Read endpoints: `read:pre-encounter:patients` (reuses existing)
- Write endpoints: `write:pre-encounter:patients` (reuses existing)
