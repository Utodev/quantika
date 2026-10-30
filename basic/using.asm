; using.asm: PRINT USING format; values. The format is copied to BUF (the values' expressions may move
; the strings); its characters are printed as they are up to a field, a field takes the next value, and
; the format starts again from its beginning while values remain. The fields:
;   !            the first character of a string          &      the whole string
;   \  \         as many characters as the backslashes and the spaces between them
;   # . ,        a number: digits before the point (a comma among them: thousands with commas), the
;                point, digits after it (rounded half up)
;   + before     the sign always (+ or -), before the digits;  - or + after: the sign after the number
;   ** before    the spaces before the number as asterisks;  $$ before: a dollar sign just before it;
;   **$          both
;   ^^^^ after   with an exponent (E+nn)
; A number that does not fit is printed whole after a %. A format without any field is an Illegal
; function call (after its characters are printed).
;
; Numbers are made double precision; their 14 BCD digits are spread as characters in FBUFFR and rounded
; there (the value is 0.D0 D1 ... D13 times 10 ^ UsingExp).

UsingPos        equ CPCNT               ; (the CIRCLE work area: not in use) where in the format
UsingLeft       equ CPCNT + 2           ; characters left of the format
UsingLength     equ CPCNT + 3           ; the format's length
UsingFlags      equ CPCNT + 4           ; bit 0 a field seen, bit 1 no values left, bit 2 no new line
UsingKind       equ CPCNT + 5           ; the field: see UsingKind* below
UsingIntPos     equ CPCNT + 6           ; the places before the point (signs, $, *, # and commas)
UsingHashes     equ CPCNT + 7           ; the # before the point
UsingFraction   equ CPCNT + 8           ; the # after the point
UsingText       equ CPCNT + 9           ; the BASIC text
UsingExp        equ CPCNT + 11          ; the decimal exponent (signed)
UsingNegative   equ CPCNT + 12          ; the sign of the value (bit 7)
UsingIntDigits  equ CPCNT + 13          ; the digits before the point
UsingZero       equ CPCNT + 14          ; 1: a 0 before the point
UsingWidth      equ CPCNT + 15          ; a string field's width

UsingKindPlus   equ 0                   ; (bits of UsingKind) + before
UsingKindMinusAfter equ 1               ; - after
UsingKindPlusAfter equ 2                ; + after
UsingKindStars  equ 3                   ; **
UsingKindDollar equ 4                   ; $$
UsingKindComma  equ 5                   ; ,
UsingKindPoint  equ 6                   ; .
UsingKindExponent equ 7                 ; ^^^^

UsingFieldNumber equ 0                  ; (UsingParse's results)
UsingFieldString equ 1                  ; (UsingWidth characters; 0: the whole string)

; PrintUsing: HL at USING.
PrintUsing:
        rst $10
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        ld a,b
        or a
        jp z,IllegalFunction
        ld (UsingLength),a
        ex de,hl
        ld de,BUF
        ld c,b
        ld b,$00
        ldir
        pop hl
        rst $08
        db ';'
        ld (UsingText),hl
        call AtStatementEnd             ; no values at all?
        ld a,$00
        jr nz,.flags
        ld a,$02
.flags:
        ld (UsingFlags),a
.restart:
        ld hl,BUF
        ld (UsingPos),hl
        ld a,(UsingLength)
        ld (UsingLeft),a
.scan:
        ld a,(UsingLeft)
        or a
        jr nz,.notEnd
        ld a,(UsingFlags)               ; the end of the format
        bit 0,a
        jp z,IllegalFunction
        bit 1,a
        jr nz,.finish
        jr .restart
.notEnd:
        call UsingParse
        jr nc,.field
        ld hl,(UsingPos)                ; a character as it is
        ld a,(hl)
        inc hl
        ld (UsingPos),hl
        ld hl,UsingLeft
        dec (hl)
        rst $18
        jr .scan
.field:
        ld b,a                          ; B = the field's kind
        ld a,(UsingFlags)
        bit 1,a
        jr nz,.finish
        or $01
        ld (UsingFlags),a
        ld (UsingPos),de                ; past the field
        ld a,c
        ld (UsingLeft),a
        push bc
        ld hl,(UsingText)
        call EvalExpression
        ld (UsingText),hl
        pop bc
        ld a,(VALTYP)
        cp TypeString
        ld a,b
        jr z,.string
        cp UsingFieldNumber
        jp nz,TypeMismatch
        call UsingNumber
        jr .next
.string:
        cp UsingFieldString
        jp nz,TypeMismatch
        call UsingString
.next:
        call UsingCheckEnd
        jr .scan
.finish:
        ld a,(UsingFlags)
        bit 2,a
        call z,PrintCrLf
        ld hl,(UsingText)
        ret

; UsingCheckEnd: after a value: ';' or ',' and the end: no new line; the end: no values left.
UsingCheckEnd:
        ld hl,(UsingText)
        call ThisChar
        cp ';'
        jr z,.separator
        cp ','
        jr nz,.end
.separator:
        rst $10
        ld (UsingText),hl
        call AtStatementEnd
        ret nz
        ld a,(UsingFlags)
        or $06
        ld (UsingFlags),a
        ret
.end:
        call AtStatementEnd
        jp nz,SyntaxError
        ld a,(UsingFlags)
        or $02
        ld (UsingFlags),a
        ret

; UsingParse: is there a field at UsingPos? Out: carry when not; else A = UsingFieldNumber (UsingKind,
; UsingIntPos, UsingHashes, UsingFraction) or UsingFieldString (UsingWidth), DE / C past the field.
UsingParse:
        ld de,(UsingPos)
        ld a,(UsingLeft)
        ld c,a
        xor a
        ld (UsingKind),a
        ld (UsingIntPos),a
        ld (UsingHashes),a
        ld (UsingFraction),a
        ld a,(de)
        cp '!'
        jr z,.one
        cp '&'
        jr z,.whole
        cp '\'
        jr z,.backslash
        cp '+'
        jr nz,.body
        call .take                      ; + before a number?
        call .startsNumber
        jr c,.plus
        dec de
        inc c
        scf
        ret
.plus:
        ld hl,UsingKind
        set UsingKindPlus,(hl)
        ld hl,UsingIntPos
        inc (hl)
        jr .number
.body:
        call .startsNumber
        ccf
        ret c
        jr .number
.one:
        ld a,1
        jr .stringField
.whole:
        xor a
.stringField:
        ld (UsingWidth),a
        call .take
        ld a,UsingFieldString
        or a
        ret
.backslash:
        push de                         ; spaces up to another backslash
        push bc
        ld b,2
.spaces:
        inc de
        dec c
        jr z,.notBackslash
        ld a,(de)
        cp '\'
        jr z,.backslashes
        cp ' '
        jr nz,.notBackslash
        inc b
        jr .spaces
.notBackslash:
        pop bc
        pop de
        scf
        ret
.backslashes:
        ld a,b
        ld (UsingWidth),a
        pop bc                          ; (the field from where it started)
        pop de
        ld b,a
.skip:
        call .take
        djnz .skip
        ld a,UsingFieldString
        or a
        ret
.number:                                ; ** $$ before the digits
        call .peek
        cp '*'
        jr nz,.notStars
        call .nextIs
        cp '*'
        jr nz,.notStars
        ld hl,UsingKind
        set UsingKindStars,(hl)
        call .take
        call .take
        ld hl,UsingIntPos
        inc (hl)
        inc (hl)
        call .peek
        cp '$'
        jr nz,.digits
        ld hl,UsingKind
        set UsingKindDollar,(hl)
        ld hl,UsingIntPos
        inc (hl)
        call .take
        jr .digits
.notStars:
        call .peek
        cp '$'
        jr nz,.digits
        ld hl,UsingKind
        set UsingKindDollar,(hl)
        call .take
        call .take
        ld hl,UsingIntPos
        inc (hl)
        inc (hl)
.digits:                                ; # and , before the point
        call .peek
        cp '#'
        jr z,.hash
        cp ','
        jr nz,.point
        ld hl,UsingKind
        set UsingKindComma,(hl)
        jr .intPlace
.hash:
        ld hl,UsingHashes
        inc (hl)
.intPlace:
        ld hl,UsingIntPos
        inc (hl)
        call .take
        jr .digits
.point:
        cp '.'
        jr nz,.exponent
        ld hl,UsingKind
        set UsingKindPoint,(hl)
        call .take
.fraction:
        call .peek
        cp '#'
        jr nz,.exponent
        ld hl,UsingFraction
        inc (hl)
        call .take
        jr .fraction
.exponent:                              ; ^^^^
        ld a,c
        cp 4
        jr c,.after
        ld h,d
        ld l,e
        ld b,4
.caret:
        ld a,(hl)
        cp '^'
        jr nz,.after
        inc hl
        djnz .caret
        ex de,hl
        ld a,c
        sub 4
        ld c,a
        ld hl,UsingKind
        set UsingKindExponent,(hl)
.after:                                 ; - or + after (not with + before)
        ld a,(UsingKind)
        bit UsingKindPlus,a
        jr nz,.numberDone
        call .peek
        ld hl,UsingKind
        cp '-'
        jr nz,.notMinus
        set UsingKindMinusAfter,(hl)
        call .take
        jr .numberDone
.notMinus:
        cp '+'
        jr nz,.numberDone
        set UsingKindPlusAfter,(hl)
        call .take
.numberDone:
        ld a,UsingFieldNumber
        or a
        ret
.startsNumber:                          ; does a number start at DE (# .# ** $$)? carry when it does
        call .peek
        cp '#'
        scf
        ret z
        ld b,a
        call .nextIs
        cp '#'
        jr nz,.notPoint
        ld a,b
        cp '.'
        scf
        ret z
.notPoint:
        ld a,b
        cp '*'
        jr z,.double
        cp '$'
        jr z,.double
        or a
        ret
.double:
        call .nextIs
        cp b
        scf
        ret z
        or a
        ret
.peek:                                  ; A = the character at DE (0 at the end)
        ld a,c
        or a
        ret z
        ld a,(de)
        ret
.nextIs:                                ; A = the character after DE (0 at the end)
        ld a,c
        cp 2
        ld a,$00
        ret c
        inc de
        ld a,(de)
        dec de
        ret
.take:
        inc de
        dec c
        ret

; UsingString: the string in DAC for the field (UsingWidth characters; 0: all of it).
UsingString:
        call StringOperand              ; B = length, DE = characters
        ld a,(UsingWidth)
        or a
        jr z,.all
        ld c,a                          ; C = the width
.char:
        ld a,b
        or a
        ld a,' '                        ; (spaces after a short string)
        jr z,.put
        ld a,(de)
        inc de
        dec b
.put:
        rst $18
        dec c
        jr nz,.char
        ret
.all:
        ld a,b
        or a
        ret z
.allChar:
        ld a,(de)
        rst $18
        inc de
        djnz .allChar
        ret

; UsingNumber: the number in DAC for the field.
UsingNumber:
        call ForceDouble
        ld hl,DAC                       ; the digits to FBUFFR, the exponent, the sign
        ld a,(hl)
        ld (UsingNegative),a
        and $7F
        jr z,.zero
        sub $40
.zero:
        ld (UsingExp),a
        inc hl
        ld de,FBUFFR
        ld b,7
.digitPair:
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and $0F
        add a,'0'
        ld (de),a
        inc de
        ld a,(hl)
        and $0F
        add a,'0'
        ld (de),a
        inc de
        inc hl
        djnz .digitPair
        ld a,(UsingKind)
        bit UsingKindExponent,a
        jp nz,UsingExponent
        ld a,(UsingExp)                 ; rounded to the digits after the point
        ld b,a
        ld a,(UsingFraction)
        add a,b
        call UsingRound
        ld a,(UsingExp)                 ; the digits before the point
        bit 7,a
        jr z,.intDigits
        xor a
.intDigits:
        ld (UsingIntDigits),a
        call UsingSignLength            ; B = sign + dollar places
        ld a,(UsingIntPos)              ; a 0 before the point when there are none and room for it
        sub b
        jr z,.noZero
        jr c,.noZero
        ld a,(UsingIntDigits)
        or a
        jr nz,.noZero
        ld a,1
        jr .zeroSet
.noZero:
        xor a
.zeroSet:
        ld (UsingZero),a
        add a,b                         ; the length of what goes before the point
        ld b,a
        ld a,(UsingIntDigits)
        add a,b
        ld b,a
        call UsingCommas
        add a,b
        ld b,a
        ld a,(UsingIntPos)              ; the padding (or %)
        sub b
        jr nc,.pad
        ld a,'%'
        rst $18
        xor a
.pad:
        ld b,a
        call UsingPadding
        call UsingSignBefore
        ld a,(UsingIntDigits)           ; the digits before the point, with commas
        or a
        jr z,.noIntDigits
        ld b,a
        ld c,$00                        ; C = the index
.intDigit:
        ld a,c
        call UsingDigit
        rst $18
        inc c
        dec b
        jr z,.noIntDigits
        ld a,(UsingKind)
        bit UsingKindComma,a
        jr z,.intDigit
        ld a,b                          ; a comma when the digits left are a multiple of 3
        ld e,3
.mod3:
        sub e
        jr z,.comma
        jr nc,.mod3
        jr .intDigit
.comma:
        ld a,','
        rst $18
        jr .intDigit
.noIntDigits:
        ld a,(UsingZero)
        or a
        jr z,.point
        ld a,'0'
        rst $18
.point:
        ld a,(UsingExp)                 ; the point and the digits after it
        ld c,a
        call UsingFractionDigits
        jp UsingSignAfter

; UsingFractionDigits: the point (if the field has one) and the UsingFraction digits from index C.
UsingFractionDigits:
        ld a,(UsingKind)
        bit UsingKindPoint,a
        ret z
        ld a,'.'
        rst $18
        ld a,(UsingFraction)
        or a
        ret z
        ld b,a
.digit:
        ld a,c
        call UsingDigit
        rst $18
        inc c
        djnz .digit
        ret

; UsingCommas: A = the commas among the UsingIntDigits digits (when the field has commas). Keeps B.
UsingCommas:
        ld a,(UsingKind)
        bit UsingKindComma,a
        ld a,$00
        ret z
        ld a,(UsingIntDigits)
        or a
        ret z
        dec a
        ld c,$00
.three:
        sub 3
        jr c,.done
        inc c
        jr .three
.done:
        ld a,c
        ret

; UsingSignLength: B = the places the sign before and the dollar take. Keeps the others but A.
UsingSignLength:
        ld b,$00
        ld a,(UsingKind)
        bit UsingKindDollar,a
        jr z,.noDollar
        inc b
.noDollar:
        bit UsingKindPlus,a
        jr nz,.sign
        and (1 << UsingKindMinusAfter) | (1 << UsingKindPlusAfter)
        ret nz
        ld a,(UsingNegative)
        bit 7,a
        ret z
.sign:
        inc b
        ret

; UsingPadding: B spaces (asterisks with **).
UsingPadding:
        ld a,b
        or a
        ret z
        ld a,(UsingKind)
        bit UsingKindStars,a
        ld a,' '
        jr z,.char
        ld a,'*'
.char:
        rst $18
        djnz .char
        ret

; UsingSignBefore: the sign before the number (with + before, or a minus) and the dollar.
UsingSignBefore:
        ld a,(UsingKind)
        bit UsingKindPlus,a
        jr nz,.sign
        and (1 << UsingKindMinusAfter) | (1 << UsingKindPlusAfter)
        jr nz,.dollar
        ld a,(UsingNegative)
        bit 7,a
        jr z,.dollar
.sign:
        call UsingSignChar
        rst $18
.dollar:
        ld a,(UsingKind)
        bit UsingKindDollar,a
        ret z
        ld a,'$'
        rst $18
        ret

; UsingSignAfter: - or + after the number (a space for - after a positive one).
UsingSignAfter:
        ld a,(UsingKind)
        bit UsingKindPlusAfter,a
        jr nz,.sign
        bit UsingKindMinusAfter,a
        ret z
        ld a,(UsingNegative)
        bit 7,a
        ld a,' '
        jr z,.put
.sign:
        call UsingSignChar
.put:
        rst $18
        ret

UsingSignChar:                          ; A = '+' or '-'
        ld a,(UsingNegative)
        bit 7,a
        ld a,'+'
        ret z
        ld a,'-'
        ret

; UsingExponent: the number with an exponent: the digits before the point are the # but one (that
; one is the sign's place unless the sign is given by + before or after).
UsingExponent:
        ld a,(UsingKind)
        and (1 << UsingKindPlus) | (1 << UsingKindMinusAfter) | (1 << UsingKindPlusAfter)
        ld a,(UsingHashes)
        jr nz,.given
        or a
        jr z,.given
        dec a
.given:
        ld (UsingIntDigits),a           ; the mantissa's digits before the point
        ld b,a
        ld a,(UsingFraction)            ; rounded to its digits
        add a,b
        call UsingRound
        ld a,(UsingNegative)            ; (zero: exponent 0)
        and $7F
        jr nz,.notZero
        ld a,(UsingIntDigits)
        ld (UsingExp),a
.notZero:
        ld a,(UsingKind)                ; the sign (or its place)
        and (1 << UsingKindPlus) | (1 << UsingKindMinusAfter) | (1 << UsingKindPlusAfter)
        jr nz,.signGiven
        ld a,(UsingNegative)
        bit 7,a
        ld a,' '
        jr z,.signPlace
        ld a,'-'
.signPlace:
        ld b,a
        ld a,(UsingHashes)              ; (only when there is a place for it)
        or a
        ld a,b
        jr z,.mantissa
        rst $18
        jr .mantissa
.signGiven:
        ld a,(UsingKind)
        bit UsingKindPlus,a
        jr z,.mantissa
        call UsingSignChar
        rst $18
.mantissa:
        ld a,(UsingIntDigits)
        or a
        jr z,.noInt
        ld b,a
        ld c,$00
.intDigit:
        ld a,c
        call UsingDigit
        rst $18
        inc c
        djnz .intDigit
.noInt:
        ld a,(UsingIntDigits)
        ld c,a
        call UsingFractionDigits
        ld a,'E'
        rst $18
        ld a,(UsingIntDigits)           ; the exponent: UsingExp - the digits before the point
        ld b,a
        ld a,(UsingExp)
        sub b
        ld b,'+'
        bit 7,a
        jr z,.positive
        neg
        ld b,'-'
.positive:
        ld c,a
        ld a,b
        rst $18
        ld a,c
        ld b,'0' - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,10 + '0'
        ld c,a
        ld a,b
        rst $18
        ld a,c
        rst $18
        jp UsingSignAfter

; UsingDigit: A = the character of digit A (signed index: outside 0-13 it is '0'). Keeps the others.
UsingDigit:
        bit 7,a
        jr nz,.zero
        cp 14
        jr nc,.zero
        push hl
        ld hl,FBUFFR
        add a,l
        ld l,a
        jr nc,.read
        inc h
.read:
        ld a,(hl)
        pop hl
        ret
.zero:
        ld a,'0'
        ret

; UsingRound: the digits in FBUFFR rounded (half up) to the first A (signed); 9s that carry out of the
; first digit make it 1 and the exponent one more. Fewer than none: all zero.
UsingRound:
        bit 7,a
        jr nz,.allZero
        cp 14
        ret nc
        ld hl,FBUFFR
        ld e,a
        ld d,$00
        add hl,de
        ld b,(hl)                       ; B = the first digit dropped
        push hl
        ld a,14
        sub e
        ld c,a
.clear:
        ld (hl),'0'
        inc hl
        dec c
        jr nz,.clear
        pop hl
        ld a,b
        cp '5'
        ret c
.carry:
        ld a,e                          ; (E = the digits kept, to the left of HL)
        or a
        jr z,.overflow
        dec hl
        dec e
        ld a,(hl)
        inc a
        cp '9' + 1
        jr nz,.store
        ld (hl),'0'
        jr .carry
.store:
        ld (hl),a
        ret
.overflow:
        ld a,'1'
        ld (FBUFFR),a
        ld hl,UsingExp
        inc (hl)
        ret
.allZero:
        ld hl,FBUFFR
        ld b,14
.zero:
        ld (hl),'0'
        inc hl
        djnz .zero
        ret
