; convert.asm: types of the number in DAC (VALTYP 2 integer at DAC + 2, 4 single, 8 double), moves
; of numbers, comparisons and the integer arithmetic of the Math-Pack.

; ForceInteger: FRCINT. DAC to a 2-byte integer, cut towards zero (Overflow outside -32768 to 32767,
; Type mismatch for a string). Only DAC + 2 and DAC + 3 change. Out: HL = the integer. Destroys all.
ForceInteger:
        ld a,(VALTYP)
        cp TypeInteger
        jr z,.done
        cp TypeString
        jp z,MathTypeMismatch
        call BcdToBinary                ; HL = the whole part of |value|, carry when above 65535
        jp c,MathOverflow
        ld a,(DAC)
        or a
        jp p,.positive
        ld de,$8000                     ; -32768 is the lowest
        or a
        sbc hl,de
        add hl,de
        jr z,.store
        jp nc,MathOverflow
        call NegateHL
        jr .store
.positive:
        bit 7,h
        jp nz,MathOverflow
.store:
        ld (DAC + 2),hl
        ld a,TypeInteger
        ld (VALTYP),a
.done:
        ld hl,(DAC + 2)
        ret

; DigitOfDac: A = digit number B + 1 of DAC's mantissa (digit 1 is the first). Destroys HL, C.
DigitOfDac:
        ld a,b
        srl a                           ; byte = (B) / 2, digit B + 1 is in it
        ld c,a
        ld hl,DAC + 1
        add a,l
        ld l,a
        jr nc,.got
        inc h
.got:
        ld a,(hl)
        bit 0,b
        jr nz,.low                      ; B odd: digit B + 1 is even: the low nibble
        rrca
        rrca
        rrca
        rrca
.low:
        and $0F
        ret

; TruncateDac: clear every digit after the units (FIXER's job without the type). Destroys AF, BC, HL.
TruncateDac:
        ld a,(DAC)
        and $7F
        ret z
        sub $40
        jr c,.belowOne
        jr z,.belowOne
        cp MantissaBytes * 2
        ret nc
        ld b,a                          ; B digits stay
        ld hl,DAC + 1
.keepBytes:
        ld a,b
        cp $02
        jr c,.half
        inc hl
        dec b
        dec b
        jr .keepBytes
.half:
        or a
        jr z,.clearFrom
        ld a,(hl)                       ; one digit stays in this byte
        and $F0
        ld (hl),a
        inc hl
.clearFrom:
        ld a,l
        sub low (DAC + MantissaBytes + 1)
        ret z
.clear:
        ld (hl),$00
        inc hl
        inc a
        jr nz,.clear
        ret
.belowOne:                              ; below 1: the exponent byte to 0 (the number 0)
        xor a
        ld (DAC),a
        ret

; BcdToBinary: the whole part of |DAC| as a binary number (DAC does not change).
; Out: HL, carry when it does not fit in 16 bits. Destroys AF, BC, DE.
BcdToBinary:
        ld hl,$0000
        ld a,(DAC)
        and $7F
        ret z                           ; 0 (no carry)
        sub $40
        jr c,.belowOne
        ret z                           ; below 1: 0
        cp $06
        ccf
        ret c                           ; 6 digits or more: too big
        ld b,a
        ld c,$00                        ; C = digit number - 1
.digit:
        push bc
        ld b,c
        call DigitOfDacHL               ; A = digit C + 1
        pop bc
        push bc
        ; HL = HL * 10 + A
        ld d,h
        ld e,l
        add hl,hl
        jr c,.tooBig
        add hl,hl
        jr c,.tooBig
        add hl,de
        jr c,.tooBig
        add hl,hl
        jr c,.tooBig
        ld e,a
        ld d,$00
        add hl,de
        jr c,.tooBig
        pop bc
        inc c
        djnz .digit
        or a
        ret
.tooBig:
        pop bc
        scf
        ret
.belowOne:
        or a
        ret

; DigitOfDacHL: DigitOfDac keeping HL. In: B. Out: A. Destroys C.
DigitOfDacHL:
        push hl
        call DigitOfDac
        pop hl
        ret

; NegateHL: HL = -HL. Destroys A.
NegateHL:
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; IntegerToBcd: the integer HL as a double precision number in DAC (VALTYP 8). Destroys all.
IntegerToBcd:
        push hl
        call ZeroDac
        pop hl
        ld c,$00                        ; C = sign
        bit 7,h
        jr z,.positive
        ld c,$80
        call NegateHL                   ; (32768 stays 8000h: read as unsigned it is right)
.positive:
        ld a,h
        or l
        jr z,.typed
        ld a,c
        or $45                          ; 0.ddddd * 10 ^ 5
        ld (DAC),a
        ld de,DAC + 1                   ; the five digits, from 10000s to units, into DAC + 1..3
        ld ix,PowersOfTen
        ld b,$05
.digit:
        push bc
        ld c,(ix+0)
        ld b,(ix+1)
        xor a
.count:
        or a
        sbc hl,bc
        jr c,.counted
        inc a
        jr .count
.counted:
        add hl,bc
        pop bc
        push hl
        ex de,hl                        ; the digit at the next nibble: high when B is odd
        bit 0,b
        jr z,.lowNibble
        rlca
        rlca
        rlca
        rlca
        ld (hl),a
        jr .placed
.lowNibble:
        or (hl)
        ld (hl),a
        inc hl
.placed:
        ex de,hl
        pop hl
        inc ix
        inc ix
        djnz .digit
        call NormaliseDac
.typed:
        ld a,TypeDouble
        ld (VALTYP),a
        ret

PowersOfTen:
        dw 10000, 1000, 100, 10, 1

; ForceDouble: FRCDBL. DAC to double precision. Destroys all.
ForceDouble:
        ld a,(VALTYP)
        cp TypeDouble
        ret z
        cp TypeString
        jp z,MathTypeMismatch
        cp TypeSingle
        jr z,.fromSingle
        ld hl,(DAC + 2)
        jp IntegerToBcd
.fromSingle:
        ld hl,$0000                     ; digits 7-14 to 0
        ld (DAC + 4),hl
        ld (DAC + 6),hl
        ld a,TypeDouble
        ld (VALTYP),a
        ret

; ForceSingle: FRCSNG. DAC to single precision (rounded to 6 digits). Destroys all.
ForceSingle:
        ld a,(VALTYP)
        cp TypeSingle
        ret z
        cp TypeString
        jp z,MathTypeMismatch
        cp TypeInteger
        jr nz,.fromDouble
        ld hl,(DAC + 2)
        call IntegerToBcd               ; (5 digits: nothing to round)
        jr .typed
.fromDouble:
        xor a
        ld (DAC + 8),a
        ld a,(DAC + 4)                  ; digit 7
        cp $50
        jr c,.cut
        ld b,$03
        call RoundUp
.cut:                                   ; (digits 7-14 stay as they were, as the original does)
.typed:
        ld a,TypeSingle
        ld (VALTYP),a
        ret

; FixDac: FIXER. DAC = SGN(DAC) * INT(ABS(DAC)): the fraction cut off, the type kept. Destroys all.
FixDac:
        ld a,(VALTYP)
        cp TypeInteger
        ret z
        jp TruncateDac

; --- moves of 8 bytes (double precision) ---
MoveDacToArg:                           ; MAF: ARG = DAC
        ld hl,DAC
MoveToArg:                              ; MAM: ARG = (HL)
        ld de,ARG
Move8:                                  ; MOV8DH: (DE) = (HL)
        ld b,$08
.byte:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .byte
        ret
MoveArgToDac:                           ; MFA: DAC = ARG
        ld hl,ARG
MoveToDac:                              ; MFM: DAC = (HL)
        ld de,DAC
        jr Move8
MoveDacTo:                              ; MMF: (HL) = DAC
        ld de,DAC
Move8Reverse:                           ; MOV8HD: (HL) = (DE)
        ex de,hl
        jr Move8

; --- moves of VALTYP bytes ---
MoveVtToArg:                            ; VMOVAM: ARG = (HL)
        ld de,ARG
MoveVt:                                 ; MOVVFM: (DE) = (HL)
        ex de,hl
MoveVtReverse:                          ; VMOVE: (HL) = (DE)
        ld a,(VALTYP)
        ld b,a
.byte:
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        djnz .byte
        ret
MoveVtArgToDac:                         ; VMOVFA: DAC = ARG
        ld hl,ARG
MoveVtToDac:                            ; VMOVFM: DAC = (HL)
        ld de,DAC
        jr MoveVt
MoveVtDacToArg:                         ; VMOVAF: ARG = DAC
        ld hl,DAC
        jr MoveVtToArg
MoveVtDacTo:                            ; VMOVMF: (HL) = DAC
        ld de,DAC
        jr MoveVtReverse

; --- moves of 4 bytes (single precision) ---
MoveSingleToDac:                        ; MOVFM: DAC = (HL)
        ld de,DAC
MoveSingle:                             ; (DE) = (HL)
        ld bc,$0004
        ldir
        ret
MoveDacToSingle:                        ; MOVMF: (HL) = DAC
        ld de,DAC
        ex de,hl
        jr MoveSingle
MoveSingleReverse:                      ; MOVE: (HL) = (DE)
        ex de,hl
        jr MoveSingle

; --- sign and absolute value ---

; SignOfDac: SIGN. A = 1 positive, 0 zero, FFh negative (by VALTYP). Destroys F.
SignOfDac:
        ld a,(VALTYP)
        cp TypeInteger
        jr nz,.real
        push hl
        ld hl,(DAC + 2)
        ld a,h
        or l
        pop hl
        ret z
        ld a,(DAC + 3)
        jr .bySign
.real:
        ld a,(DAC)
        and $7F
        ret z
        ld a,(DAC)
.bySign:
        rla
        sbc a,a                         ; FFh negative, 0 positive
        ret nz
        inc a
        ret

; NegateDac: DAC = -DAC by its type (an integer -32768 becomes single precision). Destroys AF, HL.
NegateDac:
        ld a,(VALTYP)
        cp TypeInteger
        jr nz,.real
        ld hl,(DAC + 2)
        ld a,h
        cp $80
        jr nz,.notLowest
        ld a,l
        or a
        jr nz,.notLowest
        push bc                         ; -(-32768) = 32768: no longer an integer
        push de
        call ForceSingle
        pop de
        pop bc
        jr NegateRealDac
.notLowest:
        call NegateHL
        ld (DAC + 2),hl
        ret
.real:
        jr NegateRealDac

; NegateRealDac: NEG. The sign of DAC's real number changes (VALTYP is not looked at). Destroys AF.
NegateRealDac:
        ld a,(DAC)
        or a
        ret z
        xor $80
        ld (DAC),a
        ret

; AbsDac: ABSFN. DAC = ABS(DAC).
AbsDac:
        call SignOfDac
        or a
        ret p
        jr NegateDac

; SgnDac: SGN. DAC = SGN(DAC) as an integer. Destroys AF, HL.
SgnDac:
        call SignOfDac
        ld l,a
        rla
        sbc a,a
        ld h,a
        ld (DAC + 2),hl
        ld a,TypeInteger
        ld (VALTYP),a
        ret

; --- comparisons: A = 1 when the left one is smaller, 0 equal, FFh larger ---

; CompareIntegers: ICOMP. DE with HL (signed). Destroys F, HL.
CompareIntegers:
        ld a,d
        xor h
        jp m,.signsDiffer
        push de
        ex de,hl
        or a
        sbc hl,de                       ; DE - HL
        pop de
        ld a,$00
        ret z
        ld a,$01
        ret c
        ld a,$FF
        ret
.signsDiffer:
        ld a,d                          ; DE negative: smaller
        rla
        ld a,$01
        ret c
        ld a,$FF
        ret

; CompareDoubles: XDCOMP. ARG with DAC (8 bytes each). Destroys all.
CompareDoubles:
        ld de,ARG
        ld hl,DAC
        ld b,$08
        jr CompareReals

; CompareSingles: FCOMP. The single number in C B E D (C = sign and exponent) with DAC. Destroys HL.
CompareSingles:
        push bc
        push de
        ld hl,HOLD + 4                  ; the left number in memory, then the common comparison
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld de,HOLD + 4
        ld hl,DAC
        ld b,$04
        call CompareReals
        pop de
        pop bc
        ret

; CompareReals: the real numbers at DE (left) and HL (right), B bytes. A as the comparisons above.
CompareReals:
        ld a,(de)                       ; signs first
        and $7F
        jr nz,.leftNotZero
        ld a,(de)
        and $80
        ld (de),a                       ; (a zero is +0)
.leftNotZero:
        ld a,(de)
        xor (hl)
        jp p,.sameSign
        ld a,(hl)                       ; different signs: the left one is larger if it is positive
        and $7F
        ld c,a
        ld a,(de)
        and $7F
        or c
        ret z                           ; +0 and -0
        ld a,(de)
        rla
        ld a,$FF
        ret nc
        ld a,$01
        ret
.sameSign:
        ld a,(de)
        and $80
        ld c,a                          ; C = the common sign
.byte:
        ld a,(de)
        cp (hl)
        jr nz,.differ
        inc de
        inc hl
        djnz .byte
        xor a
        ret
.differ:
        ld a,$FF                        ; left > right in magnitude...
        jr nc,.magnitude
        ld a,$01
.magnitude:
        bit 7,c                         ; ...the other way round when negative
        ret z
        neg
        ret

; --- integer arithmetic ---

; UnsignedMultiply: UMULT. DE = BC * DE (16 bits). Destroys AF, BC.
UnsignedMultiply:
        push hl
        ld hl,$0000
        ld a,16
.bit:
        add hl,hl
        ex de,hl
        add hl,hl
        ex de,hl
        jr nc,.noAdd
        add hl,bc
.noAdd:
        dec a
        jr nz,.bit
        ex de,hl
        pop hl
        ret

; IntSubtract: ISUB. HL = DE - HL; when it overflows the result is single precision in DAC.
IntSubtract:
        call NegateHLChecked
        jr c,IntOverflowSubtract
; IntAdd: IADD. HL = DE + HL (the same on overflow).
IntAdd:
        ld a,h
        xor d
        jp m,.noOverflow                ; different signs: it cannot overflow
        ld a,h
        add hl,de
        xor h                           ; the sign changed: overflow
        jp p,IntResult
        ; overflow: in single precision
        or a
        sbc hl,de                       ; back to the operand
        push de
        call IntegerToBcd
        call MoveDacToArg
        pop hl
        call IntegerToBcd
        call DecAdd
        jp ForceSingle
.noOverflow:
        add hl,de
IntResult:
        ld (DAC + 2),hl
        ld a,TypeInteger
        ld (VALTYP),a
        ret
IntOverflowSubtract:                    ; DE - (-32768)
        push de
        ld hl,$8000
        call IntegerToBcd
        call MoveDacToArg
        pop hl
        call IntegerToBcd
        call DecSubtract
        jp ForceSingle

; NegateHLChecked: HL = -HL, carry when HL was -32768.
NegateHLChecked:
        ld a,h
        cp $80
        jr nz,.fine
        ld a,l
        or a
        scf
        ret z
.fine:
        call NegateHL
        or a
        ret

; IntMultiply: IMULT. HL = DE * HL (signed; Overflow when it does not fit).
IntMultiply:
        call IntMultiplyChecked
        jp c,MathOverflow
        jp IntResult

; IntMultiplyChecked: HL = DE * HL (signed), carry when it does not fit in 16 bits. Destroys AF, BC, DE.
IntMultiplyChecked:
        ld a,h
        xor d
        push af                         ; the sign of the result
        bit 7,h
        call nz,NegateHL
        ex de,hl
        bit 7,h
        call nz,NegateHL
        ld b,h
        ld c,l                          ; BC = |DE|, DE = |HL|
        ld hl,$0000
        ld a,16
.bit:
        add hl,hl
        jr c,.overflow
        ex de,hl
        add hl,hl
        ex de,hl
        jr nc,.noAdd
        add hl,bc
        jr c,.overflow
.noAdd:
        dec a
        jr nz,.bit
        pop af
        jp p,.positive
        ld a,h
        or l
        ret z                           ; 0 (no carry)
        call NegateHL                   ; (32768 -> -32768 fits)
        bit 7,h
        jr z,.tooBig
        or a
        ret
.positive:
        bit 7,h
        ret z
.tooBig:
        scf
        ret
.overflow:
        pop af
        scf
        ret

; IntDivide: IDIV. HL = DE / HL (towards zero). Division by zero when HL is 0.
IntDivide:
        call IntDivMod
        ex de,hl
        jr IntResult

; IntModulo: IMOD. HL = DE MOD HL (the sign of DE), DE = DE / HL.
IntModulo:
        call IntDivMod
        jr IntResult

; IntDivMod: DE / HL: Out: DE = quotient, HL = remainder, with their signs. Destroys AF, BC.
IntDivMod:
        ld a,h
        or l
        jp z,MathDivisionByZero
        ld a,d
        push af                         ; sign of the remainder
        xor h
        push af                         ; sign of the quotient
        bit 7,h
        call nz,NegateHL
        ld b,h
        ld c,l                          ; BC = |divisor|
        ex de,hl
        bit 7,h
        call nz,NegateHL                ; HL = |dividend| (unsigned)
        ex de,hl                        ; DE = |dividend|
        ld hl,$0000                     ; HL = remainder
        ld a,16
.bit:
        ex de,hl
        add hl,hl
        ex de,hl
        adc hl,hl
        or a
        sbc hl,bc
        jr nc,.fits
        add hl,bc
        jr .next
.fits:
        inc e
.next:
        dec a
        jr nz,.bit
        pop af
        jp p,.quotientPositive
        ex de,hl
        call NegateHL
        ex de,hl
.quotientPositive:
        pop af
        ret p
        jp NegateHL
