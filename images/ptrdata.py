#!/usr/bin/env python3

# not-so-random quote: "humor, seventy-five percent"

import png
import sys

IMG_FILENAME = 'pointer.png'
ASM_FILENAME = 'ptrdata.i'
PALETTE_RGB = ( # sprite 0 (pointer) and 1 (ball left) share the colors
  (0xA * 0x11, 0xA * 0x11, 0xA * 0x11, 0),
  (0xF * 0x11, 0x0 * 0x11, 0x0 * 0x11, 255),
  (0xF * 0x11, 0xD * 0x11, 0xD * 0x11, 255),
  (0xF * 0x11, 0xF * 0x11, 0xF * 0x11, 255))

width, height, pixels, metadata = png.Reader(filename=IMG_FILENAME).read()
if (width > 16) or (height > 320 * 9 // 16):
  sys.exit(f'error: pointer image has an invalid size')
if 'palette' not in metadata:
  sys.exit('error: pointer image has to be palette-based')
palette = metadata['palette']
if (len(palette) != 4):
  sys.exit('error: pointer image has to contain 4 colors')
try: # PNG writer/optimizer might reorder the palette colors
  INDEX_COLOR = tuple(palette.index(c) for c in PALETTE_RGB)
except ValueError:
  sys.exit('error: pointer image palette color missmatch')

code = '';
for r in pixels:
  spr0data = '%'
  spr0datb = '%'
  for i in r:
    c = INDEX_COLOR[i]
    spr0data += '01'[(c >> 0) & 0x01]
    spr0datb += '01'[(c >> 1) & 0x01]
  code += f'\t\tdc.w   \t{spr0data:0<17},{spr0datb:0<17}\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as f:
  f.write(code)
print(ASM_FILENAME)

