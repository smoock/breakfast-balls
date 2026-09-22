"""Rebuild the small OFL Noto subsets; see README.md for sources and licensing."""
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

source_dir = Path(sys.argv[1])
output_dir = Path(__file__).resolve().parent
latin = set(range(0x20, 0x7F)) | set(range(0xA0, 0x180)) | set(range(0x2000, 0x2070))
symbols = set(map(ord, "←↑→↓↵●◯−"))
basic_symbols = set(map(ord, "Ⅱ⚑"))

for source, target, characters in [
    ("NotoSans-Regular.ttf", "NotoSans-Regular-Latin.ttf", latin),
    ("NotoSans-Bold.ttf", "NotoSans-Bold-Latin.ttf", latin),
    ("NotoSansMath-Regular.ttf", "NotoSansMath-UI.ttf", symbols),
    ("NotoSansSymbols-Regular.ttf", "NotoSansSymbols-UI.ttf", basic_symbols),
]:
    font = TTFont(source_dir / source, recalcTimestamp=False)
    options = subset.Options()
    options.name_IDs = ["*"]  # Keep copyright, license, and source attribution.
    options.name_languages = ["*"]
    options.name_legacy = True
    sub = subset.Subsetter(options=options)
    sub.populate(unicodes=characters)
    sub.subset(font)
    font.save(output_dir / target)
    print(target, (output_dir / target).stat().st_size)
