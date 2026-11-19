#!/usr/bin/env python3
"""Summarize Pilot Pro's observed USB reports; no device access or writes."""
import collections
import json
import re
import struct
import sys
from pathlib import Path


def analyze(path):
    reports = []
    for line in Path(path).read_text().splitlines():
        match = re.search(r'report=2 len=12 ([0-9a-f ]+)$', line)
        if match:
            report = bytes.fromhex(match[1])
            if len(report) == 12 and report[0] == 2:
                reports.append(report)
    joystick = [struct.unpack_from('<hh', b, 4) for b in reports if b[1:3] == b'\xf3\x01']
    wheels = [b for b in reports if b[1:3] == b'\xf3\x02']
    buttons = [b for b in reports if b[1:3] == b'\xf3\x03']
    return {
        'file': str(path),
        'total_reports': len(reports),
        'families': dict(collections.Counter(f'{b[1]:02x}/{b[2]:02x}' for b in reports)),
        'joystick': {'reports': len(joystick), 'x_range': [min(x for x, y in joystick), max(x for x, y in joystick)] if joystick else [],
                     'y_range': [min(y for x, y in joystick), max(y for x, y in joystick)] if joystick else []},
        'wheels': {'reports': len(wheels), 'hardware_ids': sorted({b[4] for b in wheels}),
                   'direction_codes': sorted({b[3] for b in wheels})},
        'buttons': {'reports': len(buttons), 'observed_group_masks': [sorted({b[i] for b in buttons}) for i in range(4, 8)]},
    }


if __name__ == '__main__':
    print(json.dumps([analyze(path) for path in sys.argv[1:]], indent=2))
