; eval.asm: expressions. One loop climbs the precedences: an operand, then while the next operator
; binds at least as tightly as asked, the left value waits on the stack while the right one is worked
; out one level higher. Precedences (the original BASIC's): IMP 1, EQV 2, XOR 3, OR 4, AND 5, NOT 6 (unary),
; relations 7, + - 8, MOD 9, \ 10, * / 11, unary minus 12, ^ 13. Real arithmetic is done in double
; precision and rounded to 6 digits when the result is single precision.
;
; A value: VALTYP and DAC (an integer at DAC + 2; a string: DAC + 2 = the address of its descriptor,
; 3 bytes: length, address).

PrecNot         equ 6
PrecRelation    equ 7
PrecUnary       equ 12
PrecPower       equ 13

; Operator codes (the low byte of OperatorTable entries)
OpImp           equ 0
OpEqv           equ 1
OpXor           equ 2
OpOr            equ 3
OpAnd           equ 4
OpRelation      equ 5
OpAdd           equ 6
OpSubtract      equ 7
OpMod           equ 8
OpIntDivide     equ 9
OpMultiply      equ 10
OpDivide        equ 11
OpPower         equ 12

; EvalExpression: FRMEVL. In: HL on the expression. Out: the value, HL on what follows it.
EvalExpression:
        ld b,$01
; EvalPrecedence: an expression whose operators bind at least with precedence B.
EvalPrecedence:
        push bc
        call EvalUnary
        pop bc
.operator:
        call ThisChar
        call OperatorInfo               ; C = precedence (0: no operator), E = operator code
        ld a,c
        or a
        ret z
        cp b
        ret c                           ; it binds less: the caller takes it
        ld d,$00
        ld a,e
        cp OpRelation
        jr nz,.notRelation
        call RelationMask               ; D = > 1, = 2, < 4 (HL past them)
        jr .haveOperator
.notRelation:
        rst $10                         ; past the operator
.haveOperator:
        push bc                         ; B = this level's minimum
        push de                         ; the operator and the relation mask
        ld d,c
        inc d                           ; the right operand binds one level higher (PushLeft uses BC)
        call PushLeft
        ld b,d
        call EvalPrecedence
        call ApplyOperator              ; takes the left value and the operator off the stack
        pop bc
        jr .operator

; OperatorInfo: In: A = character. Out: C = precedence (0 when it is no operator), E = operator code.
; Destroys AF, D... (preserves B, HL)
OperatorInfo:
        push hl
        ld hl,OperatorTable
        ld c,a
.find:
        ld a,(hl)
        inc hl
        or a
        jr z,.none
        cp c
        jr z,.found
        inc hl
        inc hl
        jr .find
.found:
        ld c,(hl)                       ; precedence
        inc hl
        ld e,(hl)                       ; code
        pop hl
        ret
.none:
        ld c,$00
        pop hl
        ret

OperatorTable:                          ; token, precedence, code
        db TkImp, 1, OpImp
        db TkEqv, 2, OpEqv
        db TkXor, 3, OpXor
        db TkOr, 4, OpOr
        db TkAnd, 5, OpAnd
        db TkGreater, PrecRelation, OpRelation
        db TkEqual, PrecRelation, OpRelation
        db TkLess, PrecRelation, OpRelation
        db TkPlus, 8, OpAdd
        db TkMinus, 8, OpSubtract
        db TkMod, 9, OpMod
        db TkBackslash, 10, OpIntDivide
        db TkTimes, 11, OpMultiply
        db TkSlash, 11, OpDivide
        db TkPower, PrecPower, OpPower
        db 0

; RelationMask: the relation at HL (>, =, <, >=, <=, <>, =>, =<, ><). Out: D = mask of the outcomes that
; make it true (1 greater, 2 equal, 4 less), HL past it. Keeps BC, E.
RelationMask:
        ld d,$00
.symbol:
        call ThisChar
        push bc
        ld b,$01
        cp TkGreater
        jr z,.add
        ld b,$02
        cp TkEqual
        jr z,.add
        ld b,$04
        cp TkLess
        jr z,.add
        pop bc
        ret
.add:
        ld a,d
        or b
        ld d,a
        pop bc
        inc hl
        jr .symbol

; EvalUnary: an operand with its unary operators: - and + (they bind above * /, below ^), NOT.
EvalUnary:
        call ThisChar
        cp TkMinus
        jr z,.minus
        cp TkPlus
        jr z,.plus
        cp TkNot
        jr z,.not
        jp EvalPrimaryPower
.plus:
        rst $10
        ld b,PrecUnary
        jp EvalPrecedence
.minus:
        rst $10
        ld b,PrecUnary
        call EvalPrecedence
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        push hl
        call NegateDac
        pop hl
        ret
.not:
        rst $10
        ld b,PrecNot + 1                ; NOT A = B is NOT (A = B)
        call EvalPrecedence
; NotDac: DAC = NOT DAC (as an integer). Keeps HL.
NotDac:
        push hl
        call DacToInteger
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        call SetIntegerResultHL
        pop hl
        ret

; EvalPrimaryPower: an operand and the ^ after it (the exponent may have a sign: 2^-1).
EvalPrimaryPower:
        call EvalPrimary
.power:
        call ThisChar
        cp TkPower
        ret nz
        rst $10
        ld de,OpPower
        push de
        call PushLeft
        call ThisChar
        cp TkMinus
        jr z,.signed
        cp TkPlus
        jr z,.signed
        call EvalPrimary
        jr .apply
.signed:
        call EvalUnary
.apply:
        call ApplyOperator
        jr .power

; --- the left operand on the stack ---

; PushLeft: VALTYP and DAC on the stack (under the return address). Destroys AF, BC, IX.
PushLeft:
        pop ix
        ld bc,(DAC + 6)
        push bc
        ld bc,(DAC + 4)
        push bc
        ld bc,(DAC + 2)
        push bc
        ld bc,(DAC)
        push bc
        ld a,(VALTYP)
        push af
        jp (ix)

; ApplyOperator: left op right. The stack holds (under the return address) the left value as PushLeft
; left it, then the operator word (E = code, D = relation mask). Right = DAC. Out: DAC. Keeps HL.
ApplyOperator:
        pop ix                          ; the return address
        pop af                          ; the left value into ARG, its type in E
        ld e,a
        pop iy
        ld (ARG),iy
        pop iy
        ld (ARG + 2),iy
        pop iy
        ld (ARG + 4),iy
        pop iy
        ld (ARG + 6),iy
        pop bc                          ; C = operator, B = relation mask
        push ix
        push hl
        ld a,(VALTYP)
        ld d,a                          ; D = right type, E = left type
        cp TypeString
        jp z,.strings
        ld a,e
        cp TypeString
        jp z,TypeMismatch
        ld a,c
        cp OpRelation
        jp z,.relation
        jr c,.integerOnly               ; the logical operators
        cp OpMod
        jr z,.integerOnly
        cp OpIntDivide
        jr z,.integerOnly
        ; + - * / ^: the larger type; / and ^ of integers give double precision
        ld a,d
        cp e
        jr nc,.typeGot
        ld a,e
.typeGot:
        ld b,a
        ld a,c
        cp OpPower
        ld a,b
        jr z,.integersToDouble          ; ^ always gives double precision
        cp TypeInteger
        jr nz,.real
        ld a,c
        cp OpDivide
        jr nc,.integersToDouble
        ld hl,(DAC + 2)                 ; integer + - *
        ld de,(ARG + 2)
        cp OpAdd
        jr nz,.notAdd
        call IntAdd
        jr .done
.notAdd:
        cp OpSubtract
        jr nz,.multiply
        call IntSubtract
        jr .done
.multiply:
        call IntMultiplyOrReal
        jr .done
.integersToDouble:
        ld a,TypeDouble
.real:
        ld (TEMP3),a                    ; the result's type
        push bc
        push de
        call ForceDouble                ; right, double
        pop de
        ld a,e
        call LeftToDac                  ; DAC = left (its type), ARG = right
        call ForceDouble
        pop bc
        ld a,c
        call RealOperation              ; DAC = DAC op ARG
        ld a,(TEMP3)
        cp TypeSingle
        call z,ForceSingle
        jr .done
.integerOnly:
        push bc
        push de
        call DacToInteger               ; right
        pop de
        push hl
        ld a,e
        call LeftToDacAgain
        call DacToInteger               ; left
        ex de,hl                        ; DE = left
        pop hl                          ; HL = right
        pop bc
        ld a,c
        call IntegerOperation
        call SetIntegerResultHL
        jr .done
.relation:
        push bc
        ld a,d
        cp TypeInteger
        jr nz,.relationReal
        ld a,e
        cp TypeInteger
        jr nz,.relationReal
        ld hl,(DAC + 2)
        ld de,(ARG + 2)
        call CompareIntegers            ; A = 1 when left is below, 0, FFh above
        jr .relationResult
.relationReal:
        push de
        call ForceDouble                ; right
        pop de
        ld a,e
        call LeftToDac                  ; DAC = left, ARG = right
        call ForceDouble
        call SwapDacArg                 ; ARG = left, DAC = right
        call CompareDoubles
.relationResult:
        pop bc
        call RelationTruth
.done:
        pop hl
        ret
.strings:
        ld a,e
        cp TypeString
        jp nz,TypeMismatch
        ld hl,(ARG + 2)                 ; left descriptor
        ld de,(DAC + 2)                 ; right descriptor
        ld a,c
        cp OpAdd
        jr z,.concatenate
        cp OpRelation
        jp nz,TypeMismatch
        push bc
        call CompareStrings
        jr .relationResult
.concatenate:
        call ConcatStrings
        jr .done

; LeftToDac: DAC (right, already in its final form) goes to ARG, the left value (in ARG) to DAC with
; VALTYP = A. LeftToDacAgain: only the left value to DAC (the right is not needed in ARG).
; Destroys AF, BC, DE (keeps HL).
LeftToDac:
        push hl
        push af
        call SwapDacArg
        pop af
        ld (VALTYP),a
        pop hl
        ret
LeftToDacAgain:
        push hl
        ld (VALTYP),a
        ld hl,ARG
        ld de,DAC
        ld bc,$0008
        ldir
        pop hl
        ret

; RelationTruth: A = the comparison (1 left below, 0 equal, FFh above), B = mask (1 >, 2 =, 4 <).
; DAC = -1 when the relation holds, else 0.
RelationTruth:
        ld c,$02
        or a
        jr z,.test
        ld c,$04
        dec a
        jr z,.test
        ld c,$01
.test:
        ld a,b
        and c
        ld hl,$0000
        jr z,SetIntegerResultHL
        dec hl
; SetIntegerResultHL: DAC = the integer HL. Preserves HL... (destroys A)
SetIntegerResultHL:
        ld (DAC + 2),hl
        ld a,TypeInteger
        ld (VALTYP),a
        ret

; SetIntegerResult: DAC = the integer DE. Destroys A.
SetIntegerResult:
        ld (DAC + 2),de
        ld a,TypeInteger
        ld (VALTYP),a
        ret

; IntegerOperation: HL = DE op HL for the logical operators, MOD and \. In: A = operator code.
IntegerOperation:
        cp OpMod
        jp z,IntModulo
        cp OpIntDivide
        jp z,IntDivide
        cp OpAnd
        jr z,.and
        cp OpOr
        jr z,.or
        cp OpXor
        jr z,.xor
        cp OpEqv
        jr z,.eqv
        ; IMP: NOT left OR right
        ld a,d
        cpl
        or h
        ld h,a
        ld a,e
        cpl
        or l
        ld l,a
        ret
.and:
        ld a,d
        and h
        ld h,a
        ld a,e
        and l
        ld l,a
        ret
.or:
        ld a,d
        or h
        ld h,a
        ld a,e
        or l
        ld l,a
        ret
.xor:
        ld a,d
        xor h
        ld h,a
        ld a,e
        xor l
        ld l,a
        ret
.eqv:
        call .xor
        ld a,h
        cpl
        ld h,a
        ld a,l
        cpl
        ld l,a
        ret

; RealOperation: DAC = DAC op ARG (doubles). In: A = operator code.
RealOperation:
        cp OpAdd
        jp z,DecAdd
        cp OpSubtract
        jp z,DecSubtract
        cp OpMultiply
        jp z,DecMultiply
        cp OpDivide
        jp z,DecDivide
        jp RealPower

; IntMultiplyOrReal: HL = DE * HL; when it does not fit, the product in single precision.
IntMultiplyOrReal:
        push de
        push hl
        call IntMultiplyChecked
        jr c,.real
        pop af
        pop af
        jp IntResult
.real:
        pop hl
        call IntegerToBcd               ; DAC = right
        call MoveDacToArg
        pop hl
        call IntegerToBcd               ; DAC = left
        call DecMultiply
        jp ForceSingle

; DacToInteger: the number in DAC as an integer (Overflow outside -32768..32767). Out: HL.
; Destroys all but... (as FRCINT)
DacToInteger:
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        jp ForceInteger

; RealPower: DAC = DAC ^ ARG (doubles). A whole exponent: by squaring (exact as far as the digits go);
; another: EXP(exponent * LOG(base)) (stage 6: Illegal function call for now).
PowerBase       equ HOLD                ; 8 bytes
PowerResult     equ HOLD2               ; 8 bytes

RealPower:
        push hl
        ld hl,DAC
        ld de,PowerBase
        ld bc,$0008
        ldir                            ; the base kept
        call MoveArgToDac               ; the exponent: is it a whole number?
        ld hl,DAC
        ld de,PowerResult
        ld bc,$0008
        ldir
        ld a,TypeDouble
        ld (VALTYP),a
        call TruncateDac
        ld hl,DAC
        ld de,PowerResult
        ld b,$08
.whole:
        ld a,(de)
        cp (hl)
        jp nz,.notWhole
        inc hl
        inc de
        djnz .whole
        call ForceInteger               ; HL = n (Overflow for a huge exponent)
        push hl                         ; (its sign for the end)
        bit 7,h
        call nz,NegateHL
        ex de,hl                        ; DE = |n|
        ld hl,OneDouble                 ; result = 1
        push de
        ld de,PowerResult
        ld bc,$0008
        ldir
        pop de
.bit:
        ld a,d
        or e
        jr z,.done
        srl d
        rr e
        jr nc,.square
        push de                         ; result = result * base
        ld hl,PowerResult
        call MoveToDac
        ld hl,PowerBase
        call MoveToArg
        call DecMultiply
        ld hl,PowerResult
        call MoveDacTo
        pop de
.square:
        ld a,d
        or e
        jr z,.done
        push de                         ; base = base * base
        ld hl,PowerBase
        call MoveToDac
        ld hl,PowerBase
        call MoveToArg
        call DecMultiply
        ld hl,PowerBase
        call MoveDacTo
        pop de
        jr .bit
.done:
        ld hl,PowerResult
        call MoveToDac
        pop hl                          ; a negative exponent: 1 / result
        bit 7,h
        jr z,.positive
        call MoveDacToArg
        ld hl,OneDouble
        call MoveToDac
        call DecDivide
.positive:
        ld a,TypeDouble
        ld (VALTYP),a
        pop hl
        ret
.notWhole:                              ; a fraction: EXP(exponent * LOG(base)), the base not negative
        ld a,(PowerBase)
        or a
        jr z,.zeroBase
        jp m,.negativeBase
        ld hl,PowerResult               ; ^ .5 is SQR (exact to the last digit)
        ld de,ConstHalf
        ld b,$08
.isHalf:
        ld a,(de)
        cp (hl)
        jr nz,.general
        inc hl
        inc de
        djnz .isHalf
        ld hl,PowerBase
        call MoveToDac
        call SqrDouble
        ld a,TypeDouble
        ld (VALTYP),a
        pop hl
        ret
.general:
        ld hl,PowerResult               ; the exponent (DIVs by integers use HOLD2: keep it apart)
        call MoveToDac
        call PushDac
        ld hl,PowerBase
        call MoveToDac
        call LogDouble
        call PopDacToArgSwap            ; ARG = LOG(base), DAC = exponent
        call DecMultiply
        call ExpDouble
        ld a,TypeDouble
        ld (VALTYP),a
        pop hl
        ret
.zeroBase:                              ; 0 ^ positive = 0 (negative: Division by zero)
        ld a,(PowerResult)
        or a
        jp m,MathDivisionByZero
        call ZeroDac
        ld a,TypeDouble
        ld (VALTYP),a
        pop hl
        ret
.negativeBase:
        pop hl
        jp IllegalFunction

OneDouble:
        db $41, $10, 0, 0, 0, 0, 0, 0
