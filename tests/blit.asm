; blit.asm: the sub-ROM's BLTVV, BLTMV and BLTVM in SCREEN 8: a 4 x 2 block (1-8) copied in VRAM, to RAM (with
; its header) and back, then BLTVV again with XOR over the first copy. Results: the flags (Z, C), the pixels,
; the RAM, the parameters after.
        include "common.inc"
EXTROM  equ $015F
NWRVRM  equ $0177
NRDVRM  equ $0174
SX      equ $F562
        TEST_START
        call ERAFNK
        ld a,8
        call CHGMOD
        xor a
        call CLS
        ; pattern 1..8 at (0..3, 0..1)
        ld hl,0
        ld a,1
        ld b,4
.p0:    push af
        call NWRVRM
        pop af
        inc a
        inc hl
        djnz .p0
        ld hl,256
        ld b,4
.p1:    push af
        call NWRVRM
        pop af
        inc a
        inc hl
        djnz .p1
        ld iy,Results
        ; BLTVV (0,0) 4x2 -> (10,5)
        ld hl,Params1
        ld de,SX
        ld bc,15
        ldir
        ld hl,SX
        ld ix,$0191
        call EXTROM
        call flags
        ld hl,5*256+10
        call read8
        ; BLTMV (0,0) 4x2 -> RAM E000
        ld hl,$E000
        ld b,16
.cl:    ld (hl),$EE
        inc hl
        djnz .cl
        ld hl,Params2
        ld de,SX
        ld bc,15
        ldir
        ld hl,SX
        ld ix,$0199
        call EXTROM
        call flags
        ld hl,$E000
        ld b,14
.cp:    ld a,(hl)
        ld (iy+0),a
        inc iy
        inc hl
        djnz .cp
        ; BLTVM RAM E000 -> (20,8)
        ld hl,Params3
        ld de,SX
        ld bc,15
        ldir
        ld hl,SX
        ld ix,$0195
        call EXTROM
        call flags
        ld hl,8*256+20
        call read8
        ld hl,Params4                   ; BLTVV with XOR (L_OP 3) over the first copy
        ld de,SX
        ld bc,15
        ldir
        ld hl,SX
        ld ix,$0191
        call EXTROM
        call flags
        ld hl,5*256+10
        call read8
        ld hl,SX
        ld b,15
.pp:    ld a,(hl)
        ld (iy+0),a
        inc iy
        inc hl
        djnz .pp
        jp TestEnd
flags:  push af
        pop hl
        ld a,l
        and $41
        ld (iy+0),a
        inc iy
        ret
read8:  ld b,4
.r0:    push bc
        push hl
        call NRDVRM
        ld (iy+0),a
        inc iy
        pop hl
        inc hl
        pop bc
        djnz .r0
        ld de,256-4
        add hl,de
        ld b,4
.r1:    push bc
        push hl
        call NRDVRM
        ld (iy+0),a
        inc iy
        pop hl
        inc hl
        pop bc
        djnz .r1
        ret
Params1: dw 0,0,10,5,4,2
        db 0,0,0
Params2: dw 0,0,$E000,0,4,2
        db 0,0,0
Params3: dw $E000,0,20,8,4,2
        db 0,0,0
Params4: dw 0,0,10,5,4,2
        db 0,0,3
        TEST_END "../out/blit.bin"
