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
// $Id: nsLatin1Prober.pas,v 1.4 2013/04/23 19:47:10 ya_nick Exp $

unit nsLatin1Prober;

interface

uses
	nsCore,
	CustomDetector;

type
	TnsLatin1Prober = class(TCustomDetector)
		private
      mLastCharClass: AnsiChar;
      mFreqCounter: array of uInt32;
      mInsideTag: Boolean;
      mPending: array of AnsiChar;
      mPendingLength: Integer;
      procedure AppendPending(aChar: AnsiChar);
      procedure ObserveByte(aChar: AnsiChar);
		public
    	constructor Create; override;
      destructor Destroy; override;

      function HandleData(aBuf: pAnsiChar;  aLen: integer): eProbingState; override;
      function GetDetectedCharset: eInternalCharsetID; override;
      procedure Reset; override;
      procedure FinishData;
      function GetConfidence: float; override;
      {$ifdef DEBUG_chardet}
      procedure DumpStatus; override;
      {$endif}
  end;

implementation

uses
	SysUtils;

const
	FREQ_CAT_NUM = 4;

  UDF = 0; (* undefined*)
  OTH = 1; (*other*)
  ASC = 2; (* ascii capital letter*)
  ASS = 3; (* ascii small letter*)
  ACV = 4; (* accent capital vowel*)
  ACO = 5; (* accent capital other*)
  ASV = 6; (* accent small vowel*)
  ASO = 7; (* accent small other*)
	CLASS_NUM = 8; (* total classes*)

Latin1_CharToClass: array [0..255] of byte =
(
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 00 - 07
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 08 - 0F
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 10 - 17
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 18 - 1F
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 20 - 27
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 28 - 2F
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 30 - 37
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 38 - 3F
  OTH, ASC, ASC, ASC, ASC, ASC, ASC, ASC,   // 40 - 47
  ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,   // 48 - 4F
  ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,   // 50 - 57
  ASC, ASC, ASC, OTH, OTH, OTH, OTH, OTH,   // 58 - 5F
  OTH, ASS, ASS, ASS, ASS, ASS, ASS, ASS,   // 60 - 67
  ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,   // 68 - 6F
  ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,   // 70 - 77
  ASS, ASS, ASS, OTH, OTH, OTH, OTH, OTH,   // 78 - 7F
  OTH, UDF, OTH, ASO, OTH, OTH, OTH, OTH,   // 80 - 87
  OTH, OTH, ACO, OTH, ACO, UDF, ACO, UDF,   // 88 - 8F
  UDF, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // 90 - 97
  OTH, OTH, ASO, OTH, ASO, UDF, ASO, ACO,   // 98 - 9F
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // A0 - A7
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // A8 - AF
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // B0 - B7
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,   // B8 - BF
  ACV, ACV, ACV, ACV, ACV, ACV, ACO, ACO,   // C0 - C7
  ACV, ACV, ACV, ACV, ACV, ACV, ACV, ACV,   // C8 - CF
  ACO, ACO, ACV, ACV, ACV, ACV, ACV, OTH,   // D0 - D7
  ACV, ACV, ACV, ACV, ACV, ACO, ACO, ACO,   // D8 - DF
  ASV, ASV, ASV, ASV, ASV, ASV, ASO, ASO,   // E0 - E7
  ASV, ASV, ASV, ASV, ASV, ASV, ASV, ASV,   // E8 - EF
  ASO, ASO, ASV, ASV, ASV, ASV, ASV, OTH,   // F0 - F7
  ASV, ASV, ASV, ASV, ASV, ASO, ASO, ASO    // F8 - FF
);


(*
	 0 : illegal
   1 : very unlikely
   2 : normal
   3 : very likely
*)
Latin1ClassModel: array [0..63] of byte =
(
(*      UDF OTH ASC ASS ACV ACO ASV ASO  *)
(*UDF*)  0,  0,  0,  0,  0,  0,  0,  0,
(*OTH*)  0,  3,  3,  3,  3,  3,  3,  3,
(*ASC*)  0,  3,  3,  3,  3,  3,  3,  3,
(*ASS*)  0,  3,  3,  3,  1,  1,  3,  3,
(*ACV*)  0,  3,  3,  3,  1,  2,  1,  2,
(*ACO*)  0,  3,  3,  3,  3,  3,  3,  3,
(*ASV*)  0,  3,  1,  3,  1,  1,  1,  3,
(*ASO*)  0,  3,  1,  3,  1,  1,  3,  3
);

  { TnsLatin1Prober }

constructor TnsLatin1Prober.Create;
begin
	inherited Create;
  SetLength(mFreqCounter, FREQ_CAT_NUM);
  Reset;
end;

destructor TnsLatin1Prober.Destroy;
begin
  SetLength(mFreqCounter, 0);

  inherited;
end;

{$ifdef DEBUG_chardet}
procedure TnsLatin1Prober.DumpStatus;
begin
  printf(' Latin1Prober: %1.3f [%s]r'#13#10'',GetConfidence,GetCharSetName);
end;
{$endif}

function TnsLatin1Prober.GetDetectedCharset: eInternalCharsetID;
begin
	Result := WINDOWS_1252_CHARSET;
end;

procedure TnsLatin1Prober.AppendPending(aChar: AnsiChar);
var
  capacity: Integer;
begin
  if mPendingLength = Length(mPending) then
    begin
      capacity := Length(mPending);
      if capacity < 64 then
        capacity := 64
      else if capacity <= High(Integer) div 2 then
        capacity := capacity * 2
      else
        capacity := High(Integer);
      SetLength(mPending, capacity);
    end;
  mPending[mPendingLength] := aChar;
  Inc(mPendingLength);
end;

procedure TnsLatin1Prober.ObserveByte(aChar: AnsiChar);
var
  charClass: AnsiChar;
  freq: Byte;
begin
  if mState = psNotMe then
    Exit;
  charClass := AnsiChar(Latin1_CharToClass[Byte(aChar)]);
  freq := Latin1ClassModel[Byte(mLastCharClass) * CLASS_NUM +
    Byte(charClass)];
  if freq = 0 then
    mState := psNotMe
  else
    begin
      Inc(mFreqCounter[freq]);
      mLastCharClass := charClass;
    end;
end;

function TnsLatin1Prober.GetConfidence: float;
var
  confidence: float;
  total: cardinal;
  i: integer;
begin
  if mState = psNotMe then
    begin
      Result := SURE_NO;
      exit;
    end;

  total := 0;
  for i := 0 to Pred(FREQ_CAT_NUM) do
	  total := total + mFreqCounter[i];

  if total = 0 then
	  confidence := 0.0
  else
    begin
      confidence := mFreqCounter[3] * 1.0 / total;
      confidence := confidence - (mFreqCounter[1] * 20.0 /total);
    end;
  if confidence < 0.0 then
	  confidence := 0.0;

  confidence := confidence * (0.50);
  (* lower the confidence of latin1 so that other more accurate detector *)
  (* can take priority.*)
  Result := confidence;
end;

function TnsLatin1Prober.HandleData(aBuf: pAnsiChar; aLen: integer): eProbingState;
var
  i, j: Integer;
  value: AnsiChar;
  isDelimiter: Boolean;
begin
  Result := inherited HandleData(aBuf, aLen);
  if Result = psNotMe then
    Exit;
  for i := 0 to aLen - 1 do
    begin
      value := aBuf[i];
      if value = '>' then
        mInsideTag := False
      else if value = '<' then
        mInsideTag := True;
      isDelimiter := (Byte(value) < $80) and
        ((value < 'A') or ((value > 'Z') and (value < 'a')) or
         (value > 'z'));
      if isDelimiter then
        begin
          if (mPendingLength > 0) and not mInsideTag then
            begin
              for j := 0 to mPendingLength - 1 do
                ObserveByte(mPending[j]);
              ObserveByte(' ');
            end;
          mPendingLength := 0;
        end
      else
        AppendPending(value);
      if mState = psNotMe then
        Break;
    end;
  Result := mState;
end;

procedure TnsLatin1Prober.FinishData;
var
  i: Integer;
begin
  if not mInsideTag then
    for i := 0 to mPendingLength - 1 do
      ObserveByte(mPending[i]);
  mPendingLength := 0;
end;

procedure TnsLatin1Prober.Reset;
var
	i: integer;
begin
  mState := psDetecting;
  mLastCharClass := AnsiChar(OTH);
  mInsideTag := False;
  SetLength(mPending, 0);
  mPendingLength := 0;
  for i := 0 to Pred(FREQ_CAT_NUM) do
  	mFreqCounter[i] := 0;
end;

end.
