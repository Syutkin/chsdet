unit CharsetUTF32;

{$mode ObjFPC}{$H+}

interface

uses
  nsCore;

type
  TUTF32Candidate = record
    Valid: Boolean;
    BMPUnits: QWord;
    Printable: QWord;
    Sampled: QWord;
  end;

  TCharsetUTF32Prober = class
  private
    FLE, FBE: TUTF32Candidate;
    FBytes: array[0..3] of Byte;
    FPending: Integer;
    FUnits: QWord;
    procedure FeedUnit;
  public
    constructor Create;
    procedure Reset;
    procedure Feed(aBuf: PAnsiChar; aLen: Integer);
    function Detect: eInternalCharsetID;
  end;

implementation

function IsPrintable(aCodePoint: LongWord): Boolean;
begin
  Result := (aCodePoint = $09) or (aCodePoint = $0A) or
    (aCodePoint = $0D) or (aCodePoint = $20) or
    ((aCodePoint >= $21) and (aCodePoint <= $10FFFF) and
     not ((aCodePoint >= $7F) and (aCodePoint <= $9F)) and
     not ((aCodePoint >= $200B) and (aCodePoint <= $200F)) and
     not ((aCodePoint >= $2028) and (aCodePoint <= $202E)) and
     not ((aCodePoint >= $2060) and (aCodePoint <= $206F)) and
     not ((aCodePoint >= $FFF9) and (aCodePoint <= $FFFF)) and
     not ((aCodePoint and $FFFE) = $FFFE));
end;

procedure FeedCodePoint(var aCandidate: TUTF32Candidate;
  aCodePoint: LongWord);
begin
  if not aCandidate.Valid then
    Exit;
  if (aCodePoint > $10FFFF) or
    ((aCodePoint >= $D800) and (aCodePoint <= $DFFF)) then
    begin
      aCandidate.Valid := False;
      Exit;
    end;
  if aCodePoint <= $FFFF then
    Inc(aCandidate.BMPUnits);
  if aCandidate.Sampled < 500 then
    begin
      Inc(aCandidate.Sampled);
      if IsPrintable(aCodePoint) then
        Inc(aCandidate.Printable);
    end;
end;

procedure TCharsetUTF32Prober.FeedUnit;
var
  codePoint: LongWord;
begin
  Inc(FUnits);
  { Positional zero tests mirror chardet's UTF-32 heuristic. Validate every
    scalar and the final byte count, even after the text sample is full. }
  if FLE.Valid then
    begin
      if FBytes[3] <> 0 then
        FLE.Valid := False
      else
        begin
          codePoint := LongWord(FBytes[0]) or
            (LongWord(FBytes[1]) shl 8) or
            (LongWord(FBytes[2]) shl 16);
          FeedCodePoint(FLE, codePoint);
        end;
    end;
  if FBE.Valid then
    begin
      if FBytes[0] <> 0 then
        FBE.Valid := False
      else
        begin
          codePoint := (LongWord(FBytes[1]) shl 16) or
            (LongWord(FBytes[2]) shl 8) or LongWord(FBytes[3]);
          FeedCodePoint(FBE, codePoint);
        end;
    end;
end;

constructor TCharsetUTF32Prober.Create;
begin
  inherited Create;
  Reset;
end;

procedure TCharsetUTF32Prober.Reset;
begin
  FillChar(FLE, SizeOf(FLE), 0);
  FillChar(FBE, SizeOf(FBE), 0);
  FLE.Valid := True;
  FBE.Valid := True;
  FPending := 0;
  FUnits := 0;
end;

procedure TCharsetUTF32Prober.Feed(aBuf: PAnsiChar; aLen: Integer);
var
  i: Integer;
begin
  for i := 0 to aLen - 1 do
    begin
      FBytes[FPending] := Byte(aBuf[i]);
      Inc(FPending);
      if FPending = 4 then
        begin
          FeedUnit;
          FPending := 0;
        end;
    end;
end;

function CandidateReady(const aCandidate: TUTF32Candidate;
  aUnits: QWord): Boolean;
begin
  Result := aCandidate.Valid and (aUnits >= 4) and
    (aCandidate.BMPUnits > aUnits div 2) and
    (aCandidate.Sampled > 0) and
    (aCandidate.Printable * 10 > aCandidate.Sampled * 7);
end;

function TCharsetUTF32Prober.Detect: eInternalCharsetID;
begin
  Result := UNKNOWN_CHARSET;
  if FPending <> 0 then
    Exit;
  if CandidateReady(FLE, FUnits) then
    Result := UTF32_LE_CHARSET
  else if CandidateReady(FBE, FUnits) then
    Result := UTF32_BE_CHARSET;
end;

end.
