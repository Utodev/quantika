; interp.asm: the heart of FBASIC: reading the program text, running statement after statement,
; errors, and the statements that change the flow (GOTO, GOSUB, RETURN, IF, ON, FOR, NEXT, END, STOP,
; CONT, REM).
;
; The text pointer is HL all through BASIC. A program line in memory is: the address of the next line
; (2 bytes, 0 after the last line), the line number (2), the tokens, 0. TXTTAB is the first line; the byte
; before it is 0. Numbers inside the text are tokens followed by their bytes (see SkipConstant), and
; those bytes may be 0 or ':', so everything that walks the text skips them whole.
;
; FOR and GOSUB leave a frame on the Z80 stack (this ROM's layout), found again by its marker word:
;   GOSUB: marker (TkGosub, 0), the line number, the text pointer after the GOSUB      7 bytes
;   FOR:   marker (TkFor, type), the variable's address, the step (8), the limit (8),
;          the line number, the text pointer after the FOR statement                 25 bytes
; The marker is the word at the lowest address (pushed last). Each frame has one unused byte above it, so
; that the frames take the room the original's do (FRE(0) counts it).

ForFrameSize    equ 25
GosubFrameSize  equ 7

; --- reading the text ---

; NextChar: CHRGTR (RST 10h). The next character of the text, past spaces.
; In: HL. Out: HL on it, A = it; Z at the end of a statement (0 or ':'), C for a digit '0'-'9'.
NextChar:
        inc hl
; ThisChar: the same without moving first.
ThisChar:
        ld a,(hl)
        cp ':'
        ret nc                          ; ':' gives Z, others above it NZ NC
        cp ' '
        jr z,NextChar
        cp '0'
        ccf                             ; C for '0'-'9' (everything here is below ':')
        inc a
        dec a                           ; Z for 0 (the carry stays)
        ret

; SyntaxCheck: SYNCHR (RST 08h). The character at HL must be the byte after the RST; then NextChar.
SyntaxCheck:
        ld a,(hl)
        ex (sp),hl
        cp (hl)
        inc hl
        ex (sp),hl
        jp nz,SyntaxError
        jr NextChar

; ConstantLength: the bytes after a number token. In: A = token (0Bh-1Fh). Out: A = count, carry when
; A was not a number token. Destroys F.
ConstantLength:
        cp $0B
        ret c
        cp $20
        ccf
        ret c
        push hl
        ld hl,ConstantLengths - $0B
        add a,l
        ld l,a
        jr nc,.got
        inc h
.got:
        ld a,(hl)
        pop hl
        or a
        ret
ConstantLengths:                        ; 0Bh-1Fh
        db 2, 2, 2, 2, 1, 0             ; &O, &H, line pointer, line number, byte, (10h)
        db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ; 0-9
        db 0, 2, 4, 0, 8                ; (1Bh), integer, single, (1Eh), double

; SkipToStatementEnd: HL to the ':' or 0 that ends the statement, past strings and numbers.
; In: HL on the first character to look at. Destroys AF.
SkipToStatementEnd:
        ld a,(hl)
        or a
        ret z
        cp ':'
        ret z
        call SkipItem
        jr SkipToStatementEnd

; SkipItem: HL past one item of the text (a character, a string in quotes, a number, a function token).
; Destroys AF.
SkipItem:
        ld a,(hl)
        inc hl
        cp '"'
        jr z,.string
        cp TkFunction
        jr z,.oneMore
        call ConstantLength
        ret c
.bytes:
        or a
        ret z
        inc hl
        dec a
        jr .bytes
.oneMore:
        inc hl
        ret
.string:
        ld a,(hl)
        or a
        ret z                           ; (an unclosed string ends with the line)
        inc hl
        cp '"'
        ret z
        jr .string

; SkipToLineEnd: HL to the 0 that ends the line (past strings and numbers). Destroys AF.
SkipToLineEnd:
        ld a,(hl)
        or a
        ret z
        call SkipItem
        jr SkipToLineEnd

; --- running ---

; RunFrom: run the text from HL (on the 0 before a line, or on a ':'), with an empty stack frame.
; Never returns: the program ends through END / an error into the Ok loop.
RunFrom:
NewStatement:
        ld (SAVTXT),hl
        ld (SAVSTK),sp
        push hl                         ; no temporary string lives past a statement
        ld hl,TEMPST
        ld (TEMPPT),hl
        pop hl
        ld a,(INTFLG)
        or a
        call nz,CheckBreak
        ld a,(ONGSBF)                   ; ON ... GOSUB traps (basic/traps.asm)
        or a
        call nz,RunTraps
        ld a,(hl)
        cp ':'
        jr z,.statement
        or a
        jp nz,SyntaxError               ; something after a statement
        ; the end of a line
        ld de,(CURLIN)
        ld a,d
        and e
        inc a
        jp z,EndDirect                  ; direct mode (CURLIN = FFFFh): the line is done
        inc hl
        ld e,(hl)                       ; the next line's link
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jp z,EndProgram                 ; the end of the program text
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (CURLIN),de
        ld a,(TRCFLG)
        or a
        call nz,TraceLine
.statement:
        call H_NEWS
        rst $10
        jr z,NewStatement               ; an empty statement
        ld de,NewStatement
        push de
; ExecuteStatement: In: HL on the statement's first item, A = it. A handler is entered with HL on the
; item after its token and A = it (NextChar's flags); it returns with HL on the statement's end.
ExecuteStatement:
        cp TkEnd
        jr c,.notToken
        cp TkLocate + 1
        jp nc,.otherToken
        sub TkEnd
        add a,a
        ld e,a
        ld d,$00
        push hl
        ld hl,StatementTable
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push de
        rst $10
        ret                             ; to the handler
.notToken:
        cp '_'                          ; _NAME is CALL NAME
        jp z,StatementCallUnderscore
        call IsLetter
        jp c,SyntaxError
        jp StatementLet                 ; an assignment without LET
.otherToken:
        cp TkApostrophe                 ; (stored as ":REM'": reached only through the REM)
        jp z,StatementRem
        cp TkFunction                   ; MID$(...) = ..., STRIG(n) / INTERVAL ON / OFF / STOP
        jp z,StatementFunctionToken
        jp SyntaxError

; IsLetter: carry when A is not a letter A-Z (capitals: the tokenizer makes names capitals).
IsLetter:
        cp 'A'
        ret c
        cp 'Z' + 1
        ccf
        ret

; AtStatementEnd: Z when HL is on the end of the statement (0 or ':'), past spaces; A = the character.
AtStatementEnd  equ ThisChar

; TraceLine: TRON: the line number between brackets.
TraceLine:
        push hl
        ld a,'['
        call OutputChar
        ld hl,(CURLIN)
        call PrintUnsigned
        ld a,']'
        call OutputChar
        pop hl
        ret

; CheckBreak: INTFLG is set: STOP (4) waits for another STOP, CTRL+STOP (3) breaks the program.
CheckBreak:
        cp $03
        jr z,.break
        cp $04
        jr nz,.clear
        xor a                           ; STOP: wait until it is pressed again (or CTRL+STOP)
        ld (INTFLG),a
.pause:
        ei
        halt
        ld a,(INTFLG)
        or a
        jr z,.pause
        cp $03
        jr z,.break
.clear:
        xor a
        ld (INTFLG),a
        ret
.break:
        xor a
        ld (INTFLG),a
        call ClearKeyBuffer
        jp StatementStop.break

; --- the end of things ---

EndDirect:
        jp Ready
EndProgram:
        xor a                           ; (CONT cannot go on past the end)
        ld (OLDTXT),a
        ld (OLDTXT + 1),a
        call CloseAllFiles
        jp Ready

; StatementEnd: END.
StatementEnd:
        ret nz                          ; (END must be alone)
        call CloseAllFiles
        ld (OLDTXT),hl
        ld hl,(CURLIN)
        ld (OLDLIN),hl
        jp Ready

; StatementStop: STOP: "Break in <line>", CONT goes on after it. STOP ON / OFF / STOP: the trap.
StatementStop:
        jr z,.break
        ld a,TrapStop
        jp TrapState
.break:                                 ; (CTRL+STOP too)
        ld (OLDTXT),hl
        ld hl,(CURLIN)
        ld (OLDLIN),hl
        call NewLineIfNeeded
        ld hl,BreakText
        call PrintString
        ld hl,(CURLIN)
        ld a,h
        and l
        inc a
        jr z,.noLine
        call PrintInLine
.noLine:
        call PrintCrLf
        jp Ready
BreakText:
        db "Break",0

; StatementCont: CONT.
StatementCont:
        ret nz
        ld hl,(OLDTXT)
        ld a,h
        or l
        ld e,ErrCantContinue
        jp z,RaiseError
        ld de,(OLDLIN)
        ld (CURLIN),de
        pop de                          ; (the return to NewStatement)
        jp NewStatement

; StatementRem: REM, ' and DATA (DATA is skipped when run): to the end of the line / statement.
StatementRem:
        jp SkipToLineEnd
StatementData:
        jp SkipToStatementEnd

; StatementElse: ELSE reached after the THEN part ran: the rest of the line is skipped.
StatementElse:
        jp SkipToLineEnd

; --- jumps ---

; GetLineNumber: a line number token (0Eh) at HL. Out: DE, HL after it, carry when there is none.
; Destroys AF.
GetLineNumber:
        call ThisChar
        cp $0E
        scf
        ret nz
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        or a
        ret

; FindLine: the line DE. Out: carry and BC = its address when it is there; otherwise BC = the first line
; after it (where it would go). Destroys AF.
FindLine:
        push hl
        ld hl,(TXTTAB)
.line:
        ld b,h
        ld c,l
        ld a,(hl)
        inc hl
        or (hl)
        jr z,.notFound                  ; the end
        inc hl
        ld a,(hl)                       ; the line number
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        rst $20                         ; HL - DE
        pop hl
        jr z,.found
        jr nc,.notFound                 ; already past it
        ld h,b
        ld l,c
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr .line
.found:
        pop hl
        scf
        ret
.notFound:
        pop hl
        or a
        ret

; GotoLine: run from line DE (Undefined line number when it is not there). Keeps the stack.
GotoLine:
        call FindLine
        ld e,ErrUndefinedLine
        jp nc,RaiseError
        ld h,b
        ld l,c
        dec hl                          ; on the 0 before the line: NewStatement reads it from there
        ld bc,$0000
        ld (CURLIN),bc                  ; (not FFFFh: a jump from direct mode runs the program)
        ret

; StatementGoto: GOTO line.
StatementGoto:
        call GetLineNumber
        jp c,SyntaxError
        call GotoLine
        ret                             ; NewStatement goes on from the line

; StatementGosub: GOSUB line.
StatementGosub:
        call GetLineNumber
        jp c,SyntaxError
        pop bc                          ; the return to NewStatement
        dec sp                          ; (the unused byte)
        push hl                         ; the frame: text after the GOSUB, the line, the marker
        ld bc,(CURLIN)
        push bc
        ld bc,TkGosub
        push bc
        call CheckStackRoom
        call GotoLine
        jp NewStatement

; StatementReturn: RETURN [line]. The FOR frames inside the subroutine go with it.
StatementReturn:
        ex de,hl                        ; DE = the text of RETURN
        ld ix,$0002                     ; the frames, after the return address
        add ix,sp
.frame:
        call FrameAtIX                  ; A = marker, carry at the bottom of the stack
        jr c,.none
        cp TkGosub
        jr z,.gosub
        ld bc,ForFrameSize              ; a FOR frame (FrameAtIX knows no other kinds)
        add ix,bc
        jr .frame
.none:
        ld e,ErrReturnWithoutGosub
        jp RaiseError
.gosub:
        ld a,(ix+1)                     ; the GOSUB of a trap: on again
        or a
        call nz,TrapReturned
        ld c,(ix+2)
        ld b,(ix+3)
        ld (CURLIN),bc
        ld l,(ix+4)
        ld h,(ix+5)                     ; HL = the text after the GOSUB
        ld bc,GosubFrameSize
        add ix,bc
        ld sp,ix                        ; the frames and the return address are gone
        ex de,hl
        call AtStatementEnd
        ex de,hl
        jp z,NewStatement
        ex de,hl                        ; RETURN line
        call GetLineNumber
        jp c,SyntaxError
        call GotoLine
        jp NewStatement

; FrameAtIX: the marker of the frame at IX. Out: A = TkGosub or TkFor, carry when IX is at the bottom
; of the stack (STKTOP) or the word there is no frame. Destroys F.
FrameAtIX:
        push hl
        push de
        push ix
        pop hl
        ld de,(STKTOP)
        rst $20                         ; IX - STKTOP
        pop de
        pop hl
        ccf
        ret c
        ld a,(ix+0)
        cp TkGosub
        ret z
        cp TkFor
        ret z
        scf
        ret

; CheckStackRoom: Out of memory when the stack comes near the variables. Destroys AF.
CheckStackRoom:
        push hl
        push de
        ld hl,(STREND)
        ld de,$0050                     ; room for the expression evaluator
        add hl,de
        ex de,hl
        ld hl,$0006
        add hl,sp
        rst $20                         ; SP - (STREND + 50h)
        pop de
        pop hl
        ret nc
        jp OutOfMemory

; StatementIf: IF condition THEN line / statements [ELSE ...], IF condition GOTO line.
StatementIf:
        call EvalExpression
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        call ThisChar
        cp ','                          ; IF x, THEN (allowed)
        jr nz,.noComma
        rst $10
.noComma:
        cp TkGoto
        jr nz,.then
        rst $10                         ; IF x GOTO line: as THEN line
        jr .decided
.then:
        rst $08
        db TkThen
.decided:
        call SignOfDac                  ; true when not 0
        or a
        jr z,.false
.true:                                  ; HL on what follows THEN (or ELSE)
        call ThisChar
        ret z
        cp $0E                          ; a line number: GOTO it
        jp nz,ExecuteStatement
        call GetLineNumber
        call GotoLine
        ret
.false:
        ld d,$01                        ; to this IF's ELSE (nested IFs have their own) or the end
.scan:
        ld a,(hl)
        or a
        ret z
        cp TkElse
        jr nz,.notElse
        dec d
        jr nz,.notElse
        inc hl                          ; past the ELSE
        jr .true
.notElse:
        cp TkIf
        jr nz,.next
        inc d
.next:
        call SkipItem
        jr .scan

; StatementOn: ON ERROR GOTO, ON value GOTO / GOSUB lines. (ON KEY / STRIG / SPRITE / STOP /
; INTERVAL: stage 8.)
StatementOn:
        cp TkError
        jp z,StatementOnError
        call OnTrap
        ret nc
        call ThisChar
        call EvalByte                   ; A = the choice
        ld b,a
        ld a,(hl)
        cp TkGoto
        jr z,.form
        cp TkGosub
        jp nz,SyntaxError
.form:
        ld c,a                          ; C = GOTO or GOSUB
        ld a,b
        or a
        jp z,SkipToStatementEnd         ; 0: nothing
        rst $10
.choose:
        call GetLineNumber
        jp c,SyntaxError
        dec b
        jr z,.found
        call ThisChar
        cp ','
        jp nz,SkipToStatementEnd        ; fewer lines than the value: nothing
        rst $10
        jr .choose
.found:
        push de
        call SkipToStatementEnd         ; a GOSUB comes back after the whole statement
        pop de
        pop af                          ; the return to NewStatement
        ld a,c
        cp TkGosub
        jr nz,.goto
        dec sp                          ; (the GOSUB frame's unused byte)
        push hl
        ld bc,(CURLIN)
        push bc
        ld bc,TkGosub
        push bc
        call CheckStackRoom
.goto:
        call GotoLine
        jp NewStatement

; StatementOnError: ON ERROR GOTO line. 0 turns it off; inside the handler, 0 stops the program with
; the error being handled.
StatementOnError:
        rst $10
        rst $08
        db TkGoto
        call GetLineNumber
        jp c,SyntaxError
        ld (ONELIN),de
        ld a,d
        or e
        ret nz
        ld a,(ONEFLG)
        or a
        ret z
        xor a
        ld (ONEFLG),a
        ld a,(ERRFLG)
        ld e,a
        jp RaiseError

; StatementResume: RESUME, RESUME NEXT, RESUME line.
StatementResume:
        ld a,(ONEFLG)
        or a
        ld e,ErrResumeWithoutError
        jp z,RaiseError
        xor a
        ld (ONEFLG),a
        pop bc                          ; the return to NewStatement
        call AtStatementEnd
        jr z,.again
        cp TkNext
        jr z,.next
        call GetLineNumber
        jp c,SyntaxError
        ld a,d
        or e
        jr z,.again                     ; RESUME 0
        call GotoLine
        jp NewStatement
.again:                                 ; the statement of the error again
        ld de,(ERRLIN)
        ld (CURLIN),de
        ld hl,(ERRTXT)
        jp NewStatement
.next:                                  ; the statement after it
        ld de,(ERRLIN)
        ld (CURLIN),de
        ld hl,(ERRTXT)
        ld a,(hl)
        or a
        jr nz,.colon
        ld bc,$0004                     ; the statement starts a line: past the 0, link and number
        add hl,bc
.colon:
        inc hl
        call SkipToStatementEnd
        jp NewStatement

; --- FOR / NEXT ---

ForLimit        equ SWPTMP              ; the limit while FOR builds its frame (8 bytes)
ForVariable     equ TEMP9               ; the variable's address
ForType         equ TEMP3               ; its type

; StatementFor: FOR variable = start TO limit [STEP step].
StatementFor:
        call StatementLetCore           ; the start into the variable; DE = its address, A = type
        cp TypeString
        jp z,TypeMismatch
        ld (ForVariable),de
        ld (ForType),a
        call ThisChar
        rst $08
        db TkTo
        call EvalNumeric
        ld a,(ForType)
        call ConvertDacTo               ; the limit in the variable's type
        push hl
        ld hl,DAC
        ld de,ForLimit
        ld bc,$0008
        ldir
        pop hl
        call ThisChar
        cp TkStep
        jr nz,.stepOne
        rst $10
        call EvalNumeric
        jr .stepGot
.stepOne:
        ld de,$0001
        call SetIntegerResult
.stepGot:
        ld a,(ForType)
        call ConvertDacTo               ; DAC = the step in the variable's type
        call SkipToStatementEnd         ; the loop starts again after the FOR statement
        pop bc                          ; the return to NewStatement
        ld de,(ForVariable)
        call FindForFrame               ; an open loop of the same variable is closed first
        jr nc,.noOldLoop
        ld bc,ForFrameSize
        add ix,bc
        ld sp,ix
.noOldLoop:
        dec sp                          ; the frame (see the top of this file)
        push hl
        ld bc,(CURLIN)
        push bc
        ld bc,(ForLimit + 6)
        push bc
        ld bc,(ForLimit + 4)
        push bc
        ld bc,(ForLimit + 2)
        push bc
        ld bc,(ForLimit)
        push bc
        ld bc,(DAC + 6)
        push bc
        ld bc,(DAC + 4)
        push bc
        ld bc,(DAC + 2)
        push bc
        ld bc,(DAC)
        push bc
        push de
        ld a,(ForType)
        ld b,a
        ld c,TkFor
        push bc
        call CheckStackRoom
        jp NewStatement

; FindForFrame: the frame of the loop of variable DE (DE = 0: the innermost loop), looking from the stack
; top down to a GOSUB frame or the bottom. Out: carry and IX = the frame when found. Destroys AF, BC.
FindForFrame:
        ld ix,$0002
        add ix,sp                       ; (after this routine's return address)
.frame:
        call FrameAtIX
        ccf
        ret nc                          ; the bottom
        cp TkGosub
        jr z,.notFound
        ld a,d
        or e
        scf
        ret z                           ; any loop will do
        ld a,(ix+2)
        cp e
        jr nz,.other
        ld a,(ix+3)
        cp d
        scf
        ret z
.other:
        ld bc,ForFrameSize
        add ix,bc
        jr .frame
.notFound:
        or a
        ret

; StatementNext: NEXT [variable [, variable ...]].
StatementNext:
        pop bc                          ; the return to NewStatement (the frames are under it)
.variable:
        ld de,$0000
        call AtStatementEnd
        jr z,.find
        call GetVariable                ; DE = the variable's address
.find:
        call FindForFrame
        ld e,ErrNextWithoutFor
        jp nc,RaiseError
        ld sp,ix                        ; inner loops are closed
        push hl                         ; the text after NEXT (the frame is under it now)
        ; variable = variable + step
        ld l,(ix+2)
        ld h,(ix+3)                     ; HL = the variable
        ld a,(ix+1)
        ld (VALTYP),a
        cp TypeInteger
        jr nz,.real
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld l,(ix+6)                     ; the step (an integer at bytes 2-3 of its 8)
        ld h,(ix+7)
        or a
        adc hl,de                       ; (adc: add hl does not tell a signed overflow)
        jp pe,Overflow
        ex de,hl
        pop hl
        ld (hl),d
        dec hl
        ld (hl),e
        ld l,(ix+14)                    ; the limit
        ld h,(ix+15)                    ; DE = variable, HL = limit
        call CompareIntegers            ; A: 1 below, 0 equal, FFh above
        jr .compared
.real:
        push hl
        call ZeroDac
        pop hl
        push hl
        call MoveVtToDac                ; DAC = the variable (4 or 8 bytes)
        push ix
        pop hl
        ld bc,$0004
        add hl,bc
        call MoveToArg                  ; ARG = the step
        call DecAdd
        ld a,(VALTYP)
        cp TypeSingle
        call z,ForceSingle.fromDouble   ; (rounded to 6 digits again)
        pop hl
        push hl
        call MoveVtDacTo                ; the variable = DAC
        call MoveDacToArg               ; ARG = the variable
        ld hl,$0000
        ld (DAC + 4),hl                 ; (a single precision limit: 8 clean bytes)
        ld (DAC + 6),hl
        push ix
        pop hl
        ld bc,$000C
        add hl,bc
        call MoveVtToDac                ; DAC = the limit
        call CompareDoubles             ; A: 1 when the variable is below the limit
        pop hl
.compared:
        ld b,a
        ld a,(ix+1)                     ; the step's sign
        cp TypeInteger
        ld a,(ix+7)
        jr z,.stepSign
        ld a,(ix+4)
.stepSign:
        rla                             ; carry: a negative step
        ld a,b
        jr c,.downwards
        cp $FF                          ; upwards: done when above the limit
        jr .decide
.downwards:
        cp $01                          ; downwards: done when below
.decide:
        pop hl                          ; the text after NEXT
        jr z,.loopDone
        ld l,(ix+22)                    ; again: from the FOR
        ld h,(ix+23)
        ld e,(ix+20)
        ld d,(ix+21)
        ld (CURLIN),de
        jp NewStatement
.loopDone:
        ld bc,ForFrameSize
        add ix,bc
        ld sp,ix                        ; the frame goes
        call ThisChar
        cp ','
        jp nz,NewStatement
        rst $10
        jp .variable

; --- errors ---

SyntaxError:
        ld e,ErrSyntax
        jp RaiseError
TypeMismatch:
        ld e,ErrTypeMismatch
        jp RaiseError
IllegalFunction:
        ld e,ErrIllegal
        jp RaiseError
OutOfMemory:
        ld e,ErrOutOfMemory
        jp RaiseError
Overflow:
        ld e,ErrOverflow
        jp RaiseError
