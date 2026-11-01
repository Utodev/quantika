; compat.asm: entries at addresses of the original BASIC that real programs jump to, although no manual
; lists them. Each one was found by tracing a program on the original ROM as a black box (the emulator's test harness: trace)
; and its behaviour studied the same way (the test named with it). Only a JP sits at each address (the
; code is in basic/compatcode.asm, which moves); layout_main.txt keeps the JPs out of the free areas.

; 73ACh: relink the program in memory and run it from its start (variables cleared). Tape loaders put a
; tokenized program at 8001h, set VARTAB and jump here (Cobra's Arc). Test: tests/run73ac.asm.
CompatRunAddress equ $73AC
        org CompatRunAddress
        jp CompatRunProgram

; 4EF8h: a return. Head over Heels' loader ends its USR routine with two copies of a value it pushed still on
; the stack (4EF8h): its RET goes there twice before it comes back to USR. In the original whatever runs there
; leaves BC, DE and HL as they were and returns (black box: the registers and the stack when USR is back).
CompatReturnAddress equ $4EF8
        org CompatReturnAddress
        ret

; 521Ch: a number 0-255 from BASIC text (the original's own name for it is GETBYT). Abracadabra's adventure
; system calls it after a RST 08h to read its arguments. Test: tests/getbyt.asm.
CompatGetByteAddress equ $521C
        org CompatGetByteAddress
        jp CompatGetByte

; The statement handlers that programs call themselves, at the addresses the standard's statement table
; (392Eh) gives them: with HL on the statement's text after its token (Don Quijote draws with COLOR,
; CIRCLE, PSET, PAINT and LINE so). Only the ones programs were found calling, and their neighbours:
; each fixed entry splits the free space. Each one goes through CompatStatement (basic/compatcode.asm), which
; first reads the character at HL as the interpreter does before a handler.
        org $4B0E                       ; LINE (and LINE INPUT)
        jp CompatStmtLine
        org $57E5                       ; PRESET
        jp CompatStmtPreset
        org $57EA                       ; PSET
        jp CompatStmtPset
        org $59C5                       ; PAINT
        jp CompatStmtPaint
        org $5B11                       ; CIRCLE
        jp CompatStmtCircle
        org $5D6E                       ; DRAW
        jp CompatStmtDraw
        org $7980                       ; COLOR
        jp CompatStmtColor
