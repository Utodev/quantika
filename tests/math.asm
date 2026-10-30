; math.asm: the Math-Pack entries on the cases of mathcases.inc (tools/mkmathtest.py). For each case:
; VALTYP and the 8 bytes of DAC after the call go to Results (9 bytes a case, the first 28 cases fit).
        include "common.inc"
        include "../common/mathpack.inc"
VALTYP  equ $F663
DAC     equ $F7F6
ARG     equ $F847
        ifndef FIRST
FIRST   equ 0
        endif
        TEST_START
        ld ix,Cases + FIRST * 19
        ld iy,Results
.case:
        ld l,(ix+0)
        ld h,(ix+1)
        ld a,h
        or l
        jp z,TestEnd
        ld (.call + 1),hl
        ld a,(ix+2)
        ld (VALTYP),a
        push ix
        pop hl
        inc hl
        inc hl
        inc hl
        ld de,DAC
        ld bc,8
        ldir
        ld de,ARG
        ld bc,8
        ldir
        xor a
        ld (DAC + 8),a
        ld (ARG + 8),a
        push ix
        push iy
.call:
        call $0000
        pop iy
        pop ix
        ld a,(VALTYP)
        ld (iy+0),a
        push iy
        pop de
        inc de
        ld hl,DAC
        ld bc,8
        ldir
        ld bc,9
        add iy,bc
        ld bc,19
        add ix,bc
        push iy                         ; stop before the results run past D0FFh
        pop hl
        ld a,h
        cp high Results + 1
        jp nc,TestEnd
        jr .case
        include "mathcases.inc"
        TEST_END "../out/math.bin"
