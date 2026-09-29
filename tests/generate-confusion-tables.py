#!/usr/bin/env python3
"""Generate the byte-category and distinguishing-byte tables for Pascal."""

from pathlib import Path
import unicodedata


CODECS = (
    ("Windows1253", "cp1253"),
    ("ISO88597", "iso8859_7"),
    ("Windows1251", "cp1251"),
    ("MacCyrillic", "mac_cyrillic"),
)
PAIRS = (
    ("GreekDifference", "cp1253", "iso8859_7"),
    ("CyrillicDifference", "cp1251", "mac_cyrillic"),
)
CATEGORIES = {
    "Ll": 2,
    "Lu": 3,
    "Lt": 4,
    "Lm": 4,
    "Lo": 4,
    "Mn": 5,
    "Mc": 5,
    "Me": 5,
    "Ps": 6,
    "Pi": 6,
    "Pe": 7,
    "Pf": 7,
    "Pd": 8,
}
GROUPS = {"C": 0, "Z": 1, "P": 9, "S": 10, "N": 11}


def decoded(byte: int, codec: str) -> str | None:
    try:
        return bytes((byte,)).decode(codec)
    except UnicodeDecodeError:
        return None


def byte_category(byte: int, codec: str) -> int:
    value = decoded(byte, codec)
    if value is None:
        return 0
    category = unicodedata.category(value)
    return CATEGORIES.get(category, GROUPS.get(category[0], 0))


def generate() -> str:
    lines = [
        "{ Generated from Python 3 single-byte codecs and unicodedata.category.",
        "  SPDX-License-Identifier: Unicode-3.0",
        f"  Unicode Character Database version: {unicodedata.unidata_version}.",
        "  Unicode data license: LICENSES/Unicode-3.0.txt.",
        "  Categories: 0 control/undefined, 1 separator, 2 lower, 3 upper,",
        "  4 other letter, 5 mark, 6 opening punctuation, 7 closing punctuation,",
        "  8 dash, 9 other punctuation, 10 symbol, 11 number. }",
        "const",
    ]
    for name, codec in CODECS:
        values = [byte_category(byte, codec) for byte in range(256)]
        lines.append(f"  {name}Categories: array[Byte] of Byte = (")
        for start in range(0, 256, 16):
            chunk = ", ".join(str(value) for value in values[start : start + 16])
            suffix = "," if start < 240 else ""
            lines.append(f"    {chunk}{suffix}  // {start:02X}")
        lines.append("  );")
    for name, first, second in PAIRS:
        values = [
            f"${byte:02X}"
            for byte in range(256)
            if decoded(byte, first) is not None
            and decoded(byte, second) is not None
            and decoded(byte, first) != decoded(byte, second)
        ]
        lines.append(f"  {name}: set of Byte = [")
        for start in range(0, len(values), 12):
            chunk = ", ".join(values[start : start + 12])
            suffix = "," if start + 12 < len(values) else ""
            lines.append(f"    {chunk}{suffix}")
        lines.append("  ];")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    destination = Path(__file__).resolve().parent.parent / "src" / "CharsetConfusionTables.inc"
    destination.write_text(generate(), encoding="utf-8")
