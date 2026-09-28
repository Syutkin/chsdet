# ChsDet examples

The standalone FPC programs are `text_detect`, `file_detect` and
`legacy_detect`. Run commands from the ChsDet repository root.

## Build and check

```sh
./examples/run-examples.sh
```

On Windows, run `examples\run-examples.cmd`. For a Linux Win64 cross-build,
set `FPC_WIN64_ROOT` and run `./examples/run-examples-win64.sh`. The runners
compile into `examples/.build/` and check output and exit codes. The main
test runners include these checks.

## Complete buffer

```sh
./examples/.build/text_detect utf8
./examples/.build/text_detect ambiguous
```

`text_detect` calls `DetectCharset` on a `RawByteString`. Accepted samples are
`empty`, `short`, `ascii`, `utf8`, `ambiguous` and `unknown`:

| Sample | Status |
|---|---|
| `empty`, `short` | `dsInsufficientData` |
| `ascii`, `utf8` | `dsDetected` |
| `ambiguous` | `dsAmbiguous` |
| `unknown` | `dsUnknown` |

## Stream and profile

```sh
./examples/.build/file_detect tests/fixtures/encodings/windows-1251-long-lf.txt \
  UTF-8 UTF-16LE UTF-16BE windows-1251
./examples/.build/file_detect tests/fixtures/encodings/utf-8-ru-bom-lf.txt \
  windows-1251
```

`file_detect` streams a file through `Feed` and `Finish`. Names after the path
form an allowed list; omitting them uses the full set. The first command
returns `dsDetected`/`windows-1251`; the second returns
`dsExcludedByProfile`/`UTF-8`. It then calls `Reset`, rewinds the stream and
repeats detection to check profile preservation. Invalid arguments and file
errors exit with code 2.

## Existing API

```sh
./examples/.build/legacy_detect tests/fixtures/encodings/ascii-lf.txt
./examples/.build/legacy_detect tests/fixtures/encodings/ascii-lf.txt 1251
```

`legacy_detect` uses `TnsUniversalDetector`. The optional number is passed to
`DisableCharset` before input. The ASCII fixture returns `ASCII`, code page
`0`.
