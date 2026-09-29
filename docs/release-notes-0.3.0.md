# ChsDet 0.3.0 release notes

## Changes

- Added `DetectCharset` for complete buffers and `TCharsetDetector` for
  streams. Results include status, selected name, decision source, BOM and
  ranked candidates.
- Added allowed charset profiles. An excluded BOM or validated Unicode result
  returns `dsExcludedByProfile` with the indicated encoding retained.
- Added BOM-free UTF-16LE/BE and UTF-32LE/BE checks, strict UTF-8 validation,
  a separate ASCII result, byte-validity checks and context checks for close
  candidates.
- Added Windows-1250 detection in both APIs using byte-pair models and word
  context, including support for allowed charset profiles.
- Fixed detection across input blocks, extended CP932 pairs and legacy
  `DisableCharset` behavior.
- Kept `TnsUniversalDetector` and its public methods. Corrected detection can
  change the name returned by existing clients.

## Limits

BOM-free UTF-8 preference requires one complete non-ASCII character. A single
valid sequence can also occur in legacy text, so short inputs can be
misclassified. A BOM does not validate the rest of the input.

Very sparse Windows-1250 text can be reported as Windows-1252.

## Verification

The required suite and examples pass on Linux and Win64/Wine.
`lazbuild --ws=qt6 chsdet.lpk` succeeds.

See the [API reference](api-0.3.0.md), [migration guide](migration-0.3.0.md)
and [supported charset list](../README.md#supported-charsets).
