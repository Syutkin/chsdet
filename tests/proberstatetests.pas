unit ProberStateTests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  fpcunit, testregistry, nsCore, nsSBCSGroupProber,
  nsEscCharsetProber, MBUnicodeMultiProber, nsMBCSMultiProber;

type
  TInspectEscProber = class(TnsEscCharSetProber)
  public
    function ActiveCount: integer;
  end;

  TInspectUnicodeProber = class(TMBUnicodeMultiProber)
  public
    function ActiveCount: integer;
    function SelectedCharset: eInternalCharsetID;
  end;

  TInspectSBCSProber = class(TnsSBCSGroupProber)
  public
    function StoredBestGuess: integer;
  end;

  TInspectMBCSProber = class(TnsMBCSMultiProber)
  public
    function SelectedCharset: eInternalCharsetID;
  end;

  TProberStateTests = class(TTestCase)
  published
    procedure ActiveModelsAndSoleCandidate;
    procedure ConfidenceGettersDoNotChangeSelection;
    procedure TerminalStateRemainsTerminal;
  end;

function TInspectEscProber.ActiveCount: integer;
begin
  Result := mActiveSM;
end;

function TInspectUnicodeProber.ActiveCount: integer;
begin
  Result := mActiveSM;
end;

function TInspectUnicodeProber.SelectedCharset: eInternalCharsetID;
begin
  Result := mDetectedCharset;
end;

function TInspectSBCSProber.StoredBestGuess: integer;
begin
  Result := mBestGuess;
end;

function TInspectMBCSProber.SelectedCharset: eInternalCharsetID;
begin
  Result := mDetectedCharset;
end;

procedure TProberStateTests.ActiveModelsAndSoleCandidate;
var
  escape: TInspectEscProber;
  unicode: TInspectUnicodeProber;
  data: RawByteString;
begin
  escape := TInspectEscProber.Create;
  unicode := TInspectUnicodeProber.Create;
  try
    AssertEquals(4, escape.ActiveCount);
    AssertTrue(escape.EnableCharset(ISO_2022_CN_CHARSET, False));
    escape.Reset;
    AssertEquals(3, escape.ActiveCount);
    AssertTrue(escape.EnableCharset(ISO_2022_JP_CHARSET, False));
    AssertTrue(escape.EnableCharset(ISO_2022_KR_CHARSET, False));
    escape.Reset;
    AssertEquals(1, escape.ActiveCount);
    data := 'plain';
    AssertTrue(escape.HandleData(PAnsiChar(data), Length(data)) <> psFoundIt);
    AssertEquals(Ord(UNKNOWN_CHARSET), Ord(escape.GetDetectedCharset));
    AssertTrue(escape.EnableCharset(HZ_GB_2312_CHARSET, False));
    escape.Reset;
    AssertEquals(0, escape.ActiveCount);
    AssertEquals(Ord(psNotMe), Ord(escape.GetState));

    AssertEquals(1, unicode.ActiveCount);
    AssertEquals(Ord(UNKNOWN_CHARSET), Ord(unicode.SelectedCharset));
    AssertEquals(SURE_NO, unicode.GetConfidence, 0.000001);
    AssertEquals(Ord(UNKNOWN_CHARSET), Ord(unicode.SelectedCharset));
    AssertTrue(unicode.EnableCharset(UTF8_CHARSET, False));
    unicode.Reset;
    AssertEquals(0, unicode.ActiveCount);
  finally
    escape.Free;
    unicode.Free;
  end;
end;

procedure TProberStateTests.ConfidenceGettersDoNotChangeSelection;
var
  sbcs: TInspectSBCSProber;
  mbcs: TInspectMBCSProber;
  data: RawByteString;
  before: eInternalCharsetID;
begin
  sbcs := TInspectSBCSProber.Create;
  mbcs := TInspectMBCSProber.Create;
  try
    AssertEquals(-1, sbcs.StoredBestGuess);
    sbcs.GetConfidence;
    sbcs.GetDetectedCharset;
    AssertEquals(-1, sbcs.StoredBestGuess);

    data := #$82#$A0#$82#$A2#$82#$A4#$82#$A6;
    mbcs.HandleData(PAnsiChar(data), Length(data));
    before := mbcs.SelectedCharset;
    AssertTrue(mbcs.GetConfidence > SURE_NO);
    mbcs.GetDetectedCharset;
    AssertEquals(Ord(before), Ord(mbcs.SelectedCharset));
  finally
    sbcs.Free;
    mbcs.Free;
  end;
end;

procedure TProberStateTests.TerminalStateRemainsTerminal;
var
  escape: TnsEscCharSetProber;
  data: RawByteString;
begin
  escape := TnsEscCharSetProber.Create;
  try
    data := #$1B'$)A';
    AssertEquals(Ord(psFoundIt),
      Ord(escape.HandleData(PAnsiChar(data), Length(data))));
    AssertEquals(Ord(ISO_2022_CN_CHARSET), Ord(escape.GetDetectedCharset));
    data := #$1B'$B';
    AssertEquals(Ord(psFoundIt),
      Ord(escape.HandleData(PAnsiChar(data), Length(data))));
    AssertEquals(Ord(ISO_2022_CN_CHARSET), Ord(escape.GetDetectedCharset));
  finally
    escape.Free;
  end;
end;

initialization
  RegisterTest(TProberStateTests);

end.
