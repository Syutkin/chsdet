# Changelog

## 0.3.0 — 2026-09-28

### Added

- `DetectCharset` and streaming `TCharsetDetector` with statuses, decision
  sources, BOM information and ranked candidates.
- Allowed charset profiles and `dsExcludedByProfile` for excluded Unicode
  decisions.
- BOM-free UTF-16LE/BE checks, strict UTF-8 validation, separate ASCII
  results and byte-validity checks.
- Windows-1250 detection in both APIs using byte-pair models and word context,
  with support for allowed charset profiles.
- Standalone examples, API reference and migration guide.

### Fixed

- BOM and escape-sequence detection across input blocks.
- Statistical model state and selection for close Greek, Hebrew and Cyrillic
  candidates.
- Windows-1255 combining marks and extended CP932 byte pairs.
- Legacy `DisableCharset` behavior across language and escape models.

`TnsUniversalDetector` remains available, but corrected detection can change
its result. See the [release notes](docs/release-notes-0.3.0.md) and
[migration guide](docs/migration-0.3.0.md).
