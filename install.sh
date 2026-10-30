#!/bin/bash
# install.sh <folder>: copies the ROMs that build.sh made to <folder> as QUANTIKA.ROM (the main ROM: BIOS and
# FBASIC) and QUANTIKA_SUB.ROM (the sub-ROM). emu80 runs it (through its package.sh) with its roms folder.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -n "$1" ] || { echo "usage: install.sh <folder>" >&2; exit 2; }
mkdir -p "$1"
cp -f "$HERE/out/main_free.rom" "$1/QUANTIKA.ROM"
cp -f "$HERE/out/sub_free.rom" "$1/QUANTIKA_SUB.ROM"
echo "installed QUANTIKA.ROM and QUANTIKA_SUB.ROM in $1"
