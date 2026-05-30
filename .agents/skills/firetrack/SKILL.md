---
name: firetrack
description: Use when editing the Firetrack Swift package, its CLI, GA4 sync logic, YAML validation, SwiftSyntax generator, tests, or documentation.
---

# Firetrack Skill

Firetrack is a Swift package for deterministic analytics tracking plans. Keep the module boundaries strict.

## Module Boundaries

- `Sources/firetrack`: executable wrapper only. It imports `FiretrackCLI` and calls `FiretrackCommand.main()`.
- `FiretrackCLI`: ArgumentParser declarations only. Command `run()` methods construct request values and call `XXXRunner(...).run(...)`.
- `FiretrackOperations`: runners, output formatting, dependency wiring, and filesystem writes.
- `FiretrackConfiguration`: Yams decoding, schema models, validation, naming conversion, and GA4 desired-state extraction.
- `FiretrackGA4`: GA4 Admin API client, auth token providers, remote state, diff, and apply.
- `FiretrackSwiftGenerator`: SwiftSyntax-backed generated Swift analytics contract.

Never put Yams, URLSession, SwiftSyntax, GA4 endpoint strings, or diff logic in `FiretrackCLI`.

## Workflow

1. Write or update focused tests first.
2. Run `swift test --package-path Firetrack`.
3. Run `swift build --package-path Firetrack`.
4. Validate MyApp YAML with `swift run --package-path Firetrack firetrack validate --config firetrack.yml`.
5. For GA4 work, dry-run before apply:
   - `swift run --package-path Firetrack firetrack ga4 diff --config firetrack.yml`
   - `swift run --package-path Firetrack firetrack ga4 sync --config firetrack.yml --apply`

## Design Rules

- YAML is the source of truth.
- Output must be deterministic.
- GA4 sync creates missing resources only.
- Never delete, archive, or rename remote GA4 resources in v1.
- Generated Swift must parse before being written.
