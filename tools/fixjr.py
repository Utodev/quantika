#!/usr/bin/env python3
"""fixjr.py: reads sjasmplus output on stdin and turns every 'jr' it says is out of range into 'jp'
(in the source file and line it names). Run from this project's folder: ./build.sh 2>&1 | python3 tools/fixjr.py"""
import re
import sys
import os
done = 0
for line in sys.stdin:
    m = re.match(r'(\S+?)\((\d+)\): error: \[JR\] Target out of range', line)
    if not m:
        continue
    name, n = m.group(1), int(m.group(2))
    path = None
    for root, _, files in os.walk('.'):
        if name in files and 'out' not in root:
            path = os.path.join(root, name)
            break
    if not path:
        continue
    lines = open(path).read().split('\n')
    old = lines[n - 1]
    new = re.sub(r'\bjr(\s)', r'jp\1', old, count=1)
    if new != old:
        lines[n - 1] = new
        open(path, 'w').write('\n'.join(lines))
        done += 1
print('fixjr.py: %d jumps made long' % done)
