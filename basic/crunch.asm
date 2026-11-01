; crunch.asm: the tokenizer: a typed line (text) into tokens in KBUF. Keywords are found at every letter
; (also inside names, as the original BASIC does: TOTAL is TO TAL), the longest first; spaces stay; numbers become
; number tokens (FIN reads them), or line numbers (0Eh) after the statements that take them; strings,
; and the text after REM, ' and DATA, are copied as they are; letters outside them become capitals. The name
; after CALL or _ is kept as it is, in capitals (CALL FORMAT: no FOR in it), as the original BASIC does.

CrunchRaw       equ 0                   ; to the end of the line as it is (REM, ')
CrunchData      equ 1                   ; as it is up to a ':' outside quotes (DATA)
CrunchLine      equ 2                   ; numbers are line numbers
CrunchName      equ 3                   ; inside a name: digits are part of it
CrunchQuote     equ 4                   ; inside quotes in DATA
CrunchCall      equ 5                   ; the name after CALL or _: its letters as they are (no keywords)

; Crunch: In: HL = the text (zero ended). Out: KBUF = the tokens and a 0, B = their bytes (with the 0).
; Line buffer overflow when they do not fit. Destroys all.
Crunch:
        ld de,KBUF
        ld c,$00                        ; C = the state bits above
.next:
        ld a,(hl)
        or a
        jp z,.end
        bit CrunchRaw,c
        jp nz,.copy
        bit CrunchData,c
        jr z,.notData
        cp '"'
        jr nz,.dataNotQuote
        ld a,c
        xor 1 << CrunchQuote
        ld c,a
        ld a,'"'
        jp .copy
.dataNotQuote:
        cp ':'
        jp nz,.copy
        bit CrunchQuote,c
        jp nz,.copy
        ld c,$00                        ; the DATA ends here
        jp .copy
.notData:
        bit CrunchCall,c
        jr z,.notCall
        cp ' '
        jr nz,.callNotSpace
        bit CrunchName,c
        jr z,.notCall                   ; (the spaces before the name)
        jr .callEnds
.callNotSpace:
        call UpperCase
        call IsLetter
        jp nc,.plainLetter
        cp '0'
        jr c,.callEnds
        cp '9' + 1
        jr c,.callChar                  ; (a digit of the name)
.callEnds:
        res CrunchCall,c
.callChar:
        ld a,(hl)
.notCall:
        cp '_'
        jr nz,.notUnderscore
        set CrunchCall,c
        res CrunchName,c
        jp .copy
.notUnderscore:
        cp '"'
        jp z,.string
        cp ' '
        jp nz,.notSpace
        res CrunchName,c
        jp .copy
.notSpace:
        cp '?'
        jr nz,.notQuestion
        ld a,TkPrint
        jp .emitToken
.notQuestion:
        cp $27                          ; '
        jr nz,.notApostrophe
        ld a,':'
        call .put
        ld a,TkRem
        call .put
        ld a,TkApostrophe
        set CrunchRaw,c
        jp .emit
.notApostrophe:
        call UpperCase
        call IsLetter
        jr c,.notLetter
        push de
        call MatchKeyword               ; A = token, B = 80h for a function, HL past it
        pop de
        jr c,.plainLetter
        bit 7,b
        jr z,.statementToken
        push af                         ; FFh, token
        ld a,TkFunction
        call .put
        pop af
        res CrunchLine,c
        res CrunchName,c
        jp .emitAfter
.statementToken:
        res CrunchName,c
        cp TkElse                       ; ELSE is stored as ':' ELSE
        jr nz,.notElse
        push af
        ld a,':'
        call .put
        pop af
.notElse:
        call .lineNumbersAfter          ; C: line number mode for the right statements
        cp TkRem
        jr nz,.notRem
        set CrunchRaw,c
.notRem:
        cp TkData
        jr nz,.notDataToken
        set CrunchData,c
.notDataToken:
        cp TkCall
        jr nz,.notCallToken
        set CrunchCall,c
.notCallToken:
        jp .emitAfter
.plainLetter:
        ld a,(hl)
        call UpperCase
        set CrunchName,c
        res CrunchLine,c
        jp .copyUpper
.notLetter:
        cp '0'
        jr c,.notDigit
        cp '9' + 1
        jr nc,.notDigit
        bit CrunchName,c
        jp nz,.copy                     ; a digit of a name
        bit CrunchLine,c
        jp nz,.lineNumber
        jp .number
.notDigit:
        cp '.'
        jp z,.number
        cp '&'
        jp z,.radix
        res CrunchName,c
        push hl
        ld hl,CrunchOperators
.operator:
        ld b,a
        ld a,(hl)
        inc hl
        or a
        jr z,.noOperator
        cp b
        ld a,b
        jr z,.isOperator
        inc hl
        jr .operator
.isOperator:
        ld a,(hl)
        pop hl
        cp TkMinus
        jr z,.keepLine                  ; (LIST 10-20)
        res CrunchLine,c
.keepLine:
        jr .emitToken
.noOperator:
        ld a,b                          ; the character again
        pop hl
        cp ','
        jr z,.copy                      ; (GOTO 10, 20: still line numbers)
        res CrunchLine,c
        jr .copy
.string:
        call .put                       ; the quote, then all up to the next one
        inc hl
.stringChar:
        ld a,(hl)
        or a
        jp z,.next
        call .put
        inc hl
        cp '"'
        jr nz,.stringChar
        jp .next
.copyUpper:
        call UpperCase
.copy:
        call .put
        inc hl
        jp .next
.emitToken:
        res CrunchName,c
.emit:
        call .put
        inc hl
        jp .next
.emitAfter:                             ; a keyword: HL is already past it
        call .put
        jp .next
.end:
        xor a
        call .put
        ex de,hl
        ld de,KBUF
        or a
        sbc hl,de
        ld b,l                          ; (at most 255)
        ret
; .put: A into KBUF (Line buffer overflow past its end). Keeps all but DE.
.put:
        ld (de),a
        inc de
        push af
        push hl
        ld hl,KBUF + 255
        rst $20                         ; KBUF end - DE
        pop hl
        jr c,.overflow
        pop af
        ret
.overflow:
        ld e,ErrLineBufferOverflow
        jp RaiseError
; .lineNumbersAfter: line number mode after GOTO, GOSUB, THEN, ELSE, RUN, LIST, LLIST, RESTORE, RESUME,
; DELETE, RENUM, AUTO (A = the token). Keeps A.
.lineNumbersAfter:
        push hl
        push af
        ld hl,LineNumberTokens
        ld b,a
.find:
        ld a,(hl)
        inc hl
        or a
        jr z,.notOne
        cp b
        jr nz,.find
        set CrunchLine,c
        jr .listed
.notOne:
        res CrunchLine,c
.listed:
        pop af
        pop hl
        ret
.lineNumber:                            ; digits as a line number (0Eh)
        push de
        ld de,$0000
.lineDigit:
        ld a,(hl)
        sub '0'
        jr c,.lineDone
        cp 10
        jr nc,.lineDone
        push hl
        ld h,d
        ld l,e
        add hl,hl
        jr c,.lineTooBig
        add hl,hl
        jr c,.lineTooBig
        add hl,de
        jr c,.lineTooBig
        add hl,hl
        jr c,.lineTooBig
        ld e,a
        ld d,$00
        add hl,de
        jr c,.lineTooBig
        ex de,hl
        pop hl
        inc hl
        jr .lineDigit
.lineTooBig:
        jp SyntaxError
.lineDone:
        ld b,d
        ld a,e
        pop de
        push af
        ld a,$0E
        call .put
        pop af
        call .put
        ld a,b
        call .put
        jp .next
.number:
        push de
        push bc
        push hl
        ld a,(hl)
        call FinNumber                  ; DAC, HL past the number
        pop de                          ; (the number's start)
.backOverSpaces:                        ; the spaces after it stay in the line
        dec hl
        ld a,(hl)
        cp ' '
        jr nz,.afterSpaces
        rst $20                         ; still after the start?
        jr nz,.backOverSpaces
.afterSpaces:
        inc hl
        pop bc
        pop de
        ld a,(VALTYP)
        cp TypeInteger
        jr z,.integer
        push hl
        ld hl,DAC
        ld b,$04
        cp TypeSingle
        ld a,$1D
        jr z,.realToken
        ld b,$08
        ld a,$1F
.realToken:
        call .put
.realByte:
        ld a,(hl)
        call .put
        inc hl
        djnz .realByte
        pop hl
        jp .next
.integer:
        push hl
        ld hl,(DAC + 2)
        ld a,h
        or a
        jr nz,.word
        ld a,l
        cp 10
        jr nc,.byte
        add a,$11                       ; 0-9: one byte
        call .put
        pop hl
        jp .next
.byte:
        ld a,$0F                        ; 10-255
        call .put
        ld a,l
        call .put
        pop hl
        jp .next
.word:
        ld a,$1C
.wordToken:
        call .put
        ld a,l
        call .put
        ld a,h
        call .put
        pop hl
        jp .next
.radix:
        inc hl                          ; &H, &O (and & alone): a word; &B stays as text
        ld a,(hl)
        dec hl
        call UpperCase
        cp 'B'
        jr nz,.notBinary
        ld a,'&'
        call .put
        inc hl
        ld a,'B'
        call .put
        inc hl
.binaryDigit:
        ld a,(hl)
        cp '0'
        jp c,.next
        cp '2'
        jp nc,.next
        call .put
        inc hl
        jr .binaryDigit
.notBinary:
        ld b,$0C
        cp 'H'
        jr z,.radixNumber
        ld b,$0B
.radixNumber:
        push bc
        push de
        call FinNumber                  ; (FIN reads &H, &O)
        pop de
        pop bc
        push hl
        ld hl,(DAC + 2)
        ld a,b
        jr .wordToken

; MatchKeyword: the keyword that starts at HL (A = its first letter, a capital), the longest one of its
; letter's block in the standard's table (basic/kwtable.asm: there LOC comes before LOCATE).
; Out: carry when there is none; else A = token, B bit 7 = a function (FFh before it), HL past it.
; Destroys DE (keeps C).
MatchKeyword:
        push bc
        push ix
        push hl
        sub 'A'
        add a,a
        ld e,a
        ld d,$00
        ld hl,StdKeywordIndex
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; DE = the block of this letter
        pop hl
        ld ix,$0000                     ; IXh = the letters after the first of the longest, IXl = its token
.entry:
        ld a,(de)
        or a
        jr z,.done
        push hl
        inc hl                          ; (the first letter is the block's)
        ld b,$00                        ; B = letters matched
.letter:
        ld a,(hl)
        call UpperCase
        ld c,a
        ld a,(de)
        and $7F
        cp c
        jr nz,.differ
        inc b
        inc hl
        ld a,(de)
        inc de
        rla                             ; bit 7: the last one
        jr nc,.letter
        ld a,ixh                        ; the whole word: the longest so far?
        cp b
        jr nc,.shorter
        ld ixh,b
        ld a,(de)
        ld ixl,a
.shorter:
        inc de                          ; past the token
        pop hl
        jr .entry
.differ:
        ld a,(de)                       ; past the rest of this one and its token
        inc de
        rla
        jr nc,.differ
        inc de
        pop hl
        jr .entry
.done:
        ld a,ixh
        or a
        jr z,.none
        inc hl                          ; HL past the word
        ld e,a
        ld d,$00
        add hl,de
        ld a,ixl                        ; the token: below 80h a function's (FFh, 80h + it)
        ld d,$00
        cp $80
        jr nc,.statement
        or $80
        ld d,$80
.statement:
        pop ix
        pop bc
        ld b,d
        or a
        ret
.none:
        pop ix
        pop bc
        scf
        ret

; UpperCase: A in capitals when it is a small letter.
UpperCase:
        cp 'a'
        ret c
        cp 'z' + 1
        ret nc
        sub $20
        ret

CrunchOperators:                        ; character, token
        db '>', TkGreater, '=', TkEqual, '<', TkLess, '+', TkPlus, '-', TkMinus, '*', TkTimes
        db '/', TkSlash, '^', TkPower, $5C, TkBackslash, 0

LineNumberTokens:                       ; numbers after these are line numbers
        db TkGoto, TkGosub, TkThen, TkElse, TkRun, TkList, TkLlist, TkRestore, TkResume, TkDelete
        db TkRenum, TkAuto, 0
