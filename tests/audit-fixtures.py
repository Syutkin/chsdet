#!/usr/bin/env python3
"""Audit the checked-in fixture bytes independently of the detector (Python stdlib)."""

import argparse
import csv
import hashlib
import subprocess
from pathlib import Path


def audit(root):
    rows = []
    by_hash = {}
    for path in sorted(root.glob("*.txt")):
        data = path.read_bytes()
        stem = path.name
        codecs = {
            "windows-1251": "cp1251", "windows-1252": "cp1252",
            "windows-1253": "cp1253", "windows-1255": "cp1255",
            "iso-8859-5": "iso8859_5", "iso-8859-7": "iso8859_7",
            "iso-8859-8": "iso8859_8", "ibm866": "cp866",
            "ibm855": "cp855", "x-mac-cyrillic": "mac_cyrillic",
            "shift-jis": "shift_jis", "big5": "big5",
            "gb18030": "gb18030", "euc-jp": "euc_jp",
            "euc-kr": "euc_kr", "x-euc-tw": "EUC-TW",
            "iso-2022-jp": "iso2022_jp", "iso-2022-kr": "iso2022_kr",
            "iso-2022-cn": "ISO-2022-CN", "hz-gb-2312": "hz",
            "koi8-r": "koi8_r", "ascii": "ascii",
            "utf-16le": "utf-16-le", "utf-16be": "utf-16-be",
            "utf-32le": "utf-32", "utf-32be": "utf-32",
            "utf-8": "utf-8",
        }
        codec = next(value for key, value in codecs.items()
                     if stem.startswith(key + "-"))
        if codec in ("EUC-TW", "ISO-2022-CN"):
            decoded = subprocess.run(
                ["iconv", "-f", codec, "-t", "UTF-8"],
                input=data, capture_output=True, check=True,
            ).stdout.decode("utf-8")
        else:
            decoded = data.decode(codec, errors="strict")
        if stem.endswith("-crlf.txt"):
            lf_path = root / stem.replace("-crlf.txt", "-lf.txt")
            lf_data = lf_path.read_bytes()
            if codec in ("EUC-TW", "ISO-2022-CN"):
                lf_decoded = subprocess.run(
                    ["iconv", "-f", codec, "-t", "UTF-8"],
                    input=lf_data, capture_output=True, check=True,
                ).stdout.decode("utf-8")
            else:
                lf_decoded = lf_data.decode(codec, errors="strict")
            if decoded.replace("\r\n", "\n") != lf_decoded:
                raise ValueError(f"LF/CRLF text differs: {stem}")
        if stem.startswith("iso-8859-8-"):
            try:
                data.decode("cp1255", errors="strict")
            except UnicodeDecodeError:
                pass
            else:
                raise ValueError(f"ISO-8859-8 bytes also decode as Windows-1255: {stem}")
        digest = hashlib.sha256(data).hexdigest()
        by_hash.setdefault(digest, []).append(stem)
        rows.append((stem, len(data), digest, codec))
    if not rows:
        raise ValueError(f"No fixtures found in {root}")
    return rows, [names for names in by_hash.values() if len(names) > 1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows, duplicates = audit(Path(__file__).resolve().parent / "fixtures/encodings")
    with args.output.open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, delimiter="\t", lineterminator="\n")
        writer.writerow(("fixture", "bytes", "sha256", "codec"))
        writer.writerows(rows)
    print(f"Fixtures: {len(rows)}; identical-byte groups: {len(duplicates)}")
    for names in duplicates:
        print("Identical bytes: " + ", ".join(names))


if __name__ == "__main__":
    main()
