; beep.asm: BEEP with the settings 0, 3, 6, 9, 12, 15 of SET BEEP (block 2 register 10 of the clock):
; the PSG registers after each; the writes to the PSG (emu80's comparison tool logs them) are compared too.
        include "common.inc"
        TEST_START
        ld iy,Results
        ld c,0
.set:
        push bc
        ld a,13
        out ($B4),a
        ld a,$0A
        out ($B5),a
        ld a,10
        out ($B4),a
        ld a,c
        out ($B5),a
        call $00C0                      ; BEEP
        ld b,0
.r:     ld a,b
        push bc
        call $0096                      ; RDPSG
        pop bc
        ld (iy+0),a
        inc iy
        inc b
        ld a,b
        cp 14
        jr nz,.r
        ld (iy+0),$EE
        ld (iy+1),$EE
        inc iy
        inc iy
        pop bc
        ld a,c
        add a,3
        ld c,a
        cp 16
        jr c,.set
        jp TestEnd
        TEST_END "../out/beep.bin"
