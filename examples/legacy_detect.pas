program legacy_detect;

{$mode ObjFPC}{$H+}

uses
  Classes, SysUtils, nsCore, nsUniversalDetector;

var
  stream: TFileStream;
  detector: TnsUniversalDetector;
  buffer: array[0..4095] of AnsiChar;
  count: LongInt;
  info: rCharsetInfo;
begin
  try
    if ParamCount <> 1 then
      raise EArgumentException.Create('Usage: legacy_detect <path>');
    stream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      detector := TnsUniversalDetector.Create;
      try
        detector.Reset;
        repeat
          count := stream.Read(buffer, SizeOf(buffer));
          if count > 0 then
            detector.HandleData(@buffer[0], count);
        until count = 0;
        if not detector.Done then
          detector.DataEnd;
        info := detector.GetDetectedCharsetInfo;
        WriteLn('Charset: ', info.Name);
        WriteLn('Code page: ', info.CodePage);
      finally
        detector.Free;
      end;
    finally
      stream.Free;
    end;
  except
    on E: Exception do
      begin
        WriteLn(StdErr, E.Message);
        ExitCode := 2;
      end;
  end;
end.
