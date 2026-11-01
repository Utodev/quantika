; mathextra.asm: the Math-Pack entries XTF, PUSHF, PHF, PHA, PPF, PPA, MOVFR, MOVRF, MOVRMI, MOVRM, FOUTB, FOUTO,
; FOUTH, SGNEXP, DBLEXP and INTEXP (whole powers only: the last digits of the others differ, see NOTES.md).
        include "common.inc"
DAC     equ $F7F6
ARG     equ $F847
VALTYP  equ $F663
        TEST_START
        ld iy,Results
        call setdac
        call $2ECC              ; MOVRF
        call savebcde           ; 0-3
        ld bc,$1122
        ld de,$3344
        call $2EC1              ; MOVFR
        ld hl,DAC
        call save4              ; 4-7
        ld hl,Data
        call $2ED6              ; MOVRMI
        call savebcde           ; 8-11
        call savehl             ; 12-13
        ld hl,Data
        call $2EDF              ; MOVRM
        call savebcde           ; 14-17
        call savehl             ; 18-19
        call setdac
        ld (spsave),sp
        call $2EB1              ; PUSHF
        ld (sp2),sp
        pop hl
        pop de
        call savehl             ; 20-21
        ex de,hl
        call savehl             ; 22-23
        call spdiff             ; 24
        call setdac
        ld (spsave),sp
        call $2CCC              ; PHF
        ld (sp2),sp
        call pop8               ; 25-32
        call spdiff             ; 33
        ld (spsave),sp
        call $2CC7              ; PHA
        ld (sp2),sp
        call pop8               ; 34-41
        call spdiff             ; 42
        ld (spsave),sp
        ld hl,$0807
        push hl
        ld hl,$0605
        push hl
        ld hl,$0403
        push hl
        ld hl,$0201
        push hl
        call $2CE1              ; PPF
        ld (sp2),sp
        ld hl,DAC
        call save8              ; 43-50
        call spdiff             ; 51
        ld (spsave),sp
        ld hl,$1817
        push hl
        ld hl,$1615
        push hl
        ld hl,$1413
        push hl
        ld hl,$1211
        push hl
        call $2CDC              ; PPA
        ld (sp2),sp
        ld hl,ARG
        call save8              ; 52-59
        call spdiff             ; 60
        call setdac
        ld (spsave),sp
        ld hl,$ABCD
        push hl
        ld hl,$1234
        push hl
        call $2C6F              ; XTF
        ld (sp2),sp
        pop hl
        pop de
        call savehl             ; 61-62
        ex de,hl
        call savehl             ; 63-64
        ld hl,DAC
        call save4              ; 65-68
        call spdiff             ; 69
        jp part2
setdac: ld hl,Dac0
        ld de,DAC
        ld bc,16
        ldir
        ld hl,Arg0
        ld de,ARG
        ld bc,8
        ldir
        ret
savebcde:
        ld (iy+0),b
        ld (iy+1),c
        ld (iy+2),d
        ld (iy+3),e
        ld bc,4
        add iy,bc
        ret
savehl: ld (iy+0),l
        ld (iy+1),h
        inc iy
        inc iy
        ret
save4:  ld b,4
        jr sv
save8:  ld b,8
sv:     ld a,(hl)
        ld (iy+0),a
        inc hl
        inc iy
        djnz sv
        ret
pop8:   pop ix                  ; (return)
        pop hl
        call savehl
        pop hl
        call savehl
        pop hl
        call savehl
        pop hl
        call savehl
        jp (ix)
spdiff: push hl
        ld hl,(spsave)
        ld de,(sp2)
        or a
        sbc hl,de
        ld (iy+0),l
        inc iy
        pop hl
        ret
spsave  equ $CF00
sp2     equ $CF02
Data:   db $55,$66,$77,$88,$99
Dac0:   db $41,$23,$45,$67,$89,$01,$23,$45,0,0,0,0,0,0,0,0
Arg0:   db $42,$11,$11,$11,$22,$22,$22,$22
part2:
        ld iy,Results+96
        ; FOUTB / FOUTO / FOUTH of the integer 1234 and -2
        ld b,0
.f:     push bc
        ld a,2
        ld (VALTYP),a
        ld hl,1234
        ld a,b
        cp 3
        jr c,.v
        ld hl,-2
.v:     ld (DAC+2),hl
        ld a,b
        cp 3
        jr c,.w
        sub 3
.w:     or a
        jr nz,.o
        call $371A
        jr .got
.o:     dec a
        jr nz,.h
        call $371E
        jr .got
.h:     call $3722
.got:   ld b,18
.c:     ld a,(hl)
        ld (iy+0),a
        inc iy
        or a
        jr z,.cd
        inc hl
        djnz .c
.cd:    ld (iy+0),$EE
        inc iy
        pop bc
        inc b
        ld a,b
        cp 6
        jr nz,.f
        ; SGNEXP 2^3 (single), DBLEXP 2^3 (double), INTEXP 3^4
        ld hl,Two
        ld de,DAC
        ld bc,8
        ldir
        ld hl,Three
        ld de,ARG
        ld bc,8
        ldir
        ld a,4
        ld (VALTYP),a
        call $37C8
        ld hl,DAC
        call save8
        ld a,(VALTYP)
        ld (iy+0),a
        inc iy
        ld hl,Two
        ld de,DAC
        ld bc,8
        ldir
        ld hl,Three
        ld de,ARG
        ld bc,8
        ldir
        ld a,8
        ld (VALTYP),a
        call $37D7
        ld hl,DAC
        call save8
        ld a,(VALTYP)
        ld (iy+0),a
        inc iy
        ld de,3
        ld hl,4
        call $383F
        ld hl,DAC
        call save8
        ld a,(VALTYP)
        ld (iy+0),a
        inc iy
        jp TestEnd
Two:    db $41,$20,0,0,0,0,0,0
Three:  db $41,$30,0,0,0,0,0,0
        TEST_END "../out/mathextra.bin"
