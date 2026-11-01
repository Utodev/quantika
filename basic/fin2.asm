; fin2.asm: FIN's second half (basic/fin.asm has the first, and the work variables): the end of a
; number and &H / &O / &B. (Two modules so that each fits in the free areas.)

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
