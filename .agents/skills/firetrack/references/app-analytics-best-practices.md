# App analytics best practices

Use this reference when designing or reviewing an app analytics tracking plan for
Firebase Analytics / GA4. The goal is not to log everything. The goal is to produce
trustworthy behavioral data that can answer product questions without leaking private
data or creating unmaintainable GA4 state.

## Start from questions

Define the questions before defining events.

- Activation: Which first actions predict D1/D7/D30 retention?
- Engagement: Which views or features produce meaningful repeated usage?
- Navigation: Where do users enter, loop, abandon, or backtrack?
- Reliability: Which errors, empty states, latency, or permission denials block success?
- Monetization: Which surfaces lead to paywall view, trial start, purchase, refund, or churn risk?

If an event does not support a question, a funnel, a cohort, a diagnostic, or a product
decision, do not add it.

## Event design

Prefer a small stable taxonomy with bounded parameters.

- Use stable `snake_case` event names and parameter names.
- Do not use dynamic event names or dynamic parameter keys.
- Put variants in parameters, not in event names.
- Use enum parameters for `source`, `surface`, `mode`, `result`, `reason`,
  `permission_status`, `plan`, `variant`, and similar fields.
- Keep numeric values numeric: counts, durations, distances, prices, indexes, and
  latency should not be strings.
- Use user properties only for slow-changing user traits; use event parameters for
  event context.

Useful event families:

- `screen_view`: user-visible route became active.
- `view_action`: meaningful interaction inside a screen.
- `view_exit`: tracked screen ended, with dwell time and next destination.
- `flow_started`, `flow_step_completed`, `flow_completed`, `flow_abandoned`: onboarding,
  checkout, recording, import/export, permission flows.
- `permission_prompted`, `permission_result`: OS or app permission outcomes.
- `error_presented`, `operation_failed`: user-visible failures and recoverability.
- `feature_used`: durable feature usage that matters for retention.
- `paywall_viewed`, `purchase_started`, `purchase_completed`, `purchase_failed`:
  monetization.

## Screen and view analytics

Screen views alone are insufficient. To understand view behavior, log entry, meaningful
actions, and exit.

Recommended parameters:

- `screen_name`: stable route-level name, not a localized title.
- `screen_class`: feature/module/container name when useful.
- `previous_screen_name`: previous stable screen.
- `next_screen_name`: next stable screen on exit.
- `entry_source`: tab, deep_link, push, widget, shortcut, onboarding, internal_link.
- `exit_reason`: navigation, background, dismiss, completion, cancel, error, timeout.
- `dwell_ms`: foreground visible duration.
- `action_name`: normalized interaction name.
- `element_id`: stable UI element identifier when action analysis needs it.
- `result`: success, failure, cancelled, denied, unavailable.

Gotchas:

- SwiftUI can re-render and re-trigger appearances; debounce route-level `screen_view`.
- Do not log every transient subview as a screen.
- Track important sheets/modals only when they are product surfaces.
- Pause dwell timers when the app backgrounds or another surface fully covers the view.
- Track exits explicitly; otherwise abandonment and dwell time become guesswork.

## Firebase / GA4 registration

GA4 custom definitions are for reporting surfaces, not for every parameter.

- Register event-scoped custom dimensions for low-cardinality categorical parameters
  needed in GA4 UI or Data API reports.
- Register custom metrics for numeric parameters that need aggregation in GA4 reports.
- Keep high-cardinality values in BigQuery only.
- Custom event parameters can appear in BigQuery export even when not registered as GA4
  custom definitions.
- Key events should represent real business outcomes, not every tap.
- Do not rely on manual GA4 console state; make registration intent reviewable.

Good GA4 dimensions:

- `screen_name`, `entry_source`, `source`, `surface`, `mode`, `result`,
  `failure_reason`, `permission_status`, `plan`, `variant`.

Bad GA4 dimensions:

- IDs, timestamps, exact addresses, coordinates, raw error messages, search text,
  free-form names, full dynamic routes, raw URLs.

## BigQuery and MCP analysis

Use GA4 reports for curated reporting and BigQuery for raw truth.

High-value BigQuery analyses:

- View counts by screen, app version, country, and acquisition source.
- Average and percentile dwell time per screen.
- Exit rate by screen and exit reason.
- Navigation paths: previous screen -> screen -> next screen.
- Funnel conversion and abandonment by step.
- Activation cohorts: first meaningful event -> D1/D7/D30 retention.
- Feature adoption and repeated usage.
- Permission denial or error impact on conversion.
- Schema drift: observed events/parameters not in the tracking plan, and planned events
  never observed.

For MCP-based analysis:

1. Read the tracking plan first.
2. Use GA4/Data API for registered report-level checks.
3. Use BigQuery for raw event SQL, pathing, cohorts, dwell time, and schema validation.
4. Always state date range, timezone, app version filters, sample size, and query assumptions.
5. Do not infer event semantics from names alone; use descriptions, fire conditions, enum
   values, owners, and PII flags.

## Privacy and safety

Never log:

- Exact addresses, raw location traces, precise coordinates, or route polylines.
- Names, emails, phone numbers, notes, search text, free-form user text, or identifiers
  that can identify a person.
- Raw error messages that may contain user data.
- Advertising identifiers or device identifiers unless there is an explicit consent and
  compliance model.

Prefer coarse, bounded, and product-meaningful values:

- `distance_bucket`, `duration_bucket`, `permission_status`, `failure_reason`,
  `entry_source`, `result`, `mode`.

## Review checklist

- Every event answers a real question.
- Event names, parameter names, and enum values are stable `snake_case`.
- Required parameters are truly required at every call site.
- Numeric parameters use numeric types.
- GA4 custom dimensions are low-cardinality.
- High-cardinality analysis fields are kept for BigQuery, not GA4 UI.
- Screen behavior includes view entry, important actions, exits, and dwell time.
- No PII or raw sensitive context is logged.
- DebugView confirms expected events, names, parameters, and types.
- The generated app code, GA4 definitions, and analysis assumptions all match the plan.
