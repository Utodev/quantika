; srch80.asm: BDOS search first / next (11h / 12h) with the FCB's drive byte 80h (bit 7 set, as the
; command interpreter's DIR gives it): A of each at D000h, the DTA's first 16 bytes after the first one
; at D010h, the FCB's first byte after it at D020h.
        device NOSLOT64K
        org $C000
Start:
        ld sp,$C000
        ld hl,$D000
        ld de,$D001
        ld bc,255
        ld (hl),$EE
        ldir
        ld de,$D080
        ld c,$1A
        call $F37D
        ld de,Fcb
        ld c,$11
        call $F37D
        ld ($D000),a
        ld hl,$D080
        ld de,$D040
        ld bc,40
        ldir
        ld a,(Fcb)
        ld ($D020),a
        ld de,Fcb
        ld c,$12
        call $F37D
        ld ($D001),a
        ld hl,$D080
        ld de,$D070
        ld bc,40
        ldir
        jr $
Fcb:    db $80, "???????????"
        ds 25, 0
        savebin "../out/srch80.bin", Start, $ - Start
