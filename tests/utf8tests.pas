unit UTF8Tests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpcunit, testregistry, CharsetUTF8, nsUniversalDetector;

type
  TUTF8Tests = class(TTestCase)
  private
    procedure CheckValidity(const aData: RawByteString; aExpected: Boolean);
    function Detect(const aData: RawByteString; aSplit: Integer): String;
    function ReadFixture(const aName: String): RawByteString;
  published
    procedure ValidRangesAndEverySplit;
    procedure RejectInvalidRangesAndTruncatedEOF;
    procedure ASCIIHasPriorityOverValidUTF8;
    procedure InvalidUTF8CannotWinAfterAnEarlyPrefix;
    procedure FixtureSplits;
  end;

procedure TUTF8Tests.CheckValidity(const aData: RawByteString;
  aExpected: Boolean);
var
  validator: TCharsetUTF8Validator;
  cut, i: Integer;
begin
  validator := TCharsetUTF8Validator.Create;
  try
    validator.Feed(PAnsiChar(aData), Length(aData));
    AssertEquals('whole input', aExpected, validator.Finish);
    for cut := 0 to Length(aData) do
      begin
        validator.Reset;
        validator.Feed(PAnsiChar(aData), cut);
        validator.Feed(nil, 0);
        validator.Feed(PAnsiChar(aData) + cut, Length(aData) - cut);
        AssertEquals('split at ' + IntToStr(cut), aExpected,
          validator.Finish);
      end;
    validator.Reset;
    for i := 1 to Length(aData) do
      validator.Feed(@aData[i], 1);
    AssertEquals('byte by byte', aExpected, validator.Finish);
  finally
    validator.Free;
  end;
end;

function TUTF8Tests.ReadFixture(const aName: String): RawByteString;
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

function TUTF8Tests.Detect(const aData: RawByteString; aSplit: Integer): String;
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

procedure TUTF8Tests.ValidRangesAndEverySplit;
begin
  CheckValidity('', True);
  CheckValidity(#$7F, True);
  CheckValidity(#$C2#$80#$DF#$BF, True);
  CheckValidity(#$E0#$A0#$80#$ED#$9F#$BF, True);
  CheckValidity(#$EE#$80#$80#$EF#$BF#$BF, True);
  CheckValidity(#$F0#$90#$80#$80#$F4#$8F#$BF#$BF, True);
end;

procedure TUTF8Tests.RejectInvalidRangesAndTruncatedEOF;
begin
  CheckValidity(#$80, False);
  CheckValidity(#$A0, False);
  CheckValidity(#$C0#$AF, False);
  CheckValidity(#$C1#$BF, False);
  CheckValidity(#$E0#$9F#$BF, False);
  CheckValidity(#$ED#$A0#$80, False);
  CheckValidity(#$F0#$8F#$BF#$BF, False);
  CheckValidity(#$F4#$90#$80#$80, False);
  CheckValidity(#$F5#$80#$80#$80, False);
  CheckValidity(#$C2'X', False);
  CheckValidity(#$E2#$82, False);
  CheckValidity(#$F0#$90#$80, False);
end;

procedure TUTF8Tests.ASCIIHasPriorityOverValidUTF8;
var
  validator: TCharsetUTF8Validator;
  data: RawByteString;
begin
  validator := TCharsetUTF8Validator.Create;
  try
    data := #0#$7F;
    validator.Feed(PAnsiChar(data), Length(data));
    AssertTrue(validator.IsASCII);
    AssertTrue(validator.HasNUL);
    AssertTrue(validator.Finish);
    validator.Reset;
    data := #$80;
    validator.Feed(PAnsiChar(data), Length(data));
    AssertFalse(validator.IsASCII);
    validator.Reset;
    data := #$A0;
    validator.Feed(PAnsiChar(data), Length(data));
    AssertFalse(validator.IsASCII);
  finally
    validator.Free;
  end;

  AssertEquals('ASCII', Detect('plain text' + #$7F, 3));
  AssertEquals('ASCII', Detect('plain' + #$1B'bad escape', 2));
  AssertEquals('ISO-2022-JP', Detect(#$1B'$B$"'#$1B'(B', 2));
  AssertTrue(Detect(#0'plain text', 4) <> 'ASCII');
  AssertTrue(Detect(#$80, 1) <> 'ASCII');
  AssertTrue(Detect(#$A0, 1) <> 'ASCII');
  AssertEquals('UTF-8', Detect('prefix ' + #$C3#$A9#$C3#$A0, 8));
  AssertTrue('one accented character is weak evidence',
    Detect(#$C3#$A9, 1) <> 'UTF-8');
end;

procedure TUTF8Tests.InvalidUTF8CannotWinAfterAnEarlyPrefix;
var
  data: RawByteString;
begin
  data := 'prefix ' + #$C3#$A9#$C3#$A0 + ' suffix ' + #$E2#$82;
  AssertTrue(Detect(data, Length(data) - 1) <> 'UTF-8');
  data := 'prefix ' + #$C3#$A9#$C3#$A0 + ' suffix ' + #$FF;
  AssertTrue(Detect(data, Length(data) - 1) <> 'UTF-8');
end;

procedure TUTF8Tests.FixtureSplits;
const
  Languages: array[0..4] of String = ('ru', 'en', 'fr', 'el', 'he');
  LineEndings: array[0..1] of String = ('lf', 'crlf');
var
  lang, ending, cut: Integer;
  bytes: RawByteString;
  fileName: String;
begin
  for lang := Low(Languages) to High(Languages) do
    for ending := Low(LineEndings) to High(LineEndings) do
      begin
        fileName := 'utf-8-' + Languages[lang] + '-' +
          LineEndings[ending] + '.txt';
        bytes := ReadFixture(fileName);
        for cut := 0 to Length(bytes) do
          AssertEquals(fileName + ' split ' + IntToStr(cut), 'UTF-8',
            Detect(bytes, cut));
      end;
end;

initialization
  RegisterTest(TUTF8Tests);

end.
