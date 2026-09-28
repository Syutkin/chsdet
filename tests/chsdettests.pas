unit ChsDetTests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, TypInfo, fpcunit, testregistry, nsCore, nsUniversalDetector;

type
  TChsDetFixtureTest = class(TTestCase)
  private
    FExpectedBom: eBOMKind;
    FExpectedCharset: string;
    FFileName: string;
    function DetectFixture(out ADetectedBom: eBOMKind): string;
    function FixturePath: string;
    procedure ReportFixture(const AInfo: rCharsetInfo; const ABom: eBOMKind;
      const ADone: Boolean; const AAbout: rAboutHolder);
  protected
    procedure RunTest; override;
  public
    constructor Create(const AFileName, AExpectedCharset: string;
      const AExpectedBom: eBOMKind = BOM_Not_Found); reintroduce;
  end;

var
  FixtureReportPath: string;

constructor TChsDetFixtureTest.Create(const AFileName,
  AExpectedCharset: string; const AExpectedBom: eBOMKind);
begin
  inherited CreateWithName('Detect_' + AFileName);
  FFileName := AFileName;
  FExpectedCharset := AExpectedCharset;
  FExpectedBom := AExpectedBom;
end;

procedure TChsDetFixtureTest.ReportFixture(const AInfo: rCharsetInfo;
  const ABom: eBOMKind; const ADone: Boolean; const AAbout: rAboutHolder);
var
  reportFile: TextFile;
  outcome: string;
begin
  if FixtureReportPath = '' then
    Exit;
  outcome := 'FAIL';
  if SameText(FExpectedCharset, AInfo.Name) and (ABom = FExpectedBom) then
    outcome := 'PASS';
  AssignFile(reportFile, FixtureReportPath);
  Append(reportFile);
  try
    WriteLn(reportFile, FFileName, #9, FExpectedCharset, #9, AInfo.Name,
      #9, AInfo.CodePage, #9, GetEnumName(TypeInfo(eBOMKind), Ord(FExpectedBom)),
      #9, GetEnumName(TypeInfo(eBOMKind), Ord(ABom)), #9, BoolToStr(ADone, True),
      #9, AAbout.MajorVersionNr, '.', AAbout.MinorVersionNr, '.',
      AAbout.BuildVersionNr, #9, 'unavailable', #9, outcome);
  finally
    CloseFile(reportFile);
  end;
end;

function TChsDetFixtureTest.FixturePath: string;
begin
  Result := ExpandFileName(ExtractFileDir(ParamStr(0)) +
    DirectorySeparator + '..' + DirectorySeparator + 'fixtures' +
    DirectorySeparator + 'encodings' + DirectorySeparator + FFileName);
end;

function TChsDetFixtureTest.DetectFixture(
  out ADetectedBom: eBOMKind): string;
var
  content: rawbytestring;
  detector: TnsUniversalDetector;
  fixtureFile: string;
  fixtureStream: TFileStream;
  info: rCharsetInfo;
  about: rAboutHolder;
begin
  fixtureFile := FixturePath;
  AssertTrue('Missing fixture: ' + fixtureFile, FileExists(fixtureFile));

  content := '';
  fixtureStream := TFileStream.Create(fixtureFile,
    fmOpenRead or fmShareDenyWrite);
  try
    SetLength(content, fixtureStream.Size);
    if content <> '' then
      fixtureStream.ReadBuffer(content[1], Length(content));
  finally
    fixtureStream.Free;
  end;

  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(PAnsiChar(content), Length(content));
    if not detector.Done then
      detector.DataEnd;
    info := detector.GetDetectedCharsetInfo;
    Result := info.Name;
    ADetectedBom := detector.BOMDetected;
    detector.GetAbout(about);
    ReportFixture(info, ADetectedBom, detector.Done, about);
  finally
    detector.Free;
  end;
end;

procedure TChsDetFixtureTest.RunTest;
var
  detectedBom: eBOMKind;
  detectedCharset: string;
begin
  detectedCharset := DetectFixture(detectedBom);
  AssertEquals(FFileName + ': unexpected charset',
    LowerCase(FExpectedCharset), LowerCase(detectedCharset));
  AssertEquals(FFileName + ': unexpected BOM', Ord(FExpectedBom),
    Ord(detectedBom));
end;

procedure AddFixture(ASuite: TTestSuite; const AFileName,
  AExpectedCharset: string;
  const AExpectedBom: eBOMKind = BOM_Not_Found);
begin
  ASuite.AddTest(TChsDetFixtureTest.Create(AFileName, AExpectedCharset,
    AExpectedBom));
end;

procedure AddTextVariants(ASuite: TTestSuite; const AStem,
  AExpectedCharset: string);
begin
  AddFixture(ASuite, AStem + '-lf.txt', AExpectedCharset,
    BOM_Not_Found);
  AddFixture(ASuite, AStem + '-crlf.txt', AExpectedCharset,
    BOM_Not_Found);
  AddFixture(ASuite, AStem + '-long-lf.txt', AExpectedCharset,
    BOM_Not_Found);
  AddFixture(ASuite, AStem + '-long-crlf.txt', AExpectedCharset,
    BOM_Not_Found);
end;

procedure AddBomVariants(ASuite: TTestSuite; const AStem,
  AExpectedCharset: string; const AExpectedBom: eBOMKind);
begin
  AddFixture(ASuite, AStem + '-bom-lf.txt', AExpectedCharset,
    AExpectedBom);
  AddFixture(ASuite, AStem + '-bom-crlf.txt', AExpectedCharset,
    AExpectedBom);
  AddFixture(ASuite, AStem + '-bom-long-lf.txt', AExpectedCharset,
    AExpectedBom);
  AddFixture(ASuite, AStem + '-bom-long-crlf.txt', AExpectedCharset,
    AExpectedBom);
end;

procedure AddUtfVariants(ASuite: TTestSuite; const ALanguage: string);
var
  suffix: string;
begin
  suffix := '-' + ALanguage;

  AddTextVariants(ASuite, 'utf-8' + suffix, 'UTF-8');
  AddBomVariants(ASuite, 'utf-8' + suffix, 'UTF-8', BOM_UTF8);
  AddTextVariants(ASuite, 'utf-16le' + suffix, 'UTF-16LE');
  AddBomVariants(ASuite, 'utf-16le' + suffix, 'UTF-16LE', BOM_UTF16_LE);
  AddTextVariants(ASuite, 'utf-16be' + suffix, 'UTF-16BE');
  AddBomVariants(ASuite, 'utf-16be' + suffix, 'UTF-16BE', BOM_UTF16_BE);
end;

function CreateChsDetTestSuite: TTestSuite;
begin
  Result := TTestSuite.Create('TChsDetTests');

  AddTextVariants(Result, 'ascii', 'ASCII');
  AddTextVariants(Result, 'windows-1251', 'windows-1251');
  AddTextVariants(Result, 'windows-1252', 'windows-1252');
  AddTextVariants(Result, 'windows-1253', 'windows-1253');
  AddTextVariants(Result, 'windows-1255', 'windows-1255');
  AddTextVariants(Result, 'koi8-r', 'KOI8-R');
  AddTextVariants(Result, 'iso-8859-5', 'ISO-8859-5');
  AddTextVariants(Result, 'iso-8859-7', 'ISO-8859-7');
  // Byte DF distinguishes ISO-8859-8 from Windows-1255 in these fixtures.
  AddTextVariants(Result, 'iso-8859-8', 'ISO-8859-8');
  AddTextVariants(Result, 'ibm866', 'IBM866');

  AddUtfVariants(Result, 'ru');
  AddUtfVariants(Result, 'en');
  AddUtfVariants(Result, 'fr');
  AddUtfVariants(Result, 'el');
  AddUtfVariants(Result, 'he');
end;

procedure InitializeFixtureReport;
var
  reportFile: TextFile;
begin
  FixtureReportPath := GetEnvironmentVariable('CHSDET_FIXTURE_REPORT');
  if FixtureReportPath = '' then
    Exit;
  AssignFile(reportFile, FixtureReportPath);
  Rewrite(reportFile);
  try
    WriteLn(reportFile, 'fixture', #9, 'expected_charset', #9, 'actual_charset',
      #9, 'code_page', #9, 'expected_bom', #9, 'actual_bom', #9, 'done',
      #9, 'version', #9, 'confidence', #9, 'result');
  finally
    CloseFile(reportFile);
  end;
end;

initialization
  InitializeFixtureReport;
  RegisterTest('', CreateChsDetTestSuite);

end.
