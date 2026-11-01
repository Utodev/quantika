# QUANTIKA ROM with FBASIC

Free system ROMs, written from scratch using a clean-room process, for the MSX2 machine that emu80
emulates as its second-generation home computer (V9938 video, 128K memory mapper, clock chip). emu80 uses 
them as its default ROMs.

Includes FBASIC, a  new implementation of BASIC language, compatible with the original BASIC for MSX up
to some extent.

| ROM | What it is | Source |
|---|---|---|
| `QUANTIKA.ROM` (32K) | the main ROM: BIOS (page 0) + FBASIC (page 1) | `main_free.asm` (BIOS + FBASIC) |
| `QUANTIKA_SUB.ROM` (16K) | the sub-ROM of the second version of the standard | `sub_free.asm` (+ `sub/`) |
| `QUANTIKA_DISK.ROM` (16K) | the disk interface's ROM (WD2793 at 7FF8h-7FFFh): driver, disk BASIC and DOS kernel | `disk_free.asm` (+ `disk/`) |

The disk ROM works only with this main ROM: it calls FBASIC through the service table of `common/diskapi.inc`,
and FBASIC hands it the disk's statements through the hooks described there. It has the driver, a DOS kernel
(compatible with the first version: its own DOS disks boot), the boot, and disk BASIC: programs (LOAD, SAVE,
MERGE, RUN, BLOAD, BSAVE, FILES, LFILES, KILL, NAME, COPY, DSKF, CALL FORMAT, CALL SYSTEM, AUTOEXEC.BAS) and
files (OPEN for input, output, append and random access, FIELD, GET, PUT, LSET, RSET, MKI$ / CVI and the
like, EOF, LOC, LOF, INPUT$, DSKI$, DSKO$). When it is installed, the line "QUANTIKA Disk BASIC extension
1.0" shows under BASIC's banner.

They are written from the published standard (jump table, work area, hooks, token numbers, number formats,
I/O ports). The original ROMs are never disassembled or copied: they are only run as black boxes in emu80 to
compare results (emu80's ROM comparison tests). Only the documented interface is fixed; everything behind it
(the code, its addresses, the algorithms, the font, the boot messages) is these ROMs' own. The BASIC is FBASIC
1.0, compatible with programs for the original BASIC 2.1 (same tokens, line format, error codes and hooks).

KEY ON / KEY OFF, DSPFNK / ERAFNK show and hide it date and time on screen. 

The function keys are not shown and type nothing at power-on: their ten strings start empty (KEY n,"..." gives
them one; ON KEY GOSUB works as usual).

# Compatibility

These ROMS were made for the emu80 emulator, which implements a specific MSX 2 machine. They won't probably
work for with other emulators, nor with a real machine.

## Building

    ./build.sh

needs `sjasmplus` (sjasmplus 1.20 or later) in the PATH, and Python 3. It writes `out/main_free.rom`,
`out/sub_free.rom` and `out/disk_free.rom` (the sizes are checked), with their symbols and listings, in `out/`.

    ./install.sh <folder>

copies them to that folder as `QUANTIKA.ROM`, `QUANTIKA_SUB.ROM` and `QUANTIKA_DISK.ROM`. 

## Layout

- `common/hw.inc`: I/O ports. `common/sysvars.inc`: work area and hooks (fixed addresses).
- `sub_free.asm` and `sub/`: the sub-ROM (it reaches the main ROM through the RAM primitives); part of
  FBASIC lives there too (`common/fbasicsub.inc`, `basic/substubs.asm`, `tools/mksubwrappers.py`).
- `layout_main.txt`: the free areas of the main ROM and its movable modules (`page0` for code that the
  interrupt or a BIOS entry runs: a cartridge may be in page 1). `tools/pack.py` places them.
- `main_free.asm`: the main ROM; `bios/jumptable.asm` is the fixed jump table, the rest of `bios/` the BIOS
  code, `data/` the font and tables, `basic/` FBASIC.
- `tools/`: the generators (`mkfont.py`, `mkkeys.py`, `mktokens.py`), `pack.py`, `mksubwrappers.py`, and
  `fixjr.py` (`./build.sh 2>&1 | python3 tools/fixjr.py` turns the JRs that are out of range into JPs).
- `tests/`: test programs (machine code at C000h, BASIC texts, tape tests, pictures) that emu80's comparison
  tests run on the original ROMs and on these.
- Labels are English, numbers hexadecimal (`$F3DF`), every routine says what it takes, returns and destroys.

