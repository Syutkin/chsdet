unit CharsetUTF16;

{$mode ObjFPC}{$H+}

interface

uses
  nsCore;

type
  TUTF16Candidate = record
    Valid: Boolean;
    PendingHighSurrogate: Boolean;
    Units: SizeInt;
    StrongText: SizeInt;
    Score: SizeInt;
  end;

  TCharsetUTF16Prober = class
  private
    FLE, FBE: TUTF16Candidate;
    FPendingByte: Boolean;
    FFirstByte: Byte;
  public
    constructor Create;
    procedure Reset;
    procedure Feed(aBuf: PAnsiChar; aLen: Integer);
    function Detect: eInternalCharsetID;
  end;

implementation

procedure FeedUnit(var aCandidate: TUTF16Candidate; aUnit: Word);
begin
  if not aCandidate.Valid then
    Exit;
  Inc(aCandidate.Units);

  if aCandidate.PendingHighSurrogate then
    begin
      aCandidate.PendingHighSurrogate := False;
      if (aUnit < $DC00) or (aUnit > $DFFF) then
        aCandidate.Valid := False
      else
        Inc(aCandidate.Score);
      Exit;
    end;
  if (aUnit >= $D800) and (aUnit <= $DBFF) then
    begin
      aCandidate.PendingHighSurrogate := True;
      Exit;
    end;
  if (aUnit >= $DC00) and (aUnit <= $DFFF) then
    begin
      aCandidate.Valid := False;
      Exit;
    end;

  if (aUnit = $09) or (aUnit = $0A) or (aUnit = $0D) or
    ((aUnit >= $20) and (aUnit <= $7E)) then
    begin
      Inc(aCandidate.StrongText);
      Inc(aCandidate.Score, 4);
    end
  else if (aUnit < $20) or ((aUnit >= $7F) and (aUnit < $A0)) or
    (aUnit = $FFFE) or (aUnit = $FFFF) then
    aCandidate.Valid := False
  else if ((aUnit >= $A0) and (aUnit <= $024F)) or
    ((aUnit >= $0370) and (aUnit <= $052F)) or
    ((aUnit >= $0590) and (aUnit <= $08FF)) then
    begin
      Inc(aCandidate.StrongText);
      Inc(aCandidate.Score, 3);
    end
  else
    Inc(aCandidate.Score);
end;

function CandidateScore(const aCandidate: TUTF16Candidate;
  aPendingByte: Boolean): SizeInt;
begin
  Result := -1;
  if aPendingByte or not aCandidate.Valid or
    aCandidate.PendingHighSurrogate or (aCandidate.Units < 8) or
    (aCandidate.StrongText < 4) or
    (aCandidate.Score < aCandidate.Units * 2) then
    Exit;
  Result := aCandidate.Score;
end;

constructor TCharsetUTF16Prober.Create;
begin
  inherited Create;
  Reset;
end;

procedure TCharsetUTF16Prober.Reset;
begin
  FillChar(FLE, SizeOf(FLE), 0);
  FillChar(FBE, SizeOf(FBE), 0);
  FLE.Valid := True;
  FBE.Valid := True;
  FPendingByte := False;
  FFirstByte := 0;
end;

procedure TCharsetUTF16Prober.Feed(aBuf: PAnsiChar; aLen: Integer);
var
  i: Integer;
  value: Byte;
begin
  for i := 0 to aLen - 1 do
    begin
      value := Byte(aBuf[i]);
      if not FPendingByte then
        begin
          FFirstByte := value;
          FPendingByte := True;
        end
      else
        begin
          FeedUnit(FLE, Word(FFirstByte) or (Word(value) shl 8));
          FeedUnit(FBE, (Word(FFirstByte) shl 8) or Word(value));
          FPendingByte := False;
        end;
    end;
end;

function TCharsetUTF16Prober.Detect: eInternalCharsetID;
var
  leScore, beScore, gap: SizeInt;
begin
  Result := UNKNOWN_CHARSET;
  leScore := CandidateScore(FLE, FPendingByte);
  beScore := CandidateScore(FBE, FPendingByte);
  gap := 12;
  if FLE.Units div 2 > gap then
    gap := FLE.Units div 2;
  if (leScore >= 0) and (leScore - beScore >= gap) then
    Result := UTF16_LE_CHARSET
  else if (beScore >= 0) and (beScore - leScore >= gap) then
    Result := UTF16_BE_CHARSET;
end;

end.
