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
// $Id: nsSBCSGroupProber.pas,v 1.4 2013/04/23 19:47:10 ya_nick Exp $

unit nsSBCSGroupProber;

interface
uses
	nsCore,
  nsGroupProber;

type
	TnsSBCSGroupProber = class(TnsGroupProber)
		private
      mPendingASCII: array of AnsiChar;
      mPendingLength: Integer;
      mSegmentHasHighByte: Boolean;
      procedure AppendPending(aChar: AnsiChar);
		public
      constructor Create; reintroduce;
      function HandleData(aBuf: pAnsiChar;  aLen: integer): eProbingState; override;
      procedure Reset; override;
      function GetModelScores: TCharsetModelScores; override;
      procedure ConfigureAllowed(const aAllowed: TInternalCharsetSet);
      procedure SetPublicCharsetEnabled(aCharset: eInternalCharsetID;
        aEnabled: Boolean);
//      {$ifdef DEBUG_chardet}
//      procedure DumpStatus; override;
//      {$endif}
  end;

implementation
uses
	SysUtils,
	nsHebrewProber,
  nsSBCharSetProber,
  LangCyrillicModel,
  LangGreekModel,
  LangBulgarianModel,
  LangHebrewModel;

{ TnsSBCSGroupProber }
const
	NUM_OF_PROBERS = 13;
  SBCSModelCharset: array[0..9] of eInternalCharsetID = (
    WINDOWS_1251_CHARSET, KOI8_R_CHARSET, ISO_8859_5_CHARSET,
    X_MAC_CYRILLIC_CHARSET, IBM866_CHARSET, IBM855_CHARSET,
    ISO_8859_7_CHARSET, WINDOWS_1253_CHARSET,
    LATIN5_BULGARIAN_CHARSET, WINDOWS_BULGARIAN_CHARSET);

constructor TnsSBCSGroupProber.Create;
var
  hebprober: TnsHebrewProber;
  i: integer;
begin
  mNumOfProbers := NUM_OF_PROBERS;
  SetLength(mProbers, NUM_OF_PROBERS);
  SetLength(mIsActive, NUM_OF_PROBERS);
  SetLength(mProberStates, NUM_OF_PROBERS);
  mProbers[0] := TnsSingleByteCharSetProber.Create(Win1251Model);
  mProbers[1] := TnsSingleByteCharSetProber.Create(Koi8rModel);
  mProbers[2] := TnsSingleByteCharSetProber.Create(Latin5Model);
  mProbers[3] := TnsSingleByteCharSetProber.Create(MacCyrillicModel);
  mProbers[4] := TnsSingleByteCharSetProber.Create(Ibm866Model);
  mProbers[5] := TnsSingleByteCharSetProber.Create(Ibm855Model);
  mProbers[6] := TnsSingleByteCharSetProber.Create(Latin7Model);
  mProbers[7] := TnsSingleByteCharSetProber.Create(Win1253Model);
  mProbers[8] := TnsSingleByteCharSetProber.Create(Latin5BulgarianModel);
  mProbers[9] := TnsSingleByteCharSetProber.Create(Win1251BulgarianModel);

  hebprober := TnsHebrewProber.Create;
  // Notice: Any change in these indexes - 10,11,12 must be reflected
  // in the code below as well.
  mProbers[10]:= hebprober;
  mProbers[11]:= TnsSingleByteCharSetProber.Create(Win1255Model,FALSE,hebprober);(* Logical Hebrew*)
  mProbers[12]:= TnsSingleByteCharSetProber.Create(Win1255Model,TRUE,hebprober); (* Visual Hebrew*)
  (* Tell the Hebrew prober about the logical and visual probers*)
  if (mProbers[10]<>nil)and(mProbers[11]<>nil)and(mProbers[12]<>nil) then
    (* all are not null*)
    hebprober.SetModelProbers(mProbers[11],mProbers[12])
  else
    (* One or more is null. avoid any Hebrew probing, null them all*)
    for i := 10 to 12 do
      begin
        mProbers[i].Free;
        mProbers[i] := nil;
      end;

  { These models must see the complete filtered stream. A shortcut reached
    between external chunks would freeze their scores at a chunk boundary. }
  for i := 0 to Pred(NUM_OF_PROBERS) do
    if mProbers[i] is TnsSingleByteCharSetProber then
      TnsSingleByteCharSetProber(mProbers[i]).UseShortcuts := False;

  inherited Create;
  (* disable latin2 before latin1 is available, otherwise all latin1 *)
  (* will be detected as latin2 because of their similarity.*)
  // mProbers[10] = new nsSingleByteCharSetProber(&Latin2HungarianModel);
  // mProbers[11] = new nsSingleByteCharSetProber(&Win1250HungarianModel);
end;

procedure TnsSBCSGroupProber.AppendPending(aChar: AnsiChar);
var
  capacity: Integer;
begin
  if mPendingLength = Length(mPendingASCII) then
    begin
      capacity := Length(mPendingASCII);
      if capacity < 64 then
        capacity := 64
      else if capacity <= High(Integer) div 2 then
        capacity := capacity * 2
      else
        capacity := High(Integer);
      SetLength(mPendingASCII, capacity);
    end;
  mPendingASCII[mPendingLength] := aChar;
  Inc(mPendingLength);
end;

procedure TnsSBCSGroupProber.ConfigureAllowed(
  const aAllowed: TInternalCharsetSet);
var
  i: Integer;
begin
  for i := 0 to 9 do
    mProbers[i].Enabled := SBCSModelCharset[i] in aAllowed;
  mProbers[10].Enabled :=
    (WINDOWS_1255_CHARSET in aAllowed) or
    (ISO_8859_8_CHARSET in aAllowed);
  mProbers[11].Enabled := WINDOWS_1255_CHARSET in aAllowed;
  mProbers[12].Enabled := ISO_8859_8_CHARSET in aAllowed;
  Reset;
end;

procedure TnsSBCSGroupProber.SetPublicCharsetEnabled(
  aCharset: eInternalCharsetID; aEnabled: Boolean);
var
  i: Integer;
begin
  for i := 0 to 9 do
    if KNOWN_CHARSETS[SBCSModelCharset[i]].CodePage =
      KNOWN_CHARSETS[aCharset].CodePage then
      mProbers[i].Enabled := aEnabled;
  if aCharset = WINDOWS_1255_CHARSET then
    mProbers[11].Enabled := aEnabled;
  if aCharset = ISO_8859_8_CHARSET then
    mProbers[12].Enabled := aEnabled;
  mProbers[10].Enabled := mProbers[11].Enabled or mProbers[12].Enabled;
  Reset;
end;

procedure TnsSBCSGroupProber.Reset;
begin
  inherited Reset;
  SetLength(mPendingASCII, 0);
  mPendingLength := 0;
  mSegmentHasHighByte := False;
end;

function TnsSBCSGroupProber.HandleData(aBuf: pAnsiChar; aLen: integer): eProbingState;
var
  filtered: PAnsiChar;
  filteredLength, i: Integer;
  value: AnsiChar;
  isDelimiter: Boolean;
begin
  Result := mState;
  if (mState <> psDetecting) or (aLen <= 0) then
    Exit;
  filtered := GetMem(aLen);
  filteredLength := 0;
  try
    for i := 0 to aLen - 1 do
      begin
        value := aBuf[i];
        isDelimiter := (value < 'A') or
          ((value > 'Z') and (value < 'a')) or (value > 'z');
        if Byte(value) > $80 then
          begin
            if not mSegmentHasHighByte then
              begin
                { The preceding ASCII letters belong to this segment only
                  once a high byte has appeared. Emit them in input order. }
                if filteredLength > 0 then
                  begin
                    inherited HandleData(filtered, filteredLength);
                    filteredLength := 0;
                  end;
                if mPendingLength > 0 then
                  inherited HandleData(@mPendingASCII[0], mPendingLength);
                mPendingLength := 0;
                mSegmentHasHighByte := True;
              end;
            filtered[filteredLength] := value;
            Inc(filteredLength);
          end
        else if isDelimiter then
          begin
            if mSegmentHasHighByte then
              begin
                filtered[filteredLength] := ' ';
                Inc(filteredLength);
              end;
            mPendingLength := 0;
            mSegmentHasHighByte := False;
          end
        else if mSegmentHasHighByte then
          begin
            filtered[filteredLength] := value;
            Inc(filteredLength);
          end
        else
          AppendPending(value);
      end;
    if filteredLength > 0 then
      inherited HandleData(filtered, filteredLength);
  finally
    FreeMem(filtered);
  end;
  Result:= mState;
end;

function TnsSBCSGroupProber.GetModelScores: TCharsetModelScores;
var
  i, count: integer;
begin
  Result := nil;
  SetLength(Result, mNumOfProbers);
  count := 0;
  for i := 0 to Pred(mNumOfProbers) do
    begin
      { Index 10 only selects the Hebrew name; 11 and 12 are the logical
        Windows and visual ISO models, respectively. }
      if (i = 10) or not mIsActive[i] or (mProbers[i] = nil) or
        (mProberStates[i] = psNotMe) then
        Continue;
      case i of
        11: Result[count].CharsetID := WINDOWS_1255_CHARSET;
        12: Result[count].CharsetID := ISO_8859_8_CHARSET;
        else Result[count].CharsetID := mProbers[i].GetDetectedCharset;
      end;
      Result[count].Confidence := mProbers[i].GetConfidence;
      Result[count].State := mProberStates[i];
      Inc(count);
    end;
  SetLength(Result, count);
end;

{$ifdef DEBUG_chardet}
procedure TnsSBCSGroupProber.DumpStatus;
var
  i: integer;
  cf: float;
  i: integer;
begin
  cf := GetConfidence;
  printf(' SBCS Group Prober --------begin status r'#13#10'');
  for i := 0 to Pred(NUM_OF_SBCS_PROBERS) do
    begin
      if 0 = mIsActive[i] then
	      printf('  inactive: [%s] (i.e. confidence is too low).r'#13#10'',mProbers[i].GetCharSetName)
      else
  	    mProbers[i].DumpStatus;
    end;
  printf(' SBCS Group found best match [%s] confidence %f.r'#13#10'',mProbers[mBestGuess].GetCharSetName,cf);
end;
{$endif}

end.
