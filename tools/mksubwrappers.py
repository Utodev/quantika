#!/usr/bin/env python3
"""mksubwrappers.py: out/subwrappers.inc, what the FBASIC code assembled into the sub-ROM needs of
the main ROM. The sub-ROM is assembled with what it has; every label it misses is looked up in the
main ROM's symbols (out/main_free.sym) and gets a wrapper that calls it through CallMain, with the main
ROM in page 0 while it runs: even a routine in page 1, which is visible from here, may call one in page
0. Repeats until nothing is missing.
usage: mksubwrappers.py <asm> <main.sym> <out.inc>"""
import re, subprocess, sys

asm, symfile, out = sys.argv[1:4]
syms = {}
for line in open(symfile):
    m = re.match(r'(\S+): EQU 0x([0-9A-Fa-f]+)', line)
    if m:
        syms[m.group(1)] = int(m.group(2), 16)

def write(names):
    with open(out, 'w', newline='\n') as f:
        f.write('; out/subwrappers.inc: made by tools/mksubwrappers.py (do not edit)\n')
        for n in sorted(names):
            a = syms[n]
            f.write(f'{n}:                            ; (IX kept: CallMain uses it)\n        push ix\n        ld ix,${a:04X}\n'
                        f'        call CallMain\n        pop ix\n        ret\n')

names = set()
while True:
    write(names)
    r = subprocess.run(['sjasmplus.exe', '--nologo', '-Icommon', asm], capture_output=True, text=True)
    missing = set(re.findall(r'Label not found: ([\w.]+)', r.stdout + r.stderr))
    if not missing:
        break
    unknown = [n for n in missing if n not in syms]
    small = [n for n in missing if n in syms and syms[n] < 0x0200]   # (a constant, not a routine)
    if small:
        sys.exit('mksubwrappers: looks like a constant: ' + ', '.join(sorted(small)))
    if unknown:
        sys.exit('mksubwrappers: not in the main ROM either: ' + ', '.join(sorted(unknown)))
    names |= missing
print(f'{len(names)} main ROM labels through CallMain')
