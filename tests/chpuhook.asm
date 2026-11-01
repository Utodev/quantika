; chpuhook.asm: (black-box study) what a routine on the hook H.CHPU sees when CHPUT calls it: the
; registers and the 12 bytes on the stack under its return address (programs that draw their own
; characters take them there). Results from D000h: AF, BC, DE, HL, then the stack's 12 bytes made
; relative (each word minus the caller's SP is not needed: the values pushed are the registers), for
; CHPUT with A = 41h, BC = 1122h, DE = 3344h, HL = 5566h; and the same for OUTDO (RST 18h) with H.OUTD.
        include "common.inc"
        TEST_START
        ld a,$C3                        ; H.CHPU: JP Hook
        ld ($FDA4),a
        ld hl,Hook
        ld ($FDA5),hl
        ld ix,Results
        ld a,$41
        ld bc,$1122
        ld de,$3344
        ld hl,$5566
        call $00A2                      ; CHPUT
        ld a,$C9
        ld ($FDA4),a
        ld a,$C3                        ; H.OUTD: JP Hook
        ld ($FEE4),a
        ld hl,Hook
        ld ($FEE5),hl
        ld ix,Results + 20
        ld a,$42
        ld bc,$1122
        ld de,$3344
        ld hl,$5566
        rst $18
        ld a,$C9
        ld ($FEE4),a
        jr TestEnd
Hook:
        ld (ix+2),c
        ld (ix+3),b
        ld (ix+4),e
        ld (ix+5),d
        ld (ix+6),l
        ld (ix+7),h
        push af
        pop bc
        ld (ix+0),c
        ld (ix+1),b
        ld hl,2                         ; the stack under the hook's return address
        add hl,sp
        ld b,12
.copy:
        ld a,(hl)
        ld (ix+8),a
        inc hl
        inc ix
        djnz .copy
        ret
        TEST_END "../out/chpuhook.bin"
