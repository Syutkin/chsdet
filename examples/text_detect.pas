program text_detect;

{$mode ObjFPC}{$H+}

uses
  SysUtils, CharsetDetector, ExampleOutput;

function Sample(const aName: string): RawByteString;
begin
  if aName = 'empty' then
    Result := ''
  else if aName = 'ascii' then
    Result := 'Plain ASCII text.'
  else if aName = 'utf8' then
    Result := 'caf' + #$C3#$A9 + ' r' + #$C3#$A9
  else if aName = 'short' then
    Result := #$80
  else if aName = 'unknown' then
    Result := #0#$01#$02#$03#$04
  else if aName = 'ambiguous' then
    { Hebrew letters shared by ISO-8859-8 and Windows-1255. }
    Result := #$E3#$E2' '#$F1#$F7#$F8#$EF' '#$F9#$E8' '#$E1#$E9#$ED' '+
      #$EE#$E0#$E5#$EB#$E6#$E1' '#$E5#$EC#$F4#$FA#$F2' '#$EE#$F6#$E0' '+
      #$EC#$E5' '#$E7#$E1#$F8#$E4'.'#10
  else
    raise EArgumentException.Create('Unknown sample: ' + aName);
end;

var
  data: RawByteString;
begin
  try
    if ParamCount <> 1 then
      raise EArgumentException.Create(
        'Usage: text_detect empty|ascii|utf8|short|unknown|ambiguous');
    data := Sample(ParamStr(1));
    PrintDetection(DetectCharset(data));
  except
    on E: Exception do
      begin
        WriteLn(StdErr, E.Message);
        ExitCode := 2;
      end;
  end;
end.
