"""Compose QA screenshots only; never modifies production art."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "build" / "qa" / "vine-attack"
FONT_PATH = Path("C:/Windows/Fonts/arial.ttf")
font = ImageFont.truetype(str(FONT_PATH), 25) if FONT_PATH.exists() else ImageFont.load_default(size=25)
small = ImageFont.truetype(str(FONT_PATH), 19) if FONT_PATH.exists() else ImageFont.load_default(size=19)
bg = (243, 238, 217)
ink = (31, 60, 42)
phases = ["prepare", "strike", "recoil"]
crop = (445, 335, 835, 540)
width, height = 390 * 2, 205 * 2
sheet = Image.new("RGB", (width * 3, 100 + (height + 42) * 4 + 44), bg)
draw = ImageDraw.Draw(sheet)
draw.text((24, 15), "Vine attack - production camera comparison", font=font, fill=ink)
draw.text((24, 52), "2.1 camera zoom, 1280 x 720 capture. Crops shown at 2x; new FlowerLight disabled for comparison.", font=small, fill=ink)
rows = [("humanoid", "light_1", "before", "Humanoid - BEFORE"), ("humanoid", "light_1", "after_same_light", "Humanoid - AFTER"), ("mature", "heavy", "before", "Mature - BEFORE"), ("mature", "heavy", "after_same_light", "Mature - AFTER")]
for row, (form, action, directory, label) in enumerate(rows):
    y = 100 + row * (height + 42)
    for col, phase in enumerate(phases):
        image = Image.open(QA / directory / f"{form}_{action}_right_{phase}.webp").convert("RGB")
        sheet.paste(image.crop(crop).resize((width, height), Image.Resampling.LANCZOS), (col * width, y + 36))
        draw.text((col * width + 14, y + 4), f"{label} / {phase}", font=font, fill=ink)
draw.text((24, sheet.height - 34), "Timeline samples use authored attack timings; this sheet does not substitute for normal-speed playback or a blind player review.", font=small, fill=ink)
sheet.save(QA / "before_after.webp", quality=94)
full = Image.new("RGB", (2560, 1520), bg)
full_draw = ImageDraw.Draw(full)
for row, (form, action) in enumerate([("humanoid", "light_1"), ("mature", "heavy")]):
    for col, directory in enumerate(["before", "after_same_light"]):
        full_draw.text((col * 1280 + 20, row * 760 + 8), f"{form} / {action} / {'BEFORE' if col == 0 else 'AFTER (FlowerLight off)'}", font=font, fill=ink)
        full.paste(Image.open(QA / directory / f"{form}_{action}_right_strike.webp").convert("RGB"), (col * 1280, row * 760 + 40))
full.save(QA / "before_after_full.webp", quality=93)
print(QA / "before_after.webp")
print(QA / "before_after_full.webp")
