#!/usr/bin/env python3
"""ModelCheck.ESCAPE_RANGES（エスケープ対象のコードポイントの範囲表）を生成して、src/core/model_check.gd に書き込む。

対象（チーム合意 T2-1）：
  一般カテゴリ Cc・Cf・Zl・Zp・Co、U+0020 以外の Zs、Default_Ignorable_Code_Point。

使い方：
  python3 scripts/gen_invisible_ranges.py <DerivedCoreProperties.txt のパス>
  DerivedCoreProperties.txt は https://www.unicode.org/Public/<版>/ucd/ から取る。
  一般カテゴリは Python の unicodedata から得る。unicodedata の版と DerivedCoreProperties.txt の版は同じにする。

ファイル中の BEGIN/END の印の間だけを書き換える。
"""
import re
import sys
import unicodedata

CATEGORIES = {"Cc", "Cf", "Zl", "Zp", "Co"}
BEGIN = "# BEGIN GENERATED ESCAPE_RANGES"
END = "# END GENERATED ESCAPE_RANGES"
TARGET = "src/core/model_check.gd"


def read_default_ignorable(path: str) -> tuple[set[int], str]:
    points: set[int] = set()
    version = ""
    with open(path, encoding="utf-8") as f:
        for line in f:
            if not version:
                m = re.match(r"#\s*DerivedCoreProperties-([\d.]+)\.txt", line)
                if m:
                    version = m.group(1)
            m = re.match(r"([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*Default_Ignorable_Code_Point\b", line)
            if m:
                lo = int(m.group(1), 16)
                hi = int(m.group(2), 16) if m.group(2) else lo
                points.update(range(lo, hi + 1))
    return points, version


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    ignorable, file_version = read_default_ignorable(sys.argv[1])
    if file_version != unicodedata.unidata_version:
        sys.exit("版が違う：DerivedCoreProperties %s、unicodedata %s" % (file_version, unicodedata.unidata_version))
    targets: set[int] = set(ignorable)
    for cp in range(0x110000):
        category = unicodedata.category(chr(cp))
        if category in CATEGORIES or (category == "Zs" and cp != 0x20):
            targets.add(cp)
    ranges: list[tuple[int, int]] = []
    for cp in sorted(targets):
        if ranges and ranges[-1][1] == cp - 1:
            ranges[-1] = (ranges[-1][0], cp)
        else:
            ranges.append((cp, cp))
    body = [
        BEGIN,
        "## Unicode %s。scripts/gen_invisible_ranges.py で生成した。手で書き換えない。" % file_version,
        "## 2つずつ組で、開始と終了（含む）のコードポイントを小さい順に並べる。",
        "const ESCAPE_RANGES: PackedInt32Array = [",
    ]
    for lo, hi in ranges:
        body.append("\t0x%04X, 0x%04X," % (lo, hi))
    body.append("]")
    body.append(END)
    with open(TARGET, encoding="utf-8") as f:
        text = f.read()
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(text):
        sys.exit("印が見つからない：" + TARGET)
    text = pattern.sub(lambda _: "\n".join(body), text)
    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(text)
    print("%d 範囲を書いた（Unicode %s）" % (len(ranges), file_version))


if __name__ == "__main__":
    main()
