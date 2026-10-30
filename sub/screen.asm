; sub/screen.asm: CHGMOD for SCREEN 4-8 (0-3 are the main ROM's), CLS, the sprites, the colours, the page.
; The registers of each mode are the standard's tables (the values the original leaves, compared by
; tests/modes.asm): SCREEN 4 Graphic 3 (tables as SCREEN 2, sprites at 1E00h / 3800h), 5 and 6 bitmaps
; with sprites at 7600h / 7800h, 7 and 8 bitmaps of 64K with sprites at FA00h / F000h.

; Registers of SCREEN 4-8: R#0, R#2, R#5, R#6, R#9, R#11 (and R#3 / R#4 / R#10 for SCREEN 4 below)
ModeRegisters:
        db $04, $06, $3F, $07, $02, $00 ; 4
        db $06, $1F, $EF, $0F, $82, $00 ; 5
        db $08, $1F, $EF, $0F, $82, $00 ; 6
        db $0A, $1F, $F7, $1E, $82, $01 ; 7
        db $0E, $1F, $F7, $1E, $82, $01 ; 8
ModeRegisterNumbers:
        db 0, 2, 5, 6, 9, 11

; ChangeMode: CHGMOD. A = screen mode.
ChangeMode:
        cp $04
        jr nc,.new
        ld ix,MainChangeMode            ; 0-3: the main ROM
        jp CallMain
.new:
        cp $09
        ret nc
        ld (SCRMOD),a
        push af
        ld a,(RG1SAV)                   ; the picture off while the tables change
        and $BF
        ld b,a
        ld c,$01
        call WriteVdpReg
        pop af
        sub $04
        ld e,a
        add a,a
        add a,e
        add a,a                         ; * 6
        ld e,a
        ld d,$00
        ld hl,ModeRegisters
        add hl,de
        ld de,ModeRegisterNumbers
        ld b,$06
.register:
        push bc
        ld a,(de)
        ld c,a
        ld b,(hl)
        call WriteVdpReg
        inc hl
        inc de
        pop bc
        djnz .register
        ld a,(RG1SAV)                   ; R#1: Graphic modes (M1, M2 off), the sprite size kept
        and $83
        or $20
        ld b,a
        ld c,$01
        call WriteVdpReg
        ld bc,$0808                     ; R#8: VRAM type, sprites on
        call WriteVdpReg
        ld a,(SCRMOD)
        cp $04
        jr nz,.notGraphic3
        ld bc,$FF03                     ; SCREEN 4: colour table 2000h, patterns 0000h
        call WriteVdpReg
        ld bc,$0304
        call WriteVdpReg
        ld bc,$000A
        call WriteVdpReg
        ld hl,(GRPNAM)                  ; the names 0-255 three times
        ld a,$40
        call SetVramAddress
        ld b,$03
.third:
        xor a
.name:
        out (VdpData),a
        inc a
        jr nz,.name
        djnz .third
.notGraphic3:
        call ChangeColours
        call ClearSprites
        xor a
        call ClearScreen
        ld a,(RG1SAV)                   ; the picture on
        or $40
        ld b,a
        ld c,$01
        jp WriteVdpReg

; ChangeModePalette: CHGMDP: CHGMOD and the palette to its default.
ChangeModePalette:
        call ChangeMode
        jp InitPalette

; ClearScreen: CLS. SCREEN 0-3 the main ROM's; 4 as SCREEN 2; 5-8 the active page to the background
; colour with the VDP's HMMV command.
ClearScreen:
        ld a,(SCRMOD)
        cp $04
        jr nc,.new
        xor a                           ; (Z: the main ROM's CLS clears)
        ld ix,MainCls
        jp CallMain
.new:
        jr nz,.bitmap
        ld hl,(GRPCGP)                  ; SCREEN 4: patterns 0, colours the background (on colour 0,
        ld bc,$1800                     ; as SCREEN 2)
        xor a
        call FillVram
        ld a,(BAKCLR)
        and $0F
        ld hl,(GRPCOL)
        ld bc,$1800
        jp FillVram
.bitmap:
        call WaitCommand
        ld a,(BAKCLR)                   ; the colour byte: a pixel's colour in every pixel of the byte
        ld e,a
        ld a,(SCRMOD)
        cp $08
        jr z,.colourByte                ; SCREEN 8: the colour is the byte
        cp $06
        ld a,e
        jr z,.twoBits
        and $0F
        ld e,a
        rlca
        rlca
        rlca
        rlca
        or e
        jr .byteDone
.twoBits:                               ; (SCREEN 6: bits 1-0 OR bits 3-2 of the colour, as the
        ld e,a                          ; original; BASIC's COLOR keeps (c AND 3) * 5 there)
        rrca
        rrca
        or e
        and $03
        ld e,a
        rlca
        rlca
        or e
        ld e,a
        rlca
        rlca
        rlca
        rlca
        or e
.byteDone:
        ld e,a
.colourByte:
        ld a,(SCRMOD)                   ; the width: 512 in SCREEN 6 and 7
        ld hl,256
        cp $06
        jr c,.width
        cp $08
        jr z,.width
        ld hl,512
.width:
        ld a,(ACPAGE)
        ld d,a
        di
        ld a,36                         ; R#36-R#46: DX, DY, NX, NY, CLR, ARG, CMD
        out (VdpCommand),a
        ld a,$80 + 17
        out (VdpCommand),a
        ld c,VdpIndirect
        xor a
        out (c),a                       ; DX = 0
        out (c),a
        out (c),a                       ; DY = the page * 256
        out (c),d
        out (c),l                       ; NX
        out (c),h
        ld a,212                        ; NY
        out (c),a
        xor a
        out (c),a
        out (c),e                       ; CLR
        out (c),a                       ; ARG
        ld a,$C0                        ; HMMV
        out (c),a
        ei
        ret

; WaitCommand: until the VDP has finished its command.
WaitCommand:
        ld a,$02
        call VdpStatus
        rrca
        jr c,WaitCommand
        ret

; SpriteTables: HL = the sprite patterns, DE = the attributes of the current mode.
SpriteTables:
        ld a,(RG6SAV)
        and $3F
        add a,a
        add a,a
        add a,a
        ld h,a
        ld l,$00
        push hl
        ld a,(SCRMOD)
        cp $04
        ld a,(RG5SAV)
        jr c,.tms
        and $FC
.tms:
        ld l,a
        ld a,(RG11SAV)
        and $03
        ld h,a
        add hl,hl                       ; (R#11 R#5) * 80h
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ex de,hl
        pop hl
        ret

; ClearSprites: CLRSPR. Patterns to 0; every sprite off the screen (Y 217 in sprite mode 2, 209
; before), pattern n (4n for 16 x 16), the foreground colour.
ClearSprites:
        ld a,(SCRMOD)
        cp $04
        jr nc,.new
        ld ix,MainClearSprites
        jp CallMain
.new:
        call SpriteTables
        push de
        ld bc,$0800
        xor a
        call FillVram
        pop hl
        push hl
        ld a,$40
        call SetVramAddress
        ld a,(RG1SAV)
        and $02
        ld c,$01
        jr z,.step
        ld c,$04
.step:
        ld b,32
        ld d,$00
.sprite:
        ld a,217
        out (VdpData),a
        xor a
        out (VdpData),a
        ld a,d
        out (VdpData),a
        add a,c
        ld d,a
        ld a,(FORCLR)                   ; (not used by these sprites: the original writes it too)
        out (VdpData),a
        djnz .sprite
        pop hl                          ; the colours: 200h under the attributes, 16 lines a sprite
        ld de,-$0200
        add hl,de
        ld bc,$0200
        ld a,(FORCLR)                   ; (the whole byte, as the original)
        jp FillVram

; SpritePattern / SpriteAttribute / SpriteSize: CALPAT / CALATR / GSPSIZ for any mode.
SpritePattern:
        push af
        call SpriteSize
        pop af
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        jr nc,.small                    ; (SpriteSize's carry: 16 x 16)
.small:
        ld a,(RG1SAV)
        and $02
        jr z,.got
        add hl,hl
        add hl,hl
.got:
        push hl
        call SpriteTables
        pop de
        add hl,de
        ret
SpriteAttribute:
        push af
        call SpriteTables
        pop af
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,de
        ret
SpriteSize:
        ld a,(RG1SAV)
        and $02
        ld a,$08
        ret z
        ld a,$20
        scf
        ret

; ChangeColours: CHGCLR. R#7: foreground and background in SCREEN 0, the border in the others (a whole
; byte in SCREEN 8).
ChangeColours:
        ld a,(SCRMOD)
        or a
        jr nz,.notText
        ld a,(FORCLR)
        rlca
        rlca
        rlca
        rlca
        and $F0
        ld b,a
        ld a,(BAKCLR)
        and $0F
        or b
        jr .write
.notText:
        cp $08
        ld a,(BDRCLR)
        jr z,.write
; (SCREEN 6: as the others: the original writes the border colour as it is)
        and $0F
.write:
        ld b,a
        ld c,$07
        jp WriteVdpReg

; SetPage: SETPAG. The displayed page DPPAGE (R#2's page bits); ACPAGE is the page drawn on.
SetPage:
        ld a,(SCRMOD)
        cp $05
        ret c
        ld a,(DPPAGE)
        and $03
        rrca
        rrca
        rrca                            ; page << 5
        or $1F
        ld b,a
        ld c,$02
        jp WriteVdpReg
