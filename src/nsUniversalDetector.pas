// +----------------------------------------------------------------------+
// |    chsdet - Charset Detector Library                                 |
// +----------------------------------------------------------------------+
// | Copyright (C) 2006, Nick Yakowlew     http://chsdet.sourceforge.net  |
// +----------------------------------------------------------------------+
// | Based on Mozilla sources     http://www.mozilla.org/projects/intl/   |
// +----------------------------------------------------------------------+
// | This library is free software; you can redistribute it and/or modify |
// | it under the terms of the GNU General Public License as published by |
// | the Free Software Foundation; either version 2 of the License, or    |
// | (at your option) any later version.                                  |
// | This library is distributed in the hope that it will be useful       |
// | but WITHOUT ANY WARRANTY; without even the implied warranty of       |
// | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                 |
// | See the GNU Lesser General Public License for more details.          |
// | http://www.opensource.org/licenses/lgpl-license.php                  |
// +----------------------------------------------------------------------+
//
// $Id: nsUniversalDetector.pas,v 1.7 2013/05/16 15:41:14 ya_nick Exp $

unit nsUniversalDetector;

interface
uses
{$I dbg.inc}
  nsCore,
  CustomDetector,
  CharsetUTF8,
  CharsetUTF16;

const
  NUM_OF_CHARSET_PROBERS = 4;

type
  eInputState = (
    isPureAscii = 0,
    isEscAscii = 1,
    isHighbyte = 2
    );

  TnsUniversalDetector = class(TObject)
  protected
    mInputState: eInputState;
    mDone: Boolean;
    mStart: Boolean;
    mGotData: Boolean;
    mLastChar: AnsiChar;
    mDetectedCharset: eInternalCharsetID;
    mCharSetProbers: array[0..Pred(NUM_OF_CHARSET_PROBERS)] of TCustomDetector;
    mEscCharSetProber: TCustomDetector;
    mDetectedBOM: eBOMKind;
    mBOMBuffer: array[0..3] of AnsiChar;
    mBOMLength: integer;
    mUTF8: TCharsetUTF8Validator;
    mUTF16: TCharsetUTF16Prober;

    procedure Report(aCharsetID: eInternalCharsetID);
    procedure ResolveInitialBytes(aAtEnd: Boolean);
    procedure ProcessData(aBuf: pAnsiChar; aLen: integer);
    function GetCharsetID(CodePage: integer): eInternalCharsetID;
    procedure DoEnableCharset(Charset: eInternalCharsetID; SetEnabledTo: Boolean);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Reset;
    function HandleData(aBuf: pAnsiChar; aLen: integer): nsResult;
    procedure DataEnd;

    function GetDetectedCharsetInfo: nsCore.rCharsetInfo;

    function GetKnownCharset(out KnownCharsets: String): integer;
    procedure GetAbout(out About: rAboutHolder);
    procedure DisableCharset(CodePage: integer);

    property Done: Boolean read mDone;
    property BOMDetected: eBOMKind read mDetectedBOM;
  end;

implementation
uses
  SysUtils,
  nsGroupProber,
  nsMBCSMultiProber,
  nsSBCSGroupProber,
  nsEscCharsetProber,
  nsLatin1Prober,
  MBUnicodeMultiProber,
  CharsetBOM;

const
  MINIMUM_THRESHOLD: float = 0.20;

  AboutInfo: rAboutHolder = (
    MajorVersionNr: 0;
    MinorVersionNr: 2;
    BuildVersionNr: 10;
    About: 'Charset Detector Library. Copyright (C) 2006 - 2013, Nick Yakowlew. http://chsdet.sourceforge.net';
  );
  { TnsUniversalDetector }

constructor TnsUniversalDetector.Create;
begin
  inherited Create;

  mCharSetProbers[0] := TnsMBCSMultiProber.Create;
  mCharSetProbers[1] := TnsSBCSGroupProber.Create;
  mCharSetProbers[2] := TnsLatin1Prober.Create;
  mCharSetProbers[3] := TMBUnicodeMultiProber.Create;
  mEscCharSetProber := TnsEscCharSetProber.Create;
  mUTF8 := TCharsetUTF8Validator.Create;
  mUTF16 := TCharsetUTF16Prober.Create;
  Reset;
end;

destructor TnsUniversalDetector.Destroy;
var
  i: integer;
begin
  for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
    mCharSetProbers[i].Free;

  mEscCharSetProber.Free;
  mUTF8.Free;
  mUTF16.Free;

  inherited;
end;

procedure TnsUniversalDetector.DataEnd;
var
  proberConfidence: float;
  maxProberConfidence: float;
  maxProber: int32;
  i: integer;
  utf16Charset: eInternalCharsetID;
  utf8Ready: Boolean;
  asciiCandidate: Boolean;
begin
  if not mGotData then
    (* we haven't got any data yet, return immediately *)
    (* caller program sometimes call DataEnd before anything has been sent to detector*)
    exit;

  if mStart then
    ResolveInitialBytes(True);

  if mDone then
    Exit;
  if mDetectedBOM <> BOM_Not_Found then
    begin
      mDone := TRUE;
      exit;
    end;

  asciiCandidate := mUTF8.IsASCII and not mUTF8.HasNUL;
  { Classify ASCII before UTF-8, but resolve UTF-16 structure before making
    the ASCII result final: UTF-16 can also contain only low-byte values. }
  utf16Charset := mUTF16.Detect;
  if utf16Charset <> UNKNOWN_CHARSET then
    begin
      mDetectedCharset := utf16Charset;
      mDone := True;
      Exit;
    end;

  if asciiCandidate then
    begin
      if mInputState = isEscAscii then
        mDetectedCharset := mEscCharSetProber.GetDetectedCharset;
      if mDetectedCharset = UNKNOWN_CHARSET then
        mDetectedCharset := PURE_ASCII_CHARSET;
      mDone := True;
      Exit;
    end;

  { Validity alone is weak evidence on short byte strings. Two complete
    non-ASCII characters are needed to prefer UTF-8 to legacy encodings. }
  utf8Ready := not mUTF8.HasNUL and mUTF8.Finish and
    (mUTF8.MultibyteCount >= 2);
  if utf8Ready then
    begin
      mDetectedCharset := UTF8_CHARSET;
      mDone := True;
      Exit;
    end;

  if (mDetectedCharset = UTF8_CHARSET) and not utf8Ready then
    mDetectedCharset := UNKNOWN_CHARSET;

  case mInputState of
    isHighbyte:
      begin
        maxProberConfidence := 0.0;
        maxProber := 0;
        for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
          begin
            if (i = 3) and not utf8Ready then
              Continue;
            proberConfidence := mCharSetProbers[i].GetConfidence;
            if proberConfidence > maxProberConfidence then
              begin
                maxProberConfidence := proberConfidence;
                maxProber := i;
              end;
          end;
        (*do not report anything because we are not confident of it, that's in fact a negative answer*)
        if maxProberConfidence > MINIMUM_THRESHOLD then
          Report(mCharSetProbers[maxProber].GetDetectedCharset);
      end;
    isEscAscii:
      begin
        mDetectedCharset := mEscCharSetProber.GetDetectedCharset;
      end;
  else
    begin
      if not mUTF8.HasNUL then
        mDetectedCharset := PURE_ASCII_CHARSET;
    end;
  end;                                  {case}
  mDone := True;
{$IFDEF DEBUG_chardet}
  AddDump('Universal detector - DataEnd');
{$ENDIF}
end;

function TnsUniversalDetector.HandleData(aBuf: pAnsiChar; aLen: integer): nsResult;
var
  i: integer;
begin
  Result := NS_OK;
  if mDone or (aLen <= 0) then
    Exit;
  mGotData := TRUE;

  i := 0;
  while mStart and (i < aLen) do
    begin
      mBOMBuffer[mBOMLength] := aBuf[i];
      Inc(mBOMLength);
      Inc(i);
      ResolveInitialBytes(False);
    end;

  if not mDone and (i < aLen) then
    ProcessData(@aBuf[i], aLen - i);
end;

procedure TnsUniversalDetector.ProcessData(aBuf: pAnsiChar; aLen: integer);
var
  i: integer;
  st: eProbingState;
begin
  mUTF8.Feed(aBuf, aLen);
  mUTF16.Feed(aBuf, aLen);

  for i := 0 to Pred(aLen) do
    if Byte(aBuf[i]) >= $80 then
      begin
        if mInputState <> isHighbyte then
          begin
            (*adjust state*)
            mInputState := isHighbyte;
          end;
      end
    else
      begin
        (*ok, just pure ascii so *)
        if (mInputState = isPureAscii) and
          ((aBuf[i] = #$1B) or
          (aBuf[i] = '{') and
          (mLastChar = '~')) then
          (*found escape character or HZ "~{"*)
          mInputState := isEscAscii;

        mLastChar := aBuf[i];
      end;

  case mInputState of
    isEscAscii:
      begin
{$IFDEF DEBUG_chardet}
        AddDump('Universal detector - Escape Detector started');
{$ENDIF}
        st := mEscCharSetProber.HandleData(aBuf, aLen);
        if st = psFoundIt then
          begin
            mDone := TRUE;
            mDetectedCharset := mEscCharSetProber.GetDetectedCharset;
          end;
      end;
    isHighbyte:
      begin
{$IFDEF DEBUG_chardet}
        AddDump('Universal detector - HighByte Detector started');
{$ENDIF}
        for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
          begin
            st := mCharSetProbers[i].HandleData(aBuf, aLen);
            if st = psFoundIt then
              begin
                if mDetectedCharset = UNKNOWN_CHARSET then
                  mDetectedCharset := mCharSetProbers[i].GetDetectedCharset;
                break;
              end;
          end;
      end;
  else
    (*pure ascii*)
    begin
      (*do nothing here*)
    end;
  end;                                  {case}
end;

procedure TnsUniversalDetector.Report(aCharsetID: eInternalCharsetID);
begin

  if (aCharsetID <> UNKNOWN_CHARSET) and
    (mDetectedCharset = UNKNOWN_CHARSET) then

    mDetectedCharset := aCharsetID;
end;

procedure TnsUniversalDetector.Reset;
var
  i: integer;
begin
  mDone := FALSE;
  mStart := TRUE;
  mDetectedCharset := UNKNOWN_CHARSET;
  mGotData := FALSE;
  mInputState := isPureAscii;
  mLastChar := #0;                      (*illegal value as signal*)
  mEscCharSetProber.Reset;
  for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
    mCharSetProbers[i].Reset;
  mDetectedBOM := BOM_Not_Found;
  mBOMLength := 0;
  mUTF8.Reset;
  mUTF16.Reset;
end;

function TnsUniversalDetector.GetDetectedCharsetInfo: nsCore.rCharsetInfo;
begin
  Result := KNOWN_CHARSETS[mDetectedCharset];
end;

function TnsUniversalDetector.GetKnownCharset(out KnownCharsets: String): integer;
var
  i: eInternalCharsetID;
begin
  KnownCharsets := '';
  for i := low(KNOWN_CHARSETS) to high(KNOWN_CHARSETS) do
    KnownCharsets := KnownCharsets + #10 + KNOWN_CHARSETS[i].Name +
      ' - ' + IntToStr(KNOWN_CHARSETS[i].CodePage);

  Result := Length(KnownCharsets);
end;

procedure TnsUniversalDetector.GetAbout(out About: rAboutHolder);
begin
  About := AboutInfo;
end;

procedure TnsUniversalDetector.ResolveInitialBytes(aAtEnd: Boolean);
begin
  if not ResolveCharsetBOM(@mBOMBuffer[0], mBOMLength, aAtEnd,
    mDetectedBOM) then
    Exit;
  mStart := False;
  case mDetectedBOM of
    BOM_UTF8:      mDetectedCharset := UTF8_CHARSET;
    BOM_UTF16_LE:  mDetectedCharset := UTF16_LE_CHARSET;
    BOM_UTF16_BE:  mDetectedCharset := UTF16_BE_CHARSET;
    BOM_UCS4_LE:   mDetectedCharset := UTF32_LE_CHARSET;
    BOM_UCS4_BE:   mDetectedCharset := UTF32_BE_CHARSET;
    BOM_UCS4_2143: mDetectedCharset := UCS4_LE_CHARSET;
    BOM_UCS4_3412: mDetectedCharset := UCS4_BE_CHARSET;
    BOM_Not_Found: ProcessData(@mBOMBuffer[0], mBOMLength);
  end;
  if mDetectedBOM <> BOM_Not_Found then
    mDone := True;
  mBOMLength := 0;
end;

procedure TnsUniversalDetector.DisableCharset(CodePage: integer);
begin
  DoEnableCharset(GetCharsetID(CodePage), false);
end;

function TnsUniversalDetector.GetCharsetID(CodePage: integer): eInternalCharsetID;
var
  i: integer;
begin
  for i := integer(low(KNOWN_CHARSETS)) + 1 to integer(high(KNOWN_CHARSETS)) do
    if (KNOWN_CHARSETS[eInternalCharsetID(i)].CodePage = CodePage) then
      begin
        Result := eInternalCharsetID(i);
        exit;
      end;
  Result := UNKNOWN_CHARSET;
end;

procedure TnsUniversalDetector.DoEnableCharset(Charset: eInternalCharsetID; SetEnabledTo: Boolean);
var
  i: integer;
begin
  if Charset = UNKNOWN_CHARSET then
    exit;
  for i := 0 to Pred(NUM_OF_CHARSET_PROBERS) do
    begin
      if (mCharSetProbers[i] is TnsGroupProber) then
        begin
          if TnsGroupProber(mCharSetProbers[i]).EnableCharset(Charset, SetEnabledTo) then
            exit;
        end;
      if (mCharSetProbers[i] is TnsEscCharSetProber) then
        begin
          TnsEscCharSetProber(mCharSetProbers[i]).Enabled := SetEnabledTo;
        end;
      if (mCharSetProbers[i] is TCustomDetector) then
        begin
          if TCustomDetector(mCharSetProbers[i]).GetDetectedCharset = Charset then
            TCustomDetector(mCharSetProbers[i]).Enabled := SetEnabledTo;
        end;
    end;

end;

end.
