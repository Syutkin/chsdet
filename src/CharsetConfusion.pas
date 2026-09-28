unit CharsetConfusion;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}

interface

type
  TConfusionPair = (cpGreek, cpCyrillic);
  TConfusionDecision = (cdNoEvidence, cdFirst, cdSecond);

  TCharsetConfusion = record
  private
    FPrevious: Byte;
    FBeforePrevious: Byte;
    FCount: QWord;
    FFinished: Boolean;
    FCategoryScore: array[TConfusionPair, 0..1] of LongInt;
    FBigramScore: array[TConfusionPair, 0..1] of LongInt;
    FDifferenceCount: array[TConfusionPair] of LongInt;
    procedure ScorePosition(aByte: Byte; aHasBefore: Boolean;
      aBefore: Byte; aHasAfter: Boolean; aAfter: Byte);
    procedure ScoreBigram(aBefore, aAfter: Byte);
  public
    procedure Reset;
    procedure Feed(aByte: Byte);
    procedure Finish;
    function Decide(aPair: TConfusionPair): TConfusionDecision;
  end;

implementation

uses
  nsSBCharSetProber, LangGreekModel, LangCyrillicModel;

{$I CharsetConfusionTables.inc}

const
  EvidenceCap = 16384;

function CategoryOf(aPair: TConfusionPair; aVariant: Integer;
  aByte: Byte): Byte;
begin
  case aPair of
    cpGreek:
      if aVariant = 0 then
        Result := Windows1253Categories[aByte]
      else
        Result := ISO88597Categories[aByte];
    cpCyrillic:
      if aVariant = 0 then
        Result := Windows1251Categories[aByte]
      else
        Result := MacCyrillicCategories[aByte];
  end;
end;

function Differs(aPair: TConfusionPair; aByte: Byte): Boolean;
begin
  case aPair of
    cpGreek: Result := aByte in GreekDifference;
    cpCyrillic: Result := aByte in CyrillicDifference;
  end;
end;

function IsLetter(aCategory: Byte): Boolean;
begin
  Result := aCategory in [2..4];
end;

function CategoryVote(aCurrent, aBefore, aAfter: Byte): LongInt;
begin
  if aCurrent = 0 then
    Exit(-4);
  if (aCurrent = 3) and (aBefore = 2) then
    Exit(-3);
  if (aCurrent = 7) and not IsLetter(aBefore) and IsLetter(aAfter) then
    Exit(-3);
  { A miscellaneous punctuation mark immediately before a letter rarely
    forms the start of a word (for example pilcrow versus Greek Ά). }
  if (aCurrent = 9) and (aBefore = 1) and IsLetter(aAfter) then
    Exit(-2);
  if (aCurrent = 10) and IsLetter(aBefore) and IsLetter(aAfter) then
    Exit(-3);
  if (aCurrent = 10) and (IsLetter(aBefore) or IsLetter(aAfter)) then
    Exit(-2);
  if (aCurrent in [6..9]) and IsLetter(aBefore) and IsLetter(aAfter) then
    Exit(-2);
  Result := 0;
end;

function ModelFor(aPair: TConfusionPair;
  aVariant: Integer): SequenceModel;
begin
  case aPair of
    cpGreek:
      if aVariant = 0 then Result := Win1253Model
      else Result := Latin7Model;
    cpCyrillic:
      if aVariant = 0 then Result := Win1251Model
      else Result := MacCyrillicModel;
  end;
end;

procedure TCharsetConfusion.Reset;
begin
  Self := Default(TCharsetConfusion);
end;

procedure TCharsetConfusion.ScorePosition(aByte: Byte;
  aHasBefore: Boolean; aBefore: Byte; aHasAfter: Boolean; aAfter: Byte);
var
  pair: TConfusionPair;
  variant: Integer;
  beforeCategory, afterCategory: Byte;
begin
  for pair := Low(TConfusionPair) to High(TConfusionPair) do
    if Differs(pair, aByte) then
      begin
        Inc(FDifferenceCount[pair]);
        for variant := 0 to 1 do
          begin
            beforeCategory := 0;
            afterCategory := 0;
            if aHasBefore then
              beforeCategory := CategoryOf(pair, variant, aBefore);
            if aHasAfter then
              afterCategory := CategoryOf(pair, variant, aAfter);
            Inc(FCategoryScore[pair, variant], CategoryVote(
              CategoryOf(pair, variant, aByte), beforeCategory,
              afterCategory));
          end;
      end;
end;

procedure TCharsetConfusion.ScoreBigram(aBefore, aAfter: Byte);
var
  pair: TConfusionPair;
  variant: Integer;
  model: SequenceModel;
  firstOrder, secondOrder, category: Byte;
begin
  for pair := Low(TConfusionPair) to High(TConfusionPair) do
    if Differs(pair, aBefore) or Differs(pair, aAfter) then
      for variant := 0 to 1 do
        begin
          model := ModelFor(pair, variant);
          firstOrder := Byte(model.charToOrderMap[aBefore]);
          secondOrder := Byte(model.charToOrderMap[aAfter]);
          if (firstOrder >= 64) or (secondOrder >= 64) then
            Continue;
          category := Byte(model.precedenceMatrix[firstOrder * 64 +
            secondOrder]);
          case category of
            0: Dec(FBigramScore[pair, variant], 2);
            2: Inc(FBigramScore[pair, variant]);
            3: Inc(FBigramScore[pair, variant], 2);
          end;
        end;
end;

procedure TCharsetConfusion.Feed(aByte: Byte);
begin
  if FFinished or (FCount >= EvidenceCap) then
    Exit;
  if FCount > 0 then
    begin
      ScorePosition(FPrevious, FCount > 1, FBeforePrevious,
        True, aByte);
      ScoreBigram(FPrevious, aByte);
    end;
  FBeforePrevious := FPrevious;
  FPrevious := aByte;
  Inc(FCount);
end;

procedure TCharsetConfusion.Finish;
begin
  if FFinished then
    Exit;
  if FCount > 0 then
    ScorePosition(FPrevious, FCount > 1, FBeforePrevious,
      False, 0);
  FFinished := True;
end;

function TCharsetConfusion.Decide(aPair: TConfusionPair):
  TConfusionDecision;
var
  categoryMargin, bigramMargin: LongInt;
begin
  Result := cdNoEvidence;
  if FDifferenceCount[aPair] = 0 then
    Exit;
  categoryMargin := FCategoryScore[aPair, 0] -
    FCategoryScore[aPair, 1];
  bigramMargin := FBigramScore[aPair, 0] -
    FBigramScore[aPair, 1];
  { A reading that breaks word shape outweighs the coarse sequence model.
    Without such a penalty, use only the pair-local sequence evidence. }
  if Abs(categoryMargin) >= 2 then
    begin
      if categoryMargin > 0 then Result := cdFirst
      else Result := cdSecond;
    end
  else if Abs(bigramMargin) >= 2 then
    begin
      if bigramMargin > 0 then Result := cdFirst
      else Result := cdSecond;
    end;
end;

end.
