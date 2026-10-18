
import hashlib
import json
import sys
from pathlib import Path

import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts"


def dart_strings(src: str) -> list[str]:
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            i = src.find("\n", i)
            i = n if i < 0 else i
        elif src.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if src.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif src.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif c in "'\"":
            raw = i > 0 and src[i - 1] == "r" and not (i > 1 and (src[i - 2].isalnum() or src[i - 2] == "_"))
            q = src[i : i + 3] if src.startswith(c * 3, i) else c
            i += len(q)
            buf = []
            while i < n and not src.startswith(q, i):
                if src[i] == "\\" and not raw:
                    nxt = src[i + 1 : i + 2]
                    if nxt == "u" and src[i + 2 : i + 3] == "{":
                        end = src.index("}", i)
                        buf.append(chr(int(src[i + 3 : end], 16)))
                        i = end + 1
                    elif nxt == "u":
                        buf.append(chr(int(src[i + 2 : i + 6], 16)))
                        i += 6
                    else:
                        buf.append(nxt)
                        i += 2
                else:
                    buf.append(src[i])
                    i += 1
            out.append("".join(buf))
            i += len(q)
        else:
            i += 1
    return out


def ui_chars() -> set[str]:
    text = []
    for arb in (ROOT / "lib" / "l10n").glob("app_*.arb"):
        data = json.loads(arb.read_text(encoding="utf-8"))
        text += [v for k, v in data.items() if not k.startswith("@")]
    for dart in (ROOT / "lib").rglob("*.dart"):
        if dart.name.startswith("app_localizations"):
            continue
        text += dart_strings(dart.read_text(encoding="utf-8"))
    return {c for c in "".join(text) if ord(c) >= 0x2E80}


def make(src: Path, chars: set[str], name: str) -> dict:
    font = TTFont(src)
    cmap = font.getBestCmap()
    keep = sorted(c for c in chars if ord(c) in cmap)
    opts = subset.Options()
    opts.hinting = False
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in keep])
    sub.subset(font)
    out = OUT / f"{name}.ttf"
    font.save(out)
    return {
        "file": out.name,
        "source": src.name,
        "source_sha256": hashlib.sha256(src.read_bytes()).hexdigest(),
        "chars": len(keep),
        "bytes": out.stat().st_size,
        "missing": "".join(sorted(chars - set(keep))),
    }


def main() -> None:
    tc_src, jp_src = map(Path, sys.argv[1:3])
    chars = ui_chars()
    tc = make(tc_src, chars, "NotoSansTC-UI")
    meta = {
        "fonttools": fontTools.version,
        "source_repo": "https://github.com/google/fonts",
        "total_chars": len(chars),
        "tc": tc,
        "jp": make(jp_src, set(tc["missing"]), "NotoSansJP-UI"),
    }
    (OUT / "ui_subset.meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({k: v if not isinstance(v, dict) else {kk: vv for kk, vv in v.items() if kk != "source_sha256"} for k, v in meta.items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
