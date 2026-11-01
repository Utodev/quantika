; print.asm: output (OUTDO), PRINT, and the statements of the screen and of memory.

; PrintString: the zero ended text at HL. Out: HL past it. Destroys AF.
PrintString:
        ld a,(hl)
        inc hl
        or a
        ret z
        rst $18
        jr PrintString

; NewLineIfNeeded: a new line unless the cursor is at the start of one.
NewLineIfNeeded:
        ld a,(PRTFLG)
        or a
        jr nz,.printer
        ld a,(CSRX)
        dec a
        ret z
        jp PrintCrLf
.printer:
        ld a,(LPTPOS)
        or a
        ret z
        jp PrintCrLf

; PrintUnsigned: the number HL (0-65535) in decimal. Destroys all.
PrintUnsigned:
        ld de,FBUFFR
        call PutUnsigned
        ld (hl),$00
        ld hl,FBUFFR
        jr PrintString

; Ready: the Ok prompt and the direct mode (see main.asm for the loop).

; --- PRINT ---

; StatementPrint: PRINT / ? [items] (; and , between them; TAB( and SPC( ).
StatementLprint:
        ld a,$01
        ld (PRTFLG),a
        call ThisChar
        call StatementPrintItems
        xor a
        ld (PRTFLG),a
        ret
StatementPrint:
        cp '#'
        jr nz,StatementPrintItems
        call FileForOutput              ; PRINT # n, ...: PTRFIL (basic/files.asm)
        call ThisChar
        call StatementPrintItems
        push hl
        ld hl,$0000
        ld (PTRFIL),hl
        pop hl
        ret
StatementPrintItems:
        cp TkUsing
        jp z,PrintUsing                 ; (in the sub-ROM)
        ld c,$00                        ; C = 0: a new line at the end
.item:
        call AtStatementEnd
        jp z,.end
        cp ';'
        jr z,.semicolon
        cp ','
        jr z,.comma
        cp TkTabParen
        jr z,.tab
        cp TkSpcParen
        jr z,.spc
        call EvalExpression
        push hl
        ld a,(VALTYP)
        cp TypeString
        jr z,.string
        xor a
        call FormatNumber               ; HL = the text
        push hl                         ; it goes to a new line if it does not fit in this one (the
        ld b,$00                        ; space after it does not count, as the original)
.length:
        ld a,(hl)
        or a
        jr z,.counted
        inc hl
        inc b
        jr .length
.counted:
        call FitsInLine
        pop hl
        call PrintString
        ld a,' '
        rst $18
        jr .printed
.string:
        call StringOperand              ; B = length, DE = characters
        ex de,hl
        ld a,b
        or a
        jr z,.printed
.char:
        ld a,(hl)
        rst $18
        inc hl
        djnz .char
.printed:
        pop hl
        ld c,$00
        jr .item
.semicolon:
        ld c,$01
        rst $10
        jr .item
.comma:
        ld c,$01
        push hl
        call NextZone
        pop hl
        rst $10
        jr .item
.tab:
        rst $10
        call EvalByte
        push af
        call CloseBracket
        pop af
        push hl
        ld b,a                          ; to column A (from 0): spaces while before it
.tabSpace:
        call CurrentColumn
        cp b
        jr nc,.tabDone
        ld a,' '
        rst $18
        jr .tabSpace
.tabDone:
        pop hl
        ld c,$01
        jr .item
.spc:
        rst $10
        call EvalByte
        push af
        call CloseBracket
        pop af
        or a
        jr z,.spcDone
        ld b,a
.spcSpace:
        ld a,' '
        rst $18
        djnz .spcSpace
.spcDone:
        ld c,$01
        jp .item
.end:
        ld a,c
        or a
        call z,PrintCrLf
        ret

; CurrentColumn: A = the column of the output (from 0).
CurrentColumn:
        push hl                         ; a file's own column
        ld hl,(PTRFIL)
        ld a,h
        or l
        jr z,.notFile
        ld a,FileColumn
        add a,l
        ld l,a
        jr nc,.column
        inc h
.column:
        ld a,(hl)
        pop hl
        ret
.notFile:
        pop hl
        ld a,(PRTFLG)
        or a
        ld a,(LPTPOS)
        ret nz
        ld a,(CSRX)
        dec a
        ret

; FitsInLine: a new line first when B characters do not fit in what is left of the screen line.
; Keeps BC, HL.
FitsInLine:
        push hl                         ; (a file has no line length)
        ld hl,(PTRFIL)
        ld a,h
        or l
        pop hl
        ret nz
        ld a,(PRTFLG)
        or a
        ret nz
        call CurrentColumn
        or a
        ret z                           ; at the start of the line: as it is
        add a,b
        ld e,a
        ld a,(LINLEN)
        cp e
        ret nc
        jp PrintCrLf

; NextZone: the comma of PRINT: to the next zone of 14 columns, or a new line past CLMLST.
NextZone:
        call CurrentColumn
        ld b,a
        ld a,(CLMLST)
        dec a
        cp b
        jp c,PrintCrLf
.space:
        ld a,' '
        rst $18
        call CurrentColumn
.zone:
        sub 14
        jr z,.done
        jr nc,.zone
        jr .space
.done:
        ret

; --- screen statements ---

; StatementCls: CLS.
StatementCls:
        push hl
        xor a                           ; (Z for the BIOS CLS)
        call ClearScreen
        pop hl
        ret

; StatementLocate: LOCATE [x] [, [y] [, cursor]].
StatementLocate:
        ld a,(CSRX)
        dec a
        ld d,a
        ld a,(CSRY)
        dec a
        ld e,a
        call ThisChar
        cp ','
        jr z,.noX
        push de
        call EvalByte
        pop de
        ld d,a
.noX:
        call ThisChar
        cp ','
        jr nz,.position
        rst $10
        cp ','
        jr z,.noY
        push de
        call EvalByte
        pop de
        ld e,a
.noY:
        call ThisChar
        cp ','
        jr nz,.position
        rst $10
        push de
        call EvalByte
        pop de
        ld (CSRSW),a
.position:
        push hl
        ld h,d
        ld l,e
        inc h
        inc l
        push hl
        call EraseCursor
        pop hl
        call MoveCursorClipped
        ld a,(CSRSW)
        or a
        call nz,DrawCursor
        pop hl
        ret

; StatementWidth: WIDTH n (1-40 in SCREEN 0 (80 with Text 2), 1-32 in SCREEN 1).
StatementWidth:
        call EvalByte
        or a
        jp z,IllegalFunction
        push hl
        ld b,a
        ld a,(SCRMOD)
        cp $01
        jr z,.screen1
        jp nc,IllegalFunction
        ld a,b
        cp 81
        jp nc,IllegalFunction
        ld (LINL40),a
        call InitText40
        jr .done
.screen1:
        ld a,b
        cp 33
        jp nc,IllegalFunction
        ld (LINL32),a
        call InitText32
.done:
        pop hl
        ret

; ScreenSixColour: in SCREEN 6 a colour is kept as its 2 bits twice (1: 5, 3: 15), as the original's
; COLOR does. A = the colour. Keeps BC, DE, HL.
ScreenSixColour:
        push bc
        ld b,a
        ld a,(SCRMOD)
        cp $06
        ld a,b
        jr nz,.done
        and $03
        ld b,a
        add a,a
        add a,a
        add a,b
.done:
        pop bc
        ret

; StatementColor: COLOR [foreground] [, [background] [, border]].
StatementColor:
        cp TkEqual
        jp z,StatementColorPalette
        ld de,FORCLR
        ld b,$03
.colour:
        call ThisChar
        cp ','
        jr z,.skip
        call AtStatementEnd
        jr z,.set
        push bc
        push de
        call EvalByte
        pop de
        pop bc
        cp 16
        jp nc,IllegalFunction
        call ScreenSixColour
        ld (de),a
        call ThisChar
        cp ','
        jr nz,.set
.skip:
        inc de
        rst $10
        djnz .colour
.set:
        ld a,(FORCLR)                   ; (the colour of the graphic statements too)
        ld (ATRBYT),a
        push hl
        call ChangeColours
        pop hl
        ret

; StatementScreen: SCREEN [mode 0-8] [, sprite size] [, key click] [, cassette 1 (1200 baud) or 2 (2400)]
; [, printer (0: one of the standard, NTSTDP)] [, interlace 0-3 (R#9's bit 3 IL, bit 2 EO)].
StatementScreen:
        call ThisChar
        cp ','
        jr z,.skipMode
        call EvalByte
        cp 9
        jp nc,IllegalFunction
        push hl
        call ChangeScreenMode
        pop hl
.skipMode:
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.skipSize
        call EvalByte                   ; sprite size: 0 8x8, 1 8x8 doubled, 2 16x16, 3 16x16 doubled
        cp 4
        jp nc,IllegalFunction
        push hl
        ld e,a
        ld a,(RG1SAV)
        and $FC
        or e
        ld b,a
        ld c,$01
        call WriteVdpReg
        call ClearSprites
        pop hl
.skipSize:
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.skipClick
        call EvalByte                   ; key click
        ld (CLIKSW),a
.skipClick:
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.skipBaud
        call EvalByte                   ; the cassette's speed: 1 or 2
        dec a
        cp $02
        jp nc,IllegalFunction
        inc a
        push hl
        call SelectBaud
        pop hl
.skipBaud:
        call ThisChar
        cp ','
        ret nz
        rst $10
        cp ','
        jr z,.skipPrinter
        call EvalByte                   ; the printer
        ld (NTSTDP),a
.skipPrinter:
        call ThisChar
        cp ','
        ret nz
        rst $10
        call EvalByte                   ; the interlace (0-3): bit 0 to IL (bit 3), bit 1 to EO (bit 2)
        cp $04
        jp nc,IllegalFunction
        ld e,$00
        bit 0,a
        jr z,.noInterlace
        set 3,e
.noInterlace:
        bit 1,a
        jr z,.noEvenOdd
        set 2,e
.noEvenOdd:
        ld a,(RG9SAV)
        and $F3
        or e
        ld b,a
        ld c,$09
        push hl
        call WriteVdpReg
        pop hl
        ret

; StatementKey: KEY ON, KEY OFF, KEY LIST, KEY n, text.
StatementKey:
        cp '('
        jp z,KeyTrapState               ; KEY(n) ON / OFF / STOP
        cp TkOn
        jr z,.on
        cp TkOff
        jr z,.off
        cp TkList
        jr z,.list
        call EvalByte                   ; KEY n, "text"
        dec a
        cp 10
        jp nc,IllegalFunction
        push af
        call Comma
        call EvalExpression
        push hl
        call StringOperand              ; B, DE
        pop hl
        pop af
        push hl
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,FNKSTR
        add hl,de
        pop de
        ld a,b
        cp 16
        jr c,.fits
        ld b,15
.fits:
        ex de,hl
        ld a,b
        or a
        jr z,.copied
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
.copied:
        xor a
        ld (de),a
        call FunctionKeysIfOn
        pop hl
        ret
.on:
        rst $10
        push hl
        call ShowFunctionKeys
        pop hl
        ret
.off:
        rst $10
        push hl
        call HideFunctionKeys
        pop hl
        ret
.list:
        rst $10
        push hl
        ld hl,FNKSTR
        ld b,10
.listKey:
        push bc
        push hl
        ld b,16
.listChar:
        ld a,(hl)
        or a
        jr z,.listEnd
        cp $20
        jr nc,.show
        ld a,' '
.show:
        rst $18
        inc hl
        djnz .listChar
.listEnd:
        call PrintCrLf
        pop hl
        ld de,16
        add hl,de
        pop bc
        djnz .listKey
        pop hl
        ret

; StatementBeep: BEEP.
StatementBeep:
        push hl
        call Beep
        pop hl
        ret

; --- memory and ports ---

; StatementPoke: POKE address, value.
StatementPoke:
        call EvalAddress
        push de
        call Comma
        call EvalByte
        pop de
        ld (de),a
        ret

; StatementVpoke: VPOKE address, value.
StatementVpoke:
        call EvalAddress
        push de
        call Comma
        call EvalByte
        pop de
        push hl
        ex de,hl
        call WriteVramBig
        pop hl
        jp VramBankZero

; StatementOut: OUT port, value.
StatementOut:
        call EvalAddress
        push de
        call Comma
        call EvalByte
        pop bc
        out (c),a
        ret

; StatementWait: WAIT port, and [, xor]: waits until (IN(port) XOR xor) AND and is not 0.
StatementWait:
        call EvalAddress
        push de
        call Comma
        call EvalByte
        ld d,a                          ; D = and
        ld e,$00
        call ThisChar
        cp ','
        jr nz,.wait
        rst $10
        push de
        call EvalByte
        pop de
        ld e,a
.wait:
        pop bc
.loop:
        in a,(c)
        xor e
        and d
        jr z,.loop
        ret

; StatementTron / StatementTroff.
StatementTron:
        ld a,$FF
        ld (TRCFLG),a
        ret
StatementTroff:
        xor a
        ld (TRCFLG),a
        ret
