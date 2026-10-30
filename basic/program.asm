; program.asm: the program in memory: lines in and out, NEW, CLEAR, RUN, LIST.

; LinkLines: the address of the next line in every line again, from TXTTAB. Out: HL = the end mark
; (the two zero bytes). Destroys AF, DE.
LinkLines:
        ld hl,(TXTTAB)
.line:
        ld a,(hl)
        inc hl
        or (hl)
        dec hl
        ret z                           ; the end
        push hl
        inc hl
        inc hl
        inc hl
        inc hl                          ; the tokens
.toEnd:
        ld a,(hl)
        inc hl
        or a
        jr z,.ended
        dec hl
        call SkipItem
        jr .toEnd
.ended:
        ex de,hl                        ; DE = the next line
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        ex de,hl
        jr .line

; StoreLine: line DE with the tokens in KBUF (B bytes, the 0 at the end included; B = 1: the line goes).
StoreLineBytes  equ TEMP3
StoreLineNumber equ TEMP2

StoreLine:
        ld a,b
        ld (StoreLineBytes),a
        ld (StoreLineNumber),de
        call FindLine                   ; BC = the line, or where it goes
        jr nc,.noOld
        ld h,b                          ; the old line goes: [it, next line) is taken out
        ld l,c
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; DE = the next line
        push bc
        ld hl,(VARTAB)
        or a
        sbc hl,de
        ld b,h
        ld c,l                          ; the bytes after it
        ex de,hl
        pop de                          ; DE = the old line
        push de
        ld a,b
        or c
        jr z,.taken
        ldir
.taken:
        ld (VARTAB),de
        pop bc                          ; the new line goes where the old one was
.noOld:
        ld a,(StoreLineBytes)
        cp $01
        jr z,.relink                    ; only the number: deleted
        add a,$04                       ; the link, the number, the tokens
        ld e,a
        ld d,$00                        ; DE = its size
        ld hl,(VARTAB)
        push hl                         ; the old end
        add hl,de
        jp c,OutOfMemory
        ld (VARTAB),hl
        push de                         ; the new end must stay under the stack
        ld de,$0080
        add hl,de
        jp c,OutOfMemory
        ex de,hl
        ld hl,$0006
        add hl,sp
        rst $20
        pop de
        jp c,OutOfMemory
        pop hl                          ; the old end
        push bc                         ; the place
        or a
        sbc hl,bc                       ; the bytes from the place to the old end move up
        jr z,.noMove
        ld b,h
        ld c,l
        ld hl,(VARTAB)
        dec hl                          ; the new last byte
        push hl
        or a
        sbc hl,de                       ; the old last byte
        pop de
        lddr
.noMove:
        pop hl                          ; the place
        ld (hl),$FF                     ; a link that is not 0 (LinkLines takes 0 for the end)
        inc hl
        ld (hl),$FF
        inc hl
        ld de,(StoreLineNumber)
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ex de,hl
        ld hl,KBUF
        ld a,(StoreLineBytes)
        ld c,a
        ld b,$00
        ldir
.relink:
        call LinkLines
        inc hl
        inc hl
        ld (VARTAB),hl
        xor a                           ; CONT cannot go on after an edit
        ld (OLDTXT),a
        ld (OLDTXT + 1),a
        jp ClearVariables

; --- NEW, CLEAR, RUN ---

; StatementNew: NEW.
StatementNew:
        ret nz
        call NewProgram
        jp Ready

; NewProgram: no program, no variables.
NewProgram:
        ld hl,(TXTTAB)
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (VARTAB),hl
        ld (OLDTXT),a
        ld (OLDTXT + 1),a
        ld (TRCFLG),a
; ClearVariables: no variables, arrays or strings, DATA from the start, no ON ERROR, the default types.
ClearVariables:
        push hl
        ld hl,(VARTAB)
        ld (ARYTAB),hl
        ld (STREND),hl
        ld hl,(MEMSIZ)
        ld (FRETOP),hl
        call FreeTemps
        ld hl,(TXTTAB)
        dec hl
        ld (DATPTR),hl
        xor a
        ld (ONELIN),a
        ld (ONELIN + 1),a
        ld (ONEFLG),a
        ld hl,TRPTBL                    ; no traps
        ld b,3 * TrapCount
.traps:
        ld (hl),a
        inc hl
        djnz .traps
        ld hl,FNKFLG
        ld b,10
.keys:
        ld (hl),a
        inc hl
        djnz .keys
        ld (ONGSBF),a
        ld hl,DEFTBL
        ld b,26
.types:
        ld (hl),TypeDouble
        inc hl
        djnz .types
        call H_CLEA
        pop hl
        ret

; StatementClear: CLEAR [string space [, highest address]].
StatementClear:
        jr z,.plain
        call EvalAddress                ; the string space
        push de
        call ThisChar
        ld de,(HIMEM)
        cp ','
        jr nz,.noTop
        rst $10
        call EvalAddress
.noTop:
        ld (HIMEM),de                   ; (the file blocks go under it, then the string space)
        pop de
        push hl
        ld a,(MAXFIL)
        call FileLayout
        pop hl
.plain:
        call ClearVariables
        pop bc                          ; the stack starts again (the return to NewStatement)
        ld sp,(STKTOP)
        jp NewStatement

; StatementRun: RUN [line].
StatementRun:
        jp nz,.fromLine
        call ClearVariables
        ld hl,(TXTTAB)
        dec hl
        ld sp,(STKTOP)
        ld bc,$0000
        ld (CURLIN),bc
        jp NewStatement
.fromLine:
        cp $0E
        jp nz,RunFile                   ; RUN "file"
        call GetLineNumber
        push de
        call ClearVariables
        pop de
        ld sp,(STKTOP)
        call GotoLine
        jp NewStatement

; --- LIST ---

; StatementList: LIST [first] [-[last]]. StatementLlist: the same to the printer.
StatementLlist:
        ld a,$01
        ld (PRTFLG),a
        call ThisChar
        call StatementList
        xor a
        ld (PRTFLG),a
        ret
StatementList:
        ld de,$0000                     ; DE = first, BC = last
        ld bc,$FFFF
        call AtStatementEnd
        jr z,.range
        cp TkMinus
        jr z,.dash
        call GetLineNumber
        jp c,SyntaxError
        ld b,d
        ld c,e                          ; LIST n: only n unless a dash follows
        call ThisChar
        cp TkMinus
        jr nz,.range
        ld bc,$FFFF
.dash:
        rst $10
        call AtStatementEnd
        jr z,.range
        push de
        call GetLineNumber
        jp c,SyntaxError
        ld b,d
        ld c,e
        pop de
.range:
        push hl
        call ListRange
        pop hl
        ret

; ListRange: the lines from DE to BC as text. Destroys all.
ListRange:
        push bc
        call FindLine                   ; BC = the first line to list
        ld h,b
        ld l,c
        pop bc
.line:
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.done
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; the line number
        inc hl
        push hl
        ld h,b
        ld l,c
        rst $20                         ; last - number
        pop hl
        jr c,.done
        push bc
        push hl
        ex de,hl
        call PrintUnsigned
        ld a,' '
        rst $18
        pop hl
        call ListLine                   ; the tokens as text; HL past the 0
        call PrintCrLf
        pop bc
        call CheckListBreak
        jr .line
.done:
        ret

; CheckListBreak: CTRL+STOP stops the listing, STOP pauses it.
CheckListBreak:
        ld a,(INTFLG)
        or a
        ret z
        jp CheckBreak

; ListLine: the tokens at HL as text, to the 0 that ends them. Out: HL past it. Destroys AF, DE.
ListLine:
        ld d,$00                        ; D: 1 inside a string, 2 after REM / DATA (raw text)
.item:
        ld a,(hl)
        inc hl
        or a
        ret z
        bit 0,d
        jr nz,.inString
        bit 1,d
        jr nz,.raw
        cp '"'
        jr z,.quote
        cp ':'
        jr z,.colon
        cp TkFunction
        jr z,.function
        cp $80
        jr nc,.token
        cp $20
        jr c,.constant
.char:
        rst $18
        jr .item
.inString:
        cp '"'
        jr nz,.char
        res 0,d
        jr .char
.raw:
        cp '"'                          ; DATA: raw until ':' outside quotes; REM: to the end
        jr nz,.rawChar
        ld a,d
        xor $04                         ; (bit 2: inside quotes in DATA)
        ld d,a
        ld a,'"'
.rawChar:
        cp ':'
        jr nz,.char
        bit 3,d                         ; (bit 3: DATA, which a ':' ends)
        jr z,.char
        bit 2,d
        jr nz,.char
        ld d,$00
        jr .char
.quote:
        set 0,d
        jr .char
.colon:
        ld a,(hl)                       ; ":ELSE" and ":REM'" are ELSE and '
        cp TkElse
        jr z,.item
        cp TkRem
        jr nz,.plainColon
        inc hl
        ld a,(hl)
        dec hl
        cp TkApostrophe
        jr nz,.plainColon
        inc hl                          ; past the REM: the ' shows
        jr .item
.plainColon:
        ld a,':'
        jr .char
.function:
        ld a,(hl)
        inc hl
        push hl
        ld hl,FunctionNames
        jr .name
.token:
        push hl
        cp TkRem
        jr z,.rem
        cp TkApostrophe
        jr z,.rem
        cp TkData
        jr nz,.notData
        ld d,$0A                        ; raw, ended by ':'
        jr .named
.rem:
        ld d,$02
        jr .named
.notData:
.named:
        ld hl,StatementNames
.name:
        sub $81                         ; the A'th name
        jr z,.found
.skipName:
        bit 7,(hl)
        inc hl
        jr z,.skipName
        dec a
        jr nz,.skipName
.found:
        ld a,(hl)
        and $7F
        rst $18
        bit 7,(hl)
        inc hl
        jr z,.found
        pop hl
        jp .item
.constant:
        dec hl
        push de
        call ListConstant
        pop de
        jp .item

; ListConstant: the number token at HL as text. Out: HL past it. Destroys AF, BC, DE.
ListConstant:
        ld a,(hl)
        cp $0B
        jr z,.octal
        cp $0C
        jr z,.hex
        cp $0E
        jr z,.lineNumber
        cp $0D
        jr z,.linePointer
        push hl
        call ConstantOperand            ; DAC, HL past the token (keeps no type info for LIST...)
        ld (TEMP2),hl
        pop hl
        xor a
        call FormatNumber
        ld a,(hl)
        cp ' '
        jr nz,.signed
        inc hl                          ; LIST shows no space before a number
.signed:
        push hl
        call PrintStringCount           ; B = characters, C = 1 if a '.' or an 'E' was there
        pop hl
        ld a,(VALTYP)
        cp TypeSingle
        jr nz,.notSingle
        ld a,c
        or a
        jr nz,.done                     ; 1.5 reads back as single precision by itself
        ld a,'!'
        rst $18
        jr .done
.notSingle:
        cp TypeDouble
        jr nz,.done
        ld a,'#'
        rst $18
.done:
        ld hl,(TEMP2)
        ret
.lineNumber:
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
.printLine:
        push hl
        ex de,hl
        call PrintUnsigned
        pop hl
        ret
.linePointer:
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        jr .printLine
.octal:
        ld c,$03
        ld a,'O'
        jr .radix
.hex:
        ld c,$04
        ld a,'H'
.radix:
        push af
        ld a,'&'
        rst $18
        pop af
        rst $18
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        call RadixText
        call PrintString
        pop hl
        ret

; PrintStringCount: PrintString that also says whether the text had a '.' or an 'E'.
; Out: C = 1 when it had. Destroys AF.
PrintStringCount:
        ld c,$00
.char:
        ld a,(hl)
        inc hl
        or a
        ret z
        cp '.'
        jr z,.mark
        cp 'E'
        jr nz,.out
.mark:
        ld c,$01
.out:
        rst $18
        jr .char
