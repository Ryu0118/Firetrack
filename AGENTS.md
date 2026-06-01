# Firetrack

Deterministic Firebase Analytics / GA4 Admin API toolkit. A single YAML file
(`firetrack.yml`) is the source of truth: Firetrack validates it,
syncs missing GA4 custom definitions / key events / BigQuery links, and generates
type-safe Swift event code from it.

## Architecture

Six modules, strict one-directional dependencies. **Keep the boundaries strict.**

```
firetrack (exe) → FiretrackCLI → FiretrackOperations → {Configuration, GA4, SwiftGenerator}
```

- `Sources/firetrack` — executable wrapper only. Bootstraps logging, then calls `FiretrackCommand.main()`.
- `FiretrackCLI` — ArgumentParser declarations only. `run()` methods build a request value and call `XXXRunner(...).run(...)`. Holds `Version.swift` (`firetrack --version`).
- `FiretrackOperations` — runners, output formatting (`logger`), dependency wiring, filesystem writes, logging setup. The `doctor` slot-machine animation is delegated to the external [SlotKit](https://github.com/Ryu0118/SlotKit) package.
- `FiretrackConfiguration` — Yams decoding, schema models, validation, naming conversion, GA4 desired-state extraction.
- `FiretrackGA4` — GA4 Admin API client, auth token providers, remote state, diff, apply.
- `FiretrackSwiftGenerator` — string-based generation of the Swift analytics contract, validated by parsing (SwiftParser) before write.

**Never** put Yams, URLSession, SwiftParser, GA4 endpoint strings, or diff logic in `FiretrackCLI`.

## Development

```bash
make setup      # nest bootstrap (lint tools) + git hooks + mise install
make build      # swift build
make test       # swift test
make format     # swiftformat (apply)
make lint       # swiftlint --strict
make my-swift-lint  # my-swift-linter (AST rules)
make periphery  # unused/redundant-public scan
make docsync    # doc/source sync check
make check      # format-lint + lint + my-swift-lint + test + docsync
```

The toolchain is pinned via `nestfile.yaml` and resolved into `.nest/bin/` by
`scripts/nest.sh`. `gitleaks` comes from `mise`.

## Conventions

- Swift 6.2, macOS 26 only. No Linux support.
- Follow `.swiftlint.yml` strictly — **0 violations**. `--strict` is enforced by hooks and CI.
- `swiftlint:disable` is **banned** (a PreToolUse hook blocks it). Fix the underlying issue.
- **No `print` / `fputs`.** All user-facing output goes through the package `logger` (swift-log).
  Result lines use `logger.info`; failures use `logger.error`. `FiretrackLogHandler` routes
  info/notice → stdout and warning+ → stderr so output stays pipeable.
- `package` access for cross-module internal API; `public` only for the genuine library surface
  (`FiretrackLogHandler`, `FiretrackLogging`). `public` declarations need doc comments (`missing_docs`).
- No file-scope `func` (`no-top-level-function`) — use a type/extension or a namespace `enum`.
- Prefer `URL(filePath:)` / `.path(percentEncoded: false)` over the deprecated path APIs.

## Design Rules

- YAML is the source of truth.
- Output must be deterministic (byte-stable for identical input).
- GA4 sync **creates missing resources only** — never delete, archive, or rename remote GA4 resources.
- Generated Swift must parse (SwiftParser) before it is written.
- Auth resolves from `GOOGLE_OAUTH_ACCESS_TOKEN`, then `gcloud`; configured impersonation always exchanges that base credential through IAMCredentials.

## Hooks & Gates

- **pre-commit**: gitleaks + swiftformat + swiftlint --strict + my-swift-linter + docsync.
- **pre-push**: periphery scan (blocks on redundant public).
- **Claude / Codex** PostToolUse hooks run the same lint on every edit; PreToolUse guards architecture and skill files.

Activate locally with `make hooks` (or `make setup`).

## Testing

Swift Testing (`import Testing`, `@Test`, `#expect`). Test runners and configuration logic
directly; `CLIBoundaryTests` asserts the `FiretrackCLI` module stays free of implementation imports.
