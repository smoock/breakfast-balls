"""Assemble unmodified Godot captures for inspecting all holes side by side."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

folder = Path(sys.argv[1])
for kind in ['green', 'bunker', 'fairway', 'water', 'play', 'sand', 'lip', 'creek', 'swing']:
    pattern = 'swing-*.png' if kind == 'swing' else '*-' + kind + ('-*.png' if kind in ['sand', 'lip'] else '.png')
    files = sorted(folder.glob(pattern))
    for start in range(0, len(files), 6):
        batch = files[start:start + 6]
        sheet = Image.new('RGB', (1440, 476 * ((len(batch) + 1) // 2)), '#142c24')
        draw = ImageDraw.Draw(sheet)
        for n, path in enumerate(batch):
            frame = Image.open(path).convert('RGB')
            frame.thumbnail((720, 450))
            x, y = (n % 2) * 720, (n // 2) * 476
            sheet.paste(frame, (x, y + 26))
            draw.text((x + 12, y + 8), path.stem, fill='white')
        sheet.save(folder / (kind + '-sheet-' + str(start // 6 + 1) + '.jpg'), quality=92)
motion = sorted((folder / 'motion').glob('*.png'))
if motion:
    frames = []
    for path in motion:
        frame = Image.open(path).convert('RGB')
        frame.thumbnail((800, 500))
        frames.append(frame.quantize(colors=128))
    frames[0].save(folder / 'swing.gif', save_all=True, append_images=frames[1:], duration=20, loop=0)
