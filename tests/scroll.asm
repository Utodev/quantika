; scroll.asm: scrolling, insert line, erase to end of screen, in 40 columns
        include "common.inc"
        TEST_START
        call ERAFNK
        xor a
        ld (CSRSW),a
        ld a,40
        ld (LINL40),a
        call INITXT
        ld b,30                         ; 30 numbered lines: the screen scrolls
.line:
        push bc
        ld a,31
        sub b
        call PrintNumber
        ld hl,Body
        call Print
        pop bc
        djnz .line
        ld hl,Text
        call Print
        ld a,(CSRX)
        ld (Results),a
        ld a,(CSRY)
        ld (Results+1),a
        jp TestEnd

PrintNumber:                            ; A = 1-99, two digits
        ld c,'0' - 1
.tens:
        inc c
        sub 10
        jr nc,.tens
        add a,10 + '0'
        push af
        ld a,c
        call CHPUT
        pop af
        jp CHPUT

Body:   db " is a line of the scroll test",13,10,0
Text:   db 27,"Y",32+5,32+0,27,"L","inserted",27,"Y",32+20,32+10,27,"J",27,"Y",32+22,32+2,"end",0
        TEST_END "../out/scroll.bin"
