; screen1.asm: SCREEN 1 (32 columns, LINL32 29) and the function key line
        include "common.inc"
        TEST_START
        xor a
        ld (CSRSW),a
        ld a,29
        ld (LINL32),a
        call INIT32
        call ERAFNK
        ld hl,Text
        call Print
        ld a,(CSRX)
        ld (Results),a
        ld a,(CSRY)
        ld (Results+1),a
        jp TestEnd
Text:   db "SCREEN 1 with 29 columns: this line wraps somewhere",13,10,"x",9,"tab",12,"after form feed",0
        TEST_END "../out/screen1.bin"
