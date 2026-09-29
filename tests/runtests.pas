program ChsDetTestsRunner;

{$mode ObjFPC}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  consoletestrunner,
  ChsDetTests, BOMTests, ProberStateTests, UTF8Tests, UTF16Tests,
  UTF32Tests, APITests;

var
  App: TTestRunner;
begin
  DefaultRunAllTests := True;
  App := TTestRunner.Create(nil);
  App.Initialize;
  App.Run;
  App.Free;
end.
