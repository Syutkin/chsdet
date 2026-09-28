# Encoding fixtures

The 216 fixtures cover every public charset name. Each encoding has short and
long, LF and CRLF variants. Every fixture must match its exact charset label
and BOM result. The files are marked as binary in `.gitattributes` so Git does
not change their bytes or line endings.

Short fixtures contain a pangram or sentence followed by one line ending.
Long fixtures contain three lines. The texts include passages from:

- Russian and Unicode: Leo Tolstoy, *Anna Karenina*.
- English: Charles Dickens, *A Tale of Two Cities*.
- French: Victor Hugo, *Les Misérables*.
- Greek: Homer, *Iliad* (polytonic marks removed for the code-page repertoire).
- Hebrew: *Genesis*.

Russian text is used for Cyrillic encodings; Japanese, Korean, traditional
Chinese and simplified Chinese use fixed sentences. UTF-8 English contains
non-ASCII typographic punctuation. Windows-1253 contains Greek characters
whose byte positions differ from ISO-8859-7, and Windows-1255 contains Hebrew
vowel points.

The UTF-8, UTF-16LE and UTF-16BE groups contain all five languages with the
suffixes `ru`, `en`, `fr`, `el` and `he`. Each language has short and long,
LF and CRLF, BOM and no-BOM variants. UTF-16 without a BOM is expected to be
recognized in its exact byte order. UTF-32LE and UTF-32BE use mixed-language
text and always have a BOM.

`tests/audit-fixtures.py` verifies decoding, line endings and hashes. It uses
Python standard codecs and `iconv` for EUC-TW and ISO-2022-CN.
