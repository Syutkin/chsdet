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
vowel points absent from ISO-8859-8. Every recognition assertion expects the
exact charset named by the fixture; alternative results are test failures.
UTF-16 without a BOM is also expected to be recognized as the exact UTF-16
byte order.
