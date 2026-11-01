; psginit.asm: the PSG registers after boot and after GICINI.
        include "common.inc"
        TEST_START
        ld iy,Results
        ld b,0
.r:     ld a,b
        push bc
        call $0096
        pop bc
        ld (iy+0),a
        inc iy
        inc b
        ld a,b
        cp 16
        jr nz,.r
        call $0090              ; GICINI
        ld b,0
.s:     ld a,b
        push bc
        call $0096
        pop bc
        ld (iy+0),a
        inc iy
        inc b
        ld a,b
        cp 16
        jr nz,.s
        jp TestEnd
        TEST_END "../out/psginit.bin"
