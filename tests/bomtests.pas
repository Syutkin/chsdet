unit BOMTests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  SysUtils, fpcunit, testregistry, nsCore, CustomDetector,
  nsUniversalDetector, CharsetBOM;

type
  TSpyProber = class(TCustomDetector)
  private
    FSeen: RawByteString;
  public
    function HandleData(aBuf: PAnsiChar; aLen: integer): eProbingState; override;
    function GetDetectedCharset: eInternalCharsetID; override;
    function GetConfidence: float; override;
    procedure Reset; override;
    property Seen: RawByteString read FSeen;
  end;

  TSpyUniversalDetector = class(TnsUniversalDetector)
  public
    constructor Create;
    function Seen: RawByteString;
  end;

  TBOMTests = class(TTestCase)
  private
    function BOMBytes(aBOM: eBOMKind): RawByteString;
    function ExpectedCharset(aBOM: eBOMKind): eInternalCharsetID;
    procedure CheckBOM(const aData: RawByteString; aBOM: eBOMKind;
      aCharset: eInternalCharsetID);
  published
    procedure PrefixResolution;
    procedure BOMOnlyAndAllSplits;
    procedure UTF32CodePages;
    procedure SharedBOMPrefixesAndEOF;
    procedure NonBOMPrefixIsForwardedOnce;
    procedure ResetClearsPendingBOM;
  end;

function TSpyProber.HandleData(aBuf: PAnsiChar; aLen: integer): eProbingState;
var
  chunk: RawByteString;
begin
  SetString(chunk, aBuf, aLen);
  FSeen := FSeen + chunk;
  Result := psDetecting;
end;

function TSpyProber.GetDetectedCharset: eInternalCharsetID;
begin
  Result := UNKNOWN_CHARSET;
end;

function TSpyProber.GetConfidence: float;
begin
  Result := SURE_NO;
end;

procedure TSpyProber.Reset;
begin
  inherited Reset;
  FSeen := '';
end;

constructor TSpyUniversalDetector.Create;
var
  i: integer;
begin
  inherited Create;
  for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
    begin
      mCharSetProbers[i].Free;
      mCharSetProbers[i] := TSpyProber.Create;
    end;
  Reset;
end;

function TSpyUniversalDetector.Seen: RawByteString;
begin
  Result := TSpyProber(mCharSetProbers[0]).Seen;
end;

function TBOMTests.BOMBytes(aBOM: eBOMKind): RawByteString;
var
  i: integer;
begin
  Result := '';
  SetLength(Result, KNOWN_BOM[aBOM].Length);
  for i := 0 to Pred(Length(Result)) do
    Result[i + 1] := KNOWN_BOM[aBOM].BOM[i];
end;

function TBOMTests.ExpectedCharset(aBOM: eBOMKind): eInternalCharsetID;
begin
  case aBOM of
    BOM_UCS4_BE: Result := UTF32_BE_CHARSET;
    BOM_UCS4_LE: Result := UTF32_LE_CHARSET;
    BOM_UTF16_BE: Result := UTF16_BE_CHARSET;
    BOM_UTF16_LE: Result := UTF16_LE_CHARSET;
    BOM_UTF8: Result := UTF8_CHARSET;
    else Result := UNKNOWN_CHARSET;
  end;
end;

procedure TBOMTests.CheckBOM(const aData: RawByteString; aBOM: eBOMKind;
  aCharset: eInternalCharsetID);
var
  detector: TnsUniversalDetector;
  cut, i: integer;
begin
  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(PAnsiChar(aData), Length(aData));
    detector.DataEnd;
    AssertEquals(Ord(aBOM), Ord(detector.BOMDetected));
    AssertEquals(String(KNOWN_CHARSETS[aCharset].Name),
      String(detector.GetDetectedCharsetInfo.Name));

    for cut := 1 to Pred(Length(aData)) do
      begin
        detector.Reset;
        detector.HandleData(PAnsiChar(aData), cut);
        detector.HandleData(nil, 0);
        detector.HandleData(PAnsiChar(aData) + cut, Length(aData) - cut);
        detector.DataEnd;
        AssertEquals('split at ' + IntToStr(cut), Ord(aBOM),
          Ord(detector.BOMDetected));
        AssertEquals(String(KNOWN_CHARSETS[aCharset].Name),
          String(detector.GetDetectedCharsetInfo.Name));
      end;

    detector.Reset;
    for i := 1 to Length(aData) do
      detector.HandleData(@aData[i], 1);
    detector.DataEnd;
    AssertEquals(Ord(aBOM), Ord(detector.BOMDetected));
    AssertEquals(String(KNOWN_CHARSETS[aCharset].Name),
      String(detector.GetDetectedCharsetInfo.Name));
  finally
    detector.Free;
  end;
end;

procedure TBOMTests.PrefixResolution;
var
  bom: eBOMKind;
  data: RawByteString;
begin
  data := #$FF#$FE;
  AssertFalse(ResolveCharsetBOM(PAnsiChar(data), Length(data), False, bom));
  AssertEquals(Ord(BOM_Not_Found), Ord(bom));
  AssertTrue(ResolveCharsetBOM(PAnsiChar(data), Length(data), True, bom));
  AssertEquals(Ord(BOM_UTF16_LE), Ord(bom));
  AssertEquals(Ord(BOM_UTF16_LE),
    Ord(DetectCharsetBOM(PAnsiChar(data), Length(data))));

  data := #$EF#$BB;
  AssertFalse(ResolveCharsetBOM(PAnsiChar(data), Length(data), False, bom));
  AssertTrue(ResolveCharsetBOM(PAnsiChar(data), Length(data), True, bom));
  AssertEquals(Ord(BOM_Not_Found), Ord(bom));
  AssertEquals(Ord(BOM_Not_Found),
    Ord(DetectCharsetBOM(PAnsiChar(data), Length(data))));
end;

procedure TBOMTests.BOMOnlyAndAllSplits;
var
  bom: eBOMKind;
begin
  for bom := Succ(BOM_Not_Found) to High(eBOMKind) do
    begin
      CheckBOM(BOMBytes(bom), bom, ExpectedCharset(bom));
      CheckBOM(BOMBytes(bom) + 'X', bom, ExpectedCharset(bom));
    end;
end;

procedure TBOMTests.UTF32CodePages;
var
  detector: TnsUniversalDetector;
  data: RawByteString;
begin
  detector := TnsUniversalDetector.Create;
  try
    data := #$FF#$FE#$00#$00;
    detector.HandleData(PAnsiChar(data), Length(data));
    detector.DataEnd;
    AssertEquals('UTF-32LE', 12000, detector.GetDetectedCharsetInfo.CodePage);

    detector.Reset;
    data := #$00#$00#$FE#$FF;
    detector.HandleData(PAnsiChar(data), Length(data));
    detector.DataEnd;
    AssertEquals('UTF-32BE', 12001, detector.GetDetectedCharsetInfo.CodePage);
  finally
    detector.Free;
  end;
end;

procedure TBOMTests.SharedBOMPrefixesAndEOF;
var
  detector: TnsUniversalDetector;
begin
  CheckBOM(#$FF#$FE#$00#$00, BOM_UCS4_LE, UTF32_LE_CHARSET);
  CheckBOM(#$FF#$FE#$00'X', BOM_UTF16_LE, UTF16_LE_CHARSET);
  CheckBOM(#$FE#$FF#$00'X', BOM_UTF16_BE, UTF16_BE_CHARSET);
  CheckBOM(#$FF#$FE#$00, BOM_UTF16_LE, UTF16_LE_CHARSET);

  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(PAnsiChar(#$FF#$FE), 2);
    AssertEquals(Ord(BOM_Not_Found), Ord(detector.BOMDetected));
    AssertFalse(detector.Done);
    detector.DataEnd;
    AssertEquals(Ord(BOM_UTF16_LE), Ord(detector.BOMDetected));
    AssertTrue(detector.Done);
  finally
    detector.Free;
  end;
end;

procedure TBOMTests.NonBOMPrefixIsForwardedOnce;
var
  detector: TSpyUniversalDetector;
  data: RawByteString;
begin
  detector := TSpyUniversalDetector.Create;
  try
    data := #$EF#$BA'abc';
    detector.HandleData(@data[1], 1);
    detector.HandleData(nil, 0);
    detector.HandleData(@data[2], 1);
    detector.HandleData(@data[3], Length(data) - 2);
    detector.DataEnd;
    AssertEquals(String(data), String(detector.Seen));
    AssertEquals(Ord(BOM_Not_Found), Ord(detector.BOMDetected));

    detector.Reset;
    data := #$EF#$BB;
    detector.HandleData(PAnsiChar(data), Length(data));
    AssertEquals('', String(detector.Seen));
    detector.DataEnd;
    AssertEquals(String(data), String(detector.Seen));
    AssertEquals(Ord(BOM_Not_Found), Ord(detector.BOMDetected));
  finally
    detector.Free;
  end;
end;

procedure TBOMTests.ResetClearsPendingBOM;
var
  detector: TnsUniversalDetector;
  data: RawByteString;
begin
  detector := TnsUniversalDetector.Create;
  try
    data := #$EF#$BB;
    detector.HandleData(PAnsiChar(data), Length(data));
    detector.Reset;
    data := 'plain ASCII';
    detector.HandleData(PAnsiChar(data), Length(data));
    detector.DataEnd;
    AssertEquals(Ord(BOM_Not_Found), Ord(detector.BOMDetected));
    AssertEquals('ASCII', String(detector.GetDetectedCharsetInfo.Name));
  finally
    detector.Free;
  end;
end;

initialization
  RegisterTest(TBOMTests);

end.
