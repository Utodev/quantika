; errors.asm: BASIC errors: the handler (ON ERROR or the message, then Ok) and the messages.

; RaiseError: In: E = error code. Never returns.
RaiseError:
        ld hl,$0000                     ; (PRINT # ends)
        ld (PTRFIL),hl
        ld a,e
        ld (ERRFLG),a
        ld hl,(CURLIN)
        ld (ERRLIN),hl
        ld hl,(SAVTXT)
        ld (ERRTXT),hl
        xor a                           ; CONT cannot go on after an error
        ld (OLDTXT),a
        ld (OLDTXT + 1),a
        call H_ERRO                     ; (E = the code: the disk ROM and others look at errors here)
        ld hl,(ONELIN)                  ; (in direct mode too, as the original: an ON ERROR left set by the
                                        ; program takes the errors of the lines typed after it)
        ld a,h
        or l
        jr z,.message                   ; no ON ERROR
        ld a,(ONEFLG)
        or a
        jr nz,.message                  ; an error inside the handler
        inc a
        ld (ONEFLG),a
        ld sp,(SAVSTK)                  ; the stack as the statement found it
        ex de,hl
        call GotoLine
        jp NewStatement
.message:
        ld sp,(STKTOP)
        call ForceTextMode              ; (the message in a text mode)
        call NewLineIfNeeded
        ld a,(ERRFLG)
        call ErrorText
        call PrintString
        ld hl,(ERRLIN)
        ld a,h
        and l
        inc a
        call nz,PrintInLine
        call PrintCrLf
        jp Ready

; PrintInLine: " in <line HL>". Destroys all.
PrintInLine:
        push hl
        ld hl,InText
        call PrintString
        pop hl
        jp PrintUnsigned
InText:
        db " in ",0

; ErrorText: HL = the message of error A (zero ended), or "Unprintable error". Destroys AF, B.
ErrorText:
        ld hl,ErrorMessages
        ld b,a
        or a
        jr z,.unprintable
        cp 26
        jr c,.find                      ; 1-25
        cp 50
        jr c,.unprintable
        cp 73
        jr nc,.unprintable
        sub 50 - 26                     ; 50-72 follow 1-25 in the table
        ld b,a
        jr .find
.unprintable:
        ld b,ErrUnprintable
.find:
        dec b
        ret z
.skip:
        ld a,(hl)
        inc hl
        or a
        jr nz,.skip
        jr .find

MathOverflow:
        ld e,ErrOverflow
        jp RaiseError
MathDivisionByZero:
        ld e,ErrDivision
        jp RaiseError
MathTypeMismatch:
        ld e,ErrTypeMismatch
        jp RaiseError
MathNotYet:                             ; a Math-Pack entry not written yet
        ret

ErrorMessages:                          ; 1-25, then 50-72
        db "NEXT without FOR",0
        db "Syntax error",0
        db "RETURN without GOSUB",0
        db "Out of DATA",0
        db "Illegal function call",0
        db "Overflow",0
        db "Out of memory",0
        db "Undefined line number",0
        db "Subscript out of range",0
        db "Redimensioned array",0
        db "Division by zero",0
        db "Illegal direct",0
        db "Type mismatch",0
        db "Out of string space",0
        db "String too long",0
        db "String formula too complex",0
        db "Can't CONTINUE",0
        db "Undefined user function",0
        db "Device I/O error",0
        db "Verify error",0
        db "No RESUME",0
        db "RESUME without error",0
        db "Unprintable error",0
        db "Missing operand",0
        db "Line buffer overflow",0
        db "FIELD overflow",0
        db "Internal error",0
        db "Bad file number",0
        db "File not found",0
        db "File already open",0
        db "Input past end",0
        db "Bad file name",0
        db "Direct statement in file",0
        db "Sequential I/O only",0
        db "File not OPEN",0
        db "Bad FAT",0
        db "Bad file mode",0
        db "Bad drive name",0
        db "Bad sector number",0
        db "File still open",0
        db "File already exists",0
        db "Disk full",0
        db "Too many files",0
        db "Disk write protected",0
        db "Disk I/O error",0
        db "Disk offline",0
        db "Rename across disk",0
        db "File write protected",0
