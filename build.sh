#!/bin/bash
# Builds the QUANTIKA ROMs with sjasmplus (see README.md).
#   build.sh            builds every ROM whose source exists
# Output: out/<name>.rom (checked size), out/<name>.sym and .lst. install.sh copies them where an emulator
# wants them. The build fails if the machine's name is in the sources or in the ROMs (see CLAUDE.md).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
python3 "$HERE/tools/mkfont.py" > /dev/null     # data/font.asm from data/font_*.txt
python3 "$HERE/tools/mkkeys.py" > /dev/null     # data/keymap.asm
python3 "$HERE/tools/mktokens.py" > /dev/null   # data/keywords.asm, common/tokens.inc
OUT="$HERE/out"
ASM=sjasmplus.exe
mkdir -p "$OUT"
# the build's date and time, shown at boot ("Build: YYYY.MM.DD-HH.MM")
printf '        define BUILD_STAMP "%s"\n' "$(date +%Y.%m.%d-%H.%M)" > "$OUT/buildstamp.inc"

# name  source  size  layout (tools/pack.py places its modules; - when none)
ROMS=(
  "main_free.rom  main_free.asm  32768  main"
  "sub_free.rom   sub_free.asm   16384  -"
)
for E in "${ROMS[@]}"; do
  read -r NAME SRC SIZE LAYOUT <<<"$E"
  [ -f "$HERE/$SRC" ] || continue
  BASE="${NAME%.rom}"
  if [ "$LAYOUT" != - ]; then
    # two passes: the modules in a row to measure them, then where they fit
    python3 "$HERE/tools/pack.py" measure "$HERE/layout_$LAYOUT.txt" "$OUT/layout_$LAYOUT.inc"
    ( cd "$HERE" && $ASM --nologo --sym="out/$BASE.sym" -Icommon -Iout "$SRC" > "$OUT/$BASE.measure.log" 2>&1 ) || {
      cat "$OUT/$BASE.measure.log"; exit 1; }
    ( cd "$HERE" && python3 tools/pack.py place "layout_$LAYOUT.txt" "out/$BASE.sym" "out/layout_$LAYOUT.inc" )
  fi
  if [ "$SRC" = sub_free.asm ]; then    # FBASIC's code in the sub-ROM reaches the main ROM
    ( cd "$HERE" && python3 tools/mksubwrappers.py "$SRC" out/main_free.sym out/subwrappers.inc )
  fi
  ( cd "$HERE" && $ASM --nologo --sym="out/$BASE.sym" --lst="out/$BASE.lst" -Icommon -Iout "$SRC" )
  ACTUAL=$(stat -c %s "$OUT/$NAME")
  if [ "$ACTUAL" -ne "$SIZE" ]; then
    echo "ERROR: $NAME is $ACTUAL bytes, it must be $SIZE" >&2
    exit 1
  fi
  echo "built $NAME ($SIZE bytes)"
done
# the machine's name is never in these sources nor in the ROMs (see CLAUDE.md)
NAME=$(printf '\115\123\130')
if grep -rIli "$NAME" --exclude-dir=out --exclude-dir=__pycache__ --exclude-dir=.git "$HERE"; then
  echo "ERROR: the files above have the machine's name (see CLAUDE.md)" >&2
  exit 1
fi
for R in "$OUT"/*_free.rom; do
  if LC_ALL=C grep -aqi "$NAME" "$R"; then echo "ERROR: $(basename "$R") has the machine's name" >&2; exit 1; fi
done
