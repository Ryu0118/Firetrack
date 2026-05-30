# Firetrack

[![Test](https://github.com/Ryu0118/Firetrack/actions/workflows/test.yml/badge.svg)](https://github.com/Ryu0118/Firetrack/actions/workflows/test.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform macOS](https://img.shields.io/badge/platform-macOS%2026-blue.svg)](https://www.apple.com/macos)
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Define your Firebase/GA4 analytics in YAML, generate type-safe Swift code & sync GA4 config.**

Firetrack makes your analytics contract _executable_. Analytics rot the moment three things disagree: the tracking plan in a spreadsheet, the event names hardcoded in your app, and the custom dimensions configured by hand in the GA4 console. Firetrack makes `firetrack.yml` the single source of truth — it validates the contract, generates type-safe Swift event code, and pushes missing definitions into GA4 over the Admin API. Change the YAML, regenerate, sync. No console clicking, no typo'd event names, no drift.

## Features

- 🦺 **Type-safe events that can't lie** — generated Swift enums turn a mistyped event name into a compile error, and the codegen parses its own output with SwiftSyntax before writing, so it never emits Swift that wouldn't compile
- 📋 **One contract, zero drift** — events, parameters, and GA4 dimensions flow from one YAML file; a parameter reused across events must agree on its type and allowed values, or `validate` fails — a guarantee a spreadsheet plan can't make
- ☁️ **Hands-off GA4 setup** — `ga4 sync` creates the matching custom dimensions, metrics, key events, and BigQuery links over the Admin API; no console clicking, and it only ever creates, never deletes

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/Firetrack/main/install.sh | bash
```

### Other methods

#### Nest ([mtj0928/nest](https://github.com/mtj0928/nest))

```bash
nest install Ryu0118/Firetrack
```

#### Mise ([jdx/mise](https://github.com/jdx/mise))

```bash
mise use -g ubi:Ryu0118/Firetrack[exe=firetrack]
```

#### Build from source

Requires Swift 6.2+ and macOS 26+.

```bash
git clone https://github.com/Ryu0118/Firetrack.git
cd Firetrack
swift build -c release
```

Verify with `firetrack --version`.

---

## Agent Skills

Firetrack ships a **`firetrack`** [Agent Skill](https://agentskills.io) so your AI agent
can install the CLI and adopt it in a project for you — set up `firetrack.yml`,
generate the Swift contract, and wire it into CI. Install it:

```bash
npx skills add Ryu0118/Firetrack --skill firetrack -g
```

Then tell your agent:

```
/firetrack set up an analytics tracking plan for my iOS app
```

---

## Quick start

1. Write `firetrack.yml` at your project root:

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

4. Build an event with no stringly-typed names, and log it to Firebase:

   ```swift
   let event = AnalyticsEvent.recordingCompleted(source: .app, distanceM: 1200)
   Analytics.logEvent(event.name, parameters: event.firebaseParameters)
   ```

   See [Logging to Firebase](#logging-to-firebase) for the one-time `firebaseParameters` bridge.

---

## Logging to Firebase

`firetrack generate` emits an `AnalyticsEvent` enum where every case carries its
parameters as compile-checked associated values, plus two computed properties:

```swift
enum AnalyticsEvent {
    case recordingCompleted(distanceM: Double, source: SourceValue)

    var name: String                       // "recording_completed"
    var parameters: [String: AnalyticsValue] // ["distance_m": .double(1200), "source": .string("app")]
}
```

`AnalyticsValue` is a closed enum (`.string` / `.int` / `.double` / `.bool`), so add a
small bridge to Firebase's untyped parameter dictionary **once** — in your app, not in
the generated file:

```swift
import FirebaseAnalytics

extension AnalyticsValue {
    var firebaseValue: Any {
        switch self {
        case let .string(value): value
        case let .int(value): value
        case let .double(value): value
        case let .bool(value): value
        }
    }
}

extension AnalyticsEvent {
    var firebaseParameters: [String: Any] {
        parameters.mapValues(\.firebaseValue)
    }

    /// Logs this event to Firebase Analytics.
    func log() {
        Analytics.logEvent(name, parameters: firebaseParameters)
    }
}
```

Now every call site is type-checked end to end — a wrong parameter name or type is a
compile error, and the event/param strings sent to Firebase always match the plan:

```swift
AnalyticsEvent.recordingCompleted(source: .app, distanceM: 1200).log()
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
firetrack ga4 diff                      # show what GA4 is missing (read-only)
firetrack ga4 sync                      # create the missing GA4 resources (--dry-run to preview)
firetrack doctor                        # diagnose GA4 readiness before sync (auth + property + token)
```

Every command reads `firetrack.yml` from the current directory by default; pass
`--config <path>` to point at a plan anywhere else.

| Command | Key flags |
|---------|-----------|
| `generate` | `--output` (required), `--access-level internal\|package\|public`, `--overwrite` |
| `ga4 diff` / `ga4 sync` | `--property-id`, `--impersonate-service-account`, `--big-query-project-number`, `--skip-custom-definitions`, `--skip-key-events`, `--skip-bigquery` |
| `ga4 sync` | `--dry-run` (preview without creating anything) |

---

## Safety model

- `ga4 diff` is **read-only** — it only reports what's missing.
- `ga4 sync` **creates missing resources only** — never deletes, archives, or renames anything in GA4.
- A BigQuery link pointing at a different project is a **hard error**, not a silent overwrite.
- `ga4 sync` applies by default; pass `--dry-run` to preview first.

---

## Authentication

Only the GA4 commands (`ga4 diff`, `ga4 sync`, `doctor`) need credentials — `validate`
and `generate` are fully offline.

**No tokens or keys go in `firetrack.yml`.** The plan holds only identifiers (GA4
property ID, service-account email, BigQuery project number). The access token is
resolved at runtime, in order:

1. **`GOOGLE_OAUTH_ACCESS_TOKEN`** environment variable — set this and `gcloud` is not needed
2. **Impersonated service account** (`ga4_sync.impersonate_service_account`, via IAMCredentials)
3. **`gcloud auth print-access-token`**

Firetrack reads exported shell variables, and also auto-loads a **`.env`** file from the
current directory — exported variables take precedence over `.env`. So either works:

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
firetrack ga4 sync

# or put it in .env (gitignored) at the project root:
echo 'GOOGLE_OAUTH_ACCESS_TOKEN=ya29....' > .env
firetrack ga4 sync
```

Impersonation requests the `analytics.edit` and `analytics.readonly` scopes.

---

## License

MIT — see [LICENSE](LICENSE).
