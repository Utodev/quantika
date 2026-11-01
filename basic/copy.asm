; copy.asm: SET PAGE and COPY between parts of the VRAM.

; SetPageStatement: SET PAGE [display] [, active] (HL past PAGE: basic/settings.asm reads the word).
SetPageStatement:
        call MaxPage                    ; (Illegal function call below SCREEN 5)
        call ThisChar
        cp ','
        jr z,.active
        call PageNumber
        ld (DPPAGE),a
        call ThisChar
        cp ','
        jr nz,.set
.active:
        rst $10
        call PageNumber
        ld (ACPAGE),a
.set:
        push hl
        call SetPage
        pop hl
        ret

; PageNumber: a page of the mode. Out: A. Destroys BC, DE.
PageNumber:
        call EvalByte
        ld c,a
        call MaxPage
        ld a,c
        cp b
        ret z
        ret c
        jp IllegalFunction

; MaxPage: B = the last page of the mode (SCREEN 5, 6: 3; 7, 8: 1); Illegal function call in the others.
; Keeps the others but A.
MaxPage:
        ld a,(SCRMOD)
        cp $05
        jp c,IllegalFunction
        ld b,$03
        cp $07
        ret c
        ld b,$01
        ret

; StatementCopy: COPY (x1, y1) - (x2, y2) [, page] TO (x3, y3) [, page] [, operation]: the VDP's LMMM.
; From (x1, y1) towards (x2, y2), to (x3, y3) in the same directions (left or up when x2 or y2 is the
; smaller). The pages are the active one by default.
StatementCopy:
        call MaxPage
        call ThisChar
        cp '('
        jp nz,CopyFromArray             ; (files: with the disk)
        call GraphicCoordinates
        push bc                         ; x1, y1
        push de
        call ThisChar
        rst $08
        db TkMinus
        call GraphicCoordinates         ; x2, y2
        ld a,(ACPAGE)
        call CopyPage
        ld (VdpBlock + 9),a             ; (the source page, for now)
        pop hl                          ; y1
        push hl
        ex de,hl                        ; DE = y1, HL = y2
        or a
        sbc hl,de                       ; y2 - y1
        ld a,$00
        jr nc,.down
        call NegateHL
        ld a,$08                        ; DIY: up
.down:
        inc hl
        ld (VdpBlock + 10),hl           ; NY (kept above the block for now)
        ld (CopyArg),a
        pop de                          ; y1
        pop hl                          ; x1
        push hl
        push de
        ld d,b                          ; (BC = x2)
        ld e,c
        ex de,hl                        ; DE = x1, HL = x2
        or a
        sbc hl,de
        jr nc,.right
        call NegateHL
        ld a,(CopyArg)
        or $04                          ; DIX: left
        ld (CopyArg),a
.right:
        inc hl
        ld (CopyWidth),hl               ; NX
        pop de                          ; the source: SX, SY on its page
        pop bc
        ld (CopySource),bc
        ld a,(VdpBlock + 9)
        add a,d
        ld d,a
        ld (CopySource + 2),de
        ld hl,(CopyText)                ; (the text pointer was kept)
        call ThisChar
        rst $08
        db TkTo
        cp '('
        jp nz,CopyToArray
        call GraphicCoordinates         ; x3, y3
        ld a,(ACPAGE)
        call CopyPage
        add a,d
        ld d,a
        ld (CopyDest),bc
        ld (CopyDest + 2),de
        call GraphicOperation           ; the operation (PSET by default)
        push hl
        call VdpWaitCommand
        di
        ld a,32                         ; R#32-R#46: SX, SY, DX, DY, NX, NY, CLR, ARG, CMD
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld hl,CopySource
        ld bc,$0800 + VdpIndirect
        otir
        ld hl,(CopyWidth)
        out (c),l
        out (c),h
        ld hl,(VdpBlock + 10)
        out (c),l
        out (c),h
        xor a
        out (c),a
        ld a,(CopyArg)
        out (c),a
        ld a,(LOGOPR)
        and $0F
        or $90                          ; LMMM
        out (c),a
        ei
        pop hl
        ret

CopySource      equ BUF                 ; SX, SY (on its page), then DX, DY: the order of R#32-R#39
CopyData        equ BUF + 13            ; (arrays) the data's address
CopyBits        equ BUF + 15            ; bits a pixel
CopyByte        equ BUF + 16            ; the byte being filled or emptied
CopyBitsLeft    equ BUF + 17            ; its bits not used yet
CopyRows        equ BUF + 18            ; rows and columns left
CopyColumns     equ BUF + 20
CopyX           equ BUF + 22            ; the pixel
CopyY           equ BUF + 24
CopyPageSaved   equ BUF + 26
CopyDest        equ BUF + 4
CopyWidth       equ BUF + 8
CopyArg         equ BUF + 10
CopyText        equ BUF + 11

; CopyPage: an optional ", page" (A = the default; ",," leaves the second comma for what follows).
; Out: A. Keeps BC, DE; HL = the text, also in CopyText.
CopyPage:
        push af
        call ThisChar
        cp ','
        jr nz,.default
        rst $10
        cp ','
        jr z,.default
        push bc
        push de
        call PageNumber
        pop de
        pop bc
        ld (CopyText),hl
        inc sp                          ; (the default goes)
        inc sp
        ret
.default:
        ld (CopyText),hl
        pop af
        ret

; --- arrays: width (2 bytes), height (2 bytes), then the pixels at the mode's bits, the first in the
;     high bits, the rows one after another (as the original keeps them) ---

; CopyToArray: COPY (x1, y1) - (x2, y2) [, page] TO array (HL at the name): from (x1, y1) towards
; (x2, y2) a row at a time.
CopyToArray:
        call CopyFindArray              ; DE = the data, BC = its bytes
        ld (CopyData),de
        push hl
        push bc
        ld hl,(CopyWidth)               ; it must fit: 4 + (width * height * bits + 7) / 8
        ld de,(VdpBlock + 10)
        call CopyDataBytes
        pop bc
        ex de,hl
        ld h,b
        ld l,c
        rst $20                         ; room - needed
        jp c,IllegalFunction
        ld hl,(CopyData)                ; the sizes
        ld de,(CopyWidth)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld de,(VdpBlock + 10)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (CopyData),hl
        ld hl,(CopySource)
        ld (CopyX),hl
        ld hl,(CopySource + 2)          ; (SY has the page in it: POINT on page 0)
        ld (CopyY),hl
        ld a,(ACPAGE)
        ld (CopyPageSaved),a
        xor a
        ld (ACPAGE),a
        ld (CopyByte),a
        ld a,8
        ld (CopyBitsLeft),a
        ld hl,(VdpBlock + 10)
        ld (CopyRows),hl
.row:
        ld hl,(CopyWidth)
        ld (CopyColumns),hl
        ld bc,(CopyX)
.pixel:
        push bc
        ld de,(CopyY)
        call VdpPoint
        call CopyPutPixel
        pop bc
        ld a,(CopyArg)                  ; the next column
        call CopyStepX
        ld hl,(CopyColumns)
        dec hl
        ld (CopyColumns),hl
        ld a,h
        or l
        jr nz,.pixel
        ld a,(CopyArg)                  ; the next row
        call CopyStepY
        ld hl,(CopyRows)
        dec hl
        ld (CopyRows),hl
        ld a,h
        or l
        jr nz,.row
        ld a,(CopyBitsLeft)             ; the last byte
        cp 8
        jr z,.done
        ld hl,(CopyData)
        ld a,(CopyByte)
        ld (hl),a
.done:
        ld a,(CopyPageSaved)
        ld (ACPAGE),a
        pop hl
        ret

; CopyFromArray: COPY array [, direction] TO (x, y) [, page] [, operation] (HL at the name). The
; direction: bit 0 the columns to the left, bit 1 the rows upwards.
CopyFromArray:
        call CopyFindArray
        push de                         ; the data
        xor a
        ld (CopyArg),a
        call ThisChar
        cp ','
        jr nz,.to
        rst $10
        call EvalByte
        cp 4
        jp nc,IllegalFunction
        add a,a                         ; (bit 0 -> DIX, bit 1 -> DIY: as LMMM's ARG)
        add a,a
        ld (CopyArg),a
.to:
        call ThisChar
        rst $08
        db TkTo
        call GraphicCoordinates
        ld (CopyX),bc
        ld (CopyY),de
        ld a,(ACPAGE)
        call CopyPage
        ld (CopyPageSaved + 1),a        ; (the destination page)
        call GraphicOperation
        pop de
        push hl
        ex de,hl
        ld e,(hl)                       ; the sizes
        inc hl
        ld d,(hl)
        inc hl
        ld (CopyWidth),de
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (CopyRows),de
        ld (CopyData),hl
        ld a,(ACPAGE)
        ld (CopyPageSaved),a
        ld a,(CopyPageSaved + 1)
        ld (ACPAGE),a
        call CopyBitsOfMode
        xor a
        ld (CopyBitsLeft),a
        ld hl,(CopyRows)
        ld a,h
        or l
        jr z,.done
.row:
        ld hl,(CopyWidth)
        ld a,h
        or l
        jr z,.done
        ld (CopyColumns),hl
        ld bc,(CopyX)
.pixel:
        call CopyGetPixel               ; A
        ld (ATRBYT),a
        push bc
        ld de,(CopyY)
        call Clip
        call nc,VdpPset
        pop bc
        ld a,(CopyArg)
        call CopyStepX
        ld hl,(CopyColumns)
        dec hl
        ld (CopyColumns),hl
        ld a,h
        or l
        jr nz,.pixel
        ld a,(CopyArg)
        call CopyStepY
        ld hl,(CopyRows)
        dec hl
        ld (CopyRows),hl
        ld a,h
        or l
        jr nz,.row
.done:
        ld a,(CopyPageSaved)
        ld (ACPAGE),a
        pop hl
        ret

; CopyStepX: BC (the column) one step to the right, or to the left with bit 2 of A (DIX). The first
; column again comes from CopyX at each row (CopyFromArray) or CopySource (CopyToArray): see
; CopyStepY.
CopyStepX:
        bit 2,a
        jr nz,.left
        inc bc
        ret
.left:
        dec bc
        ret

; CopyStepY: CopyY one row down, or up with bit 3 of A (DIY).
CopyStepY:
        ld hl,(CopyY)
        bit 3,a
        jr nz,.up
        inc hl
        jr .set
.up:
        dec hl
.set:
        ld (CopyY),hl
        ret

; CopyBitsOfMode: CopyBits = 4, 2 (SCREEN 6) or 8 (SCREEN 8).
CopyBitsOfMode:
        ld a,(SCRMOD)
        ld b,8
        cp $08
        jr z,.set
        ld b,2
        cp $06
        jr z,.set
        ld b,4
.set:
        ld a,b
        ld (CopyBits),a
        ret

; CopyDataBytes: HL = 4 + (HL * DE * bits + 7) / 8 (width HL, height DE), carry when it is too big.
CopyDataBytes:
        call CopyBitsOfMode
        ld b,h
        ld c,l
        ld hl,$0000                     ; HL = width * height
.times:
        ld a,d
        or e
        jr z,.timesDone
        add hl,bc
        ret c
        dec de
        jr .times
.timesDone:
        ld a,(CopyBits)                 ; * bits / 8, rounded up
        cp 8
        jr z,.plus4
        ld de,1
        cp 4
        jr z,.half
        ld de,3                         ; 2 bits: / 4
        add hl,de
        srl h
        rr l
        srl h
        rr l
        jr .plus4
.half:
        add hl,de
        srl h
        rr l
.plus4:
        ld de,4
        add hl,de
        ret

; CopyPutPixel: pixel A into the data (the bits of the mode, from the high ones down).
CopyPutPixel:
        ld c,a
        ld a,(CopyBits)
        ld b,a
        ld a,(CopyBitsLeft)
        sub b
        ld (CopyBitsLeft),a
        ld e,a                          ; shift the pixel to its place
        ld a,c
        inc e
.shift:
        dec e
        jr z,.placed
        add a,a
        jr .shift
.placed:
        ld hl,CopyByte
        or (hl)
        ld (hl),a
        ld a,(CopyBitsLeft)
        or a
        ret nz
        ld hl,(CopyData)                ; the byte is full
        ld a,(CopyByte)
        ld (hl),a
        inc hl
        ld (CopyData),hl
        xor a
        ld (CopyByte),a
        ld a,8
        ld (CopyBitsLeft),a
        ret

; CopyGetPixel: the next pixel of the data. Out: A. Keeps BC.
CopyGetPixel:
        ld a,(CopyBitsLeft)
        or a
        jr nz,.have
        ld hl,(CopyData)                ; the next byte
        ld a,(hl)
        inc hl
        ld (CopyData),hl
        ld (CopyByte),a
        ld a,8
.have:
        push bc
        ld hl,CopyBits
        sub (hl)
        ld (CopyBitsLeft),a
        ld b,(hl)                       ; the pixel: the top bits of the byte
        ld a,(CopyByte)
        ld c,$00
.bit:
        add a,a
        rl c
        djnz .bit
        ld (CopyByte),a
        ld a,c
        pop bc
        ret

; CopyFindArray: the array named at HL. Out: DE = its data, BC = their bytes, HL past the name.
; Illegal function call when there is no such array.
CopyFindArray:
        call GetVariableName            ; C, B = the name, A = the type
        push hl
        ld d,a
        ld hl,(ARYTAB)
.search:
        push de
        ld de,(STREND)
        rst $20                         ; past the last array: there is none
        pop de
        jp nc,IllegalFunction
        ld a,(hl)
        cp d
        jr nz,.next
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.next
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp b
        jr z,.found
.next:
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld a,(hl)
        inc hl
        push de
        ld d,a
        add hl,de                       ; past it
        pop de
        jr .search
.found:
        inc hl                          ; the size after this field
        inc hl
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,(hl)                       ; the subscripts
        inc hl
        dec bc
        ld e,a
        ld d,$00
        add hl,de
        add hl,de                       ; their sizes
        ex de,hl                        ; DE = the data
        ld h,b
        ld l,c
        ld c,a
        ld b,$00
        or a
        sbc hl,bc
        or a
        sbc hl,bc
        ld b,h
        ld c,l                          ; BC = the data's bytes
        pop hl
        ret
