; modes.asm: CHGMOD to SCREEN MODE (assembled with -DMODE=n) after setting the colours, then CLS.
; Results: R#0 R#1 R#2 R#4 R#7 R#8 R#9, R#3 R#5 R#6 in the modes that use them, SCRMOD, OLDSCR
        include "common.inc"
        TEST_START
        call ERAFNK
        ld hl,$040F                     ; FORCLR 15, BAKCLR 4, BDRCLR 4
        ld ($F3E9),hl
        ld a,4
        ld ($F3EB),a
        ld a,MODE
        call CHGMOD
        xor a                           ; Z: CLS clears
        call CLS
        ld de,Results
        ld hl,Registers
.next:
        ld a,(hl)
        inc hl
        or a
        jr z,.done
        ld c,a
        ld b,(hl)
        inc hl
        ld a,(bc)
        ld (de),a
        inc de
        jr .next
.done:
        ld a,($FCAF)
        ld (de),a
        inc de
        ld a,($FCB0)
        ld (de),a
        jp TestEnd
Registers:
        dw $F3DF, $F3E0, $F3E1, $F3E3, $F3E6, $FFE7, $FFE8
        if MODE == 1 || MODE == 2 || MODE == 4
        dw $F3E2, $F3E4, $F3E5
        endif
        db 0
        TEST_END "../out/modes.bin"
