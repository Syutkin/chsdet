# ChsDet

## Summary

ChsDet is a standalone Free Pascal/Lazarus component that estimates the
character encoding of raw text bytes. Applications can use its result to
choose a decoder for multilingual text. ChsDet reports an encoding name and
status; it does not convert the input.

## State

Version 0.3.0.
Copyright (C) 2026 Andrey Syutkin
The current source and tests are in
[this repository](https://github.com/Syutkin/chsdet).
The legacy `TnsUniversalDetector` API remains available alongside the new result and
streaming API.

## Original

Based on:

- Mozilla's i18n component,
  [universalchardet](https://dxr.mozilla.org/mozilla/source/extensions/universalchardet/).
- The [Double Commander component](https://github.com/doublecmd/doublecmd/tree/master/components/chsdet).
  Copyright (C) 2011–2019 Alexander Koblov.
- The [original Charset Detector](http://chsdet.sourceforge.net).
  Copyright (C) 2006–2013 Nikolaj Yakowlew.

## Requirements

The detector needs no external components or LCL runtime. The Lazarus
package depends only on FCL. Build and test instructions below use FPC 3.2.2.

## Use

For a complete `RawByteString`:

```pascal
Detection := DetectCharset(Data);
```

For a stream:

```pascal
Detector := TCharsetDetector.Create;
try
  Detector.Feed(Buffer, Count); // repeat for each block
  Detection := Detector.Finish;
finally
  Detector.Free;
end;
```

Both entry points are in `CharsetDetector.pas`. Check `Detection.Status` before
using `Detection.Charset`. `Confidence` is a model score, not a probability;
check `HasConfidence` before using it. `TnsUniversalDetector` remains available
for existing clients.

See the [API reference](docs/api-0.3.0.md), [migration guide](docs/migration-0.3.0.md)
and [examples](examples/README.md).

## Supported charsets

The names and code pages below are defined in `src/nsCore.pas`. `Unknown` has
code page `-1` and is not a supported encoding.

| Code page | Public name | Detection |
|---:|---|---|
| 0 | ASCII | ASCII-only input |
| 855 | IBM855 | Statistical |
| 866 | IBM866 | Statistical |
| 932 | Shift_JIS | Statistical |
| 950 | Big5 | Statistical |
| 1200 | UTF-16LE | BOM or structure |
| 1201 | UTF-16BE | BOM or structure |
| 1251 | windows-1251 | Statistical |
| 1252 | windows-1252 | Statistical |
| 1253 | windows-1253 | Statistical |
| 1255 | windows-1255 | Statistical |
| 10007 | x-mac-cyrillic | Statistical |
| 12000 | UTF-32LE | BOM or structure |
| 12001 | UTF-32BE | BOM or structure |
| 20866 | KOI8-R | Statistical |
| 28595 | ISO-8859-5 | Statistical |
| 28597 | ISO-8859-7 | Statistical |
| 28598 | ISO-8859-8 | Statistical |
| 50222 | ISO-2022-JP | Escape sequence |
| 50225 | ISO-2022-KR | Escape sequence |
| 50227 | ISO-2022-CN | Escape sequence |
| 51932 | EUC-JP | Statistical |
| 51936 | x-euc-tw | Statistical |
| 51949 | EUC-KR | Statistical |
| 52936 | HZ-GB-2312 | Escape sequence |
| 54936 | GB18030 | Statistical |
| 65001 | UTF-8 | BOM or validation |

## Build and test

From the repository root with FPC 3.2.2:

```sh
./tests/run-tests.sh --format=plain --sparse
lazbuild --ws=qt6 chsdet.lpk
```

The test runner also builds and checks the examples. On Windows use
`tests\run-tests.cmd --format=plain --sparse`. See
[test instructions](tests/README.md) for fixture audits and Win64
cross-builds.

## License

ChsDet is distributed under the GNU Lesser General Public License; see
[LICENCE](LICENCE). The Unicode data notice is in
[UNICODE-LICENSE](UNICODE-LICENSE). Changes in this version are listed in the
[changelog](CHANGELOG.md) and [release notes](docs/release-notes-0.3.0.md).
