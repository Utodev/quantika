; data.asm: READ / RESTORE (DATA), INPUT, CALL, SWAP, ERROR.

; StatementRestore: RESTORE [line]: the next READ starts at that line (or the first).
StatementRestore:
        ld de,$0000
        call AtStatementEnd
        jr z,.first
        call GetLineNumber
        jp c,SyntaxError
        push hl
        call FindLine
        ld e,ErrUndefinedLine
        jp nc,RaiseError
        ld h,b
        ld l,c
        dec hl
        ld (DATPTR),hl
        pop hl
        ret
.first:
        push hl
        ld hl,(TXTTAB)
        dec hl
        ld (DATPTR),hl
        pop hl
        ret

; StatementRead: READ variable [, variable ...].
StatementRead:
        call GetVariable
        push hl
        push de
        ld a,(VALTYP)
        push af
        call NextDataItem               ; HL = the item in the program
        pop af
        pop de
        push de
        push af
        call ReadItem                   ; DAC = its value (as the variable wants), HL after it
        ld (DATPTR),hl
        pop af
        pop de
        call AssignValue
        pop hl
        call ThisChar
        cp ','
        ret nz
        rst $10
        jr StatementRead

; NextDataItem: HL = the next DATA item (Out of DATA when there is none). DATLIN = its line.
NextDataItem:
        ld hl,(DATPTR)
        ld a,(hl)
        cp ','
        jr nz,.search
        inc hl                          ; the next item of the same DATA
        ret
.search:
        ld a,(hl)
        or a
        jr nz,.notLineEnd
        inc hl                          ; the next line
        ld a,(hl)
        inc hl
        or (hl)
        ld e,ErrOutOfData
        jp z,RaiseError
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (DATLIN),de
        inc hl
        jr .search
.notLineEnd:
        cp TkData
        jr z,.found
        call SkipItem
        jr .search
.found:
        inc hl
        ret

; ReadItem: the DATA item at HL as a value for a variable of type A. Out: DAC, HL on what follows (',' or
; the end of the statement). A number item that is not one: Syntax error.
ReadItem:
        cp TypeString
        jr z,ReadStringItem
        call ThisChar
        call FinNumber
        call ThisChar
        or a
        ret z
        cp ':'
        ret z
        cp ','
        ret z
        ld de,(DATLIN)                  ; the error is in the DATA line
        ld (CURLIN),de
        jp SyntaxError

; ReadStringItem: a string item: in quotes, or the characters up to ',', ':' or the end (without the
; spaces around them). Out: a temporary string, HL on what follows.
ReadStringItem:
        call ThisChar
        cp '"'
        jr nz,.unquoted
        call StringLiteral              ; HL past the closing quote
        call CopyTempString             ; (the text may go: a copy in the string space)
        jp ThisChar
.unquoted:
        ld d,h
        ld e,l
        ld b,$00
.count:
        ld a,(hl)
        or a
        jr z,.counted
        cp ':'
        jr z,.counted
        cp ','
        jr z,.counted
        inc hl
        inc b
        jr .count
.counted:
        push hl                         ; the spaces at the end go
.trim:
        ld a,b
        or a
        jr z,.trimmed
        dec hl
        ld a,(hl)
        cp ' '
        jr nz,.trimmed
        dec b
        jr .trim
.trimmed:
        ex de,hl
        call MakeString
        pop hl
        ret

; CopyTempString: the temporary string in DAC copied into the string space. Keeps HL.
CopyTempString:
        push hl
        ld hl,(DAC + 2)
        call ReleaseString              ; B, DE
        ex de,hl
        call MakeString
        pop hl
        ret

; StatementInput: INPUT ["prompt";] variable [, variable ...]. Values are typed separated by commas;
; when they do not fit: "?Redo from start".
StatementInput:
        cp '#'
        jp z,InputFile                  ; (INPUT #: basic/files.asm)
        cp '"'
        jr nz,.noPrompt
        call StringLiteral              ; the prompt
        push hl
        ld hl,(DAC + 2)
        call ReleaseString
        ex de,hl
        ld a,b
        or a
        jr z,.promptDone
.promptChar:
        ld a,(hl)
        rst $18
        inc hl
        djnz .promptChar
.promptDone:
        pop hl
        call ThisChar
        cp ';'
        jr z,.semicolon
        cp ','
        jp nz,SyntaxError
        rst $10                         ; (with a comma: no "? ")
        push hl
        call InputLineAtCursor
        jr .typed
.semicolon:
        rst $10
.noPrompt:
        push hl
        call InputLineQuestion
.typed:
        jr nc,.got
        pop hl                          ; CTRL+STOP: the program stops
        jp StatementStop.break
.got:
        ld hl,BUF
        ld (InputPointer),hl
        pop hl                          ; the statement: its variables
.variable:
        call GetVariable
        push hl
        push de
        ld a,(VALTYP)
        push af
        ld hl,(InputPointer)
        cp TypeString
        jr nz,.number
        call ReadStringItem
        jr .item
.number:
        call ThisChar
        call FinNumber
        call ThisChar
        or a
        jr z,.item
        cp ','
        jr nz,.redo
.item:
        ld (InputPointer),hl
        pop af
        pop de
        call AssignValue
        pop hl                          ; the statement
        call ThisChar
        cp ','
        ret nz
        push hl
        ld hl,(InputPointer)            ; more variables: the typed text must go on with a comma
        call ThisChar
        cp ','
        jr nz,.redo
        inc hl
        ld (InputPointer),hl
        pop hl
        rst $10
        jr .variable
.redo:
        ld hl,RedoText                  ; and the whole INPUT again
        call PrintString
        ld sp,(SAVSTK)
        ld hl,(SAVTXT)
        jp NewStatement
RedoText:
        db "?Redo from start",$0D,$0A,0
InputPointer    equ TEMP                 ; the typed text being read

; StatementCall: CALL name [(arguments)] and _name: offered to the ROMs that take statements.
StatementCallUnderscore:
StatementCall:
        call ThisChar
        ld de,PROCNM                    ; the name, in capitals, ended by 0
        ld b,15
.name:
        call UpperCase
        call IsNameChar
        jr c,.nameDone
        ld (de),a
        inc de
        inc hl
        ld a,(hl)
        djnz .name
.nameDone:
        xor a
        ld (de),a
        ld a,(PROCNM)
        or a
        jp z,SyntaxError
        ; every slot and page whose ROM takes statements (SLTATR bit 5)
        ld b,$00                        ; B = SLTATR index
.slot:
        push bc
        push hl
        ld a,b
        ld hl,SLTATR
        add a,l
        ld l,a
        jr nc,.noCarry
        inc h
.noCarry:
        bit 5,(hl)
        pop hl
        jr z,.nextSlot
        ld a,b                          ; slot ID from the index: primary * 16 + sub * 4 + page
        rrca
        rrca
        rrca
        rrca
        and $03                         ; primary
        ld c,a
        ld a,b
        and $0C                         ; sub * 4
        or c
        push hl
        ld hl,EXPTBL
        ld e,c
        ld d,$00
        add hl,de
        or (hl)                         ; bit 7: expanded
        and $8F
        pop hl
        push af
        ld a,b                          ; the header: page * 4000h
        and $03
        rrca
        rrca
        ld d,a
        ld e,$04                        ; STATEMENT at +4
        pop af
        push af
        push hl
        ex de,hl
        call ReadSlotWord               ; DE = the handler
        pop hl
        pop af
        push af
        pop iy                          ; IYh = slot
        push de
        pop ix
        call CallSlot                   ; HL = text after the name; carry: not taken
        ei
        jr nc,.taken
.nextSlot:
        pop bc
        inc b
        ld a,b
        cp $40
        jr nz,.slot
        jp SyntaxError
.taken:
        pop bc
        ret

; ReadSlotWord: DE = the word at HL in slot A. Keeps HL.
ReadSlotWord:
        push hl
        push af
        call ReadSlot
        ld e,a
        pop af
        pop hl
        push hl
        inc hl
        push de
        call ReadSlot
        pop de
        ld d,a
        pop hl
        ret

; StatementSwap: SWAP variable, variable (of the same type).
StatementSwap:
        call GetVariable
        ld a,(VALTYP)
        push de
        push af
        call Comma
        call GetVariable
        pop af
        ld b,a
        ld a,(VALTYP)
        cp b
        jp nz,TypeMismatch
        pop ix                          ; the first
        push hl
        ld c,b                          ; bytes: the type (a string: its 3-byte descriptor)
.swap:
        ld a,(de)
        ld b,(ix+0)
        ld (ix+0),a
        ld a,b
        ld (de),a
        inc de
        inc ix
        dec c
        jr nz,.swap
        pop hl
        ret

; StatementError: ERROR code.
StatementError:
        call EvalByte
        or a
        jp z,IllegalFunction
        ld e,a
        jp RaiseError


