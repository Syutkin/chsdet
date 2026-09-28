# Migration from ChsDet 0.2.x to 0.3.0

The 0.3.0 API is implemented in `src/CharsetDetector.pas`. The library still
reports version 0.2.10 until the release version update in stage 8. This guide
describes the intended client migration; it does not require existing clients
to migrate when they update the library.

## Start with working clients

The complete, standalone FPC programs are
[`examples/legacy_detect.pas`](../examples/legacy_detect.pas) and
[`examples/file_detect.pas`](../examples/file_detect.pas). Both read the same
file in 4096-byte blocks and own their `TFileStream` and detector. Build them
and check their behavior on Linux with FPC 3.2.2:

```sh
./examples/run-examples.sh
./examples/.build/legacy_detect tests/fixtures/encodings/windows-1251-long-lf.txt
./examples/.build/file_detect tests/fixtures/encodings/windows-1251-long-lf.txt
```

Both print `Charset: windows-1251` for this file. The new client also prints
`Status: dsDetected`, `Source: csStatistics`, a score and ranked candidates.
It runs a second pass after `Reset`; both passes should agree. The runners
compile and execute both clients with this shared fixture, check the result
and exit code, and test the disabled-code-page behavior of the old client.

On native Windows, run `examples\run-examples.cmd` from `cmd.exe`, then
`examples\.build\legacy_detect.exe` or `file_detect.exe` with the same fixture
path. On Linux with the FPC Win64 cross toolchain and Wine, set
`FPC_WIN64_ROOT` and run `./examples/run-examples-win64.sh`. No Entime or LCL
dependency is needed.

## Replace the calls in order

| 0.2.x client | New client | Behavior to preserve or reconsider |
|---|---|---|
| `uses nsCore, nsUniversalDetector` | `uses CharsetDetector` (and `nsCore` if inspecting `eBOMKind`) | The old units remain available. |
| `TnsUniversalDetector.Create`, `Reset` | `TCharsetDetector.Create` | Both objects belong to the caller and must be freed. The new constructor starts a fresh analysis; `Reset` is for reuse. |
| `DisableCharset(CodePage)` before input | `SetAllowedCharsets(['UTF-8', 'UTF-16LE', 'UTF-16BE', 'windows-1251'])` before input | The old method excludes a numeric code page; the new profile is an explicit allow list of public names. Choose that list from application requirements; a single exclusion is not equivalent to a small allow list. |
| `HandleData(PAnsiChar(Buffer), Count)` | `Feed(@Buffer[0], Count)` | Pass raw bytes and their actual count, including every block. `Feed` buffers at most a small block internally and does not own the caller's buffer. |
| `if not Done then DataEnd` | `Result := Finish` | `Finish` finalizes incomplete sequences and returns a final result. Call it at EOF even for empty input. Repeated `Finish` is stable; `Feed` after it raises `EInvalidOp` until `Reset`. |
| `GetDetectedCharsetInfo` | Inspect `Result.Status`, then `Charset`, `CodePage`, `Source`, `BOM`, `Confidence`, `Candidates` | The old record has one name and code page. The new record expresses uncertainty and the reason for a decision. |

The relevant streaming loops in the two compiled clients are:

```pascal
{ Before: examples/legacy_detect.pas }
detector := TnsUniversalDetector.Create;
try
  detector.Reset;
  repeat
    count := stream.Read(buffer, SizeOf(buffer));
    if count > 0 then
      detector.HandleData(@buffer[0], count);
  until count = 0;
  if not detector.Done then
    detector.DataEnd;
  info := detector.GetDetectedCharsetInfo;
finally
  detector.Free;
end;
```

```pascal
{ After: examples/file_detect.pas }
detector := TCharsetDetector.Create;
try
  detector.SetAllowedCharsets(['UTF-8', 'UTF-16LE', 'UTF-16BE',
    'windows-1251']);
  repeat
    count := stream.Read(buffer, SizeOf(buffer));
    if count > 0 then
      detector.Feed(@buffer[0], count);
  until count = 0;
  detection := detector.Finish;
finally
  detector.Free;
end;
```

The excerpts show the calls; the linked programs contain the complete
compilable declarations, file opening, exception handling and output. The
new one rewinds the stream, calls `Reset` and reads it again. `Reset` keeps
the allowed list. `ClearProfile` restores full mode; change the profile only
before the first nonempty `Feed`, or after `Reset`. An unknown charset name
raises `EArgumentException`. An empty allow list excludes every charset.
`DetectCharset(Data: RawByteString)` is the simpler one-shot form and always
uses full mode; see [`examples/text_detect.pas`](../examples/text_detect.pas).

The stream and detector have separate owners. Neither `HandleData` nor `Feed`
retains the input pointer after the call. Keep `try/finally` around both
objects. `TCharsetDetectionResult` is a value record; its candidate array is
copied when `Finish` returns, so it remains usable after freeing the detector.

## Interpret the result, not just the name

| New status | Caller action | Relation to the old API |
|---|---|---|
| `dsDetected` | Use `Charset`/`CodePage` as the detector's choice, then decode and validate the content separately. | The old API returns one name but provides no matching reliability status. |
| `dsAmbiguous` | Present candidates or use trusted external metadata. | The old API may return one of the names, for example on shared ISO-8859-8/Windows-1255 bytes. It cannot express ambiguity. |
| `dsInsufficientData` | Obtain more bytes or external context. A leading statistical guess may still be present. | The old API can return a name such as ASCII or a statistical guess, or `Unknown`. |
| `dsUnknown` | Do not assume UTF-8; ask for context or retain raw bytes. A weak guess may be present. | The old API may return `Unknown` or a name because it uses different decision rules. |
| `dsExcludedByProfile` | Reject the input or revise the allowed list. Preserve the reported BOM or Unicode indication for diagnostics. | There is no equivalent status. In particular, old `DisableCharset` does not override a BOM. |

There is **no lossless status-to-name mapping** from the new result back to
`GetDetectedCharsetInfo`: the two APIs make their own final choices. If an
application must retain the exact old result, keep using the old API. Do not
silently treat a non-`dsDetected` leading `Charset` as a confirmed choice.

The preserved `TnsUniversalDetector` surface includes `Reset`, `HandleData`,
`DataEnd`, `GetDetectedCharsetInfo`, `DisableCharset`, `GetKnownCharset`,
`GetAbout`, and the `Done` and `BOMDetected` properties. `HandleData` still
returns `nsResult` (`NS_OK` on ordinary input); it can set `Done` before EOF
for a BOM or a decisive escape sequence, after which later `HandleData` calls
have no effect. `DataEnd` finalizes a nonempty undecided stream; call it when
`Done` is false. `GetDetectedCharsetInfo` still returns `rCharsetInfo` with a
name, code page and language, without candidates or a confidence/status
field. `GetAbout` continues to report the old version until stage 8 updates
the package version.

`Source` identifies the basis of a result: `csBOM`, `csASCII`,
`csUTF8Validation`, `csUTF16Structure`, `csStatistics` or
`csConfusionResolution` (or `csNone`). `BOM` and `BOMSize` remain available
when a BOM conflicts with a profile; the result is `dsExcludedByProfile` and
contains no statistical candidates. A BOM is evidence of the intended
encoding, not proof that every subsequent byte is valid for a decoder.

ASCII is a separate result, although ASCII bytes are also valid UTF-8. For
BOM-free UTF-8 the detector validates the whole input and requires at least
two complete non-ASCII characters before preferring UTF-8 over legacy
encodings. A single non-ASCII character can remain unresolved. BOM-free
UTF-16LE/BE can be selected from structure; very short or binary input can
remain unknown. Escape sequences such as HZ are checked before treating the
whole input as plain ASCII.

`Confidence` is a model score, **not a calibrated probability**. Check
`HasConfidence` before displaying it: BOM, ASCII and validated Unicode have
no invented score. Candidate scores need not sum to 1. Language models for
the same public encoding merge into one candidate using their maximum score.
The candidates stay sorted by model score; a context decision can choose the
second candidate, indicated by `Source = csConfusionResolution`. A profile
removes disallowed models but does not raise the remaining scores.

## Intentional behavior changes since 0.2.x

Updating the library without migrating client code can change detected names
because the shared core has been fixed:

- BOM prefixes are resolved across input blocks and at EOF; UTF-8/UTF-16/UTF-32
  BOMs take priority over statistical guesses.
- ASCII, strict whole-stream UTF-8 and BOM-free UTF-16LE/BE are handled
  explicitly. The UTF-8 preference requires two multibyte characters.
- HZ and ISO-2022 escape handling works across block boundaries; an HZ
  sequence is no longer lost when the first block begins with `~`.
- Single-byte candidates with undefined input bytes are excluded, including
  distinguishing ISO-8859-8 and Windows-1255 bytes. Shared Hebrew bytes
  remain genuinely ambiguous in the new API.
- Greek Windows-1253/ISO-8859-7 and Cyrillic Windows-1251/Mac Cyrillic
  comparisons use distinguishing bytes and completed model scores. The
  Bulgarian Windows-1251 model participates in the old API's decision.
- Windows-1255 combining marks, extended CP932 pairs and filter state across
  input blocks have fixes. Supported corpus files now give the same result
  across tested block sizes.
- Legacy `DisableCharset` now excludes every language model of a code page
  and can disable one escape encoding without disabling the others. Call it
  before passing input. It does not provide a new status for a conflict.

These changes can improve a previous wrong answer or change one uncertain
guess to another. They do not make indistinguishable bytes uniquely
identifiable. Review application expectations against its own data, especially
where it formerly interpreted every non-`Unknown` name as certain.

## Build paths and compatibility

Existing Lazarus users can continue to install `chsdet.lpk` and use
`nsUniversalDetector` and `nsCore`. Those unit names and the package path have
not moved. New clients add `CharsetDetector` from the same package; standalone
FPC builds include `src/` and `src/sbseq/` in the unit search path, as the
example scripts do. No new runtime dependency is required.

The [0.3.0 API contract](api-0.3.0.md) documents the result fields and
selection rules in more detail.
