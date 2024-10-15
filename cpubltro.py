#!/usr/bin/env python3

import png
import sys

ASM_FILENAME = 'cpubltro.i'
IMG_FILENAME = 'cpubltro.png'
IMG_WIDTH = 320
IMG_HEIGHT = 256
ROW_COLORS = 4

# D1/D2/D3/D4/D5/D6/D7/A0/A1/A2/A3/A4/A5/M1/M2/M3/M4/M5/M6/M7/M8/M9
#  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21
# 11 12 13 14 16 18 Cx Cn  1  3  5  7  9  0  2  4  6  8 10 15 17 19
COL_IDX = (
  13, 8, 14, 9, 15, 10, 16, 11, 17, 12, 18, # M1/A1/M2/A2/M3/A3/M4/A4/M5/A5/M6
  0, 1, 2,                                  # D1/D2/D3
  3, 19, 4, 20, 5, 21                       # D4/M7/D5/M8/D6/M9
)
CCR_IDX = (6, 7)                            # D7/A0
IMG_LENGTH = len(COL_IDX)
ROW_LENGTH = IMG_LENGTH + len(CCR_IDX)
assert IMG_LENGTH == IMG_WIDTH // 16, 'fixme: column table size'
assert ROW_LENGTH == len(set(COL_IDX + CCR_IDX)), 'fixme: row table set'
assert min(COL_IDX + CCR_IDX) == 0, 'fixme: row table min'
assert max(COL_IDX + CCR_IDX) == ROW_LENGTH - 1, 'fixme: row table max'

def get_pal_rgb(pal, idx):
  return int(
    (pal[idx][0] << 16) |
    (pal[idx][1] <<  8) |
    (pal[idx][2] <<  0))

OCS_SCALE = 0xFF // 0xF
OCS_ROUND = (OCS_SCALE - 1) // 2

def rgb_to_ocs(rgb):
  return int(
    (((((rgb >> 16) & 0xFF) + OCS_ROUND) // OCS_SCALE) << 8) |
    (((((rgb >>  8) & 0xFF) + OCS_ROUND) // OCS_SCALE) << 4) |
    (((((rgb >>  0) & 0xFF) + OCS_ROUND) // OCS_SCALE) << 0))

def ocs_to_rgb(ocs):
  return int(
    ((((ocs >> 8) & 0xF) * OCS_SCALE) << 16) |
    ((((ocs >> 4) & 0xF) * OCS_SCALE) <<  8) |
    ((((ocs >> 0) & 0xF) * OCS_SCALE) <<  0))

width, height, rows, info = png.Reader(filename=IMG_FILENAME).read()
if (width != IMG_WIDTH) or (height != IMG_HEIGHT):
  sys.exit(f'fixme: image size has to be {IMG_WIDTH:d}x{IMG_HEIGHT:d}')
if ('palette' not in info):
  sys.exit('fixme: only palette-based images implemented')
pal = info['palette']

img_code = ''
img_pal = []
row_pal = []
y = -1
for row in rows:
  y += 1
  row_idx = set([idx for idx in row])
  row_dat = [0] * ROW_LENGTH
  updated = -1
  for column in range(IMG_LENGTH):
    bpl2dat = 0
    bpl3dat = 0
    for bit in range(16):
      x = column * 16 + bit
      index = row[x]
      if index not in row_pal:
        if updated < 0:
          for i in range(len(row_pal)):
            if row_pal[i] not in row_idx:
              updated = i
              row_pal[updated] = index
              break
        if (updated < 0) or (row_pal[updated] != index):
          img_pal.append(index)
          row_pal.append(index)
          if len(img_pal) > ROW_COLORS:
            sys.exit(f'fixme: too many colors at [{x:d},{y:d}]')
      color = row_pal.index(index)
      bpl2dat = (bpl2dat << 1) | ((color >> 0) & 1)
      bpl3dat = (bpl3dat << 1) | ((color >> 1) & 1)
    row_dat[COL_IDX[column]] = (bpl2dat << 16) | bpl3dat
  if updated < 0:
    row_dat[CCR_IDX[0]] = 0
    row_dat[CCR_IDX[1]] = 0xDFF116 # bpl4data/bpl5data
  else:
    ocs = rgb_to_ocs(get_pal_rgb(pal, row_pal[updated]))
    row_dat[CCR_IDX[0]] = (ocs << 16) | ocs
    row_dat[CCR_IDX[1]] = 0xDFF180 + (updated * 2 * 2)
  img_code += '\t\tdc.l\t' + ','.join(f'${l:08X}' for l in row_dat) + '\n'
img_ocs = [rgb_to_ocs(get_pal_rgb(pal, i)) for i in img_pal]
while len(img_ocs) < ROW_COLORS:
  img_ocs.append(0)
pal_code = '\t\tdc.w\t' + ','.join(f'${w:03X}' for w in img_ocs) + '\n'

with open(ASM_FILENAME, 'w', encoding='ascii') as f:
  f.write(pal_code)
  f.write(img_code)

