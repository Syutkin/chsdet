# ChsDet 0.3.0 release notes

## Changes

- Added `DetectCharset` for complete buffers and `TCharsetDetector` for
  streams. Results include status, selected name, decision source, BOM and
  ranked candidates.
- Added allowed charset profiles. An excluded BOM or validated Unicode result
  returns `dsExcludedByProfile` with the indicated encoding retained.
- Added BOM-free UTF-16LE/BE checks, strict UTF-8 validation, a separate ASCII
  result, byte-validity checks and context checks for close candidates.
- Fixed detection across input blocks, extended CP932 pairs and legacy
  `DisableCharset` behavior.
- Kept `TnsUniversalDetector` and its public methods. Corrected detection can
  change the name returned by existing clients.

## Limits

Shared ISO-8859-8/Windows-1255 bytes cannot establish the original label.
The new API reports ambiguity for the four shared-byte fixtures; the old API
selects Windows-1255. BOM-free UTF-8 preference requires two complete
non-ASCII characters. Short inputs and sparse legacy text can remain
uncertain. A BOM does not validate the rest of the input.

## Verification

The required suite passes 205/205 on Linux and Win64/Wine; the examples pass
on both. `lazbuild --ws=qt6 chsdet.lpk` succeeds.

See the [API reference](api-0.3.0.md), [migration guide](migration-0.3.0.md)
and [supported charset list](../README.md#supported-charsets).
