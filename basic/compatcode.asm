; compatcode.asm: the routines behind the fixed entries of basic/compat.asm.

; CompatRunProgram: 73ACh: relink the program in memory, clear the variables and run it from its start.
CompatRunProgram:
        ld sp,(STKTOP)
        call LinkLines
        call ClearVariables
        ld hl,(TXTTAB)
        dec hl
        ld bc,$0000
        ld (CURLIN),bc
        jp NewStatement

; CompatGetByte: 521Ch: a number 0-255 from the text at HL (Illegal function call if it is not). Out: A = E
; = it, D = 0, HL at the character after it, the flags as ThisChar leaves them for that character. IX
; and IY kept, as the original keeps them (the callers' own pointers may be there).
CompatGetByte:
        push ix
        push iy
        call EvalByte
        pop iy
        pop ix
        ld e,a
        ld d,$00
        call ThisChar
        jr nz,.flags
        or a                            ; the end of the line: its flags as the original leaves them
        jr z,.flags
        cp ':'                          ; (a ':' as ThisChar's)
.flags:
        ld a,e
        ret

; CompatStmt...: the statement handlers of basic/compat.asm's fixed entries: the character at HL first (A,
; the flags), as the interpreter enters a handler.
CompatStmtLine:
        call ThisChar
        jp StatementLine
CompatStmtPreset:
        call ThisChar
        jp StatementPreset
CompatStmtPset:
        call ThisChar
        jp StatementPset
CompatStmtPaint:
        call ThisChar
        jp StatementPaint
CompatStmtCircle:
        call ThisChar
        jp StatementCircle
CompatStmtDraw:
        call ThisChar
        jp StatementDraw
CompatStmtColor:
        call ThisChar
        jp StatementColor
