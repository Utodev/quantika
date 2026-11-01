; sub/main.asm: the sub-ROM's own helpers, the calls into the main ROM and the simple entries.

; SubInit: INIT (the free main ROM does not call it; another main ROM may).
SubInit:
        ret

; NotWritten: an entry not written yet: returns with carry clear and A = 0.
NotWritten:
        xor a
        ret

; BasicHandler: the BASIC statement handlers of the original sub-ROM belong to the original BASIC
; (FBASIC has its own): Syntax error through the main ROM's error routine is not reachable from here,
; so they return with carry set and the text untouched.
BasicHandler:
        scf
        ret

; CallMain: call IX in the main ROM (slot 0 here: the BIOS's slot, EXPTBL's first byte). AF, BC, DE, HL
; go to it and come back. Uses the RAM primitive CLPRIM: page 0 changes while it runs from RAM.
CallMain:
        exx
        ex af,af'                       ; the caller's AF in the other set
        in a,(PpiSlotSelect)
        push af                         ; the A8 that CLPRIM puts back after the call
        and $FC
        ld b,a
        ld a,(EXPTBL)
        and $03
        or b
        exx                             ; the caller's BC, DE, HL
        jp CLPRIM

; SubSyntaxCheck: SYNCHR (RST 08h) for the BASIC code that runs here: the character at HL must be the
; byte after the RST (the main ROM's SYNCHR would read it from its own page 0); then CHRGTR.
SubSyntaxCheck:
        ld a,(hl)
        ex (sp),hl
        cp (hl)
        inc hl
        ex (sp),hl
        jp nz,SyntaxError
        jp NextChar

; ReadMain: A = the byte at HL of the main ROM (page 0). Keeps BC, HL.
ReadMain:
        push de
        di
        in a,(PpiSlotSelect)
        ld d,a
        and $FC
        ld e,a
        ld a,(EXPTBL)
        and $03
        or e
        call RDPRIM                     ; E = the byte (RDPRIM runs in RAM)
        ei
        ld a,e
        pop de
        ret

; WriteVdpReg: WRTVDP. C = register, B = value; the copy in the work area.
WriteVdpReg:
        ld a,b
        di
        out (VdpCommand),a
        ld a,c
        or $80
        out (VdpCommand),a
        ei
        push hl
        ld a,c
        ld hl,RG0SAV
        cp $08
        jr c,.store
        ld hl,RG8SAV - $08
        cp $18
        jr c,.store
        ld hl,RG25SAV - $19
        cp $19
        jr c,.done
        cp $1C
        jr nc,.done
.store:
        add a,l
        ld l,a
        ld a,h
        adc a,$00
        ld h,a
        ld (hl),b
.done:
        pop hl
        ret

; VdpStatus: VDPSTA. A = the status register to read (0-9). Out: A.
VdpStatus:
        di
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
        ret

; SetVramAddress: HL = VRAM address (64K, with R#14), A = 40h to write, 0 to read. Destroys AF.
SetVramAddress:
        push bc
        ld c,a
        ld a,h
        rlca
        rlca
        and $03
        di
        ld (RG14SAV),a
        out (VdpCommand),a
        ld a,$8E
        out (VdpCommand),a
        ld a,l
        out (VdpCommand),a
        ld a,h
        and $3F
        or c
        out (VdpCommand),a
        ei
        pop bc
        ret

; WriteVram / ReadVram: WRTVRM / RDVRM with 64K addresses. HL = address, A = byte.
; (the main ROM's 64K VRAM routines, which FBASIC's code here calls, are these: no trip to the main
; ROM for every pixel)
ReadVramBig     equ ReadVram
WriteVramBig    equ WriteVram
SetVramWriteBig:
        ld a,$40
        jr SetVramAddress
WriteVram:
        push af
        ld a,$40
        call SetVramAddress
        pop af
        out (VdpData),a
        ret
ReadVram:
        xor a
        call SetVramAddress
        in a,(VdpData)
        ret

; FillVram: BC bytes A from HL (64K address). Destroys AF, BC.
FillVram:
        push de
        ld d,a
        ld a,$40
        call SetVramAddress
.byte:
        ld a,d
        out (VdpData),a
        dec bc
        ld a,b
        or c
        jr nz,.byte
        pop de
        ret

; GetPattern: GETPAT. A = character: its 8 bytes of the character set CGPNT names to PATWRK (the main
; ROM's FontPattern).
GetPattern:
        jp FontPattern

; NewPad: NEWPAD. No light pen, mouse or track ball here: 0.
NewPad:
        xor a
        ret

; Beep / ShowFunctionKeys / the TMS9918 modes: the main ROM's.
Beep:
        ld ix,MainBeep
        jp CallMain
ShowFunctionKeys:
        ld ix,MainShowKeys
        jp CallMain
InitText:
        ld ix,MainInitText
        jp CallMain
InitText32:
        ld ix,MainInitText32
        jp CallMain
InitGraphic:
        ld ix,MainInitGraphic
        jp CallMain
InitMulticolour:
        ld ix,MainInitMulti
        jp CallMain
SetText:
        ld ix,MainSetText
        jp CallMain
SetText32:
        ld ix,MainSetText32
        jp CallMain
SetGraphic:
        ld ix,MainSetGraphic
        jp CallMain
SetMulticolour:
        ld ix,MainSetMulti
        jp CallMain
ClearText:
        xor a                           ; Z: the main ROM's CLS clears
        ld ix,MainCls
        jp CallMain
