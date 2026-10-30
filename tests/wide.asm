; wide.asm: 80 columns (Text 2)
        include "common.inc"
        TEST_START
        call ERAFNK
        xor a
        ld (CSRSW),a
        ld a,80
        ld (LINL40),a
        call INITXT
        ld hl,Text
        call Print
        ld a,(CSRX)
        ld (Results),a
        ld a,(CSRY)
        ld (Results+1),a
        jp TestEnd
Text:   db "Eighty columns: a long line that is longer than forty and goes on and on until it wraps past 80",13,10,"next",0
        TEST_END "../out/wide.bin"
