unit CharsetBOM;

interface

uses
  nsCore;

{ Returns False while the bytes can still begin a longer BOM. At EOF, the
  longest complete matching BOM wins; incomplete prefixes are not BOMs. }
function ResolveCharsetBOM(aBuf: PAnsiChar; aLen: integer; aAtEnd: Boolean;
  out aBOM: eBOMKind): Boolean;

implementation

function ResolveCharsetBOM(aBuf: PAnsiChar; aLen: integer; aAtEnd: Boolean;
  out aBOM: eBOMKind): Boolean;
var
  bom, bestBOM: eBOMKind;
  i, prefixLength: integer;
  same, hasLongerPrefix: Boolean;
begin
  bestBOM := BOM_Not_Found;
  hasLongerPrefix := False;
  for bom := Succ(BOM_Not_Found) to High(eBOMKind) do
    begin
      prefixLength := aLen;
      if prefixLength > KNOWN_BOM[bom].Length then
        prefixLength := KNOWN_BOM[bom].Length;
      same := True;
      for i := 0 to prefixLength - 1 do
        if aBuf[i] <> KNOWN_BOM[bom].BOM[i] then
          begin
            same := False;
            Break;
          end;
      if not same then
        Continue;
      if KNOWN_BOM[bom].Length > aLen then
        hasLongerPrefix := True
      else if KNOWN_BOM[bom].Length > KNOWN_BOM[bestBOM].Length then
        bestBOM := bom;
    end;

  Result := aAtEnd or not hasLongerPrefix;
  aBOM := BOM_Not_Found;
  if Result then
    aBOM := bestBOM;
end;

end.
