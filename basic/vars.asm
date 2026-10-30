; vars.asm: variables. Simple variables go from VARTAB to ARYTAB, arrays from ARYTAB to STREND, both
; after the program. A name has two characters that count (more are allowed and ignored) and a type
; from its suffix ($ % ! #) or from DEFTBL by its first letter.
;   simple: type, first character, second character (0 if none), the value (2, 4, 8 bytes, or the
;           3-byte descriptor of a string)
;   array:  type, the two characters, the size of the rest (2), the number of dimensions, the size of
;           each dimension (2 each, the first first), the elements (the first index the fastest)
; An array used without DIM gets 11 elements (0-10) in each of the dimensions it is used with.

MaxDimensions   equ 8

; IsNameChar: carry when A is not a letter or a digit.
IsNameChar:
        cp '0'
        ret c
        cp '9' + 1
        ccf
        ret nc
        jp IsLetter

; GetVariable: PTRGET. In: HL on the name. Out: DE = the address of the value, VALTYP = its type, HL after
; the name (and its subscripts). New variables are made.
GetVariable:
        xor a
        ld (DIMFLG),a
GetVariableDim:                         ; (DIMFLG = 1: DIM: a new array with the sizes given)
        call H_PTRG
        call GetVariableName
        call ThisChar
        cp '('
        jp z,ArrayElement
        cp '['
        jp z,ArrayElement
; FindOrMakeSimple: the simple variable C, B of type VALTYP (made, with a value of 0, if new).
; Out: DE = its value. Keeps HL, BC.
FindOrMakeSimple:
        push hl
        ld hl,(VARTAB)
.search:
        ex de,hl
        ld hl,(ARYTAB)
        rst $20
        ex de,hl
        jr z,.new
        ld a,(VALTYP)
        cp (hl)
        jr nz,.next
        inc hl
        ld a,(hl)
        cp c
        jr nz,.nextFromName
        inc hl
        ld a,(hl)
        cp b
        jr nz,.nextFromSecond
        inc hl
        ex de,hl                        ; DE = the value
        pop hl
        ret
.nextFromSecond:
        dec hl
.nextFromName:
        dec hl
.next:
        ld a,(hl)                       ; past this one: 3 + the value's size
        add a,$03
        ld e,a
        ld d,$00
        add hl,de
        jr .search
.new:
        push bc
        ld a,(VALTYP)
        add a,$03
        ld c,a
        ld b,$00                        ; BC = its size
        ld de,(ARYTAB)
        push de
        call MakeRoom                   ; arrays up
        ld hl,(ARYTAB)
        add hl,bc
        ld (ARYTAB),hl
        pop hl                          ; the new variable
        pop bc
        ld a,(VALTYP)
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ex de,hl                        ; DE = the value: zeros
        push de
        push bc
        ld b,a
        xor a
.zero:
        ld (de),a
        inc de
        djnz .zero
        pop bc
        pop de
        pop hl
        ret

; GetVariableName: the name at HL. Out: C, B = its two characters (B = 0 for one), VALTYP = A = its
; type (suffix or DEFTBL), HL past it.
GetVariableName:
        call ThisChar
        call IsLetter
        jp c,SyntaxError
        ld c,a                          ; C = first character
        ld b,$00                        ; B = second
        inc hl
        ld a,(hl)
        call IsNameChar
        jr c,.nameDone
        ld b,a
.skipName:
        inc hl
        ld a,(hl)
        call IsNameChar
        jr nc,.skipName
.nameDone:
        ld e,TypeString
        cp '$'
        jr z,.suffix
        ld e,TypeInteger
        cp '%'
        jr z,.suffix
        ld e,TypeSingle
        cp '!'
        jr z,.suffix
        ld e,TypeDouble
        cp '#'
        jr z,.suffix
        push hl                         ; the default type of the first letter
        ld a,c
        sub 'A'
        ld e,a
        ld d,$00
        ld hl,DEFTBL
        add hl,de
        ld e,(hl)
        pop hl
        jr .typed
.suffix:
        inc hl
.typed:
        ld a,e
        ld (VALTYP),a
        ret

; MakeRoom: BC bytes of room at DE: what is between DE and STREND moves up; STREND goes up.
; Out of memory when the stack would be too close. Keeps BC, DE.
MakeRoom:
        push hl
        push de
        push bc
        ld hl,(STREND)
        push hl
        add hl,bc                       ; the new STREND
        jp c,OutOfMemory
        ld (TEMP2),hl
        ld de,$0050                     ; it must stay below the stack with some room
        add hl,de
        jp c,OutOfMemory
        ex de,hl
        ld hl,$0000
        add hl,sp
        rst $20                         ; SP - (new STREND + 50h)
        jp c,OutOfMemory
        pop hl                          ; the old STREND
        pop bc
        pop de
        push de
        push bc
        ; bytes to move: old STREND - DE
        push hl
        or a
        sbc hl,de
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr z,.moved
        dec hl                          ; from the last byte, down
        ld de,(TEMP2)
        dec de
        lddr
.moved:
        ld hl,(TEMP2)
        ld (STREND),hl
        pop bc
        pop de
        pop hl
        ret

; ArrayElement: the element of an array. In: HL on the bracket, C and B = the name, VALTYP = type,
; DIMFLG = 1 for DIM. Out: DE = the element (not for DIM), HL past the closing bracket.
; While it works the stack holds: the name, the type and DIM flag, the subscripts (the last on top).
ArraySubPtr     equ TEMP2                ; walks the subscripts on the stack
ArrayDimPtr     equ TEMP8                ; walks the sizes in the array's header

ArrayElement:
        push bc                         ; the name
        ld a,(DIMFLG)
        ld d,a
        ld a,(VALTYP)
        ld e,a
        push de                         ; the type (E) and the DIM flag (D)
        ld b,$00
.subscript:
        rst $10                         ; past ( or ,
        push bc
        call EvalInteger                ; DE = the subscript
        pop bc
        push de
        inc b
        ld a,b
        cp MaxDimensions + 1
        jp nc,SubscriptError
        call ThisChar
        cp ','
        jr z,.subscript
        cp ')'
        jr z,.closed
        cp ']'
        jp nz,SyntaxError
.closed:
        inc hl
        push hl                         ; the text
        ld l,b
        ld h,$00
        add hl,hl
        inc hl
        inc hl
        add hl,sp
        push hl
        pop ix                          ; IX = the type word; subscript k at IX - 2k
        ld a,(ix+0)
        ld (VALTYP),a
        ld c,(ix+2)
        ld a,(ix+3)
        ld (TEMP9),a                    ; (the second character, B is the subscript count)
        ld hl,(ARYTAB)
.search:
        ex de,hl
        ld hl,(STREND)
        rst $20
        ex de,hl
        jr z,.new
        ld a,(VALTYP)
        cp (hl)
        jr nz,.next
        inc hl
        ld a,(hl)
        dec hl
        cp c
        jr nz,.next
        inc hl
        inc hl
        ld a,(TEMP9)
        cp (hl)
        dec hl
        dec hl
        jr z,.found
.next:
        inc hl
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        add hl,de
        jr .search
.found:
        ld a,(ix+1)
        or a
        ld e,ErrRedimensioned
        jp nz,RaiseError                ; DIM of an array that is already there
        push hl
        ld de,$0005
        add hl,de
        ld a,(hl)                       ; its dimensions must be as many as the subscripts
        cp b
        jp nz,SubscriptError
        pop iy                          ; IY = the array
        jp .index
.new:
        ; HL = STREND: the new array goes there. Its size: 5 + 1 + 2 * dimensions + elements * size
        push hl
        pop iy
        ld a,(VALTYP)
        ld e,a
        ld d,$00                        ; DE = the bytes of the elements so far (one element)
        push ix
        pop hl
        ld (ArraySubPtr),hl
        push bc
.sizeLoop:
        push bc
        call .dimensionSize             ; HL = this dimension's size (subscript + 1, or 11)
        ld b,h
        ld c,l
        call UnsignedMultiplyChecked    ; DE = DE * BC
        jp c,OutOfMemory
        pop bc
        djnz .sizeLoop
        pop bc
        ld l,b
        ld h,$00
        add hl,hl
        inc hl                          ; 1 + 2 * dimensions
        add hl,de
        jp c,OutOfMemory
        push hl                         ; the size of the rest
        ld de,$0005
        add hl,de
        jp c,OutOfMemory
        push bc
        ld b,h
        ld c,l
        ld de,(STREND)
        call MakeRoom
        pop bc
        push iy
        pop hl                          ; the header
        ld a,(VALTYP)
        ld (hl),a
        inc hl
        ld (hl),c
        inc hl
        ld a,(TEMP9)
        ld (hl),a
        inc hl
        pop de                          ; the size of the rest
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),b
        inc hl
        push de
        push ix                         ; the sizes, the first dimension first
        pop de
        ld (ArraySubPtr),de
        push bc
.writeSize:
        push hl
        call .dimensionSize
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .writeSize
        pop bc
        pop de                          ; the size of the rest: the elements are what is left
        ld a,b
        add a,a
        inc a
        ld c,a                          ; C = 1 + 2 * dimensions... B keeps the count
        push bc
        ex de,hl
        ld b,$00
        or a
        sbc hl,bc                       ; HL = bytes of elements
        ex de,hl
.zero:
        ld a,d
        or e
        jr z,.zeroed
        ld (hl),$00
        inc hl
        dec de
        jr .zero
.zeroed:
        pop bc
        ld a,(ix+1)
        or a
        jr nz,.dimDone                  ; DIM: no element wanted
.index:
        ; offset = ((sub_n) * d_(n-1) + sub_(n-1)) ... * d_1 + sub_1, each sub_k < d_k
        push iy
        pop hl
        ld de,$0006
        add hl,de                       ; the sizes
        ld e,b
        dec e
        ld d,$00
        add hl,de
        add hl,de                       ; HL = the size of the last dimension
        ld (ArrayDimPtr),hl
        push ix                         ; the last subscript: IX - 2n
        pop hl
        ld e,b
        ld d,$00
        or a
        sbc hl,de
        sbc hl,de
        ld (ArraySubPtr),hl
        ld de,$0000                     ; DE = offset
.indexLoop:
        push bc
        ld hl,(ArrayDimPtr)
        ld c,(hl)
        inc hl
        ld b,(hl)                       ; BC = d_k
        dec hl
        dec hl
        dec hl
        ld (ArrayDimPtr),hl
        ld hl,(ArraySubPtr)
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a                          ; HL = sub_k
        push hl
        or a
        sbc hl,bc
        jp nc,SubscriptError            ; (a negative subscript is a large one here)
        call UnsignedMultiplyChecked    ; DE = offset * d_k
        pop hl
        add hl,de
        ex de,hl                        ; DE = offset * d_k + sub_k
        ld hl,(ArraySubPtr)
        inc hl
        inc hl
        ld (ArraySubPtr),hl
        pop bc
        djnz .indexLoop
        ; the element: the data + offset * element size
        ld a,(VALTYP)
        ld b,$00
        ld c,a
        call UnsignedMultiplyChecked    ; DE = offset * size
        push iy
        pop hl
        ld bc,$0006
        add hl,bc
        ld a,(iy+5)
        add a,a
        ld c,a
        ld b,$00
        add hl,bc                       ; the elements
        add hl,de
        ex de,hl                        ; DE = the element
        jr .clean
.dimDone:
        ld de,$0000
.clean:
        ld a,(ix+0)                     ; (read before the stack moves past it)
        ld (VALTYP),a
        pop hl                          ; the text
        ld sp,ix                        ; the subscripts go
        inc sp
        inc sp                          ; the type word
        pop bc                          ; the name
        ret
; .dimensionSize: HL = the size of the dimension whose subscript is at (ArraySubPtr) - 2, which moves on
; (for a new array: subscript + 1 for DIM, 11 otherwise). Keeps BC, DE.
.dimensionSize:
        ld hl,(ArraySubPtr)
        dec hl
        dec hl
        ld (ArraySubPtr),hl
        ld a,(ix+1)
        or a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr z,.eleven
        bit 7,h
        jp nz,IllegalFunction           ; DIM A(-1)
        inc hl
        ret
.eleven:
        ld hl,11
        ret

SubscriptError:
        ld e,ErrSubscript
        jp RaiseError

; UnsignedMultiplyChecked: DE = DE * BC (unsigned), carry when it does not fit in 16 bits. Keeps BC, HL.
UnsignedMultiplyChecked:
        push hl
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
        ex de,hl
        pop hl
        or a
        ret
.overflow:
        pop hl
        scf
        ret

; --- assignments ---

; StatementLet: LET variable = expression (also the statements that start with a name).
StatementLet:
        call StatementLetCore
        ret

; StatementLetCore: the assignment at HL. Out: DE = the variable's value, A = its type.
StatementLetCore:
        call GetVariable
        ld a,(VALTYP)
        push de
        push af
        call ThisChar
        rst $08
        db TkEqual
        call EvalExpression
        pop af
        pop de
        push de
        push af
        call AssignValue
        pop af
        pop de
        ret

; AssignValue: the value in DAC into the variable at DE of type A. Keeps HL.
AssignValue:
        push hl
        cp TypeString
        jr z,.string
        push de
        push af
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        pop af
        push af
        call ConvertDacTo
        pop af
        pop de
        ld hl,DAC
        cp TypeInteger
        jr nz,.copy
        ld hl,DAC + 2
.copy:
        ld c,a
        ld b,$00
        ldir
        pop hl
        ret
.string:
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        push de
        ld hl,(DAC + 2)                 ; the value's descriptor
        call IsAdoptable
        jr c,.copyChars
        ; a temporary whose characters are in the string space: the variable takes them
        pop de
        ld bc,$0003
        ldir
        pop hl
        ret
.copyChars:
        ld b,(hl)
        ld a,b
        or a
        jr z,.empty
        push hl
        call AllocString                ; DE = the room (a garbage collection may move the source)
        pop hl
        push de
        ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld c,b
        push bc
        ld b,$00
        ldir
        pop bc
        pop de                          ; the new characters
        pop hl                          ; the variable's descriptor
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
        ret
.empty:
        pop hl
        ld (hl),$00
        pop hl
        ret

; IsAdoptable: no carry when descriptor HL is a temporary whose characters a variable can keep where
; they are: in the string space (FRETOP to MEMSIZ) or in the program's text (TXTTAB to VARTAB: a
; literal; editing the program clears the variables). Not a literal of a direct statement (KBUF is
; used again). Keeps HL.
IsAdoptable:
        push hl
        push de
        ld de,TEMPST
        rst $20
        jr c,.no
        ld de,TEMPST + 30
        rst $20
        jr nc,.no
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl                        ; HL = the characters
        ld de,(FRETOP)                  ; in the string space?
        rst $20
        jr c,.text
        ld de,(MEMSIZ)
        rst $20
        jr c,.yes
.text:
        ld de,(TXTTAB)                  ; in the program?
        rst $20
        jr c,.no
        ld de,(VARTAB)
        rst $20
        jr nc,.no
.yes:
        or a
        jr .done
.no:
        scf
.done:
        pop de
        pop hl
        ret

; ConvertDacTo: the number in DAC to type A (Type mismatch for a string). Keeps HL.
ConvertDacTo:
        push hl
        ld b,a
        ld a,(VALTYP)
        cp TypeString
        jp z,TypeMismatch
        ld a,b
        cp TypeInteger
        jr nz,.notInteger
        call ForceInteger
        jr .done
.notInteger:
        cp TypeSingle
        jr nz,.double
        call ForceSingle
        jr .done
.double:
        call ForceDouble
.done:
        pop hl
        ret

; StatementDim: DIM name(sizes) [, name(sizes) ...].
StatementDim:
        ld a,$01
        ld (DIMFLG),a
        call GetVariableDim
        call ThisChar
        cp ','
        ret nz
        rst $10
        jr StatementDim

; StatementDefType: DEFINT / DEFSNG / DEFDBL / DEFSTR letter[-letter] [, ...]: DEFTBL.
StatementDefStr:
        ld e,TypeString
        jr DefType
StatementDefInt:
        ld e,TypeInteger
        jr DefType
StatementDefSng:
        ld e,TypeSingle
        jr DefType
StatementDefDbl:
        ld e,TypeDouble
DefType:
        call ThisChar
        call IsLetter
        jp c,SyntaxError
        ld c,a
        ld b,a                          ; B..C = the range
        rst $10
        cp TkMinus
        jr nz,.range
        rst $10
        call IsLetter
        jp c,SyntaxError
        ld b,a
        rst $10
.range:
        ld a,b
        cp c
        jp c,IllegalFunction
        push hl
        ld a,c
        sub 'A'
        ld c,a
        ld a,b
        sub 'A'
        sub c
        inc a
        ld b,a                          ; B = letters
        ld hl,DEFTBL
        ld a,c
        add a,l
        ld l,a
        jr nc,.set
        inc h
.set:
        ld (hl),e
        inc hl
        djnz .set
        pop hl
        call ThisChar
        cp ','
        ret nz
        rst $10
        jr DefType
