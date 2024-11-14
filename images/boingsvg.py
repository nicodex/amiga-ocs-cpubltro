#!/usr/bin/env python3

import sys
from mpmath import mp

FRAME_COUNT = 11 # original has 14 frames (color cycling steps)
FILE_PREFIX = 'boing'
RENDER_SIZE = '240px' # original size 94mm (Amiga monitor 1081)

SHADE_NONE, SHADE_CCW, SHADE_CW = range(3)
SHADE_TYPE = SHADE_CCW

mp.dps = 36

def nstr(x):
  return f'{mp.nstr(x, 17, min_fixed=mp.ninf, max_fixed=mp.inf):0<18s}'

BALL_SCALE = 112 // 2 # Boing! ball radius (viewPort = LoRes pixel)
BALL_WIDTH = BALL_SCALE * 2
QUAD_COUNT = 8 // 2 # horizontal/vertical squares per sphere octant
QUAD_ANGLE = mp.pi / 2 / QUAD_COUNT
STEP_COUNT = 14 // 2 # horizontal (color palette) steps per square
STEP_ANGLE = QUAD_ANGLE / STEP_COUNT

# Some SVG renderers use alpha blending for the path edges,
# therefore, to avoid translucent effects at the square edges,
# we draw them strictly from back to front with slight overlap.
QUAD_OVERLAP = STEP_ANGLE / 2
# initial Boing! ball frame starts with two clockwise color steps
ROTATE_ANGLE = STEP_ANGLE * 2

FRAME_ANGLE = QUAD_ANGLE * 2 / FRAME_COUNT

def svg_head(frame):
  return (
    '<svg version="1.1"' +
    ' xmlns="http://www.w3.org/2000/svg"' +
    ' viewBox="0 0 {0:d} {0:d}"'.format(BALL_WIDTH) +
    ' preserveAspectRatio="xMinYMin"' +
    ' width="{0:s}" height="{0:s}">\n'.format(RENDER_SIZE) +
    '\t<title>Amiga Boing! ball (frame {0:d}/{1:d})</title>\n'.format(
      frame, FRAME_COUNT) +
    '\t<style>circle, path { shape-rendering: crispEdges; }</style>\n')

def svg_foot():
  return '</svg>\n'

def svg_clip():
  fmt = '\t\t\t<path d="M 0,{1:s} H {0:d} V {2:s} H 0 z"/>\n'
  # draw order: o(dd) first, e(ven) second
  xml = '\t\t<clipPath id="o">\n'
  for i in range(0, QUAD_COUNT * 2, 2):
    xml += fmt.format(BALL_WIDTH, nstr(mp.mpf(0)) if i <= 0 else (
      nstr((1 - mp.cos(QUAD_ANGLE * (i + 0) - QUAD_OVERLAP)) * BALL_SCALE)),
      nstr((1 - mp.cos(QUAD_ANGLE * (i + 1) + QUAD_OVERLAP)) * BALL_SCALE))
  xml += '\t\t</clipPath>\n'
  xml += '\t\t<clipPath id="e">\n'
  for i in range(1, QUAD_COUNT * 2, 2):
    xml += fmt.format(BALL_WIDTH,
      nstr((1 - mp.cos(QUAD_ANGLE * (i + 0))) * BALL_SCALE),
      nstr((1 - mp.cos(QUAD_ANGLE * (i + 1))) * BALL_SCALE))
  xml += '\t\t</clipPath>\n'
  if SHADE_TYPE != SHADE_NONE:
    xml += '\t\t<clipPath id="s">\n'
    for i in range(0, QUAD_COUNT * 2, 2):
      xml += fmt.format(BALL_WIDTH,
        nstr((1 - mp.cos(QUAD_ANGLE * (i + 0))) * BALL_SCALE),
        nstr((1 - mp.cos(QUAD_ANGLE * (i + 1))) * BALL_SCALE))
    xml += '\t\t</clipPath>\n'
  return xml

def svg_defs():
  return (
    '\t<defs>\n' +
    svg_clip() +
    '\t</defs>\n')
  return code

def svg_ball(index):
  xml = '\t<g transform="rotate({0:s} {1:d} {1:d})">\n'.format(
    nstr(mp.degrees(mp.atan(mp.mpf(1) / 3))), BALL_SCALE)
  fmt = (
    '\t\t<path d="M {0:d},0' +
    ' a {2:s},{0:d} {3:s} 0,{1:d} ' +
    ' A {4:s},{0:d} {5:s} {0:d},0 z"' +
    ' clip-path="url(#{6:s})" fill="{7:s}"/>\n')
  # left/back to center/front
  for i in reversed(range(-1, QUAD_COUNT + 2)):
    a1 = (ROTATE_ANGLE + (QUAD_ANGLE * (i + 1)) - (FRAME_ANGLE * index))
    a2 = (ROTATE_ANGLE + (QUAD_ANGLE * (i + 0)) - (FRAME_ANGLE * index) -
      QUAD_OVERLAP)
    x1 = BALL_SCALE * mp.sin(a1) * mp.sign(mp.cos(a1))
    x2 = BALL_SCALE * mp.sin(a2) * mp.sign(mp.cos(a2))
    if x1 < 0:
      x1 = mp.mpf(BALL_SCALE)
      if x2 < 0:
        continue
    xml += fmt.format(BALL_SCALE, BALL_WIDTH,
      nstr(mp.fabs(x1)), '0,0,0' if x1 >= 0 else '0,0,1',
      nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
      'o', '#F00' if i & 1 else '#FFF')
    xml += fmt.format(BALL_SCALE, BALL_WIDTH,
      nstr(mp.fabs(x1)), '0,0,0' if x1 >= 0 else '0,0,1',
      nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
      'e', '#FFF' if i & 1 else '#F00')
    if SHADE_TYPE != SHADE_NONE:
      if SHADE_CCW == SHADE_TYPE:
        a1 -= QUAD_ANGLE - STEP_ANGLE
      else:
        a2 = a1 - STEP_ANGLE
      x1 = BALL_SCALE * mp.sin(a1) * mp.sign(mp.cos(a1))
      x2 = BALL_SCALE * mp.sin(a2) * mp.sign(mp.cos(a2))
      if x1 < 0:
        if x2 >= 0:
          x1 = mp.mpf(BALL_SCALE)
        elif SHADE_CW == SHADE_TYPE:
          continue
      xml += fmt.format(BALL_SCALE, BALL_WIDTH,
        nstr(mp.fabs(x1)), '0,0,0' if x1 >= 0 else '0,0,1',
        nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
        'e' if i & 1 else 's', '#FDD')
  # right/back to center/front
  for i in reversed(range(-1, QUAD_COUNT + 1)):
    a1 = (ROTATE_ANGLE - (QUAD_ANGLE * (i + 0)) - (FRAME_ANGLE * index))
    a2 = (ROTATE_ANGLE - (QUAD_ANGLE * (i + 1)) - (FRAME_ANGLE * index))
    if a1 < -QUAD_ANGLE:
      a1 += QUAD_OVERLAP
    x1 = BALL_SCALE * mp.sin(a1) * mp.sign(mp.cos(a1))
    x2 = BALL_SCALE * mp.sin(a2) * mp.sign(mp.cos(a2))
    if x1 >= 0:
      continue
    if x2 >= 0:
      x2 = mp.mpf(-BALL_SCALE)
    xml += fmt.format(BALL_SCALE, BALL_WIDTH,
      nstr(mp.fabs(x1)), '0,0,1',
      nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
      'o', '#FFF' if i & 1 else '#F00')
    xml += fmt.format(BALL_SCALE, BALL_WIDTH,
      nstr(mp.fabs(x1)), '0,0,1',
      nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
      'e', '#F00' if i & 1 else '#FFF')
    if SHADE_TYPE != SHADE_NONE:
      if SHADE_CCW == SHADE_TYPE:
        a1 = a2 + STEP_ANGLE
      else:
        a2 = a1 - STEP_ANGLE
      x1 = BALL_SCALE * mp.sin(a1) * mp.sign(mp.cos(a1))
      x2 = BALL_SCALE * mp.sin(a2) * mp.sign(mp.cos(a2))
      if x1 >= 0:
        continue
      if x2 >= 0:
        x2 = mp.mpf(-BALL_SCALE)
      xml += fmt.format(BALL_SCALE, BALL_WIDTH,
        nstr(mp.fabs(x1)), '0,0,0' if x1 >= 0 else '0,0,1',
        nstr(mp.fabs(x2)), '0,0,1' if x2 >= 0 else '0,0,0',
        's' if i & 1 else 'e', '#FDD')
  xml += '\t</g>\n'
  return xml

for index in range(FRAME_COUNT):
  frame = index + 1
  xml = (
    svg_head(frame) +
    svg_defs() +
    svg_ball(index) +
    svg_foot())
  filename = '{0:s}{1:03d}.svg'.format(FILE_PREFIX, frame)
  with open(filename, 'w', encoding='ascii') as svg:
    svg.write(xml)

