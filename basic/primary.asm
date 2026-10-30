; primary.asm: operands (numbers in the text, strings in quotes, brackets, variables) and the functions.

; EvalPrimary: one operand. In: HL on it. Out: DAC, HL after it.
EvalPrimary:
        call H_EVAL
        call ThisChar
        ld e,ErrMissingOperand
        jp z,RaiseError                 ; the statement ended
        cp '"'
        jp z,StringLiteral
        cp '('
        jr nz,.notBracket
        rst $10
        call EvalExpression
        call ThisChar
        rst $08
        db ')'
        jp ThisChar
.notBracket:
        cp $20
        jp c,ConstantOperand
        cp '&'
        jp z,FinOperand
        cp '.'
        jp z,FinOperand
        cp '0'
        jr c,.notDigit
        cp '9' + 1
        jp c,FinOperand
.notDigit:
        call IsLetter
        jp nc,VariableOperand
        cp TkFunction
        jp z,FunctionOperand
        ld e,a
        push hl
        ld hl,TokenOperands
.find:
        ld a,(hl)
        inc hl
        or a
        jr z,.none
        cp e
        jr z,.found
        inc hl
        inc hl
        jr .find
.found:
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push de
        rst $10                         ; past the token
        ret                             ; to the operand's routine
.none:
        pop hl
        jp SyntaxError

TokenOperands:                          ; tokens that are operands
        db TkErl : dw OperandErl
        db TkErr : dw OperandErr
        db TkCsrlin : dw OperandCsrlin
        db TkInkeyStr : dw OperandInkey
        db TkStringStr : dw OperandString
        db TkInstr : dw OperandInstr
        db TkVarptr : dw OperandVarptr
        db TkTime : dw OperandTime
        db TkVdp : dw OperandVdp
        db TkBase : dw OperandBase
        db TkMinus : dw OperandMinus
        db TkPlus : dw EvalPrimary
        db TkNot : dw OperandNot
        db TkUsr : dw OperandUsr
        db TkFn : dw OperandFn
        db TkPoint : dw OperandPoint
        db TkPlay : dw OperandPlay
        db TkInput : dw OperandInput
        db 0

OperandMinus:                           ; (a sign where EvalUnary did not look: 2^-1 went there)
        call EvalPrimary
        push hl
        call NegateDac
        pop hl
        ret
OperandNot:
        call EvalPrimary
        jp NotDac

; ConstantOperand: a number token of the text (A = it). Out: DAC, HL past it.
ConstantOperand:
        cp $11
        jr c,.notDigit
        cp $1A + 1
        jr nc,.notDigit
        sub $11                         ; 0-9
        ld e,a
        ld d,$00
        inc hl
        jp SetIntegerResult
.notDigit:
        inc hl
        cp $0F
        jr nz,.notByte
        ld e,(hl)
        ld d,$00
        inc hl
        jp SetIntegerResult
.notByte:
        cp $1D
        jr z,.single
        cp $1F
        jr z,.double
        cp $0D
        jr z,.pointer
        ld e,(hl)                       ; 0Bh, 0Ch, 0Eh, 1Ch: a word
        inc hl
        ld d,(hl)
        inc hl
        cp $0E
        jp nz,SetIntegerResult
        jp SetUnsignedResult            ; a line number: unsigned
.pointer:
        ld e,(hl)                       ; the line it points to: its number
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        jp SetUnsignedResult
.single:
        ld a,TypeSingle
        ld bc,$0004
        jr .real
.double:
        ld a,TypeDouble
        ld bc,$0008
.real:
        ld (VALTYP),a
        push bc
        push hl
        call ZeroDac
        pop hl
        pop bc
        ld de,DAC
        ldir
        ret

; SetUnsignedResult: DAC = DE read unsigned (an integer up to 32767, single precision above). Keeps HL.
SetUnsignedResult:
        bit 7,d
        jp z,SetIntegerResult
        push hl
        ex de,hl
        call IntegerToBcd               ; (8000h-FFFFh read as 32768-65535)
        call ForceSingle
        pop hl
        ret

; FinOperand: a number written in ASCII (&B..., or text that FIN reads). Keeps the text pointer moving.
FinOperand:
        ld a,(hl)
        jp FinNumber

; VariableOperand: the value of a variable.
VariableOperand:
        call GetVariable
        push hl
        ld a,(VALTYP)
        cp TypeString
        jr z,.string
        ex de,hl
        cp TypeInteger
        jr nz,.real
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        jp SetIntegerResult
.real:
        push af
        push hl
        call ZeroDac
        pop hl
        pop af
        ld c,a
        ld b,$00
        ld de,DAC
        ldir
        pop hl
        ret
.string:
        ld (DAC + 2),de                 ; the variable's own descriptor
        pop hl
        ret

; --- argument helpers (HL = text) ---

; EvalNumeric: an expression that must be a number.
EvalNumeric:
        call EvalExpression
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        ret

; EvalInteger: a number as an integer. Out: DE. Keeps HL.
EvalInteger:
        call EvalNumeric
        push hl
        call ForceInteger
        ex de,hl
        pop hl
        ret

; EvalByte: a number 0-255. Out: A = E. (Illegal function call otherwise.)
EvalByte:
        call EvalInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld a,e
        ret

; EvalAddress: a number 0-65535 (or -32768-65535). Out: DE. Keeps HL.
EvalAddress:
        call EvalNumeric
        push hl
        call DacToAddress
        ex de,hl
        pop hl
        ret

; DacToAddress: HL = the number in DAC as a 16-bit address (values above 32767 wrap). Destroys all.
DacToAddress:
        ld a,(VALTYP)
        cp TypeInteger
        jp z,ForceInteger
        call ForceDouble
        ld a,(DAC)
        cp $45
        jp nz,ForceInteger              ; below 10000 (or negative): as it is
        ld a,(DAC + 1)
        cp $32                          ; 32768 and up: minus 65536
        jp c,ForceInteger
        ld hl,Minus65536
        call MoveToArg
        call DecAdd
        jp ForceInteger
Minus65536:
        db $C5, $65, $53, $60, 0, 0, 0, 0

; ParenNumeric: "(" a number ")". Keeps HL moving past the bracket.
ParenNumeric:
        call ThisChar
        rst $08
        db '('
        call EvalNumeric
        jp CloseBracket
; ParenInteger: "(" an integer ")". Out: DE.
ParenInteger:
        call ThisChar
        rst $08
        db '('
        call EvalInteger
        jp CloseBracket
; ParenString: "(" a string ")". Out: B = length, DE = characters (released).
ParenString:
        call ThisChar
        rst $08
        db '('
        call EvalExpression
        call CloseBracket
        push hl
        call StringOperand
        pop hl
        ret
; CloseBracket: ")" at HL. Keeps the registers but AF.
CloseBracket:
        call ThisChar
        rst $08
        db ')'
        jp ThisChar
; Comma: "," at HL.
Comma:
        call ThisChar
        rst $08
        db ','
        ret

; --- functions (FFh + token) ---

FunctionOperand:
        inc hl
        ld a,(hl)
        sub FnLeftStr
        jp c,SyntaxError
        cp FnMkdStr - FnLeftStr + 1
        jp nc,SyntaxError
        add a,a
        ld e,a
        ld d,$00
        push hl
        ld hl,FunctionTable
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        push de
        rst $10
        ret

FunctionTable:
        dw FuncLeft, FuncRight, FuncMid, FuncSgn, FuncInt, FuncAbs, FuncSqr, FuncRnd, FuncSin, FuncLog, FuncExp, FuncCos
        dw FuncTan, FuncAtn, FuncFre, FuncInp, FuncPos, FuncLen, FuncStr, FuncVal, FuncAsc, FuncChr, FuncPeek, FuncVpeek
        dw FuncSpace, FuncOct, FuncHex, FuncLpos, FuncBin, FuncCint, FuncCsng, FuncCdbl, FuncFix, FuncStick, FuncStrig
        dw FuncPdl, FuncPad, FuncDisk, FuncDisk, FuncDisk, FuncDisk, FuncDisk, FuncEof, FuncDisk, FuncDisk, FuncDisk
        dw FuncDisk, FuncDisk

; Numbers of a number: the argument in brackets, then a routine on DAC (HL kept around it).
FuncSgn:
        ld de,SgnDac
        jr NumericFunction
FuncAbs:
        ld de,AbsDac
        jr NumericFunction
FuncFix:
        ld de,FixDac
        jr NumericFunction
FuncInt:
        ld de,FloorDac
        jr NumericFunction
FuncCint:
        ld de,ForceInteger
        jr NumericFunction
FuncCsng:
        ld de,ForceSingle
        jr NumericFunction
FuncCdbl:
        ld de,ForceDouble
        jr NumericFunction
FuncSqr:
        ld de,SqrDac
        jr NumericFunction
FuncRnd:
        ld de,RndDac
        jr NumericFunction
FuncSin:
        ld de,SinDac
        jr NumericFunction
FuncLog:
        ld de,LogDac
        jr NumericFunction
FuncExp:
        ld de,ExpDac
        jr NumericFunction
FuncCos:
        ld de,CosDac
        jr NumericFunction
FuncTan:
        ld de,TanDac
        jr NumericFunction
FuncAtn:
        ld de,AtnDac
NumericFunction:
        push de
        call ParenNumeric
        pop de
        push hl
        ld hl,.back
        push hl
        ex de,hl
        jp (hl)
.back:
        pop hl
        ret

; FloorDac: INT: the largest whole number not above DAC.
FloorDac:
        ld a,(VALTYP)
        cp TypeInteger
        ret z
        ld hl,DAC
        ld de,HOLD2
        ld bc,$0008
        ldir                            ; the value before
        call FixDac
        ld a,(DAC)
        or a
        ret p                           ; positive (or 0): cutting is enough
        ld hl,HOLD2                     ; negative: if something was cut, one less
        ld de,DAC
        ld b,$08
.same:
        ld a,(de)
        cp (hl)
        jr nz,.cut
        inc hl
        inc de
        djnz .same
        ret
.cut:
        ld a,(VALTYP)
        push af
        call ForceDouble
        ld hl,MinusOne
        call MoveToArg
        call DecAdd
        pop af
        cp TypeSingle
        ret nz
        jp ForceSingle
MinusOne:
        db $C1, $10, 0, 0, 0, 0, 0, 0

; FuncLen / FuncAsc / FuncVal: of a string.
FuncLen:
        call ParenString
        ld e,b
        ld d,$00
        jp SetIntegerResult
FuncAsc:
        call ParenString
        ld a,b
        or a
        jp z,IllegalFunction
        ld a,(de)
        ld e,a
        ld d,$00
        jp SetIntegerResult
FuncVal:
        call ParenString
        push hl
        ld hl,FBUFFR                    ; a copy with an end (FIN reads past the string otherwise)
        ld a,b
        cp 40
        jr c,.copy
        ld b,40
.copy:
        ld c,b
        ld b,$00
        ex de,hl
        or a
        jr z,.empty
        ldir
.empty:
        xor a
        ld (de),a
        ld hl,FBUFFR
        ld a,(hl)
        call FinNumber
        pop hl
        ret

; FuncChr: CHR$(n).
FuncChr:
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld a,e
; OneCharString: a temporary string of the character A. Keeps HL.
OneCharString:
        push hl
        ld (FBUFFR),a
        ld hl,FBUFFR
        ld b,$01
        call MakeString
        pop hl
        ret

; FuncStr: STR$(n): the number as PRINT shows it (with its space).
FuncStr:
        call ParenNumeric
        push hl
        xor a
        call FormatNumber
        call StringFromZeroEnded
        pop hl
        ret

; StringFromZeroEnded: a temporary string copied from the zero ended text at HL.
StringFromZeroEnded:
        push hl
        ld b,$00
.count:
        ld a,(hl)
        or a
        jr z,.counted
        inc hl
        inc b
        jr .count
.counted:
        pop hl
        jp MakeString

; FuncHex / FuncOct / FuncBin: the integer (as 16 bits) in base 16, 8, 2.
FuncHex:
        ld c,$04                        ; bits a digit
        jr RadixFunction
FuncOct:
        ld c,$03
        jr RadixFunction
FuncBin:
        ld c,$01
RadixFunction:
        push bc
        call ParenNumeric
        push hl
        call DacToAddress
        pop de
        pop bc
        push de
        call RadixText                  ; HL = the text
        call StringFromZeroEnded
        pop hl
        ret

; RadixText: the digits of HL in base 2^C (C = 1, 3 or 4), no leading zeros, zero ended.
; Out: HL = the text (in FBUFFR). Destroys AF, BC, DE.
RadixText:
        ld a,$01                        ; B = the mask of one digit: 2^C - 1
        ld b,c
.mask:
        add a,a
        djnz .mask
        dec a
        ld b,a
        ld de,FBUFFR + 20               ; from the last digit backwards
        xor a
        ld (de),a
.digit:
        ld a,l
        and b
        add a,'0'
        cp '9' + 1
        jr c,.isDigit
        add a,'A' - '9' - 1
.isDigit:
        dec de
        ld (de),a
        push bc
        ld b,c
.shift:
        srl h
        rr l
        djnz .shift
        pop bc
        ld a,h
        or l
        jr nz,.digit
        ex de,hl
        ret

; FuncLeft / FuncRight / FuncMid: parts of a string. The string's descriptor waits on the stack while the
; other arguments are worked out, and is read at the end (a garbage collection keeps it right).
FuncLeft:
        call StringAndCount             ; B = length, DE = characters, C = count
        ld a,c
        cp b
        jr nc,SubString                 ; the whole string
        ld b,c
        jr SubString
FuncRight:
        call StringAndCount
        ld a,b
        sub c
        jr c,SubString                  ; the whole string
        add a,e                         ; from length - count on
        ld e,a
        jr nc,.noCarry
        inc d
.noCarry:
        ld b,c
        jr SubString
FuncMid:
        call ParenStringFirst           ; the descriptor on the stack
        call Comma
        call EvalByte                   ; the start (from 1)
        or a
        jp z,IllegalFunction
        ld c,a
        ld b,$FF                        ; the count: all by default
        push bc
        call ThisChar
        cp ','
        jr nz,.noCount
        rst $10
        call EvalByte
        pop bc
        ld b,a
        push bc
.noCount:
        call CloseBracket
        pop bc                          ; C = start, B = count
        ex (sp),hl                      ; HL = the descriptor, the text on the stack
        push bc
        call ReleaseString              ; B = length, DE = characters
        pop hl                          ; L = start, H = count
        ld a,l
        dec a                           ; characters skipped
        cp b
        jr nc,.empty                    ; it starts after the end
        ld c,a
        add a,e
        ld e,a
        jr nc,.noCarry
        inc d
.noCarry:
        ld a,b
        sub c
        ld b,a                          ; B = characters left
        ld a,h
        cp b
        jr nc,.take
        ld b,h
.take:
        pop hl
        jr SubString
.empty:
        ld b,$00
        pop hl
        jr SubString

; StringAndCount: "(" string "," count ")". Out: B = length, DE = characters, C = count.
StringAndCount:
        call ParenStringFirst
        call Comma
        call EvalByte
        push af
        call CloseBracket
        pop af
        ex (sp),hl                      ; HL = the descriptor, the text on the stack
        push af
        call ReleaseString
        pop af
        ld c,a
        pop hl
        ret

; SubString: a new temporary string of B characters from DE. Keeps HL.
SubString:
        push hl
        ex de,hl
        call MakeString
        pop hl
        ret

; ParenStringFirst: "(" and a string: its descriptor is left on the stack (under the return address).
ParenStringFirst:
        call ThisChar
        rst $08
        db '('
        call EvalExpression
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        pop de                          ; the return address
        push hl
        ld hl,(DAC + 2)
        ex (sp),hl                      ; the descriptor on the stack, HL = text
        push de
        ret

; FuncSpace: SPACE$(n). OperandString: STRING$(n, code or string).
FuncSpace:
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld b,e
        ld c,' '
        jr RepeatedString
OperandString:
        call ThisChar
        rst $08
        db '('
        call EvalByte
        push af
        call Comma
        call EvalExpression
        call CloseBracket
        push hl
        ld a,(VALTYP)
        cp TypeString
        jr nz,.code
        call StringOperand
        ld a,b
        or a
        jp z,IllegalFunction
        ld a,(de)
        jr .got
.code:
        call ForceInteger
        ld a,h
        or a
        jp nz,IllegalFunction
        ld a,l
.got:
        pop hl
        ld c,a
        pop af
        ld b,a
; RepeatedString: a temporary string of B characters C. Keeps HL.
RepeatedString:
        push hl
        push bc
        call AllocString                ; DE = the room
        pop bc
        push de
        ld a,b
        or a
        jr z,.done
        push bc
.fill:
        ld a,c
        ld (de),a
        inc de
        djnz .fill
        pop bc
.done:
        pop de
        call NewTempDescriptor
        pop hl
        ret

; OperandInput: INPUT$(n): the next n keys (not shown). CTRL+STOP breaks the program. INPUT$(n, [#] f):
; the next n characters of a file (basic/files.asm).
OperandInput:
        rst $08
        db '$'
        call ThisChar
        rst $08
        db '('
        call EvalInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        or e
        jp z,IllegalFunction
        ld b,a
        call ThisChar
        cp ','
        jp z,InputFileChars
        push bc
        call CloseBracket
        pop bc
        ld c,' '
        call RepeatedString             ; the room for them
        push hl
        ld hl,(DAC + 2)                 ; its descriptor: length, address
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
.key:
        push bc
        push de
        call GetKey
        pop de
        pop bc
        ld (de),a
        inc de
        ld a,(INTFLG)
        cp $03
        call z,CheckBreak
        djnz .key
        pop hl
        ret

; OperandInstr: INSTR([start,] string, pattern): where the pattern starts (from 1), or 0.
InstrText       equ HOLD2                ; the string's characters
InstrLength     equ HOLD2 + 2
InstrPattern    equ HOLD2 + 3            ; the pattern's characters
InstrPatternLen equ HOLD2 + 5
InstrPosition   equ HOLD2 + 6            ; (from 0)

OperandInstr:
        call ThisChar
        rst $08
        db '('
        call EvalExpression
        ld c,$01                        ; the start
        ld a,(VALTYP)
        cp TypeString
        jr z,.haveString
        push hl
        call ForceInteger
        ld a,h
        or a
        jp nz,IllegalFunction
        ld a,l
        or a
        jp z,IllegalFunction
        pop hl
        ld c,a
        push bc
        call Comma
        call EvalExpression
        pop bc
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
.haveString:
        push bc                         ; the start
        ld de,(DAC + 2)
        push de                         ; the string's descriptor
        call Comma
        call EvalExpression
        call CloseBracket
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        ex (sp),hl                      ; HL = the string's descriptor, the text on the stack
        push hl
        ld hl,(DAC + 2)                 ; the pattern (the later temporary: released first)
        call ReleaseString
        ld (InstrPattern),de
        ld a,b
        ld (InstrPatternLen),a
        pop hl
        call ReleaseString
        ld (InstrText),de
        ld a,b
        ld (InstrLength),a
        pop hl                          ; the text
        pop bc                          ; C = start
        push hl
        ld a,c
        dec a
        ld (InstrPosition),a
.position:
        ld a,(InstrLength)              ; room left for the pattern?
        ld hl,InstrPosition
        sub (hl)
        jr c,.notFound
        ld hl,InstrPatternLen
        cp (hl)
        jr c,.notFound
        ld a,(hl)
        or a
        jr z,.found                     ; an empty pattern is found at the start
        ld b,a
        ld hl,(InstrText)
        ld a,(InstrPosition)
        add a,l
        ld l,a
        jr nc,.noCarry
        inc h
.noCarry:
        ld de,(InstrPattern)
.compare:
        ld a,(de)
        cp (hl)
        jr nz,.next
        inc de
        inc hl
        djnz .compare
.found:
        ld a,(InstrPosition)
        inc a
        jr .result
.next:
        ld hl,InstrPosition
        inc (hl)
        jr .position
.notFound:
        xor a
.result:
        ld e,a
        ld d,$00
        pop hl
        jp SetIntegerResult

; FuncPeek / FuncVpeek / FuncInp.
FuncPeek:
        call ParenAddress
        ld a,(de)
        jr ByteResult
FuncVpeek:
        call ParenAddress
        push hl
        ex de,hl
        call ReadVramBig
        pop hl
        jr ByteResult
FuncInp:
        call ParenAddress
        ld c,e
        in a,(c)
ByteResult:
        ld e,a
        ld d,$00
        jp SetIntegerResult
ParenAddress:
        call ThisChar
        rst $08
        db '('
        call EvalAddress
        jp CloseBracket

; FuncFre: FRE(string): the string space left after a garbage collection; FRE(number): the memory left.
FuncFre:
        call ThisChar
        rst $08
        db '('
        call EvalExpression
        call CloseBracket
        push hl
        ld a,(VALTYP)
        cp TypeString
        jr nz,.memory
        call CollectGarbage
        ld hl,(FRETOP)
        ld de,(STKTOP)
        jr .difference
.memory:                                ; (from the stack as this statement found it, less 14 bytes: the
        ld hl,(SAVSTK)                  ; original's count, which a GOSUB or FOR frame lowers too; 4
        ld de,14                        ; more while a program runs)
        or a
        sbc hl,de
        ld de,(CURLIN)
        ld a,d
        and e
        inc a
        jr z,.direct
        ld de,4
        sbc hl,de
.direct:
        ld de,(STREND)
.difference:
        or a
        sbc hl,de
        ex de,hl
        pop hl
        jp SetUnsignedResult

; FuncPos / FuncLpos / OperandCsrlin.
FuncPos:
        call ParenNumeric
        ld a,(CSRX)
        dec a
        jr ByteResult
FuncLpos:
        call ParenNumeric
        ld a,(LPTPOS)
        jr ByteResult
OperandCsrlin:
        ld a,(CSRY)
        dec a
        jr ByteResult

; FuncStick / FuncStrig / FuncPdl / FuncPad.
FuncStick:
        call ParenInteger
        push hl
        ld a,e
        call GetStick
        pop hl
        jr ByteResult
FuncStrig:
        call ParenInteger
        push hl
        ld a,e
        call GetTrigger
        pop hl
        ld e,a
        ld d,a
        jp SetIntegerResult
FuncPdl:
        call ParenInteger
        push hl
        ld a,e
        call GetPaddle
        pop hl
        jp ByteResult
FuncPad:
        call ParenInteger
        push hl
        ld a,e
        call GetPad
        pop hl
        jp ByteResult

; FuncDisk: the disk functions come from a disk ROM (its hooks); without one: Syntax error.
FuncDisk:
        jp SyntaxError

; OperandErl / OperandErr / OperandTime.
OperandErl:
        ld de,(ERRLIN)
        jp SetUnsignedResult
OperandErr:
        ld a,(ERRFLG)
        jp ByteResult
OperandTime:
        ld de,(JIFFY)
        jp SetUnsignedResult

; OperandInkey: INKEY$: the key waiting, or "".
OperandInkey:
        push hl
        call KeyAvailable
        jr z,.none
        call GetKey
        pop hl
        jp OneCharString
.none:
        ld b,$00
        ld de,FBUFFR
        call NewTempDescriptor
        pop hl
        ret

; OperandVarptr: VARPTR(variable): the address of its value.
OperandVarptr:
        call ThisChar
        rst $08
        db '('
        call GetVariable
        call CloseBracket
        jp SetIntegerResult

; OperandVdp: VDP(n): a VDP register's copy (0-7 and 9-24 for 8-23), the status (8).
OperandVdp:
        call ParenInteger
        push hl
        ld a,e
        cp $08
        jr z,.status
        jr c,.low
        cp 25
        jp nc,IllegalFunction
        add a,low (RG8SAV - 9)
        ld l,a
        ld h,high RG8SAV
        jr .read
.low:
        ld hl,RG0SAV
        add a,l
        ld l,a
.read:
        ld a,(hl)
        pop hl
        jp ByteResult
.status:
        call ReadVdpStatus
        pop hl
        jp ByteResult

; OperandBase: BASE(n): the table addresses of SCREEN 0-3 (n = 0-19, 5 a mode).
OperandBase:
        call ParenInteger
        ld a,e
        cp 20
        jp nc,IllegalFunction
        push hl
        add a,a
        ld l,a
        ld h,$00
        ld de,TXTNAM
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        jp SetUnsignedResult
