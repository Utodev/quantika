; compat.asm: entries at addresses of the original BASIC that real programs jump to, although no manual
; lists them. Each one was found by tracing a program on the original ROM as a black box (the emulator's test harness: trace)
; and its behaviour studied the same way (the test named with it). Only a JP sits at each address (the
; code is in basic/compatcode.asm, which moves); layout_main.txt keeps the JPs out of the free areas.

; 73ACh: relink the program in memory and run it from its start (variables cleared). Tape loaders put a
; tokenized program at 8001h, set VARTAB and jump here (Cobra's Arc). Test: tests/run73ac.asm.
CompatRunAddress equ $73AC
        org CompatRunAddress
        jp CompatRunProgram
