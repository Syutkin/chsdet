# ChsDet 0.3.0 API

Status: implemented API contract. The package still reports version 0.2.10
until the release version update. The result and streaming API, charset
profiles, and standalone examples are implemented. This document describes
current behavior.

## Scope

ChsDet examines raw bytes and suggests an encoding. It does not decode text,
strip a BOM, normalize strings, or choose an encoding from application
settings. The caller owns those decisions and any input stream. The library
has no LCL or external runtime dependency.

The new public unit is `CharsetDetector`. Existing clients can continue to
use `nsUniversalDetector` and `nsCore`; see the
[migration guide](migration-0.3.0.md).

## Public types and entry points

```pascal
type
  TCharsetDetectionStatus = (
    dsDetected, dsAmbiguous, dsInsufficientData, dsUnknown,
    dsExcludedByProfile
  );
  TCharsetDetectionSource = (
    csNone, csBOM, csASCII, csUTF8Validation, csUTF16Structure,
    csStatistics, csConfusionResolution
  );
  TCharsetCandidate = record
    Charset: string;
    CodePage: Integer;
    Confidence: Double;
    HasConfidence: Boolean;
    Source: TCharsetDetectionSource;
    Language: string;
  end;
  TCharsetCandidates = array of TCharsetCandidate;
  TCharsetDetectionResult = record
    Status: TCharsetDetectionStatus;
    Charset: string;
    CodePage: Integer;
    Confidence: Double;
    HasConfidence: Boolean;
    Source: TCharsetDetectionSource;
    BOM: eBOMKind;
    BOMSize: Integer;
    Candidates: TCharsetCandidates;
    BytesSeen: QWord;
    IsFinal: Boolean;
  end;

  TCharsetDetector = class
  public
    constructor Create;
    destructor Destroy; override;
    procedure Feed(Buffer: Pointer; Count: SizeInt);
    function Finish: TCharsetDetectionResult;
    procedure Reset;
    procedure SetAllowedCharsets(const aNames: array of string);
    procedure ClearProfile;
  end;

function DetectCharset(const Data: RawByteString): TCharsetDetectionResult;
```

The declaration above omits private members. Free a `TCharsetDetector` that
you create. `DetectCharset` creates and
frees one internally, uses the full charset set, and returns the same final
result as `Feed` followed by `Finish` on the same bytes.

## Results and decisions

| Status | Meaning |
|---|---|
| `dsDetected` | A BOM, Unicode check, ASCII check, escape detector, or sufficiently supported statistical candidate produced a choice. Detection does not validate decoding of the whole text. |
| `dsAmbiguous` | Multiple encodings remain plausible. `Charset` is a guess, not a confirmed encoding. |
| `dsInsufficientData` | Too little evidence for a statistical choice, including empty input. A short input may still have a leading guess. |
| `dsUnknown` | No candidate reached the choice threshold, or no viable candidate exists. A weak guess may still be present. |
| `dsExcludedByProfile` | A BOM, ASCII, or validated Unicode decision points to an encoding outside the allowed list. The indicated encoding is retained for diagnostics, without a candidate. |

For a statistical result, `Candidates` contains unique public encodings.
`Charset`, `CodePage`, `Confidence`, and `Source` describe the selected
candidate even when `Status` is `dsAmbiguous`, `dsInsufficientData`, or
`dsUnknown`. Usually this is the highest scoring candidate. A
`csConfusionResolution` decision can select the second candidate while
preserving the original score order. If there is no guess, `Charset` is empty,
`CodePage` is 0, and `HasConfidence` is false. Code page 0 alone is not an
unknown marker: ASCII also uses it.

For a BOM, ASCII, or validated Unicode choice, the result contains one
candidate with `HasConfidence = False`. A profile conflict returns the
indicated `Charset`, `CodePage`, and `Source`, plus `BOM` and
`BOMSize` when present; it returns no candidates and no statistical score.
An empty input has `dsInsufficientData`, no guess, and `BytesSeen = 0`.

`Source` records the basis of a decision or guess:
`csBOM`, `csASCII`, `csUTF8Validation`, `csUTF16Structure`,
`csStatistics`, or `csConfusionResolution`. `csNone` means no basis was
available. `Language` identifies the contributing model and is only a
diagnostic hint, not a language detection result.

`Confidence` is a model score in the range 0..1, **not a calibrated
probability**. Check `HasConfidence` before using it. Candidate scores
are not normalized and need not sum to 1. Models for the same public encoding
(such as Russian and Bulgarian Windows-1251) merge using their maximum score,
not their sum. A BOM, ASCII, or Unicode validation result does not receive an
invented score. Restricting the candidate set does not raise the remaining
model scores.

## Selection rules

- A BOM has priority. It indicates an intended encoding, but does not prove
  that all following bytes decode correctly.
- Without a BOM, UTF-16LE/BE structure is checked before returning ASCII.
  ASCII-only bytes are a distinct `ASCII` result even though they are valid
  UTF-8. Escape sequences such as HZ are checked before plain ASCII is final.
- BOM-free UTF-8 must validate across the whole input. At least two complete
  non-ASCII UTF-8 characters are required before preferring it to a legacy
  encoding. An incomplete final sequence cannot establish UTF-8.
- Statistical candidates with undefined input bytes are removed for the
  supported single-byte encodings. A model score at or below `SURE_NO`
  (0.01) does not create a candidate.
- A statistical choice needs at least four input bytes and a leading score
  of at least 0.20. A gap of 0.05 or less between the top two scores produces
  `dsAmbiguous`, unless distinguishing-byte context resolves the pair.
  These thresholds do not block BOM, ASCII, or structural Unicode decisions.
- Candidates are sorted by descending score and then by public charset name
  for a stable tie order. An exact tie does not establish the original
  encoding.
- ISO-8859-8 and Windows-1255 share many Hebrew-letter bytes. Without a
  distinguishing byte, both can remain candidates and the result can be
  `dsAmbiguous`. A unique original label cannot be recovered from bytes
  that decode identically under both encodings.

## Streaming and lifecycle

```pascal
Detector := TCharsetDetector.Create;
try
  repeat
    Count := Stream.Read(Buffer, SizeOf(Buffer));
    if Count > 0 then
      Detector.Feed(@Buffer[0], Count);
  until Count = 0;
  Detection := Detector.Finish;
finally
  Detector.Free;
end;
```

The caller owns `Stream`, keeps it open during feeding, and frees it
separately. `Feed` does not retain the caller's buffer. It accepts
`Feed(nil, 0)`; a negative count or nil pointer with a positive count raises
`EArgumentException`. Internally the wrapper feeds the shared core in fixed
512-byte blocks. It retains detector state and short unfinished sequences,
not the entire input, and its final result does not depend on caller block
boundaries. `BytesSeen` counts all accepted input bytes.

`Finish` signals EOF, finalizes incomplete sequences, and returns
`IsFinal = True`. Repeating `Finish` returns the same values and an
independent candidate array. `Feed` after `Finish` raises `EInvalidOp`.
`Reset` starts a new analysis and preserves the selected profile. The old
API's `Done` property is not a substitute for feeding the entire input to
the new API.

## Explicit charset profiles

```pascal
Detector := TCharsetDetector.Create;
try
  Detector.SetAllowedCharsets(['ASCII', 'UTF-8', 'UTF-16LE', 'UTF-16BE',
    'windows-1251']);
  Detector.Feed(@Buffer[0], Count);
  Detection := Detector.Finish;
finally
  Detector.Free;
end;
```

Names are the returned public charset names, matched without case
sensitivity. Duplicate names have no additional effect. Every language
model for an allowed public encoding is enabled; individual escape
encodings can be selected independently. Unknown names raise
`EArgumentException`. An empty list allows nothing; it does not restore
full mode. Use `ClearProfile` for the default full set.

Set or clear a profile before the first nonempty `Feed`, or after
`Reset`. Changing it after input or `Finish` raises `EInvalidOp`.
`Reset` keeps the profile. If a BOM indicates an excluded encoding, the
result is `dsExcludedByProfile`, with the BOM and indicated name retained.
The detector does not replace that indication with a permitted statistical
guess. The same status applies to excluded ASCII or validated Unicode
choices.

## Compatibility and examples

`TnsUniversalDetector`, `HandleData`, `DataEnd`,
`GetDetectedCharsetInfo`, `Done`, `BOMDetected`, and
`DisableCharset(CodePage)` remain available. The legacy result has one
name and code page, without a confidence or ambiguity status. There is no
exact one-to-one mapping from a new status to the old name: both APIs make
their own decisions. See the [migration guide](migration-0.3.0.md) for
behavior changes and ownership rules.

Complete, compiled examples are in [examples/](../examples/README.md):
`text_detect` uses `RawByteString` and `DetectCharset`;
`file_detect` streams a file, configures a profile, and reuses the detector
after `Reset`; `legacy_detect` retains the old API.
