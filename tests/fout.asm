; fout.asm: FOUT on the numbers of foutcases.inc (tools/mkfouttest.py), from case FIRST: the text of each
; one (16 bytes, zero padded) to Results
        include "common.inc"
        include "../common/mathpack.inc"
VALTYP  equ $F663
DAC     equ $F7F6
        ifndef FIRST
FIRST   equ 0
        endif
        TEST_START
        ld ix,Cases + FIRST * 9
        ld iy,Results
        ld b,16
.case:
        push bc
        ld a,(ix+0)
        or a
        jp z,TestEnd
        ld (VALTYP),a
        push ix
        pop hl
        inc hl
        ld de,DAC
        ld bc,8
        ldir
        push ix
        push iy
        call FOUT
        pop iy
        pop ix
        push iy
        pop de
        ld b,16
.copy:
        ld a,(hl)
        or a
        jr z,.padded
        ld (de),a
        inc hl
        inc de
        djnz .copy
.padded:
        ld bc,16
        add iy,bc
        ld bc,9
        add ix,bc
        pop bc
        djnz .case
        jp TestEnd
        include "foutcases.inc"
        TEST_END "../out/fout.bin"
