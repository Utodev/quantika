; console.asm: a test of the text console through the BIOS jump table only, so the same binary runs
; on the original and on the free ROM and the screens can be compared (the emulator's test harness: exec).
        device NOSLOT64K
        org $C000
CHPUT   equ $00A2
INITXT  equ $006C
INIT32  equ $006F
ERAFNK  equ $00CC
POSIT   equ $00C6
LINL40  equ $F3AE
LINL32  equ $F3AF
CSRSW   equ $FCA9

Start:
        di
        ld sp,$F000
        ei
        call ERAFNK
        xor a
        ld (CSRSW),a
        ld a,40
        ld (LINL40),a
        call INITXT
        ld hl,Text
        call Print
        ld hl,$0514                     ; column 5, row 20
        call POSIT
        ld hl,Text2
        call Print
.end:
        jr .end

Print:
        ld a,(hl)
        inc hl
        or a
        ret z
        call CHPUT
        jr Print

Text:
        db "Line one",13,10
        db "Tab:",9,"x",9,"y",13,10
        db "A long line that goes past the end of the row and wraps to the next one",13,10
        db 27,"Y",32+10,32+3,"at 4,11"
        db 27,"Y",32+12,32+0,"erase this part",27,"Y",32+12,32+5,27,"K"
        db 13,10,"graphic:",1,$41,1,$42,"end"
        db 27,"Y",32+15,32+0,"up",27,"A",27,"A","x",27,"B",27,"C","y",27,"D",27,"D","z"
        db 27,"Y",32+18,32+0,"to be deleted",13,10,"stays",27,"A",27,"M"
        db 0
Text2:
        db "at posit",8,8,"PO",29,"q",28,28,"r",0

        savebin "../out/console.bin", Start, $ - Start
