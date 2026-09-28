# ChsDet 0.3.0 API

`CharsetDetector` examines raw bytes and reports a likely encoding. It does
not decode text or remove a BOM. The caller owns input streams and buffers.

## Entry points

```pascal
function DetectCharset(const Data: RawByteString): TCharsetDetectionResult;
```

`DetectCharset` analyzes a complete buffer with the full charset set. For
streaming input, use `TCharsetDetector`:

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

`Feed` accepts `nil, 0`. A negative count or nil pointer with a positive count
raises `EArgumentException`. `Finish` is repeatable and returns an independent
candidate array. `Feed` after `Finish` raises `EInvalidOp`; call `Reset` to
start another analysis. Results are independent of caller block boundaries.

## Result

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
```

| Status | Meaning |
|---|---|
| `dsDetected` | The detector selected an encoding. |
| `dsAmbiguous` | Several encodings remain plausible; `Charset` is a guess. |
| `dsInsufficientData` | Too little evidence, including empty input; a guess may be present. |
| `dsUnknown` | No supported choice; a weak guess may be present. |
| `dsExcludedByProfile` | A BOM, ASCII or validated Unicode choice is outside the profile. The indicated name and BOM remain in the result; `Candidates` is empty. |

`Charset`, `CodePage`, `Confidence` and `Source` describe the selected
candidate even when `Status` is not `dsDetected`. If no guess exists,
`Charset` is empty, `CodePage` is `0` and `HasConfidence` is false. ASCII also
uses code page `0`; inspect `Status` and `Charset`.

`Candidates` contains distinct public encodings, sorted by descending model
score and then name. `csConfusionResolution` may select the second candidate
without changing that order. `Language` names the contributing model; it is
not a language detection result.

`Confidence` is a model score from 0 to 1, not a probability. Check
`HasConfidence`; BOM, ASCII and validated Unicode results have no score.
Scores are not normalized. Models for the same encoding merge using their
maximum score. Profiles do not increase scores.

`BOMSize` is the detected BOM length; `BytesSeen` is the number of accepted
input bytes. `Finish` sets `IsFinal = True`. Empty input returns
`dsInsufficientData` with `BytesSeen = 0` and no guess.

## Selection rules

1. A BOM takes priority. It identifies an intended encoding but does not
   validate the remaining bytes.
2. Without a BOM, UTF-16LE/BE structure is checked before ASCII. Escape
   sequences are checked before plain ASCII is final. ASCII is reported
   separately from UTF-8.
3. BOM-free UTF-8 must validate across the complete input. Preference over
   legacy encodings requires at least two complete non-ASCII characters.
4. Statistical candidates with undefined input bytes are excluded for the
   supported single-byte encodings. A score at or below `0.01` creates no
   candidate. A statistical choice requires at least four bytes and a score
   of at least `0.20`.
5. A score gap of `0.05` or less produces `dsAmbiguous` unless context around
   distinguishing bytes resolves the pair. Shared ISO-8859-8/Windows-1255
   bytes can remain ambiguous.

## Profiles

```pascal
Detector.SetAllowedCharsets(['ASCII', 'UTF-8', 'UTF-16LE',
  'UTF-16BE', 'windows-1251']);
```

Names match public charset names case insensitively. Unknown names raise
`EArgumentException`; duplicates have no effect. An empty list allows no
charset. `ClearProfile` restores the full set.

Set or clear the profile before the first nonempty `Feed` or after `Reset`.
Changing it after input or `Finish` raises `EInvalidOp`. `Reset` preserves the
profile. An excluded BOM, ASCII or validated Unicode choice returns
`dsExcludedByProfile` without a fallback statistical guess.

## Existing API

`TnsUniversalDetector` in `nsUniversalDetector` remains available. Its result
contains one charset name and code page, without status, confidence or
candidates. See the [migration guide](migration-0.3.0.md) and
[compiled examples](../examples/README.md).
