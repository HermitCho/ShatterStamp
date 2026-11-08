"""게임용 한글 폰트 서브셋을 만든다.

Noto Sans KR 가변 폰트를 Bold(700)로 고정하고, ASCII 전체 + scripts/i18n.gd에 나오는
한글 글자만 남겨 assets/fonts/game_font.ttf로 저장한다. (웹 빌드 용량을 줄이기 위해)

사용법: python tools/build_font.py <NotoSansKR[wght].ttf 경로>
원본: https://github.com/google/fonts/tree/main/ofl/notosanskr (SIL Open Font License 1.1)
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "game_font.ttf"


def main() -> None:
    src = sys.argv[1]
    text = (ROOT / "scripts" / "i18n.gd").read_text(encoding="utf-8")
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars |= {ch for ch in text if ord(ch) > 0x7F}
    font = TTFont(src)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": 700})
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    sub = subset.Subsetter(opts)
    sub.populate(text="".join(sorted(chars)))
    sub.subset(font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    print(f"{len(chars)} chars -> {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
