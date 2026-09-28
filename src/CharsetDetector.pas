unit CharsetDetector;

{$mode ObjFPC}{$H+}

interface

uses
  nsCore, nsUniversalDetector;

type
  TCharsetDetectionStatus = (
    dsDetected, dsAmbiguous, dsInsufficientData, dsUnknown,
    dsExcludedByProfile
  );
  TCharsetDetectionSource = (
    csNone, csBOM, csASCII, csUTF8Validation, csUTF16Structure,
    csStatistics
  );
  TCharsetCandidate = record
    Charset: string;
    CodePage: Integer;
    Confidence: Double;
    HasConfidence: Boolean;
    Source: TCharsetDetectionSource;
    Language: string;
  end;
  TCharsetCandidates = array of TCharsetCandidate;
  TCharsetDetectionResult = record
    Status: TCharsetDetectionStatus;
    Charset: string;
    CodePage: Integer;
    Confidence: Double;
    HasConfidence: Boolean;
    Source: TCharsetDetectionSource;
    BOM: eBOMKind;
    BOMSize: Integer;
    Candidates: TCharsetCandidates;
    BytesSeen: QWord;
    IsFinal: Boolean;
  end;

  TCharsetDetector = class
  private
    const InputBlockSize = 512;
  private
    FCore: TnsUniversalDetector;
    FInputBlock: array[0..InputBlockSize - 1] of Byte;
    FInputLength: Integer;
    FBytesSeen: QWord;
    FFinal: Boolean;
    FSharedHebrewBytes: Boolean;
    FHasHebrew: Boolean;
    FResult: TCharsetDetectionResult;
    function BuildResult: TCharsetDetectionResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Feed(Buffer: Pointer; Count: SizeInt);
    function Finish: TCharsetDetectionResult;
    procedure Reset;
  end;

function DetectCharset(const Data: RawByteString): TCharsetDetectionResult;

implementation

uses
  SysUtils;

type
  TCharsetCoreDetector = class(TnsUniversalDetector)
  public
    function ChosenCharset: eInternalCharsetID;
    function DecisionSource: TCharsetDetectionSource;
    function ModelScores: TCharsetModelScores;
  end;

function TCharsetCoreDetector.ChosenCharset: eInternalCharsetID;
begin
  Result := mDetectedCharset;
end;

function TCharsetCoreDetector.DecisionSource: TCharsetDetectionSource;
begin
  Result := csNone;
  if mDetectedBOM <> BOM_Not_Found then
    Result := csBOM
  else if (mDetectedCharset = UTF16_LE_CHARSET) or
    (mDetectedCharset = UTF16_BE_CHARSET) then
    begin
      if mUTF16.Detect = mDetectedCharset then
        Result := csUTF16Structure
      else
        Result := csStatistics;
    end
  else if mDetectedCharset = PURE_ASCII_CHARSET then
    Result := csASCII
  else if mDetectedCharset = UTF8_CHARSET then
    begin
      if mUTF8.Finish and (mUTF8.MultibyteCount >= 2) and
        not mUTF8.HasNUL then
        Result := csUTF8Validation
      else
        Result := csStatistics;
    end
  else if mDetectedCharset <> UNKNOWN_CHARSET then
    Result := csStatistics;
end;

function TCharsetCoreDetector.ModelScores: TCharsetModelScores;
var
  part: TCharsetModelScores;
  i, j, first: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  if mInputState = isEscAscii then
    Exit(mEscCharSetProber.GetModelScores);
  if mInputState <> isHighbyte then
    Exit;
  { The old UTF-8 state machine is superseded by CharsetUTF8. }
  for i := 0 to 2 do
    begin
      part := mCharSetProbers[i].GetModelScores;
      first := Length(Result);
      SetLength(Result, first + Length(part));
      for j := 0 to High(part) do
        Result[first + j] := part[j];
    end;
end;

procedure AddCandidate(var aCandidates: TCharsetCandidates;
  aCharset: eInternalCharsetID; aConfidence: Double;
  aHasConfidence: Boolean; aSource: TCharsetDetectionSource);
var
  i: Integer;
  name: string;
begin
  if aCharset = UNKNOWN_CHARSET then
    Exit;
  name := String(KNOWN_CHARSETS[aCharset].Name);
  if aConfidence < 0 then
    aConfidence := 0
  else if aConfidence > 1 then
    aConfidence := 1;
  for i := 0 to High(aCandidates) do
    if SameText(aCandidates[i].Charset, name) then
      begin
        { Several language models for one encoding contribute one candidate.
          The maximum model score is used, never their sum. }
        if aHasConfidence and
          (not aCandidates[i].HasConfidence or
           (aConfidence > aCandidates[i].Confidence)) then
          begin
            aCandidates[i].Confidence := aConfidence;
            aCandidates[i].HasConfidence := True;
            aCandidates[i].Language := String(KNOWN_CHARSETS[aCharset].Language);
          end;
        Exit;
      end;
  i := Length(aCandidates);
  SetLength(aCandidates, i + 1);
  aCandidates[i].Charset := name;
  aCandidates[i].CodePage := KNOWN_CHARSETS[aCharset].CodePage;
  aCandidates[i].Confidence := aConfidence;
  aCandidates[i].HasConfidence := aHasConfidence;
  aCandidates[i].Source := aSource;
  aCandidates[i].Language := String(KNOWN_CHARSETS[aCharset].Language);
end;

function CandidateBefore(const aLeft, aRight: TCharsetCandidate): Boolean;
begin
  if aLeft.HasConfidence <> aRight.HasConfidence then
    Exit(aLeft.HasConfidence);
  if aLeft.Confidence <> aRight.Confidence then
    Exit(aLeft.Confidence > aRight.Confidence);
  Result := CompareText(aLeft.Charset, aRight.Charset) < 0;
end;

procedure SortCandidates(var aCandidates: TCharsetCandidates);
var
  i, j: Integer;
  item: TCharsetCandidate;
begin
  for i := 1 to High(aCandidates) do
    begin
      item := aCandidates[i];
      j := i;
      while (j > 0) and CandidateBefore(item, aCandidates[j - 1]) do
        begin
          aCandidates[j] := aCandidates[j - 1];
          Dec(j);
        end;
      aCandidates[j] := item;
    end;
end;

function CandidateIndex(const aCandidates: TCharsetCandidates;
  const aName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(aCandidates) do
    if SameText(aCandidates[i].Charset, aName) then
      Exit(i);
  Result := -1;
end;

constructor TCharsetDetector.Create;
begin
  inherited Create;
  FCore := TCharsetCoreDetector.Create;
  Reset;
end;

destructor TCharsetDetector.Destroy;
begin
  FCore.Free;
  inherited Destroy;
end;

procedure TCharsetDetector.Reset;
begin
  FCore.Reset;
  FInputLength := 0;
  FBytesSeen := 0;
  FFinal := False;
  FSharedHebrewBytes := True;
  FHasHebrew := False;
  FResult := Default(TCharsetDetectionResult);
end;

procedure TCharsetDetector.Feed(Buffer: Pointer; Count: SizeInt);
var
  current: PByte;
  remaining: SizeInt;
  take, i: Integer;
  value: Byte;
begin
  if FFinal then
    raise EInvalidOp.Create('Feed after Finish');
  if (Count < 0) or ((Count > 0) and (Buffer = nil)) then
    raise EArgumentException.Create('Invalid input buffer or byte count');
  if Count = 0 then
    Exit;
  if FBytesSeen > High(QWord) - QWord(Count) then
    raise EArgumentException.Create('Input byte count overflow');

  current := PByte(Buffer);
  remaining := Count;
  while remaining > 0 do
    begin
      if remaining > InputBlockSize - FInputLength then
        take := InputBlockSize - FInputLength
      else
        take := Integer(remaining);
      for i := 0 to take - 1 do
        begin
          value := current[i];
          if value in [$E0..$FA] then
            FHasHebrew := True
          else if value >= $80 then
            FSharedHebrewBytes := False;
        end;
      Move(current^, FInputBlock[FInputLength], take);
      Inc(FInputLength, take);
      Inc(FBytesSeen, QWord(take));
      Inc(current, take);
      Dec(remaining, take);
      if FInputLength = InputBlockSize then
        begin
          FCore.HandleData(PAnsiChar(@FInputBlock[0]), FInputLength);
          FInputLength := 0;
        end;
    end;
end;

function TCharsetDetector.BuildResult: TCharsetDetectionResult;
const
  MinimumStatConfidence = 0.20;
  AmbiguousGap = 0.05;
var
  core: TCharsetCoreDetector;
  scores: TCharsetModelScores;
  source: TCharsetDetectionSource;
  chosen: eInternalCharsetID;
  i, isoIndex, windowsIndex: Integer;
  hebrewConfidence: Double;
  sharedHebrew: Boolean;
begin
  Result := Default(TCharsetDetectionResult);
  Result.Status := dsUnknown;
  Result.BOM := FCore.BOMDetected;
  Result.BOMSize := KNOWN_BOM[Result.BOM].Length;
  Result.BytesSeen := FBytesSeen;
  Result.IsFinal := True;
  if FBytesSeen = 0 then
    begin
      Result.Status := dsInsufficientData;
      Exit;
    end;

  core := TCharsetCoreDetector(FCore);
  chosen := core.ChosenCharset;
  source := core.DecisionSource;
  if (source in [csBOM, csASCII, csUTF8Validation, csUTF16Structure]) and
    (chosen <> UNKNOWN_CHARSET) then
    begin
      Result.Status := dsDetected;
      Result.Charset := String(KNOWN_CHARSETS[chosen].Name);
      Result.CodePage := KNOWN_CHARSETS[chosen].CodePage;
      Result.Source := source;
      AddCandidate(Result.Candidates, chosen, 0, False, source);
      Exit;
    end;

  scores := core.ModelScores;
  for i := 0 to High(scores) do
    if (scores[i].State <> psNotMe) and
      (scores[i].Confidence > SURE_NO) then
      AddCandidate(Result.Candidates, scores[i].CharsetID,
        scores[i].Confidence, True, csStatistics);
  SortCandidates(Result.Candidates);
  if Length(Result.Candidates) > 0 then
    begin
      Result.Charset := Result.Candidates[0].Charset;
      Result.CodePage := Result.Candidates[0].CodePage;
      Result.Confidence := Result.Candidates[0].Confidence;
      Result.HasConfidence := Result.Candidates[0].HasConfidence;
      Result.Source := Result.Candidates[0].Source;
    end;
  { A statistical guess from fewer than four bytes is insufficient evidence.
    Exact BOM and ASCII decisions above do not use this threshold. }
  if FBytesSeen < 4 then
    begin
      Result.Status := dsInsufficientData;
      Exit;
    end;
  if (Length(Result.Candidates) = 0) or
    (Result.Candidates[0].Confidence < MinimumStatConfidence) then
    Exit;

  isoIndex := CandidateIndex(Result.Candidates, 'ISO-8859-8');
  windowsIndex := CandidateIndex(Result.Candidates, 'windows-1255');
  sharedHebrew := False;
  if FSharedHebrewBytes and FHasHebrew and
    (isoIndex >= 0) and (windowsIndex >= 0) then
    begin
      hebrewConfidence := Result.Candidates[isoIndex].Confidence;
      if Result.Candidates[windowsIndex].Confidence > hebrewConfidence then
        hebrewConfidence := Result.Candidates[windowsIndex].Confidence;
      sharedHebrew := (hebrewConfidence >= MinimumStatConfidence) and
        (Result.Candidates[0].Confidence - hebrewConfidence <= AmbiguousGap);
    end;
  if sharedHebrew or
    ((Length(Result.Candidates) > 1) and
     (Result.Candidates[0].Confidence -
      Result.Candidates[1].Confidence <= AmbiguousGap)) then
    begin
      Result.Status := dsAmbiguous;
      Exit;
    end;

  Result.Status := dsDetected;
end;

function TCharsetDetector.Finish: TCharsetDetectionResult;
begin
  if not FFinal then
    begin
      if FInputLength > 0 then
        begin
          FCore.HandleData(PAnsiChar(@FInputBlock[0]), FInputLength);
          FInputLength := 0;
        end;
      FCore.DataEnd;
      FResult := BuildResult;
      FFinal := True;
    end;
  Result := FResult;
  Result.Candidates := Copy(FResult.Candidates, 0, Length(FResult.Candidates));
end;

function DetectCharset(const Data: RawByteString): TCharsetDetectionResult;
var
  detector: TCharsetDetector;
begin
  detector := TCharsetDetector.Create;
  try
    detector.Feed(Pointer(Data), Length(Data));
    Result := detector.Finish;
  finally
    detector.Free;
  end;
end;

end.
