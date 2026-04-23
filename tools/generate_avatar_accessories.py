#!/usr/bin/env python3
"""Generate media/avatar_head_accessories.png

Spec: 1024×1280, 4 cols × 5 rows, 256×256/tile, white-on-transparent silhouettes.
Designed to overlay on avatar_faceshapes.png (same tile grid, same anchor points).

Head positioning reference (from faceshapes.png inspection):
  head top (no tall hair): y≈55
  head top (tall hair/afro): y≈30
  head center X: 128
  head x-range at crown: ~x=63..193
  ear-level Y: ~y=105
  head bottom Y: ~y=210

Run from repo root:
  python3 tools/generate_avatar_accessories.py
"""

import math
import os
from PIL import Image, ImageDraw

COLS, ROWS = 4, 5
TILE = 256
W = COLS * TILE   # 1024
H = ROWS * TILE   # 1280
WHITE = (255, 255, 255, 255)

# Shared head-geometry constants (calibrated to avatar_faceshapes.png)
CX = 128          # head center X
REST_Y = 55       # where a flat hat brim rests on the head top
EAR_Y = 105       # approximate ear / side-of-head level
HEAD_L = 63       # left edge of head at crown
HEAD_R = 193      # right edge of head at crown


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def new_tile():
    return Image.new('RGBA', (TILE, TILE), (0, 0, 0, 0))

def paste_tile(sheet, tile, col, row):
    sheet.paste(tile, (col * TILE, row * TILE))


# ---------------------------------------------------------------------------
# Individual accessory drawing functions
# Each receives an ImageDraw.Draw on a blank 256×256 RGBA tile.
# ---------------------------------------------------------------------------

def draw_none(d):
    """Slot 0 — no accessory (fully transparent)."""
    pass


def draw_crown(d):
    """5-point crown sitting at head top."""
    by = REST_Y           # band top-y
    bh = 20               # band height
    # Base band
    d.rectangle([HEAD_L, by, HEAD_R, by + bh], fill=WHITE)
    # Central spike
    d.polygon([(CX, 12), (CX - 14, by), (CX + 14, by)], fill=WHITE)
    # Mid spikes
    mid_x = 93
    d.polygon([(mid_x, 26), (mid_x - 13, by), (mid_x + 13, by)], fill=WHITE)
    d.polygon([(256 - mid_x, 26), (256 - mid_x - 13, by), (256 - mid_x + 13, by)], fill=WHITE)
    # Outer spikes (shorter)
    outer_x = 68
    d.polygon([(outer_x, 40), (HEAD_L, by), (outer_x + 18, by)], fill=WHITE)
    d.polygon([(256 - outer_x, 40), (256 - outer_x - 18, by), (HEAD_R, by)], fill=WHITE)


def draw_tophat(d):
    """Classic top hat."""
    brim_y = REST_Y - 5
    # Wide flat brim
    d.ellipse([38, brim_y, 218, brim_y + 22], fill=WHITE)
    # Crown body (tall rectangle)
    d.rectangle([84, 8, 172, brim_y + 8], fill=WHITE)


def draw_cap(d):
    """Baseball cap — dome + front bill."""
    dome_y0 = REST_Y - 40
    dome_y1 = REST_Y + 22
    # Main dome (half-ellipse effect using two overlapping ellipses)
    d.ellipse([56, dome_y0, 200, dome_y1 + 30], fill=WHITE)
    # Erase the lower portion of ellipse to get a dome silhouette
    d.rectangle([56, dome_y1, 200, dome_y1 + 35], fill=(0, 0, 0, 0))
    # Flat cap base
    d.rectangle([56, dome_y1 - 14, 200, dome_y1], fill=WHITE)
    # Front bill (extends right of center)
    d.polygon([
        (200, dome_y1 - 14),
        (232, dome_y1 + 4),
        (200, dome_y1),
    ], fill=WHITE)
    d.ellipse([196, dome_y1 - 16, 238, dome_y1 + 6], fill=WHITE)


def draw_graduation(d):
    """Mortarboard / graduation cap."""
    band_y = REST_Y - 5
    # Head band
    d.ellipse([76, band_y - 10, 180, band_y + 18], fill=WHITE)
    # Flat square top (diamond-ish from front view)
    board_cx, board_cy = CX, REST_Y - 32
    hw, hh = 64, 14   # half-width, half-height of the board
    d.polygon([
        (board_cx, board_cy - hh),
        (board_cx + hw, board_cy),
        (board_cx, board_cy + hh),
        (board_cx - hw, board_cy),
    ], fill=WHITE)
    # Tassel (line + ball)
    d.rectangle([board_cx + 30, board_cy, board_cx + 38, board_cy + 45], fill=WHITE)
    d.ellipse([board_cx + 22, board_cy + 40, board_cx + 46, board_cy + 60], fill=WHITE)


def draw_party_hat(d):
    """Conical party hat."""
    brim_y = REST_Y + 2
    # Cone
    d.polygon([(CX, 6), (HEAD_L + 10, brim_y), (HEAD_R - 10, brim_y)], fill=WHITE)
    # Band at brim
    d.rectangle([HEAD_L + 10, brim_y, HEAD_R - 10, brim_y + 14], fill=WHITE)
    # Pom-pom tip
    d.ellipse([CX - 10, 2, CX + 10, 22], fill=WHITE)


def draw_viking(d):
    """Viking helmet with two horns."""
    dome_top = REST_Y - 42
    # Main helmet dome
    d.ellipse([66, dome_top, 190, REST_Y + 18], fill=WHITE)
    # Nose guard strip
    d.rectangle([CX - 9, REST_Y - 4, CX + 9, REST_Y + 50], fill=WHITE)
    # Left horn (polygon)
    d.polygon([(72, REST_Y - 20), (14, dome_top - 20), (48, REST_Y - 8)], fill=WHITE)
    # Right horn
    d.polygon([(184, REST_Y - 20), (242, dome_top - 20), (208, REST_Y - 8)], fill=WHITE)


def draw_cowboy(d):
    """Cowboy / Western hat."""
    # Crown (pinched at top)
    d.ellipse([78, REST_Y - 46, 178, REST_Y + 12], fill=WHITE)
    # Crease at top (narrow dark line — skip for pure silhouette)
    # Wide brim
    d.ellipse([22, REST_Y - 4, 234, REST_Y + 24], fill=WHITE)


def draw_headband(d):
    """Simple thick headband across the forehead."""
    hb_y = REST_Y + 10   # sits a bit lower, just at the hairline
    d.rectangle([HEAD_L - 4, hb_y, HEAD_R + 4, hb_y + 20], fill=WHITE)
    # Round the ends
    d.ellipse([HEAD_L - 14, hb_y - 4, HEAD_L + 6, hb_y + 24], fill=WHITE)
    d.ellipse([HEAD_R - 6, hb_y - 4, HEAD_R + 14, hb_y + 24], fill=WHITE)


def draw_beanie(d):
    """Knit beanie with pom-pom."""
    dome_y0 = 12
    dome_y1 = REST_Y + 14
    # Main dome
    d.ellipse([54, dome_y0, 202, dome_y1 + 20], fill=WHITE)
    # Erase below cuff line
    d.rectangle([54, dome_y1, 202, dome_y1 + 25], fill=(0, 0, 0, 0))
    # Cuff roll
    d.rectangle([54, dome_y1 - 16, 202, dome_y1], fill=WHITE)
    # Pom-pom
    d.ellipse([CX - 16, 4, CX + 16, 36], fill=WHITE)


def draw_sombrero(d):
    """Wide Mexican sombrero."""
    # Dome
    d.ellipse([82, REST_Y - 36, 174, REST_Y + 12], fill=WHITE)
    # Very wide brim
    d.ellipse([12, REST_Y - 2, 244, REST_Y + 28], fill=WHITE)


def draw_laurel(d):
    """Laurel / olive leaf wreath."""
    cy = REST_Y + 6    # vertical center of wreath
    radius = 52        # radius of the wreath ring
    # Draw leaf ellipses around a semicircle (top half only, left+right)
    n_leaves = 7
    for side in (-1, 1):
        for i in range(n_leaves):
            angle_deg = 180 + side * (20 + i * 22)
            angle = math.radians(angle_deg)
            lx = CX + int(radius * math.cos(angle))
            ly = cy + int(radius * math.sin(angle))
            leaf_angle = angle + math.pi / 2
            la, lb = 14, 7   # leaf semi-major, semi-minor
            pts = []
            for t in range(8):
                tt = t * math.pi / 4
                px = lx + la * math.cos(tt) * math.cos(leaf_angle) - lb * math.sin(tt) * math.sin(leaf_angle)
                py = ly + la * math.cos(tt) * math.sin(leaf_angle) + lb * math.sin(tt) * math.cos(leaf_angle)
                pts.append((int(px), int(py)))
            d.polygon(pts, fill=WHITE)
    # Center connecting band
    d.rectangle([CX - 26, cy + 4, CX + 26, cy + 18], fill=WHITE)


def draw_bow(d):
    """Hair bow / ribbon."""
    bow_y = REST_Y - 30
    # Left lobe (ellipse)
    d.ellipse([HEAD_L + 4, bow_y - 22, CX - 10, bow_y + 22], fill=WHITE)
    # Right lobe
    d.ellipse([CX + 10, bow_y - 22, HEAD_R - 4, bow_y + 22], fill=WHITE)
    # Center knot
    d.ellipse([CX - 14, bow_y - 12, CX + 14, bow_y + 12], fill=WHITE)


def draw_bandana(d):
    """Bandana / do-rag tied across the forehead."""
    top_y = REST_Y - 2
    bot_y = top_y + 28
    # Main band (trapezoid, wider at top)
    d.polygon([
        (HEAD_L - 6, top_y),
        (HEAD_R + 6, top_y),
        (HEAD_R, bot_y),
        (HEAD_L, bot_y),
    ], fill=WHITE)
    # Tie tails on right side
    d.polygon([
        (HEAD_R + 6, top_y),
        (HEAD_R + 38, top_y - 8),
        (HEAD_R + 32, top_y + 14),
        (HEAD_R, bot_y - 4),
    ], fill=WHITE)


def draw_witch_hat(d):
    """Tall pointed witch hat."""
    brim_y = REST_Y - 4
    # Tall narrow cone (slightly askew for character)
    d.polygon([(CX + 6, 6), (HEAD_L + 12, brim_y), (HEAD_R - 12, brim_y)], fill=WHITE)
    # Wide brim
    d.ellipse([32, brim_y - 2, 224, brim_y + 20], fill=WHITE)


def draw_tiara(d):
    """Delicate tiara / mini crown."""
    base_y = REST_Y + 2
    band_h = 13
    # Thin base band
    d.rectangle([HEAD_L + 12, base_y, HEAD_R - 12, base_y + band_h], fill=WHITE)
    # Central tall jewel spike
    d.polygon([(CX, REST_Y - 26), (CX - 11, base_y), (CX + 11, base_y)], fill=WHITE)
    # Two shorter side spikes
    for sx in [CX - 36, CX + 36]:
        d.polygon([(sx, REST_Y - 10), (sx - 9, base_y), (sx + 9, base_y)], fill=WHITE)


def draw_chef_hat(d):
    """Tall puffy chef's toque."""
    band_y = REST_Y + 10
    band_h = 18
    # Puffy dome (tall)
    d.ellipse([62, 6, 194, band_y + 20], fill=WHITE)
    # Flat band at base of dome
    d.rectangle([62, band_y, 194, band_y + band_h], fill=WHITE)


def draw_antlers(d):
    """Reindeer / deer antlers on a headband."""
    hb_y = REST_Y + 8
    # Headband
    d.rectangle([HEAD_L, hb_y, HEAD_R, hb_y + 16], fill=WHITE)
    # Left antler trunk
    lx = HEAD_L + 18
    d.rectangle([lx - 9, hb_y - 52, lx + 9, hb_y], fill=WHITE)
    # Left forward branch
    d.polygon([(lx - 9, hb_y - 30), (lx - 38, hb_y - 48), (lx - 24, hb_y - 18)], fill=WHITE)
    # Left back tine
    d.rectangle([lx, hb_y - 52, lx + 20, hb_y - 38], fill=WHITE)
    # Right antler trunk (mirror)
    rx = HEAD_R - 18
    d.rectangle([rx - 9, hb_y - 52, rx + 9, hb_y], fill=WHITE)
    # Right forward branch
    d.polygon([(rx + 9, hb_y - 30), (rx + 38, hb_y - 48), (rx + 24, hb_y - 18)], fill=WHITE)
    # Right back tine
    d.rectangle([rx - 20, hb_y - 52, rx, hb_y - 38], fill=WHITE)


def draw_earmuffs(d):
    """Fluffy earmuffs on a headband."""
    # Connecting arc / headband over top of head
    d.rectangle([HEAD_L - 8, REST_Y - 10, HEAD_R + 8, REST_Y + 10], fill=WHITE)
    # Left muff (large circle)
    lx = HEAD_L - 22
    d.ellipse([lx - 26, EAR_Y - 28, lx + 26, EAR_Y + 28], fill=WHITE)
    # Right muff
    rx = HEAD_R + 22
    d.ellipse([rx - 26, EAR_Y - 28, rx + 26, EAR_Y + 28], fill=WHITE)
    # Connecting stems from arc down to muffs
    d.rectangle([HEAD_L - 14, REST_Y + 6, HEAD_L + 2, EAR_Y], fill=WHITE)
    d.rectangle([HEAD_R - 2, REST_Y + 6, HEAD_R + 14, EAR_Y], fill=WHITE)


def draw_bunny_ears(d):
    """Tall bunny ears."""
    ear_bot = REST_Y + 4
    ear_top = 6
    ear_hw = 18    # half-width of each ear
    gap = 24       # distance from center to ear center
    for sign in (-1, 1):
        ex = CX + sign * gap
        # Outer ear (full ellipse)
        d.ellipse([ex - ear_hw, ear_top, ex + ear_hw, ear_bot], fill=WHITE)


# ---------------------------------------------------------------------------
# Accessory catalogue (matches JS catalogue structure)
# ---------------------------------------------------------------------------

ACCESSORIES = [
    # col, row, key,           label (Norwegian)
    (0, 0, 'acc_none',         'Ingen',           draw_none),
    (1, 0, 'acc_crown',        'Krone',            draw_crown),
    (2, 0, 'acc_tophat',       'Flosshatt',        draw_tophat),
    (3, 0, 'acc_cap',          'Caps',             draw_cap),

    (0, 1, 'acc_graduation',   'Akademialue',      draw_graduation),
    (1, 1, 'acc_party_hat',    'Festlue',          draw_party_hat),
    (2, 1, 'acc_viking',       'Vikinglehjelm',    draw_viking),
    (3, 1, 'acc_cowboy',       'Cowboyhatt',       draw_cowboy),

    (0, 2, 'acc_headband',     'Pannebånd',        draw_headband),
    (1, 2, 'acc_beanie',       'Lue',              draw_beanie),
    (2, 2, 'acc_sombrero',     'Sombrero',         draw_sombrero),
    (3, 2, 'acc_laurel',       'Laurbærkrans',     draw_laurel),

    (0, 3, 'acc_bow',          'Sløyfe',           draw_bow),
    (1, 3, 'acc_bandana',      'Bandana',          draw_bandana),
    (2, 3, 'acc_witch_hat',    'Heksehatt',        draw_witch_hat),
    (3, 3, 'acc_tiara',        'Tiara',            draw_tiara),

    (0, 4, 'acc_chef_hat',     'Kokkehatt',        draw_chef_hat),
    (1, 4, 'acc_antlers',      'Gevir',            draw_antlers),
    (2, 4, 'acc_earmuffs',     'Ørevarmere',       draw_earmuffs),
    (3, 4, 'acc_bunny_ears',   'Kaninører',        draw_bunny_ears),
]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def generate(out_path: str):
    sheet = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    for col, row, key, label, draw_fn in ACCESSORIES:
        tile = new_tile()
        draw_fn(ImageDraw.Draw(tile))
        paste_tile(sheet, tile, col, row)
        print(f"  ({col},{row})  {key:22s}  {label}")

    sheet.save(out_path)
    print(f"\nSaved {W}×{H} PNG → {out_path}")
    print(f"Tiles: {COLS} cols × {ROWS} rows, {TILE}×{TILE}px each, {len(ACCESSORIES)} accessories")


if __name__ == '__main__':
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(repo_root, 'media', 'avatar_head_accessories.png')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    print("Generating avatar_head_accessories.png …\n")
    generate(out)
