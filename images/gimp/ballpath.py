#!/usr/bin/env python3

# not-so-random quote: "this little maneuver's gonna cost us fifty-one years"

import argparse
import pathlib
from mpmath import mp

mp.dps = 17 * 2 # work with quadruple precision, print with double precision
ff = lambda x : mp.nstr(x, mp.dps // 2, min_fixed=mp.ninf, max_fixed=mp.inf)

PATH_FILE = 'ballpath.svg'
NTSC_FILE = 'ntscpath.svg'
B_WIDTH = 7 * 16 # original Boing! ball width is very close to 7 full sprites
#
# TL;DR display and pixel aspect ratio decision that I made for this project:
#   - PAL  display aspect ratio (DAR) 5:4 => pixel aspect ratio (PAR) 1:1
#   - NTSC display aspect ratio (DAR) 4:3 => pixel aspect ratio (PAR) 5:6
#
# LoRes storage aspect ratio (SAR) is 320:200 (NTSC 8:5) or 320:256 (PAL 5:4)
# and the pixel aspect ratio (PAR) returned by the OS display/monitor info is
# 44:52 (NTSC 11:13) or 44:44 (PAL 1:1). Therefore the AmigaOS uses different
# display aspect ratios (DAR = SAR * PAR) of 88:65 (NTSC) or 5:4 (PAL), which
# both differ from the early standard TV screens and computer monitors (4:3).
# However, my Commodore Amiga 1081 PAL monitor has a rectangular display area
# of 270x200mm (27:20), where LoRes has a PAR of 27:32 (NTSC) or 27:25 (PAL).
# So in theory, if the default PAL LoRes screen is stretched into the corners
# on my Amiga 1081 monitor, the stored ball image would be 112x121px in size.
# On the other hand, if the AmigaOS is right about square pixels on PAL LoRes
# (makes sense because I want to make the demo easily accessible and the ball
# should be round on newer displays, which almost always have square pixels),
# I have to reduce/adjust the H.Width to 250mm (pillarbox, 10mm on the sides)
# to correctly display square pixels on my monitor (well, the CRTs horizontal
# resolution is defined by the dot pitch, not pixels, but you get the point).
# So far so good, but the original Boing! demo has been designed for NTSC and
# the draw_globe function divides the vertical values by 1.1 (PAR 10:11), but
# in the end (low sine table precision, error propagation) the drawn ball has
# a size of 113x98px (DAR 32:23), which doesn't really match any of the above
# ratios. Let's use something practical for NTSC - standard TV 4:3 (PAR 5:6).
#
SAR_X, SAR_Y, DAR_X, DAR_Y = (320, 256, 5, 4)
P_COLOR = ( # (PAL / 6) / (NTSC / 7) = 97.22% of original NTSC rotation speed
  0x005, 0x00F, 0x050, 0x05A, 0x0A5, 0x0AF,
  0x0FA, 0x505, 0x50F, 0x5A0, 0x5AA, 0x5F5)
if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--output',  metavar=f'.svg', type=pathlib.Path,
    default=argparse.SUPPRESS, help=f'output filename (default={PATH_FILE})')
  parser.add_argument('--ntsc', action='store_true',
    default=False, help=f'generate a NTSC variant ({NTSC_FILE})')
  args = parser.parse_args()
  if hasattr(args, 'output'): PATH_FILE = args.output
  if args.ntsc:
    if not hasattr(args, 'output'): PATH_FILE = NTSC_FILE
    SAR_X, SAR_Y, DAR_X, DAR_Y = (320, 200, 4, 3)
    P_COLOR = (*P_COLOR[0:6], 0x0F0, *P_COLOR[6:12], 0x5FF)
B_HEIGHT = (B_WIDTH * SAR_Y * DAR_X + SAR_X * DAR_Y // 2) // (SAR_X * DAR_Y)
ANIM_LEN = len(P_COLOR) * 2 # * 2 fields/frame
Q_COUNT = 8 // 2
Q_ANGLE = mp.pi / 2 / Q_COUNT
A_COUNT = ANIM_LEN // 2 * Q_COUNT
R_ANGLE = mp.atan(mp.mpf(1) / 3) # 1:3 pixel stairs (clockwise, before scale)
BEZIERK = (mp.sqrt(385) - 13) / 12 # ~0.55178474 (integral of the errors = 0)
X_SCALE = mp.mpf(B_WIDTH) / 2
Y_SCALE = mp.mpf(B_HEIGHT) / 2
EAST, NORTH, WEST, SOUTH = (mp.mpf(0), mp.pi / 2, mp.pi, mp.pi * 3 / 2)
globe_p = lambda a, r=(X_SCALE, Y_SCALE), o=(X_SCALE, Y_SCALE) : (
  o[0] + r[0] * mp.cos(a - R_ANGLE), o[1] - r[1] * mp.sin(a - R_ANGLE))
NORTH_P = globe_p(NORTH)
SOUTH_P = globe_p(SOUTH)

xml = (
  '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n' +
  '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN"\n' +
  '\t"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">\n' +
  '<svg version="1.0" xmlns="http://www.w3.org/2000/svg"\n' +
  '\txmlns:xlink="http://www.w3.org/1999/xlink"\n' +
  f'\tviewBox="0 0 {B_WIDTH} {B_HEIGHT}"' +
  f' width="{B_WIDTH}px" height="{B_HEIGHT}px"' +
  ' preserveAspectRatio="xMinYMin">\n' +
  '\t<!-- disable path anti-aliasing in GIMP -->\n' +
  '\t<style type="text/css">path, rect {' +
  ' shape-rendering: crispEdges; }</style>\n' +
  '\t<defs>\n' +
  '\t\t<!-- binary channel filter (round to on/off) -->\n' +
  f'\t\t<filter id="f" x="0" y="0" width="{B_WIDTH}" height="{B_HEIGHT}">\n' +
  '\t\t\t<feComponentTransfer>\n' +
  '\t\t\t\t<feFuncR type="discrete" tableValues="0 1"/>\n' +
  '\t\t\t\t<feFuncG type="discrete" tableValues="0 1"/>\n' +
  '\t\t\t\t<feFuncB type="discrete" tableValues="0 1"/>\n' +
  '\t\t\t\t<feFuncA type="discrete" tableValues="0 1"/>\n' +
  '\t\t\t</feComponentTransfer>\n' +
  '\t\t</filter>\n' +
  f'\t\t<rect id="a" x="0" y="0" width="{B_WIDTH}" height="{B_HEIGHT}"/>\n')
xml += (
  '\t\t<!-- transformed arcs (GIMP does not tranform paths on import) -->\n')
# SVG arcs would be sufficient for PAR 1:1, but for height scaling we have
# to use cubic Bézier curves (GIMP converts the arcs during import anyway)
for i in reversed(range(A_COUNT)):
  COVERT = mp.cos(i * mp.pi / 2 / A_COUNT)
  WEST_P = globe_p(WEST, (X_SCALE * COVERT, Y_SCALE * COVERT))
  EAST_P = globe_p(EAST, (X_SCALE * COVERT, Y_SCALE * COVERT))
  ctrl_p = lambda o, a, k : globe_p(a, (X_SCALE * k, Y_SCALE * k), o)
  xml += (
    '\t\t<path id="a{0:02d}" d="M {1},{2}\n' +
    '\t\t\tC {3},{4}\n' +
    '\t\t\t  {5},{6} {7},{8}\n' +
    '\t\t\tS {9},{10} {11},{12}\n' +
    '\t\t\tS {13},{14} {15},{16}\n' +
    '\t\t\tS {17},{18} {19},{20}\n' +
    '\t\t\tZ"/><clipPath id="c{0:02d}">' +
    '<use xlink:href="#a{0:02d}"/></clipPath>\n').format(A_COUNT - i,
    *map(ff, NORTH_P), *map(ff, ctrl_p(NORTH_P, WEST, BEZIERK * COVERT)),
    *map(ff, ctrl_p(WEST_P, NORTH, BEZIERK)), *map(ff, WEST_P),
    *map(ff, ctrl_p(SOUTH_P, WEST, BEZIERK * COVERT)), *map(ff, SOUTH_P),
    *map(ff, ctrl_p(EAST_P, SOUTH, BEZIERK)), *map(ff, EAST_P),
    *map(ff, ctrl_p(NORTH_P, EAST, BEZIERK * COVERT)), *map(ff, NORTH_P))
xml += (
  '\t\t<mask id="m">\n' +
  '\t\t\t<path id="l" d="M {0},{1}\n' +
  '\t\t\t\tV 0 H 0 V {2} H {3} V {4} Z" fill="white"/>\n' +
  '\t\t</mask>\n' +
  '\t</defs>\n').format(*map(ff, NORTH_P), B_HEIGHT, *map(ff, SOUTH_P))
xml += (
  '\t<!-- arc fill is only for illustration, can be ignored/deleted -->\n' +
  '\t<g id="v" filter="url(#f)" mask="url(#m)">\n')
for i in range(A_COUNT):
  xml += (
    '\t\t<use xlink:href="#a" clip-path="url(#c{0:02d})" fill="{1}"/>\n'
    ).format(A_COUNT - i, 'black' if i & 1 else 'white')
xml += (
  '\t</g>\n' +
  '\t<g id="h">\n')
for i in reversed(range(1, Q_COUNT)):
  xml += (
    '\t\t<path id="n{0}" d="M {1},{2} L {3},{4} Z"/>\n').format(i,
    *map(ff, globe_p(WEST - Q_ANGLE * i)),
    *map(ff, globe_p(EAST + Q_ANGLE * i)))
xml += (
  '\t\t<path id="h0" d="M {0},{1} L {2},{3} Z"/>\n').format(
    *map(ff, globe_p(WEST)), *map(ff, globe_p(EAST)))
for i in range(1, Q_COUNT):
  xml += (
    '\t\t<path id="s{0}" d="M {1},{2} L {3},{4} Z"/>\n').format(i,
    *map(ff, globe_p(WEST + Q_ANGLE * i)),
    *map(ff, globe_p(EAST - Q_ANGLE * i)))
xml += (
  '\t</g>\n')
if len(P_COLOR) == ANIM_LEN // 2:
  P_SIZE = (3 * (6 * 2)) // len(P_COLOR)
  xml += (
    '\t<!-- animation grayscale ({0} * 2) * 2 intensity levels -->\n' +
    '\t<g id="g">\n').format(len(P_COLOR) // 2)
  for i in reversed(range(0, len(P_COLOR) * 2)):
    xml += (
      '\t\t<rect id="g{0:02d}" fill="#{3:02x}{3:02x}{3:02x}"' +
      ' width="{0}" height="{0}"'.format(P_SIZE) +
      ' y="{2}" x="{1}"/>\n').format(len(P_COLOR) * 2 - i,
      B_WIDTH - P_SIZE - (
        P_SIZE * ((len(P_COLOR) * 2 - i - 1) % (len(P_COLOR) // 2))),
      P_SIZE * ((len(P_COLOR) * 2 - i - 1) // (len(P_COLOR) // 2)),
      ((0xFF * 2 // 0x11 - i) * 0x11 + 2 // 2) // 2)
  xml += (
    '\t</g>\n' +
    '\t<!-- pixel art rotate/invertible ({0} * 2) * 2 color palette -->\n' +
    '\t<g id="p">\n').format(len(P_COLOR) // 2)
  P_FRMT = (
    '\t\t<rect id="{0}{1:X}" fill="#{4:03x}"' +
    ' width="{0}" height="{0}"'.format(P_SIZE) +
    ' y="{3}" x="{2}"/>\n')
  for i in range(0, len(P_COLOR) // 2):
    xml += P_FRMT.format('p', i + 1,
      P_SIZE * (len(P_COLOR) // 2 - i - 1), P_SIZE * 0,
      P_COLOR[i])
  for i in range(0, len(P_COLOR) // 2):
    xml += P_FRMT.format('i', len(P_COLOR) // 2 - i,
      P_SIZE * (len(P_COLOR) // 2 - i - 1), P_SIZE * 1,
      0xFFF & ~P_COLOR[len(P_COLOR) // 2 - i - 1])
  for i in range(0, len(P_COLOR) // 2):
    xml += P_FRMT.format('p', len(P_COLOR) // 2 + i + 1,
      P_SIZE * (len(P_COLOR) // 2 - i - 1), P_SIZE * 2,
      P_COLOR[len(P_COLOR) // 2 + i])
  for i in range(0, len(P_COLOR) // 2):
    xml += P_FRMT.format('i', len(P_COLOR) - i,
      P_SIZE * (len(P_COLOR) // 2 - i - 1), P_SIZE * 3,
      0xFFF & ~P_COLOR[len(P_COLOR) - i - 1])
  xml += (
    '\t</g>\n')
xml += (
  '</svg>\n')

with open(PATH_FILE, 'w', encoding='ascii') as svg: svg.write(xml)

