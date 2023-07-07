#!/usr/bin/env python3

import png
import sys

ASM_FILENAME = 'cpubltro_img.i'
IMG_FILENAME = 'cpubltro_img.png'
DISPL_VPOS = 0x1C # first display line (only for ASM comments)
DISPL_HPOS = 0x38 # first BPL1DAT write (only for ASM comments)
ASM_LENGTH = (1 + 20 + 1) # words
IMG_HEIGHT = 280
ASM_COLOR0 = 0xAAA #AAAAAA/#555555
ASM_COLOR1 = 0x05A #0055AA/#002255

IMG_WIDTH = ASM_LENGTH * 16
COL_OFFSET = (                                         # MOVEM.L (An)+,Rn*
  tuple(r for r in range(16 * 0, IMG_WIDTH, 16 * 2)) + #  MOVE.L Rn,(An)
  tuple(a for a in range(16 * 1, IMG_WIDTH, 16 * 2))   #  MOVE.L (An)+,(An)
)
print('c =', ','.join(f'{x // 16:d}' for x in COL_OFFSET))
assert len(COL_OFFSET) == ASM_LENGTH, 'fixme: offset table size'
assert len(COL_OFFSET) == len(set(COL_OFFSET)), 'fixme: offset table set'

RGB_COLOR = (
  tuple(((ASM_COLOR0 >> i) & 0xF) * 0x11 for i in (8, 4, 0)), # color 0
  tuple(((ASM_COLOR1 >> i) & 0xF) * 0x11 for i in (8, 4, 0)), # color 1
  tuple(((ASM_COLOR0 >> i) & 0x7) * 0x11 for i in (9, 5, 1)), # color 0 EHB
  tuple(((ASM_COLOR1 >> i) & 0x7) * 0x11 for i in (9, 5, 1))  # color 1 EHB
)
print('p =', ','.join(f'#{c[0]:02X}{c[1]:02X}{c[2]:02X}' for c in RGB_COLOR))
assert len(RGB_COLOR) == len(set(RGB_COLOR)), 'fixme: RGB color set'

width, height, rows, info = png.Reader(filename=IMG_FILENAME).read()
if (width != IMG_WIDTH) or (height != IMG_HEIGHT):
  sys.exit(f'error: image size has to be {IMG_WIDTH:d}x{IMG_HEIGHT:d}')
if ('palette' not in info):
  sys.exit('error: image has to be palette-based')
palette = info['palette']
print('i =', ','.join(f'#{c[0]:02X}{c[1]:02X}{c[2]:02X}' for c in palette))
if (len(palette) != 4):
  sys.exit('error: image has to contain 4 colors')
try: # PNG writer/optimizer might reorder the palette colors
  MAP_COLOR = tuple(palette.index(c) for c in RGB_COLOR)
except ValueError:
  sys.exit('error: image palette missmatch')
print('m = ', ', '.join(f'{i:d} -> {MAP_COLOR[i]:d}' for i in range(4)))
if (len(MAP_COLOR) != len(set(MAP_COLOR))):
  sys.exit('error: palette is not unique')

code = 'MainImage:\n';
vpos = DISPL_VPOS
for row in rows:
  words = []
  for col in range(ASM_LENGTH):
    x = COL_OFFSET[col]
    bpl5dat = 0
    bpl6dat = 0
    for bit in range(16):
      color = MAP_COLOR[row[x + bit]]
      bpl5dat = (bpl5dat << 1) | ((color >> 0) & 0x01)
      bpl6dat = (bpl6dat << 1) | ((color >> 1) & 0x01)
    words.append(bpl5dat)
    words.append(bpl6dat)
  hpos = DISPL_HPOS
  BWORDS = 8 * 2
  BCOUNT = ((len(words) - 1) // BWORDS) + 1
  blocks = tuple(words[w * BWORDS : (w + 1) * BWORDS] for w in range(BCOUNT))
  for b in blocks:
    if DISPL_HPOS == hpos:
      code += f'\t;\t{vpos:03d}:\t        '
    else:
      code += '\t\t;   \t        '
    code += '         '.join(f'${hpos + w:02X}' for w in range(0, len(b) * 4, 8))
    code += '\n'
    code += '\t\tdc.w\t'
    code += ','.join(f'${w:04X}' for w in b)
    code += '\n'
    hpos += (BWORDS // 2) * 8
  vpos += 1
print('l = ', code.count('\n'))

with open(ASM_FILENAME, 'w', encoding='ascii') as f:
    f.write(code)

