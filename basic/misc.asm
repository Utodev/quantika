; misc.asm: SOUND, TIME =, VDP() =, MID$() =, LINE INPUT, ERASE, DEF USR / USR, DEF FN / FN.

; StatementSound: SOUND register, value (register 7 keeps the joystick port's direction bits).
StatementSound:
        call EvalByte
        cp 14
        jp nc,IllegalFunction
        push af
        call Comma
        call EvalByte
        ld e,a
        pop af
        cp PsgMixer
        jr nz,.write
        ld a,e
        and $3F
        or $80                          ; port A in, port B out
        ld e,a
        ld a,PsgMixer
.write:
        jp WritePsg

; StatementTime: TIME = value (the frame counter).
StatementTime:
        call ThisChar
        rst $08
        db TkEqual
        call EvalAddress
        ld (JIFFY),de
        ret

; StatementVdp: VDP(n) = value: a VDP register (n as VDP() reads them: 0-7, 9-24 for 8-23).
StatementVdp:
        call ParenInteger
        push de
        call ThisChar
        rst $08
        db TkEqual
        call EvalByte
        pop de
        ld b,a
        ld a,e
        cp $08
        jr c,.register
        jp z,IllegalFunction            ; (8 is the status: read only)
        cp 25
        jp nc,IllegalFunction
        dec a
.register:
        ld c,a
        jp WriteVdpReg

; StatementMidAssign: MID$(variable, start [, count]) = string: characters of the variable replaced.
; The variable's characters are made its own (in the string space) before the rest is worked out; its
; descriptor is read again at the end (a garbage collection may move them).
MidVariable     equ TEMP2                ; the variable's descriptor
MidStart        equ TEMP3                ; start (from 1), count
StatementMidAssign:
        inc hl                          ; past FFh: the MID$ token
        ld a,(hl)
        cp FnMidStr
        jp nz,SyntaxError
        rst $10
        call ThisChar
        rst $08
        db '('
        call GetVariable
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        ex de,hl
        call IsInStringSpace            ; (a literal of the program: changed in a copy, not there)
        jr nc,.inSpace
        push de
        call CopyVariableString
        pop de
.inSpace:
        ex de,hl
        push de                         ; the descriptor
        call Comma
        call EvalByte
        or a
        jp z,IllegalFunction
        ld c,a                          ; start
        ld b,$FF                        ; count
        push bc
        call ThisChar
        cp ','
        jr nz,.closed
        rst $10
        call EvalByte
        pop bc
        ld b,a
        push bc
.closed:
        call CloseBracket
        rst $08
        db TkEqual
        call EvalExpression
        pop bc
        ld (MidStart),bc
        pop de
        ld (MidVariable),de
        push hl
        call StringOperand              ; B = the new text's length, DE = its characters
        ld hl,(MidVariable)
        ld a,(hl)                       ; the variable's length
        inc hl
        ld c,(hl)
        inc hl
        ld h,(hl)
        ld l,c                          ; HL = its characters
        ld c,a
        ld a,(MidStart)
        dec a                           ; skipped
        cp c
        jp nc,IllegalFunction           ; it starts after the end
        push de
        ld e,a
        ld d,$00
        add hl,de                       ; where the new characters go
        neg
        add a,c                         ; room after the start
        pop de
        cp b
        jr c,.roomLess
        ld a,b                          ; the new text is shorter
.roomLess:
        ld b,a
        ld a,(MidStart + 1)             ; and the count
        cp b
        jr nc,.counted
        ld b,a
.counted:
        ld a,b
        or a
        jr z,.done
        ex de,hl
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
.done:
        pop hl
        ret

; IsInStringSpace: no carry when the characters of descriptor HL are in the string space. Keeps HL.
IsInStringSpace:
        push hl
        push de
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(STKTOP)
        ex de,hl
        rst $20                         ; characters - STKTOP
        pop de
        pop hl
        ret

; CopyVariableString: the characters of descriptor HL copied into the string space. Keeps HL.
CopyVariableString:
        push hl
        ld b,(hl)
        ld a,b
        or a
        jr z,.done
        push hl
        call AllocString                ; DE = the room
        pop hl
        push hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push de
        ld c,b
        ld b,$00
        ldir
        pop de
        pop hl
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
.done:
        pop hl
        ret

; StatementLineInput: LINE INPUT [;] ["prompt";] string variable: the whole typed line (LINE INPUT #:
; a line of a file).
StatementLineInput:
        rst $10                         ; past INPUT
        cp '#'
        jp z,LineInputFile              ; (LINE INPUT #: basic/files.asm)
        cp ';'
        jr nz,.noSemicolon
        rst $10
.noSemicolon:
        cp '"'
        jr nz,.noPrompt
        call StringLiteral
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
        rst $08
        db ';'
.noPrompt:
        call GetVariable
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        push hl
        push de
        call InputLineAtCursor
        jr nc,.got
        pop de
        pop hl
        jp StatementStop.break
.got:
        inc hl                          ; BUF
        call StringFromZeroEnded
        pop de
        ld a,TypeString
        call AssignValue
        pop hl
        ret

; StatementLine: LINE INPUT, or the graphic LINE (graphics.asm).
StatementLine:
        cp TkInput
        jr z,StatementLineInput
        jp StatementLineGraphic

; StatementErase: ERASE array [, array ...]: the arrays go, the ones after them move down.
StatementErase:
        call ThisChar
        call IsLetter
        jp c,SyntaxError
        ld c,a
        ld b,$00
        inc hl
        ld a,(hl)
        call IsNameChar
        jr c,.nameDone
        ld b,a
.skipName:
        inc hl
        ld a,(hl)
        call IsNameChar
        jr nc,.skipName
.nameDone:
        ld e,TypeString                 ; the type, as GetVariable finds it
        cp '$'
        jr z,.suffix
        ld e,TypeInteger
        cp '%'
        jr z,.suffix
        ld e,TypeSingle
        cp '!'
        jr z,.suffix
        ld e,TypeDouble
        cp '#'
        jr z,.suffix
        push hl
        ld a,c
        sub 'A'
        ld e,a
        ld d,$00
        ld hl,DEFTBL
        add hl,de
        ld e,(hl)
        pop hl
        jr .typed
.suffix:
        inc hl
.typed:
        push hl                         ; the text
        ld d,e                          ; D = type
        ld hl,(ARYTAB)
.search:
        push de
        ld de,(STREND)
        rst $20                         ; past the last array: there is none
        pop de
        jp nc,IllegalFunction
        ld a,(hl)
        cp d
        jr nz,.next
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.next
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp b
        jr z,.found
.next:
        push de
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        add hl,de
        pop de
        jr .search
.found:
        push hl                         ; its start
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        add hl,de                       ; HL = the next array
        ex de,hl
        pop hl                          ; HL = the start, DE = the next
        push hl
        ld hl,(STREND)
        or a
        sbc hl,de                       ; bytes after it
        ld b,h
        ld c,l
        pop hl
        push hl
        ex de,hl                        ; HL = the next, DE = the start
        ld a,b
        or c
        jr z,.moved
        ldir
.moved:
        ld (STREND),de
        pop hl
        pop hl
        call ThisChar
        cp ','
        ret nz
        rst $10
        jp StatementErase

; --- DEF USR / USR, DEF FN / FN ---

; StatementDef: DEF USR[n] = address, DEF FNname[(parameters)] = expression.
StatementDef:
        cp TkUsr
        jr z,.usr
        cp TkFn
        jp z,DefFn
        jp SyntaxError
.usr:
        rst $10
        call UsrNumber                  ; DE = the USRTAB entry
        push de
        call ThisChar
        rst $08
        db TkEqual
        call EvalAddress
        ex (sp),hl                      ; (the text pointer stays on the stack)
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ret

; UsrNumber: the digit after USR (0 when there is none). Out: DE = its USRTAB entry, HL past it.
UsrNumber:
        call ThisChar
        ld e,$00
        cp $11                          ; a digit is a number token 11h-1Ah
        jr c,.got
        cp $1A + 1
        jr nc,.got
        sub $11
        ld e,a
        inc hl
.got:
        ld a,e
        add a,a
        ld e,a
        ld d,$00
        push hl
        ld hl,USRTAB
        add hl,de
        ex de,hl
        pop hl
        ret

; OperandUsr: USR[n](argument): calls the machine code at USRTAB n with the argument in DAC (VALTYP)
; and HL = DAC; the routine leaves its result there.
OperandUsr:
        call UsrNumber
        push de
        call ThisChar
        rst $08
        db '('
        call EvalExpression
        call CloseBracket
        pop de
        push hl
        ex de,hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                        ; HL = the routine
        ld de,.back
        push de
        push hl
        ld hl,DAC
        ret                             ; to it, HL = DAC
.back:
        pop hl
        ret

; DefFn: DEF FNname[(parameters)] = expression. The definition is kept as a simple variable whose
; first character has bit 7 set; its 2-byte value is the address of the text after the name.
DefFn:
        ld a,(CURLIN + 1)               ; Illegal direct
        and $80
        jr z,.inProgram
        ld a,(CURLIN)
        inc a
        ld e,ErrIllegalDirect
        jp z,RaiseError
.inProgram:
        rst $10                         ; past FN
        call FnVariable                 ; DE = the definition's value (created if new)
        ex de,hl
        ld (hl),e                       ; the text after the name
        inc hl
        ld (hl),d
        ex de,hl
        jp SkipToStatementEnd

; FnVariable: the variable of the function named at HL. Out: DE = its 2-byte value, A = the function's
; type, HL past the name.
FnVariable:
        call GetVariableName            ; C, B = the name, A = type, HL past it
        push af
        set 7,c
        ld a,TypeInteger                ; the definition is kept as a 2-byte value
        ld (VALTYP),a
        call FindOrMakeSimple
        pop af
        ret

; OperandFn: FNname[(arguments)]: each parameter (a variable of the definition) takes its argument;
; its value before is kept on the stack and put back once the definition's expression is worked out.
; A kept parameter on the stack: its type (AF), its address, its 8 bytes.
FnDefinition    equ PRMPRV               ; the definition's text while the parameters are set
FnCall          equ PRMPRV + 2           ; ... and the call's (PRMPRV, PRMLN2: free in this BASIC)

OperandFn:
        call FnVariable
        push af                         ; the function's type
        ex de,hl                        ; DE = the call
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld h,b
        ld l,c                          ; HL = the definition
        ld a,h
        or l
        jr nz,.defined
        ld e,ErrUndefinedFunction
        jp RaiseError
.defined:
        ld c,$00                        ; C = parameters kept
        ld a,(hl)
        cp '('
        jp nz,.expression
        ex de,hl
        call ThisChar
        ex de,hl
        cp '('
        jp nz,SyntaxError
.parameter:
        push bc
        push hl                         ; the definition (on its '(' or ',')
        ex de,hl
        rst $10
        call EvalExpression             ; the argument (more FNs may run here)
        ex de,hl
        pop hl
        push de                         ; the call
        ld a,(VALTYP)
        push af                         ; the argument's type
        rst $10
        call GetVariable                ; the parameter: DE = its value, VALTYP = its type
        ld (FnDefinition),hl
        ld a,(VALTYP)
        ld c,a                          ; C = the parameter's type
        pop af
        ld (VALTYP),a                   ; the argument's type again
        pop hl
        ld (FnCall),hl
        pop hl                          ; (the count, as BC)
        ld a,l
        push af                         ; (the count in A for now)
        ; keep the parameter: its 8 bytes, its address, its type (under the count, popped first)
        pop af
        ld b,a                          ; B = count
        ld a,c
        ex de,hl                        ; HL = the parameter's value
        push bc
        ld de,FnKeep
        ld bc,$0008
        push hl
        ldir
        pop de                          ; DE = the parameter's value
        pop bc
        ld hl,(FnKeep + 6)
        push hl
        ld hl,(FnKeep + 4)
        push hl
        ld hl,(FnKeep + 2)
        push hl
        ld hl,(FnKeep)
        push hl
        push de                         ; its address
        push af                         ; its type
        inc b
        ld c,b                          ; C = parameters kept
        push bc
        call AssignValue                ; the argument into it (A = its type, DE = it)
        pop bc
        ld hl,(FnDefinition)
        ld de,(FnCall)
        call ThisChar
        cp ','
        jr nz,.lastParameter
        ex de,hl
        call ThisChar
        ex de,hl
        cp ','
        jp nz,SyntaxError
        jr .parameter
.lastParameter:
        cp ')'
        jp nz,SyntaxError
        ex de,hl
        call ThisChar
        ex de,hl
        cp ')'
        jp nz,SyntaxError
        inc hl
        inc de
.expression:
        push de                         ; the call
        push bc                         ; the count
        call ThisChar
        rst $08
        db TkEqual
        call EvalExpression
        pop bc
        pop de
        ; the parameters back
        ld a,c
        or a
        jr z,.restored
        ld b,c
.restore:
        pop af                          ; type
        pop hl                          ; address
        ld (FnKeep + 8),hl
        pop hl
        ld (FnKeep),hl
        pop hl
        ld (FnKeep + 2),hl
        pop hl
        ld (FnKeep + 4),hl
        pop hl
        ld (FnKeep + 6),hl
        push de
        push bc
        ld hl,FnKeep
        ld de,(FnKeep + 8)
        ld c,a
        ld b,$00
        ldir                            ; only the bytes of its type
        pop bc
        pop de
        djnz .restore
.restored:
        pop af                          ; the function's type
        push de
        call ConvertResult
        pop hl                          ; the call's text, past it
        ret
FnKeep          equ HOLD                ; 10 bytes: a parameter's value and address while moved

; ConvertResult: DAC to type A (a string must be a string).
ConvertResult:
        cp TypeString
        jp nz,ConvertDacTo
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        ret

; StatementBase: BASE(n) = address: the address of table n MOD 5 (names, colours, patterns, sprite
; attributes, sprite patterns) of SCREEN n / 5 (0-3), kept at TXTNAM + 2n; it must be where the VDP can
; have that table (an Illegal function call otherwise, as the original).
StatementBase:
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld a,e
        cp 20
        jp nc,IllegalFunction
        push de
        call ThisChar
        rst $08
        db TkEqual
        call EvalAddress                ; DE
        ex (sp),hl                      ; HL = n, the text on the stack
        push hl
        ld a,l                          ; the table's alignment: a mask the address must not touch
        ld c,0
.mode:
        sub 5
        jr c,.table
        inc c
        jr .mode
.table:
        add a,5                         ; A = table, C = mode
        add a,a
        ld l,a
        ld h,0
        push de
        ld de,BaseMasks
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; DE = the mask
        ld a,c                          ; SCREEN 2's colours and patterns: 0 or 2000h
        cp 2
        jr nz,.masked
        ld a,l
        sub low BaseMasks + 2
        cp 4
        jr nc,.masked
        ld de,$1FFF
.masked:
        pop hl                          ; HL = the address
        ld a,l
        and e
        jp nz,IllegalFunction
        ld a,h
        and d
        jp nz,IllegalFunction
        ex de,hl                        ; DE = the address
        pop hl                          ; n
        push hl
        add hl,hl
        ld bc,TXTNAM
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl                          ; the current mode's table: the VDP follows at once
        ld a,l
        ld c,0
.ofMode:
        sub 5
        jr c,.modeFound
        inc c
        jr .ofMode
.modeFound:
        ld a,(SCRMOD)
        cp c
        jr nz,.done
        ld hl,BaseSetters
        add a,a
        add a,l
        ld l,a
        jr nc,.setter
        inc h
.setter:
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call .jump
.done:
        pop hl
        ret
.jump:
        jp (hl)
BaseSetters:
        dw SetText40, SetText32, SetGraphic, SetMulticolour
BaseMasks:                              ; names, colours, patterns, sprite attributes, sprite patterns
        dw $03FF, $003F, $07FF, $007F, $07FF
