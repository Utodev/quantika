; bcd.asm: the decimal arithmetic of the Math-Pack. A real number is a byte of sign (bit 7) and
; exponent (bits 6-0, excess 64: the value is 0.mantissa * 10 ^ (exponent - 64), 0 = the number zero)
; and the mantissa in BCD, two digits a byte, the first one first: 3 bytes in single precision (6
; digits), 7 in double (14 digits). Here every operation works on 16 digits: the byte after the
; mantissa (DAC + 8, ARG + 8) holds two guard digits, and the result is rounded to 14 digits.
;
; The algorithms are this ROM's own: shifts by one digit with RRD / RLD, addition and subtraction with
; DAA, multiplication by adding the multiplicand once per unit of each digit of the multiplier, the
; partial product shifting a digit right each time, and division by subtracting the divisor while it
; fits, one quotient digit at a time.

MantissaBytes   equ 8                   ; 14 digits and the two guard digits

; Work areas of the Math-Pack (HOLD8 is the Math-Pack's own scratch area)
Product         equ HOLD8               ; 10 bytes: integer byte and 18 digits
Remainder       equ HOLD8 + $10         ; 10 bytes
Quotient        equ HOLD8 + $20         ; 9 bytes

; DecSubtract: DECSUB. DAC = DAC - ARG (ARG changes).
DecSubtract:
        ld hl,ARG
        ld a,(hl)
        xor $80
        ld (hl),a
; DecAdd: DECADD. DAC = DAC + ARG, both double precision, the result rounded (ARG changes).
DecAdd:
        xor a
        ld (DAC + 8),a
        ld (ARG + 8),a
        ld a,(ARG)
        and $7F
        ret z                           ; + 0
        ld c,a
        ld a,(DAC)
        and $7F
        jp z,CopyArgToDac               ; 0 + ARG
        sub c
        jr nc,.ordered
        call SwapDacArg                 ; the larger exponent in DAC
        neg
.ordered:
        cp MantissaBytes * 2 + 1
        jp nc,RoundDac                  ; ARG is too small to count
        call ShiftArgRight
        ld a,(ARG)
        ld hl,DAC
        xor (hl)
        jp m,.subtract
        call AddMantissas
        jr nc,.rounded
        ld a,$01                        ; a carry: one more digit at the top
        call ShiftDacRight
        call IncrementExponent
.rounded:
        jp RoundDac
.subtract:
        call SubtractMantissas
        jr nc,.positive
        call NegateMantissa             ; ARG was the larger: the sign changes
        ld hl,DAC
        ld a,(hl)
        xor $80
        ld (hl),a
.positive:
        call NormaliseDac
        jp RoundDac

; CopyArgToDac: DAC = ARG (9 bytes, with the guard byte). Destroys BC, DE, HL.
CopyArgToDac:
        ld hl,ARG
        ld de,DAC
        ld bc,MantissaBytes + 1
        ldir
        ret

; SwapDacArg: exchange DAC and ARG (9 bytes). Preserves A. Destroys B, DE, HL.
SwapDacArg:
        push af
        ld hl,DAC
        ld de,ARG
        ld b,MantissaBytes + 1
.swap:
        ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .swap
        pop af
        ret

; ShiftArgRight: the mantissa of ARG A digits to the right (A may be 0). Destroys AF, B, HL.
ShiftArgRight:
        or a
        ret z
        ld b,a
.digit:
        push bc
        ld hl,ARG + 1
        xor a
        ld b,MantissaBytes
.byte:
        rrd
        inc hl
        djnz .byte
        pop bc
        djnz .digit
        ret

; ShiftDacRight: the mantissa of DAC one digit to the right, A (0-9) coming in at the top.
; Destroys AF, B, HL.
ShiftDacRight:
        ld hl,DAC + 1
        ld b,MantissaBytes
.byte:
        rrd
        inc hl
        djnz .byte
        ret

; ShiftDacLeft: the mantissa of DAC one digit to the left, 0 coming in at the bottom. Destroys AF, B, HL.
ShiftDacLeft:
        ld hl,DAC + MantissaBytes
        ld b,MantissaBytes
        xor a
.byte:
        rld
        dec hl
        djnz .byte
        ret

; AddMantissas: DAC mantissa += ARG mantissa. Out: carry from the top digit. Destroys AF, BC, DE, HL.
AddMantissas:
        ld hl,DAC + MantissaBytes
        ld de,ARG + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,(de)
        adc a,(hl)
        daa
        ld (hl),a
        dec hl
        dec de
        djnz .byte
        ret

; SubtractMantissas: DAC mantissa -= ARG mantissa. Out: carry when ARG was the larger.
; Destroys AF, BC, DE, HL.
SubtractMantissas:
        ld hl,DAC + MantissaBytes
        ld de,ARG + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,(de)
        ld c,a
        ld a,(hl)
        sbc a,c
        daa
        ld (hl),a
        dec hl
        dec de
        djnz .byte
        ret

; NegateMantissa: DAC mantissa = 0 - DAC mantissa (ten's complement). Destroys AF, BC, HL.
NegateMantissa:
        ld hl,DAC + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,$00
        sbc a,(hl)
        daa
        ld (hl),a
        dec hl
        djnz .byte
        ret

; IncrementExponent: DAC's exponent + 1 (Overflow when it passes 7Fh). Destroys AF, HL.
IncrementExponent:
        ld hl,DAC
        ld a,(hl)
        inc a
        ld (hl),a
        and $7F
        ret nz
        jp MathOverflow

; NormaliseDac: DECNRM. Shift the mantissa left until its first digit is not 0, the exponent down
; with it; a mantissa of zeros, or an exponent going below 1, gives the number 0. Destroys AF, BC, HL.
NormaliseDac:
        ld hl,DAC + 1
        ld b,MantissaBytes
        xor a
.anyDigit:
        or (hl)
        inc hl
        djnz .anyDigit
        jr z,ZeroDac
.check:
        ld a,(DAC + 1)
        and $F0
        ret nz
        ld a,(DAC)
        and $7F
        dec a
        jr z,ZeroDac                    ; too small: 0
        ld hl,DAC
        dec (hl)
        call ShiftDacLeft
        jr .check

; ZeroDac: DAC = 0 (the exponent byte and the mantissa with its guard digits). Destroys AF, B, HL.
ZeroDac:
        ld hl,DAC
        ld b,MantissaBytes + 1
        xor a
.clear:
        ld (hl),a
        inc hl
        djnz .clear
        ret

; RoundDac: DECROU. Round DAC to 14 digits with the guard digits, which are then cleared.
; Destroys AF, BC, HL.
RoundDac:
        ld hl,DAC + MantissaBytes
        ld a,(hl)
        ld (hl),$00
        cp $50
        ret c
        ld b,MantissaBytes - 1
        ; fall through
; RoundUp: add 1 to the last digit of the B mantissa bytes of DAC; a carry out of the top (all 9s)
; makes the mantissa 0.1 and the exponent one more. Destroys AF, B, HL.
RoundUp:
        ld hl,DAC
        ld a,l
        add a,b
        ld l,a
        jr nc,.add
        inc h
.add:
        scf
.byte:
        ld a,(hl)
        adc a,$00
        daa
        ld (hl),a
        dec hl
        jr nc,.done
        djnz .byte
        ld a,$10                        ; 0.999.. + 0.000..1 = 1.0 = 0.1 * 10
        ld (DAC + 1),a
        jp IncrementExponent
.done:
        or a
        ret

; DecMultiply: DECMUL. DAC = DAC * ARG.
DecMultiply:
        xor a
        ld (DAC + 8),a
        ld (ARG + 8),a
        ld a,(DAC)
        and $7F
        ret z                           ; 0 * x
        ld b,a
        ld a,(ARG)
        and $7F
        jp z,ZeroDac                    ; x * 0
        ; exponent: e1 + e2 - 64, kept in 16 bits to see overflow and underflow
        ld l,a
        ld h,$00
        ld c,b
        ld b,$00
        add hl,bc
        ld bc,-$40
        add hl,bc
        push hl
        ld a,(ARG)                      ; the sign
        ld hl,DAC
        xor (hl)
        and $80
        push af
        ; Product = 0
        ld hl,Product
        ld b,10
.clearProduct:
        ld (hl),$00
        inc hl
        djnz .clearProduct
        ; the multiplier's digits, from the last
        ld hl,ARG + MantissaBytes
        ld c,MantissaBytes
.multiplierByte:
        ld a,(hl)
        push hl
        push af
        and $0F
        call MultiplyStep               ; the low digit
        pop af
        rrca
        rrca
        rrca
        rrca
        and $0F
        call MultiplyStep               ; the high digit
        pop hl
        dec hl
        dec c
        jr nz,.multiplierByte
        ; the product's fraction to DAC
        ld hl,Product + 1
        ld de,DAC + 1
        ld bc,MantissaBytes
        ldir
        pop af                          ; sign
        pop hl                          ; exponent
        jp SetExponentAndFinish

; MultiplyStep: Product = (Product + DAC mantissa * A) / 10. Preserves C. Destroys AF, B, DE, HL.
MultiplyStep:
        push bc
        or a
        jr z,.shift
        ld b,a
.add:
        push bc
        ld hl,Product + MantissaBytes
        ld de,DAC + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,(de)
        adc a,(hl)
        daa
        ld (hl),a
        dec hl
        dec de
        djnz .byte
        ld a,(hl)                       ; the carry into the integer byte
        adc a,$00
        daa
        ld (hl),a
        pop bc
        djnz .add
.shift:
        ld hl,Product
        ld b,10
        xor a
.shiftByte:
        rrd
        inc hl
        djnz .shiftByte
        pop bc
        ret

; SetExponentAndFinish: the result's mantissa is in DAC; give it its exponent and sign, normalise and
; round it. In: HL = exponent (may be out of 1-127), A = sign (bit 7).
SetExponentAndFinish:
        ld c,a
        bit 7,h
        jp nz,ZeroDac                   ; far too small
        ld a,h
        or a
        jp nz,MathOverflow
        ld a,l
        or a
        jp z,ZeroDac
        cp $80
        jp nc,MathOverflow
        or c
        ld (DAC),a
        call NormaliseDac
        jp RoundDac

; DecDivide: DECDIV. DAC = DAC / ARG (Division by zero when ARG is 0).
DecDivide:
        xor a
        ld (DAC + 8),a
        ld (ARG + 8),a
        ld a,(ARG)
        and $7F
        jp z,MathDivisionByZero
        ld c,a
        ld a,(DAC)
        and $7F
        ret z                           ; 0 / x
        ; exponent: e1 - e2 + 64 (+ 1 below if the quotient has an integer digit)
        ld l,a
        ld h,$00
        ld b,$00
        or a
        sbc hl,bc
        ld bc,$40
        add hl,bc
        push hl
        ld a,(ARG)
        ld hl,DAC
        xor (hl)
        and $80
        push af
        ; Remainder = 0 . DAC mantissa, Quotient = 0
        ld hl,Remainder
        ld (hl),$00
        inc hl
        ex de,hl
        ld hl,DAC + 1
        ld bc,MantissaBytes
        ldir
        xor a
        ld (de),a                       ; Remainder + 9
        ld hl,Quotient
        ld b,9
.clearQuotient:
        ld (hl),a
        inc hl
        djnz .clearQuotient
        ld c,17                         ; the integer digit and 16 more
.digit:
        ld b,$00                        ; B = this digit
.trySubtract:
        call RemainderMinusDivisor
        jr c,.tooMuch
        inc b
        jr .trySubtract
.tooMuch:
        call RemainderPlusDivisor       ; undo the last subtraction
        ld a,b                          ; the digit into the quotient, from the right
        ld hl,Quotient + 8
        push bc
        ld b,9
.insert:
        rld
        dec hl
        djnz .insert
        ld hl,Remainder + 9             ; Remainder * 10
        ld b,10
        xor a
.shift:
        rld
        dec hl
        djnz .shift
        pop bc
        dec c
        jr nz,.digit
        ; Quotient: byte 0 low digit = integer digit, bytes 1-8 = the fraction
        pop de                          ; D = sign
        pop hl                          ; exponent
        ld a,(Quotient)
        and $0F
        jr z,.noIntegerDigit
        inc hl                          ; one digit more on the left: shift right
        push hl
        push de
        ld hl,Quotient
        ld b,9
        xor a
.shiftRight:
        rrd
        inc hl
        djnz .shiftRight
        pop de
        pop hl
.noIntegerDigit:
        push hl
        push de
        ld hl,Quotient + 1
        ld de,DAC + 1
        ld bc,MantissaBytes
        ldir
        pop af                          ; the sign (pushed as D, now in A)
        pop hl
        jp SetExponentAndFinish

; RemainderMinusDivisor: Remainder (10 bytes) -= 0 . ARG mantissa (aligned with Remainder + 1).
; Out: carry when it went below zero. Preserves BC. Destroys AF, DE, HL.
RemainderMinusDivisor:
        push bc
        ld hl,Remainder + 8
        ld de,ARG + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,(de)
        ld c,a
        ld a,(hl)
        sbc a,c
        daa
        ld (hl),a
        dec hl
        dec de
        djnz .byte
        ld a,(hl)                       ; the integer byte
        sbc a,$00
        daa
        ld (hl),a
        pop bc
        ret

; RemainderPlusDivisor: the opposite. Preserves BC. Destroys AF, DE, HL.
RemainderPlusDivisor:
        push bc
        ld hl,Remainder + 8
        ld de,ARG + MantissaBytes
        ld b,MantissaBytes
        or a
.byte:
        ld a,(de)
        adc a,(hl)
        daa
        ld (hl),a
        dec hl
        dec de
        djnz .byte
        ld a,(hl)
        adc a,$00
        daa
        ld (hl),a
        pop bc
        ret
