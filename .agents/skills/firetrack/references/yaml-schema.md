# firetrack.yml schema

Complete reference for the Firetrack tracking-plan contract (`version: 1`).

Unknown keys, duplicate keys, and schema versions other than `version: 1` are rejected.

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
    description: Drive recording completed successfully.   # optional; becomes a /// doc comment
    fire_when: The user stops a recording and it saves.    # optional; documents the trigger
    owner: product                                         # optional; team/domain owner
    retention_anchor: true                                 # optional; activation/retention anchor
    parameters:
      source:
        type: enum
        required: true
        display_name: Recording Source                     # optional; GA4 custom dimension display name
        description: Where the recording was started from. # optional; GA4 custom definition description
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

Event metadata fields (`description`, `fire_when`, `owner`, `retention_anchor`)
are not enforced by `validate` — they document intent and feed reporting:
`description` becomes a doc comment on the generated Swift case, and `doctor`
surfaces missing `owner`/`fire_when` coverage and lists retention anchors.

## items (ECommerce)

Only the 14 reserved ECommerce events accept an `items` map (`view_item`,
`add_to_cart`, `view_cart`, `begin_checkout`, `purchase`, `refund`,
`view_promotion`, … — see Firebase's measure-ecommerce list). Declaring `items`
on any other event is a validation error. Each item field is a **flat scalar**
(`enum` is not allowed); reserved field names (`item_id`, `item_name`, `price`,
`quantity`, `item_category`, …) must use their canonical type, and any other
field is a custom item parameter (snake_case, no reserved prefix, max 27).

```yaml
events:
  purchase:
    parameters:
      value:
        type: double
        required: true
    items:
      item_id: { type: string, required: true }   # reserved → must be string
      price: { type: double, required: true }      # reserved → must be double
      quantity: { type: int }
      gift_wrap: { type: bool }                     # custom item param
```

`generate` emits a typed `{Event}Item` struct and an `items: [{Event}Item]`
associated value on the case; items are bridged under the `"items"` key in
`firebaseParameters`. Item fields take **no** `ga4_custom_dimension`/
`ga4_custom_metric` flags — item-scoped GA4 custom definitions are not synced
yet (item values still reach BigQuery). The 200-items-per-event and
100-character-value caps are runtime limits, not validated here.

## Parameter types

| Field | Values | Notes |
|-------|--------|-------|
| `type` | `enum`, `string`, `int`, `double`, `bool` | required |
| `required` | `true` / `false` | default `false` |
| `allowed` | list of snake_case values | for `type: enum` |
| `description` | free text | GA4 custom definition description (falls back to a default) |
| `display_name` | free text | GA4 custom dimension/metric display name (falls back to the humanized name) |
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
- `items` is only valid on a reserved ECommerce event; reserved item fields must
  use their canonical type; item fields cannot be `enum`; at most 27 custom item
  parameters.
- Unknown YAML keys and schema versions other than `version: 1` are rejected.
- `TODO` placeholders in `destinations`/`ga4_sync` must be replaced before sync.
