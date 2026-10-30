; outdo.asm: OUTDO (RST 18h) and PrintCrLf (INLIN uses it), BIOS code: in page 0 (a cartridge may be
; in page 1).

; OutputChar: OUTDO (RST 18h). A to the screen, or to the printer while PRTFLG is set. Preserves all.
OutputChar:
        push af
        call H_OUTD
        push hl                         ; to a file (PRINT #)?
        ld hl,(PTRFIL)
        ld a,h
        or l
        pop hl
        jr nz,.file
        ld a,(PRTFLG)
        or a
        jr nz,.notScreen
        pop af
        jp PutChar
.notScreen:
        jp m,.tape                      ; 80h: SAVE's text to the tape buffer
        pop af
        jp PrinterOutFormatted
.tape:
        pop af
        jp TapeBufferChar
.file:
        pop af
        jp FileOutputChar

; PrintCrLf: a new line.
PrintCrLf:
        ld a,$0D
        rst $18
        ld a,$0A
        rst $18
        ret

