; boxes.asm: the sub-ROM's DOGRPH, NVBXLN and NVBXFL (-DOP=0085h, 00C9h, 00CDh) in SCREEN MODE (5-8):
; GRPACX / GRPACY = (2, 1), GXPOS / GYPOS = (9, 5), BC / DE = (4, 3), colour 15. Results: the carry, GRPACX,
; GRPACY, GXPOS, GYPOS after (low bytes), then rows 0-6, columns 0-15 of the picture (1: drawn).
        include "common.inc"
EXTROM  equ $015F
GRPACX  equ $FCB7
GRPACY  equ $FCB9
GXPOS   equ $FCB3
GYPOS   equ $FCB5
ATRBYT  equ $F3F2
LOGOPR  equ $FB02
NRDVRM  equ $0174
        TEST_START
        call ERAFNK
        ld hl,$0000
        ld ($F3E9),hl
        ld a,MODE
        call CHGMOD
        xor a
        call CLS
        ld a,15
        ld (ATRBYT),a
        xor a
        ld (LOGOPR),a
        ld hl,2
        ld (GRPACX),hl
        ld hl,1
        ld (GRPACY),hl
        ld hl,9
        ld (GXPOS),hl
        ld hl,5
        ld (GYPOS),hl
        ld bc,4
        ld de,3
        ld ix,OP
        call EXTROM
        ld iy,Results
        ld (iy+0),$00                   ; (the carry is not given: the original's differs by mode)
        ld a,(GRPACX)
        ld (iy+1),a
        ld a,(GRPACY)
        ld (iy+2),a
        ld a,(GXPOS)
        ld (iy+3),a
        ld a,(GYPOS)
        ld (iy+4),a
        ld iy,Results + 8
        ld e,0
.row:
        ld d,0
.column:
        push de
        call PixelAt                    ; A = the pixel at D, E
        pop de
        ld (iy+0),a
        inc iy
        inc d
        ld a,d
        cp 16
        jr nz,.column
        inc e
        ld a,e
        cp 7
        jr nz,.row
        jp TestEnd

; PixelAt: A = 1 when the pixel D (x), E (y) is not 0. (The byte of the pixel, read whole: enough here.)
PixelAt:
        ld h,e                          ; HL = y * bytes a row + x * bytes a pixel
        ld l,0
        if MODE == 5 || MODE == 6
        srl h
        rr l
        ld a,d
        srl a
        if MODE == 6
        srl a
        endif
        else
        ld a,d
        if MODE == 7
        srl a
        endif
        endif
        add a,l
        ld l,a
        if MODE >= 7
        add hl,hl                       ; (SCREEN 7 and 8: 256 bytes a row, interleaved: the address * 2...)
        srl h
        rr l
        endif
        call NRDVRM
        or a
        ret z
        ld a,1
        ret
        TEST_END "../out/boxes.bin"
