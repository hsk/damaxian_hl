#!/usr/bin/env python3
"""SDCC の pattern.c / bg.c の表を、hlang の pattern.hl / bg.hl に写す（元のファイルと 1 対 1）。"""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "orig" / "damaxian_msx" / "sources"
OUT = Path(__file__).resolve().parents[1]


def array(file, name, kind):
    text = re.sub(r"//.*", "", (SOURCE / file).read_text())
    m = re.search(rf"(?:static\s+)?const\s+{kind}\s+const\s+{name}\[\]\s*=\s*\{{(.*?)\}};", text, re.S)
    if not m:
        raise ValueError(f"{name} が {file} にない")
    return [int(t, 0) for t in re.findall(r"0[xX][0-9a-fA-F]+|\b\d+\b", m.group(1))]


def render(name, kind, values, width=16):
    rows = [f"data {name}: {kind} = ["]
    for i in range(0, len(values), width):
        rows.append("  " + ", ".join(f"0x{v:02x}" if kind == "u8" else f"0x{v:04x}" for v in values[i:i + width]) + ",")
    rows.append("]")
    return "\n".join(rows)


files = {
    "pattern.hl": ("pattern.c", [("pattern", "pattern"), ("spritePattern", "spritePattern")]),
    "bg.hl": ("bg.c", [("bg", "bg"), ("logoPatternNameTable", "logoPatternNameTable"),
                       ("messagePatternNameTable", "messagePatternNameTable"),
                       ("enemyPointTable", "enemyPointTable")]),
}
for out, (src, tables) in files.items():
    body = [f"// {out} : {src} の写し（tools/import_assets.py で作る）"]
    body += [render(name, "u8", array(src, sym, "u8")) for name, sym in tables]
    (OUT / out).write_text("\n\n".join(body) + "\n")
    print("wrote", out)
