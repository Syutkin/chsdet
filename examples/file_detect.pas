program file_detect;

{$mode ObjFPC}{$H+}

uses
  Classes, SysUtils, CharsetDetector, ExampleOutput;

procedure DetectFile(aStream: TStream; aDetector: TCharsetDetector);
var
  buffer: array[0..4095] of Byte;
  count: LongInt;
begin
  aStream.Position := 0;
  repeat
    count := aStream.Read(buffer, SizeOf(buffer));
    if count > 0 then
      aDetector.Feed(@buffer[0], count);
  until count = 0;
  PrintDetection(aDetector.Finish);
end;

var
  stream: TFileStream;
  detector: TCharsetDetector;
  allowed: array of string;
  i: Integer;
begin
  try
    if ParamCount < 1 then
      raise EArgumentException.Create(
        'Usage: file_detect <path> [allowed-charset ...]');
    SetLength(allowed, ParamCount - 1);
    for i := 2 to ParamCount do
      allowed[i - 2] := ParamStr(i);
    stream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      detector := TCharsetDetector.Create;
      try
        if ParamCount > 1 then
          detector.SetAllowedCharsets(allowed);
        WriteLn('Pass 1:');
        DetectFile(stream, detector);
        detector.Reset; { The selected profile remains in effect. }
        WriteLn('Pass 2 after Reset:');
        DetectFile(stream, detector);
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
