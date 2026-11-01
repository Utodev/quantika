; getbyt.asm: (black-box study) 521Ch, which programs call to read a number 0-255 from BASIC text at HL
; (Abracadabra's adventure system does, after a RST 08h). For each text: A, F, E, D and HL (as an offset in
; the text) after it, 6 bytes, from D000h.
        include "common.inc"
        TEST_START
        ld ix,Results
        ld hl,Text1
        call .one
        ld hl,Text2
        call .one
        ld hl,Text3
        call .one
        ld hl,Text4
        call .one
        ld hl,Text5
        call .one
        jr TestEnd
.one:
        push hl
        ld de,$1234
        call $521C
        ld (ix+0),a
        push af
        pop bc
        ld (ix+1),c                     ; F
        ld (ix+2),e
        ld (ix+3),d
        pop bc                          ; BC = the text's start
        or a
        sbc hl,bc
        ld (ix+4),l                     ; HL - start
        ld (ix+5),h
        ld de,6
        add ix,de
        ret
Text1:  db "12)", 0
Text2:  db " 255:", 0
Text3:  db $11, $F1, $12, ",", 0        ; the tokens 0, +, 1 (tokenized text: digits 0-9 are 11h-1Ah)
Text4:  db $0F, 200, $F2, $0F, 3, 0     ; 200 - 3, tokenized
Text5:  db "7", 0
        TEST_END "../out/getbyt.bin"
