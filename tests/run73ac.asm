; run73ac.asm: (black-box study) a tokenized program put at 8001h with wrong links, VARTAB set, and a jump
; to 73ACh, as tape loaders do: does it relink and run it? Results: the screen.
        include "common.inc"
        TEST_START
        ld hl,Program
        ld de,$8001
        ld bc,ProgramEnd - Program
        ldir
        ld hl,$8001 + ProgramEnd - Program
        ld ($F6C2),hl                   ; VARTAB
        ld a,$55
        ld ($C800),a
        jp $73AC
Program:
        dw $1234, 10                    ; a wrong link
        db $91, " ", $0F, 123, ":", $88, " A", $EF, $0F, 7, 0
        dw $1234, 20
        db $91, " A", 0
        dw 0
ProgramEnd:
        TEST_END "../out/run73ac.bin"
