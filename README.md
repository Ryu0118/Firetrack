# Firetrack

[![Test](https://github.com/Ryu0118/Firetracker/actions/workflows/test.yml/badge.svg)](https://github.com/Ryu0118/Firetracker/actions/workflows/test.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform macOS](https://img.shields.io/badge/platform-macOS%2026-blue.svg)](https://www.apple.com/macos)
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**One YAML file is your analytics contract. Firetrack keeps your code, your GA4 config, and your tracking plan from ever drifting apart.**

Analytics rot the moment three things disagree: the tracking plan in a spreadsheet, the event names hardcoded in your app, and the custom dimensions configured by hand in the GA4 console. Firetrack makes `analytics-tracking-plan.yaml` the single source of truth — it validates the contract, generates type-safe Swift event code, and pushes missing definitions into GA4 over the Admin API. Change the YAML, regenerate, sync. No console clicking, no typo'd event names, no drift.

## Features

- 📋 **One contract, zero drift** — events, parameters, and GA4 dimensions all flow from one validated YAML file
- 🦺 **Type-safe events** — generated Swift enums make a mistyped event name a compile error, not a silent data gap
- ☁️ **Hands-off GA4 setup** — sync custom dimensions, metrics, key events, and BigQuery links straight from the plan, no console required

## Installation

**Install script** — no toolchain needed:

```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/Firetracker/main/install.sh | bash
```

<details>
<summary>Other methods (mise, nest, from source)</summary>

```bash
# mise
mise use -g ubi:Ryu0118/Firetracker[exe=firetrack]

# nest — add to nestfile.yaml, then: nest bootstrap nestfile.yaml
#   - reference: Ryu0118/Firetracker
#     version: 0.1.0

# from source (Swift 6.2, macOS 26+)
git clone https://github.com/Ryu0118/Firetracker.git
cd Firetracker && swift build -c release
```

</details>

Verify with `firetrack --version`. Requires **macOS 26+**.

---

## Quick start

1. Write `Documents/analytics-tracking-plan.yaml`:

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

2. Validate it:

   ```bash
   firetrack validate
   ```

3. Generate type-safe Swift:

   ```bash
   firetrack generate --output Sources/Analytics/GeneratedAnalytics.swift --overwrite
   ```

4. Log events with no stringly-typed names:

   ```swift
   let event = AnalyticsEvent.recordingCompleted(source: .app, distanceM: 1200)
   ```

---

## The YAML contract

```yaml
version: 1
platforms: [ios]

destinations:
  firebase_analytics:
    enabled: true
  ga4:
    property_id: "YOUR_GA4_PROPERTY_ID"
  bigquery:
    project_id: your-project
    project_number: "YOUR_PROJECT_NUMBER"
    dataset: analytics_YOUR_PROJECT_NUMBER

ga4_sync:
  impersonate_service_account: your-service-account@your-project.iam.gserviceaccount.com
  key_events:
    - recording_completed
  bigquery_link:
    enabled: true
    project_number: "YOUR_PROJECT_NUMBER"
    daily_export_enabled: true
    streaming_export_enabled: true
    dataset_location: US

global_parameters:
  source:
    type: enum
    allowed: [app, widget]
    ga4_custom_dimension: true

events:
  recording_completed:
    pii: false
    parameters:
      source:
        type: enum
        required: true
        ga4_custom_dimension: true
      distance_m:
        type: double
        required: true
        ga4_custom_metric: true
```

`validate` enforces snake_case names, GA4-safe prefixes, metric type rules
(`int`/`double` only), enum value formatting, and key-event references —
deterministically, with sorted output. `ga4_custom_metric` units are inferred
from the name suffix (`_ms`, `_sec`, `_m`).

---

## Commands

```bash
firetrack validate                      # verify the plan: schema, names, rules (offline, no auth)
firetrack generate --output <path>      # emit type-safe Swift (--overwrite, --access-level)
firetrack ga4 diff                      # show what GA4 is missing (dry-run)
firetrack ga4 sync --apply              # create the missing GA4 resources
firetrack doctor                        # diagnose GA4 readiness before sync (auth + property + token)
```

Every command takes `--plan <path>` (default `Documents/analytics-tracking-plan.yaml`).

**`validate` vs `doctor`**: `validate` checks the plan *file* alone — schema, snake_case
names, type/enum rules — with no network or credentials. `doctor` re-runs that check and
then probes whether you can actually *sync*: GA4 property ID, service account, and a live
`gcloud` token. Use `validate` in CI on every change; run `doctor` before your first `ga4 sync`.

| Command | Key flags |
|---------|-----------|
| `generate` | `--output` (required), `--access-level internal\|package\|public`, `--overwrite` |
| `ga4 diff` / `ga4 sync` | `--property-id`, `--impersonate-service-account`, `--big-query-project-number`, `--skip-custom-definitions`, `--skip-key-events`, `--skip-bigquery` |
| `ga4 sync` | `--apply` (without it, sync is a dry-run) |

---

## Safety model

`ga4 diff` and `ga4 sync` (without `--apply`) are dry-runs. Apply mode **only
creates missing resources** — Firetrack never deletes, archives, or renames GA4
resources, and an existing BigQuery link pointing at a different project is a hard
error. Tokens are resolved in order: `GOOGLE_OAUTH_ACCESS_TOKEN` → impersonated
service account (IAMCredentials) → `gcloud auth print-access-token`.

---

## Architecture

```mermaid
graph TD
    Wrapper["firetrack<br/>executable"] --> CLI["FiretrackCLI<br/>ArgumentParser"]
    CLI --> Ops["FiretrackOperations<br/>runners / output"]
    Ops --> Config["FiretrackConfiguration<br/>YAML / validation"]
    Ops --> GA4["FiretrackGA4<br/>Admin API / auth"]
    Ops --> Gen["FiretrackSwiftGenerator<br/>SwiftSyntax codegen"]
    GA4 --> Config
    Gen --> Config
```

Generated Swift is byte-stable for identical YAML and is parsed with SwiftSyntax
before it is ever written to disk.

---

## CI integration

```yaml
- run: firetrack validate
- run: |
    firetrack generate --output Sources/Analytics/GeneratedAnalytics.swift --overwrite
    git diff --exit-code Sources/Analytics/GeneratedAnalytics.swift
```

The build fails if a plan change wasn't regenerated and committed.

---

## License

MIT — see [LICENSE](LICENSE).
