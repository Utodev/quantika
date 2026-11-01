; pixel.asm: the pixel primitives for machine code: the sub-ROM's SCALXY ... NVBXFL, and through the main
; ROM's entries (bios/pixel.asm) its RIGHTC ... SCANL. The current pixel is CLOC / CMASK, as the original
; keeps it (black box):
;   SCREEN 2 and 4 (bits): CLOC = the pattern byte's offset ((y / 8) * 256 + (x AND F8h) + (y AND 7)),
;     CMASK = its bit (80h for the leftmost)
;   SCREEN 3 (blocks): x, y are blocks (0-63, 0-47; SCALXY gives them): CLOC = cell * 8 + (y AND 7) with
;     cell = ((y / 8) * 32 + x / 2) AND FFh, CMASK = F0h for an even x, 0Fh for an odd one
;   SCREEN 5-8 (bitmap): CLOC = x, CMASK = y; the moves (RIGHTC, LEFTC, UPC, DOWNC and their tests) then do
;     what they do in SCREEN 3, as the original's do; SCANR / SCANL move along x.
; The original sub-ROM uses the blocks' way in SCREEN 2 too; these use the bits' way there.

; PixelKind: A = 0 bits, 1 blocks, 2 bitmap, Z for bits. Keeps the other registers.
PixelKind:
        ld a,(SCRMOD)
        cp $05
        jr nc,.bitmap
        cp $03
        jr z,.blocks
        xor a
        ret
.blocks:
        ld a,$01
        or a
        ret
.bitmap:
        ld a,$02
        or a
        ret

; MapXY: MAPXY. BC = x, DE = y: CLOC / CMASK. Keeps BC, DE, HL.
MapXY:
        push hl
        call PixelKind
        jr z,.bits
        dec a
        jr z,.blocks
        ld (CLOC),bc                    ; bitmap
        ld a,e
        ld (CMASK),a
        pop hl
        ret
.bits:
        ld a,e
        and $07
        ld l,a
        ld a,c
        and $F8
        or l
        ld l,a
        ld a,e
        rrca
        rrca
        rrca
        and $1F
        ld h,a
        ld (CLOC),hl
        ld a,c
        and $07
        ld l,a
        ld a,$80
        inc l
.shift:
        dec l
        jr z,.mask
        rrca
        jr .shift
.blocks:
        ld a,e                          ; ((y / 8) * 32 + x / 2) AND FFh: the cell
        and $F8
        add a,a
        add a,a
        ld l,a
        ld a,c
        srl a
        add a,l
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,e
        and $07
        or l
        ld l,a
        ld (CLOC),hl
        ld a,c
        and $01
        ld a,$F0
        jr z,.mask
        ld a,$0F
.mask:
        ld (CMASK),a
        pop hl
        ret

; RightC / LeftC / UpC / DownC: RIGHTC / LEFTC / UPC / DOWNC: the next pixel that way (no test of the edge).
; Destroy AF.
RightC:
        call PixelKind
        jr nz,.nibble
        ld a,(CMASK)
        rrca
        ld (CMASK),a
        ret nc
        jr NextCell
.nibble:
        ld a,(CMASK)
        cp $F0
        ld a,$0F
        jr z,StoreMask
        ld a,$F0
        ld (CMASK),a
NextCell:
        push hl
        push de
        ld hl,(CLOC)
        ld de,8
        add hl,de
        ld (CLOC),hl
        pop de
        pop hl
        ret
StoreMask:
        ld (CMASK),a
        ret

LeftC:
        call PixelKind
        jr nz,.nibble
        ld a,(CMASK)
        rlca
        ld (CMASK),a
        ret nc
        jr PreviousCell
.nibble:
        ld a,(CMASK)
        cp $0F
        ld a,$F0
        jr z,StoreMask
        ld a,$0F
        ld (CMASK),a
PreviousCell:
        push hl
        push de
        ld hl,(CLOC)
        ld de,-8
        add hl,de
        ld (CLOC),hl
        pop de
        pop hl
        ret

DownC:
        push hl
        push de
        ld hl,(CLOC)
        ld a,l
        and $07
        cp $07
        ld de,1
        jr nz,.move
        ld de,$0100 - 7                 ; the first row of the next row of cells
.move:
        add hl,de
        ld (CLOC),hl
        pop de
        pop hl
        ret

UpC:
        push hl
        push de
        ld hl,(CLOC)
        ld a,l
        and $07
        ld de,-1
        jr nz,.move
        ld de,-($0100 - 7)              ; the last row of the row of cells above
.move:
        add hl,de
        ld (CLOC),hl
        pop de
        pop hl
        ret

; TUpC / TDownC / TRight / TLeftC: TUPC / TDOWNC / TRIGHT / TLEFTC: carry (and no move) at the edge of the
; screen, else the move and no carry. SCREEN 5-8: TUPC and TDOWNC move y (CMASK) between 0 and 211, as the
; original's. Destroy AF.
TUpC:
        call PixelKind
        cp $02
        jr nz,.cells
        ld a,(CMASK)
        or a
        scf
        ret z
        dec a
        ld (CMASK),a
        or a
        ret
.cells:
        ld a,(CLOC + 1)                 ; the top row of cells, the first row of it
        or a
        jr nz,.move
        ld a,(CLOC)
        and $07
        jr nz,.move
        scf
        ret
.move:
        call UpC
        or a
        ret

TDownC:
        call PixelKind
        cp $02
        jr nz,.cells
        ld a,(CMASK)
        cp 211
        scf
        ret z
        inc a
        ld (CMASK),a
        or a
        ret
.cells:
        ld a,(CLOC)
        and $07
        cp $07
        jr nz,.move
        call PixelKind                  ; the last row of cells: 1700h (bits), 0500h (blocks)
        ld a,(CLOC + 1)
        jr nz,.blocks
        cp $17
        jr .compare
.blocks:
        cp $05
.compare:
        jr c,.move
        scf
        ret
.move:
        call DownC
        or a
        ret

TRight:
        ld a,(CLOC)
        and $F8
        cp $F8
        jr nz,.move                     ; not the last column of cells
        call PixelKind
        ld a,(CMASK)
        jr nz,.nibble
        cp $01
        jr .test
.nibble:
        cp $F0
        jr z,.move
        xor a                           ; (Z: the right half)
.test:
        jr nz,.move
        scf
        ret
.move:
        call RightC
        or a
        ret

TLeftC:
        ld a,(CLOC)
        and $F8
        jr nz,.move                     ; not the first column of cells
        call PixelKind
        ld a,(CMASK)
        jr nz,.nibble
        cp $80
        jr .test
.nibble:
        cp $0F
        jr z,.move
        xor a
.test:
        jr nz,.move
        scf
        ret
.move:
        call LeftC
        or a
        ret

; ScalXY: SCALXY. BC = x, DE = y (signed): both into the screen (0 - 255 or 511, 0 - 191 or 211); SCREEN 3:
; then into blocks (/ 4). Carry when they were in it already, no carry when one was moved. Destroys AF.
ScalXY:
        push hl
        ld l,$01                        ; L = 1: nothing moved
        ld a,b
        rlca
        jr nc,.xPositive
        ld bc,$0000
        ld l,$00
.xPositive:
        push hl
        call ScreenWidth                ; HL = the last x
        or a
        sbc hl,bc
        jr nc,.xIn
        add hl,bc
        ld b,h
        ld c,l
        pop hl
        ld l,$00
        jr .y
.xIn:
        pop hl
.y:
        ld a,d
        rlca
        jr nc,.yPositive
        ld de,$0000
        ld l,$00
.yPositive:
        push hl
        ld a,(SCRMOD)
        cp $05
        ld hl,191
        jr c,.height
        ld hl,211
.height:
        or a
        sbc hl,de
        jr nc,.yIn
        add hl,de
        ex de,hl
        pop hl
        ld l,$00
        jr .blocks
.yIn:
        pop hl
.blocks:
        ld a,(SCRMOD)
        cp $03
        jr nz,.done
        srl b                           ; SCREEN 3: blocks of 4 x 4
        rr c
        srl b
        rr c
        srl d
        rr e
        srl d
        rr e
.done:
        ld a,l
        rrca                            ; carry: nothing moved
        pop hl
        ret

; ScreenWidth: HL = the last x of the mode (511 in SCREEN 6 and 7, else 255). Destroys A.
ScreenWidth:
        ld a,(SCRMOD)
        ld hl,255
        cp $06
        ret c
        cp $08
        ret nc
        ld hl,511
        ret

; SetAtr: SETATR. A = colour: ATRBYT (carry and nothing when it cannot be one: 16 or more, but in SCREEN 8;
; SCREEN 6 keeps (A AND 3) * 5, as BASIC's COLOR does, and takes any).
SetAtr:
        push af
        ld a,(SCRMOD)
        cp $06
        jr z,.twoBits
        cp $08
        jr z,.take
        pop af
        cp $10
        ccf
        ret c
        push af
.take:
        pop af
        ld (ATRBYT),a
        or a
        ret
.twoBits:
        pop af
        push bc
        and $03
        ld b,a
        add a,a
        add a,a
        add a,b
        ld (ATRBYT),a
        pop bc
        or a
        ret

; ReadC: READC. A = the colour of the current pixel. Destroys F.
ReadC:
        push hl
        push de
        push bc
        call PixelKind
        jr z,.bits
        dec a
        jr z,.blocks
        ld bc,(CLOC)                    ; bitmap: the VDP's POINT
        ld a,(CMASK)
        ld e,a
        ld d,$00
        call VdpPoint
        jr .done
.bits:
        ld hl,(CLOC)
        push hl
        ld de,(GRPCGP)
        add hl,de
        call ReadVram
        ld b,a                          ; B = the pattern byte
        pop hl
        ld de,(GRPCOL)
        add hl,de
        call ReadVram
        ld c,a                          ; C = its colours
        ld a,(CMASK)
        and b
        ld a,c
        jr z,.low                       ; a 0 bit: the background
        jr .high
.blocks:
        ld hl,(CLOC)
        ld de,(MLTCGP)
        add hl,de
        call ReadVram
        ld c,a
        ld a,(CMASK)
        cp $F0
        ld a,c
        jr nz,.low
.high:
        rrca
        rrca
        rrca
        rrca
.low:
        and $0F
.done:
        pop bc
        pop de
        pop hl
        ret

; SetC: SETC. The current pixel to ATRBYT (SCREEN 5-8: with the logical operation of LOGOPR). Destroys AF.
SetC:
        push hl
        push de
        push bc
        call PixelKind
        jr z,.bits
        dec a
        jr z,.blocks
        ld bc,(CLOC)                    ; bitmap: the VDP's PSET
        ld a,(CMASK)
        ld e,a
        ld d,$00
        call VdpPset
        jr .done
.bits:
        ld hl,(CLOC)                    ; the bit set, the foreground of the byte to the colour
        push hl
        ld de,(GRPCGP)
        add hl,de
        call ReadVram
        ld b,a
        ld a,(CMASK)
        or b
        call WriteVram
        pop hl
        ld de,(GRPCOL)
        add hl,de
        call ReadVram
        and $0F
        ld b,a
        ld a,(ATRBYT)
        rlca
        rlca
        rlca
        rlca
        and $F0
        or b
        call WriteVram
        jr .done
.blocks:
        ld hl,(CLOC)
        ld de,(MLTCGP)
        add hl,de
        call ReadVram
        ld b,a
        ld a,(CMASK)
        cp $F0
        jr nz,.right
        ld a,(ATRBYT)                   ; the left block: the high half
        and $0F
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,b
        and $0F
        jr .write
.right:
        ld a,(ATRBYT)
        and $0F
        ld c,a
        ld a,b
        and $F0
.write:
        or c
        call WriteVram
.done:
        pop bc
        pop de
        pop hl
        ret

; NSetCx: NSETCX (main ROM). HL pixels from the current one to the right in ATRBYT (SETC and RIGHTC each
; time). SCREEN 2 and 4: CLOC / CMASK stay as they were (HL = where the moves ended); the others: they move.
NSetCx:
        ld a,h
        or l
        ret z
        call PixelKind
        push af
        ld de,(CLOC)
        push de
        ld a,(CMASK)
        push af
        call PixelKind
        jr nz,.dot
        call PaintRun                   ; SCREEN 2 and 4: by whole bytes where it can
        jr .moved
.dot:
        call SetC
        call RightC
        dec hl
        ld a,h
        or l
        jr nz,.dot
.moved:
        ld hl,(CLOC)
        pop bc                          ; B = CMASK before
        pop de                          ; CLOC before
        pop af
        ret nz                          ; SCREEN 3, 5-8: as it moved
        ld (CLOC),de
        ld a,b
        ld (CMASK),a
        ret

; PntIni: PNTINI (main ROM). A = the border colour of PAINT: BRDATR (SCREEN 2 and 4: the paint colour,
; ATRBYT, as these modes cannot tell them apart). Carry when it cannot be a colour.
PntIni:
        push af
        call PixelKind
        jr nz,.colour
        pop af
        ld a,(ATRBYT)
        ld (BRDATR),a
        or a
        ret
.colour:
        ld a,(SCRMOD)
        cp $08
        jr z,.take
        pop af
        cp $10
        ccf
        ret c
        push af
.take:
        pop af
        ld (BRDATR),a
        or a
        ret

; ScanR: SCANR. B = fill switch, DE = the skip count. From the current pixel: border pixels (BRDATR) are
; skipped (DE less one each), the position of the first other one is kept (CSAVEA / CSAVEM), then the
; pixels up to the next border one (or to the edge) are counted (HL) and then, with the switch on, painted
; in ATRBYT; the current pixel ends on that border one (or the last pixel). SCREEN 5-8 (as the original):
; they are always painted, and nothing is done when the skip count is 0 on a border pixel (or from the
; start), and the current pixel stays where it was. The carry is not given.
ScanR:
        call PixelKind
        cp $02
        jr nz,.start
        ld b,$01                        ; SCREEN 5-8: always painted
        ld a,d
        or e
        jr nz,.start
        ld hl,$0000
        ret
.start:
        ld hl,(CLOC)
        push hl                         ; (where it started, in case nothing is found)
        ld hl,$0000
.skip:
        call IsBorder
        jr nz,.found
        call PixelKind
        cp $02
        jr nz,.skipOne
        ld a,d
        or e
        jr nz,.skipOne
        pop hl                          ; SCREEN 5-8: no skip left: back where it started
        ld (CLOC),hl
        ld hl,$0000
        ret
.skipOne:
        dec de
        call ScanRightEdge
        jr c,.edge
        call ScanRight
        jr .skip
.edge:
        pop hl
        ld hl,$0000
        ret
.found:
        pop af                          ; (the start: not needed)
.first:
        push hl
        ld hl,(CLOC)
        ld (CSAVEA),hl
        ld a,(CMASK)
        ld (CSAVEM),a
        pop hl
.count:
        inc hl
        call ScanRightEdge
        jr c,.counted
        call ScanRight
        call IsBorder
        jr nz,.count
.counted:
        call PixelKind
        jr nz,.kept
        ld (ScanCount),hl               ; (SCREEN 2 and 4: SCANL paints this many more)
.kept:
        ld a,b
        or a
        ret z
        push hl                         ; painted from the first one
        push de
        ld de,(CLOC)
        push de
        ld a,(CMASK)
        push af
        ld de,(CSAVEA)
        ld (CLOC),de
        ld a,(CSAVEM)
        ld (CMASK),a
        call PaintRun
        pop af
        ld (CMASK),a
        pop de
        ld (CLOC),de
        pop de
        pop hl
        ret

; ScanL: SCANL. From the pixel left of the current one, the pixels up to a border one (or to the edge) are
; counted (HL) and painted in ATRBYT; the current pixel ends on the leftmost of them. SCREEN 2 and 4 (as the
; original, for PAINT: SCANR found the right part of the line, SCANL fills it all): the run painted is HL
; plus the count of the last SCANR. SCREEN 5-8: DE = its x (as the original). The carry is not given.
ScanCount       equ $F867               ; (SCANR's count: where the original keeps it, inside FILNAM)
ScanL:
        ld hl,$0000
.pixel:
        call ScanLeftEdge
        jr c,.end
        call ScanLeft
        call IsBorder
        jr z,.back
        inc hl
        jr .pixel
.back:
        call ScanRight
.end:
        push hl
        call PixelKind
        jr nz,.own
        ld de,(ScanCount)
        add hl,de
.own:
        ld de,(CLOC)
        push de
        ld a,(CMASK)
        push af
        call PaintRun
        pop af
        ld (CMASK),a
        pop de
        ld (CLOC),de
        pop hl
        ret

; PaintRun: HL pixels from the current one to the right in ATRBYT (the current pixel moves). SCREEN 2 and 4
; (as the original): a byte the run covers whole gets the pattern 0 and the colour as its background, the
; others their bits and the colour as their foreground. Destroys AF, HL.
PaintRun:
        ld a,h
        or l
        ret z
        call PixelKind
        jr nz,.one
        ld a,(CMASK)
        cp $80
        jr nz,.one                      ; (not at the start of a byte)
        ld a,h
        or a
        jr nz,.byte
        ld a,l
        cp $08
        jr c,.one
.byte:
        push hl
        push de
        ld hl,(CLOC)
        push hl
        ld de,(GRPCGP)
        add hl,de
        xor a
        call WriteVram
        pop hl
        ld de,(GRPCOL)
        add hl,de
        ld a,(ATRBYT)
        and $0F
        call WriteVram
        pop de
        pop hl
        call NextCell
        ld a,l
        sub $08
        ld l,a
        jr nc,PaintRun
        dec h
        jr PaintRun
.one:
        call SetC
        call ScanRight
        dec hl
        jr PaintRun

; IsBorder: Z when the current pixel has the border colour (BRDATR; in SCREEN 6 its two low bits). Keeps BC,
; DE, HL.
IsBorder:
        call ReadC
        push bc
        ld c,a
        ld a,(SCRMOD)
        cp $06
        ld a,(BRDATR)
        jr nz,.compare
        and $03
.compare:
        cp c
        pop bc
        ret

; ScanRight / ScanLeft: the next pixel that way for the scans (x + 1 / x - 1 in SCREEN 5-8). Keep BC, DE,
; HL. ScanRightEdge / ScanLeftEdge: carry when the current pixel is the last / first of its row.
ScanRight:
        call PixelKind
        cp $02
        jp nz,RightC
        push hl
        ld hl,(CLOC)
        inc hl
        ld (CLOC),hl
        pop hl
        ret
ScanLeft:
        call PixelKind
        cp $02
        jp nz,LeftC
        push hl
        ld hl,(CLOC)
        dec hl
        ld (CLOC),hl
        pop hl
        ret
ScanRightEdge:
        push hl
        push de
        call PixelKind
        cp $02
        jr nz,.cells
        call ScreenWidth
        ld de,(CLOC)
        or a
        sbc hl,de                       ; 0: the last x
        jr .test
.cells:
        ld a,(CLOC)
        and $F8
        cp $F8
        jr nz,.no
        call PixelKind
        ld a,(CMASK)
        ld h,$01
        jr z,.bits
        ld h,$0F
.bits:
        cp h
.test:
        jr nz,.no
        pop de
        pop hl
        scf
        ret
.no:
        pop de
        pop hl
        or a
        ret
ScanLeftEdge:
        push hl
        call PixelKind
        cp $02
        jr nz,.cells
        ld hl,(CLOC)
        ld a,h
        or l
        jr .test
.cells:
        ld a,(CLOC)
        and $F8
        jr nz,.no
        call PixelKind
        ld a,(CMASK)
        ld h,$80
        jr z,.bits
        ld h,$F0
.bits:
        cp h
.test:
        jr nz,.no
        pop hl
        scf
        ret
.no:
        pop hl
        or a
        ret

; DoGrph: DOGRPH. A line from BC, DE to (GXPOS, GYPOS) in ATRBYT with LOGOPR. GRPACX / GRPACY stay.
DoGrph:
        call SwapEnd
        call DrawLine
        jp SwapEnd

; NvBxLn / NvBxFl: NVBXLN / NVBXFL. The box BC, DE - (GXPOS, GYPOS), its sides / filled, in ATRBYT with
; LOGOPR. NVBXLN leaves GXPOS = x0 and GYPOS = y0 + 1 (as the original).
NvBxLn:
        push bc
        push de
        call SwapEnd
        call Box
        call SwapEnd
        pop de
        pop bc
        ld (GXPOS),bc
        inc de
        ld (GYPOS),de
        ret
NvBxFl:
        call SwapEnd
        call FilledBox
        jp SwapEnd

; SwapEnd: GRPACX / GRPACY and GXPOS / GYPOS change places (the line and box routines end at GRPACX /
; GRPACY). Keeps BC, DE.
SwapEnd:
        push hl
        push de
        ld hl,(GRPACX)
        ld de,(GXPOS)
        ld (GXPOS),hl
        ld (GRPACX),de
        ld hl,(GRPACY)
        ld de,(GYPOS)
        ld (GYPOS),hl
        ld (GRPACY),de
        pop de
        pop hl
        ret
