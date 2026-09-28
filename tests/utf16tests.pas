unit UTF16Tests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpcunit, testregistry, nsCore, nsUniversalDetector,
  CharsetUTF16;

type
  TUTF16Tests = class(TTestCase)
  private
    function ReadFixture(const aName: String): RawByteString;
    function Detect(const aData: RawByteString; aSplit: Integer): String;
  published
    procedure BOMlessFixturesAtEverySplit;
    procedure SurrogatesOddLengthAndWeakEvidence;
    procedure LegacyAndBinaryNegativeSamples;
    procedure IndependentTextSamples;
  end;

function TUTF16Tests.ReadFixture(const aName: String): RawByteString;
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

function TUTF16Tests.Detect(const aData: RawByteString; aSplit: Integer): String;
var
  detector: TnsUniversalDetector;
begin
  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(PAnsiChar(aData), aSplit);
    detector.HandleData(nil, 0);
    detector.HandleData(PAnsiChar(aData) + aSplit, Length(aData) - aSplit);
    detector.DataEnd;
    Result := detector.GetDetectedCharsetInfo.Name;
  finally
    detector.Free;
  end;
end;

procedure TUTF16Tests.BOMlessFixturesAtEverySplit;
const
  Languages: array[0..4] of String = ('ru', 'en', 'fr', 'el', 'he');
  ByteOrders: array[0..1] of String = ('le', 'be');
  LineEndings: array[0..1] of String = ('lf', 'crlf');
var
  lang, order, ending, cut, i: Integer;
  fileName, expected: String;
  bytes: RawByteString;
  detector: TnsUniversalDetector;
begin
  for lang := Low(Languages) to High(Languages) do
    for order := Low(ByteOrders) to High(ByteOrders) do
      for ending := Low(LineEndings) to High(LineEndings) do
      begin
        fileName := 'utf-16' + ByteOrders[order] + '-' + Languages[lang] +
          '-' + LineEndings[ending] + '.txt';
        bytes := ReadFixture(fileName);
        expected := 'UTF-16' + UpperCase(ByteOrders[order]);
        for cut := 0 to Length(bytes) do
          AssertEquals(fileName + ' split ' + IntToStr(cut), expected,
            Detect(bytes, cut));

        detector := TnsUniversalDetector.Create;
        try
          for i := 1 to Length(bytes) do
            detector.HandleData(@bytes[i], 1);
          detector.DataEnd;
          AssertEquals(fileName + ' bytewise', expected,
            String(detector.GetDetectedCharsetInfo.Name));
        finally
          detector.Free;
        end;
      end;
end;

procedure TUTF16Tests.SurrogatesOddLengthAndWeakEvidence;
var
  prober: TCharsetUTF16Prober;
  data: RawByteString;
begin
  prober := TCharsetUTF16Prober.Create;
  try
    data := 'A'#0'B'#0'C'#0'D'#0'E'#0'F'#0'G'#0'H'#0 + #$3D#$D8#$00#$DE;
    prober.Feed(PAnsiChar(data), 1);
    prober.Feed(PAnsiChar(data) + 1, Length(data) - 1);
    AssertEquals(Ord(UTF16_LE_CHARSET), Ord(prober.Detect));

    prober.Reset;
    prober.Feed(PAnsiChar(data), Length(data) - 2);
    AssertEquals('unfinished surrogate', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    data := 'A'#0'B'#0'C'#0'D'#0'E'#0'F'#0'G'#0'H'#0 + #$00#$DC;
    prober.Feed(PAnsiChar(data), Length(data));
    AssertEquals('isolated low surrogate', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    data := 'A'#0'B'#0'C'#0'D'#0'E'#0'F'#0'G'#0'H'#0'X';
    prober.Feed(PAnsiChar(data), Length(data));
    AssertEquals('odd byte count', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));

    prober.Reset;
    data := 'A'#0'B'#0;
    prober.Feed(PAnsiChar(data), Length(data));
    AssertEquals('too little evidence', Ord(UNKNOWN_CHARSET),
      Ord(prober.Detect));
  finally
    prober.Free;
  end;
end;

procedure TUTF16Tests.LegacyAndBinaryNegativeSamples;
const
  LegacyNames: array[0..10] of String = (
    'ascii', 'windows-1251', 'windows-1252', 'windows-1253',
    'windows-1255', 'koi8-r', 'iso-8859-5', 'iso-8859-7',
    'iso-8859-8', 'iso-8859-8-shared', 'ibm866');
var
  bytes: RawByteString;
  name: String;
  i, ending: Integer;
begin
  for i := Low(LegacyNames) to High(LegacyNames) do
    for ending := 0 to 1 do
      begin
        name := LegacyNames[i];
        if ending = 0 then
          name := name + '-lf.txt'
        else
          name := name + '-crlf.txt';
        bytes := ReadFixture(name);
        AssertTrue(name + ' must not be UTF-16',
          (Detect(bytes, Length(bytes) div 2) <> 'UTF-16LE') and
          (Detect(bytes, Length(bytes) div 2) <> 'UTF-16BE'));
      end;

  bytes := ReadFixture('windows-1251-crlf.txt');
  AssertTrue('CP1251/CRLF must not be UTF-16LE',
    Detect(bytes, Length(bytes) div 2) <> 'UTF-16LE');
  AssertTrue('CP1251/CRLF must not be UTF-16BE',
    Detect(bytes, Length(bytes) div 2) <> 'UTF-16BE');
  bytes := #$00#$01#$00#$00#$02#$00#$00#$03
    + #$00#$00#$00#$04#$00#$05#$00#$00;
  AssertTrue('binary with NULs must not be UTF-16',
    (Detect(bytes, 5) <> 'UTF-16LE') and
    (Detect(bytes, 5) <> 'UTF-16BE'));
  bytes := ReadFixture('utf-16le-en-lf.txt');
  SetLength(bytes, Length(bytes) - 1);
  AssertTrue('truncated UTF-16 must not be accepted',
    Detect(bytes, Length(bytes) div 2) <> 'UTF-16LE');
end;

procedure TUTF16Tests.IndependentTextSamples;
var
  bytes: RawByteString;
begin
  bytes := 'H'#0'e'#0'l'#0'l'#0'o'#0','#0' '#0'w'#0'o'#0'r'#0'l'#0'd'#0'!'#0
    + #$0D#0#$0A#0;
  AssertEquals('UTF-16LE', Detect(bytes, 13));
  bytes := #0'H'#0'e'#0'l'#0'l'#0'o'#0','#0' '#0'w'#0'o'#0'r'#0'l'#0'd'#0'!'
    + #0#$0D#0#$0A;
  AssertEquals('UTF-16BE', Detect(bytes, 13));
end;

initialization
  RegisterTest(TUTF16Tests);

end.
