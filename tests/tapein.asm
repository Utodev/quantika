; tapein.asm: TAPION / TAPIN on a tape (the test harness: exec -tape): the first 16 bytes of the first two
; blocks to Results and Results + 20h; the carry of each call counts in Results + 1Fh / 3Fh
        include "common.inc"
TAPION  equ $00E1
TAPIN   equ $00E4
TAPIOF  equ $00E7
        TEST_START
        ld ix,Results
        call ReadBlock
        ld ix,Results + $20
        call ReadBlock
        call TAPIOF
        jp TestEnd

ReadBlock:
        call TAPION
        jr nc,.headerOk
        inc (ix+$1F)
.headerOk:
        ld b,16
.byte:
        push bc
        call TAPIN
        pop bc
        jr nc,.byteOk
        inc (ix+$1F)
.byteOk:
        ld (ix+0),a
        inc ix
        djnz .byte
        ret
        TEST_END "../out/tapein.bin"
