; edit.asm: DELETE and RENUM, the statements that change the program's lines (AUTO is in main.asm: it
; lives in the direct mode's loop). Both end in the direct mode (Ok).

RenumNew        equ CPCNT               ; (the CIRCLE work area: not in use) the first new number
RenumOld        equ CPCNT + 2           ; the first line renumbered
RenumStep       equ CPCNT + 4           ; the increment
RenumFirst      equ CPCNT + 6           ; the address of the first line renumbered
RenumLine       equ CPCNT + 8           ; the line being looked at (for the messages)

; StatementDelete: DELETE line, DELETE first-last, DELETE -last (the lines given must exist).
StatementDelete:
        cp TkMinus
        jr nz,.first
        ld bc,(TXTTAB)                  ; -last: from the first line
        push bc
        rst $10
        jr .last
.first:
        call DeleteLine                 ; BC = its address
        push bc
        call ThisChar
        cp TkMinus
        jr nz,.one
        rst $10
.last:
        call DeleteLine
        jr .range
.one:
        pop bc
        push bc
.range:
        call AtStatementEnd
        jp nz,SyntaxError
        ld h,b                          ; DE = the line after the last one
        ld l,c
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop bc                          ; BC = the first one
        ld h,d
        ld l,e
        or a
        sbc hl,bc
        jp z,IllegalFunction
        jp c,IllegalFunction            ; (the last one before the first)
        ld hl,(VARTAB)                  ; [first, after the last) goes: what follows moves down
        or a
        sbc hl,de
        push bc
        ld b,h
        ld c,l
        ex de,hl
        pop de
        ld a,b
        or c
        jr z,.moved
        ldir
.moved:
        call LinkLines
        inc hl
        inc hl
        ld (VARTAB),hl
        xor a                           ; CONT cannot go on after an edit
        ld (OLDTXT),a
        ld (OLDTXT + 1),a
        call ClearVariables
        jp Ready

; DeleteLine: a line number that must be in the program. Out: BC = its line's address.
DeleteLine:
        call GetLineNumber
        jp c,IllegalFunction
        call FindLine
        ret c
        jp IllegalFunction

; StatementRenum: RENUM [new] [, [old] [, increment]] (10, the first line, 10). The lines from old on
; are numbered new, new + increment...; every line number in the program that refers to them follows.
; A reference to a line that is not there is told ("Undefined line n in m") and left as it is.
StatementRenum:
        ld de,10
        ld (RenumNew),de
        ld (RenumStep),de
        ld de,$0000
        ld (RenumOld),de
        call AtStatementEnd
        jr z,.check
        cp ','
        jr z,.old
        call GetLineNumber
        jp c,SyntaxError
        ld (RenumNew),de
        call ThisChar
        cp ','
        jr nz,.check
.old:
        rst $10
        cp ','
        jr z,.step
        call GetLineNumber
        jp c,SyntaxError
        ld (RenumOld),de
        call ThisChar
        cp ','
        jr nz,.check
.step:
        rst $10
        call GetLineNumber
        jp c,SyntaxError
        ld a,d
        or e
        jp z,IllegalFunction
        ld (RenumStep),de
.check:
        call AtStatementEnd
        jp nz,SyntaxError
        ld de,(RenumOld)                ; the first line renumbered
        call FindLine
        ld (RenumFirst),bc
        ld h,b
        ld l,c
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.references                ; none: only the references are looked at
        ld hl,(TXTTAB)                  ; the line before it must stay below the new numbers
        ld d,b
        ld e,c
        rst $20
        jr z,.lastFits                  ; (it is the first line)
.before:
        ld c,(hl)
        inc hl
        ld b,(hl)
        dec hl                          ; BC = the line after HL
        ld a,b
        cp d
        jr nz,.notBefore
        ld a,c
        cp e
        jr z,.isBefore
.notBefore:
        ld h,b
        ld l,c
        jr .before
.isBefore:
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; its number
        ld hl,(RenumNew)
        rst $20                         ; new - that number
        jp z,IllegalFunction
        jp c,IllegalFunction
.lastFits:
        ld hl,(RenumFirst)              ; the last new number must be 65529 or less
        ld de,(RenumNew)
.count:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                          ; the next line
        ld a,(hl)
        inc hl
        or (hl)
        dec hl
        jr z,.lastNumber
        push hl
        ld hl,(RenumStep)
        add hl,de
        ex de,hl
        pop hl
        jp c,IllegalFunction
        jr .count
.lastNumber:
        ld hl,65529
        rst $20                         ; 65529 - the last number
        jp c,IllegalFunction
.references:
        call RenumReferences
        ld hl,(RenumFirst)              ; the lines' own numbers
        ld de,(RenumNew)
.renumber:
        ld c,(hl)
        inc hl
        ld b,(hl)                       ; BC = the next line
        ld a,b
        or c
        jr z,.done
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(RenumStep)
        add hl,de
        ex de,hl
        ld h,b
        ld l,c
        jr .renumber
.done:
        call ClearVariables
        jp Ready

; RenumReferences: every line number token (0Eh) of the program: the new number of its line.
RenumReferences:
        ld hl,(TXTTAB)
.line:
        ld a,(hl)
        inc hl
        or (hl)
        ret z                           ; the end
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld (RenumLine),de
.token:
        ld a,(hl)
        or a
        jr z,.endOfLine
        cp '"'
        jr z,.string
        cp $0E
        jr z,.reference
        call ConstantLength             ; a number: its bytes are not tokens
        inc hl
        jr c,.token
        ld e,a
        ld d,$00
        add hl,de
        jr .token
.endOfLine:
        inc hl
        jr .line
.string:
        inc hl
        ld a,(hl)
        or a
        jr z,.token
        cp '"'
        jr nz,.string
        inc hl
        jr .token
.reference:
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        call RenumNumber                ; DE = the new number
        pop hl
        jr c,.undefined
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
.next:
        inc hl
        jr .token
.undefined:
        push hl
        push de
        call NewLineIfNeeded
        ld hl,UndefinedLineText
        call RenumText
        pop hl
        call PrintUnsigned
        ld hl,InLineText
        call RenumText
        ld hl,(RenumLine)
        call PrintUnsigned
        call PrintCrLf
        pop hl
        jr .next

UndefinedLineText:
        db "Undefined line ",0
InLineText:
        db " in ",0

; RenumText: the zero ended text at HL (of this ROM: the main ROM's PrintString cannot read it).
RenumText:
        ld a,(hl)
        or a
        ret z
        rst $18
        inc hl
        jr RenumText

; RenumNumber: the new number of line DE (itself when it is before the lines renumbered). Out: DE,
; carry when there is no such line.
RenumNumber:
        push de
        call FindLine                   ; BC = its line
        pop de
        ccf
        ret c
        ld hl,(RenumOld)
        ex de,hl
        rst $20                         ; line - old
        ex de,hl
        ccf
        ret nc                          ; before them: as it is
        ld hl,(RenumFirst)              ; new + step for each line before it
        ld de,(RenumNew)
.count:
        ld a,h
        cp b
        jr nz,.notThis
        ld a,l
        cp c
        jr nz,.notThis
        or a
        ret
.notThis:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        ld hl,(RenumStep)
        add hl,de
        ex de,hl
        pop hl
        jr .count
