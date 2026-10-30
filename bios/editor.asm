; editor.asm: the screen editor: a line is typed (and edited anywhere on the screen) and RETURN reads
; the logical line under the cursor from the screen into BUF. A logical line is one or more rows that
; LINTTB says go on into the next. If the typing started on that same logical line (INPUT's prompt is
; before it), the line is read from where it started (FSTPOS).

; InputLineQuestion: QINLIN. "? " and then INLIN. (Typing needs a text mode: a graphic one goes back
; to the last text mode first, here and in INLIN.)
InputLineQuestion:
        call H_QINL
        call ForceTextMode
        ld a,'?'
        rst $18
        ld a,' '
        rst $18
        jr InputLineAtCursor

; InputLine: PINLIN. The line of the BASIC prompt. Out: BUF, HL = BUF - 1, carry for CTRL+STOP.
InputLine:
        call H_PINL
; InputLineAtCursor: INLIN.
InputLineAtCursor:
        call H_INLI
        call ForceTextMode
        ld hl,(CSRY)                    ; where the typing starts
        ld (FSTPOS),hl
.key:
        call GetKey
        cp $0D
        jp z,.return
        cp $03
        jr z,.stop
        cp $08
        jr z,.backspace
        cp $7F
        jr z,.delete
        cp $12
        jr z,.insertKey
        cp $05
        jr z,.eraseEnd
        cp $15
        jr z,.eraseLine
        cp $1B
        jr z,.key                       ; ESC: nothing
        cp $20
        jr c,.control
        ld c,a
        ld a,(INSFLG)
        or a
        call nz,InsertCell
        ld a,c
.control:
        call PutChar
        jr .key
.backspace:
        ld a,(CSRX)                     ; at the start of the row: the end of the one above
        dec a
        jr nz,.left
        ld a,(CSRY)
        dec a
        jr z,.key
.left:
        ld a,$1D
        call PutChar
.delete:
        call DeleteCell
        jr .key
.insertKey:
        call EraseCursor
        ld a,(INSFLG)
        cpl
        ld (INSFLG),a
        ld (CSTYLE),a                   ; (an underline cursor while inserting)
        jr .key
.eraseEnd:
        ld a,$1B
        call PutChar
        ld a,'K'
        call PutChar
        jr .key
.eraseLine:
        call LogicalLineStart           ; to the start of the logical line, and clear it
        ld h,$01
        call SetCursor
        ld a,$1B
        call PutChar
        ld a,'K'
        call PutChar
        jr .key
.stop:
        call EndInsertMode
        call PrintCrLf
        ld hl,BUF
        ld (hl),$00
        dec hl
        scf
        ret
.return:
        call EndInsertMode
        call EraseCursor
        call LogicalLineStart           ; L = its first row
        ld h,$01
        ld a,(FSTPOS)                   ; the typing started on this logical line: from there
        ld b,a
        call LogicalLineEnd             ; A = its last row
        ld c,a
        ld a,b
        cp l
        jr c,.fromStart
        cp c
        jr z,.fromTyping
        jr nc,.fromStart
.fromTyping:
        ld hl,(FSTPOS)
.fromStart:
        ; read from row L, column H, to the end of row C, into BUF
        ld de,BUF
        ld b,$00                        ; B = characters
.row:
        ld a,(LINLEN)
.cell:
        cp h
        jr c,.rowDone
        push af
        push hl
        push de
        push bc
        call CellAddress
        call ReadVram
        pop bc
        pop de
        pop hl
        cp $20
        jr nc,.plain
        push af                         ; a graphic character: 01h and its code + 40h
        ld a,$01
        ld (de),a
        inc de
        inc b
        pop af
        add a,$40
.plain:
        ld (de),a
        inc de
        inc b
        pop af
        inc h
        jr nz,.cell
.rowDone:
        ld a,l
        cp c
        jr nc,.read
        inc l
        ld h,$01
        jr .row
.read:
        ld a,b                          ; the spaces at the end go
.trim:
        or a
        jr z,.trimmed
        dec de
        ld a,(de)
        cp ' '
        jr nz,.keep
        dec b
        ld a,b
        jr .trim
.keep:
        inc de
.trimmed:
        xor a
        ld (de),a
        ld a,c                          ; the cursor after the logical line
        ld (CSRY),a
        call PrintCrLf
        ld hl,BUF - 1
        or a
        ret

; EndInsertMode: insert mode off (it ends with the line).
EndInsertMode:
        ld a,(INSFLG)
        or a
        ret z
        call EraseCursor
        xor a
        ld (INSFLG),a
        ld (CSTYLE),a
        ret

; LogicalLineStart: L = the first row of the logical line of the cursor. Destroys AF.
LogicalLineStart:
        ld a,(CSRY)
        ld l,a
.up:
        ld a,l
        dec a
        ret z
        push hl
        call LineTermAddress            ; the row above: does it go on into this one?
        ld a,(hl)
        pop hl
        or a
        ret nz
        dec l
        jr .up

; LogicalLineEnd: A = the last row of the logical line of the cursor. Keeps the others.
LogicalLineEnd:
        push hl
        push bc
        ld a,(CSRY)
        ld c,a
.down:
        call BottomRow
        cp c
        jr z,.done
        ld a,c
        call LineTermAddress
        ld a,(hl)
        or a
        jr nz,.done
        inc c
        jr .down
.done:
        ld a,c
        pop bc
        pop hl
        ret

; DeleteCell: the characters right of the cursor in its row move one left; a space at the end.
DeleteCell:
        call EraseCursor
        ld hl,(CSRY)
.cell:
        ld a,(LINLEN)
        cp h
        jr z,.last
        inc h                           ; the next cell's character into this one
        push hl
        call CellAddress
        call ReadVram
        pop hl
        dec h
        push hl
        push af
        call CellAddress
        pop af
        call WriteVram
        pop hl
        inc h
        jr .cell
.last:
        call CellAddress
        ld a,' '
        jp WriteVram

; InsertCell: the characters from the cursor on in its row move one right (the last is lost).
InsertCell:
        push bc
        call EraseCursor
        ld hl,(CSRY)
        ld a,(LINLEN)
        ld h,a
.cell:
        ld a,(CSRX)
        cp h
        jr z,.done
        dec h                           ; the cell on the left into this one
        push hl
        call CellAddress
        call ReadVram
        pop hl
        inc h
        push hl
        push af
        call CellAddress
        pop af
        call WriteVram
        pop hl
        dec h
        jr .cell
.done:
        pop bc
        ret
