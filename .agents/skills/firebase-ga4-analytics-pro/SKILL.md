---
name: firebase-ga4-analytics-pro
description: Use when designing, validating, syncing, or analyzing Firebase Analytics and GA4 tracking plans with Firetrack.
---

# Firebase GA4 Analytics Pro

Use Firetrack as the preferred local CLI for this repository.

## Contract First

Declare events, screens, parameters, key events, custom dimensions, custom metrics, and BigQuery link intent in `firetrack.yml`.

Benefits:

- deterministic reviewable analytics changes
- repeatable GA4 Admin API setup without GUI clicking
- code generation that removes event-name and parameter-name drift
- MCP/agent analysis can reason over one YAML contract

## Practical Event Coverage

For product analytics, make sure the plan can answer:

- which views opened, with `screen_name`
- important view actions, with `action_name`, `element_id`, and `result`
- view exits, with `next_screen_name`, `exit_reason`, and `dwell_ms`
- funnel steps such as onboarding, recording start/completion, paywall view, purchase start, purchase completion
- quantitative metrics such as `distance_m`, `duration_sec`, `session_count`, and `visible_chart_count`

## Firetrack Commands

```bash
swift run --package-path Firetrack firetrack validate --config firetrack.yml
swift run --package-path Firetrack firetrack ga4 diff --config firetrack.yml
swift run --package-path Firetrack firetrack ga4 sync --config firetrack.yml --dry-run  # preview
swift run --package-path Firetrack firetrack ga4 sync --config firetrack.yml            # apply
swift run --package-path Firetrack firetrack generate --config firetrack.yml --output /tmp/GeneratedAnalytics.swift --access-level public --overwrite
swift run --package-path Firetrack firetrack doctor --config firetrack.yml
```

## GA4 Setup

Firetrack can register:

- event-scoped custom dimensions from `ga4_custom_dimension: true`
- event-scoped custom metrics from `ga4_custom_metric: true`
- key events from `ga4_sync.key_events`
- BigQuery links from `ga4_sync.bigquery_link`

Auth priority:

1. `GOOGLE_OAUTH_ACCESS_TOKEN`
2. IAMCredentials impersonation via `ga4_sync.impersonate_service_account`
3. `gcloud auth print-access-token`

Dry-run first. Apply only after the missing resources look correct.
