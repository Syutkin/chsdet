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
// $Id: nsCore.pas,v 1.5 2013/04/23 19:47:10 ya_nick Exp $

unit nsCore;

interface

type
  int16 = smallint;
  int32 = integer;
  uInt32 = cardinal;

  aByteArray = array of Byte;
  puInt32 = ^uInt32;
  auInt32 = array of uInt32;

  pInt16 = ^int16;
  aInt16 = array of int16;

const
  SURE_YES: double = 0.99;
  SURE_NO: double  = 0.01;
const
	ENOUGH_DATA_THRESHOLD: cardinal = 1024;
	SHORTCUT_THRESHOLD = 0.95;

type
  eProbingState = (
    psDetecting = 0,   //We are still detecting, no sure answer yet, but caller can ask for confidence.
    psFoundIt   = 1,   //That's a positive answer
    psNotMe     = 2    //Negative answer
	);

type
	nsResult = uInt32;
const
  NS_OK = 0;
  NS_ERROR_OUT_OF_MEMORY = $8007000e;

type
	float = double;

  rAboutHolder = record
    MajorVersionNr: Cardinal;
    MinorVersionNr: Cardinal;
    BuildVersionNr: Cardinal;
    About: pChar;
  end;

  eBOMKind = (
    BOM_Not_Found,
    BOM_UCS4_BE,    // 00 00 FE FF           UTF-32, big-endian
    BOM_UCS4_LE,    // FF FE 00 00           UTF-32, little-endian
    BOM_UTF16_BE,   // FE FF ## ##           UTF-16,   big-endian
    BOM_UTF16_LE,   // FF FE ## ##           UTF-16,   little-endian
    BOM_UTF8        // EF BB BF              UTF-8
  );

  rBOMDef = record
    Length: integer;
    BOM: array [0..3] of AnsiChar;
  end;
const
  KNOWN_BOM: array [eBOMKind] of rBOMDef = (
    (Length: 00; BOM: (#$00, #$00, #$00, #$00)),
    (Length: 04; BOM: (#$00, #$00, #$FE, #$FF)),
    (Length: 04; BOM: (#$FF, #$FE, #$00, #$00)),
    (Length: 02; BOM: (#$FE, #$FF, #$00, #$00)),
    (Length: 02; BOM: (#$FF, #$FE, #$00, #$00)),
    (Length: 03; BOM: (#$EF, #$BB, #$BF, #$00))
  );

// "extended" charset info
type
  rCharsetInfo = record
    Name: PAnsiChar;
    CodePage: Integer;
    Language: PAnsiChar;
  end;

  eInternalCharsetID = (
    UNKNOWN_CHARSET,
    PURE_ASCII_CHARSET,
    UTF8_CHARSET,
    UTF16_BE_CHARSET,
    UTF32_BE_CHARSET,
    UTF32_LE_CHARSET,
    UTF16_LE_CHARSET,
    LATIN5_BULGARIAN_CHARSET,
    WINDOWS_BULGARIAN_CHARSET,
    KOI8_R_CHARSET,
    WINDOWS_1251_CHARSET,
    ISO_8859_5_CHARSET,
    X_MAC_CYRILLIC_CHARSET,
    IBM866_CHARSET,
    IBM855_CHARSET,
    ISO_8859_7_CHARSET,
    WINDOWS_1253_CHARSET,
    ISO_8859_8_CHARSET,
    WINDOWS_1255_CHARSET,
    BIG5_CHARSET,
    ISO_2022_CN_CHARSET,
    ISO_2022_JP_CHARSET,
    ISO_2022_KR_CHARSET,
    EUC_JP_CHARSET,
    EUC_KR_CHARSET,
    X_EUC_TW_CHARSET,
    SHIFT_JIS_CHARSET,
    GB18030_CHARSET,
    HZ_GB_2312_CHARSET,
    WINDOWS_1252_CHARSET,
    WINDOWS_1250_CHARSET
  );

  TInternalCharsetSet = set of eInternalCharsetID;

  TCharsetModelScore = record
    CharsetID: eInternalCharsetID;
    Confidence: float;
    State: eProbingState;
  end;
  TCharsetModelScores = array of TCharsetModelScore;

const
  KNOWN_CHARSETS: array [eInternalCharsetID] of rCharsetInfo = (
	// UNKNOWN_CHARSET
    (
      Name: 'Unknown';
      CodePage: -1;
      Language: 'Unknown'
    ),
  // PURE_ASCII_CHARSET
    (
      Name: 'ASCII';
      CodePage: 0;
      Language: 'ASCII'
    ),
  // UTF8_CHARSET
    (
      Name: 'UTF-8';
      CodePage: 65001;
      Language: 'Unicode'
    ),
  // UTF16_BE_CHARSET
    (
      Name: 'UTF-16BE';
      CodePage: 1201;
      Language: 'Unicode'
    ),
  // UTF32_BE_CHARSET
    (
      Name: 'UTF-32BE';
      CodePage: 12001;
      Language: 'Unicode'
    ),
  // UTF32_LE_CHARSET
    (
      Name: 'UTF-32LE';
      CodePage: 12000;
      Language: 'Unicode'
    ),
  // UTF16_LE_CHARSET
    (
      Name: 'UTF-16LE';
      CodePage: 1200;
      Language: 'Unicode'
    ),
	// LATIN5_BULGARIAN_CHARSET
    (
      Name: 'ISO-8859-5';
      CodePage: 28595;
      Language: 'Bulgarian'
    ),
  // WINDOWS_BULGARIAN_CHARSET
    (
      Name: 'windows-1251';
      CodePage: 1251;
      Language: 'Bulgarian'
    ),
  // KOI8_R_CHARSET
    (
      Name: 'KOI8-R';
      CodePage: 20866;
      Language: 'russian'
    ),
  // WINDOWS_1251_CHARSET
    (
      Name: 'windows-1251';
      CodePage: 1251;
      Language: 'russian'
    ),
  // ISO_8859_5_CHARSET
    (
      Name: 'ISO-8859-5';
      CodePage: 28595;
      Language: 'russian'
    ),
  // X_MAC_CYRILLIC_CHARSET
    (
      Name: 'x-mac-cyrillic';
      CodePage: 10007;
      Language: 'russian'
    ),
  // IBM866_CHARSET
    (
      Name: 'IBM866';
      CodePage: 866;
      Language: 'russian'
    ),
  // IBM855_CHARSET
    (
      Name: 'IBM855';
      CodePage: 855;
      Language: 'russian'
    ),
  //  ISO_8859_7_CHARSET
    (
      Name: 'ISO-8859-7';
      CodePage: 28597;
      Language: 'greek'
    ),
  // WINDOWS_1253_CHARSET
    (
      Name: 'windows-1253';
      CodePage: 1253;
      Language: 'greek'
    ),
  // ISO_8859_8_CHARSET
    (
      Name: 'ISO-8859-8';
      CodePage: 28598;
      Language: 'hebrew'
    ),
  // WINDOWS_1255_CHARSET
    (
      Name: 'windows-1255';
      CodePage: 1255;
      Language: 'hebrew'
    ),
  // BIG5_CHARSET
    (
      Name: 'Big5';
      CodePage: 950;
      Language: 'ch'
       ),
  // ISO_2022_CN_CHARSET
    (
      Name:  'ISO-2022-CN';
      CodePage:  50227;
      Language:  'ch';
      ),
  // ISO_2022_JP_CHARSET
    (
      Name:  'ISO-2022-JP';
      CodePage:  50222;
      Language:  'japanese';
    ),
  // ISO_2022_KR_CHARSET
    (
      Name:  'ISO-2022-KR';
      CodePage:  50225;
      Language:  'kr';
    ),
  // EUC_JP_CHARSET
    (
      Name:  'EUC-JP';
      CodePage:  51932;
      Language:  'japanese';
    ),
  // EUC_KR_CHARSET
    (
      Name:  'EUC-KR';
      CodePage:  51949;
      Language:  'kr';
    ),
  // X_EUC_TW_CHARSET
    (
      Name:  'x-euc-tw';
      CodePage:  51936;
      Language:  'ch';
    ),
  // SHIFT_JIS_CHARSET
    (
      Name:  'Shift_JIS';
      CodePage:  932;
      Language:  'japanese';
    ),
  // GB18030_CHARSET
    (
      Name:  'GB18030';
      CodePage:  54936;
      Language:  'ch';
    ),
  // HZ_GB_2312_CHARSET
    (
      Name:  'HZ-GB-2312';
      CodePage:  52936;
      Language:  'ch';
    ),
  // WINDOWS_1252_CHARSET
    (
      Name:  'windows-1252';
      CodePage:  1252;
      Language:  'eu';
    ),
  // WINDOWS_1250_CHARSET
    (
      Name:  'windows-1250';
      CodePage:  1250;
      Language:  'Central European';
    )

  );

  (* Helper functions used in the Latin1 and Group probers.*)
  (* both functions Allocate a new buffer for newBuf. This buffer should be *)
  (* freed by the caller using PR_FREEIF.*)
  (* Both functions return PR_FALSE in case of memory allocation failure.*)
  function FilterWithoutEnglishLetters(aBuf: pAnsiChar;  aLen: integer; var newBuf: pAnsiChar; var newLen: integer): Boolean;
  function FilterWithEnglishLetters(aBuf: pAnsiChar;  aLen: integer; var newBuf: pAnsiChar; var newLen: integer): Boolean;
implementation

function FilterWithEnglishLetters(aBuf: pAnsiChar;
  aLen: integer; var newBuf: pAnsiChar; var newLen: integer): Boolean;
var
  newptr: pAnsiChar;
  prevPtr: pAnsiChar;
  curPtr: pAnsiChar;
  isInTag: Boolean;
begin
  //do filtering to reduce load to probers
  isInTag := FALSE;
  newLen := 0;

  newptr := newBuf;
  if (newptr = nil) then
  	begin
    	Result := FALSE;
      exit;
    end;

  prevPtr := aBuf;
  curPtr := prevPtr;
  while (curPtr < aBuf+aLen) do
  begin
    if (curPtr^ = '>') then
      isInTag := FALSE
    else
    	if (curPtr^ = '<') then
      	isInTag := TRUE;

    if ((curPtr^ < #$80) and
        ((curPtr^ < 'A') or ((curPtr^ > 'Z') and (curPtr^ < 'a')) or (curPtr^ > 'z')) ) then
      begin
        if ((curPtr > prevPtr) and (not isInTag)) then 	// Current segment contains more than just a symbol
                               		           		 				// and it is not inside a tag, keep it.
          begin
            while (prevPtr < curPtr) do
            	begin
              	newptr^ := prevPtr^;
              	inc(newptr);
              	inc(prevPtr);
              end;
            inc(prevPtr);
            newptr^ := ' ';
            inc(newptr);
          end
        else
          prevPtr := curPtr+1;
      end;
  	inc(curPtr);
  end;

  // If the current segment contains more than just a symbol
  // and it is not inside a tag then keep it.
  if ( not isInTag) then
    while (prevPtr < curPtr) do
    	begin
        newptr^ := prevPtr^;
        inc(newptr);
        inc(prevPtr);
      end;

  newLen := newptr - newBuf;

  Result := TRUE;
end;

function FilterWithoutEnglishLetters(aBuf: pAnsiChar;
  aLen: integer; var newBuf: pAnsiChar; var newLen: integer): Boolean;
var
	newPtr: pAnsiChar;
  prevPtr: pAnsiChar;
  curPtr: pAnsiChar;
  meetMSB: Boolean;
begin
(*This filter applies to all scripts which do not use English characters*)
	Result := FALSE;
  newLen := 0;
  meetMSB:= FALSE;

  if newBuf = nil then
    exit;

  newPtr := newBuf;
  curPtr := aBuf;
  prevPtr := curPtr;

  while curPtr < aBuf+aLen do
    begin
      if curPtr^ > #$80 then
        meetMSB := TRUE
      else
        if ((curPtr^ < 'A') or ((curPtr^ > 'Z') and (curPtr^ < 'a')) or (curPtr^ > 'z')) then
          begin
            //current char is a symbol, most likely a punctuation. we treat it as segment delimiter
            if (meetMSB and (curPtr > prevPtr)) then
            //this segment contains more than single symbol, and it has upper ASCII, we need to keep it
              begin
                while (prevPtr < curPtr) do
                  begin
                    newptr^ := prevPtr^;
                    inc(newptr);
                    inc(prevPtr);
                  end;
                inc(prevPtr);
                newptr^ := ' ';
                inc(newptr);
                meetMSB := FALSE;
            	end
          	else //ignore current segment. (either because it is just a symbol or just an English word)
            	prevPtr := curPtr+1;
         end;
      inc(curPtr);
    end;
  if (meetMSB and (curPtr > prevPtr)) then
    while (prevPtr < curPtr) do
    	begin
        newptr^ := prevPtr^;
        inc(newptr);
        inc(prevPtr);
      end;

  newLen := newptr - newBuf;

  Result := TRUE;
end;

end.
