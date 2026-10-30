; slots.asm: the slot machinery. Primary slots are chosen with port A8h (two bits per 16K page);
; an expanded primary slot has a secondary register at FFFFh of its page 3 (written as is, read
; complemented), so changing it means putting that primary slot in page 3 for a moment: the code
; doing it uses no stack between the two OUTs. The work area keeps EXPTBL (expanded flags) and
; SLTTBL (copies of the secondary registers).

; --- The RAM primitives, copied to RDPRIM/WRPRIM/CLPRIM at boot. Their entry points and what
;     they do are part of the standard (other ROMs call them), so they are assembled for F380h. ---
RamPrimitives:
        disp RDPRIM
RamReadPrim:                    ; RDPRIM: A = new A8, D = A8 to restore, HL = address -> E = byte
        out (PpiSlotSelect),a
        ld e,(hl)
        jr RamPrimTail
RamWritePrim:                   ; WRPRIM: A = new A8, D = A8 to restore, HL = address, E = byte
        out (PpiSlotSelect),a
        ld (hl),e
RamPrimTail:                    ; back to the A8 in D and return
        ld a,d
        out (PpiSlotSelect),a
        ret
RamCallPrim:                    ; CLPRIM: A = new A8, alternate AF = the caller's AF, the A8 to
        out (PpiSlotSelect),a   ; restore pushed (as AF), IX = routine
        ex af,af'
        call RamCallPrimJump
        ex af,af'
        pop af
        out (PpiSlotSelect),a
        ex af,af'
        ret
RamCallPrimJump:
        jp (ix)
RamPrimitivesTop:
        ent
RamPrimitivesSize equ RamPrimitivesTop - RDPRIM
        assert RamWritePrim == WRPRIM && RamCallPrim == CLPRIM && RamPrimitivesTop == USRTAB

; PageMask: the two bits of a page in a slot register.
; In: A = page (0-3). Out: A = 03h, 0Ch, 30h or C0h. Preserves the other registers.
PageMask:
        push bc
        ld b,a
        ld a,$03
        inc b
.shift:
        dec b
        jr z,.done
        rlca
        rlca
        jr .shift
.done:
        pop bc
        ret

; Spread: copy a two-bit number into the four fields of a slot register (n * 55h).
; In: A (bits 1-0). Out: A. Preserves the other registers.
Spread:
        push bc
        and $03
        ld b,a
        rlca
        rlca
        or b
        ld b,a
        rlca
        rlca
        rlca
        rlca
        or b
        pop bc
        ret

; SlotSetup: get ready to reach a slot in the page of an address.
; In: A = slot ID (bit 7 expanded, bits 3-2 subslot, bits 1-0 primary), H = high byte of the address.
; Out: B = A8 value with that page on the primary slot, C = A8 now, D = 80h + primary when a secondary
;      register was changed (RestoreSubslot puts back E), else D = 0. Interrupts disabled.
; Destroys AF. Preserves HL.
SlotSetup:
        di
        push hl
        ld l,a
        ld a,h
        rlca
        rlca
        and $03
        call PageMask
        ld h,a                          ; H = the page's bits
        ld de,$0000
        bit 7,l
        call nz,SwitchSubslot
        in a,(PpiSlotSelect)
        ld c,a
        ld a,l
        call Spread
        xor c                           ; (primary in every field AND mask) OR (A8 AND NOT mask)
        and h
        xor c
        ld b,a
        pop hl
        ret

; SwitchSubslot: select a subslot for one page of an expanded slot.
; In: L = slot ID, H = mask of the page's bits. Out: D = 80h + primary, E = the register before.
; Destroys AF, BC. No stack is used while page 3 is on the other primary slot.
SwitchSubslot:
        ld a,l
        rrca
        rrca
        call Spread
        ld b,a                          ; B = subslot in every field
        ld a,l
        and $03
        ld d,a                          ; D = primary
        rrca
        rrca
        ld e,a                          ; E = primary in the page 3 field
        in a,(PpiSlotSelect)
        ld c,a                          ; C = A8 to come back to
        and $3F
        or e
        out (PpiSlotSelect),a           ; page 3 on that primary slot: no stack from here...
        ld a,(SLTSL)
        cpl
        ld e,a                          ; E = the register as it was
        ld a,b
        xor e
        and h
        xor e
        ld (SLTSL),a
        ld b,a
        ld a,c
        out (PpiSlotSelect),a           ; ...to here
        push hl
        ld a,d
        add a,low SLTTBL
        ld l,a
        ld h,high SLTTBL
        ld (hl),b
        pop hl
        set 7,d
        ret

; RestoreSubslot: put back a secondary register changed by SlotSetup.
; In: D = 80h + primary (nothing to do when bit 7 is clear), E = value. Destroys AF, BC. Preserves HL, DE.
RestoreSubslot:
        bit 7,d
        ret z
        ld a,d
        rrca
        rrca
        and $C0
        ld b,a
        in a,(PpiSlotSelect)
        ld c,a
        and $3F
        or b
        out (PpiSlotSelect),a           ; no stack until A8 is back
        ld a,e
        ld (SLTSL),a
        ld a,c
        out (PpiSlotSelect),a
        push hl
        ld a,d
        and $03
        add a,low SLTTBL
        ld l,a
        ld h,high SLTTBL
        ld (hl),e
        pop hl
        ret

; ReadSlot: RDSLT. In: A = slot ID, HL = address. Out: A = byte. Interrupts disabled.
; Destroys AF, BC, DE. Page 3 is read as it is (its slot holds the stack).
ReadSlot:
        ld b,a
        ld a,h
        cp $C0
        jr nc,.pageThree
        ld a,b
        call SlotSetup
        push de
        ld a,b
        ld d,c
        call RDPRIM
        ld a,e
        pop de
        push af
        call RestoreSubslot
        pop af
        ret
.pageThree:
        ld a,(hl)
        ret

; WriteSlot: WRSLT. In: A = slot ID, HL = address, E = byte. Interrupts disabled. Destroys AF, BC, D.
WriteSlot:
        ld b,a
        ld a,h
        cp $C0
        jr nc,.pageThree
        ld a,b
        push de
        call SlotSetup
        ex (sp),hl                      ; HL = the caller's DE (E = byte), the address on the stack
        ld a,l
        pop hl
        push de
        ld e,a
        ld a,b
        ld d,c
        call WRPRIM
        pop de
        jp RestoreSubslot
.pageThree:
        ld (hl),e
        ret

; EnableSlot: ENASLT. In: A = slot ID, HL = an address in the page. The page stays on that slot.
; Interrupts disabled. Destroys all. (Page 3 must not be switched this way: it holds the stack.)
EnableSlot:
        call SlotSetup
        ld d,b
        jp RamPrimTail                  ; the last OUT runs in RAM: page 0 may be the one switched

; CallSlot: CALSLT. In: IYh = slot ID, IX = routine; AF, BC, DE, HL go to the routine and come back
; from it. Destroys the alternate registers and IY. Interrupts disabled.
CallSlot:
        exx
        ex af,af'
        push iy
        pop af                          ; A = IYh
        push ix
        pop hl
        call SlotSetup
        push de                         ; for RestoreSubslot
        ld hl,CallSlotDone
        push hl
        ld a,c
        push af                         ; the A8 that CLPRIM puts back
        ld a,b
        exx
        jp CLPRIM
CallSlotDone:
        ex af,af'
        exx
        pop de
        call RestoreSubslot
        exx
        ex af,af'
        ret

; FarCall: CALLF (RST 30h). The slot ID and the address follow the RST: RST 30h / DB slot / DW address.
; Registers as CallSlot.
FarCall:
        ex (sp),hl
        push af
        push de
        ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        pop ix
        push af
        pop iy
        pop de
        pop af
        ex (sp),hl
        jp CallSlot

; CallBasic: CALBAS. Call IX in the main ROM's slot (BASIC).
CallBasic:
        ld iy,(EXPTBL - 1)              ; IYh = EXPTBL = the main ROM's slot
        jp CallSlot

; CallSubRomDirect: EXTROM. Call IX in the sub-ROM. Preserves IY.
CallSubRomDirect:
        push iy
        ld iy,(EXBRSA - 1)              ; IYh = EXBRSA = the sub-ROM's slot
        call CallSlot
        pop iy
        ret

; CallSubRom: SUBROM. Entered with JP after the caller has pushed IX: calls IX in the sub-ROM and
; pops IX before returning.
CallSubRom:
        call CallSubRomDirect
        pop ix
        ret

; FirstSlotOfPrimary: the first slot ID of a primary slot (subslot 0 when it is expanded).
; In: A = primary (0-3). Out: A = slot ID, carry clear. Preserves the other registers.
FirstSlotOfPrimary:
        push hl
        ld hl,EXPTBL
        add a,l
        ld l,a
        sub low EXPTBL
        bit 7,(hl)
        jr z,.plain
        or $80
.plain:
        pop hl
        or a
        ret

; NextSlotId: the slot after A in the order 0-0, 0-1 .. 3-3 (non-expanded slots once).
; In: A = slot ID. Out: A = next slot ID, carry set when A was the last one. Preserves the others.
NextSlotId:
        bit 7,a
        jr z,.nextPrimary
        add a,$04
        bit 4,a
        jr nz,.nextPrimary
        or a
        ret
.nextPrimary:
        and $03
        inc a
        cp $04
        ccf
        ret c
        jr FirstSlotOfPrimary

