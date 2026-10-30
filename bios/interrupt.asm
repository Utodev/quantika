; interrupt.asm: the maskable interrupt (RST 38h, KEYINT) and the NMI.
; H.KEYI is called first (before the VDP status is read: S#1 line interrupts are seen there), then on
; a vertical blank H.TIMI with A = S#0, the frame counter and the keyboard matrix.

InterruptHandler:
        push hl
        push de
        push bc
        push af
        exx
        ex af,af'
        push hl
        push de
        push bc
        push af
        push iy
        push ix
        call H_KEYI
        in a,(VdpCommand)               ; S#0, which also acknowledges the interrupt
        or a
        jp p,.done                      ; not a vertical blank
        ld (STATFL),a
        call H_TIMI
        ld hl,(JIFFY)
        inc hl
        ld (JIFFY),hl
        call ScanKeyboard
        call ProcessKeys
        ld a,(STATFL)
        call InterruptTraps
        call PlayMusic
.done:
        pop ix
        pop iy
        pop af
        pop bc
        pop de
        pop hl
        ex af,af'
        exx
        pop af
        pop bc
        pop de
        pop hl
        ei
        ret

; NmiHandler: the NMI goes to H.NMI only.
NmiHandler:
        call H_NMI
        retn
