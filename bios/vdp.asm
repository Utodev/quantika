; vdp.asm: the V9938 primitives of the BIOS and the TMS9918-compatible screen modes (SCREEN 0-3).
; SCREEN 4-8 and 80-column text come from the sub-ROM (stage 2).

; WriteVdpReg: WRTVDP. Write a VDP register and keep its copy in the work area
; (R#0-7 at RG0SAV, R#8-23 at RG8SAV, R#25-27 at RG25SAV). In: C = register, B = value. Destroys AF.
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
        jr c,.noCopy
        cp $1C
        jr nc,.noCopy
.store:
        add a,l
        ld l,a
        ld a,h
        adc a,$00
        ld h,a
        ld (hl),b
.noCopy:
        pop hl
        ret

; ReadVdpStatus: RDVDP. Out: A = status register 0.
ReadVdpStatus:
        in a,(VdpCommand)
        ret

; SetVramWrite: SETWRT. In: HL = VRAM address (14 bits in SCREEN 0-4, 16 bits from SCREEN 5).
; Destroys AF.
SetVramWrite:
        ld a,$40
        jr SetVramAddress

; SetVramRead: SETRD. As SetVramWrite, for reading.
SetVramRead:
        xor a
SetVramAddress:
        push hl
        push af
        ld a,(SCRMOD)
        cp $05
        jr nc,.bigAddress
        res 7,h                         ; the TMS9918 modes see 16K
        res 6,h
.bigAddress:
        pop af
        call SetVramBig
        pop hl
        ret

; SetVramWriteBig / SetVramReadBig: NSTWRT / NSETRD. In: HL = VRAM address (64K, with R#14).
; Destroys AF.
SetVramWriteBig:
        ld a,$40
        jr SetVramBig
SetVramReadBig:
        xor a
; SetVramBig: In: HL = address, A = 40h to write or 0 to read. Destroys AF.
SetVramBig:
        push bc
        ld c,a
        ld a,h
        rlca
        rlca
        and $03                         ; bits 14-15 of the address go to R#14
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

; ReadVram: RDVRM. In: HL = address. Out: A = byte.
ReadVram:
        call SetVramRead
        in a,(VdpData)
        ret

; WriteVram: WRTVRM. In: HL = address, A = byte.
WriteVram:
        push af
        call SetVramWrite
        pop af
        out (VdpData),a
        ret

; ReadVramBig / WriteVramBig: NRDVRM / NWRVRM, with 64K addresses.
ReadVramBig:
        call SetVramReadBig
        in a,(VdpData)
        ret
WriteVramBig:
        push af
        call SetVramWriteBig
        pop af
        out (VdpData),a
        ret

; FillVram: FILVRM. In: HL = address, BC = length, A = byte. Destroys AF, BC.
FillVram:
        push de
        ld d,a
        call SetVramWrite
.next:
        ld a,d
        out (VdpData),a
        dec bc
        ld a,b
        or c
        jr nz,.next
        pop de
        ret

; FillVramBig: BIGFIL. As FillVram with a 64K address.
FillVramBig:
        push de
        ld d,a
        call SetVramWriteBig
        jr FillVram.next

; CopyRamToVram: LDIRVM. In: HL = RAM, DE = VRAM, BC = length. Destroys all.
CopyRamToVram:
        ex de,hl
        call SetVramWrite
        ex de,hl
.next:
        ld a,(hl)
        out (VdpData),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.next
        ret

; CopyVramToRam: LDIRMV. In: HL = VRAM, DE = RAM, BC = length. Destroys all.
CopyVramToRam:
        call SetVramRead
        ex de,hl
.next:
        in a,(VdpData)
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.next
        ret

; DisableScreen / EnableScreen: DISSCR / ENASCR (R#1 bit 6). Destroy AF, BC.
DisableScreen:
        ld a,(RG1SAV)
        and $BF
        jr SetReg1
EnableScreen:
        ld a,(RG1SAV)
        or $40
SetReg1:
        ld b,a
        ld c,$01
        jp WriteVdpReg

; ChangeColours: CHGCLR. R#7: FORCLR and BAKCLR in SCREEN 0, the border colour BDRCLR in the others.
; Destroys AF, BC.
ChangeColours:
        ld a,(SCRMOD)
        or a
        ld a,(BDRCLR)
        jr nz,.write
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
.write:
        ld b,a
        ld c,$07
        jp WriteVdpReg

; ChangeScreenMode: CHGMOD. In: A = screen mode. SCREEN 0-3 here, 4-8 in the sub-ROM.
ChangeScreenMode:
        cp $04
        jr nc,.subRom
        or a
        jp z,InitText40
        dec a
        jp z,InitText32
        dec a
        jp z,InitGraphic
        dec a
        jp z,InitMulticolour
        ret
.subRom:
        push ix
        ld ix,SubRomChangeMode
        call CallSubRomDirect
        pop ix
        ret

; --- The four TMS9918 modes. SETxxx programs the registers from the work area's table addresses,
;     INIxxx also clears the screen and (text modes) loads the character set. ---

; ModeRegisters: R#0 and R#1 for a mode, keeping R#1's sprite size / magnification bits.
; In: B = R#0 mode bits (M3 = 02h), D = R#1 mode bits (M1 = 10h text, M2 = 08h multicolour).
; Destroys AF, BC.
ModeRegisters:
        ld a,(RG0SAV)
        and $F1
        or b
        ld b,a
        ld c,$00
        call WriteVdpReg
        ld a,(RG1SAV)
        and $E7
        or d
        ld b,a
        ld c,$01
        jp WriteVdpReg

; TableRegisters: R#2-R#6 from a table of five addresses in the work area (name, colour, patterns,
; sprite attributes, sprite patterns). In: HL = the work area's table. Destroys AF, BC, DE, HL.
TableRegisters:
        ld e,(hl)                       ; name table: address / 400h
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        rrca
        rrca
        and $3F
        ld b,a
        ld c,$02
        call WriteVdpReg
        ld e,(hl)                       ; colour table: address / 40h
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        add hl,hl
        add hl,hl
        ld a,(SCRMOD)
        cp $02
        ld a,h
        jr nz,.colourDone
        or $7F                          ; SCREEN 2: the table is 6K, the low bits are a mask
.colourDone:
        ld b,a
        ld c,$03
        call WriteVdpReg
        pop hl
        ld e,(hl)                       ; patterns: address / 800h
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        rrca
        rrca
        rrca
        and $1F
        ld b,a
        ld a,(SCRMOD)
        cp $02
        jr nz,.patternDone
        ld a,b
        or $03                          ; SCREEN 2: mask bits
        ld b,a
.patternDone:
        ld c,$04
        call WriteVdpReg
        ld e,(hl)                       ; sprite attributes: address / 80h
        inc hl
        ld d,(hl)
        inc hl
        ld a,e
        rlca
        ld a,d
        rla
        ld b,a
        ld c,$05
        call WriteVdpReg
        ld e,(hl)                       ; sprite patterns: address / 800h
        inc hl
        ld d,(hl)
        ld a,d
        rrca
        rrca
        rrca
        and $1F
        ld b,a
        ld c,$06
        jp WriteVdpReg

; SetText40: SETTXT. Text: 40 columns, or Text 2 (80 columns, patterns at 1000h) when LINL40 is
; above 40.
SetText40:
        xor a
        ld (SCRMOD),a
        ld (OLDSCR),a
        ld a,(LINL40)
        ld (LINLEN),a
        cp 41
        jr nc,.wide
        ld a,(RG0SAV)                   ; the patterns where BASE(2) says (back at 0800h after the
        and $04                         ; 80 columns: Text 2 still on, its patterns at 1000h)
        jr z,.patterns
        ld hl,$0800
        ld (TXTCGP),hl
.patterns:
        ld b,$00
        ld d,$10
        call ModeRegisters
        ld hl,TXTNAM
        call TableRegisters
        jp ChangeColours
.wide:
        ld hl,$1000
        ld (TXTCGP),hl
        ld b,$04                        ; M4: Text 2
        ld d,$10
        call ModeRegisters
        ld a,(TXTNAM + 1)
        rrca
        rrca
        or $03
        ld b,a
        ld c,$02
        call WriteVdpReg
        ld bc,$2F03                     ; blink table at 0A00h
        call WriteVdpReg
        ld bc,$000A
        call WriteVdpReg
        ld bc,$0204                     ; patterns at 1000h
        call WriteVdpReg
        ld bc,$000D                     ; no blinking
        call WriteVdpReg
        jp ChangeColours

; SetText32: SETT32. 32 x 24 text with sprites (SCREEN 1).
SetText32:
        ld a,$01
        ld (SCRMOD),a
        ld (OLDSCR),a
        ld a,(LINL32)
        ld (LINLEN),a
        ld b,$00
        ld d,$00
        call ModeRegisters
        ld hl,T32NAM
        call TableRegisters
        jp ChangeColours

; SetGraphic: SETGRP. 256 x 192 graphics (SCREEN 2).
SetGraphic:
        ld a,$02
        ld (SCRMOD),a
        ld b,$02
        ld d,$00
        call ModeRegisters
        ld hl,GRPNAM
        call TableRegisters
        jp ChangeColours

; SetMulticolour: SETMLT. 64 x 48 blocks (SCREEN 3).
SetMulticolour:
        ld a,$03
        ld (SCRMOD),a
        ld b,$00
        ld d,$08
        call ModeRegisters
        ld hl,MLTNAM
        call TableRegisters
        jp ChangeColours

; InitText40: INITXT. SCREEN 0 with the screen cleared and the character set loaded.
InitText40:
        call DisableScreen
        call SetText40
        ld hl,(TXTCGP)
        call LoadFont
        call ClearTextScreen
        jp EnableScreen

; InitText32: INIT32. SCREEN 1: characters, colours, sprites.
InitText32:
        call DisableScreen
        call SetText32
        ld hl,(T32CGP)
        call LoadFont
        ld a,(FORCLR)                   ; the 32 colour groups
        rlca
        rlca
        rlca
        rlca
        and $F0
        ld b,a
        ld a,(BAKCLR)
        and $0F
        or b
        ld hl,(T32COL)
        ld bc,$0020
        call FillVram
        call ClearTextScreen
        call ClearSprites
        jp EnableScreen

; InitGraphic: INIGRP. SCREEN 2: the name table holds 0-255 three times, patterns clear.
InitGraphic:
        call DisableScreen
        call SetGraphic
        ld hl,(GRPNAM)
        call SetVramWrite
        ld b,$03
.third:
        xor a
.cell:
        out (VdpData),a
        inc a
        jr nz,.cell
        djnz .third
        call ClearGraphic
        call ClearSprites
        jp EnableScreen

; InitMulticolour: INIMLT. SCREEN 3: each band of four rows shows the same 32 names.
InitMulticolour:
        call DisableScreen
        call SetMulticolour
        ld hl,(MLTNAM)
        call SetVramWrite
        ld c,$00                        ; C = first name of the band
.band:
        ld d,$04
.row:
        ld a,c
        ld b,$20
.column:
        out (VdpData),a
        inc a
        djnz .column
        dec d
        jr nz,.row
        ld a,c
        add a,$20
        ld c,a
        cp $C0
        jr c,.band
        ld hl,(MLTCGP)
        ld bc,$0600
        xor a
        call FillVram
        call ClearSprites
        jp EnableScreen

; ClearGraphic: SCREEN 2 patterns to 0 and colours to BAKCLR (on colour 0, as the original: a dot set
; later gives its byte the foreground colour).
ClearGraphic:
        ld hl,(GRPCGP)
        ld bc,$1800
        xor a
        call FillVram
        ld a,(BAKCLR)
        and $0F
        ld hl,(GRPCOL)
        ld bc,$1800
        jp FillVram

; LoadFont: the character set (FontData, 2K) to VRAM. In: HL = pattern table. Destroys all.
LoadFont:
        ex de,hl
        ld hl,FontData
        ld bc,$0800
        jp CopyRamToVram

; ClearSprites: CLRSPR. Sprite patterns to 0, every sprite off the screen with pattern n (or 4n for
; 16 x 16 sprites) and the foreground colour. Destroys all.
ClearSprites:
        ld a,(SCRMOD)                   ; SCREEN 4-8: the sub-ROM's CLRSPR
        cp $04
        jr c,.tms
        push ix
        ld ix,SubRomClearSprites
        call CallSubRomDirect
        pop ix
        ret
.tms:
        call SpriteTables
        push de
        ld bc,$0800
        xor a
        call FillVram                   ; HL = patterns
        pop hl
        call SetVramWrite               ; attributes
        ld a,(RG1SAV)
        and $02
        ld c,$01
        jr z,.step
        ld c,$04
.step:
        ld a,(FORCLR)
        and $0F
        ld e,a
        ld b,$20
        ld d,$00                        ; D = pattern number
.sprite:
        ld a,$D1                        ; below the last line
        out (VdpData),a
        xor a
        out (VdpData),a
        ld a,d
        out (VdpData),a
        add a,c
        ld d,a
        ld a,e
        out (VdpData),a
        djnz .sprite
        ret

; SpriteTables: HL = sprite pattern table, DE = sprite attribute table of the current mode (SCREEN 1-3).
SpriteTables:
        ld a,(SCRMOD)
        ld hl,T32PAT
        ld de,T32ATR
        dec a
        jr z,.got
        ld hl,GRPPAT
        ld de,GRPATR
        dec a
        jr z,.got
        ld hl,MLTPAT
        ld de,MLTATR
.got:
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        ld d,a
        ld e,c
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; SpritePatternAddr: CALPAT. In: A = sprite pattern number. Out: HL = its VRAM address. Destroys AF, DE.
SpritePatternAddr:
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        call SpriteSize
        cp $08
        jr z,.small
        add hl,hl                       ; 16 x 16: patterns of 32 bytes
        add hl,hl
.small:
        push hl
        call SpriteTables
        pop de
        add hl,de
        ret

; SpriteAttributeAddr: CALATR. In: A = sprite number. Out: HL = its attributes. Destroys AF, DE.
SpriteAttributeAddr:
        push af
        call SpriteTables
        pop af
        ex de,hl
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,de
        ret

; SpriteSize: GSPSIZ. Out: A = 8 or 32 (bytes per pattern), carry set for 16 x 16 sprites.
SpriteSize:
        ld a,(RG1SAV)
        and $02
        ld a,$08
        ret z
        ld a,$20
        scf
        ret

; IsNewScreenMode: CHKNEW. Carry set when the screen mode is 0-4 (the TMS9918-like ones).
IsNewScreenMode:
        ld a,(SCRMOD)
        cp $05
        ret

; SetDefaultPalette: the 16 colours of the standard (those of the TMS9918) in the V9938's palette.
; Destroys AF, BC, HL.
SetDefaultPalette:
        ld bc,$0010                     ; R#16 = colour 0
        call WriteVdpReg
        ld hl,DefaultPalette
        ld b,$20
        ld c,VdpPalette
        di
        otir
        ei
        ret

; Two bytes per colour: red * 16 + blue, then green (levels 0-7)
DefaultPalette:
        db $00,$00, $00,$00, $11,$06, $33,$07, $17,$01, $27,$03, $51,$01, $27,$06
        db $71,$01, $73,$03, $61,$06, $64,$06, $11,$04, $65,$02, $55,$05, $77,$07
