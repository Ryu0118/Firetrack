---
name: firetrack
description: The single skill for everything Firetrack. Use when (a) installing or adopting the Firetrack CLI in a project — set up a firetrack.yml tracking plan as the source of truth for Firebase Analytics / GA4, install the firetrack binary (install script, mise, or nest), generate type-safe Swift analytics code, or wire validate/generate into CI; (b) designing, validating, syncing, or analyzing a Firebase Analytics / GA4 tracking plan; or (c) editing the Firetrack Swift package itself — its CLI, GA4 sync logic, YAML validation, Swift code generator, tests, or docs. Triggers include "install firetrack", "set up firetrack", "add analytics tracking plan", "adopt firetrack", "design a GA4 tracking plan", "sync GA4 custom dimensions", and "work on the Firetrack package".
---

# Firetrack

Firetrack turns one YAML file (`firetrack.yml`) into the source of truth for
Firebase Analytics / GA4: it **validates** the contract, **syncs** missing GA4 custom
dimensions/metrics/key-events/BigQuery links, and **generates** type-safe Swift event
code. The config file `firetrack.yml` is the default `--config` path; the CLI binary
is `firetrack`.

This skill covers three jobs. Jump to the section that matches the task:

- **Adoption** — install the CLI and wire it into a project (§1–§5).
- **Tracking-plan design & GA4** — design a good plan and sync it to GA4 (§6).
- **Package development** — work on the Firetrack Swift package itself (§7).

When designing the tracking plan, first read
[references/app-analytics-best-practices.md](references/app-analytics-best-practices.md).
Firetrack should encode a well-designed app analytics strategy; it should not cause
agents to create event spam just because YAML makes events easy to declare.

---

## Adoption

### 1. Install the `firetrack` CLI

Three supported methods — pick what matches the user's toolchain.

**Install script** (no toolchain required):
```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/Firetrack/main/install.sh | VERSION=0.1.0 bash
```
Installs to `~/.local/bin` (override with `INSTALL_DIR=...`). Re-runs are idempotent;
force a reinstall with `FORCE=1`. The installer verifies the release archive checksum.

**mise** (`jdx/mise`):
```bash
mise use -g ubi:Ryu0118/Firetrack[exe=firetrack]
```

**nest** (`mtj0928/nest`) — add to the project `nestfile.yaml` and bootstrap:
```yaml
- reference: Ryu0118/Firetrack
  version: 0.1.0
```
```bash
nest bootstrap nestfile.yaml   # binary lands in .nest/bin/firetrack
```

Verify: `firetrack --version`. Requires **macOS 26+**.

### 2. Create the tracking plan

Two scaffolding shortcuts, or write the file by hand:

- **Greenfield**: `firetrack init` writes a minimal, valid starter `firetrack.yml`.
- **Brownfield** (a GA4 property already exists): `firetrack pull` reads the
  property's custom dimensions/metrics/key events and writes a starting plan.
  This is a **scaffold, not a mirror** — GA4 has no event/parameter-type schema,
  so dimensions come back as `string`, metrics as `double`, and events as stubs.
  Review and edit (especially parameter types) before syncing.

Both refuse to overwrite an existing file without `--overwrite`.

Place `firetrack.yml` at the working-directory root (the default `--config` path;
override with `--config <path>` to put it anywhere). Minimal valid plan:

```yaml
version: 1
platforms: [ios]
events:
  recording_completed:
    description: Drive recording completed and saved successfully.
    parameters:
      source:
        type: enum
        required: true
        allowed: [app, widget]
        ga4_custom_dimension: true
      distance_m:
        type: double
        required: true
        ga4_custom_metric: true
```

Full schema (destinations, ga4_sync, global_parameters, screens, parameter types,
naming rules, GA4 custom dimension/metric flags): see
[references/yaml-schema.md](references/yaml-schema.md).

### 3. Validate and generate

```bash
firetrack validate --config firetrack.yml
firetrack generate --config firetrack.yml \
  --output Sources/Analytics/GeneratedAnalytics.swift \
  --access-level internal --overwrite
```

`generate` is deterministic (byte-stable for identical YAML) and the output is parsed
by SwiftParser before being written. Use the generated `AnalyticsEvent` enum:

```swift
let event = AnalyticsEvent.recordingCompleted(source: .app, distanceM: 1200)
```

### 4. (Optional) Sync GA4

Preview with `--dry-run` first, then run sync for real. Sync only **creates** missing
resources — it never deletes, archives, or renames remote GA4 resources.

```bash
firetrack ga4 diff --config firetrack.yml               # read-only diff
firetrack ga4 sync --config firetrack.yml --dry-run     # preview, no changes
firetrack ga4 sync --config firetrack.yml               # create missing
firetrack doctor --config firetrack.yml                 # check auth/config
firetrack doctor --config firetrack.yml --check-remote  # also list remote drift (read-only)
```

`doctor --check-remote` lists custom dimensions/metrics that exist in GA4 but are
absent from the plan. It only reports — Firetrack never deletes remote resources.

Auth resolves from `GOOGLE_OAUTH_ACCESS_TOKEN`, then `gcloud auth print-access-token`.
When `ga4_sync.impersonate_service_account` is configured, the resolved base credential
is always exchanged through IAMCredentials. Read-only commands request
`analytics.readonly`; applying sync requests `analytics.edit`.

### 5. Wire into CI

Validate the plan and assert generated code is up to date on every PR:

```yaml
- run: firetrack validate --config firetrack.yml
- run: |
    firetrack generate --config firetrack.yml \
      --output Sources/Analytics/GeneratedAnalytics.swift --overwrite
    git diff --exit-code Sources/Analytics/GeneratedAnalytics.swift
```

The second step fails the build if a committed plan change wasn't regenerated.
Keep GA4 `sync` out of CI unless service-account auth is configured as a secret (it
applies by default — use `--dry-run` if you only want a CI preview).

---

## Tracking-plan design & GA4

Design the plan contract-first. Declare events, screens, parameters, key events,
custom dimensions, custom metrics, and BigQuery link intent in `firetrack.yml`.

Benefits:

- deterministic, reviewable analytics changes
- repeatable GA4 Admin API setup without GUI clicking
- code generation that removes event-name and parameter-name drift
- MCP/agent analysis can reason over one YAML contract

### Naming

Name events `object_action` with a past-tense verb — the convention every major
analytics vendor converges on (`recording_completed`, `paywall_viewed`,
`purchase_failed`), not `completed_recording` or `recordingDone`. Put variants in
enum parameters, never in the event name (`add_to_cart` + `item`, not
`add_shirt_to_cart`). Event, parameter, and enum-value names are `snake_case`;
`validate` enforces that. See
[references/app-analytics-best-practices.md](references/app-analytics-best-practices.md).

### Out of scope: experimentation

Firetrack is the event-taxonomy layer. A/B testing and feature flags
(Firebase A/B Testing, Statsig, GrowthBook, …) sit *on top* of it — they read the
events Firetrack defines but assign variants and compute statistics at runtime.
Keep that layer separate; do not model experiment assignment or variant logic in
`firetrack.yml`. A variant is fine as an enum *parameter* on an event; the
experiment engine itself is not Firetrack's job.

### Practical event coverage

For product analytics, make sure the plan can answer:

- which views opened, with `screen_name`
- important view actions, with `action_name`, `element_id`, and `result`
- view exits, with `next_screen_name`, `exit_reason`, and `dwell_ms`
- funnel steps such as onboarding, recording start/completion, paywall view,
  purchase start, purchase completion
- quantitative metrics such as `distance_m`, `duration_sec`, `session_count`,
  and `visible_chart_count`

### ECommerce items

For the 14 reserved ECommerce events (`view_item`, `add_to_cart`, `purchase`,
`refund`, …), declare an `items` map on the event for item-scoped fields. This is
the only place a structured (array-of-object) parameter is allowed — Firebase
rejects arbitrary nested/array parameters everywhere else. Item fields are flat
scalars (no `enum`); reserved fields (`item_id`, `price`, `quantity`, …) are
type-checked and up to 27 custom item params are allowed. `generate` produces a
typed `{Event}Item` struct and bridges the array under `"items"`. Item-scoped GA4
custom definitions are not synced (item values reach BigQuery regardless). See
[references/yaml-schema.md](references/yaml-schema.md) for the full shape.

### What Firetrack registers in GA4

- event-scoped custom dimensions from `ga4_custom_dimension: true`
- event-scoped custom metrics from `ga4_custom_metric: true`
- key events from `ga4_sync.key_events`
- BigQuery links from `ga4_sync.bigquery_link`

Dry-run first. Apply only after the missing resources look correct. The commands in
§4 are the same whether you installed the binary or run from source (§7).

---

## Package development

When editing the Firetrack Swift package, keep the module boundaries strict.

### Module boundaries

- `Sources/firetrack`: executable wrapper only. It imports `FiretrackCLI` and calls `FiretrackCommand.main()`.
- `FiretrackCLI`: ArgumentParser declarations only. Command `run()` methods construct request values and call `XXXRunner(...).run(...)`.
- `FiretrackOperations`: runners, output formatting, dependency wiring, and filesystem writes.
- `FiretrackConfiguration`: Yams decoding, schema models, validation, naming conversion, and GA4 desired-state extraction.
- `FiretrackGA4`: GA4 Admin API client, auth token providers, remote state, diff, and apply.
- `FiretrackSwiftGenerator`: string-based generated Swift analytics contract, validated by parsing (SwiftParser) before write.

Never put Yams, URLSession, SwiftParser, GA4 endpoint strings, or diff logic in `FiretrackCLI`.

### Workflow

1. Write or update focused tests first.
2. Run `swift test`.
3. Run `swift build`.
4. Validate the tracking plan: `swift run firetrack validate --config firetrack.yml`.
5. For GA4 work, preview with `--dry-run` before syncing for real:
   - `swift run firetrack ga4 diff --config firetrack.yml`
   - `swift run firetrack ga4 sync --config firetrack.yml --dry-run`
   - `swift run firetrack ga4 sync --config firetrack.yml`

### Design rules

- YAML is the source of truth.
- Output must be deterministic (byte-stable for identical input).
- GA4 sync creates missing resources only — never delete, archive, or rename remote GA4 resources.
- Generated Swift must parse (SwiftParser) before being written.
