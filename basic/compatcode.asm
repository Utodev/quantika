; compatcode.asm: the routines behind the fixed entries of basic/compat.asm.

; CompatRunProgram: 73ACh: relink the program in memory, clear the variables and run it from its start.
CompatRunProgram:
        ld sp,(STKTOP)
        call LinkLines
        call ClearVariables
        ld hl,(TXTTAB)
        dec hl
        ld bc,$0000
        ld (CURLIN),bc
        jp NewStatement
