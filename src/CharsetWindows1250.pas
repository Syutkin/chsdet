unit CharsetWindows1250;

{$mode ObjFPC}{$H+}

interface

uses
  nsCore, CustomDetector;

type
  TWindows1250Prober = class(TCustomDetector)
  private
    FInsideTag: Boolean;
    FWordLength: Integer;
    FWordASCII: Integer;
    FWordEvidence: Integer;
    FWordMarks: set of Byte;
    FWordMarkCount: Integer;
    FEvidence: Integer;
    FMarks: set of Byte;
    FMarkCount: Integer;
    FHighBytes: Integer;
    FPairCounts: array of Cardinal;
    FPreviousByte: Byte;
    FHasPrevious: Boolean;
    procedure FinishWord;
    procedure ModelConfidence(out aCentral, aWestern: Double);
  public
    constructor Create; override;
    function HandleData(aBuf: PAnsiChar; aLen: Integer): eProbingState; override;
    function GetDetectedCharset: eInternalCharsetID; override;
    function GetConfidence: Double; override;
    procedure Reset; override;
    procedure FinishData;
  end;

implementation

uses
  Math;

type
  TModelInfo = record
    Charset: eInternalCharsetID;
    First: Integer;
    Count: Integer;
    Norm: Double;
  end;

{$I sbseq/CharsetWindows1250Models.inc}

constructor TWindows1250Prober.Create;
begin
  inherited Create;
  SetLength(FPairCounts, 65536);
  Reset;
end;

procedure TWindows1250Prober.ModelConfidence(out aCentral, aWestern: Double);
var
  i, j: Integer;
  inputNormSquared, value, dot: Double;
  score: Double;
begin
  aCentral := 0;
  aWestern := 0;
  inputNormSquared := 0;
  for i := 0 to High(FPairCounts) do
    if FPairCounts[i] <> 0 then
    begin
      value := Double(FPairCounts[i]) * IDFWeights[i];
      inputNormSquared := inputNormSquared + value * value;
    end;
  if inputNormSquared = 0 then
    Exit;
  for i := 0 to ModelCount - 1 do
  begin
    dot := 0;
    for j := ModelInfo[i].First to ModelInfo[i].First + ModelInfo[i].Count - 1 do
      dot := dot + Double(FPairCounts[ModelPairs[j]]) * ModelWeights[j];
    score := dot / (ModelInfo[i].Norm * Sqrt(inputNormSquared));
    if ModelInfo[i].Charset = WINDOWS_1250_CHARSET then
      aCentral := Max(aCentral, score)
    else
      aWestern := Max(aWestern, score);
  end;
end;

procedure TWindows1250Prober.FinishWord;
begin
  if not FInsideTag and (FWordLength >= 3) and (FWordASCII > 0) then
  begin
    Inc(FEvidence, FWordEvidence);
    FMarks := FMarks + FWordMarks;
    Inc(FMarkCount, FWordMarkCount);
  end;
  FWordLength := 0;
  FWordASCII := 0;
  FWordEvidence := 0;
  FWordMarks := [];
  FWordMarkCount := 0;
end;

function TWindows1250Prober.HandleData(aBuf: PAnsiChar;
  aLen: Integer): eProbingState;
var
  i: Integer;
  value: Byte;
begin
  Result := inherited HandleData(aBuf, aLen);
  if Result = psNotMe then
    Exit;
  for i := 0 to aLen - 1 do
  begin
    value := Byte(aBuf[i]);
    { Match chardet 7's collapsed whitespace runs when forming byte pairs. }
    if FHasPrevious and not ((FPreviousByte = value) and
      (value in [$09..$0D, $20, $A0])) then
      Inc(FPairCounts[(Integer(FPreviousByte) shl 8) or value]);
    FPreviousByte := value;
    FHasPrevious := True;
    if value = Ord('<') then
    begin
      FinishWord;
      FInsideTag := True;
    end
    else if value = Ord('>') then
    begin
      FinishWord;
      FInsideTag := False;
    end
    else if (value >= Ord('A')) and (value <= Ord('Z')) or
      (value >= Ord('a')) and (value <= Ord('z')) or (value >= $80) then
    begin
      Inc(FWordLength);
      if value >= $80 then
      begin
        Inc(FHighBytes);
        { These bytes are letters in CP1250 but symbols or undefined in
          CP1252. Evidence counts only inside a word, across input blocks. }
        if value in [$8D, $8F, $9D, $A1, $A3, $A5, $AF,
          $B3, $B9, $BC, $BE, $BF, $AA, $BA] then
          Inc(FWordEvidence);
        if value in [$C8, $E8, $CC, $EC, $D8, $F8, $D2, $F2,
          $D9, $F9, $D5, $F5, $DB, $FB, $C6, $E6, $D0, $F0] then
        begin
          Include(FWordMarks, value);
          Inc(FWordMarkCount);
        end;
      end;
      if value < $80 then
        Inc(FWordASCII);
    end
    else
      FinishWord;
  end;
end;

function TWindows1250Prober.GetDetectedCharset: eInternalCharsetID;
begin
  Result := WINDOWS_1250_CHARSET;
end;

function TWindows1250Prober.GetConfidence: Double;
var
  hasCzech, hasHungarian, hasSlavic: Boolean;
  centralScore, westernScore: Double;
begin
  if not Enabled or (FHighBytes = 0) then
    Exit(0);
  ModelConfidence(centralScore, westernScore);
  hasCzech := ((FMarks * [$D8, $F8]) <> []) and
    ((FMarks * [$C8, $E8, $CC, $EC]) <> []);
  hasHungarian := ((FMarks * [$D5, $F5]) <> []) and
    ((FMarks * [$DB, $FB]) <> []);
  hasSlavic := ((FMarks * [$C6, $E6]) <> []) and
    ((FMarks * [$D0, $F0]) <> []) and
    ((FMarks * [$C8, $E8]) <> []);
  if (FEvidence >= 2) and (FEvidence * 50 >= FHighBytes) then
    Result := 0.70 + 0.05 * FEvidence
  else if (FMarkCount >= 3) and (FMarkCount * 50 >= FHighBytes) and
    (hasCzech or hasHungarian or hasSlavic) then
    { Distinct central European letters must co-occur in ordinary words.
      A single accent also has a plausible Western interpretation. }
    Result := 0.70 + 0.02 * FMarkCount
  else
    Result := 0;
  { Full CP1250 and CP1252 language profiles from chardet 7. Their cosine
    scores share one input norm, so compare the strongest language per page. }
  if (centralScore >= 0.12) and (centralScore > westernScore * 1.08) and
    (centralScore - westernScore >= 0.02) and (FHighBytes >= 5) then
    Result := Max(Result, 0.75 + 0.20 * centralScore);
  if (westernScore >= 0.12) and (westernScore > centralScore * 1.05) then
    Result := 0;
  if Result > 0.95 then
    Result := 0.95;
end;

procedure TWindows1250Prober.Reset;
begin
  inherited Reset;
  FInsideTag := False;
  FWordLength := 0;
  FWordASCII := 0;
  FWordEvidence := 0;
  FWordMarks := [];
  FWordMarkCount := 0;
  FEvidence := 0;
  FMarks := [];
  FMarkCount := 0;
  FHighBytes := 0;
  FHasPrevious := False;
  FillChar(FPairCounts[0], Length(FPairCounts) * SizeOf(Cardinal), 0);
end;

procedure TWindows1250Prober.FinishData;
begin
  FinishWord;
end;

end.
