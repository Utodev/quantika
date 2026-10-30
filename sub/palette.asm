; sub/palette.asm: the 16 colours. The VDP's palette cannot be read, so its copy lives in VRAM (as
; programs that load a picture with its palette expect): at 7680h in SCREEN 5-6, FA80h in 7-8, and
; 1B80h in the others (a free part of their tables). 2 bytes a colour: red * 16 + blue, green.

; PaletteTable: HL = the copy's address in VRAM for the current mode.
PaletteTable:
        ld a,(SCRMOD)
        ld hl,$1B80
        cp $05
        ret c
        ld hl,$7680
        cp $07
        ret c
        ld hl,$FA80
        ret

DefaultColours:                         ; the standard's 16 colours (as the TMS9918's)
        db $00,$00, $00,$00, $11,$06, $33,$07, $17,$01, $27,$03, $51,$01, $27,$06
        db $71,$01, $73,$03, $61,$06, $64,$06, $11,$04, $65,$02, $55,$05, $77,$07

; InitPalette: INIPLT. The default colours in the VDP and in the copy.
InitPalette:
        call PaletteTable
        ld a,$40
        call SetVramAddress
        ld hl,DefaultColours
        ld b,32
.copy:
        ld a,(hl)
        out (VdpData),a
        inc hl
        djnz .copy
        ld hl,DefaultColours
        jr LoadPalette

; RestorePalette: RSTPLT. The copy in VRAM back into the VDP.
RestorePalette:
        call PaletteTable
        xor a
        call SetVramAddress
        ld hl,PATWRK - 32               ; (read into a buffer first: 32 bytes of LINWRK / PATWRK)
        push hl
        ld b,32
.read:
        in a,(VdpData)
        ld (hl),a
        inc hl
        djnz .read
        pop hl
; LoadPalette: the 32 bytes at HL into the VDP's palette.
LoadPalette:
        ld bc,$0010                     ; R#16 = colour 0
        call WriteVdpReg
        ld b,32
        ld c,VdpPalette
        di
        otir
        ei
        ret

; GetPalette: GETPLT. A = colour. Out: B = red * 16 + blue, C = green.
GetPalette:
        and $0F
        add a,a
        ld e,a
        ld d,$00
        call PaletteTable
        add hl,de
        call ReadVram
        ld b,a
        inc hl
        push bc
        call ReadVram
        pop bc
        ld c,a
        ret

; SetPalette: SETPLT. D = colour, A = red * 16 + blue, E = green.
SetPalette:
        push af
        ld a,d
        and $0F
        ld b,a
        ld c,$10
        call WriteVdpReg
        pop af
        di
        out (VdpPalette),a
        push af
        ld a,e
        out (VdpPalette),a
        ei
        ld a,d                          ; and the copy
        and $0F
        add a,a
        ld c,a
        ld b,$00
        call PaletteTable
        add hl,bc
        pop af
        call WriteVram
        inc hl
        ld a,e
        jp WriteVram
