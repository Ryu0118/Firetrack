# firetrack.yml schema

Complete reference for the Firetrack tracking-plan contract (`version: 1`).

## Contents

- [Top level](#top-level)
- [destinations](#destinations)
- [ga4_sync](#ga4_sync)
- [global_parameters](#global_parameters)
- [screens](#screens)
- [events](#events)
- [Parameter types](#parameter-types)
- [Naming & validation rules](#naming--validation-rules)

## Top level

```yaml
version: 1                 # schema version (required, currently 1)
platforms: [ios]           # target platforms, e.g. [ios], [android]
destinations: { ... }      # optional — Firebase/GA4/BigQuery connection info
ga4_sync: { ... }          # optional — GA4 Admin API sync settings
global_parameters: { ... } # optional — parameters shared by all events
screens: { ... }           # optional — screen/view definitions
events: { ... }            # event definitions (the core of the plan)
```

## destinations

```yaml
destinations:
  firebase_analytics:
    enabled: true
  ga4:
    property_id: "YOUR_GA4_PROPERTY_ID"          # GA4 property ID (numeric string)
  bigquery:
    project_id: my-project
    project_number: "YOUR_PROJECT_NUMBER"
    dataset: analytics_YOUR_PROJECT_NUMBER
```

## ga4_sync

```yaml
ga4_sync:
  impersonate_service_account: svc@my-project.iam.gserviceaccount.com
  key_events:
    - recording_completed             # event names promoted to GA4 key events
  bigquery_link:
    enabled: true
    project_number: "YOUR_PROJECT_NUMBER"
    daily_export_enabled: true
    streaming_export_enabled: true
    dataset_location: US
```

## global_parameters

Parameters merged into every event. Same shape as per-event parameters.

```yaml
global_parameters:
  source:
    type: enum
    allowed: [app, widget]
    ga4_custom_dimension: true
```

## screens

Optional screen/view registry.

```yaml
screens:
  DriveRecordScreen:
    route: tab.record
    owner: product
    primary_action: recording_started
```

## events

```yaml
events:
  recording_completed:
    description: Drive recording completed successfully.   # optional
    owner: product                                         # optional
    retention_anchor: true                                 # optional
    pii: false                                             # must be false in v1
    parameters:
      source:
        type: enum
        required: true
        ga4_custom_dimension: true
      distance_m:
        type: double
        required: true
        ga4_custom_metric: true
      duration_sec:
        type: int
        required: false
        ga4_custom_metric: true
```

## Parameter types

| Field | Values | Notes |
|-------|--------|-------|
| `type` | `enum`, `string`, `int`, `double`, `bool` | required |
| `required` | `true` / `false` | default `false` |
| `allowed` | list of snake_case values | for `type: enum` |
| `ga4_custom_dimension` | `true` | register as GA4 custom dimension |
| `ga4_custom_metric` | `true` | register as GA4 custom metric — **only `int`/`double`** |

GA4 metric measurement unit is inferred from the parameter-name suffix:
`_ms` → MILLISECONDS, `_sec` → SECONDS, `_m` → METERS, otherwise STANDARD.

## Naming & validation rules

`firetrack validate` enforces these deterministically (errors are sorted):

- Event and parameter names must be `snake_case`.
- Event names must not use GA4 reserved prefixes.
- `ga4_custom_metric` is only valid on `int`/`double` parameters.
- `enum` values in `allowed` must be `snake_case`.
- Every `ga4_sync.key_events` entry must reference a defined event.
- `pii: true` is **not supported in v1** — keep it `false`.
- `TODO` placeholders in `destinations`/`ga4_sync` must be replaced before sync.
