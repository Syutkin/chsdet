# Migrating from ChsDet 0.2.x to 0.3.0

`TnsUniversalDetector` remains available. Use `CharsetDetector` when the
application needs status, candidates or an allowed charset list.

## API mapping

| 0.2.x | 0.3.0 | Change |
|---|---|---|
| `uses nsCore, nsUniversalDetector` | `uses CharsetDetector` | Add `nsCore` when using `eBOMKind`. |
| `TnsUniversalDetector.Create` | `TCharsetDetector.Create` | The caller frees either object. |
| `HandleData(Buffer, Count)` | `Feed(Buffer, Count)` | Feed every input block. The pointer is not retained. |
| `if not Done then DataEnd` | `Result := Finish` | Always call `Finish` at EOF. |
| `GetDetectedCharsetInfo` | Inspect `Result.Status` and `Result.Charset` | The new result includes source, confidence and candidates. |
| `DisableCharset(CodePage)` | `SetAllowedCharsets(Names)` | The old method excludes a code page; the new method permits listed names. Define the list from application requirements. |

A streaming example:

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

For a complete `RawByteString`, call `DetectCharset(Data)`. It uses the full
charset set. `Reset` allows reuse of a streaming detector and preserves its
profile; `ClearProfile` restores the full set. Set a profile before feeding
input. The caller owns the stream and detector.

## Using the result

| Status | Caller action |
|---|---|
| `dsDetected` | Decode with the selected encoding and validate the content. |
| `dsAmbiguous` | Inspect candidates or use trusted metadata. |
| `dsInsufficientData` | Obtain more bytes or external context. |
| `dsUnknown` | Keep the bytes until an encoding is known. |
| `dsExcludedByProfile` | Reject the input or revise the profile; the indicated BOM or Unicode name remains available. |

`Charset` may contain a leading guess for `dsAmbiguous`,
`dsInsufficientData` or `dsUnknown`. It is not a confirmed encoding.
`Confidence` is a model score, not a probability; check `HasConfidence`.
The new status cannot be converted losslessly to the old API's single name.
Keep using `TnsUniversalDetector` if that exact result is required.

## Detection changes

The shared core can return a different name to unchanged 0.2.x clients:

- BOM, HZ and ISO-2022 sequences are recognized across input blocks.
- ASCII, strict whole-input UTF-8 and BOM-free UTF-16LE/BE have explicit
  checks. BOM-free UTF-8 preference requires two complete non-ASCII
  characters.
- Single-byte candidates with undefined input bytes are excluded.
- Greek, Cyrillic and Hebrew comparisons use distinguishing bytes.
- Windows-1255 combining marks, extended CP932 pairs and model state across
  input blocks have fixes.
- `DisableCharset` excludes every model of the specified code page without
  disabling unrelated escape models.

The old API still has no ambiguity status. Its `Done` property can become true
before EOF for a BOM or decisive escape sequence. See the
[API reference](api-0.3.0.md) for result and profile rules and the
[standalone examples](../examples/README.md) for compiled clients.
