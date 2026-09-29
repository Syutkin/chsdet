unit CharsetByteValidity;

{$mode ObjFPC}{$H+}

interface

uses
  nsCore;

type
  TCharsetSeenBytes = set of Byte;

function SingleByteCharsetCanDecode(aCharset: eInternalCharsetID;
  const aSeenBytes: TCharsetSeenBytes): Boolean;

implementation

function SingleByteCharsetCanDecode(aCharset: eInternalCharsetID;
  const aSeenBytes: TCharsetSeenBytes): Boolean;
const
  { Undefined positions in the corresponding strict single-byte codec maps. }
  ISO88597Undefined: TCharsetSeenBytes = [$AE, $D2, $FF];
  Windows1253Undefined: TCharsetSeenBytes =
    [$81, $88, $8A, $8C..$90, $98, $9A, $9C..$9F, $AA, $D2, $FF];
  ISO88598Undefined: TCharsetSeenBytes =
    [$A1, $BF, $C0..$DE, $FB, $FC, $FF];
  Windows1255Undefined: TCharsetSeenBytes =
    [$81, $8A, $8C..$90, $9A, $9C..$9F, $CA, $D9..$DF,
     $FB, $FC, $FF];
  Windows1251Undefined: TCharsetSeenBytes = [$98];
  Windows1252Undefined: TCharsetSeenBytes = [$81, $8D, $8F, $90, $9D];
  Windows1250Undefined: TCharsetSeenBytes = [$81, $83, $88, $90, $98];
begin
  case aCharset of
    ISO_8859_7_CHARSET:
      Result := (aSeenBytes * ISO88597Undefined) = [];
    WINDOWS_1253_CHARSET:
      Result := (aSeenBytes * Windows1253Undefined) = [];
    ISO_8859_8_CHARSET:
      Result := (aSeenBytes * ISO88598Undefined) = [];
    WINDOWS_1255_CHARSET:
      Result := (aSeenBytes * Windows1255Undefined) = [];
    WINDOWS_1251_CHARSET, WINDOWS_BULGARIAN_CHARSET:
      Result := (aSeenBytes * Windows1251Undefined) = [];
    WINDOWS_1252_CHARSET:
      Result := (aSeenBytes * Windows1252Undefined) = [];
    WINDOWS_1250_CHARSET:
      Result := (aSeenBytes * Windows1250Undefined) = [];
    else
      { The remaining supported single-byte codecs map all 256 bytes.
        Multi-byte encodings are checked by their existing state machines. }
      Result := True;
  end;
end;

end.
