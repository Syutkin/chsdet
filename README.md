# Charset Detector

Standalone FPC examples and commands are in [examples/README.md](examples/README.md).

## Summary

Charset Detector - as the name says - is a stand alone component for automatic charset detection of a given text.

It can be useful for internationalisation support in multilingual applications such as web-script editors or Unicode editors.

Given input buffer will be analysed to guess used encoding. The result can be used as control parameter for charset conversation procedure.

Based on Mozilla's i18n component - https://dxr.mozilla.org/mozilla/source/extensions/universalchardet/.

## State

Version 0.2.10 stable.

Copyright (C) 2011-2019 Alexander Koblov

The latest version can be found at [https://github.com/doublecmd/doublecmd/tree/master/components/chsdet/](https://github.com/doublecmd/doublecmd/tree/master/components/chsdet/).

## Original

Based on

Charset Detector - http://chsdet.sourceforge.net

Copyright (C) 2006-2013 Nikolaj Yakowlew

## Requirements

Charset Detector doesn't need any external components.

## Output

As result you will get guessed charset as MS Windows Code Page id and charset name.

## Unicode detection

`CharsetBOM.DetectCharsetBOM` accepts a complete initial buffer and treats its end as EOF.

For streaming input, `CharsetBOM.ResolveCharsetBOM` needs up to four initial bytes before it can rule out a longer BOM; call it with `aAtEnd=True` when no more bytes will arrive.

Without a BOM, the detector checks UTF-16LE/BE structure, then returns ASCII for ASCII-only text. NUL-containing data is examined as possible UTF-16 rather than returned as ASCII immediately. Escape-encoded text keeps its escape detector result. Strict UTF-8 validation covers every input block, including an incomplete final sequence. At least two complete non-ASCII UTF-8 characters are required to prefer UTF-8 to a legacy encoding. Valid ASCII is returned as ASCII, not UTF-8. Short or structurally ambiguous UTF-16 may remain Unknown.

## Detection API under development

The `CharsetDetector` unit adds two ways to obtain the same final result:

```pascal
Detection := DetectCharset(Data); // Data is RawByteString
```

```pascal
Detector := TCharsetDetector.Create;
try
  Detector.Feed(Buffer, Count); // repeat for each block
  Detection := Detector.Finish;
finally
  Detector.Free;
end;
```

The result includes `Status`, `Charset`, `CodePage`, `Source`, `BOM/BOMSize`, `BytesSeen`, `IsFinal`, and ranked `Candidates`. When a statistical candidate exists, `Charset`, `CodePage`, and `Confidence` contain the leading guess even for `dsAmbiguous`, `dsInsufficientData`, or `dsUnknown`; `Status` indicates whether it is reliable.

An empty input or input with no viable candidate has no charset guess.

Statistical confidence is an algorithm score, not a probability. Candidates with the same charset are merged using the maximum model score. BOM, ASCII, and validated Unicode do not receive an invented statistical confidence.

`Feed(nil, 0)` is allowed. Feed after Finish raises `EInvalidOp`; Reset starts a new analysis. Finish is repeatable.

The streaming class uses fixed 512-byte blocks inside the shared detector, so caller block boundaries do not change the result and the entire input is never stored.

An application can read a `TStream` in blocks and call Feed; the detector does not take ownership of the stream.

## Charset profiles

The default detector considers every supported charset. A profile explicitly
limits the public charset names considered by one `TCharsetDetector` instance:

```pascal
Detector := TCharsetDetector.Create;
try
  Detector.SetAllowedCharsets(['UTF-8', 'UTF-16LE', 'UTF-16BE',
    'windows-1251']);
  Detector.Feed(Buffer, Count); // repeat for every input block
  Detection := Detector.Finish;
finally
  Detector.Free;
end;
```

Names are the public names returned by the detector (case insensitive).
Unknown names raise `EArgumentException`; repeated names have no extra effect.
An empty list is valid and permits no charset. The list applies to every
language model of each allowed charset. It also selects individual escape
charsets without disabling other escape models. The legacy
`TnsUniversalDetector.DisableCharset(CodePage)` remains available.

Set or clear the profile before the first nonempty `Feed`. Changing it after
input or `Finish` raises `EInvalidOp`; call `Reset` first. `Reset` preserves the
profile. `ClearProfile` restores the default full mode. `DetectCharset(Data)`
always uses full mode.

An excluded BOM returns `dsExcludedByProfile`, the actual BOM, its size and
charset name, with no candidates or statistical confidence. Other excluded
Unicode or ASCII decisions use the same status. A profile does not increase
model confidence: scores retain their original meaning. Restricting the
candidate set can remove ambiguity, but a weak score remains weak.

## Licence

Charset Detector is open source project and distributed under GNU LGPL.

See the GNU Lesser General Public License for more details - https://opensource.org/licenses/LGPL-2.1

## Supported charsets

| Code pade | Name | Note |
|---:|---|---|
| 0 | ASCII | Pseudo code page. |
| 855 | IBM855 | |
| 866 | IBM866 | |
| 932 | Shift_JIS | |
| 950 | Big5 | |
| 1200 | UTF-16LE | |
| 1201 | UTF-16BE | |
| 1251 | windows-1251 | |
| 1252 | windows-1252 | |
| 1253 | windows-1253 | |
| 1255 | windows-1255 | |
| 10007 | x-mac-cyrillic | |
| 12000 | X-ISO-10646-UCS-4-2143 | |
| 12000 | UTF-32LE | |
| 12001 | X-ISO-10646-UCS-4-3412 | |
| 12001 | UTF-32BE | |
| 20866 | KOI8-R | |
| 28595 | ISO-8859-5 | |
| 28595 | ISO-8859-5 | |
| 28597 | ISO-8859-7 | |
| 28598 | ISO-8859-8 | |
| 50222 | ISO-2022-JP | |
| 50225 | ISO-2022-KR | |
| 50227 | ISO-2022-CN | |
| 51932 | EUC-JP | |
| 51936 | x-euc-tw | |
| 51949 | EUC-KR | |
| 52936 | HZ-GB-2312 | |
| 54936 | GB18030 | |
| 65001 | UTF-8 | |

## Types

### Return values

```pascal
NS_OK = 0;
NS_ERROR_OUT_OF_MEMORY = $8007000e;
```

### Returned types

```pascal
rCharsetInfo = record
  Name: PAnsiChar;      // Charset GNU canonical name
  CodePage: Integer;    // MS Windows CodePage ID
  Language: PAnsiChar;
end;
```

## Usage sample

Below is a small usage sample in Free Pascal.

```pascal
function DetectEncoding(const S: String): rCharsetInfo;
var
  Detector: TnsUniversalDetector;
begin
  Detector:= TnsUniversalDetector.Create;
  try
    Detector.Reset;
    Detector.HandleData(PAnsiChar(S), Length(S));
    if not Detector.Done then Detector.DataEnd;
    Result:= Detector.GetDetectedCharsetInfo;
  finally
    FreeAndNil(Detector);
  end;
end;
```
