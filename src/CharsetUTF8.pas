unit CharsetUTF8;

{$mode ObjFPC}{$H+}

interface

type
  TCharsetUTF8Validator = class
  private
    FValid: Boolean;
    FASCII: Boolean;
    FHasNUL: Boolean;
    FRemaining: Byte;
    FNextMin: Byte;
    FNextMax: Byte;
    FMultibyteCount: SizeInt;
  public
    constructor Create;
    procedure Reset;
    procedure Feed(aBuf: PAnsiChar; aLen: Integer);
    function Finish: Boolean;
    property IsASCII: Boolean read FASCII;
    property HasNUL: Boolean read FHasNUL;
    property MultibyteCount: SizeInt read FMultibyteCount;
  end;

implementation

constructor TCharsetUTF8Validator.Create;
begin
  inherited Create;
  Reset;
end;

procedure TCharsetUTF8Validator.Reset;
begin
  FValid := True;
  FASCII := True;
  FHasNUL := False;
  FRemaining := 0;
  FNextMin := $80;
  FNextMax := $BF;
  FMultibyteCount := 0;
end;

procedure TCharsetUTF8Validator.Feed(aBuf: PAnsiChar; aLen: Integer);
var
  i: Integer;
  value: Byte;
begin
  for i := 0 to aLen - 1 do
    begin
      value := Byte(aBuf[i]);
      if value >= $80 then
        FASCII := False;
      if value = 0 then
        FHasNUL := True;
      if not FValid then
        Continue;

      if FRemaining <> 0 then
        begin
          if (value < FNextMin) or (value > FNextMax) then
            begin
              FValid := False;
              Continue;
            end;
          Dec(FRemaining);
          FNextMin := $80;
          FNextMax := $BF;
          if FRemaining = 0 then
            Inc(FMultibyteCount);
        end
      else if value < $80 then
        Continue
      else if (value >= $C2) and (value <= $DF) then
        FRemaining := 1
      else if value = $E0 then
        begin
          FRemaining := 2;
          FNextMin := $A0;
        end
      else if (value >= $E1) and (value <= $EC) then
        FRemaining := 2
      else if value = $ED then
        begin
          FRemaining := 2;
          FNextMax := $9F;
        end
      else if (value >= $EE) and (value <= $EF) then
        FRemaining := 2
      else if value = $F0 then
        begin
          FRemaining := 3;
          FNextMin := $90;
        end
      else if (value >= $F1) and (value <= $F3) then
        FRemaining := 3
      else if value = $F4 then
        begin
          FRemaining := 3;
          FNextMax := $8F;
        end
      else
        FValid := False;
    end;
end;

function TCharsetUTF8Validator.Finish: Boolean;
begin
  Result := FValid and (FRemaining = 0);
end;

end.
