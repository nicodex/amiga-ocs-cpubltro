#!/usr/bin/env python3

# not-so-random quote: "get ready to match our spin with the retro thrusters"

import argparse
import os
import pathlib
import png
import sys

argp = argparse.ArgumentParser(prog='ballanim.py', add_help=False,
  usage='python3 %(prog)s (--pal | --ntsc) [--interlaced] [--help | options]',
  description='Generate ball animation images from greyscale colormap.',
  allow_abbrev=False)
argp_mode = argp.add_argument_group('mode')
argp_ntsc = argp_mode.add_mutually_exclusive_group(required=True)
argp_ntsc.add_argument('--pal', '-p', action='store_false', dest='ntsc',
  help='50Hz (6*2 colors * steps/frame)')
argp_ntsc.add_argument('--ntsc', '-n', action='store_true',
  help='60Hz (7*2 colors * steps/frame)')
argp_mode.add_argument('--interlaced', '-i', action='store_true', dest='lace',
  help='1 step/frame (else progressive)', default=False)
argp_mode.add_argument('--help', '-h', action='store_true',
  help='show this help message and exit', default=False)
args, _ = argp.parse_known_args()
argp_opts = argp.add_argument_group('options ({0}, {1})'.format(
  'NTSC' if args.ntsc else 'PAL',
  'interlaced' if args.lace else 'progressive'))
BASE_STR = 'ntsc' if args.ntsc else 'ball'
STEP_LEN = 1 if args.lace else 2 # analog TV frame vs progressive fields
ANIM_LEN = ((7 if args.ntsc else 6) * 2) * STEP_LEN # 7*50/60/6 = 97.22%
ANIM_BASE = -2 * STEP_LEN # original demo starts with two steps westward
ROT_FADER = 1 # animation fading steps (original has half the steps = 2)
IMG_SCALE = 1 # scale output files (no filter, has to be 1 for ROM code)
NAME_BASE = 0 # (1 makes APNG fallback easier, has to be 0 for ROM code)
MASK_USED = False # TODO (needs more work to squeeze it into 256 KB ROM)
MAKE_EAST = True
MAKE_STOP = MASK_USED
MAKE_WEST = True
BACKWARDS = False
CMAP_FILE = f'{BASE_STR}cmap.png'
MASK_FILE = f'{BASE_STR}mask.png' # optional shadow mask
argp_opts.add_argument('--cmap-file', metavar='.png', type=pathlib.Path,
  help=f'8-bit greyscale (={CMAP_FILE})', default=CMAP_FILE)
argp_opts.add_argument('--anim-base', metavar=f'{1-ANIM_LEN}..{ANIM_LEN-1}',
  help=f'first animation pos (default={ANIM_BASE})', default=ANIM_BASE,
  type=int, choices=range(1-ANIM_LEN, ANIM_LEN))
argp_opts.add_argument('--rot-fader', metavar=f'0..{ANIM_LEN // 2}',
  help=f'rotation fade width (default={ROT_FADER})', default=ROT_FADER,
  type=int, choices=range(0, (ANIM_LEN // 2) + 1))
argp_opts.add_argument('--img-scale', '-x', metavar='1..N',
  help=f'output image scaler (ROMcode={IMG_SCALE})', default=IMG_SCALE,
  type=lambda x : int(x) if int(x) >= 1 else argp.error('invalid scale'))
argp_opts.add_argument('--name-base', metavar='0..N',
  help=f'first output number (ROMcode={NAME_BASE})', default=NAME_BASE,
  type=lambda x : int(x) if int(x) >= 0 else argp.error('invalid offset'))
if not MASK_USED:
  argp_opts.add_argument('--mask-used', action='store_true',
    help='shadow mask (black: white=fade)', default=False)
argp_opts.add_argument('--mask-file',  metavar=f'.png', type=pathlib.Path,
  help=f'1-bit greyscale (={MASK_FILE})', default=MASK_FILE)
if     MAKE_EAST:
  argp_opts.add_argument('--skip-east', action='store_true',
    help='do not generate eastward images', default=False)
if not MAKE_STOP:
  argp_opts.add_argument('--make-stop', action='store_true',
    help='force generating stopped images', default=False)
if     MAKE_WEST:
  argp_opts.add_argument('--skip-west', action='store_true',
    help='do not generate westward images', default=False)
if not BACKWARDS:
  argp_opts.add_argument('--backwards', action='store_true',
    help='backward animation order (west)', default=False)
args = argp.parse_args()
if args.help:
  argp.print_help(sys.stderr)
  sys.exit(1)
CMAP_FILE = args.cmap_file
MASK_FILE = args.mask_file
ANIM_BASE = args.anim_base
ROT_FADER = args.rot_fader
IMG_SCALE = args.img_scale
NAME_BASE = args.name_base
if not MASK_USED: MASK_USED =     args.mask_used
if     MAKE_EAST: MAKE_EAST = not args.skip_east
if not MAKE_STOP: MAKE_STOP =     args.make_stop or MASK_USED
if     MAKE_WEST: MAKE_WEST = not args.skip_west
if not BACKWARDS: BACKWARDS =     args.backwards
PATH_EXT = ''
if BACKWARDS : PATH_EXT += 'b'
if args.lace : PATH_EXT += 'i'
if IMG_SCALE != 1: PATH_EXT += f'x{IMG_SCALE}'
if NAME_BASE != 0: PATH_EXT += f'n{NAME_BASE}'
if PATH_EXT : PATH_EXT = f'-{PATH_EXT}'
FILE_FRMT = 'image{0:03d}.png'
EAST_PATH = f'{BASE_STR}east{PATH_EXT}'
STOP_PATH = f'{BASE_STR}stop{PATH_EXT}'
WEST_PATH = f'{BASE_STR}west{PATH_EXT}'
EAST_FRMT = os.path.join(EAST_PATH, FILE_FRMT) if MAKE_EAST else ''
STOP_FRMT = os.path.join(STOP_PATH, FILE_FRMT) if MAKE_STOP else ''
WEST_FRMT = os.path.join(WEST_PATH, FILE_FRMT) if MAKE_WEST else ''

ocs_to_rgb = lambda c : tuple(((c >> i) & 0x0F) * 0x11 for i in (8, 4, 0))
palette = (
  (*ocs_to_rgb(0xAAA), 0), # BACK/transparent (gray)
  (*ocs_to_rgb(0xF00),  ), # RED
  (*ocs_to_rgb(0xFDD),  ), # FADE (pink)
  (*ocs_to_rgb(0xFFF),  )) # WHITE
BACK, RED, FADE, WHITE = range(len(palette))
# see 'gimp/ballpath.gpl' for details (interlace index //= 2)
INTENSITY_BASE = (((0xFF * STEP_LEN) // 0x11) + 1) - ANIM_LEN
intensity_to_index = lambda i : (
  (((int(i) * STEP_LEN) + (0x11 // 2)) // 0x11) - INTENSITY_BASE)
index_to_intensity = lambda i : (
  (((i + INTENSITY_BASE) * 0x11) + (STEP_LEN // 2)) // STEP_LEN)
black_to_fade_bool = lambda i : False if i else True

width, height, pixels, metadata = png.Reader(filename=CMAP_FILE).read()
if not metadata['greyscale'] or metadata['bitdepth'] != 8:
  sys.exit(f'error: {CMAP_FILE:s} has to be a 8-bit grayscale image')
cmap = tuple(tuple(map(intensity_to_index, row)) for row in pixels)
if MASK_USED:
  pixels, metadata = png.Reader(filename=MASK_FILE).read()[2:]
  if not metadata['greyscale'] or metadata['bitdepth'] != 1:
    sys.exit(f'error: {MASK_FILE:s} has to be a 1-bit grayscale image')
  if tuple(metadata['size']) != (width, height):
    sys.exit(f'error: {MASK_FILE:s} size has to match {CMAP_FILE:s}')
  fade = tuple(tuple(map(black_to_fade_bool, row)) for row in pixels)
  is_fade_pixel = lambda x, y : fade[y][x]
else:
  is_fade_pixel = lambda x, y : False
del pixels, metadata

writer = png.Writer(size=(width * IMG_SCALE, height * IMG_SCALE),
  bitdepth=(len(palette) - 1).bit_length(), palette=palette, compression=9)

EAST, STOP, WEST = range(3)
for n in range(ANIM_LEN):
  p = [[] for _ in range(3)]
  for y in range(height):
    r = [[] for _ in range(3)]
    for x in range(width):
      a = cmap[y][x]
      if a < 0:
        for i in (EAST, STOP, WEST):
          r[i] += [BACK] * IMG_SCALE
        continue
      a = (a + n + ANIM_BASE + ANIM_LEN) % ANIM_LEN
      c = RED if a >= ANIM_LEN // 2 else FADE if is_fade_pixel(x, y) else WHITE
      r[EAST] += IMG_SCALE * [
        FADE if WHITE == c and a < ROT_FADER else c] 
      r[STOP] += IMG_SCALE * [c]
      r[WEST] += IMG_SCALE * [
        FADE if WHITE == c and a >= ANIM_LEN // 2 - ROT_FADER else c]
    for i in (EAST, STOP, WEST):
      p[i] += [r[i]] * IMG_SCALE
  for i in (EAST, STOP, WEST):
    f = {EAST: EAST_FRMT, STOP: STOP_FRMT, WEST: WEST_FRMT}[i]
    if not f: continue
    f = f.format(((ANIM_LEN - n if BACKWARDS else n) % ANIM_LEN) + NAME_BASE)
    d, _ = os.path.split(f)
    if d and not os.path.isdir(d): os.makedirs(d)
    print(f)
    with open(f, 'wb') as o: writer.write(o, p[i])
    # release post-processing with zopflipng --keepcolortype
    # --keepchunks=PLTE --filters=01234meb --iterations=1024

