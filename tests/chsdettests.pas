unit ChsDetTests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpcunit, testregistry, nsCore, nsUniversalDetector;

type
  TChsDetFixtureTest = class(TTestCase)
  private
    FExpectedBom: eBOMKind;
    FExpectedCharset: string;
    FFileName: string;
    function DetectFixture(out ADetectedBom: eBOMKind): string;
    function FixturePath: string;
  protected
    procedure RunTest; override;
  public
    constructor Create(const AFileName, AExpectedCharset: string;
      const AExpectedBom: eBOMKind = BOM_Not_Found); reintroduce;
  end;

constructor TChsDetFixtureTest.Create(const AFileName,
  AExpectedCharset: string; const AExpectedBom: eBOMKind);
begin
  inherited CreateWithName('Detect_' + AFileName);
  FFileName := AFileName;
  FExpectedCharset := AExpectedCharset;
  FExpectedBom := AExpectedBom;
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
  AddFixture(ASuite, AStem + '-lf.txt', AExpectedCharset);
  AddFixture(ASuite, AStem + '-crlf.txt', AExpectedCharset);
  AddFixture(ASuite, AStem + '-long-lf.txt', AExpectedCharset);
  AddFixture(ASuite, AStem + '-long-crlf.txt', AExpectedCharset);
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
  AddTextVariants(Result, 'iso-8859-8', 'ISO-8859-8');
  AddTextVariants(Result, 'ibm866', 'IBM866');

  AddUtfVariants(Result, 'ru');
  AddUtfVariants(Result, 'en');
  AddUtfVariants(Result, 'fr');
  AddUtfVariants(Result, 'el');
  AddUtfVariants(Result, 'he');
end;

initialization
  RegisterTest('', CreateChsDetTestSuite);

end.
