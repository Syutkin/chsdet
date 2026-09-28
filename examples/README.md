# Standalone charset detection examples

These console programs use ChsDet and the FPC standard library. They do not
need Lazarus, LCL or the Entime application. Run the commands from the ChsDet
repository root.

## Build and check

Linux with FPC 3.2.2:

```sh
./examples/run-examples.sh
```

Native Windows with FPC 3.2.2, from `cmd.exe`:

```bat
examples\run-examples.cmd
```

On Linux with the Win64 cross toolchain and Wine:

```sh
FPC_WIN64_ROOT=/path/to/fpc-win64-3.2.2 ./examples/run-examples-win64.sh
```

Each command builds the three programs into `examples/.build/`, runs fixed
samples, checks status and exit code, and ends with `Examples: build and checks
passed` (the cross runner says `Win64 examples: ...`). The ordinary library
test scripts also run these checks after FPCUnit succeeds.

## RawByteString input

```sh
./examples/.build/text_detect utf8
./examples/.build/text_detect ambiguous
./examples/.build/text_detect empty
```

`text_detect` calls `DetectCharset` on an in-memory `RawByteString`. The
other accepted sample names are `ascii`, `short`, and `unknown`. Their expected
statuses are:

| Sample | Status | Meaning |
|---|---|---|
| `empty`, `short` | `dsInsufficientData` | No useful amount of evidence; a short input can still have a leading statistical guess. |
| `ascii`, `utf8` | `dsDetected` | ASCII is distinct from UTF-8; the UTF-8 sample contains two multibyte characters. |
| `ambiguous` | `dsAmbiguous` | The bytes fit both ISO-8859-8 and Windows-1255. |
| `unknown` | `dsUnknown` | No reliable encoding choice for these control bytes. |

For example, `text_detect utf8` prints `Charset: UTF-8`,
`Source: csUTF8Validation`, `BOM: BOM_Not_Found (0 bytes)` and
`Confidence: n/a`. The `ambiguous` sample prints statistical candidates and
scores. A score is a model measure, not a probability; the leading name in an
ambiguous, insufficient or unknown result is not a confirmed encoding.

## File input and profiles

```sh
./examples/.build/file_detect tests/fixtures/encodings/windows-1251-long-lf.txt \
  UTF-8 UTF-16LE UTF-16BE windows-1251
./examples/.build/file_detect tests/fixtures/encodings/utf-8-ru-bom-lf.txt \
  windows-1251
```

`file_detect` opens a `TFileStream`, reads 4096-byte blocks into a fixed
buffer and calls `Feed` for each block, then `Finish`. Charset names after the
path form an explicit allowed list; omitting them uses the full library mode.
The first command reports `dsDetected` and `windows-1251` twice. The second
reports `dsExcludedByProfile`, `UTF-8` and `BOM_UTF8` twice. A conflicting BOM
is never replaced with a permitted statistical guess.

The example then calls `Reset`, rewinds the stream and runs a second pass to
show that the profile survives `Reset`. `file_detect` owns and frees both the
stream and detector. `Feed` reads from the caller's buffer but does not own
it. The stream and detector are freed with `try/finally` even when reading or
analysis fails. Missing files, unknown profile names and invalid arguments
exit with code 2.

## Preserved API

```sh
./examples/.build/legacy_detect tests/fixtures/encodings/ascii-lf.txt
```

This program uses `TnsUniversalDetector.HandleData`, `DataEnd` and
`GetDetectedCharsetInfo`; the sample prints `Charset: ASCII` and `Code page:
0`. An optional second argument calls `DisableCharset` with a numeric code
page before reading, for example `legacy_detect file.txt 1251`. It reads the
file in blocks and frees the stream and detector. Existing
clients can continue using this API while new clients use `TCharsetDetector`.

These examples detect an encoding name. They do not decode input bytes; the
application must choose and run a matching decoder after examining the status.
