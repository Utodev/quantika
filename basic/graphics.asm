; graphics.asm: the graphic statements of FBASIC: PSET, PRESET, LINE, CIRCLE, PAINT, POINT, PUT SPRITE,
; SPRITE$, COLOR = (palette). One pixel routine knows the layout of every mode:
;   SCREEN 2  pattern bit (7 - x mod 8) of byte (y AND F8h) * 32 + (x AND F8h) + (y AND 7), the colour of
;             that byte's 8 pixels in the colour table's high nibble
;   SCREEN 3  4 x 4 blocks: byte (by AND F8h) * 32 + (bx AND FEh) * 4 + (by AND 7), the nibble by bx
;   SCREEN 5  4 bits a pixel, 128 bytes a line;  6: 2 bits, 128 bytes;  7: 4 bits, 256;  8: 8 bits, 256
; LINE and filled boxes in SCREEN 5-8 use the V9938's own commands. Coordinates are clipped to the
; screen; the last point drawn is GRPACX / GRPACY (for STEP and LINE -(x, y)).

; GraphicCoordinates: "(x, y)" or "STEP (x, y)" (relative to the last point). Out: BC = x, DE = y
; (signed), HL past the bracket.
GraphicCoordinates:
        call ThisChar
        ld a,$00
        cp TkStep
        jr nz,.absolute
        rst $10
        ld a,$01
.absolute:
        push af
        call ThisChar
        rst $08
        db '('
        call EvalInteger
        push de
        call Comma
        call EvalInteger
        call CloseBracket
        pop bc
        pop af
        or a
        ret z
        push hl                         ; STEP: from the last point
        ld hl,(GRPACX)
        add hl,bc
        ld b,h
        ld c,l
        ld hl,(GRPACY)
        add hl,de
        ex de,hl
        pop hl
        ret

; GraphicColour: an optional ", colour" (the foreground by default). Out: ATRBYT. Keeps BC, DE.
GraphicColour:
        push bc
        push de
        ld a,(FORCLR)
        ld (ATRBYT),a
        call ThisChar
        cp ','
        jr nz,.done
        rst $10
        cp ','
        jr z,.back                      ; ",," : the default, a comma is still there
        call AtStatementEnd
        jr z,.done
        call EvalByte
        ld (ATRBYT),a
        jr .done
.back:
        dec hl                          ; (leave the second comma for the next argument)
.done:
        pop de
        pop bc
        ret

; IsGraphicMode: Illegal function call in the text modes.
IsGraphicMode:
        ld a,(SCRMOD)
        cp $02
        ret nc
        jp IllegalFunction

; --- PSET / PRESET / POINT ---

StatementPset:
        call IsGraphicMode
        call GraphicCoordinates
        call GraphicColour
        call GraphicOperation
        jr PlotAndRemember
StatementPreset:
        call IsGraphicMode
        call GraphicCoordinates
        push bc
        push de
        call GraphicColour
        call GraphicOperation
        pop de
        pop bc
        call ThisChar                   ; no colour given: the background
        ld a,(BAKCLR)
        ld (ATRBYT),a
PlotAndRemember:
        ld (GRPACX),bc
        ld (GRPACY),de
        push hl
        call PlotPixel
        pop hl
        ret

; OperandPoint: POINT(x, y): the colour of a pixel (-1 outside the screen).
OperandPoint:
        call ThisChar
        rst $08
        db '('
        call EvalInteger
        push de
        call Comma
        call EvalInteger
        call CloseBracket
        pop bc
        push hl
        call PixelColour                  ; A = colour, carry outside
        pop hl
        ld e,a
        ld d,$00
        jp nc,SetIntegerResult
        ld de,$FFFF
        jp SetIntegerResult

; ScreenSize: HL = the width, DE = the height of the current graphic mode.
ScreenSize:
        ld a,(SCRMOD)
        ld hl,256
        ld de,212
        cp $05
        jr c,.tms
        cp $06
        ret c
        cp $08
        ret z
        ld hl,512                       ; SCREEN 6, 7
        ret
.tms:
        ld de,192
        ret

; Clip: carry when BC, DE is outside the screen.
Clip:
        push hl
        push de
        bit 7,b
        jr nz,.out
        bit 7,d
        jr nz,.out
        push de
        call ScreenSize
        pop de
        push hl
        ex de,hl                        ; HL = y, DE = height
        rst $20                         ; y - height
        pop hl
        jr nc,.out
        ld d,b
        ld e,c
        rst $20                         ; width - x... (HL = width, DE = x): carry when x > width
        jr c,.out
        jr z,.out
        pop de
        pop hl
        or a
        ret
.out:
        pop de
        pop hl
        scf
        ret

; ClampPoint: BC, DE (signed) kept on the screen: a coordinate beyond an edge goes to that edge.
ClampPoint:
        push hl
        push de
        call ScreenSize                 ; HL = width, DE = height
        dec hl
        dec de
        ex (sp),hl                      ; HL = y, width - 1 on the stack
        call .clamp
        ex (sp),hl                      ; HL = width - 1, y on the stack
        ex de,hl
        ld h,b
        ld l,c
        call .clamp
        ld b,h
        ld c,l
        pop de
        pop hl
        ret
.clamp:                                 ; HL between 0 and DE
        bit 7,h
        jr z,.notNegative
        ld hl,$0000
        ret
.notNegative:
        rst $20
        ret c
        ex de,hl
        ret

; PixelAddress: the VRAM address of pixel BC, DE (inside the screen) and its place.
; Out: HL = address, A = mask of the pixel's bits in that byte, C = how far left they are (shift).
; For SCREEN 2 / 3 the colour table / block nibble handling is in PlotPixel.
PixelAddress:
        ld a,(SCRMOD)
        cp $05
        jr nc,.bitmap
        cp $03
        jr z,.multicolour
        ; SCREEN 2 (and 4): (y AND F8h) * 32 + (x AND F8h) + (y AND 7)
        ld a,e
        and $F8
        ld h,a                          ; * 256 / 8 * 8 ... (y AND F8h) * 32 = (y >> 3) << 8
        srl h
        srl h
        srl h
        ld a,c
        and $F8
        ld l,a
        ld a,e
        and $07
        or l
        ld l,a
        ld a,c                          ; the bit
        and $07
        ld c,a
        ld a,$80
        jr z,.maskDone
        ld b,c
.maskShift:
        rrca
        djnz .maskShift
.maskDone:
        ret
.multicolour:
        ; blocks: bx = x / 4, by = y / 4; (by AND F8h) * 32 + (bx AND FEh) * 4 + (by AND 7)
        srl e
        srl e                           ; E = by
        srl b
        rr c
        srl c                           ; C = bx
        ld a,e
        and $F8
        rrca
        rrca
        rrca
        ld h,a                          ; (by >> 3) << 8
        ld a,c
        and $FE
        add a,a
        add a,a
        ld l,a
        ld a,e
        and $07
        or l
        ld l,a
        bit 0,c
        ld a,$F0
        ld c,$04
        ret z
        ld a,$0F
        ld c,$00
        ret
.bitmap:
        ld h,e                          ; y * 256 (SCREEN 7, 8) or y * 128 (5, 6)
        ld l,$00
        cp $07
        jr nc,.wideLines
        srl h
        rr l
.wideLines:
        cp $08
        jr z,.eightBits
        cp $06
        jr z,.twoBits
        ; 4 bits: x / 2, the even pixel on the left (high nibble)
        ld a,c
        and $01
        push af                         ; NZ: an odd x
        srl b
        rr c
        add hl,bc
        pop af
        ld a,$F0
        ld c,$04
        ret z
        ld a,$0F
        ld c,$00
        ret
.twoBits:
        ld a,c
        and $03
        push af
        srl b
        rr c
        srl b
        rr c
        add hl,bc
        pop af
        ld b,a                          ; pixel 0 on the left: bits 7-6
        ld a,3
        sub b
        add a,a
        ld c,a                          ; shift
        ld a,$03
        ld b,c
        inc b
.twoShift:
        dec b
        ret z
        rlca
        jr .twoShift
.eightBits:
        add hl,bc
        ld a,$FF
        ld c,$00
        ret

; PlotPixel: pixel BC, DE (clipped) to the colour ATRBYT.
PlotPixel:
        call Clip
        ret c
        ld a,(SCRMOD)
        cp $05
        jr nc,.bitmap
        cp $03
        jr z,.multicolour
        call PixelAddress               ; SCREEN 2: the pattern bit and the colour of the byte
        push hl
        push af
        ld de,(GRPCGP)
        add hl,de
        call ReadVram
        pop bc
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
        jp WriteVram
.multicolour:
        call PixelAddress
        ld de,(MLTCGP)
        add hl,de
        ld d,a
        ld a,(ATRBYT)
        jr .nibble
.bitmap:
        jp VdpPset
.nibble:
        ; A = colour, D = mask, C = shift: (byte AND NOT mask) OR (colour << shift AND mask)
        inc c
.shift:
        dec c
        jr z,.shifted
        add a,a
        jr .shift
.shifted:
        and d
        ld e,a                          ; E = the new bits
        ld a,d
        push af                         ; the mask
        call ReadVramBig
        pop bc
        push af
        ld a,b
        cpl
        ld b,a
        pop af
        and b
        or e
        jp WriteVramBig

; VdpPset: pixel BC, DE of the active page to ATRBYT with the logical operation LOGOPR (0 PSET, 1 AND,
; 2 OR, 3 XOR, 4 PRESET = NOT, + 8 the T ones: colour 0 draws nothing): the VDP's PSET command.
VdpPset:
        call VdpWaitCommand
        di
        ld a,36                         ; R#36-R#39: DX, DY
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld a,c
        out (VdpIndirect),a
        ld a,b
        out (VdpIndirect),a
        ld a,e
        out (VdpIndirect),a
        ld a,(ACPAGE)
        add a,d
        out (VdpIndirect),a
        ld a,44                         ; R#44-R#46: CLR, ARG, CMD
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld a,(ATRBYT)
        out (VdpIndirect),a
        xor a
        out (VdpIndirect),a
        ld a,(LOGOPR)
        and $0F
        or $50
        out (VdpIndirect),a
        ei
        ret

; VdpPoint: A = the colour of pixel BC, DE of the active page: the VDP's POINT command. No carry.
VdpPoint:
        call VdpWaitCommand
        di
        ld a,32                         ; R#32-R#35: SX, SY
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld a,c
        out (VdpIndirect),a
        ld a,b
        out (VdpIndirect),a
        ld a,e
        out (VdpIndirect),a
        ld a,(ACPAGE)
        add a,d
        out (VdpIndirect),a
        ld a,$40                        ; R#46: POINT
        out (VdpCommand),a
        ld a,$80 + 46
        out (VdpCommand),a
        ei
        call VdpWaitCommand
        ld a,$07
        call VdpStatus                  ; S#7: the colour
        or a
        ret

; PixelBits: colour A with only the bits a pixel of this mode has (SCREEN 6: 2, 8: 8, the others 4).
; Keeps the others but F.
PixelBits:
        push bc
        ld b,a
        ld a,(SCRMOD)
        cp $08
        ld a,b
        jr z,.done
        ld a,(SCRMOD)
        cp $06
        ld a,b
        jr nz,.four
        and $03
        jr .done
.four:
        and $0F
.done:
        pop bc
        ret

; GraphicOperation: an optional ", [T]PSET / PRESET / AND / OR / XOR" (SCREEN 5-8; elsewhere a Syntax
; error, as the original): LOGOPR (PSET when none is given). Keeps BC, DE.
GraphicOperation:
        xor a
        ld (LOGOPR),a
        call ThisChar
        cp ','
        ret nz
        ld a,(SCRMOD)
        cp $05
        jp c,SyntaxError
        rst $10
        push bc
        cp TkTo                         ; TOR is crunched as TO and R
        jr nz,.notTor
        rst $10
        cp 'R'
        jp nz,SyntaxError
        ld a,$08 | $02
        jr .set
.notTor:
        ld c,$00
        cp 'T'
        jr nz,.operation
        ld c,$08
        rst $10
.operation:
        ld b,$00
        cp TkPset
        jr z,.found
        inc b
        cp TkAnd
        jr z,.found
        inc b
        cp TkOr
        jr z,.found
        inc b
        cp TkXor
        jr z,.found
        inc b
        cp TkPreset
        jp nz,SyntaxError
.found:
        ld a,b
        or c
.set:
        ld (LOGOPR),a
        pop bc
        rst $10
        ret

; PixelColour: A = the colour of pixel BC, DE; carry outside the screen.
PixelColour:
        call Clip
        ret c
        ld a,(SCRMOD)
        cp $05
        jr nc,.bitmap
        cp $03
        jr z,.multicolour
        call PixelAddress               ; SCREEN 2: foreground or background of the byte
        push hl
        push af
        ld de,(GRPCGP)
        add hl,de
        call ReadVram
        pop bc
        and b
        pop hl
        push af
        ld de,(GRPCOL)
        add hl,de
        call ReadVram
        ld b,a
        pop af
        ld a,b
        jr z,.background
        rrca
        rrca
        rrca
        rrca
.background:
        and $0F
        or a
        ret
.multicolour:
        call PixelAddress
        ld de,(MLTCGP)
        add hl,de
        jr .nibble
.bitmap:
        jp VdpPoint
.nibble:
        ld b,a
        push bc
        call ReadVramBig
        pop bc
        and b
        inc c
.shift:
        dec c
        ret z                           ; (no carry: or above... the AND cleared it)
        srl a
        jr .shift

; --- LINE ---

; StatementLine: LINE INPUT, or LINE [(x1, y1)] - (x2, y2) [, colour] [, B | BF].
StatementLineGraphic:
        call IsGraphicMode
        call ThisChar
        ld bc,(GRPACX)                  ; from the last point unless a start is given
        ld de,(GRPACY)
        cp TkMinus
        jr z,.dash
        call GraphicCoordinates
.dash:
        push bc
        push de
        call ThisChar
        rst $08
        db TkMinus
        call GraphicCoordinates
        ld (GRPACX),bc
        ld (GRPACY),de
        call GraphicColour
        ld a,$00                        ; 0 line, 1 box, 2 filled box
        push af
        call ThisChar
        cp ','
        jr nz,.operation
        rst $10
        cp ','                          ; ",,": no B, an operation after it
        jr z,.operation
        cp 'B'
        jp nz,SyntaxError
        rst $10
        pop af
        ld a,$01
        push af
        call ThisChar
        cp 'F'
        jr nz,.operation
        rst $10
        pop af
        ld a,$02
        push af
.operation:
        call GraphicOperation
        pop af
        pop de                          ; the start
        pop bc
        push hl
        or a
        jr z,.line
        dec a
        jr z,.box
        call FilledBox
        pop hl
        ret
.box:
        call Box
        pop hl
        ret
.line:
        call DrawLine
        pop hl
        ret

; DrawLine: from BC, DE to (GRPACX, GRPACY), Bresenham's way (SCREEN 5-8: the VDP's LINE command).
LineX0          equ CPCNT               ; the work of the line (the CIRCLE work area: not in use)
LineY0          equ CPCNT8
LineDX          equ CRCSUM
LineDY          equ CSTCNT
LineError       equ CXOFF
LineStepX       equ CYOFF
LineStepY       equ LOHADR

DrawLine:
        ld hl,(GRPACX)                  ; (the ends are kept on the screen, as the original BASIC does; the last
        push hl                         ; point stays as it was given)
        ld hl,(GRPACY)
        push hl
        call ClampPoint
        push bc
        push de
        ld bc,(GRPACX)
        ld de,(GRPACY)
        call ClampPoint
        ld (GRPACX),bc
        ld (GRPACY),de
        pop de
        pop bc
        ld hl,(GRPACY)                  ; drawn downwards (the end with the smaller y first), as the
        or a                            ; original: the same pixels whichever way it is given
        sbc hl,de
        jr nc,.downwards
        ld hl,(GRPACX)
        ld (GRPACX),bc
        ld b,h
        ld c,l
        ld hl,(GRPACY)
        ld (GRPACY),de
        ex de,hl
.downwards:
        call .onScreen
        pop hl
        ld (GRPACY),hl
        pop hl
        ld (GRPACX),hl
        ret
.onScreen:
        ld a,(SCRMOD)
        cp $05
        jp nc,VdpLine
        ld (LineX0),bc
        ld (LineY0),de
        ld hl,(GRPACX)                  ; DX = |x1 - x0|, step x
        or a
        sbc hl,bc
        ld bc,$0001
        bit 7,h                         ; (signed: the points may be off the screen)
        jr z,.dxPositive
        call NegateHL
        ld bc,$FFFF
.dxPositive:
        ld (LineDX),hl
        ld (LineStepX),bc
        ld hl,(GRPACY)                  ; DY = -|y1 - y0|, step y
        ld de,(LineY0)
        or a
        sbc hl,de
        ld bc,$0001
        bit 7,h
        jr z,.dyPositive
        call NegateHL
        ld bc,$FFFF
.dyPositive:
        call NegateHL
        ld (LineDY),hl
        ld (LineStepY),bc
        ld de,(LineDX)                  ; error = DX + DY
        add hl,de
        ld (LineError),hl
.point:
        ld bc,(LineX0)
        ld de,(LineY0)
        call PlotPixel
        ld hl,(LineX0)                  ; the end?
        ld de,(GRPACX)
        or a
        sbc hl,de
        jr nz,.notEnd
        ld hl,(LineY0)
        ld de,(GRPACY)
        or a
        sbc hl,de
        ret z
.notEnd:
        ld hl,(LineError)
        add hl,hl                       ; e2 = 2 * error
        push hl
        ld de,(LineDY)                  ; e2 >= DY: step x
        or a
        sbc hl,de
        call SignedNotBelow
        jr c,.noStepX
        ld hl,(LineError)
        add hl,de
        ld (LineError),hl
        ld hl,(LineX0)
        ld bc,(LineStepX)
        add hl,bc
        ld (LineX0),hl
.noStepX:
        pop hl                          ; e2 <= DX: step y
        ld de,(LineDX)
        ex de,hl
        or a
        sbc hl,de                       ; DX - e2
        call SignedNotBelow
        jr c,.point
        ld hl,(LineError)
        ld de,(LineDX)
        add hl,de
        ld (LineError),hl
        ld hl,(LineY0)
        ld bc,(LineStepY)
        add hl,bc
        ld (LineY0),hl
        jr .point

; SignedNotBelow: after SBC HL: carry when the signed result is negative (overflow taken into account).
SignedNotBelow:
        jp pe,.overflow
        bit 7,h
        scf
        ret nz
        or a
        ret
.overflow:
        bit 7,h
        scf
        ret z
        or a
        ret

; Box: the four sides of the box BC, DE - (GRPACX, GRPACY).
Box:
        push bc
        push de
        ld hl,(GRPACY)                  ; top: y0 from x0 to x1
        push hl
        ld (GRPACY),de
        call DrawLine
        pop hl
        ld (GRPACY),hl
        pop de
        pop bc
        push bc
        push de
        ld hl,(GRPACX)                  ; left: x0 from y0 to y1
        push hl
        ld (GRPACX),bc
        call DrawLine
        pop hl
        ld (GRPACX),hl
        pop de
        pop bc
        push de                         ; y0
        ld de,(GRPACY)                  ; bottom: y1 from x0 to x1
        call DrawLine
        pop de
        ld bc,(GRPACX)                  ; right: x1 from y0 to y1
        jp DrawLine

; FilledBox: every pixel of the box (SCREEN 5-8: the VDP's LMMV command).
FilledBox:
        ld a,(SCRMOD)
        cp $05
        jp nc,VdpFilledBox
        cp $02
        jr z,FilledBoxScreen2
        ld hl,(GRPACY)                  ; a line for each y from the smaller to the larger
        call OrderPair                  ; DE = smaller, HL = larger
.row:
        push hl
        push de
        push bc
        ld hl,(GRPACY)
        push hl
        ld (GRPACY),de
        call DrawLine
        pop hl
        ld (GRPACY),hl
        pop bc
        pop de
        pop hl
        rst $20
        ret z
        inc de
        jr .row

; FilledBoxScreen2: in SCREEN 2 the bytes the box covers whole get the colour as their background
; (the pattern cleared), as the original BASIC does; the pixels of the bytes at the edges one by one.
FilledBoxScreen2:
        ld hl,(GRPACX)
        call OrderPairBC                ; BC = left, HL = right
        ld (LineX0),bc
        ld (LineDX),hl
        ld hl,(GRPACY)
        call OrderPair                  ; DE = top, HL = bottom
        ld (LineDY),hl
.row:
        ld bc,(LineX0)
.pixel:
        ld hl,(LineDX)                  ; past the right edge: the next row
        or a
        sbc hl,bc
        jp m,.rowDone
        ld a,c                          ; a whole byte from here?
        and $07
        jr nz,.single
        ld a,l                          ; (right - x >= 7)
        cp $07
        jr nc,.whole
        ld a,h
        or a
        jr nz,.whole
.single:
        push bc
        push de
        call PlotPixel
        pop de
        pop bc
        inc bc
        jr .pixel
.whole:
        push bc
        push de
        call Clip
        jr c,.wholeDone
        call PixelAddress
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
        ld b,a
        rlca
        rlca
        rlca
        rlca
        or b
        call WriteVram
.wholeDone:
        pop de
        pop bc
        ld hl,$0008
        add hl,bc
        ld b,h
        ld c,l
        jr .pixel
.rowDone:
        ld hl,(LineDY)
        rst $20
        ret z
        inc de
        jr .row

; OrderPair: DE, HL in order (signed): DE the smaller.
OrderPair:
        push hl
        or a
        sbc hl,de
        pop hl
        ret p
        ex de,hl
        ret

; --- V9938 commands (SCREEN 5-8) ---

; VdpWaitCommand: until the VDP has finished its command (S#2 bit 0).
VdpWaitCommand:
        di
        ld a,$02
        out (VdpCommand),a
        ld a,$8F
        out (VdpCommand),a
        in a,(VdpCommand)
        push af
        xor a
        out (VdpCommand),a
        ld a,$8F
        out (VdpCommand),a
        ei
        pop af
        rrca
        jr c,VdpWaitCommand
        ret

; VdpCommandRegisters: R#36-R#46 from VdpBlock (DX, DY, NX, NY, CLR, ARG, CMD: 11 bytes).
VdpBlock        equ PARM2               ; (PARM2: the DEF FN area, free while drawing)
VdpRun:
        call VdpWaitCommand
        ld hl,VdpBlock + 3              ; DY on the active page (SET PAGE)
        ld a,(ACPAGE)
        add a,(hl)
        ld (hl),a
        di
        ld a,36
        out (VdpCommand),a
        ld a,$80 + 17                   ; R#17 = 36, increasing
        out (VdpCommand),a
        ld hl,VdpBlock
        ld bc,$0B00 + VdpIndirect
        otir
        ei
        ret

; VdpLine: LINE from BC, DE to (GRPACX, GRPACY) (both on the screen): the long side NX, the short NY, the direction in ARG.
VdpLine:
        ld (VdpBlock),bc                ; DX
        ld (VdpBlock + 2),de            ; DY
        ld hl,(GRPACX)
        or a
        sbc hl,bc
        ld b,$00                        ; ARG: bit 2 DIX (left), bit 3 DIY (up), bit 0 MAJ (y longer)
        jr nc,.right
        call NegateHL
        set 2,b
.right:
        push hl                         ; |dx|
        ld hl,(GRPACY)
        or a
        sbc hl,de
        jr nc,.down
        call NegateHL
        set 3,b
.down:
        pop de                          ; DE = |dx|, HL = |dy|
        rst $20                         ; |dy| - |dx|
        jr c,.xLonger
        set 0,b
        ex de,hl
.xLonger:
        ld (VdpBlock + 4),de            ; NX: the long side
        ld (VdpBlock + 6),hl            ; NY: the short side
        ld a,(ATRBYT)
        ld (VdpBlock + 8),a
        ld a,b
        ld (VdpBlock + 9),a
        ld a,(LOGOPR)                   ; LINE, with the logical operation
        and $0F
        or $70
        ld (VdpBlock + 10),a
        jr VdpRun

; VdpFilledBox: LMMV over the box BC, DE - (GRPACX, GRPACY).
VdpFilledBox:
        ld hl,(GRPACX)
        call OrderPairBC                ; BC = left, HL = right
        or a
        sbc hl,bc
        inc hl
        ld (VdpBlock + 4),hl            ; NX
        ld (VdpBlock),bc
        ld hl,(GRPACY)
        call OrderPair                  ; DE = top, HL = bottom
        or a
        sbc hl,de
        inc hl
        ld (VdpBlock + 6),hl            ; NY
        ld (VdpBlock + 2),de
        ld a,(ATRBYT)
        ld (VdpBlock + 8),a
        xor a
        ld (VdpBlock + 9),a
        ld a,(LOGOPR)                   ; LMMV, with the logical operation
        and $0F
        or $80
        ld (VdpBlock + 10),a
        jp VdpRun

; OrderPairBC: BC, HL in order (signed): BC the smaller.
OrderPairBC:
        push hl
        or a
        sbc hl,bc
        pop hl
        ret p
        push hl
        ld h,b
        ld l,c
        pop bc
        ret

; --- CIRCLE ---

; StatementCircle: CIRCLE (x, y), radius [, colour [, start [, end [, aspect]]]].
; The points of one octant come from the midpoint algorithm (x = r, y = 0 and up while x >= y: steps
; 0 to n); each is drawn in the 8 octants. An arc keeps the positions from start to end (round the
; circle, through 0 when start is past end): an angle (radians, 0 to 2 pi) gives the octant and the
; step int(fraction * n) in it, counted in the direction of the angle. A negative angle also draws the
; radius to that end. The aspect squeezes one axis: below 1 y * int(aspect * 256) / 256, above 1
; x * int(256 / aspect) / 256 (rounded); SCREEN 6 and 7 are 0.5 by default. (All as the original draws.)
CircleX         equ CENCNT              ; the centre
CircleY         equ CNPNTS
CircleXX        equ CPCNT               ; the octant point (CircleYY is its step)
CircleYY        equ CPCNT8
CircleError     equ CRCSUM
CircleN         equ BUF                 ; the last step of an octant
CircleStart     equ BUF + 2             ; the arc: its first and last positions (octant * (n + 1) + step)
CircleEnd       equ BUF + 4
CircleFlags     equ BUF + 6             ; see CircleFlag*
CircleFactor    equ BUF + 7             ; the squeeze (/ 256)
CircleBase      equ BUF + 8             ; octant * (n + 1), while drawing
CircleOctant    equ BUF + 10
CircleStartX    equ BUF + 11            ; the arc's ends as drawn (for the radiuses)
CircleStartY    equ BUF + 13
CircleEndX      equ BUF + 15
CircleEndY      equ BUF + 17
CircleRadius    equ BUF + 19
CircleFlagStartLine equ 0
CircleFlagEndLine equ 1
CircleFlagArc   equ 2
CircleFlagScaleX equ 3
CircleFlagScaleY equ 4

StatementCircle:
        call IsGraphicMode
        call GraphicCoordinates
        ld (CircleX),bc
        ld (CircleY),de
        ld (GRPACX),bc
        ld (GRPACY),de
        call Comma
        call EvalInteger
        bit 7,d
        jp nz,IllegalFunction
        push de
        call GraphicColour
        pop de
        push hl
        ld (CircleRadius),de
        call CircleSteps                ; n
        ld (CircleN),hl
        inc hl                          ; the whole circle: 0 to 8 (n + 1) - 1
        add hl,hl
        add hl,hl
        add hl,hl
        dec hl
        ld (CircleEnd),hl
        ld hl,$0000
        ld (CircleStart),hl
        xor a
        ld (CircleFlags),a
        ld a,(SCRMOD)                   ; SCREEN 6, 7: the aspect is 0.5
        cp $06
        jr c,.aspectDone
        cp $08
        jr nc,.aspectDone
        ld a,128
        ld (CircleFactor),a
        ld a,1 << CircleFlagScaleY
        ld (CircleFlags),a
.aspectDone:
        pop hl
        call CircleArgument             ; start
        jr nc,.noStart
        call CircleAngle
        ld (CircleStart),de
        ld b,1 << CircleFlagStartLine
        call CircleArcFlags
.noStart:
        call CircleArgument             ; end
        jr nc,.noEnd
        call CircleAngle
        ld (CircleEnd),de
        ld b,1 << CircleFlagEndLine
        call CircleArcFlags
.noEnd:
        call CircleArgument             ; aspect
        call c,CircleAspect
        call AtStatementEnd
        jp nz,SyntaxError
        push hl
        ld a,(LOGOPR)                   ; (CIRCLE draws with PSET; LOGOPR stays as it was)
        push af
        xor a
        ld (LOGOPR),a
        call CircleDraw
        pop af
        ld (LOGOPR),a
        pop hl
        ret

; CircleArcFlags: an arc; with carry also the radius flag B.
CircleArcFlags:
        ld a,(CircleFlags)
        set CircleFlagArc,a
        jr nc,.set
        or b
.set:
        ld (CircleFlags),a
        ret

; CircleArgument: ", value" (",," or the end: none, the comma left for the next). Carry with the value
; in DAC.
CircleArgument:
        call ThisChar
        cp ','
        jr nz,.none
        rst $10
        cp ','
        jr z,.none
        call AtStatementEnd
        jr z,.none
        call EvalExpression
        scf
        ret
.none:
        or a
        ret

; CircleInit: the octant's first point for radius DE: x = r, y = 0, error = 1 - r.
CircleInit:
        ld (CircleXX),de
        ld hl,$0000
        ld (CircleYY),hl
        inc hl
        or a
        sbc hl,de
        ld (CircleError),hl
        ret

; CircleMore: carry when the octant is done (x < y).
CircleMore:
        ld hl,(CircleXX)
        ld de,(CircleYY)
        or a
        sbc hl,de
        jp SignedNotBelow

; CircleNext: the octant's next point: y + 1; error < 0: error += 2y + 1, else x - 1 and error +=
; 2 (y - x) + 1.
CircleNext:
        ld hl,(CircleYY)
        inc hl
        ld (CircleYY),hl
        ld hl,(CircleError)
        bit 7,h
        jr z,.moveX
        ld de,(CircleYY)
        add hl,de
        add hl,de
        inc hl
        ld (CircleError),hl
        ret
.moveX:
        ld hl,(CircleXX)
        dec hl
        ld (CircleXX),hl
        ex de,hl
        ld hl,(CircleYY)
        or a
        sbc hl,de
        add hl,hl
        inc hl
        ld de,(CircleError)
        add hl,de
        ld (CircleError),hl
        ret

; CircleSteps: n, the last step of an octant of radius DE. Out: HL.
CircleSteps:
        call CircleInit
.step:
        call CircleMore
        jr c,.done
        call CircleNext
        jr .step
.done:
        ld hl,(CircleYY)
        dec hl
        ret

; CircleAngle: the angle in DAC as a position. Out: DE, carry when it was negative.
CircleAngle:
        push hl
        call ForceDouble
        pop hl
        ld a,(DAC)
        push af                         ; its sign
        res 7,a
        ld (DAC),a
        push hl
        ld hl,AngleScale                ; DAC * 2048 * 4 / pi: octant * 2048 + fraction
        ld de,ARG
        ld bc,8
        ldir
        ld ix,DECMUL
        call CallMain
        call ForceInteger               ; HL
        ld de,16385
        rst $20
        jp nc,IllegalFunction           ; above 2 pi
        ld a,h                          ; the octant (8 at 2 pi: the last step of octant 7)
        rrca
        rrca
        rrca
        and $1F
        cp $08
        jr c,.octant
        ld a,$07
        ld hl,(CircleN)
        jr .position
.octant:
        push af
        ld a,h
        and $07
        ld b,a
        ld c,l                          ; BC = the fraction (/ 2048)
        ld de,(CircleN)
        call CircleFraction             ; HL = fraction * n
        pop af
.position:
        ld (CircleOctant),a
        ex de,hl                        ; DE = the step (in the angle's direction)
        ld a,(CircleOctant)
        ld hl,(CircleN)
        inc hl
        ld b,h
        ld c,l
        ld hl,$0000
        or a
        jr z,.based
.times:
        add hl,bc
        dec a
        jr nz,.times
.based:
        add hl,de
        ex de,hl
        pop hl
        pop af
        rlca                            ; carry: negative
        ret
AngleScale:                             ; 2048 * 4 / pi, double precision
        db $44, $26, $07, $59, $45, $87, $61, $76

; CircleFraction: HL = BC * DE / 2048 (BC < 2048; DE < 8192).
CircleFraction:
        ld a,5
.align:
        sla c                           ; the fraction's top bit to bit 15
        rl b
        dec a
        jr nz,.align
        xor a                           ; A:HL = the product
        ld h,a
        ld l,a
        ld ixl,11
.bit:
        add hl,hl
        rla
        sla c
        rl b
        jr nc,.next
        add hl,de
        adc a,$00
.next:
        dec ixl
        jr nz,.bit
        ld l,h                          ; / 2048
        ld h,a
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ret

; CircleAspect: the aspect in DAC: the factor and the axis it squeezes (1: none).
CircleAspect:
        push hl
        call ForceDouble
        ld a,(DAC)
        bit 7,a
        jp nz,IllegalFunction
        cp $41
        jr c,.below                     ; (exponent 40h or less: below 1)
        call MoveDacToArg               ; 256 / aspect
        ld hl,Number256
        ld de,DAC
        ld bc,8
        ldir
        ld ix,DECDIV
        call CallMain
        ld b,1 << CircleFlagScaleX
        jr .factor
.below:
        ld hl,Number256                 ; aspect * 256
        ld de,ARG
        ld bc,8
        ldir
        ld ix,DECMUL
        call CallMain
        ld b,1 << CircleFlagScaleY
.factor:
        push bc
        call ForceInteger               ; HL
        pop bc
        ld a,(CircleFlags)
        and ~((1 << CircleFlagScaleX) | (1 << CircleFlagScaleY))
        inc h
        dec h
        jr nz,.set                      ; 256: no squeeze
        or b
        ld c,a
        ld a,l
        ld (CircleFactor),a
        ld a,c
.set:
        ld (CircleFlags),a
        pop hl
        ret
Number256:                              ; 256, double precision
        db $43, $25, $60, $00, $00, $00, $00, $00

; CircleDraw: the circle (or the arc) and the radiuses.
CircleDraw:
        ld de,(CircleRadius)
        call CircleInit
.step:
        call CircleMore
        jr c,.radiuses
        call CircleEight
        call CircleNext
        jr .step
.radiuses:
        ld a,(CircleFlags)
        bit CircleFlagStartLine,a
        jr z,.noStart
        ld hl,(CircleStartX)
        ld de,(CircleStartY)
        call CircleRadiusLine
.noStart:
        ld a,(CircleFlags)
        bit CircleFlagEndLine,a
        ret z
        ld hl,(CircleEndX)
        ld de,(CircleEndY)
; CircleRadiusLine: a line from HL, DE to the centre (the last point stays the centre).
CircleRadiusLine:
        ld b,h
        ld c,l
        ld hl,(CircleX)
        ld (GRPACX),hl
        ld hl,(CircleY)
        ld (GRPACY),hl
        call DrawLine
        ld hl,(CircleX)
        ld (GRPACX),hl
        ld hl,(CircleY)
        ld (GRPACY),hl
        ret

; CircleEight: the octant point in the 8 octants (those in the arc).
CircleEight:
        ld hl,$0000
        ld (CircleBase),hl
        xor a
.octant:
        ld (CircleOctant),a
        ld hl,(CircleYY)                ; its step: y, counted down in the odd octants
        bit 0,a
        jr z,.even
        ex de,hl
        ld hl,(CircleN)
        or a
        sbc hl,de
.even:
        ld de,(CircleBase)
        add hl,de                       ; HL = its position
        call CircleInArc
        jr nc,.next
        push hl
        call CircleOctantPoint          ; BC, DE
        pop hl
        push de
        ld de,(CircleStart)             ; the arc's ends: remembered for the radiuses
        rst $20
        pop de
        jr nz,.notStart
        ld (CircleStartX),bc
        ld (CircleStartY),de
.notStart:
        push de
        ld de,(CircleEnd)
        rst $20
        pop de
        jr nz,.notEnd
        ld (CircleEndX),bc
        ld (CircleEndY),de
.notEnd:
        call PlotPixel
.next:
        ld hl,(CircleBase)
        ld de,(CircleN)
        add hl,de
        inc hl
        ld (CircleBase),hl
        ld a,(CircleOctant)
        inc a
        cp $08
        jr c,.octant
        ret

; CircleInArc: carry when position HL is in the arc. Keeps HL.
CircleInArc:
        ld a,(CircleFlags)
        bit CircleFlagArc,a
        scf
        ret z
        push hl
        ld hl,(CircleEnd)
        ld de,(CircleStart)
        rst $20                         ; end - start
        pop hl
        jr c,.through0
        rst $20                         ; position - start
        ccf
        ret nc                          ; before the start
        push hl
        ld de,(CircleEnd)               ; and not past the end
        ex de,hl
        rst $20                         ; end - position
        pop hl
        ccf
        ret
.through0:                              ; from start round to end: position >= start or <= end
        rst $20
        ccf
        ret c
        push hl
        ld de,(CircleEnd)
        ex de,hl
        rst $20
        pop hl
        ccf
        ret

; CircleOctantPoint: the screen point of the octant point in octant CircleOctant (squeezed by the
; aspect). Out: BC = x, DE = y.
CircleOctantPoint:
        ld a,(CircleOctant)
        ld hl,OctantSigns
        add a,l
        ld l,a
        jr nc,.sign
        inc h
.sign:
        ld a,(hl)                       ; bit 0 x and y swapped, 1 dx negative, 2 dy negative
        ld hl,(CircleXX)
        ld de,(CircleYY)
        bit 0,a
        jr z,.notSwapped
        ex de,hl
.notSwapped:                            ; HL = dx, DE = dy (up)
        bit 1,a
        jr z,.dxDone
        call CircleNegateHL
.dxDone:
        bit 2,a
        jr z,.dyDone
        ex de,hl
        call CircleNegateHL
        ex de,hl
.dyDone:
        ld a,(CircleFlags)
        bit CircleFlagScaleX,a
        call nz,CircleScale
        ld a,(CircleFlags)
        bit CircleFlagScaleY,a
        jr z,.place
        ex de,hl
        call CircleScale
        ex de,hl
.place:
        ld bc,(CircleX)                 ; x = cx + dx, y = cy - dy
        add hl,bc
        ld b,h
        ld c,l
        ld hl,(CircleY)
        or a
        sbc hl,de
        ex de,hl
        ret
OctantSigns:
        db %000, %001, %011, %010, %110, %111, %101, %100

; CircleScale: HL * CircleFactor / 256, rounded half away from 0. Keeps BC, DE.
CircleScale:
        push bc
        push de
        ld a,h
        push af                         ; the sign
        or a
        call m,CircleNegateHL
        ex de,hl                        ; DE = |value|
        ld a,(CircleFactor)
        ld c,a
        xor a                           ; A:HL = the product
        ld h,a
        ld l,a
        ld b,8
.bit:
        add hl,hl
        rla
        sla c
        jr nc,.next
        add hl,de
        adc a,$00
.next:
        djnz .bit
        ld de,128
        add hl,de
        adc a,$00
        ld l,h
        ld h,a
        pop af
        or a
        call m,CircleNegateHL
        pop de
        pop bc
        ret

; CircleNegateHL: HL = -HL. Keeps the flags but A... (destroys A).
CircleNegateHL:
        push af
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        pop af
        ret

; --- PAINT ---

; StatementPaint: PAINT (x, y) [, colour [, border]] (the border is the colour by default; SCREEN 2
; and 4 have only that). A scan line fill with a stack of seeds in the free memory: SCREEN 3 by blocks
; (PaintFill), the others a row at a time (PaintFillBitmap, PaintFillSearch).
PaintColour     equ CSAVEA              ; colour, border
StatementPaint:
        call IsGraphicMode
        call GraphicCoordinates
        call GraphicColour
        ld a,(ATRBYT)
        ld (PaintColour + 1),a          ; the border: the colour unless given
        call ThisChar
        cp ','
        jr nz,.go
        rst $10
        push bc
        push de
        call EvalByte
        ld e,a
        ld a,(SCRMOD)                   ; SCREEN 2 and 4 have no border colour: the paint's own (as
        cp $02                          ; the original: a byte has only two colours)
        jr z,.noBorder
        cp $04
        jr z,.noBorder
        ld a,e
        ld (PaintColour + 1),a
.noBorder:
        pop de
        pop bc
.go:
        push hl
        ld a,(PaintColour + 1)          ; (the colours as the pixels hold them)
        call PixelBits
        ld (PaintColour + 1),a
        ld a,(ATRBYT)
        call PixelBits
        ld (PaintColour),a
        ld a,(LOGOPR)                   ; (PAINT draws with PSET; LOGOPR stays as it was)
        push af
        xor a
        ld (LOGOPR),a
        ld hl,(GRPACX)                  ; (the runs are drawn as lines: the last point stays)
        push hl
        ld hl,(GRPACY)
        push hl
        ld a,(SCRMOD)
        cp $03
        jr z,.blocks
        call PaintFillBitmap
        jr .filled
.blocks:
        call PaintFill
.filled:
        pop hl
        ld (GRPACY),hl
        pop hl
        ld (GRPACX),hl
        pop af
        ld (LOGOPR),a
        pop hl
        ret

; PaintFill: SCREEN 2 and 3 from BC, DE. The seeds (x, y) go on a stack that grows up from STREND. In
; SCREEN 3 a pixel is a block of 4 x 4: the steps are 4 (from the block's corner).
PaintStep       equ LOHDIR

PaintFill:
        ld a,(SCRMOD)
        cp $03
        ld a,$01
        jr nz,.step
        ld a,c                          ; (the block's corner)
        and $FC
        ld c,a
        ld a,e
        and $FC
        ld e,a
        ld a,$04
.step:
        ld (PaintStep),a
        ld hl,(STREND)
        ld (LOHADR),hl                  ; the seed stack's top
        call PushSeed
.next:
        ld hl,(LOHADR)                  ; empty?
        ld de,(STREND)
        rst $20
        ret z
        call PopSeed                    ; BC, DE
        call IsFillable
        jr c,.next
        ; to the left end of the run
.left:
        call .backBC
        call IsFillable
        jr nc,.left
        call .onBC
        ld (LOHCNT),bc                  ; the run's left end
        ; fill right, looking at the rows above and below for new runs
        xor a
        ld (LOHMSK),a                   ; bit 0: a seed above is pending, bit 1: below
.fill:
        call IsFillable
        jr c,.runEnd
        push bc
        push de
        call PlotPixel
        pop de
        pop bc
        call .backDE                    ; above
        ld a,$01
        call .look
        call .onDE
        call .onDE                      ; below
        ld a,$02
        call .look
        call .backDE
        call .onBC
        jr .fill
.backBC:                                ; BC - step
        ld a,(PaintStep)
        neg
        add a,c
        ld c,a
        ret c
        dec b
        ret
.onBC:                                  ; BC + step
        ld a,(PaintStep)
        add a,c
        ld c,a
        ret nc
        inc b
        ret
.backDE:
        ld a,(PaintStep)
        neg
        add a,e
        ld e,a
        ret c
        dec d
        ret
.onDE:
        ld a,(PaintStep)
        add a,e
        ld e,a
        ret nc
        inc d
        ret
.runEnd:
        jr .next
; .look: the pixel at BC, DE: a fillable one starts a run (one seed per run), others end it.
; In: A = the bit of LOHMSK for this row.
.look:
        push af
        call IsFillable
        jr c,.closed
        pop af
        ld hl,LOHMSK
        push af
        and (hl)
        jr z,.newRun
        pop af                          ; this run already has its seed
        ret
.newRun:
        pop af
        or (hl)
        ld (hl),a
        push bc
        push de
        call PushSeed
        pop de
        pop bc
        ret
.closed:
        pop af
        cpl
        ld hl,LOHMSK
        and (hl)
        ld (hl),a                       ; the next fillable pixel starts a new run
        ret

; PaintFillBitmap: PAINT in SCREEN 5-8 from BC, DE, a row at a time. A row is read from VRAM and spread
; to a byte a pixel in a buffer above STREND (with a pixel of the border's colour at each end, so the
; scans stop there); the run of fillable pixels around a seed is found there, drawn with the VDP's LINE
; command (and in the buffer), then the rows above and below are read and every run of fillable pixels
; over it gets a seed. The seeds go above the buffer.
PaintBuffer     equ CENCNT              ; (the CIRCLE work area: not in use) pixel 0 of the buffer
PaintSeeds      equ CNPNTS              ; the bottom of the seed stack
PaintCached     equ CXOFF               ; the row in the buffer (FFFFh: none)
PaintLeft       equ LOHCNT              ; the run
PaintRight      equ SKPCNT
PaintY          equ MOVCNT
PaintSeedY      equ CYOFF               ; the row PaintSeedRow looks at
PaintWidth      equ LFPROG              ; (LFPROG, RTPROG) the screen's width
PaintHeight     equ CSAVEM

PaintFillBitmap:
        ld a,(SCRMOD)                   ; (SCREEN 2: the rows are read from the patterns and colours,
        cp $05                          ; the runs drawn a pixel at a time)
        jr c,.buffer
        ld a,(PaintColour)              ; the border is the paint's colour: the VDP finds the runs
        ld h,a
        ld a,(PaintColour + 1)
        cp h
        jp z,PaintFillSearch
.buffer:
        push bc
        push de
        call ScreenSize
        ld (PaintWidth),hl
        ld a,e
        ld (PaintHeight),a
        ld hl,(STREND)                  ; the buffer: a border pixel, the pixels, a border pixel
        ld a,(PaintColour + 1)
        ld (hl),a
        inc hl
        ld (PaintBuffer),hl
        ld de,(PaintWidth)
        add hl,de
        ld (hl),a
        inc hl
        ld (PaintSeeds),hl
        ld (LOHADR),hl
        ld hl,$FFFF
        ld (PaintCached),hl
        pop de
        pop bc
        call PushSeed
.next:
        ld hl,(LOHADR)                  ; no seeds left?
        ld de,(PaintSeeds)
        rst $20
        ret z
        call PopSeed                    ; BC, DE
        ld (PaintY),de
        call PaintLoadRow
        ld hl,(PaintBuffer)
        add hl,bc
        ld a,(PaintColour + 1)
        ld d,a                          ; D = border, E = paint
        ld a,(PaintColour)
        ld e,a
        ld a,(hl)
        cp d
        jr z,.next                      ; (painted since it was seeded)
        cp e
        jr z,.next
        push hl
.left:
        dec hl
        ld a,(hl)
        cp d
        jr z,.leftEnd
        cp e
        jr nz,.left
.leftEnd:
        inc hl
        ld (PaintLeft),hl               ; (as addresses in the buffer for now)
        pop hl
.right:
        inc hl
        ld a,(hl)
        cp d
        jr z,.rightEnd
        cp e
        jr nz,.right
.rightEnd:
        dec hl
        ld (PaintRight),hl
        ld de,(PaintLeft)               ; the run in the buffer: painted
        or a
        sbc hl,de
        ld b,h
        ld c,l
        inc bc
        ld h,d
        ld l,e
        ld a,(PaintColour)
.mark:
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        ld a,(PaintColour)
        jr nz,.mark
        ld de,(PaintBuffer)             ; the run's ends as x
        ld hl,(PaintLeft)
        or a
        sbc hl,de
        ld (PaintLeft),hl
        ld hl,(PaintRight)
        or a
        sbc hl,de
        ld (PaintRight),hl
        ld (GRPACX),hl                  ; drawn
        ld de,(PaintY)
        ld (GRPACY),de
        ld bc,(PaintLeft)
        ld a,(SCRMOD)
        cp $05
        jr c,.pixels
        call VdpLine
        jr .drawn
.pixels:
        push bc
        push de
        call PlotPixel
        pop de
        pop bc
        ld hl,(PaintRight)
        or a
        sbc hl,bc
        inc bc
        jr nz,.pixels
.drawn:
        ld de,(PaintY)                  ; the row above
        ld a,d
        or e
        jr z,.below
        dec de
        call PaintSeedRow
.below:
        ld de,(PaintY)                  ; the row below
        inc de
        ld a,(PaintHeight)
        cp e
        call nz,PaintSeedRow
        jp .next

; PaintFillSearch: PAINT in SCREEN 5-8 when the border is the paint's colour: a pixel is fillable when it
; is of another colour, so the VDP's SRCH command finds the ends of a run and of the runs over and under
; it.
SearchRight     equ $00                 ; (VdpSearch's ARG) to the right, stop at the colour
SearchLeft      equ $04                 ; to the left
SearchOther     equ $02                 ; stop at another colour

PaintFillSearch:
        push bc
        push de
        call ScreenSize
        ld (PaintWidth),hl
        ld a,e
        ld (PaintHeight),a
        ld hl,(STREND)
        ld (PaintSeeds),hl
        ld (LOHADR),hl
        pop de
        pop bc
        call PushSeed
.next:
        ld hl,(LOHADR)                  ; no seeds left?
        ld de,(PaintSeeds)
        rst $20
        ret z
        call PopSeed                    ; BC, DE
        ld (PaintY),de
        ld h,b
        ld l,c
        ld a,SearchRight | SearchOther  ; still fillable? (another colour right there)
        call VdpSearch
        jr c,.next
        or a
        sbc hl,bc
        jr nz,.next                     ; (painted since it was seeded)
        ld h,b                          ; the left end: past the colour to the left
        ld l,c
        ld a,SearchLeft
        call VdpSearch
        inc hl                          ; (at the edge: -1 + 1)
        ld (PaintLeft),hl
        ld h,b                          ; the right end: before the colour to the right
        ld l,c
        ld a,SearchRight
        call VdpSearch
        jr nc,.rightFound
        ld hl,(PaintWidth)
.rightFound:
        dec hl
        ld (PaintRight),hl
        ld (GRPACX),hl                  ; drawn
        ld (GRPACY),de
        ld bc,(PaintLeft)
        call VdpLine
        ld de,(PaintY)                  ; the row above
        ld a,d
        or e
        jr z,.below
        dec de
        call PaintSearchRow
.below:
        ld de,(PaintY)                  ; the row below
        inc de
        ld a,(PaintHeight)
        cp e
        call nz,PaintSearchRow
        jp .next

; PaintSearchRow: row DE over (or under) the run: a seed at the start of every run of other colours in it.
PaintSearchRow:
        ld hl,(PaintLeft)
.run:
        ld a,SearchRight | SearchOther  ; the next fillable pixel
        call VdpSearch
        ret c
        call .inRun
        ret c
        ld b,h
        ld c,l
        push hl
        push de
        call PushSeed
        pop de
        pop hl
        ld a,SearchRight                ; its run's end
        call VdpSearch
        ret c
        call .inRun
        ret c
        jr .run
.inRun:                                 ; carry when HL is past the run
        push de
        ex de,hl
        ld hl,(PaintRight)
        or a
        sbc hl,de                       ; right - x
        ex de,hl
        pop de
        ret

; VdpSearch: the VDP's SRCH from x HL of row DE for the paint's colour, A = its ARG (SearchLeft,
; SearchOther). Out: HL = where it stopped, carry when it reached the edge (HL: -1 or the width... as it
; was left). Keeps BC, DE.
VdpSearch:
        push bc
        push af
        call VdpWaitCommand
        di
        ld a,32                         ; R#32-R#35: SX, SY
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld c,VdpIndirect
        out (c),l
        out (c),h
        out (c),e
        ld a,(ACPAGE)                   ; (SY on the active page)
        add a,d
        out (c),a
        ld a,44                         ; R#44-R#46: CLR, ARG, CMD
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld a,(PaintColour)
        out (c),a
        pop af
        out (c),a
        ld a,$60
        out (c),a
        ei
        call VdpWaitCommand
        ld a,$02
        call VdpStatus
        and $10                         ; BD: found
        jr z,.edge
        ld a,$08
        call VdpStatus
        ld l,a
        ld a,$09
        call VdpStatus
        and $01
        ld h,a
        pop bc
        or a
        ret
.edge:
        ld hl,$FFFF
        pop bc
        scf
        ret

; PaintSeedRow: row DE under (or over) the run: a seed for every run of fillable pixels in it.
PaintSeedRow:
        call PaintLoadRow
        ld (PaintSeedY),de
        ld hl,(PaintRight)
        ld de,(PaintLeft)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        inc bc                          ; BC = the pixels
        ld hl,(PaintBuffer)
        add hl,de                       ; HL = the first
        ld a,(PaintColour + 1)
        ld d,a
        ld a,(PaintColour)
        ld e,a
.outside:                               ; looking for a fillable pixel
        ld a,(hl)
        cp d
        jr z,.outsideNext
        cp e
        jr z,.outsideNext
        push bc                         ; it starts a run: a seed
        push de
        push hl
        ld de,(PaintBuffer)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld de,(PaintSeedY)
        call PushSeed
        pop hl
        pop de
        pop bc
        jr .insideNext
.outsideNext:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.outside
        ret
.inside:                                ; in a run: up to its end
        ld a,(hl)
        cp d
        jr z,.outsideNext
        cp e
        jr z,.outsideNext
.insideNext:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.inside
        ret

; PaintLoadRow: row DE of the screen into the buffer, a byte a pixel (unless it is there already).
; Keeps BC, DE, HL.
PaintLoadRow:
        push hl
        ld hl,(PaintCached)
        rst $20
        pop hl
        ret z
        push bc
        push de
        push hl
        ld (PaintCached),de
        ld a,(SCRMOD)
        cp $05
        jr c,.screen2
        call VdpWaitCommand             ; (a run may still be being drawn)
        ld h,e                          ; y * 256 (SCREEN 7, 8: a page is 64K) or y * 128 (5, 6: 32K)
        ld l,$00
        ld a,(ACPAGE)
        ld d,a                          ; D = the address's bit 16
        ld a,(SCRMOD)
        cp $07
        jr nc,.wide
        srl h
        rr l
        srl d                           ; (an odd page: the upper 32K)
        jr nc,.wide
        set 7,h
.wide:
        call SetVramRead17
        ld hl,(PaintBuffer)
        ld c,VdpData
        ld a,(SCRMOD)
        cp $08
        jr z,.bytes
        cp $06
        jr z,.twoBits
        ld b,128                        ; 4 bits: 128 (SCREEN 5) or 256 (7) bytes
        cp $07
        jr nz,.nibbles
        ld b,$00
.nibbles:
        in a,(c)
        ld e,a
        rrca
        rrca
        rrca
        rrca
        and $0F
        ld (hl),a
        inc hl
        ld a,e
        and $0F
        ld (hl),a
        inc hl
        djnz .nibbles
        jr .loaded
.twoBits:
        ld b,128
.quarter:
        in a,(c)
        ld e,a
        ld d,4
.pair:
        rlca
        rlca
        ld e,a
        and $03
        ld (hl),a
        inc hl
        ld a,e
        dec d
        jr nz,.pair
        djnz .quarter
        jr .loaded
.bytes:
        ld b,$00
        inir
.loaded:
        pop hl
        pop de
        pop bc
        ret
.screen2:                               ; 32 bytes of pattern and of colour: a pixel is the colour's
        ld a,e                          ; high nibble where its bit is set, else the low one
        rrca
        rrca
        rrca
        and $1F
        ld h,a
        ld a,e
        and $07
        ld l,a                          ; HL = the row's first byte, (y AND F8h) * 32 + (y AND 7)
        ld de,(PaintBuffer)
        ld b,32
.column:
        push bc
        push hl
        ld bc,(GRPCOL)
        add hl,bc
        xor a
        call SetVramAddress
        in a,(VdpData)
        ld c,a                          ; C = the colours
        pop hl
        push hl
        push bc
        ld bc,(GRPCGP)
        add hl,bc
        xor a
        call SetVramAddress
        pop bc
        in a,(VdpData)
        ld b,8                          ; A = the pattern
.bit:
        rlca
        push af
        ld a,c
        jr nc,.background
        rrca
        rrca
        rrca
        rrca
.background:
        and $0F
        ld (de),a
        inc de
        pop af
        djnz .bit
        pop hl
        ld bc,8
        add hl,bc
        pop bc
        djnz .column
        jr .loaded

; SetVramRead17: VRAM reads from HL with bit 16 of the address in D. Destroys AF, D.
SetVramRead17:
        ld a,h
        rlca
        rlca
        and $03
        sla d
        sla d
        or d
        di
        ld (RG14SAV),a
        out (VdpCommand),a
        ld a,$8E
        out (VdpCommand),a
        ld a,l
        out (VdpCommand),a
        ld a,h
        and $3F
        out (VdpCommand),a
        ei
        ret

; IsFillable: carry when pixel BC, DE is outside, of the border's colour or already painted.
IsFillable:
        push bc
        push de
        call PixelColour
        pop de
        pop bc
        ret c
        ld hl,PaintColour + 1
        cp (hl)
        scf
        ret z
        dec hl
        cp (hl)
        scf
        ret z
        or a
        ret

; PushSeed / PopSeed: BC, DE on the seed stack (Out of memory near the stack).
PushSeed:
        ld hl,(LOHADR)
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (LOHADR),hl
        push de
        ld de,$0080
        add hl,de
        ex de,hl
        ld hl,$0000
        add hl,sp
        rst $20
        pop de
        ret nc
        jp OutOfMemory
PopSeed:
        ld hl,(LOHADR)
        dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        dec hl
        ld b,(hl)
        dec hl
        ld c,(hl)
        ld (LOHADR),hl
        ret

; --- sprites ---

; SpriteTablesAny: HL = the sprite pattern table, DE = the attribute table, for any mode.
SpriteTablesAny:
        ld a,(RG6SAV)
        and $3F
        add a,a
        add a,a
        add a,a
        ld h,a
        ld l,$00                        ; R#6 * 800h
        ld a,(RG5SAV)                   ; attributes: R#11 R#5 * 80h
        ld e,a
        ld a,(SCRMOD)
        cp $04
        ld a,e
        jr c,.tms
        and $FC                         ; (sprite mode 2: the low bits are ones)
.tms:
        ld d,$00
        ld e,a
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        ret

; StatementPutSprite: PUT SPRITE n [, (x, y)] [, colour] [, pattern].
StatementPut:
        cp TkSprite
        jp nz,SyntaxError
        rst $10
        call EvalByte
        cp 32
        jp nc,IllegalFunction
        ld (SpriteNumber),a
        push hl
        call SpriteTablesAny
        pop hl
        ld a,(SpriteNumber)             ; DE = this sprite's attributes
        add a,a
        add a,a
        add a,e
        ld e,a
        jr nc,.attr
        inc d
.attr:
        ld (PutSpriteAttribute),de
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.noPosition
        call GraphicCoordinates
        push hl
        ld hl,(PutSpriteAttribute)
        call SetVramWriteBig
        ld a,e                          ; Y, X (as the original BASIC writes them)
        out (VdpData),a
        ld a,c
        out (VdpData),a
        pop hl
.noPosition:
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.noColour
        call EvalByte
        push hl
        push af
        ld a,(SCRMOD)
        cp $04
        jr nc,.colourTable
        ld hl,(PutSpriteAttribute)
        inc hl
        inc hl
        inc hl
        pop af
        call WriteVramBig
        pop hl
        jr .noColour
.colourTable:                           ; sprite mode 2: the 16 lines of its colour table
        ld hl,(PutSpriteAttribute)
        ld de,-$0200
        add hl,de
        ld a,(SpriteNumber)
        ld e,a
        ld d,$00
        ex de,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        call SetVramWriteBig
        pop af
        ld b,16
.line:
        out (VdpData),a
        djnz .line
        pop hl
.noColour:
        call ThisChar
        cp ','
        ret nz
        rst $10
        call EvalByte
        push hl
        ld b,a
        ld a,(RG1SAV)                   ; 16 x 16: pattern n is n * 4
        and $02
        ld a,b
        jr z,.small
        add a,a
        add a,a
.small:
        ld hl,(PutSpriteAttribute)
        inc hl
        inc hl
        call WriteVramBig
        pop hl
        ret
SpriteNumber    equ TEMP3
PutSpriteAttribute equ TEMP2

; StatementSprite: SPRITE$(n) = string (the pattern; zeros after a short string).
StatementSprite:
        cp '$'
        jp nz,SyntaxError
        rst $10
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        push de
        call ThisChar
        rst $08
        db TkEqual
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        pop hl
        ex (sp),hl                      ; the pattern number, the text on the stack
        push de
        push bc
        ld a,(RG1SAV)                   ; 8 or 32 bytes a pattern
        and $02
        ld c,8
        jr z,.size
        ld c,32
.size:
        ld a,l
        ld h,$00
        push bc
        ld b,$00
        call UnsignedMultiplyHLBC
        pop bc
        push hl
        call SpriteTablesAny            ; HL = patterns
        pop de
        add hl,de
        call SetVramWriteBig
        pop af                          ; A = the string's length (pushed as B)... C = size
        pop de
        ld b,c
.byte:
        or a
        jr z,.zero
        push af
        ld a,(de)
        out (VdpData),a
        inc de
        pop af
        dec a
        djnz .byte
        pop hl
        ret
.zero:
        out (VdpData),a
        djnz .byte
        pop hl
        ret

; UnsignedMultiplyHLBC: HL = L * C (small numbers).
UnsignedMultiplyHLBC:
        ld h,$00
        ld b,h
        push de
        ex de,hl
        ld hl,$0000
.add:
        ld a,c
        or a
        jr z,.done
        add hl,de
        dec c
        jr .add
.done:
        pop de
        ret

; --- the palette ---

; StatementColorPalette: COLOR = (n, red, green, blue) (levels 0-7).
StatementColorPalette:
        rst $10                         ; past =
        call ThisChar
        rst $08
        db '('
        call EvalByte
        cp 16
        jp nc,IllegalFunction
        push af
        call Comma
        call EvalByte
        push af
        call Comma
        call EvalByte
        push af
        call Comma
        call EvalByte
        call CloseBracket
        ld e,a                          ; blue
        pop af
        ld d,a                          ; green
        pop af
        ld c,a                          ; red
        pop af                          ; colour number
        push hl
        push de
        push bc
        ld b,a
        ld c,$10
        call WriteVdpReg                ; R#16 = the colour
        pop bc
        pop de
        ld a,c
        and $07
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,e
        and $07
        or c
        di
        out (VdpPalette),a              ; red * 16 + blue, then green
        ld a,d
        and $07
        out (VdpPalette),a
        ei
        pop hl
        ret
