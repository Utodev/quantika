; resident.asm: the routines this ROM keeps in RAM (at ResCode, under the buffers; INIT copies them there).
; They serve both ways the machine runs: with the main ROM in page 0 (BASIC), and with RAM in page 0 (the
; disk operating system), where page 0's standard entries (RDSLT, WRSLT, CALSLT, ENASLT, CALLF and the
; interrupt at 38h) jump here: each puts the main ROM back in page 0 for as long as it takes. The places
; F1C9h, F368h, F36Bh and F36Eh of the work area jump here too.

ResImage:
        disp ResCode

; ResRamLdir (RamCopy): BC bytes from HL to DE with the RAM in page 1, then this ROM there again.
; Destroys AF, BC, DE, HL (as LDIR leaves them).
ResRamLdir:
        call ResEnableRam
        ldir
        ; on into ResEnableRom

; ResEnableRom / ResEnableRam: this ROM (MASTER) / the RAM (RAMAD1) in page 1. Keep BC, DE, HL, IX, IY;
; the interrupts are off afterwards.
ResEnableRom:
        push af
        ld a,(MASTER)
        jr ResPageOne
ResEnableRam:
        push af
        ld a,(RAMAD1)
ResPageOne:
        push hl
        push de
        push bc
        push ix
        push iy
        ld h,$40
        call ENASLT
        pop iy
        pop ix
        pop bc
        pop de
        pop hl
        pop af
        ret

; ResFbasic: calls IX (FBASIC's service, or a program loaded by BLOAD ..., R) with BASIC's ROM (the main
; ROM) in page 1, wherever IX is (CALBAS would put it only in IX's own page), then this ROM there again.
; AF, BC, DE and HL go and come back; interrupts on.
ResFbasic:
        push ix
        push af
        push bc
        push de
        push hl
        ld a,(EXPTBL)
        ld h,$40
        call ENASLT
        pop hl
        pop de
        pop bc
        pop af
        pop ix
        ei
        call .run
        push af
        push bc
        push de
        push hl
        ld a,(MySlot)
        ld h,$40
        call ENASLT
        pop hl
        pop de
        pop bc
        pop af
        ei
        ret
.run:
        jp (ix)

; ResPrintText (F1C9h): the text at DE (in the RAM, whatever page 1 shows) up to "$", on the console.
; Out: DE on the "$", this ROM in page 1.
ResPrintText:
        call ResEnableRam
        ld a,(de)
        call ResEnableRom
        cp '$'
        ret z
        push de
        call ConsoleChar
        pop de
        inc de
        jr ResPrintText

; --- page 0's entries when RAM is there ---

ResRdslt:
        push hl
        ld hl,RDSLT
        jr ResViaBios
ResWrslt:
        push hl
        ld hl,WRSLT
        jr ResViaBios
ResCalslt:
        push hl
        ld hl,CALSLT
        jr ResViaBios
ResEnaslt:
        push hl
        ld hl,ENASLT
        ; on into ResViaBios

; ResViaBios: the main ROM's routine HL with the main ROM in page 0, then the RAM there again (the other
; pages as the routine left them). The registers go and come back as the routine says (HL: the caller's,
; on the stack).
ResViaBios:
        ld (.target + 1),hl
        pop hl
        push af
        in a,($A8)
        ld (ResOldSlots),a
        and $FC
        push hl
        ld hl,BiosSlots
        or (hl)
        pop hl
        out ($A8),a
        pop af
.target:
        call 0
        push af
        push bc
        ld a,(ResOldSlots)
        and $03
        ld b,a
        in a,($A8)
        and $FC
        or b
        out ($A8),a
        pop bc
        pop af
        ret

; ResCallf (RST 30h): the slot ID and the address in the 3 bytes after the RST: called there (CALSLT).
ResCallf:
        ex (sp),hl
        push af
        ld a,(hl)
        ld (ResCallfSlot),a
        inc hl
        ld a,(hl)
        ld (ResCallfAddr),a
        inc hl
        ld a,(hl)
        ld (ResCallfAddr + 1),a
        inc hl
        pop af
        ex (sp),hl
        push ix
        push iy
        ld ix,(ResCallfAddr)
        ld iy,(ResCallfSlot - 1)
        call ResCalslt
        pop iy
        pop ix
        ret

; ResInterrupt (38h): the main ROM's interrupt routine, with it in page 0.
ResInterrupt:
        push af
        in a,($A8)
        push af
        and $FC
        push hl
        ld hl,BiosSlots
        or (hl)
        pop hl
        out ($A8),a
        call $0038                      ; (it ends with EI and RET)
        di
        pop af
        out ($A8),a
        pop af
        ei
        ret

; ResPageZeroRam: the RAM (RAMAD0) in page 0 (page 3 shows the same primary slot: the RAM's), its entries
; filled in. Interrupts off.
ResPageZeroRam:
        di
        ld a,(RAMAD0)
        bit 7,a
        jr z,.primary
        ld b,a                          ; expanded: its subslot for page 0, in the register at FFFFh
        rrca
        rrca
        and $03
        ld c,a
        ld a,($FFFF)
        cpl
        and $FC
        or c
        ld ($FFFF),a
        ld c,a
        ld a,b
        and $03
        ld e,a
        ld d,0
        ld hl,SLTTBL
        add hl,de
        ld (hl),c
        ld a,b
.primary:
        and $03
        ld b,a
        in a,($A8)
        and $FC
        or b
        out ($A8),a
        ld hl,ResVectors
.vector:
        ld e,(hl)                       ; the place
        inc hl
        ld a,e
        cp $FF
        ret z
        ld d,0
        ld a,$C3
        ld (de),a
        inc de
        ldi
        ldi
        jr .vector
ResVectors:
        db $0C
        dw ResRdslt
        db $14
        dw ResWrslt
        db $1C
        dw ResCalslt
        db $24
        dw ResEnaslt
        db $30
        dw ResCallf
        db $38
        dw ResInterrupt
        db $FF

; ResPageZeroRom: the main ROM in page 0 again. Interrupts off.
ResPageZeroRom:
        di
        ld a,(BiosSlots)
        ld b,a
        in a,($A8)
        and $FC
        or b
        out ($A8),a
        ret

; ResDosBdos (BDOS, F37Dh, while RAM is in page 0): the kernel, with this ROM in page 1 for the call, and
; page 1 as it was afterwards.
ResDosBdos:
        push af
        push hl
        call ResPageOneSlot
        ld (ResBdosSlot),a
        pop hl
        pop af
        call ResEnableRom
        call KernelEntry
        push af
        push bc
        push de
        push hl
        ld a,(ResBdosSlot)
        ld h,$40
        call ENASLT
        pop hl
        pop de
        pop bc
        pop af
        ei
        ret

; ResPageOneSlot: A = the slot ID page 1 shows. Keeps BC, DE; destroys HL.
ResPageOneSlot:
        push bc
        in a,($A8)
        rrca
        rrca
        and $03
        ld c,a                          ; the primary slot
        ld b,0
        ld hl,EXPTBL
        add hl,bc
        ld a,(hl)
        and $80
        jr z,.done
        ld hl,SLTTBL                    ; expanded: page 1's subslot (bits 3-2 of its register's copy)
        add hl,bc
        ld a,(hl)
        and $0C
        or $80
.done:
        or c
        pop bc
        ret

ResOldSlots:    db 0
ResBdosSlot:    db 0
ResCallfSlot:   db 0
ResCallfAddr:   dw 0

ResEnd:
        ent
ResImageLength  equ ResEnd - ResCode
        assert ResImageLength <= ResRoom, "the resident routines have no room"
