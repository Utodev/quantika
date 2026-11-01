; blit.asm: the sub-ROM's block copies BLTVV, BLTVM, BLTMV (the ones to and from disk need a disk ROM: not
; here). HL = their parameters (the standard puts them at BltSX): SX, SY, DX, DY, NX, NY (2 bytes each),
; CDUMMY, ARG (direction: bit 2 x to the left, bit 3 y upwards), L_OP (the logical operation) - the order of
; the VDP's command registers R#32-R#45.
;   BLTVV: VRAM (SX, SY) to VRAM (DX, DY), NX x NY, with the VDP's LMMM command
;   BLTMV: VRAM (SX, SY), NX x NY, to RAM at DX: NX and NY (2 bytes each) then a byte a pixel
;   BLTVM: RAM at SX (as BLTMV leaves it: its own NX and NY first) to VRAM (DX, DY) with L_OP
; The pixels go one by one (the VDP's POINT and PSET) in BLTMV and BLTVM.

BltSX           equ $F562               ; (the standard's parameter block, inside BUF)
BltL_OP         equ BltSX + 14

; BltVV: BLTVV. Carry clear.
BltVV:
        push hl
        call VdpWaitCommand
        pop hl
        di
        ld a,32
        out (VdpCommand),a
        ld a,$80 + 17                   ; R#17 = 32, increasing
        out (VdpCommand),a
        ld bc,$0E00 + VdpIndirect       ; R#32-R#45
        otir
        ld a,(hl)                       ; L_OP
        and $0F
        or $90                          ; LMMM
        out (VdpIndirect),a
        ei
        call VdpWaitCommand
        or a
        ret

; BltMV: BLTMV. Z.
BltMV:
        push ix
        push hl
        pop ix
        ld e,(ix+4)                     ; DE = the RAM: NX, NY first
        ld d,(ix+5)
        ld a,(ix+8)
        ld (de),a
        inc de
        ld a,(ix+9)
        ld (de),a
        inc de
        ld a,(ix+10)
        ld (de),a
        inc de
        ld a,(ix+11)
        ld (de),a
        inc de
        call BltRows                    ; each pixel: A = it, to (DE)
        pop ix
        xor a
        ret
.pixel:                                 ; (BltRows' callback: BC, HL = x, y)
        push de
        ld d,h
        ld e,l
        call VdpPoint
        pop de
        ld (de),a
        inc de
        ret

; BltVM: BLTVM. Z.
BltVM:
        push ix
        push hl
        pop ix
        ld e,(ix+0)                     ; DE = the RAM: its NX, NY first
        ld d,(ix+1)
        ld a,(de)
        ld (ix+8),a
        inc de
        ld a,(de)
        ld (ix+9),a
        inc de
        ld a,(de)
        ld (ix+10),a
        inc de
        ld a,(de)
        ld (ix+11),a
        inc de
        ld a,(LOGOPR)
        push af
        ld a,(ATRBYT)
        push af
        ld a,(ix+14)
        ld (LOGOPR),a
        ld a,(ix+4)                     ; (SX, SY) := (DX, DY): where the rows go
        ld (ix+0),a
        ld a,(ix+5)
        ld (ix+1),a
        ld a,(ix+6)
        ld (ix+2),a
        ld a,(ix+7)
        ld (ix+3),a
        call BltRowsVM
        pop af
        ld (ATRBYT),a
        pop af
        ld (LOGOPR),a
        pop ix
        xor a
        ret

; BltRows: for each pixel of the NX x NY block at (SX, SY) of the parameters at IX (in ARG's directions),
; BltMV.pixel with BC = x, HL = y. BltRowsVM: the same with BltVM's pixel (from (DE) to the pixel).
; (Y counts the pages itself: ACPAGE is 0 meanwhile.)
BltRows:
        ld hl,BltMV.pixel
        jr BltWalk
BltRowsVM:
        ld hl,BltVmPixel
BltWalk:
        ld (BltCallback),hl
        ld a,(ACPAGE)
        push af
        xor a
        ld (ACPAGE),a
        call .rows
        pop af
        ld (ACPAGE),a
        ret
.rows:
        ld l,(ix+2)                     ; HL = y
        ld h,(ix+3)
        ld c,(ix+10)                    ; NY rows
        ld b,(ix+11)
.row:
        ld a,b
        or c
        ret z
        push bc
        push hl
        ld c,(ix+0)                     ; BC = x
        ld b,(ix+1)
        ld a,(ix+8)                     ; NX pixels
        ld (BltCount),a
        ld a,(ix+9)
        ld (BltCount + 1),a
.pixel:
        push hl
        ld hl,(BltCount)
        ld a,h
        or l
        pop hl
        jr z,.rowDone
        push hl
        ld hl,(BltCount)
        dec hl
        ld (BltCount),hl
        pop hl
        push bc
        push hl
        call .callback
        pop hl
        pop bc
        bit 2,(ix+13)                   ; ARG: x to the left?
        jr nz,.left
        inc bc
        jr .pixel
.left:
        dec bc
        jr .pixel
.rowDone:
        pop hl
        pop bc
        dec bc
        bit 3,(ix+13)                   ; ARG: y upwards?
        jr nz,.up
        inc hl
        jr .row
.up:
        dec hl
        jr .row
.callback:
        push hl
        ld hl,(BltCallback)
        ex (sp),hl
        ret

; BltVmPixel: the byte at (DE) to the pixel BC, HL (with LOGOPR).
BltVmPixel:
        ld a,(de)
        inc de
        ld (ATRBYT),a
        push de
        ld d,h
        ld e,l
        call VdpPset
        pop de
        ret

BltCallback     equ BltSX + 16          ; (work: after the parameters, still inside BUF)
BltCount        equ BltSX + 18
