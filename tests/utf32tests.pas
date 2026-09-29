unit UTF32Tests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpcunit, testregistry, nsCore, nsUniversalDetector,
  CharsetDetector, CharsetUTF32;

type
  TUTF32Tests = class(TTestCase)
  private
    function ReadFixture(const aName: String): RawByteString;
    procedure CheckSplit(const aBytes, aExpected: RawByteString);
  published
    procedure BOMlessFixturesAtEverySplit;
    procedure SupplementaryAndChunkBoundaries;
    procedure InvalidScalarAndIncompleteTail;
    procedure ShortAndBinarySamples;
    procedure NewAPIAndProfile;
  end;

function TUTF32Tests.ReadFixture(const aName: String): RawByteString;
var
  stream: TFileStream;
  path: String;
begin
  path := ExpandFileName(ExtractFileDir(ParamStr(0)) +
    '/../fixtures/encodings/' + aName);
  Result := '';
  stream := TFileStream.Create(path, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, stream.Size);
    if Length(Result) > 0 then
      stream.ReadBuffer(Result[1], Length(Result));
  finally
    stream.Free;
  end;
end;

procedure TUTF32Tests.CheckSplit(const aBytes, aExpected: RawByteString);
var
  detector: TnsUniversalDetector;
  cut, i: Integer;
begin
  for cut := 0 to Length(aBytes) do
    begin
      detector := TnsUniversalDetector.Create;
      try
        detector.HandleData(PAnsiChar(aBytes), cut);
        detector.HandleData(nil, 0);
        detector.HandleData(PAnsiChar(aBytes) + cut, Length(aBytes) - cut);
        detector.DataEnd;
        AssertEquals('split ' + IntToStr(cut), String(aExpected),
          String(detector.GetDetectedCharsetInfo.Name));
        AssertEquals(Ord(BOM_Not_Found), Ord(detector.BOMDetected));
      finally
        detector.Free;
      end;
    end;
  detector := TnsUniversalDetector.Create;
  try
    for i := 1 to Length(aBytes) do
      detector.HandleData(@aBytes[i], 1);
    detector.DataEnd;
    AssertEquals('bytewise', String(aExpected),
      String(detector.GetDetectedCharsetInfo.Name));
  finally
    detector.Free;
  end;
end;

procedure TUTF32Tests.BOMlessFixturesAtEverySplit;
const
  Orders: array[0..1] of String = ('le', 'be');
  Endings: array[0..1] of String = ('lf', 'crlf');
var
  order, ending: Integer;
  bytes: RawByteString;
begin
  for order := Low(Orders) to High(Orders) do
    for ending := Low(Endings) to High(Endings) do
      begin
        bytes := ReadFixture('utf-32' + Orders[order] + '-' +
          Endings[ending] + '.txt');
        CheckSplit(bytes, 'UTF-32' + UpperCase(Orders[order]));
      end;
end;

procedure TUTF32Tests.SupplementaryAndChunkBoundaries;
var
  bytes: RawByteString;
begin
  bytes := 'H'#0#0#0'i'#0#0#0' '#0#0#0 + #$00#$F6#$01#0 +
    't'#0#0#0'e'#0#0#0'x'#0#0#0't'#0#0#0;
  CheckSplit(bytes, 'UTF-32LE');
  bytes := #0#0#0'H'#0#0#0'i'#0#0#0' ' + #0#$01#$F6#$00 +
    #0#0#0't'#0#0#0'e'#0#0#0'x'#0#0#0't';
  CheckSplit(bytes, 'UTF-32BE');
end;

procedure TUTF32Tests.InvalidScalarAndIncompleteTail;
var
  prober: TCharsetUTF32Prober;
  bytes: RawByteString;
begin
  prober := TCharsetUTF32Prober.Create;
  try
    bytes := 'H'#0#0#0'e'#0#0#0'l'#0#0#0'l'#0#0#0'o'#0#0#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals(Ord(UTF32_LE_CHARSET), Ord(prober.Detect));
    prober.Feed(PAnsiChar(#0), 1);
    AssertEquals('unfinished quartet', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    bytes := bytes + #0#$D8#0#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals('surrogate', Ord(UNKNOWN_CHARSET), Ord(prober.Detect));

    prober.Reset;
    bytes := 'H'#0#0#0'e'#0#0#0'l'#0#0#0'l'#0#0#0 + #0#0#$11#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals('out of Unicode range', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    bytes := StringOfChar('A', 1025);
    bytes := StringReplace(bytes, 'A', 'A'#0#0#0, [rfReplaceAll]);
    prober.Feed(PAnsiChar(bytes), 4096);
    prober.Feed(PAnsiChar(bytes) + 4096, Length(bytes) - 4096);
    AssertEquals('invalid scalar after 4096 bytes', Ord(UTF32_LE_CHARSET),
      Ord(prober.Detect));
    prober.Feed(PAnsiChar(#0#0#$11#0), 4);
    AssertEquals('invalid scalar beyond sample', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));
  finally
    prober.Free;
  end;
end;

procedure TUTF32Tests.ShortAndBinarySamples;
var
  prober: TCharsetUTF32Prober;
  bytes: RawByteString;
begin
  prober := TCharsetUTF32Prober.Create;
  try
    bytes := 'A'#0#0#0'B'#0#0#0'C'#0#0#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals('three code points', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    bytes := #0#0#0#0#1#0#0#0#2#0#0#0#3#0#0#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals('binary controls', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    bytes := 'A'#0#0#0'B'#0#0#0'C'#0#0#0'D'#0#0#0;
    prober.Feed(PAnsiChar(bytes), Length(bytes));
    AssertEquals(Ord(UTF32_LE_CHARSET), Ord(prober.Detect));
    prober.Reset;
    AssertEquals('reset', Ord(UNKNOWN_CHARSET), Ord(prober.Detect));
  finally
    prober.Free;
  end;
end;

procedure TUTF32Tests.NewAPIAndProfile;
var
  detector: TCharsetDetector;
  detected: TCharsetDetectionResult;
  bytes: RawByteString;
begin
  bytes := ReadFixture('utf-32be-lf.txt');
  detected := DetectCharset(bytes);
  AssertEquals(Ord(dsDetected), Ord(detected.Status));
  AssertEquals('UTF-32BE', detected.Charset);
  AssertEquals(12001, detected.CodePage);
  AssertEquals(Ord(csUTF32Structure), Ord(detected.Source));
  AssertEquals(Ord(BOM_Not_Found), Ord(detected.BOM));
  AssertFalse(detected.HasConfidence);

  detected := DetectCharset(bytes + #0);
  AssertTrue('incomplete final quartet must not identify UTF-32',
    detected.Source <> csUTF32Structure);

  detector := TCharsetDetector.Create;
  try
    detector.SetAllowedCharsets(['UTF-8']);
    detector.Feed(Pointer(bytes), Length(bytes));
    detected := detector.Finish;
    AssertEquals(Ord(dsExcludedByProfile), Ord(detected.Status));
    AssertEquals('UTF-32BE', detected.Charset);
    AssertEquals(Ord(csUTF32Structure), Ord(detected.Source));
  finally
    detector.Free;
  end;
end;

initialization
  RegisterTest(TUTF32Tests);

end.
