#!/usr/bin/env python3
"""Create the editable UI diagram, not a transformation of a generated image."""
from pathlib import Path
import math
root=Path(__file__).resolve().parent.parent
parts=['''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="1200" viewBox="0 0 900 1200" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
<title>Pilot Pro — mapa de controls</title>
<desc>Esquema amb quatre botons a cada lateral en graella 2 per 2, creu inferior, tres controls giratoris i joystick central. Fons transparent. Les superfícies laterals s'han desplegat per facilitar la configuració.</desc>
<g id="body">
<path d="M350 85 C300 85 283 115 260 166 L180 345 C153 407 152 478 177 548 L313 1030 Q325 1075 370 1075 H530 Q575 1075 587 1030 L723 548 C748 478 747 407 720 345 L640 166 C617 115 600 85 550 85 Z"/>
<path d="M362 110 C322 110 307 139 288 182 L211 354 C184 416 184 477 207 542 L338 1026 Q344 1050 371 1050 H529 Q556 1050 562 1026 L693 542 C716 477 716 416 689 354 L612 182 C593 139 578 110 538 110 Z" stroke-width="2"/>
</g>
<g id="small-wheel"><circle cx="450" cy="207" r="48"/><ellipse cx="450" cy="207" rx="35" ry="35" stroke-width="2"/></g>
<g id="large-wheel"><circle cx="450" cy="510" r="220"/><circle cx="450" cy="510" r="190" stroke-width="2"/>''']
for i in range(96):
 a=2*math.pi*i/96
 x1=450+197*math.cos(a);y1=510+197*math.sin(a)
 x2=450+211*math.cos(a);y2=510+211*math.sin(a)
 parts.append(f'<path d="M{x1:.2f} {y1:.2f} L{x2:.2f} {y2:.2f}" stroke-width="2"/>')
parts.append('''</g><g id="dial"><circle cx="450" cy="510" r="166"/><circle cx="450" cy="510" r="149" stroke-width="2"/></g>
<g id="joystick"><circle cx="450" cy="510" r="104"/><circle cx="450" cy="510" r="62"/><path d="M418 455 Q450 439 482 455" stroke-width="2"/></g>''')
# Flattened side-wall banks are deliberately schematic, not an inaccurate perspective.
for side,xx,yy in [('left',20,185),('right',688,715)]:
 parts.append(f'<g id="side-{side}"><rect x="{xx-6}" y="{yy-11}" width="138" height="192" rx="20" stroke-width="2"/>')
 for i in range(4):
  x=xx+(i%2)*66;y=yy+(i//2)*86
  parts.append(f'<rect id="side.{side}.{i+1}" x="{x}" y="{y}" width="60" height="78" rx="9"/>')
 parts.append('</g>')
parts.append('''<g id="cross">
<path id="cross.up" d="M425 814 Q450 808 475 814 Q487 817 487 831 V856 L450 884 L413 856 V831 Q413 817 425 814 Z"/>
<path id="cross.down" d="M425 984 Q450 990 475 984 Q487 981 487 967 V942 L450 914 L413 942 V967 Q413 981 425 984 Z"/>
<path id="cross.left" d="M365 874 Q359 899 365 924 Q368 936 382 936 H407 L435 899 L407 862 H382 Q368 862 365 874 Z"/>
<path id="cross.right" d="M535 874 Q541 899 535 924 Q532 936 518 936 H493 L465 899 L493 862 H518 Q532 862 535 874 Z"/>
</g></svg>''')
(root/'Assets/Pilot-Pro-white.svg').write_text('\n'.join(parts))
