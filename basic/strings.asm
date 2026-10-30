; strings.asm: string space and string values. A string is a descriptor of 3 bytes (length, address);
; its characters live in the program text (a literal), in a buffer, or in the string space, which goes
; from STKTOP up to MEMSIZ and fills from the top down (FRETOP = its lowest used byte). Values made by
; an expression get a temporary descriptor in TEMPST (10 of them, TEMPPT = the next free one); they are
; forgotten at the start of every statement. When the space runs out, the strings in use are packed
; at the top again (CollectGarbage) and the rest is free.

; NewTempDescriptor: a temporary descriptor for B characters at DE; it becomes the value in DAC.
; Out: HL = the descriptor. Destroys AF.
NewTempDescriptor:
        ld hl,(TEMPPT)
        push de
        ld de,TEMPST + 30
        rst $20
        pop de
        jr nc,.tooComplex
        ld (hl),b
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (TEMPPT),hl
        dec hl
        dec hl
        dec hl
        ld (DAC + 2),hl
        ld a,TypeString
        ld (VALTYP),a
        ret
.tooComplex:
        ld e,ErrStringFormula
        jp RaiseError

; FreeTemps: forget every temporary descriptor (at the start of a statement).
FreeTemps:
        ld hl,TEMPST
        ld (TEMPPT),hl
        ret

; ReleaseString: the string of descriptor HL is no longer needed: if it is the last temporary, the
; descriptor is free again, and if its characters are the last ones put in the string space, that space
; too. Out: B = length, DE = address (to read it before anything new is made). Destroys AF.
ReleaseString:
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        dec hl
        push hl
        push de
        ex de,hl
        ld hl,(TEMPPT)                  ; the last temporary?
        dec hl
        dec hl
        dec hl
        rst $20
        pop de
        pop hl
        ret nz
        ld (TEMPPT),hl
        push hl
        ld hl,(FRETOP)                  ; its characters at FRETOP?
        rst $20
        pop hl
        ret nz
        push hl
        ld hl,(FRETOP)
        ld a,l
        add a,b
        ld l,a
        jr nc,.noCarry
        inc h
.noCarry:
        ld (FRETOP),hl
        pop hl
        ret

; AllocString: room for B characters in the string space. Out: DE = their address. Destroys AF.
AllocString:
        push hl
        push bc
        call .try
        jr nc,.done
        call CollectGarbage
        pop bc
        push bc
        call .try
        jr nc,.done
        ld e,ErrOutOfStringSpace
        jp RaiseError
.done:
        pop bc
        pop hl
        ret
.try:                                   ; FRETOP - B >= STKTOP? then FRETOP -= B
        ld hl,(FRETOP)
        ld a,l
        sub b
        ld l,a
        jr nc,.noBorrow
        dec h
.noBorrow:
        ld de,(STKTOP)
        rst $20                         ; new FRETOP - STKTOP
        ret c
        ld (FRETOP),hl
        ex de,hl
        or a
        ret

; MakeString: a new temporary string of B characters copied from HL. Out: DAC, DE = its characters.
; Destroys AF, BC, HL.
MakeString:
        push hl
        call AllocString
        pop hl
        push de
        push bc
        ld a,b
        or a
        jr z,.empty
        ld c,b
        ld b,$00
        ldir
.empty:
        pop bc
        pop de
        jp NewTempDescriptor

; StringLiteral: the string in quotes at HL (on the quote) as a temporary descriptor pointing into the
; text. Out: DAC, HL past the closing quote.
StringLiteral:
        inc hl
        ld d,h
        ld e,l
        ld b,$00
.count:
        ld a,(hl)
        or a
        jr z,.end
        inc hl
        cp '"'
        jr z,.end
        inc b
        jr .count
.end:
        push hl
        call NewTempDescriptor
        pop hl
        ret

; CompareStrings: the strings of descriptors HL (left) and DE (right).
; Out: A = 1 left below, 0 equal, FFh above (by character codes, a shorter one first). Destroys all.
CompareStrings:
        push de
        call ReleaseString              ; B = left length, DE = left characters
        ld c,b
        push de
        pop ix
        pop hl
        call ReleaseString              ; B = right length, DE = right characters
        ex de,hl                        ; HL = right characters, IX = left, C = left length, B = right
.char:
        ld a,c
        or b
        ret z                           ; both ended: equal (A = 0)
        ld a,c
        or a
        jr z,.leftShorter
        ld a,b
        or a
        jr z,.leftLonger
        ld a,(ix+0)
        cp (hl)
        jr c,.leftShorter
        jr nz,.leftLonger
        inc ix
        inc hl
        dec c
        dec b
        jr .char
.leftShorter:
        ld a,$01
        ret
.leftLonger:
        ld a,$FF
        ret

; ConcatStrings: a new string, left (descriptor HL) then right (DE). String too long above 255.
ConcatStrings:
        push hl                         ; (the left one, released again at the end)
        push hl
        push de
        ld a,(de)
        add a,(hl)
        ld e,ErrStringTooLong
        jp c,RaiseError
        ld b,a
        call AllocString                ; DE = the room (the two may still be read: GC keeps temps)
        ld (TEMP2),de
        pop hl
        ex (sp),hl                      ; right on the stack, left in HL
        call CopyStringOut              ; left's characters to DE
        pop hl
        call CopyStringOut              ; right's
        pop hl                          ; the left one is the last temporary now: its descriptor
        push bc                         ; goes too (it was not the last when it was copied)
        push de
        call ReleaseString
        pop de
        pop bc
        ld hl,(TEMP2)
        ex de,hl
        jp NewTempDescriptor            ; (B = the total length)

; CopyStringOut: the characters of descriptor HL to DE (DE moves past them); the descriptor is released.
; Keeps B... (B is the length of the result being built: saved here)
CopyStringOut:
        push bc
        push de
        call ReleaseString              ; B = length, DE = characters
        ex de,hl
        pop de
        ld a,b
        or a
        jr z,.done
        ld c,b
        ld b,$00
        ldir
.done:
        pop bc
        ret

; StringOperand: the value in DAC must be a string. Out: HL = its descriptor (released), B = length,
; DE = characters. Destroys AF.
StringOperand:
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        ld hl,(DAC + 2)
        jp ReleaseString

; --- garbage collection ---

; CollectGarbage: the strings in use (in the variables, the arrays and the temporaries) packed at the top
; of the string space; FRETOP goes up. Repeatedly the in-use string with the highest address not yet
; moved goes just under the ones moved before it. Destroys AF, BC, DE, HL.
CollectGarbage:
        push ix
        push iy
        ld hl,(MEMSIZ)
        ld (TEMP9),hl                   ; TEMP9 = the bottom of the packed part
.round:
        ld iy,$0000                     ; IY = the descriptor found (0: none)
        ld hl,(FRETOP)
        ld (TEMP),hl                    ; TEMP = the highest address found so far (starts at FRETOP)
        ; temporaries
        ld hl,TEMPST
.temp:
        ex de,hl
        ld hl,(TEMPPT)
        rst $20
        ex de,hl
        jr z,.tempsDone
        call .consider
        inc hl
        inc hl
        inc hl
        jr .temp
.tempsDone:
        ; simple variables
        ld hl,(VARTAB)
.variable:
        ex de,hl
        ld hl,(ARYTAB)
        rst $20
        ex de,hl
        jr z,.variablesDone
        ld a,(hl)                       ; type
        inc hl
        inc hl
        inc hl                          ; the value
        cp TypeString
        call z,.consider
        ld e,a
        ld d,$00
        add hl,de
        jr .variable
.variablesDone:
        ; arrays
        ld hl,(ARYTAB)
.array:
        ex de,hl
        ld hl,(STREND)
        rst $20
        ex de,hl
        jr z,.arraysDone
        ld a,(hl)                       ; type
        inc hl
        inc hl
        inc hl
        ld c,(hl)                       ; the size of the rest
        inc hl
        ld b,(hl)
        inc hl
        push hl
        add hl,bc
        ld b,h
        ld c,l                          ; BC = the next array
        pop hl
        cp TypeString
        jr nz,.nextArray
        ld a,(hl)                       ; dimensions
        inc hl
        add a,a
        ld e,a
        ld d,$00
        add hl,de                       ; the elements
.element:
        ld a,l
        cp c
        jr nz,.consider3
        ld a,h
        cp b
        jr z,.nextArray
.consider3:
        call .consider
        inc hl
        inc hl
        inc hl
        jr .element
.nextArray:
        ld h,b
        ld l,c
        jr .array
.arraysDone:
        ld a,iyh
        or iyl
        jr z,.finished
        ; move the string of descriptor IY under the packed part
        ld b,(iy+0)
        ld l,(iy+1)
        ld h,(iy+2)
        ld de,(TEMP9)
        ld a,e
        sub b
        ld e,a
        jr nc,.noBorrow
        dec d
.noBorrow:
        ld (TEMP9),de
        ld (iy+1),e
        ld (iy+2),d
        ld a,b
        or a
        jp z,.round
        ld c,b                          ; moving up: from the last byte down (they may overlap)
        ld b,$00
        dec bc
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        inc bc
        lddr
        jp .round
.finished:
        ld hl,(TEMP9)
        ld (FRETOP),hl
        pop iy
        pop ix
        ret
; .consider: the descriptor at HL, if its characters are in the string space below the packed part and
; above the best so far, becomes the best. Keeps HL, A.
.consider:
        push af
        push hl
        push de
        ld a,(hl)
        or a
        jr z,.notThis                   ; empty
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)                       ; DE = its characters
        ld hl,(TEMP9)
        rst $20                         ; packed bottom - characters
        jr c,.notThis
        jr z,.notThis                   ; already packed
        ld hl,(TEMP)
        ex de,hl
        rst $20                         ; characters - best
        jr c,.notThis
        ld (TEMP),hl
        pop de
        pop hl
        push hl
        push de
        push hl
        pop iy
.notThis:
        pop de
        pop hl
        pop af
        ret
