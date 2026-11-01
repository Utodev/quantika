; garbage.asm: the string space's garbage collection (the rest of the strings is in basic/strings.asm;
; two modules so that each fits in the free areas).

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
