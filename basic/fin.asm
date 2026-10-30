; fin.asm: FIN, a number written as text into DAC. The digits go straight into DAC's mantissa (16 at
; most) while the position of the point and the exponent are counted; the type comes from a suffix
; (% ! #), the exponent letter (E single, D double) or the number itself (a whole number up to 32767
; is an integer, up to 6 digits single, more double). Spaces between the characters are skipped. Only
; the bytes of DAC that the type uses change (FIN keeps a copy of DAC in HOLD for the others).

FinFlags        equ HOLD8               ; bit 0 point seen, 1 a digit not 0 seen, 2 negative, 3 exponent part
FinDigits       equ HOLD8 + 1           ; digits counted from the first that is not 0
FinDecimals     equ HOLD8 + 2           ; digits after the point
FinPointExp     equ HOLD8 + 3           ; exponent from the digits (signed)
FinExpValue     equ HOLD8 + 4           ; the written exponent (signed)
FinType         equ HOLD8 + 5           ; type asked for (0 = from the number)

FinPoint        equ 0
FinSignificant  equ 1
FinNegative     equ 2
FinExponent     equ 3

; FinNumber: FIN. In: HL = the text, A = its first character. Out: DAC and VALTYP; HL = the character
; after the number; B = digits after the point, C = FFh without a point (0 with one), D = digits.
FinNumber:
        push hl
        ld hl,DAC                       ; keep DAC: the bytes the type does not use stay
        ld de,HOLD
        ld bc,$0008
        ldir
        call ZeroDac
        ld hl,FinFlags
        ld b,$06
.clearVars:
        ld (hl),$00
        inc hl
        djnz .clearVars
        pop hl
        call FinSkipSpaces
        cp '-'
        jr nz,.notMinus
        ld a,1 << FinNegative
        ld (FinFlags),a
        jr .afterSign
.notMinus:
        cp '+'
        jr nz,.body
.afterSign:
        inc hl
        call FinSkipSpaces
.body:
        cp '&'
        jp z,FinRadix
.character:
        call FinSkipSpaces
        cp '0'
        jr c,.notDigit
        cp '9' + 1
        jr nc,.notDigit
        call FinDigit
        inc hl
        jr .character
.notDigit:
        cp '.'
        jr nz,.notPoint
        ld a,(FinFlags)
        bit FinPoint,a
        jr nz,.end                      ; a second point ends the number
        set FinPoint,a
        ld (FinFlags),a
        inc hl
        jr .character
.notPoint:
        or $20                          ; letters in either case
        cp 'e'
        jr z,.exponentLetter
        cp 'd'
        jr z,.exponentLetter
        ld c,TypeInteger
        cp '%' | $20
        jr z,.suffix
        ld c,TypeSingle
        cp '!' | $20
        jr z,.suffix
        ld c,TypeDouble
        cp '#' | $20
        jr nz,.end
.suffix:
        ld a,c
        ld (FinType),a
        inc hl
        jr .end
.exponentLetter:                        ; E or D followed by a letter is a word (7 EQV 2), not an exponent
        ld c,a
        push hl
        inc hl
        call FinSkipSpaces
        pop hl
        call UpperCase
        call IsLetter
        jr nc,.end
        ld a,c
        cp 'e'
        ld a,TypeSingle
        jr z,.exponent
        ld a,TypeDouble
.exponent:
        ld (FinType),a
        ld a,(FinFlags)
        set FinExponent,a
        ld (FinFlags),a
        inc hl
        call FinExponentPart
.end:
        jp FinFinish

; FinSkipSpaces: A = (HL), past any spaces.
FinSkipSpaces:
        ld a,(hl)
        cp ' '
        ret nz
        inc hl
        jr FinSkipSpaces

; FinDigit: one digit (A = '0'-'9') into the number. Destroys AF, BC, DE.
FinDigit:
        sub '0'
        ld c,a
        ld a,(FinFlags)
        bit FinPoint,a
        jr z,.notDecimal
        push hl
        ld hl,FinDecimals
        inc (hl)
        pop hl
.notDecimal:
        bit FinSignificant,a
        jr nz,.significant
        ld a,c
        or a
        jr nz,.first
        ld a,(FinFlags)                 ; a 0 before the first digit: only the point position counts
        bit FinPoint,a
        ret z
        push hl
        ld hl,FinPointExp
        dec (hl)
        pop hl
        ret
.first:
        ld a,(FinFlags)
        set FinSignificant,a
        ld (FinFlags),a
.significant:
        bit FinPoint,a
        jr nz,.store
        push hl
        ld hl,FinPointExp               ; a digit before the point: one more power of ten
        inc (hl)
        pop hl
.store:
        ld a,(FinDigits)
        cp MantissaBytes * 2
        jr nc,.count                    ; the 17th digit on counts but is not kept
        push hl
        ld e,a
        srl e                           ; E = the byte of this digit
        ld d,$00
        ld hl,DAC + 1
        add hl,de
        and $01                         ; an odd digit number: the low nibble
        ld a,c
        jr nz,.lowNibble
        rlca
        rlca
        rlca
        rlca
.lowNibble:
        or (hl)
        ld (hl),a
        pop hl
.count:
        ld a,(FinDigits)
        inc a
        ld (FinDigits),a
        ret

; FinExponentPart: after E or D: a sign and up to the digits that follow (FinExpValue).
FinExponentPart:
        call FinSkipSpaces
        ld b,$00                        ; B = sign: 0 or FFh
        cp '-'
        jr nz,.notMinus
        dec b
        jr .signDone
.notMinus:
        cp '+'
        jr nz,.digits
.signDone:
        inc hl
.digits:
        ld c,$00                        ; C = value
.digit:
        call FinSkipSpaces
        sub '0'
        jr c,.done
        cp 10
        jr nc,.done
        ld e,a
        ld a,c                          ; C = C * 10 + digit, stuck at 127 or more
        cp 13
        jr nc,.big
        add a,a
        ld d,a
        add a,a
        add a,a
        add a,d
        add a,e
        ld c,a
        inc hl
        jr .digit
.big:
        ld c,127
        inc hl
        jr .digit
.done:
        ld a,c
        bit 7,b
        jr z,.store
        neg
.store:
        ld (FinExpValue),a
        ret

; FinFinish: exponent, type, rounding; restore the bytes of DAC the type does not use.
FinFinish:
        push hl
        ld a,(FinFlags)
        bit FinSignificant,a
        jr z,.zero
        ld a,(FinPointExp)              ; exponent = 64 + point position + written exponent
        ld c,a
        ld a,(FinExpValue)
        ld l,a
        rla
        sbc a,a
        ld h,a                          ; HL = written exponent (16 bits)
        ld a,c
        ld e,a
        rla
        sbc a,a
        ld d,a
        add hl,de
        ld de,$0040
        add hl,de                       ; HL = exponent byte, maybe out of 1-127
        bit 7,h
        jr nz,.zero                     ; too small: 0
        ld a,h
        or a
        jp nz,MathOverflow
        ld a,l
        or a
        jr z,.zero
        cp $80
        jp nc,MathOverflow
        ld b,a
        ld a,(FinFlags)
        and 1 << FinNegative
        rrca
        rrca
        rrca                            ; bit 2 -> bit 7
        or b
        ld (DAC),a
        jr .typed
.zero:
        call ZeroDac
.typed:
        ld a,TypeDouble
        ld (VALTYP),a
        call RoundDac
        ld a,(FinType)
        or a
        jr nz,.haveType
        ld a,(FinFlags)                 ; from the number: a whole number up to 32767 is an integer
        and (1 << FinPoint) | (1 << FinExponent)
        jr nz,.realType
        ld a,(FinDigits)
        cp $06
        jr nc,.realType
        call BcdToBinary
        jr c,.realType
        bit 7,h
        jr nz,.realType
        ld a,TypeInteger
        jr .haveType
.realType:
        ld a,(FinDigits)
        cp $07
        ld a,TypeSingle
        jr c,.haveType
        ld a,TypeDouble
.haveType:
        cp TypeInteger
        jr z,.integer
        cp TypeSingle
        jr z,.single
        ld hl,$0000                     ; double: every byte of DAC is the number's
        ld (HOLD),hl
        ld (HOLD + 2),hl
        ld (HOLD + 4),hl
        ld (HOLD + 6),hl
        ld bc,$0000
        jr .restore
.single:
        call ForceSingle
        ld bc,$0004                     ; bytes 4-7 come back
        jr .restore
.integer:
        call ForceInteger
        ld a,(DAC)                      ; bytes 0, 1 and 4-7 come back
        ld hl,(HOLD)
        ld (DAC),hl
        ld bc,$0004
.restore:
        ld a,b
        or c
        jr z,.registers
        ld hl,HOLD + 4
        ld de,DAC + 4
        ldir
.registers:
        ld a,(FinDecimals)
        ld b,a
        ld a,(FinFlags)
        bit FinPoint,a
        ld c,$FF
        jr z,.noPoint
        ld c,$00
.noPoint:
        ld a,(FinDigits)
        ld d,a
        pop hl
        ret

; FinRadix: &H hexadecimal, &O octal, &B binary (& and digits: octal). An integer; Overflow above
; FFFFh. In: HL at the &.
FinRadix:
        inc hl
        ld a,(hl)
        or $20
        ld c,16
        cp 'h'
        jr z,.letter
        ld c,8
        cp 'o'
        jr z,.letter
        ld c,2
        cp 'b'
        jr z,.letter
        ld c,8
        jr .digits
.letter:
        inc hl
.digits:
        ld de,$0000                     ; DE = value
.digit:
        ld a,(hl)
        sub '0'
        jr c,.done
        cp 10
        jr c,.decimal
        or $20                          ; (letters: 'A' - '0' = 11h)
        sub 'a' - '0'
        jr c,.done
        add a,10
.decimal:
        cp c
        jr nc,.done
        push hl
        ld h,d                          ; DE = DE * radix + digit
        ld l,e
        ld b,c
        ld de,$0000
.multiply:
        ex de,hl
        add hl,de
        ex de,hl
        jp c,MathOverflow
        djnz .multiply
        ld l,a
        ld h,$00
        add hl,de
        jp c,MathOverflow
        ex de,hl
        pop hl
        inc hl
        jr .digit
.done:
        ld a,(FinFlags)                 ; a minus before the &
        bit FinNegative,a
        ex de,hl
        call nz,NegateHL
        ld (DAC + 2),hl
        ex de,hl
        ld a,(HOLD)                     ; DAC's other bytes as they were
        ld (DAC),a
        ld a,(HOLD + 1)
        ld (DAC + 1),a
        push hl
        ld hl,HOLD + 4
        ld de,DAC + 4
        ld bc,$0004
        ldir
        pop hl
        ld a,TypeInteger
        ld (VALTYP),a
        ret
