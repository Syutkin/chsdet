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
// $Id: nsEscCharsetProber.pas,v 1.4 2013/04/23 19:47:10 ya_nick Exp $

unit nsEscCharsetProber;

interface

uses
	nsCore,
	MultiModelProber;

type
	TnsEscCharSetProber = class (TMultiModelProber)
		private
      mIso2022CnSequence: array [0..3] of AnsiChar;
      mIso2022CnSequenceLength: Integer;
      function IsIso2022CnDesignator: Boolean;
      function IsIso2022CnEnabled: Boolean;
		public
    	constructor Create; override;
      function HandleData(aBuf: pAnsiChar; aLen: integer): eProbingState; override;
      procedure Reset; override;
      function GetConfidence: float; override;
  end;


implementation
uses
  nsCodingStateMachine,
  CustomDetector;
  
{$I '.\mbclass\ISO2022KRLangModel.inc'}
{$I '.\mbclass\ISO2022JPLangModel.inc'}
{$I '.\mbclass\ISO2022CNLangModel.inc'}
{$I '.\mbclass\HZLangModel.inc'}

{ TnsEscCharSetProber }
const
	NUM_OF_ESC_CHARSETS = 4;

constructor TnsEscCharSetProber.Create;
begin
  inherited;
  AddCharsetModel(HZSMModel);
  AddCharsetModel(ISO2022CNSMModel);
  AddCharsetModel(ISO2022JPSMModel);
  AddCharsetModel(ISO2022KRSMModel);
  Reset;
end;

function TnsEscCharSetProber.IsIso2022CnDesignator: Boolean;
begin
  Result := False;
  if (mIso2022CnSequence[0] <> #$1B) or
     (mIso2022CnSequence[1] <> '$') then
    Exit;

  case mIso2022CnSequence[2] of
    ')': Result := mIso2022CnSequence[3] in ['A', 'E', 'G'];
    '*': Result := mIso2022CnSequence[3] = 'H';
    '+': Result := mIso2022CnSequence[3] in ['I', 'J', 'K', 'L', 'M'];
  end;
end;

function TnsEscCharSetProber.IsIso2022CnEnabled: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(mCharsetsCount) do
    if mCodingSM[i].GetCharsetID = ISO_2022_CN_CHARSET then
      begin
        Result := mCodingSM[i].Enabled;
        Exit;
      end;
end;

function TnsEscCharSetProber.HandleData(aBuf: pAnsiChar;
  aLen: integer): eProbingState;
var
  i: Integer;
begin
  if mState <> psDetecting then
    Exit(mState);
  for i := 0 to Pred(aLen) do
    begin
      if mIso2022CnSequenceLength < Length(mIso2022CnSequence) then
        begin
          mIso2022CnSequence[mIso2022CnSequenceLength] := aBuf[i];
          Inc(mIso2022CnSequenceLength);
        end
      else
        begin
          Move(mIso2022CnSequence[1], mIso2022CnSequence[0], 3);
          mIso2022CnSequence[3] := aBuf[i];
        end;

      if (mIso2022CnSequenceLength = Length(mIso2022CnSequence)) and
         IsIso2022CnEnabled and IsIso2022CnDesignator then
        begin
          mDetectedCharset := ISO_2022_CN_CHARSET;
          mState := psFoundIt;
          Result := mState;
          Exit;
        end;
    end;

  Result := inherited HandleData(aBuf, aLen);
end;

procedure TnsEscCharSetProber.Reset;
begin
  inherited Reset;
  mIso2022CnSequenceLength := 0;
end;

function TnsEscCharSetProber.GetConfidence: float;
begin
  case mState of
    psFoundIt:   Result := SURE_YES;
    psNotMe:     Result := SURE_NO;
    psDetecting: Result := (SURE_YES + SURE_NO) / 2;
    else
      Result := 1.1 * SURE_NO;
  end;
end;

end.
