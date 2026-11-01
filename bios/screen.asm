; screen.asm: the text console of SCREEN 0 (40 or 80 columns) and SCREEN 1: CHPUT with its control
; codes and escape sequences, the cursor, scrolling, the function key line, CLS and POSIT.
; The cursor position is CSRX / CSRY (from 1). The text area is LINLEN columns wide, centred in the
; name table's row. ESCCNT holds the state of an escape sequence in bits 0-6 (the values are this
; BIOS's own) and, in bit 7, whether the cursor is drawn; the character under it is kept in CODSAV.

; Escape states in ESCCNT
EscNone         equ 0
EscGraphic      equ 1                   ; after 01h: the next code minus 40h is a graphic character
EscStart        equ 2                   ; after 1Bh
EscRow          equ 3                   ; ESC Y: the row comes next
EscCursorOff    equ 4                   ; ESC x: '4' block cursor, '5' cursor hidden
EscCursorOn     equ 5                   ; ESC y: '4' underline cursor, '5' cursor shown
EscColumn       equ $40                 ; ESC Y row: the column comes next (row in bits 0-5)
CursorDrawn     equ 7                   ; bit of ESCCNT

; PutChar: CHPUT. In: A = character or control code. Preserves all.
PutChar:
        push hl
        push de
        push bc
        push af
        call H_CHPU
        ld a,(SCRMOD)
        cp $02
        jr nc,.done                     ; graphic modes: the console is not shown
        call EraseCursor
        pop af
        push af
        call ConsoleOutput
        ld a,(CSRSW)
        or a
        call nz,DrawCursor
.done:
        pop af
        pop bc
        pop de
        pop hl
        ret

; ConsoleOutput: one code to the console. In: A. Destroys all.
ConsoleOutput:
        ld c,a
        ld a,(ESCCNT)
        and $7F
        jp nz,EscapeState
        ld a,c
        cp $20
        jr c,ControlCode
PrintCode:                              ; C = character to show
        ld hl,(CSRY)
        call CellAddress
        ld a,c
        call WriteVram
        ld a,(LINLEN)
        ld b,a
        ld a,(CSRX)
        cp b
        jr nc,.wrap
        inc a
        ld (CSRX),a
        ret
.wrap:
        ld a,(CSRY)                     ; the logical line goes on in the next row
        call LineTermAddress
        ld (hl),$00
        ld a,$01
        ld (CSRX),a
        jp CursorDownScroll

ControlCode:
        ld hl,ControlTable
.find:
        ld a,(hl)
        inc hl
        or a
        ret z                           ; not a control code of the console: ignored
        cp c
        jr z,.found
        inc hl
        inc hl
        jr .find
.found:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

ControlTable:
        db $01 : dw StartGraphic
        db $07 : dw Beep
        db $08 : dw CursorBack
        db $09 : dw Tabulate
        db $0A : dw CursorDownScroll
        db $0B : dw CursorHome
        db $0C : dw ClearConsole
        db $0D : dw CarriageReturn
        db $1B : dw StartEscape
        db $1C : dw CursorRight
        db $1D : dw CursorLeft
        db $1E : dw CursorUp
        db $1F : dw CursorDown
        db 0

StartGraphic:
        ld a,EscGraphic
        jr SetEscState
StartEscape:
        ld a,EscStart
SetEscState:
        ld b,a
        ld a,(ESCCNT)
        and $80
        or b
        ld (ESCCNT),a
        ret

EscapeState:                            ; A = state, C = code
        cp EscGraphic
        jr nz,.notGraphic
        call EndEscape
        ld a,c
        sub $40
        ld c,a
        jp PrintCode
.notGraphic:
        cp EscStart
        jr z,EscapeCommand
        cp EscRow
        jr nz,.notRow
        ld a,c
        sub $1F                         ; row + 20h -> row from 1
        and $3F
        or EscColumn
        jr SetEscState
.notRow:
        cp EscCursorOff
        jr z,.cursorOff
        cp EscCursorOn
        jr z,.cursorOn
        ; EscColumn + row
        and $3F
        ld l,a
        ld a,c
        sub $1F
        ld h,a
        call EndEscape
        jp MoveCursorClipped
.cursorOff:
        call EndEscape
        ld a,c
        cp '4'
        jr nz,.hide
        xor a
        ld (CSTYLE),a                   ; block
        ret
.hide:
        cp '5'
        ret nz
        xor a
        ld (CSRSW),a
        ret
.cursorOn:
        call EndEscape
        ld a,c
        cp '4'
        jr nz,.show
        ld a,$01
        ld (CSTYLE),a                   ; underline
        ret
.show:
        cp '5'
        ret nz
        ld a,$01
        ld (CSRSW),a
        ret

EndEscape:
        xor a
        jr SetEscState

EscapeCommand:                          ; C = the code after ESC
        call EndEscape
        ld a,c
        ld hl,EscapeTable
.find:
        ld a,(hl)
        inc hl
        or a
        ret z
        cp c
        jp z,ControlCode.found
        inc hl
        inc hl
        jr .find

EscapeTable:
        db 'A' : dw CursorUp
        db 'B' : dw CursorDown
        db 'C' : dw CursorRight
        db 'D' : dw CursorLeft
        db 'E' : dw ClearConsole
        db 'j' : dw ClearConsole
        db 'H' : dw CursorHome
        db 'J' : dw ClearToEndOfScreen
        db 'K' : dw ClearToEndOfLine
        db 'l' : dw ClearWholeLine
        db 'L' : dw InsertLine
        db 'M' : dw DeleteLine
        db 'Y' : dw .locate
        db 'x' : dw .cursorOff
        db 'y' : dw .cursorOn
        db 0
.locate:
        ld a,EscRow
        jp SetEscState
.cursorOff:
        ld a,EscCursorOff
        jp SetEscState
.cursorOn:
        ld a,EscCursorOn
        jp SetEscState

; --- cursor movement ---

CursorHome:
        ld hl,$0101
        jp StoreCursor

CarriageReturn:
        ld a,$01
        ld (CSRX),a
        ret

CursorRight:
        ld a,(LINLEN)
        ld b,a
        ld a,(CSRX)
        cp b
        jr nc,.nextRow
        inc a
        ld (CSRX),a
        ret
.nextRow:
        call BottomRow
        ld b,a
        ld a,(CSRY)
        cp b
        ret nc
        inc a
        ld (CSRY),a
        ld a,$01
        ld (CSRX),a
        ret

CursorLeft:
CursorBack:
        ld a,(CSRX)
        dec a
        jr z,.previousRow
        ld (CSRX),a
        ret
.previousRow:
        ld a,(CSRY)
        dec a
        ret z
        ld (CSRY),a
        ld a,(LINLEN)
        ld (CSRX),a
        ret

CursorUp:
        ld a,(CSRY)
        dec a
        ret z
        ld (CSRY),a
        ret

CursorDown:
        call BottomRow
        ld b,a
        ld a,(CSRY)
        cp b
        ret nc
        inc a
        ld (CSRY),a
        ret

; CursorDownScroll: line feed: down one row, scrolling at the bottom.
CursorDownScroll:
        call BottomRow
        ld b,a
        ld a,(CSRY)
        cp b
        jp nc,ScrollUp
        inc a
        ld (CSRY),a
        ret

Tabulate:
        ld c,' '
        call PrintCode
        ld a,(CSRX)
        dec a
        and $07
        jr nz,Tabulate
        ret

; MoveCursorClipped: In: H = column, L = row (from 1), kept inside the text area.
MoveCursorClipped:
        ld a,(LINLEN)
        cp h
        jr nc,.columnOk
        ld h,a
.columnOk:
        call BottomRow
        cp l
        jr nc,.rowOk
        ld l,a
.rowOk:
        ld a,h
        or a
        jr nz,.columnNotZero
        inc h
.columnNotZero:
        ld a,l
        or a
        jr nz,StoreCursor
        inc l
StoreCursor:
        ld (CSRY),hl                    ; L -> CSRY, H -> CSRX
        ret

; SetCursor: POSIT. In: H = column, L = row (from 1). Destroys AF.
SetCursor:
        push hl
        push de
        push bc
        push hl
        call EraseCursor
        pop hl
        ld (CSRY),hl
        ld a,(CSRSW)
        or a
        call nz,DrawCursor
        pop bc
        pop de
        pop hl
        ret

; --- geometry ---

; BottomRow: A = the last row the text uses (CRTCNT, one less when the function keys are shown).
BottomRow:
        ld a,(CNSDFG)
        or a
        ld a,(CRTCNT)
        ret z
        dec a
        ret

; TextLayout: Out: HL = name table, E = length of a row in it (32, 40 or 80), D = the first column
; used: the text area (LINLEN wide) is centred. Destroys AF.
TextLayout:
        ld a,(SCRMOD)
        or a
        jr nz,.screen1
        ld hl,(TXTNAM)
        ld e,40
        ld a,(RG0SAV)
        and $04                         ; Text 2: 80 columns
        jr z,.margin
        ld e,80
        jr .margin
.screen1:
        ld hl,(T32NAM)
        ld e,32
.margin:
        ld a,(LINLEN)
        ld d,a
        ld a,e
        sub d
        jr nc,.halve
        xor a
.halve:
        inc a                           ; (row length - LINLEN + 1) / 2
        srl a
        ld d,a
        ret

; RowAddress: In: L = row (from 1). Out: HL = VRAM address of the row's first byte, E = its length.
; Destroys AF, D.
RowAddress:
        push bc
        ld c,l
        call TextLayout
        ld d,$00
        ld a,c
        pop bc
.addRow:
        dec a
        ret z
        add hl,de
        jr .addRow

; CellAddress: In: H = column, L = row (from 1). Out: HL = VRAM address. Destroys AF, DE.
CellAddress:
        push bc
        ld b,h
        ld c,l
        call TextLayout
        ld a,d
        add a,b
        dec a                           ; first column + column - 1
        push af
        ld d,$00
        ld a,c
.addRow:
        dec a
        jr z,.rowDone
        add hl,de
        jr .addRow
.rowDone:
        pop af
        add a,l
        ld l,a
        jr nc,.done
        inc h
.done:
        pop bc
        ret

; LineTermAddress: In: A = row (from 1). Out: HL = its byte in LINTTB (0 = the logical line goes on
; in the next row). Destroys AF.
LineTermAddress:
        ld hl,LINTTB - 1
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; --- the cursor ---

; DrawCursor: show the cursor: the character under it is copied, inverted (block) or underlined, to
; pattern FFh, and FFh is put on the screen. Destroys AF, BC, DE, HL.
DrawCursor:
        ld a,(ESCCNT)
        bit CursorDrawn,a
        ret nz
        call H_DSPC
        ld a,(SCRMOD)
        cp $02
        ret nc
        ld hl,(CSRY)
        call CellAddress
        push hl
        call ReadVram
        ld (CODSAV),a
        call PatternTable               ; DE = pattern table
        push de
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld de,PATWRK
        ld bc,$0008
        call CopyVramToRam
        ld hl,PATWRK
        ld a,(CSTYLE)
        or a
        jr nz,.underline
        ld b,$08
.invert:
        ld a,(hl)
        cpl
        ld (hl),a
        inc hl
        djnz .invert
        jr .write
.underline:
        ld hl,PATWRK + 7
        ld (hl),$FF
.write:
        pop hl                          ; pattern table
        ld de,$FF * 8
        add hl,de
        ex de,hl
        ld hl,PATWRK
        ld bc,$0008
        call CopyRamToVram
        pop hl
        ld a,$FF
        call WriteVram
        ld hl,ESCCNT
        set CursorDrawn,(hl)
        ret

; EraseCursor: put back the character under the cursor. Destroys AF, DE, HL.
EraseCursor:
        ld hl,ESCCNT
        bit CursorDrawn,(hl)
        ret z
        res CursorDrawn,(hl)
        call H_ERAC
        ld a,(SCRMOD)
        cp $02
        ret nc
        ld hl,(CSRY)
        call CellAddress
        ld a,(CODSAV)
        jp WriteVram

; PatternTable: DE = the character patterns of the text mode. Preserves AF.
PatternTable:
        push af
        ld a,(SCRMOD)
        or a
        ld de,(TXTCGP)
        jr z,.done
        ld de,(T32CGP)
.done:
        pop af
        ret

; --- clearing and scrolling ---

; FillCells: In: HL = VRAM address, B = number of cells. Spaces. Destroys AF, BC.
FillCells:
        ld a,b
        or a
        ret z
        ld c,b
        ld b,$00
        ld a,' '
        jp FillVram

; ClearRow: the whole row L (from 1) to spaces, the line not continued. Destroys all.
ClearRow:
        push hl
        call RowAddress
        ld b,e
        call FillCells
        pop hl
        ld a,l
        call LineTermAddress
        ld (hl),$01
        ret

; ClearToEndOfLine: ESC K. From the cursor to the end of the row.
ClearToEndOfLine:
        ld hl,(CSRY)
; ClearFrom: In: H = column, L = row. Destroys all.
ClearFrom:
        push hl
        call CellAddress
        pop de
        ld a,(LINLEN)
        sub d
        inc a
        ld b,a
        call FillCells
        ret

; EraseToEndOfLine: EOL. In: H = column, L = row. Destroys all.
EraseToEndOfLine:
        push hl
        call EraseCursor
        pop hl
        jr ClearFrom

ClearWholeLine:                         ; ESC l
        ld hl,(CSRY)
        jr ClearRow

; ClearToEndOfScreen: ESC J.
ClearToEndOfScreen:
        call ClearToEndOfLine
        ld a,(CSRY)
.nextRow:
        ld l,a
        call BottomRow
        cp l
        ret z
        ret c
        inc l
        ld a,l
        push af
        call ClearRow
        pop af
        jr .nextRow

; ClearConsole: form feed / ESC E: every row of the text area, cursor home.
ClearConsole:
        call BottomRow
        ld l,a
.nextRow:
        push hl
        call ClearRow
        pop hl
        dec l
        jr nz,.nextRow
        jp CursorHome

; CopyRow: In: B = row to copy, C = row it goes to. Destroys all (IX kept).
CopyRow:
        push ix
        ld ix,-80
        add ix,sp
        ld sp,ix                        ; 80 bytes on the stack
        push bc
        ld l,b
        call RowAddress
        ld c,e
        ld b,$00
        push ix
        pop de
        call CopyVramToRam
        pop bc
        push bc
        ld l,c
        call RowAddress
        ld c,e
        ld b,$00
        ex de,hl
        push ix
        pop hl
        call CopyRamToVram
        pop bc
        ld a,b                          ; and the row's logical line mark
        call LineTermAddress
        ld e,(hl)
        ld a,c
        call LineTermAddress
        ld (hl),e
        ld hl,80
        add hl,sp
        ld sp,hl
        pop ix
        ret

; ScrollUp: rows 2 to the bottom up one, the bottom row cleared. The row where the line being typed
; started (FSTPOS) goes up with it.
ScrollUp:
        ld hl,FSTPOS
        ld a,(hl)
        dec a
        jr z,.firstRow
        ld (hl),a
.firstRow:
        ld bc,$0201
.next:
        call BottomRow
        cp b
        jr c,.clearBottom
        push bc
        call CopyRow
        pop bc
        inc b
        inc c
        jr .next
.clearBottom:
        call BottomRow
        ld l,a
        jp ClearRow

; DeleteLine: ESC M. The cursor's row goes, the rows below move up. (RowDelete: the same, for the sub-ROM,
; whose DeleteLine is BASIC's.)
DeleteLine:
RowDelete:
        ld a,(CSRY)
        ld c,a
        ld b,a
        inc b
.next:
        call BottomRow
        cp b
        jr c,.clearBottom
        push bc
        call CopyRow
        pop bc
        inc b
        inc c
        jr .next
.clearBottom:
        call BottomRow
        ld l,a
        call ClearRow
        jp CarriageReturn

; InsertLine: ESC L. A blank row at the cursor, the rows below move down.
InsertLine:
        call BottomRow
        ld c,a
        ld b,a
        dec b
.next:
        ld a,(CSRY)
        cp c
        jr z,.clearRow
        push bc
        call CopyRow
        pop bc
        dec b
        dec c
        jr .next
.clearRow:
        ld a,(CSRY)
        ld l,a
        call ClearRow
        jp CarriageReturn

; ClearTextScreen: every row (the function key line too) to spaces, cursor home, then the function keys
; again if they are on. Destroys all.
ClearTextScreen:
        call TextLayout
        ld bc,24 * 80                   ; at most: the whole name table of the text modes
        ld a,(SCRMOD)
        or a
        jr z,.fill
        ld bc,24 * 32
.fill:
        ld a,e
        cp 40
        jr nz,.fillNow
        ld bc,24 * 40
.fillNow:
        ld a,' '
        call FillVram
        ld hl,LINTTB
        ld b,24
.marks:
        ld (hl),$01
        inc hl
        djnz .marks
        ld hl,ESCCNT
        res CursorDrawn,(hl)
        ld hl,$0101
        ld (CSRY),hl
        jp FunctionKeysIfOn

; ClearScreen: CLS. Only when the Z flag is set (as BASIC calls it). Destroys AF, BC, DE.
ClearScreen:
        ret nz
        push hl
        ld a,(SCRMOD)
        cp $02
        jr c,.text
        jr nz,.notGraphic
        call ClearGraphic
        jr .done
.notGraphic:
        cp $03
        jr nz,.subRom
        ld a,(BAKCLR)                   ; SCREEN 3: every block the background colour
        and $0F
        ld b,a
        rlca
        rlca
        rlca
        rlca
        or b
        ld hl,(MLTCGP)
        ld bc,$0600
        call FillVram
        jr .done
.subRom:
        push ix
        ld ix,SubRomCls
        call CallSubRomDirect
        pop ix
        jr .done
.text:
        call ClearTextScreen
.done:
        pop hl
        ret

; --- function keys ---

; InitFunctionKeys: INIFNK. The ten function key strings to their power-on values: empty in this ROM (the
; function keys are not shown, so they type nothing until KEY n gives them a string; ON KEY GOSUB still works).
InitFunctionKeys:
        ld hl,FunctionKeyDefaults
        ld de,FNKSTR
        ld b,10
.key:
        push bc
        ld bc,$0010
        push de
.copy:
        ld a,(hl)
        inc hl
        ld (de),a
        inc de
        or a
        jr nz,.copy
        pop de
        ex de,hl
        add hl,bc
        ex de,hl
        pop bc
        djnz .key
        ret

FunctionKeyDefaults:
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; FunctionKeysIfOn: FNKSB. The status line when it is on.
FunctionKeysIfOn:
        ld a,(CNSDFG)
        or a
        ret z
; ShowFunctionKeys: DSPFNK. The bottom row (in the text modes) is this ROM's status line: the date and
; time of the clock, DD/MM/YY HH:MM, at its right end (not drawn in rows narrower than that). The function
; keys are not shown (they still type their strings). FNKSWI keeps the minute shown (BCD). Destroys all.
ShowFunctionKeys:
        ld a,$FF
        ld (CNSDFG),a
        call H_DSPF
        ld a,(SCRMOD)
        cp $02
        ret nc
        ld a,(CRTCNT)
        ld l,a
        call ClearRow
        ld a,(LINLEN)
        sub StatusLength - 1
        ret c
        ret z
        ld h,a                          ; H = the first column
        ld a,(CRTCNT)
        ld l,a
        call CellAddress
        call SetVramWrite
        ld a,$07                        ; DD
        call ClockPair
        call OutBcd
        ld a,'/'
        out (VdpData),a
        ld a,$09                        ; MM
        call ClockPair
        call OutBcd
        ld a,'/'
        out (VdpData),a
        ld a,$0B                        ; YY: the clock counts the years from 1980
        call ClockPair
        add a,$80
        daa
        call OutBcd
        ld a,' '
        out (VdpData),a
        ld a,$04                        ; HH
        call ClockPair
        call OutBcd
        ld a,':'
        out (VdpData),a
        ld a,$02                        ; MM
        call ClockPair
        ld (FNKSWI),a
        jp OutBcd
StatusLength    equ 14                  ; "DD/MM/YY HH:MM"

; ClockPair: A = the two digits (BCD) of the clock's registers A + 1 (tens) and A (units), block 0 (the
; time and the date). Keeps BC, DE, HL.
ClockPair:
        push bc
        ld b,a
        inc a
        call ClockRegister
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,b
        call ClockRegister
        or c
        pop bc
        ret

; ClockRegister: A = the 4 bits of the clock's register A in block 0 (the timer left on). The interrupts
; stay as they are (the interrupt does not use the clock). Keeps BC, DE, HL.
ClockRegister:
        push bc
        ld c,a
        ld a,$0D
        out (RtcIndex),a
        ld a,$08
        out (RtcData),a
        ld a,c
        out (RtcIndex),a
        in a,(RtcData)
        and $0F
        pop bc
        ret

; OutBcd: the two digits of A (BCD) to the VDP's data port. Destroys AF.
OutBcd:
        push af
        rrca
        rrca
        rrca
        rrca
        call .digit
        pop af
.digit:
        and $0F
        add a,'0'
        out (VdpData),a
        ret

; HideFunctionKeys: ERAFNK.
HideFunctionKeys:
        xor a
        ld (CNSDFG),a
        call H_ERAF
        ld a,(SCRMOD)
        cp $02
        ret nc
        ld a,(CRTCNT)
        ld l,a
        jp ClearRow

; ForceTextMode: TOTEXT. In a graphic mode, back to the last text mode (OLDSCR).
ForceTextMode:
        ld a,(SCRMOD)
        cp $02
        ret c
        call H_TOTE
        ld a,(OLDSCR)
        jp ChangeScreenMode

; ConvertGraphicChar: CNVCHR. In: A = character. Out: 01h (graphic header): NC (and GRPHED set);
; the code after a header: A = code - 40h, Z and C; any other: C and NZ. Destroys F.
ConvertGraphicChar:
        push hl
        ld hl,GRPHED
        cp $01
        jr z,.header
        push af
        ld a,(hl)
        or a
        jr z,.plain
        ld (hl),$00
        pop af
        sub $40
        cp a                            ; Z
        scf
        pop hl
        ret
.plain:
        pop af
        ld l,a
        ld a,$01
        or a                            ; NZ
        ld a,l
        scf
        pop hl
        ret
.header:
        ld (hl),a
        or a                            ; NC
        pop hl
        ret

; GraphicPrintChar: GRPPRT: character A on a graphic screen at GRPACX / GRPACY (the sub-ROM's). Keeps
; every register.
GraphicPrintChar:
        push ix
        ld ix,SubRomGraphicPrint
        call CallSubRomDirect
        pop ix
        ret
