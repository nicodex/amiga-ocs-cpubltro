#!/usr/bin/env python3

#TODO: NTSC support, optimize sprite data (line skip)

import png
import sys

IMG_BASENAME = 'ball' # NTSC 'ntsc'
ASM_FILENAME = f'{IMG_BASENAME}data.i'
IMG_FILEFRMT = f'{IMG_BASENAME}{{0}}/image{{1:03d}}.png'
IMG_COUNT = 24        # NTSC 28
IMG_WIDTH = 7*16
IMG_HEIGHT = IMG_WIDTH
PALETTE_RGB = (
  (0xA * 0x11, 0xA * 0x11, 0xA * 0x11, 0),
  (0xF * 0x11, 0x0 * 0x11, 0x0 * 0x11, 255),
  (0xF * 0x11, 0xD * 0x11, 0xD * 0x11, 255),
  (0xF * 0x11, 0xF * 0x11, 0xF * 0x11, 255))

def read_image(img_filename):
  width, height, pixels, metadata = png.Reader(filename=img_filename).read()
  if (width != IMG_WIDTH) or (height != IMG_HEIGHT):
    sys.exit(f'{img_filename}: image has to be {IMG_WIDTH:d}x{IMG_HEIGHT:d} in size')
  if 'palette' not in metadata:
    sys.exit(f'{img_filename}: image has to be palette-based')
  palette = metadata['palette']
  if (len(palette) != 4):
    sys.exit(f'{img_filename}: image has to contain 4 colors')
  try: # PNG writer/optimizer might reorder the palette colors
    INDEX_COLOR = tuple(palette.index(c) for c in PALETTE_RGB)
  except ValueError:
    sys.exit(f'{img_filename}: image palette color missmatch')
  code = f'\t\tdcb.l  \t7,0\t; {img_filename}\n'
  for r in pixels:
    d = []
    for s in range(IMG_WIDTH // 16):
      SPRxDATA = 0
      SPRxDATB = 0
      for i in range(16):
        c = INDEX_COLOR[r[s * 16 + i]]
        SPRxDATA = (SPRxDATA << 1) | ((c >> 0) & 0x01)
        SPRxDATB = (SPRxDATB << 1) | ((c >> 1) & 0x01)
      d.append((SPRxDATA << 16) | SPRxDATB)
    code += f'\t\tdc.l   \t{','.join(f'${l:08X}' for l in d)}\n'
  return code

code = ''
for d in ('west', 'east'):
  for n in range(IMG_COUNT):
    code += read_image(IMG_FILEFRMT.format(d, n))
code += '\t\tdcb.l  \t7,0\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as f:
  f.write(code)
print(ASM_FILENAME)

