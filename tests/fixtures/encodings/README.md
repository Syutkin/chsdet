# Encoding fixtures

Each fixture contains one short pangram followed by one line ending. Every
supported encoding has separate `lf` and `crlf` variants. UTF-8, UTF-16LE,
and UTF-16BE also have explicit `bom` variants for both line endings.

Every variant also has a `long` counterpart containing three lines from a
classic work:

- Russian and Unicode: Leo Tolstoy, *Anna Karenina*.
- English: Charles Dickens, *A Tale of Two Cities*.
- French: Victor Hugo, *Les Misérables*.
- Greek: Homer, *Iliad* (polytonic marks removed for the codepage repertoire).
- Hebrew: *Genesis*.

The UTF-8, UTF-16LE, and UTF-16BE groups contain all five languages and use the
language suffixes `ru`, `en`, `fr`, `el`, and `he`. Each language has short and
long, LF and CRLF, BOM and no-BOM variants.

The fixture files are marked as binary in `.gitattributes` so Git does not alter
their byte encoding or line endings.

The Russian pangram is used for Cyrillic encodings. UTF-8 English contains
non-ASCII typographic punctuation. Windows-1253 contains Greek characters
whose byte positions differ from ISO-8859-7, and Windows-1255 contains Hebrew
vowel points absent from ISO-8859-8. The four exact-label ISO-8859-8 fixtures
contain byte DF (double low line), which Windows-1255 cannot decode.
Recognition assertions expect the exact charset named by the fixture, except
for four `iso-8859-8-shared` fixtures containing only the shared ASCII/Hebrew-
letter repertoire: the legacy API may report ISO-8859-8 or Windows-1255
because both decode those bytes to the same text.
The original exact-label assertions remain available with
`CHSDET_STRICT_FIXTURES=1`; see [test policy](../../README.md).
UTF-16 without a BOM is expected to be recognized as the exact byte order.
