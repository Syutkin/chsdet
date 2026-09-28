unit ExampleOutput;

{$mode ObjFPC}{$H+}

interface

uses
  CharsetDetector;

procedure PrintDetection(const aResult: TCharsetDetectionResult);

implementation

uses
  SysUtils, nsCore;

function StatusName(aStatus: TCharsetDetectionStatus): string;
begin
  case aStatus of
    dsDetected: Result := 'dsDetected';
    dsAmbiguous: Result := 'dsAmbiguous';
    dsInsufficientData: Result := 'dsInsufficientData';
    dsUnknown: Result := 'dsUnknown';
    dsExcludedByProfile: Result := 'dsExcludedByProfile';
  end;
end;

function SourceName(aSource: TCharsetDetectionSource): string;
begin
  case aSource of
    csNone: Result := 'csNone';
    csBOM: Result := 'csBOM';
    csASCII: Result := 'csASCII';
    csUTF8Validation: Result := 'csUTF8Validation';
    csUTF16Structure: Result := 'csUTF16Structure';
    csStatistics: Result := 'csStatistics';
    csConfusionResolution: Result := 'csConfusionResolution';
  end;
end;

function BOMName(aBOM: eBOMKind): string;
begin
  case aBOM of
    BOM_Not_Found: Result := 'BOM_Not_Found';
    BOM_UCS4_BE: Result := 'BOM_UCS4_BE';
    BOM_UCS4_LE: Result := 'BOM_UCS4_LE';
    BOM_UTF16_BE: Result := 'BOM_UTF16_BE';
    BOM_UTF16_LE: Result := 'BOM_UTF16_LE';
    BOM_UTF8: Result := 'BOM_UTF8';
  end;
end;

procedure PrintDetection(const aResult: TCharsetDetectionResult);
var
  i: Integer;
begin
  WriteLn('Status: ', StatusName(aResult.Status));
  if aResult.Charset = '' then
    WriteLn('Charset: <none>')
  else
    WriteLn('Charset: ', aResult.Charset);
  WriteLn('Code page: ', aResult.CodePage);
  WriteLn('BOM: ', BOMName(aResult.BOM), ' (', aResult.BOMSize, ' bytes)');
  WriteLn('Source: ', SourceName(aResult.Source));
  if aResult.HasConfidence then
    WriteLn('Confidence: ', aResult.Confidence:0:6)
  else
    WriteLn('Confidence: n/a');
  WriteLn('Bytes seen: ', aResult.BytesSeen);
  for i := 0 to High(aResult.Candidates) do
    WriteLn('Candidate: ', aResult.Candidates[i].Charset, ' score=',
      aResult.Candidates[i].Confidence:0:6, ' source=',
      SourceName(aResult.Candidates[i].Source));
  case aResult.Status of
    dsAmbiguous:
      WriteLn('Candidates are ambiguous; use external context before decoding.');
    dsInsufficientData, dsUnknown:
      WriteLn('No reliable choice; provide more data or external context.');
    dsExcludedByProfile:
      WriteLn('Encoding is outside the profile; revise it or reject the input.');
  end;
end;

end.
