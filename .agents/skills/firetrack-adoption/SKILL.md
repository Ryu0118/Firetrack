---
name: firetrack-adoption
description: Install the Firetrack CLI and adopt it in a project. Use when a user wants to add Firetrack to their app, set up an analytics-tracking-plan.yaml as the source of truth for Firebase Analytics / GA4, install the firetrack binary (install script, mise, or nest), generate type-safe Swift analytics code, or wire Firetrack validate/generate into CI. Triggers include "install firetrack", "set up firetrack", "add analytics tracking plan", "adopt firetrack", and "firetrack in my project".
---

# Firetrack Adoption

Firetrack turns one YAML file (`analytics-tracking-plan.yaml`) into the source of
truth for Firebase Analytics / GA4: it **validates** the contract, **syncs** missing
GA4 custom dimensions/metrics/key-events/BigQuery links, and **generates** type-safe
Swift event code. This skill covers installing the CLI and adopting it in a project.

> For authoring/validating/syncing the tracking plan itself, use the
> `firebase-ga4-analytics-pro` skill. This skill is install + adoption only.

## 1. Install the `firetrack` CLI

Three supported methods — pick what matches the user's toolchain.

**Install script** (no toolchain required):
```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/Firetracker/main/install.sh | bash
```
Installs to `~/.local/bin` (override with `INSTALL_DIR=...`). Re-runs are idempotent;
force a reinstall with `FORCE=1`. Pin a version with `VERSION=0.1.0`.

**mise** (`jdx/mise`):
```bash
mise use -g ubi:Ryu0118/Firetracker[exe=firetrack]
```

**nest** (`mtj0928/nest`) — add to the project `nestfile.yaml` and bootstrap:
```yaml
- reference: Ryu0118/Firetracker
  version: 0.1.0
```
```bash
nest bootstrap nestfile.yaml   # binary lands in .nest/bin/firetrack
```

Verify: `firetrack --version`. Requires **macOS 26+**.

## 2. Create the tracking plan

Place `analytics-tracking-plan.yaml` at the project root (or `Documents/`). Minimal
valid plan:

```yaml
version: 1
platforms: [ios]
events:
  recording_completed:
    pii: false
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

## 3. Validate and generate

```bash
firetrack validate --plan analytics-tracking-plan.yaml
firetrack generate --plan analytics-tracking-plan.yaml \
  --output Sources/Analytics/GeneratedAnalytics.swift \
  --access-level internal --overwrite
```

`generate` is deterministic (byte-stable for identical YAML) and the output is parsed
by SwiftSyntax before being written. Use the generated `AnalyticsEvent` enum:

```swift
let event = AnalyticsEvent.recordingCompleted(source: .app, distanceM: 1200)
```

## 4. (Optional) Sync GA4

Dry-run first, then apply. Apply only **creates** missing resources — it never deletes,
archives, or renames remote GA4 resources.

```bash
firetrack ga4 diff --plan analytics-tracking-plan.yaml          # dry-run
firetrack ga4 sync --plan analytics-tracking-plan.yaml --apply  # create missing
firetrack doctor --plan analytics-tracking-plan.yaml            # check auth/config
```

Auth resolves in order: `GOOGLE_OAUTH_ACCESS_TOKEN` → `ga4_sync.impersonate_service_account`
(IAMCredentials) → `gcloud auth print-access-token`. Required scopes:
`analytics.edit`, `analytics.readonly`.

## 5. Wire into CI

Validate the plan and assert generated code is up to date on every PR:

```yaml
- run: firetrack validate --plan analytics-tracking-plan.yaml
- run: |
    firetrack generate --plan analytics-tracking-plan.yaml \
      --output Sources/Analytics/GeneratedAnalytics.swift --overwrite
    git diff --exit-code Sources/Analytics/GeneratedAnalytics.swift
```

The second step fails the build if a committed plan change wasn't regenerated.
Keep GA4 `sync --apply` out of CI unless service-account auth is configured as a secret.
