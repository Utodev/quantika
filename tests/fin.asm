; fin.asm: FIN on the texts below, from case FIRST: per case (16 bytes) VALTYP, DAC (8), the characters
; read (HL after - HL before), B, C, D and the character at HL after
        include "common.inc"
        include "../common/mathpack.inc"
VALTYP  equ $F663
DAC     equ $F7F6
        ifndef FIRST
FIRST   equ 0
        endif
        TEST_START
        ld hl,Texts
        ld b,FIRST
        inc b
.skip:  dec b
        jr z,.start
.skipText:
        ld a,(hl)
        inc hl
        or a
        jr nz,.skipText
        jr .skip
.start:
        ld iy,Results
        ld c,16
.case:
        ld a,(hl)
        or a
        jp z,TestEnd
        push bc
        push hl
        ld de,DAC                       ; DAC to a known value
        ld b,16
.fill:  ld a,$EE
        ld (de),a
        inc de
        djnz .fill
        ld a,(hl)
        push iy
        call FIN
        pop iy
        ld a,(hl)
        ld (iy+13),a
        pop de
        push hl
        or a
        sbc hl,de
        ld (iy+9),l
        ld a,(VALTYP)
        ld (iy+0),a
        push iy
        pop de
        inc de
        ld hl,DAC
        ld bc,8
        ldir
        pop hl
.next:  ld a,(hl)                       ; to the next text
        inc hl
        or a
        jr nz,.next
        ld bc,16
        add iy,bc
        pop bc
        dec c
        jr nz,.case
        jp TestEnd
Texts:
        db "5",0, "123",0, "32767",0, "32768",0, "1.5",0, "1234567",0, "12345678901234567",0, ".5",0
        db "1E3",0, "1D3",0, "1.5E-2",0, "12%",0, "12!",0, "12#",0, "1.5#",0, "0",0
        db "00012",0, "1 2 3",0, "1.2.3",0, "-5",0, "+7",0, "&H10",0, "1E",0, "1E+",0
        db "123456",0, "1234567.",0, "0.0001",0, "65536",0, "1e5",0, "3:",0, "999999.5",0, "7 EQV",0, "7 E5",0, "7E 5",0, "1 .5",0, "1. 5",0, "7 D",0
        db 0
        TEST_END "../out/fin.bin"
