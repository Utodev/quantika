; textops.asm: the sub-ROM's DELLNO, INSLNO, PUTVRM (-DOP=0121h, 0125h, 0129h) in 40 columns: rows 1-6 hold "AA" to
; "FF", then OP with H = 5, L = 3, A = "*", C = "G" (PUTVRM's character is in C). The screen is compared.
        include "common.inc"
EXTROM  equ $015F
        TEST_START
        ld b,6
        ld c,'A'
.row:   push bc
        ld a,c
        call CHPUT
        ld a,c
        call CHPUT
        ld a,13
        call CHPUT
        ld a,10
        call CHPUT
        pop bc
        inc c
        djnz .row
        ld h,5
        ld l,3
        ld a,'*'
        ld ix,OP
        call EXTROM
        jp TestEnd                      ; (what they leave in the registers is not given)
        TEST_END "../out/textops.bin"
