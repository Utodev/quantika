; keys.asm: CHGET for the typed text (the test harness: exec -type): the codes go to Results and the screen
        include "common.inc"
CHGET   equ $009F
        TEST_START
        call ERAFNK
        xor a
        ld (CSRSW),a
        ld a,40
        ld (LINL40),a
        call INITXT
        ld hl,Results
.next:
        call CHGET
        ld (hl),a
        inc hl
        cp 13
        jp z,TestEnd
        call CHPUT
        jr .next
        TEST_END "../out/keys.bin"
