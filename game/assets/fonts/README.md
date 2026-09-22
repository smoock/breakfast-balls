# Browser typography

These bundled fonts retain the clubhouse's serif headings, provide clear sans-serif controls, and render all of the game's arrow and symbol characters without relying on installed system fonts. Desktop typography is unchanged. The five TTF files total 294,956 bytes (288 KiB).

All fonts are distributed under the SIL Open Font License 1.1. Keep the accompanying license files and embedded copyright/license metadata with redistributions.

| File | Source and changes | License |
| --- | --- | --- |
| `LibreBaskerville.ttf` | [Official Google Fonts source](https://github.com/google/fonts/blob/main/ofl/librebaskerville/LibreBaskerville%5Bwght%5D.ttf), unmodified variable font; weight 700 selected at runtime | `LibreBaskerville-OFL.txt` |
| `NotoSans-Regular-Latin.ttf` | Latin and punctuation subset of [Noto Sans Regular](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf) | `NotoSans-OFL.txt` |
| `NotoSans-Bold-Latin.ttf` | Latin and punctuation subset of [Noto Sans Bold](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSans/NotoSans-Bold.ttf) | `NotoSans-OFL.txt` |
| `NotoSansMath-UI.ttf` | UI arrow and circle subset of [Noto Sans Math](https://github.com/google/fonts/blob/main/ofl/notosansmath/NotoSansMath-Regular.ttf) | `NotoSansMath-OFL.txt` |
| `NotoSansSymbols-UI.ttf` | Pause and flag subset of [Noto Sans Symbols](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSansSymbols/NotoSansSymbols-Regular.ttf) | `NotoSans-OFL.txt` |

Noto Sans copyright: Copyright 2015–2021 Google LLC. All Rights Reserved. Noto Sans Symbols copyright: Copyright 2016 Google LLC. All Rights Reserved. The source repository's `LICENSE` is retained as `NotoSans-OFL.txt`; the exact font copyright notices are also retained in each subset's name table. The unmodified Libre Baskerville file retains its reserved family name.

To reproduce the subsets, install FontTools 4.60.2 in a development environment, download the four Noto source TTFs to a temporary directory using their original filenames, then run:

```sh
python3 game/assets/fonts/build_subsets.py /path/to/font-sources
```

The script keeps Latin U+0020–007E, U+00A0–017F and punctuation U+2000–206F where present. Two small fallback fonts supply `← ↑ → ↓ ↵ ● ◯ − Ⅱ ⚑`. Copyright and licensing name-table records are preserved. No glyph outlines are changed.

Source SHA-256 hashes, downloaded September 21, 2026:

```text
b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5  NotoSans-Regular.ttf
c976e4b1b99edc88775377fcc21692ca4bfa46b6d6ca6522bfda505b28ff9d6a  NotoSans-Bold.ttf
3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d  NotoSansMath-Regular.ttf
8f02f31959bbdf6061547a188248e13f84dc5fdd940326ec494675f453f072bb  NotoSansSymbols-Regular.ttf
05a95421961341c5b2556285e8415df9db27dab4f4abe22b446b3c6a8b916c5d  LibreBaskerville.ttf
```
