; pixel.asm: the pixel primitives for machine code in SCREEN MODE (-DMODE=n), from the main ROM's jump table or
; (-DSUB) the sub-ROM's (through EXTROM). Only what each one gives is kept (see the Save routines): CLOC /
; CMASK after the moves, the carry of the tests, SCALXY's coordinates, READC's colour, SCANR / SCANL's counts
; and the pixels they paint (not their carry, which the original gives in some modes and not in others). In SCREEN 3 the coordinates are blocks (/ 4).
        include "common.inc"
EXTROM  equ $015F
CLOC    equ $F92A
CMASK   equ $F92C
ATRBYT  equ $F3F2
FORCLR  equ $F3E9
BRDATR  equ $FCB2
Pointer equ $CF00                       ; where the next result goes
        if MODE == 3
S       equ 4
        else
S       equ 1
        endif

        ifdef SUB
RIGHTC  equ $00A5
LEFTC   equ $00AD
UPC     equ $00BD
TUPC    equ $00B9
DOWNC   equ $00B5
TDOWNC  equ $00B1
SCALXY  equ $008D
MAPXY   equ $0091
SETATR  equ $0099
READC   equ $0095
SETC    equ $009D
SCANR   equ $00C1
SCANL   equ $00C5
TRIGHT  equ $00A1
TLEFTC  equ $00A9
        else
RIGHTC  equ $00FC
LEFTC   equ $00FF
UPC     equ $0102
TUPC    equ $0105
DOWNC   equ $0108
TDOWNC  equ $010B
SCALXY  equ $010E
MAPXY   equ $0111
FETCHC  equ $0114
STOREC  equ $0117
SETATR  equ $011A
READC   equ $011D
SETC    equ $0120
NSETCX  equ $0123
GTASPC  equ $0126
PNTINI  equ $0129
SCANR   equ $012C
SCANL   equ $012F
        endif

        macro CALLB address
        ifdef SUB
        ld ix,address
        call EXTROM
        else
        call address
        endif
        endm

        macro AT x, y                   ; MAPXY (x, y) (blocks in SCREEN 3)
        ld bc,x / S
        ld de,y / S
        CALLB MAPXY
        endm

        TEST_START
        call ERAFNK
        ld hl,$0109                     ; FORCLR 9, BAKCLR 1
        ld (FORCLR),hl
        ld a,MODE
        call CHGMOD
        xor a
        call CLS
        ld hl,Results
        ld (Pointer),hl
        ; the moves: right (to the next byte), down (to the next row of cells), up, left
        AT 39, 7
        call SaveVars
        CALLB RIGHTC
        call SaveVars
        CALLB DOWNC
        call SaveVars
        CALLB UPC
        call SaveVars
        CALLB LEFTC
        call SaveVars
        ; the tests: TUPC at the top, TDOWNC at the bottom, and inside
        AT 0, 0
        CALLB TUPC
        call SaveCarry
        call SaveVars
        AT 0, 191
        CALLB TDOWNC
        call SaveCarry
        call SaveVars
        AT 20, 100
        CALLB TUPC
        call SaveCarry
        CALLB TDOWNC
        call SaveCarry
        call SaveVars
        ; SCALXY: out of the screen (both), x negative, inside
        ld bc,300
        ld de,250
        CALLB SCALXY
        call SaveCarry
        call SaveBcDe
        ld bc,$FFFB
        ld de,10
        CALLB SCALXY
        call SaveCarry
        call SaveBcDe
        ld bc,100
        ld de,100
        CALLB SCALXY
        call SaveCarry
        call SaveBcDe
        ; SETATR 7 and 16 (not a colour but in SCREEN 8)
        ld a,7
        CALLB SETATR
        call SaveCarry
        ld a,(ATRBYT)
        call SaveA
        ld a,16
        CALLB SETATR
        call SaveCarry
        ld a,(ATRBYT)
        call SaveA
        ; SETC at (50, 60) in 9, READC there and beside it
        AT 50, 60
        ld a,9
        CALLB SETATR
        CALLB SETC
        CALLB READC
        call SaveA
        AT 54, 60
        CALLB READC
        call SaveA
        ifdef SUB
        ; TRIGHT at the right edge, TLEFTC at the left one
        AT 255, 12
        CALLB TRIGHT
        call SaveCarry
        call SaveVars
        AT 0, 12
        CALLB TLEFTC
        call SaveCarry
        call SaveVars
        else
        ; NSETCX 30 dots from (10, 64) in 9: READC at 39, 40 and 9, and where it left CLOC
        AT 12, 64
        ld hl,30 / S
        CALLB NSETCX
        call SaveVars
        AT 40, 64
        CALLB READC
        call SaveA
        AT 44, 64
        CALLB READC
        call SaveA
        AT 8, 64
        CALLB READC
        call SaveA
        ; GTASPC, STOREC / FETCHC
        CALLB GTASPC
        ld b,h
        ld c,l
        call SaveBcDe                   ; (HL, DE)
        ld hl,$1234
        ld a,$40
        CALLB STOREC
        ld hl,0
        xor a
        CALLB FETCHC
        call SaveA
        ld b,h
        ld c,l
        call SaveBcDe
        endif
        ; PAINT's helpers: border dots (5) at 20 and 44 on row 80
        ld a,5
        CALLB SETATR
        AT 20, 80
        CALLB SETC
        AT 44, 80
        CALLB SETC
        ifndef SUB
        ld a,5
        CALLB PNTINI
        call SaveCarry
        else
        ld a,5
        ld (BRDATR),a
        endif
        ld a,(BRDATR)
        call SaveA
        ld a,9
        CALLB SETATR
        ; SCANR from 28 (no fill, skip 3), from 20 (a border: skipped; fill), SCANL from 36
        AT 28, 80
        ld b,0
        ld de,3
        CALLB SCANR
        call SaveScan
        AT 20, 80
        ld b,1
        ld de,3
        CALLB SCANR
        call SaveScan
        AT 36, 80
        CALLB SCANL
        ld de,0                         ; (what SCANL leaves in DE is not given)
        call SaveScan
        ; the colours of the row from 16 to 48 (every 4th: blocks in SCREEN 3)
        ld b,0
.row:
        push bc
        ld a,b
        add a,16 / S
        ld c,a
        ld b,0
        ld de,80 / S
        CALLB MAPXY
        CALLB READC
        call SaveA
        pop bc
        inc b
        ld a,b
        cp 32 / S + 1
        jr nz,.row
        jp TestEnd

; SaveCarry: 1 (carry) or 0. SaveA: A. SaveBcDe: BC, DE. SaveVars: CLOC, CMASK. SaveScan: HL, DE, CLOC,
; CMASK, CSAVEA, CSAVEM. They keep all.
SaveCarry:
        push af
        ld a,$00
        rla
        call SaveA
        pop af
        ret
SaveA:
        push hl
        ld hl,(Pointer)
        ld (hl),a
        inc hl
        ld (Pointer),hl
        pop hl
        ret
SaveBcDe:
        push af
        ld a,c
        call SaveA
        ld a,b
        call SaveA
        ld a,e
        call SaveA
        ld a,d
        call SaveA
        pop af
        ret
SaveVars:
        push af
        ld a,(CLOC)
        call SaveA
        ld a,(CLOC + 1)
        call SaveA
        ld a,(CMASK)
        call SaveA
        pop af
        ret
SaveScan:
        push af
        ld a,l
        call SaveA
        ld a,h
        call SaveA
        ld a,e
        call SaveA
        ld a,d
        call SaveA
        call SaveVars
        ld a,($F942)
        call SaveA
        ld a,($F943)
        call SaveA
        ld a,($F944)
        call SaveA
        pop af
        ret
        TEST_END "../out/pixel.bin"
