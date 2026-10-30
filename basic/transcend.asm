; transcend.asm: SQR, EXP, LOG, SIN, COS, TAN, ATN and RND, worked out in double precision with this
; ROM's arithmetic:
;   SQR  Newton's iteration y = (y + x / y) / 2 from a first guess with half the exponent
;   EXP  e^x = 10^n * e^y (n = INT(x / LN 10), y = the rest * LN 10), e^y by its series
;   LOG  x = m * 10^e, m doubled into [0.5, 1): LN m = 2 * atanh((m - 1) / (m + 1)) by its series
;   SIN  brought into [0, PI / 2] by PI's symmetries, then the series; COS x = SIN(PI / 2 - x)
;   TAN  SIN / COS;  ATN  1/x above 1, the argument halved twice, then the series
;   RND  a 32-bit linear congruential generator, the state in RNDX
; The results are double precision, whatever the argument's type (as the original BASIC does).

MathT1          equ FBUFFR              ; work values (FBUFFR is free while these run)
MathT2          equ FBUFFR + 8
MathT3          equ FBUFFR + 16
MathT4          equ FBUFFR + 24
MathExp         equ FBUFFR + 32         ; EXP: n; LOG: the decimal exponent
MathCount       equ FBUFFR + 33         ; LOG: the halvings
MathSeriesSign  equ FBUFFR + 34         ; the series: 80h when the terms change sign
MathSign        equ FBUFFR + 35         ; SIN / ATN: the sign of the result
MathInverted    equ FBUFFR + 36         ; ATN: 1/x was taken

; PushDac / PopDac: DAC's 8 bytes on the stack (under the return address) and back. Destroy BC, IX.
PushDac:
        pop ix
        ld bc,(DAC + 6)
        push bc
        ld bc,(DAC + 4)
        push bc
        ld bc,(DAC + 2)
        push bc
        ld bc,(DAC)
        push bc
        jp (ix)
PopDac:
        pop ix
        pop bc
        ld (DAC),bc
        pop bc
        ld (DAC + 2),bc
        pop bc
        ld (DAC + 4),bc
        pop bc
        ld (DAC + 6),bc
        jp (ix)

; LoadDac / StoreDac / LoadArg: the 8 bytes at HL. Destroy AF, B, DE, HL.
LoadDac         equ MoveToDac
StoreDac        equ MoveDacTo
LoadArg         equ MoveToArg

; MulDacBy / AddDacTo / DivDacBy: DAC = DAC op (HL).
MulDacBy:
        call LoadArg
        jp DecMultiply
AddDacTo:
        call LoadArg
        jp DecAdd
DivDacBy:
        call LoadArg
        jp DecDivide
SubFromDac:
        call LoadArg
        jp DecSubtract

; FunctionEnd: the result is double precision whatever the argument was (as the original BASIC does).
FunctionEnd:
        ld a,TypeDouble
        ld (VALTYP),a
        ret

; FunctionStart: the argument as a double. Out: A = its type (as it was). Keeps HL... no: destroys all.
FunctionStart:
        ld a,(VALTYP)
        push af
        call ForceDouble
        xor a
        ld (DAC + 8),a
        pop af
        ret

; --- SQR ---
SqrDac:
        call FunctionStart
        push af
        call SqrDouble
        pop af
        jr FunctionEnd

SqrDouble:
        ld a,(DAC)
        or a
        ret z
        jp m,IllegalFunction
        ld hl,MathT1
        call StoreDac                   ; x
        ld a,(DAC)                      ; the guess: 0.5 * 10^ceil(e/2)
        sub $40
        sra a
        jr nc,.even
        inc a
.even:
        add a,$40
        ld hl,MathT2
        ld (hl),a
        inc hl
        ld (hl),$50
        ld b,6
.zero:
        inc hl
        ld (hl),$00
        djnz .zero
        ld c,20                         ; at most 20 steps
.step:
        push bc
        ld hl,MathT1
        call LoadDac
        ld hl,MathT2
        call DivDacBy                   ; x / y
        ld hl,MathT2
        call AddDacTo                   ; + y
        ld hl,ConstHalf
        call MulDacBy                   ; / 2
        ld hl,MathT2                    ; the same as before: done
        ld de,DAC
        ld b,$08
.compare:
        ld a,(de)
        cp (hl)
        jr nz,.changed
        inc hl
        inc de
        djnz .compare
        pop bc
        ret
.changed:
        ld hl,MathT2
        call StoreDac
        pop bc
        dec c
        jr nz,.step
        ret

; --- EXP ---
ExpDac:
        call FunctionStart
        push af
        call ExpDouble
        pop af
        jp FunctionEnd

ExpDouble:
        ld a,(DAC)
        or a
        jr nz,.notZero
        ld hl,ConstOne                  ; e^0 = 1
        jp LoadDac
.notZero:
        ld a,TypeDouble
        ld (VALTYP),a
        ld hl,ConstLn10
        call DivDacBy                   ; t = x / LN 10
        ld hl,MathT1
        call StoreDac
        ld a,TypeDouble
        ld (VALTYP),a
        call FloorDac                   ; n = INT(t)
        ld hl,MathT2
        call StoreDac
        ld a,(DAC)                      ; |n| above 99: far out of range
        and $7F
        cp $43
        jr c,.inRange
        ld a,(DAC)
        or a
        jp p,MathOverflow
        jp ZeroDac                      ; e^(very negative) = 0
.inRange:
        call ForceInteger               ; n (DAC holds it)
        ld a,l
        ld (MathExp),a
        ld hl,MathT1
        call LoadDac
        ld hl,MathT2
        call SubFromDac                 ; f = t - n, 0 <= f < 1
        ld hl,ConstLn10
        call MulDacBy                   ; y = f * LN 10, 0 <= y < 2.31
        call ExpSeries                  ; e^y
        ld a,(DAC)                      ; * 10^n: n added to the exponent
        or a
        ret z
        ld e,a
        ld d,$00
        ld a,(MathExp)
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,de
        xor a                           ; (positive)
        jp SetExponentAndFinish

; ExpSeries: DAC = e^DAC for a small DAC: the sum of z^k / k!.
ExpSeries:
        ld hl,MathT3
        call StoreDac                   ; z
        ld hl,ConstOne
        ld de,MathT4
        call Move8                      ; term = 1
        ld hl,ConstOne
        call LoadDac
        ld hl,MathT2
        call StoreDac                   ; sum = 1
        ld c,$01                        ; k
.term:
        push bc
        ld hl,MathT4
        call LoadDac
        ld hl,MathT3
        call MulDacBy                   ; term * z
        pop bc
        push bc
        ld l,c
        ld h,$00
        call DivDacByInteger            ; / k
        ld hl,MathT4
        call StoreDac
        ld a,(DAC)
        and $7F
        jr z,.done
        ld hl,MathT2
        call AddDacTo                   ; sum + term
        call IsSumUnchanged
        ld hl,MathT2
        call StoreDac
        pop bc
        jr z,.doneNoPop
        inc c
        ld a,c
        cp 40
        jr c,.term
        jr .doneNoPop
.done:
        pop bc
.doneNoPop:
        ld hl,MathT2
        jp LoadDac

; IsSumUnchanged: Z when DAC is the same as MathT2 (the term added nothing). Keeps DAC.
IsSumUnchanged:
        ld hl,MathT2
        ld de,DAC
        ld b,$08
.byte:
        ld a,(de)
        cp (hl)
        ret nz
        inc hl
        inc de
        djnz .byte
        ret

; DivDacByInteger / MulDacByInteger: DAC op the integer HL.
DivDacByInteger:
        push hl
        ld hl,DAC
        ld de,HOLD2
        ld bc,$0008
        ldir
        pop hl
        call IntegerToBcd
        call MoveDacToArg
        ld hl,HOLD2
        call LoadDac
        jp DecDivide
MulDacByInteger:
        push hl
        ld hl,DAC
        ld de,HOLD2
        ld bc,$0008
        ldir
        pop hl
        call IntegerToBcd
        call MoveDacToArg
        ld hl,HOLD2
        call LoadDac
        jp DecMultiply

; --- LOG ---
LogDac:
        call FunctionStart
        push af
        call LogDouble
        pop af
        jp FunctionEnd

LogDouble:
        ld a,(DAC)
        or a
        jp z,IllegalFunction
        jp m,IllegalFunction
        sub $41
        ld (MathExp),a                  ; e (signed): x = m * 10^e, m in [1, 10)
        ld a,$41
        ld (DAC),a
        ld c,$00                        ; C = halvings
.halve:
        ld a,(DAC)                      ; m >= 2: halved
        cp $41
        jr nz,.belowTwo
        ld a,(DAC + 1)
        cp $20
        jr c,.belowTwo
        push bc
        ld hl,ConstHalf
        call MulDacBy
        pop bc
        inc c
        jr .halve
.belowTwo:
        ld a,c
        ld (MathCount),a
        ld hl,MathT1
        call StoreDac                   ; m
        ld hl,ConstOne
        call AddDacTo
        ld hl,MathT2
        call StoreDac                   ; m + 1
        ld hl,MathT1
        call LoadDac
        ld hl,ConstOne
        call SubFromDac                 ; m - 1
        ld hl,MathT2
        call DivDacBy                   ; z
        call AtanhSeries                ; atanh z
        ld hl,ConstTwo
        call MulDacBy                   ; LN m'
        ld hl,MathT1
        call StoreDac
        ld a,(MathCount)                ; + halvings * LN 2
        ld l,a
        ld h,$00
        call IntegerToBcd
        ld hl,ConstLn2
        call MulDacBy
        ld hl,MathT1
        call AddDacTo
        ld hl,MathT1
        call StoreDac
        ld a,(MathExp)                  ; + e * LN 10
        ld l,a
        rla
        sbc a,a
        ld h,a
        call IntegerToBcd
        ld hl,ConstLn10
        call MulDacBy
        ld hl,MathT1
        jp AddDacTo

; AtanhSeries: DAC = z + z^3/3 + z^5/5 + ... (|z| < 1). AtanSeries: z - z^3/3 + z^5/5 - ...
AtanhSeries:
        ld c,$00
        jr OddSeries
AtanSeries:
        ld c,$80
OddSeries:
        ld a,c
        ld (MathSeriesSign),a           ; the sign change of z^2 (atan) or none (atanh)
        ld hl,MathT2
        call StoreDac                   ; sum = z
        ld hl,MathT4
        call StoreDac                   ; power = z
        call MoveDacToArg
        call DecMultiply
        ld a,(DAC)
        or a
        jr z,.zSquared
        ld hl,MathSeriesSign
        xor (hl)
        ld (DAC),a                      ; z^2 (negative for atan)
.zSquared:
        ld hl,MathT3
        call StoreDac
        ld c,$03
.term:
        push bc
        ld hl,MathT4
        call LoadDac
        ld hl,MathT3
        call MulDacBy                   ; power * (+-z^2)
        ld hl,MathT4
        call StoreDac
        pop bc
        push bc
        ld l,c
        ld h,$00
        call DivDacByInteger            ; / k
        ld a,(DAC)
        and $7F
        jr z,.done
        ld hl,MathT2
        call AddDacTo
        call IsSumUnchanged
        ld hl,MathT2
        call StoreDac
        pop bc
        jr z,.doneNoPop
        inc c
        inc c
        ld a,c
        cp 61
        jr c,.term
        jr .doneNoPop
.done:
        pop bc
.doneNoPop:
        ld hl,MathT2
        jp LoadDac

; --- SIN, COS, TAN ---
SinDac:
        call FunctionStart
        push af
        call SinDouble
        pop af
        jp FunctionEnd
CosDac:
        call FunctionStart
        push af
        call CosDouble
        pop af
        jp FunctionEnd
TanDac:
        call FunctionStart
        push af
        call PushDac                    ; x
        call SinDouble
        call PopDacToArgSwap            ; ARG = SIN x, DAC = x
        call PushArg                    ; SIN x on the stack
        call CosDouble
        call MoveDacToArg               ; ARG = COS x
        call PopDac                     ; DAC = SIN x
        call DecDivide
        pop af
        jp FunctionEnd

; PopDacToArgSwap: DAC goes to ARG and the 8 bytes on the stack to DAC.
PopDacToArgSwap:
        pop ix
        ld (TEMP8),ix
        call MoveDacToArg
        call PopDac
        ld ix,(TEMP8)
        jp (ix)
; PushArg: ARG's 8 bytes on the stack.
PushArg:
        pop ix
        ld bc,(ARG + 6)
        push bc
        ld bc,(ARG + 4)
        push bc
        ld bc,(ARG + 2)
        push bc
        ld bc,(ARG)
        push bc
        jp (ix)

CosDouble:
        call MoveDacToArg               ; COS x = SIN(PI / 2 - x)
        ld hl,ConstHalfPi
        call LoadDac
        call DecSubtract
SinDouble:
        ld a,(DAC)
        and $80
        ld (MathSign),a                 ; the sign of the result
        ld a,(DAC)
        and $7F
        ret z
        ld (DAC),a                      ; |x|
        ld hl,MathT1
        call StoreDac
        ld hl,ConstTwoPi                ; x - 2 PI * INT(x / 2 PI)
        call DivDacBy
        ld a,TypeDouble
        ld (VALTYP),a
        call FixDac
        ld hl,ConstTwoPi
        call MulDacBy
        call MoveDacToArg
        ld hl,MathT1
        call LoadDac
        call DecSubtract
        ld hl,ConstPi                   ; above PI: minus PI, the other sign
        call CompareWith
        jr c,.belowPi
        ld hl,ConstPi
        call SubFromDac
        ld a,(MathSign)
        xor $80
        ld (MathSign),a
.belowPi:
        ld hl,ConstHalfPi               ; above PI / 2: PI - x
        call CompareWith
        jr c,.firstQuarter
        call MoveDacToArg
        ld hl,ConstPi
        call LoadDac
        call DecSubtract
.firstQuarter:
        ld hl,ConstQuarterPi            ; above PI / 4: COS(PI / 2 - x), the smaller series
        call CompareWith
        jr c,.sinSeries
        call MoveDacToArg
        ld hl,ConstHalfPi
        call LoadDac
        call DecSubtract
        ld c,$01                        ; cosine: 1 - y^2/2! + ...: the term starts at 1, k from 1
        call TrigSeries
        jr .signAndClamp
.sinSeries:
        ld c,$02                        ; sine: y - y^3/3! + ...: the term starts at y, k from 2
        call TrigSeries
.signAndClamp:
        ld hl,ConstOne                  ; never above 1 (rounding)
        call CompareWith
        jr c,.signed
        ld hl,ConstOne
        call LoadDac
.signed:
        ld a,(DAC)
        or a
        ret z
        ld hl,MathSign
        xor (hl)
        ld (DAC),a
        ret

; TrigSeries: the series of SIN (C = 2: from y) or COS (C = 1: from 1) of the DAC y: each term is the
; one before * -y^2 / (k * (k + 1)), k going up by 2.
TrigSeries:
        push bc
        call MoveDacToArg
        call DecMultiply                ; y^2
        ld a,(DAC)
        or a
        jr z,.squared
        xor $80                         ; -y^2
        ld (DAC),a
.squared:
        ld hl,MathT3
        call StoreDac
        pop bc
        push bc
        ld a,c
        cp $02
        jr z,.fromY
        ld hl,ConstOne                  ; cosine: the first term 1
        call LoadDac
        jr .first
.fromY:
        call MoveArgToDac               ; sine: the first term y (ARG still holds it)
.first:
        ld hl,MathT2
        call StoreDac                   ; sum
        ld hl,MathT4
        call StoreDac                   ; term
        pop bc
.term:
        push bc
        ld hl,MathT4
        call LoadDac
        ld hl,MathT3
        call MulDacBy                   ; term * -y^2
        pop bc
        push bc
        ld a,c                          ; / (k * (k + 1))
        inc a
        ld l,c
        ld h,$00
        ld e,a
        ld d,$00
        call MultiplyHLDE
        call DivDacByInteger
        ld hl,MathT4
        call StoreDac
        ld a,(DAC)
        and $7F
        jr z,.done
        ld hl,MathT2
        call AddDacTo
        call IsSumUnchanged
        ld hl,MathT2
        call StoreDac
        pop bc
        jr z,.doneNoPop
        inc c
        inc c
        ld a,c
        cp 40
        jr c,.term
        jr .doneNoPop
.done:
        pop bc
.doneNoPop:
        ld hl,MathT2
        jp LoadDac

; CompareWith: carry when DAC is below the constant at HL (both positive doubles). Keeps DAC.
CompareWith:
        ld de,DAC
        ld b,$08
.byte:
        ld a,(de)
        cp (hl)
        ret nz                          ; (carry: DAC's byte is the smaller)
        inc hl
        inc de
        djnz .byte
        or a
        ret

; MultiplyHLDE: HL = HL * DE (small numbers). Destroys AF, BC.
MultiplyHLDE:
        ld b,h
        ld c,l
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
        ret

; --- ATN ---
AtnDac:
        call FunctionStart
        push af
        call AtnDouble
        pop af
        jp FunctionEnd

AtnDouble:
        ld a,(DAC)
        and $80
        ld (MathSign),a
        ld a,(DAC)
        and $7F
        ret z
        ld (DAC),a                      ; |x|
        xor a
        ld (MathInverted),a
        ld hl,ConstOne
        call CompareWith
        jr c,.small
        call MoveDacToArg               ; above 1: ATN x = PI/2 - ATN(1/x)
        ld hl,ConstOne
        call LoadDac
        call DecDivide
        ld a,$01
        ld (MathInverted),a
.small:
        ld b,2                          ; x / (1 + SQR(1 + x^2)) twice: ATN x = 4 ATN(that)
.halve:
        push bc
        call PushDac                    ; x (SQR uses the work values)
        call MoveDacToArg
        call DecMultiply
        ld hl,ConstOne
        call AddDacTo
        call SqrDouble
        ld hl,ConstOne
        call AddDacTo
        call PopDacToArgSwap            ; ARG = 1 + SQR(...), DAC = x
        call DecDivide
        pop bc
        djnz .halve
        call AtanSeries
        ld hl,ConstFour
        call MulDacBy
        ld a,(MathInverted)
        or a
        jr z,.signed
        call MoveDacToArg
        ld hl,ConstHalfPi
        call LoadDac
        call DecSubtract
.signed:
        ld a,(DAC)
        or a
        ret z
        ld hl,MathSign
        or (hl)
        ld (DAC),a
        ret

; --- RND ---
; RND(x): x > 0 the next number, x = 0 the last one again, x < 0 a new start from x. 0 <= RND < 1.
RndDac:
        call FunctionStart
        push af
        call RndDouble
        pop af
        jp FunctionEnd

RndDouble:
        ld a,(DAC)
        or a
        jr z,.fromState                 ; RND(0): the last one
        jp p,.next
        ld hl,(DAC + 1)                 ; a negative x: the state from its digits
        ld (RNDX),hl
        ld hl,(DAC + 3)
        ld (RNDX + 2),hl
.next:
        ; state = state * 214013 + 2531011 (mod 2^32)
        call Rnd32Step
.fromState:
        ; 14 digits of state / 2^32
        call ZeroDac
        ld hl,(RNDX)
        ld (HOLD2),hl
        ld hl,(RNDX + 2)
        ld (HOLD2 + 2),hl
        ld de,DAC + 1
        ld b,14
.digit:
        push bc
        push de
        call Rnd32Times10               ; A = the digit that comes out on top
        pop de
        pop bc
        bit 0,b
        jr z,.highNibble
        ex de,hl
        or (hl)
        ld (hl),a
        ex de,hl
        inc de
        jr .placed
.highNibble:
        rlca
        rlca
        rlca
        rlca
        ld (de),a
.placed:
        djnz .digit
        ld a,$40
        ld (DAC),a
        jp NormaliseDac

; Rnd32Step: (RNDX) = (RNDX) * 214013 + 2531011, 32 bits.
Rnd32Step:
        ld hl,RNDX
        ld de,HOLD2
        ld bc,$0004
        ldir                            ; the old state
        ld hl,RNDX                      ; state = 0
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld hl,RndMultiplier             ; for each set bit of the multiplier: + old << bit
        ld c,$00                        ; C = the bit
.bit:
        ld a,c
        cp 32
        jr nc,.add
        srl a
        srl a
        srl a
        ld e,a
        ld d,$00
        push hl
        add hl,de
        ld b,(hl)
        pop hl
        ld a,c
        and $07
        jr z,.tested
.shiftBit:
        srl b
        dec a
        jr nz,.shiftBit
.tested:
        bit 0,b
        call nz,.addShifted
        inc c
        jr .bit
.add:
        ld hl,RNDX                      ; + 2531011 (0026_9EC3)
        ld de,RndIncrement
        ld b,$04
        or a
.addByte:
        ld a,(de)
        adc a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz .addByte
        ret
.addShifted:                            ; RNDX += HOLD2 << C
        push hl
        push bc
        ld hl,HOLD2
        ld de,HOLD2 + 4
        ld bc,$0004
        ldir                            ; a copy to shift
        pop bc
        push bc
        ld a,c
        or a
        jr z,.shifted
        ld b,a
.shift:
        ld hl,HOLD2 + 4
        sla (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        inc hl
        rl (hl)
        djnz .shift
.shifted:
        ld hl,RNDX
        ld de,HOLD2 + 4
        ld b,$04
        or a
.addCopy:
        ld a,(de)
        adc a,(hl)
        ld (hl),a
        inc hl
        inc de
        djnz .addCopy
        pop bc
        pop hl
        ret

RndMultiplier:
        db $FD, $43, $03, $00           ; 214013
RndIncrement:
        db $C3, $9E, $26, $00           ; 2531011

; Rnd32Times10: HOLD2 (32-bit fraction) * 10: A = the integer part, HOLD2 = the new fraction.
Rnd32Times10:
        ld hl,HOLD2
        ld b,$04
        ld c,$00                        ; carry into the next byte
.byte:
        push bc
        ld e,(hl)
        ld d,$00
        ex de,hl                        ; HL = byte
        add hl,hl
        ld b,h
        ld c,l                          ; * 2
        add hl,hl
        add hl,hl                       ; * 8
        add hl,bc                       ; * 10
        pop bc
        ld a,l
        add a,c
        ld l,a
        jr nc,.noCarry
        inc h
.noCarry:
        ex de,hl
        ld (hl),e
        inc hl
        ld c,d
        djnz .byte
        ld a,c
        ret

; Constants (doubles)
ConstOne:       db $41, $10, 0, 0, 0, 0, 0, 0
ConstTwo:       db $41, $20, 0, 0, 0, 0, 0, 0
ConstFour:      db $41, $40, 0, 0, 0, 0, 0, 0
ConstHalf:      db $40, $50, 0, 0, 0, 0, 0, 0
ConstPi:        db $41, $31, $41, $59, $26, $53, $58, $98
ConstHalfPi:    db $41, $15, $70, $79, $63, $26, $79, $49
ConstQuarterPi: db $40, $78, $53, $98, $16, $33, $97, $45
ConstTwoPi:     db $41, $62, $83, $18, $53, $07, $17, $96
ConstLn10:      db $41, $23, $02, $58, $50, $92, $99, $40
ConstLn2:       db $40, $69, $31, $47, $18, $05, $59, $95
