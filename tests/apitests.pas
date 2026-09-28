unit APITests;

{$mode ObjFPC}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpcunit, testregistry, nsCore, nsUniversalDetector,
  CharsetDetector, CharsetByteValidity;

type
  TAPITests = class(TTestCase)
  private
    function ReadFixture(const aName: string): RawByteString;
    function FindCandidate(const aResult: TCharsetDetectionResult;
      const aName: string): Integer;
    procedure CheckEqual(const aExpected, aActual: TCharsetDetectionResult;
      const aContext: string);
  published
    procedure UnicodeSourcesAndEmptyInput;
    procedure WeakAndShortStatisticalGuesses;
    procedure StreamingEqualsOneShot;
    procedure FixtureCorpusStreamingEquivalence;
    procedure CrossesInternalBlocks;
    procedure UniqueSortedCandidatesAndHebrewAmbiguity;
    procedure SingleByteValidity;
    procedure InvalidHebrewCandidatesAreExcluded;
    procedure HebrewWithCombiningMarks;
    procedure HZAcrossChunksAndPlainASCII;
    procedure ConfusionResolutionUsesDistinguishingBytes;
    procedure FinishResetAndInvalidFeed;
    procedure ExistingDetectorRemainsUsable;
  end;

function TAPITests.ReadFixture(const aName: string): RawByteString;
var
  stream: TFileStream;
  path: string;
begin
  path := ExpandFileName(ExtractFileDir(ParamStr(0)) +
    '/../fixtures/encodings/' + aName);
  Result := '';
  stream := TFileStream.Create(path, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, stream.Size);
    if Length(Result) > 0 then
      stream.ReadBuffer(Result[1], Length(Result));
  finally
    stream.Free;
  end;
end;

procedure TAPITests.SingleByteValidity;
var
  seen: TCharsetSeenBytes;
begin
  seen := [$DF];
  AssertTrue(SingleByteCharsetCanDecode(ISO_8859_8_CHARSET, seen));
  AssertFalse(SingleByteCharsetCanDecode(WINDOWS_1255_CHARSET, seen));

  seen := [$C8];
  AssertFalse(SingleByteCharsetCanDecode(ISO_8859_8_CHARSET, seen));
  AssertTrue(SingleByteCharsetCanDecode(WINDOWS_1255_CHARSET, seen));

  seen := [$A2];
  AssertTrue(SingleByteCharsetCanDecode(ISO_8859_7_CHARSET, seen));
  AssertTrue(SingleByteCharsetCanDecode(WINDOWS_1253_CHARSET, seen));

  seen := [$AE];
  AssertFalse(SingleByteCharsetCanDecode(ISO_8859_7_CHARSET, seen));
  AssertTrue(SingleByteCharsetCanDecode(WINDOWS_1253_CHARSET, seen));

  seen := [$AA];
  AssertTrue(SingleByteCharsetCanDecode(ISO_8859_7_CHARSET, seen));
  AssertFalse(SingleByteCharsetCanDecode(WINDOWS_1253_CHARSET, seen));

  seen := [$98];
  AssertFalse(SingleByteCharsetCanDecode(WINDOWS_1251_CHARSET, seen));
  AssertFalse(SingleByteCharsetCanDecode(WINDOWS_BULGARIAN_CHARSET, seen));
  AssertTrue(SingleByteCharsetCanDecode(X_MAC_CYRILLIC_CHARSET, seen));

  seen := [$81];
  AssertFalse(SingleByteCharsetCanDecode(WINDOWS_1252_CHARSET, seen));
  AssertTrue(SingleByteCharsetCanDecode(KOI8_R_CHARSET, seen));
end;

procedure TAPITests.InvalidHebrewCandidatesAreExcluded;
var
  detected: TCharsetDetectionResult;
begin
  detected := DetectCharset(ReadFixture('iso-8859-8-lf.txt'));
  AssertTrue(FindCandidate(detected, 'ISO-8859-8') >= 0);
  AssertEquals(-1, FindCandidate(detected, 'windows-1255'));

  detected := DetectCharset(ReadFixture('windows-1255-lf.txt'));
  AssertTrue(FindCandidate(detected, 'windows-1255') >= 0);
  AssertEquals(-1, FindCandidate(detected, 'ISO-8859-8'));

  detected := DetectCharset(ReadFixture('iso-8859-8-shared-lf.txt'));
  AssertEquals(Ord(dsAmbiguous), Ord(detected.Status));
  AssertTrue(FindCandidate(detected, 'ISO-8859-8') >= 0);
  AssertTrue(FindCandidate(detected, 'windows-1255') >= 0);
end;

procedure TAPITests.HebrewWithCombiningMarks;
const
  Names: array[0..3] of string = (
    'windows-1255-lf.txt', 'windows-1255-crlf.txt',
    'windows-1255-long-lf.txt', 'windows-1255-long-crlf.txt');
var
  detected: TCharsetDetectionResult;
  name: string;
begin
  for name in Names do
    begin
      detected := DetectCharset(ReadFixture(name));
      AssertEquals(name + ' status', Ord(dsDetected), Ord(detected.Status));
      AssertEquals(name + ' charset', 'windows-1255', detected.Charset);
      AssertTrue(name + ' confidence', detected.Confidence >= 0.20);
      AssertEquals(name + ' ISO candidate', -1,
        FindCandidate(detected, 'ISO-8859-8'));
    end;
end;

procedure TAPITests.HZAcrossChunksAndPlainASCII;
var
  legacy: TnsUniversalDetector;
  detector: TCharsetDetector;
  data, plain: RawByteString;
  expected, actual: TCharsetDetectionResult;
  i: Integer;
begin
  data := '~{5<So~}';
  plain := 'plain ~{ literal braces and symbols } text';
  legacy := TnsUniversalDetector.Create;
  detector := TCharsetDetector.Create;
  try
    for i := 0 to 1 do
      begin
        legacy.Reset;
        if i = 0 then
          legacy.HandleData(PAnsiChar(data), Length(data))
        else
          begin
            legacy.HandleData(@data[1], 1);
            legacy.HandleData(@data[2], Length(data) - 1);
          end;
        legacy.DataEnd;
        AssertEquals('HZ across call boundary', 'HZ-GB-2312',
          String(legacy.GetDetectedCharsetInfo.Name));
      end;

    expected := DetectCharset(data);
    AssertEquals(Ord(dsDetected), Ord(expected.Status));
    AssertEquals('HZ-GB-2312', expected.Charset);
    for i := 1 to Length(data) do
      detector.Feed(@data[i], 1);
    actual := detector.Finish;
    CheckEqual(expected, actual, 'HZ bytewise feed');

    legacy.Reset;
    legacy.HandleData(PAnsiChar(plain), Length(plain));
    legacy.DataEnd;
    AssertEquals('plain text with tilde and brace', 'ASCII',
      String(legacy.GetDetectedCharsetInfo.Name));
    AssertEquals('ASCII', DetectCharset(plain).Charset);
  finally
    detector.Free;
    legacy.Free;
  end;
end;

procedure TAPITests.ConfusionResolutionUsesDistinguishingBytes;
var
  detected: TCharsetDetectionResult;
  candidateIndex: Integer;
begin
  detected := DetectCharset(ReadFixture('windows-1251-lf.txt'));
  AssertEquals(Ord(dsDetected), Ord(detected.Status));
  AssertEquals('windows-1251', detected.Charset);
  AssertEquals(Ord(csConfusionResolution), Ord(detected.Source));
  candidateIndex := FindCandidate(detected, detected.Charset);
  AssertTrue(candidateIndex >= 0);
  AssertTrue('raw model leader can differ from contextual choice',
    candidateIndex > 0);
  AssertTrue(Abs(detected.Confidence -
    detected.Candidates[candidateIndex].Confidence) < 1e-12);

  detected := DetectCharset(ReadFixture('windows-1253-lf.txt'));
  AssertEquals(Ord(dsDetected), Ord(detected.Status));
  AssertEquals('windows-1253', detected.Charset);
  AssertEquals(Ord(csConfusionResolution), Ord(detected.Source));
  AssertTrue(FindCandidate(detected, 'ISO-8859-7') >= 0);

  detected := DetectCharset(ReadFixture('iso-8859-7-lf.txt'));
  AssertEquals(Ord(dsAmbiguous), Ord(detected.Status));
  AssertEquals(Ord(csStatistics), Ord(detected.Source));
  AssertTrue(FindCandidate(detected, 'windows-1253') >= 0);
end;

function TAPITests.FindCandidate(const aResult: TCharsetDetectionResult;
  const aName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to High(aResult.Candidates) do
    if SameText(aResult.Candidates[i].Charset, aName) then
      Exit(i);
  Result := -1;
end;

procedure TAPITests.CheckEqual(const aExpected, aActual:
  TCharsetDetectionResult; const aContext: string);
var
  i: Integer;
begin
  AssertEquals(aContext + ' status', Ord(aExpected.Status), Ord(aActual.Status));
  AssertEquals(aContext + ' charset', aExpected.Charset, aActual.Charset);
  AssertEquals(aContext + ' code page', aExpected.CodePage, aActual.CodePage);
  AssertEquals(aContext + ' source', Ord(aExpected.Source), Ord(aActual.Source));
  AssertEquals(aContext + ' BOM', Ord(aExpected.BOM), Ord(aActual.BOM));
  AssertEquals(aContext + ' BOM size', aExpected.BOMSize, aActual.BOMSize);
  AssertEquals(aContext + ' bytes', Int64(aExpected.BytesSeen),
    Int64(aActual.BytesSeen));
  AssertEquals(aContext + ' final', aExpected.IsFinal, aActual.IsFinal);
  AssertEquals(aContext + ' confidence flag', aExpected.HasConfidence,
    aActual.HasConfidence);
  AssertTrue(aContext + ' confidence',
    Abs(aExpected.Confidence - aActual.Confidence) < 1e-12);
  AssertEquals(aContext + ' candidate count', Length(aExpected.Candidates),
    Length(aActual.Candidates));
  for i := 0 to High(aExpected.Candidates) do
    begin
      AssertEquals(aContext + ' candidate name',
        aExpected.Candidates[i].Charset, aActual.Candidates[i].Charset);
      AssertEquals(aContext + ' candidate code page',
        aExpected.Candidates[i].CodePage, aActual.Candidates[i].CodePage);
      AssertEquals(aContext + ' candidate source',
        Ord(aExpected.Candidates[i].Source),
        Ord(aActual.Candidates[i].Source));
      AssertEquals(aContext + ' candidate language',
        aExpected.Candidates[i].Language, aActual.Candidates[i].Language);
      AssertEquals(aContext + ' candidate confidence flag',
        aExpected.Candidates[i].HasConfidence,
        aActual.Candidates[i].HasConfidence);
      AssertTrue(aContext + ' candidate confidence',
        Abs(aExpected.Candidates[i].Confidence -
            aActual.Candidates[i].Confidence) < 1e-12);
    end;
end;

procedure TAPITests.FixtureCorpusStreamingEquivalence;
const
  ChunkSizes: array[0..2] of Integer = (1, 7, 513);
var
  search: TSearchRec;
  directory: string;
  data: RawByteString;
  expected: TCharsetDetectionResult;
  detector: TCharsetDetector;
  i, position, take, tested: Integer;
begin
  directory := ExpandFileName(ExtractFileDir(ParamStr(0)) +
    '/../fixtures/encodings');
  tested := 0;
  detector := TCharsetDetector.Create;
  try
    if FindFirst(directory + '/*.txt', faAnyFile, search) <> 0 then
      Fail('No encoding fixtures found');
    try
      repeat
        if (search.Attr and faDirectory) <> 0 then
          Continue;
        data := ReadFixture(search.Name);
        expected := DetectCharset(data);
        for i := Low(ChunkSizes) to High(ChunkSizes) do
          begin
            detector.Reset;
            position := 0;
            while position < Length(data) do
              begin
                take := ChunkSizes[i];
                if take > Length(data) - position then
                  take := Length(data) - position;
                detector.Feed(PByte(Pointer(data)) + position, take);
                Inc(position, take);
              end;
            CheckEqual(expected, detector.Finish,
              search.Name + ' blocks of ' + IntToStr(ChunkSizes[i]));
          end;
        Inc(tested);
      until FindNext(search) <> 0;
    finally
      FindClose(search);
    end;
  finally
    detector.Free;
  end;
  AssertTrue('expected the complete fixture corpus', tested >= 164);
end;

procedure TAPITests.CrossesInternalBlocks;
var
  data, sample: RawByteString;
  expected: TCharsetDetectionResult;
  detector: TCharsetDetector;
  i: Integer;
begin
  sample := ReadFixture('windows-1251-lf.txt');
  data := '';
  for i := 1 to 40 do
    data := data + sample;
  AssertTrue('test input must cross several internal blocks', Length(data) > 2048);
  expected := DetectCharset(data);
  detector := TCharsetDetector.Create;
  try
    for i := 1 to Length(data) do
      detector.Feed(@data[i], 1);
    CheckEqual(expected, detector.Finish, 'large bytewise input');
    AssertEquals(Int64(Length(data)), Int64(expected.BytesSeen));
  finally
    detector.Free;
  end;
end;

procedure TAPITests.UnicodeSourcesAndEmptyInput;
var
  detected: TCharsetDetectionResult;
begin
  detected := DetectCharset('');
  AssertEquals(Ord(dsInsufficientData), Ord(detected.Status));
  AssertEquals('', detected.Charset);
  AssertEquals(0, detected.CodePage);
  AssertEquals(0, Int64(detected.BytesSeen));
  AssertTrue(detected.IsFinal);

  detected := DetectCharset(#$EF#$BB#$BF'hello');
  AssertEquals(Ord(dsDetected), Ord(detected.Status));
  AssertEquals('UTF-8', detected.Charset);
  AssertEquals(Ord(csBOM), Ord(detected.Source));
  AssertEquals(Ord(BOM_UTF8), Ord(detected.BOM));
  AssertEquals(3, detected.BOMSize);
  AssertEquals(8, Int64(detected.BytesSeen));
  AssertFalse(detected.HasConfidence);

  detected := DetectCharset('plain ASCII');
  AssertEquals('ASCII', detected.Charset);
  AssertEquals(0, detected.CodePage);
  AssertEquals(Ord(csASCII), Ord(detected.Source));

  detected := DetectCharset('caf' + #$C3#$A9 + ' r' + #$C3#$A9);
  AssertEquals('UTF-8', detected.Charset);
  AssertEquals(Ord(csUTF8Validation), Ord(detected.Source));
  AssertFalse(detected.HasConfidence);

  detected := DetectCharset(ReadFixture('utf-16be-en-lf.txt'));
  AssertEquals('UTF-16BE', detected.Charset);
  AssertEquals(Ord(csUTF16Structure), Ord(detected.Source));
  AssertEquals(Ord(BOM_Not_Found), Ord(detected.BOM));

  detected := DetectCharset(#$E2#$82);
  AssertTrue('unfinished UTF-8 is not detected',
    (detected.Charset <> 'UTF-8') or
    (detected.Source <> csUTF8Validation));

  detected := DetectCharset(#0#$01#$02#$03#$04);
  AssertEquals(Ord(dsUnknown), Ord(detected.Status));
  detected := DetectCharset(#$80);
  AssertEquals(Ord(dsInsufficientData), Ord(detected.Status));
end;

procedure TAPITests.WeakAndShortStatisticalGuesses;
var
  detected: TCharsetDetectionResult;
begin
  detected := DetectCharset(#$80);
  AssertEquals(Ord(dsInsufficientData), Ord(detected.Status));
  AssertTrue('short input still has a statistical guess',
    Length(detected.Candidates) > 0);
  AssertEquals(detected.Candidates[0].Charset, detected.Charset);
  AssertEquals(detected.Candidates[0].CodePage, detected.CodePage);
  AssertTrue(detected.HasConfidence);
  AssertTrue(Abs(detected.Candidates[0].Confidence -
    detected.Confidence) < 1e-12);

  detected := DetectCharset(#$E2#$8B#$D8#$A1#$CF#$E8#$A5#$9C#$CB#$EE#$82#$87);
  AssertEquals(Ord(dsUnknown), Ord(detected.Status));
  AssertTrue('weak input still has a statistical guess',
    Length(detected.Candidates) > 0);
  AssertTrue('test sample stays below the choice threshold',
    detected.Candidates[0].Confidence < 0.20);
  AssertEquals(detected.Candidates[0].Charset, detected.Charset);
  AssertEquals(detected.Candidates[0].CodePage, detected.CodePage);
  AssertTrue(detected.HasConfidence);
  AssertEquals(Ord(csStatistics), Ord(detected.Source));
  AssertTrue(Abs(detected.Candidates[0].Confidence -
    detected.Confidence) < 1e-12);
end;

procedure TAPITests.StreamingEqualsOneShot;
const
  Files: array[0..5] of string = (
    'ascii-lf.txt', 'utf-8-ru-lf.txt', 'utf-16le-fr-crlf.txt',
    'utf-16be-he-lf.txt', 'windows-1251-lf.txt',
    'iso-8859-8-shared-lf.txt');
var
  detector: TCharsetDetector;
  data: RawByteString;
  expected, actual: TCharsetDetectionResult;
  fileIndex, cut, i: Integer;
begin
  detector := TCharsetDetector.Create;
  try
    for fileIndex := Low(Files) to High(Files) do
      begin
        data := ReadFixture(Files[fileIndex]);
        expected := DetectCharset(data);
        for cut := 0 to Length(data) do
          begin
            detector.Reset;
            detector.Feed(Pointer(data), cut);
            detector.Feed(nil, 0);
            detector.Feed(PByte(Pointer(data)) + cut, Length(data) - cut);
            actual := detector.Finish;
            CheckEqual(expected, actual, Files[fileIndex] + ' split ' +
              IntToStr(cut));
            CheckEqual(actual, detector.Finish, 'repeat Finish');
          end;
        detector.Reset;
        for i := 1 to Length(data) do
          detector.Feed(@data[i], 1);
        CheckEqual(expected, detector.Finish, Files[fileIndex] + ' bytewise');
      end;
  finally
    detector.Free;
  end;
end;

procedure TAPITests.UniqueSortedCandidatesAndHebrewAmbiguity;
var
  detected, repeated: TCharsetDetectionResult;
  detector: TCharsetDetector;
  data: RawByteString;
  i, count: Integer;
begin
  data := ReadFixture('windows-1251-lf.txt');
  detected := DetectCharset(data);
  count := 0;
  for i := 0 to High(detected.Candidates) do
    begin
      if SameText(detected.Candidates[i].Charset, 'windows-1251') then
        Inc(count);
      if i > 0 then
        begin
          AssertTrue('candidates sorted by score',
            detected.Candidates[i - 1].Confidence >=
            detected.Candidates[i].Confidence);
          if detected.Candidates[i - 1].Confidence =
            detected.Candidates[i].Confidence then
            AssertTrue('equal scores sorted by canonical name',
              CompareText(detected.Candidates[i - 1].Charset,
                detected.Candidates[i].Charset) < 0);
        end;
    end;
  AssertEquals('Russian and Bulgarian models merge', 1, count);
  AssertTrue(FindCandidate(detected, 'x-mac-cyrillic') >= 0);

  data := ReadFixture('iso-8859-8-shared-lf.txt');
  detected := DetectCharset(data);
  AssertEquals(Ord(dsAmbiguous), Ord(detected.Status));
  AssertTrue('ambiguous result has a leading candidate',
    Length(detected.Candidates) > 0);
  AssertEquals(detected.Candidates[0].Charset, detected.Charset);
  AssertEquals(detected.Candidates[0].CodePage, detected.CodePage);
  AssertEquals(Ord(csStatistics), Ord(detected.Source));
  AssertTrue(detected.HasConfidence);
  AssertTrue(Abs(detected.Candidates[0].Confidence -
    detected.Confidence) < 1e-12);
  AssertTrue(FindCandidate(detected, 'ISO-8859-8') >= 0);
  AssertTrue(FindCandidate(detected, 'windows-1255') >= 0);

  detector := TCharsetDetector.Create;
  try
    detector.Feed(Pointer(data), Length(data));
    detected := detector.Finish;
    detected.Candidates[0].Charset := 'modified by caller';
    repeated := detector.Finish;
    AssertTrue('Finish returns an independent candidate array',
      repeated.Candidates[0].Charset <> 'modified by caller');
  finally
    detector.Free;
  end;
end;

procedure TAPITests.FinishResetAndInvalidFeed;
var
  detector: TCharsetDetector;
  detected: TCharsetDetectionResult;
  data: RawByteString;
  raised: Boolean;
begin
  detector := TCharsetDetector.Create;
  try
    detector.Feed(nil, 0);
    detected := detector.Finish;
    AssertEquals(Ord(dsInsufficientData), Ord(detected.Status));
    raised := False;
    try
      detector.Feed(nil, 0);
    except
      on EInvalidOp do raised := True;
    end;
    AssertTrue('Feed after Finish is rejected', raised);

    detector.Reset;
    raised := False;
    try
      detector.Feed(nil, 1);
    except
      on EArgumentException do raised := True;
    end;
    AssertTrue('nil with positive count is rejected', raised);
    data := 'A';
    raised := False;
    try
      detector.Feed(Pointer(data), -1);
    except
      on EArgumentException do raised := True;
    end;
    AssertTrue('negative count is rejected', raised);

    detector.Feed(Pointer(data), Length(data));
    detected := detector.Finish;
    AssertEquals('ASCII', detected.Charset);
    AssertEquals(1, Int64(detected.BytesSeen));
  finally
    detector.Free;
  end;
end;

procedure TAPITests.ExistingDetectorRemainsUsable;
var
  detector: TnsUniversalDetector;
  data: RawByteString;
begin
  data := 'legacy interface';
  detector := TnsUniversalDetector.Create;
  try
    detector.HandleData(PAnsiChar(data), Length(data));
    if not detector.Done then
      detector.DataEnd;
    AssertEquals('ASCII', String(detector.GetDetectedCharsetInfo.Name));
  finally
    detector.Free;
  end;
end;

initialization
  RegisterTest(TAPITests);

end.
