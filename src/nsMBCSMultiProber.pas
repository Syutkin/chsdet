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
// $Id: nsMBCSMultiProber.pas,v 1.3 2013/04/23 19:47:10 ya_nick Exp $

unit nsMBCSMultiProber;

interface

uses
  {$I dbg.inc}
	nsCore,
  MultiModelProber,
  JpCntx,
	CharDistribution;

type
	TLastChar = array [0..1] of AnsiChar;

	TnsMBCSMultiProber = class (TMultiModelProber)
    private
      mDistributionAnalysis: array of TCharDistributionAnalysis;
      mContextAnalysis: array of TJapaneseContextAnalysis;
      mLastChar: array of TLastChar;
      mKeepNext: Byte;
      mBestGuess: integer;

      function RunStatAnalyse(aBuf: pAnsiChar; aLen: integer): eProbingState;
      function GetConfidenceFor(index: integer): double; reintroduce;
		public
			constructor Create; reintroduce;
      destructor Destroy; override;
		  function HandleData(aBuf: pAnsiChar; aLen: integer): eProbingState; override;
      function GetConfidence: double; override;
      procedure Reset; override;
      {$ifdef DEBUG_chardet}
      procedure DumpStatus(Dump: string); override;
      {$endif}
end;

implementation
uses
	SysUtils,
  nsCodingStateMachine
  {$ifdef DEBUG_chardet}
  ,TypInfo
  {$endif}
  ;

{$I '.\mbclass\SJISLangModel.inc'}
{$I '.\mbclass\EUCJPLangModel.inc'}
{$I '.\mbclass\GB18030LangModel.inc'}
{$I '.\mbclass\EUCKRLangModel.inc'}
{$I '.\mbclass\Big5LangModel.inc'}
{$I '.\mbclass\EUCTWLangModel.inc'}



{ TnsMBCSMultiProber }
const
	NUM_OF_PROBERS = 6;


constructor TnsMBCSMultiProber.Create;
begin
  inherited Create;
  SetLength(mDistributionAnalysis, NUM_OF_PROBERS);
  SetLength(mContextAnalysis, NUM_OF_PROBERS);
  SetLength(mLastChar, NUM_OF_PROBERS);

  AddCharsetModel(SJISLangModel);
  mDistributionAnalysis[0] := TSJISDistributionAnalysis.Create;
  mContextAnalysis[0] := TSJISContextAnalysis.Create;

  AddCharsetModel(EUCJPLangModel);
  mDistributionAnalysis[1] := TEUCJPDistributionAnalysis.Create;
  mContextAnalysis[1] := TEUCJPContextAnalysis.Create;

  AddCharsetModel(GB18030LangModel);
  mDistributionAnalysis[2] := TGB2312DistributionAnalysis.Create;
  mContextAnalysis[2] := nil;

  AddCharsetModel(EUCKRLangModel);
  mDistributionAnalysis[3] := TEUCKRDistributionAnalysis.Create;
  mContextAnalysis[3] := nil;

  AddCharsetModel(Big5LangModel);
  mDistributionAnalysis[4] := TBig5DistributionAnalysis.Create;
  mContextAnalysis[4] := nil;

  AddCharsetModel(EUCTWLangModel);
  mDistributionAnalysis[5] := TEUCTWDistributionAnalysis.Create;
  mContextAnalysis[5] := nil;

end;

destructor TnsMBCSMultiProber.Destroy;
var
  i: integer;
begin
  inherited;
  for i := 0 to Pred(mCharsetsCount) do
    begin
      if mDistributionAnalysis[i] <> nil then
        mDistributionAnalysis[i].Free;
      if mContextAnalysis[i] <> nil then
        mContextAnalysis[i].Free;
    end;

  SetLength(mDistributionAnalysis, 0);
  SetLength(mContextAnalysis, 0);
  SetLength(mLastChar, 0);

end;

{$ifdef DEBUG_chardet}
procedure TnsMBCSMultiProber.DumpStatus(Dump: string);
var
  i: integer;
begin
  AddDump(Dump + ' Current state ' + GetEnumName(TypeInfo(eProbingState), integer(mState)));
  AddDump(Format('%30s - %10s - %5s',
          ['Prober',
           'State',
           'Conf']));
  for i := 0 to Pred(mCharsetsCount) do
    AddDump(Format('%30s - %10s - %1.5f',
          [GetEnumName(TypeInfo(eInternalCharsetID), integer(mCodingSM[i].GetCharsetID)),
           GetEnumName(TypeInfo(eProbingState), integer(mSMState[i])),
           GetConfidenceFor(i)
           ]));
end;
{$endif}

function TnsMBCSMultiProber.HandleData(aBuf: pAnsiChar; aLen: integer): eProbingState;
var
  i: integer; (*do filtering to reduce load to probers*)
  highbyteBuf: pAnsiChar;
  hptr: pAnsiChar;
begin
  highbyteBuf := AllocMem(aLen);
  try
    hptr:= highbyteBuf;
    if hptr = nil  then
      begin
        Result := mState;
        exit;
      end;
    for i:=0 to Pred(aLen) do
      begin
        if (Byte(aBuf[i]) and $80) <> 0 then
          begin
            hptr^ := aBuf[i];
            inc(hptr);
            mKeepNext:= 2;
          end
        else
          begin
            (*if previous is highbyte, keep this even it is a ASCII*)
            if mKeepNext > 0 then
              begin
                hptr^ := aBuf[i];
                inc(hptr);
                Dec(mKeepNext);
              end;
          end;
      end;
    {$IFDEF DEBUG_chardet}
     AddDump('MultiByte - HandleData - start');
    {$endif}

    if (mState <> psFoundIt) and
       (mState <> psNotMe) then
      RunStatAnalyse(highbyteBuf, hptr - highbyteBuf);
    {$IFDEF DEBUG_chardet}
     AddDump('MultiByte - HandleData - end');
    {$endif}
  finally
	  FreeMem(highbyteBuf, aLen);
  end;

	Result := mState;
end;

function TnsMBCSMultiProber.RunStatAnalyse(aBuf: pAnsiChar; aLen: integer): eProbingState;
var
  i, c: integer;
  codingState: nsSMState;
  charLen: byte;
begin
  {$IFDEF DEBUG_chardet}
   AddDump('MultiByte - Stat Analyse - start');
  {$endif}

  for i := 0 to Pred(mCharsetsCount) do
    begin
      if (mSMState[i] = psFoundIt) or
         (mSMState[i] = psNotMe) then
        continue;
      if not mCodingSM[i].Enabled then
        continue;
      if mDistributionAnalysis[i] = nil then
        continue;
      for c := 0 to Pred(aLen) do
        begin
          codingState := mCodingSM[i].NextState(aBuf[c]);
          if codingState = eError then
            begin
              mSMState[i] := psNotMe;
              Dec(mActiveSM);
              break;
            end;
          if codingState = eItsMe then
            begin
              mSMState[i] := psFoundIt;
              mState := psFoundIt;
              mDetectedCharset := mCodingSM[i].GetCharsetID;
              Result := mState;
              Exit;
            end;
          if codingState = eStart then
            begin
              charLen := mCodingSM[i].GetCurrentCharLen;
              if c = 0 then
                begin
                  mLastChar[i][1] := aBuf[0];
                  if mContextAnalysis[i] <> nil then
                      mContextAnalysis[i].HandleOneChar(@mLastChar[i][0],charLen);
                  mDistributionAnalysis[i].HandleOneChar(@mLastChar[i][0],charLen);
                end
              else
                begin
                  if mContextAnalysis[i] <> nil then
                    mContextAnalysis[i].HandleOneChar(aBuf+c-1,charLen);
                  mDistributionAnalysis[i].HandleOneChar(aBuf+c-1,charLen);
                end;
            end;
          if (mContextAnalysis[i] <> nil) then
             if mContextAnalysis[i].GotEnoughData and
    	         (GetConfidenceFor(i) > SHORTCUT_THRESHOLD) then
            begin
		        mSMState[i] := psFoundIt;
  		        mState := psFoundIt;
              mDetectedCharset := mCodingSM[i].GetCharsetID;
              Result := mState;
              Exit;
            end;
        end;
      if aLen > 0 then
        mLastChar[i][0] := aBuf[aLen - 1];
    end;

  if mActiveSM = 0 then
    mState := psNotMe;

  {$IFDEF DEBUG_chardet}
   AddDump('MultiByte - Stat Analyse - EXIT');
  {$endif}
  Result := mState;
end;

function TnsMBCSMultiProber.GetConfidenceFor(index: integer): double;
var
  contxtCf: double;
  distribCf: double;
begin
  if mContextAnalysis[index] <> nil then
    contxtCf := mContextAnalysis[index].GetConfidence
  else
    contxtCf := -1;

  distribCf := mDistributionAnalysis[index].GetConfidence;

  if contxtCf > distribCf then
    Result := contxtCf
  else
    Result := distribCf;
end;

function TnsMBCSMultiProber.GetConfidence: double;
var
  i: integer;
  conf,
  bestConf: double;
begin
  mBestGuess := -1;
  bestConf := SURE_NO;
  for i := 0 to Pred(mCharsetsCount) do
    begin
      if (mSMState[i] = psFoundIt) or
         (mSMState[i] = psNotMe) then
        continue;
      if mDistributionAnalysis[i] = nil then
        continue;
      conf := GetConfidenceFor(i);
      if conf > bestConf then
        begin
          mBestGuess := i;
          bestConf := conf;
        end;
    end;
  Result := bestConf;
  if mBestGuess > -1 then
    mDetectedCharset := mCodingSM[mBestGuess].GetCharsetID
  else
    mDetectedCharset := UNKNOWN_CHARSET;
end;

procedure TnsMBCSMultiProber.Reset;
var
  i: integer;
begin
  inherited Reset;
  mKeepNext := 0;
  for i := 0 to Pred(mCharsetsCount) do
    begin
      mLastChar[i][0] := #0;
      mLastChar[i][1] := #0;
      if mDistributionAnalysis[i] <> nil then
        mDistributionAnalysis[i].Reset;
      if mContextAnalysis[i] <> nil then
        mContextAnalysis[i].Reset;
    end;
end;

end.
