; mathextra.asm: the last Math-Pack entries (common/mathpack.inc), as the original's behave (black box):
; the stack moves (XTF, PUSHF, PHF, PHA, PPF, PPA: 4 or 8 bytes in memory order under the return address),
; the single precision register moves (C, B, E, D are DAC's first four bytes), FOUTB / FOUTO / FOUTH and
; the powers (SGNEXP: BCDE ^ DAC, DBLEXP: DAC ^ ARG, INTEXP: DE ^ HL; a whole result of whole numbers with an
; exponent not below 0 is an integer when it fits, any other a double).

; MathXtf: XTF. The 4 bytes on the stack and DAC's first 4 change places.
MathXtf:
        ld hl,2
        add hl,sp
        ld de,DAC
        ld b,4
.byte:
        ld a,(de)
        ld c,(hl)
        ld (hl),a
        ld a,c
        ld (de),a
        inc hl
        inc de
        djnz .byte
        ret

; MathPushf: PUSHF (DAC's 4 bytes). MathPhf: PHF (DAC's 8). MathPha: PHA (ARG's 8).
MathPushf:
        pop hl
        ld de,(DAC + 2)
        push de
        ld de,(DAC)
        push de
        jp (hl)
MathPhf:
        ld de,DAC
        jr Push8
MathPha:
        ld de,ARG
Push8:                                  ; (the 8 bytes at DE: the last word first, so they end in order)
        pop ix                          ; (the return)
        ld hl,6
        add hl,de
        ld b,4
.word:
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        dec hl
        dec hl
        push de
        djnz .word
        jp (ix)

; MathPpf: PPF (8 bytes to DAC). MathPpa: PPA (to ARG).
MathPpf:
        ld hl,DAC
        jr Pop8
MathPpa:
        ld hl,ARG
Pop8:
        pop ix                          ; (the return)
        ld b,4
.word:
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .word
        jp (ix)

; MathMovfr: MOVFR (DAC = C, B, E, D). MathMovrf: MOVRF (the registers = DAC). MathMovrmi: MOVRMI (C, B,
; E, D = 4 bytes at HL); MathMovrm: MOVRM (E, D, C, B = them); HL past them.
MathMovfr:
        ld (DAC),bc
        ld (DAC + 2),de
        ret
MathMovrf:
        ld bc,(DAC)
        ld de,(DAC + 2)
        ret
MathMovrmi:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ret
MathMovrm:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ret

; MathFoutb / MathFouto / MathFouth: FOUTB / FOUTO / FOUTH. The integer in DAC as binary / octal /
; hexadecimal text. Out: HL = it (zero ended).
MathFoutb:
        ld c,$01
        jr MathRadix
MathFouto:
        ld c,$03
        jr MathRadix
MathFouth:
        ld c,$04
MathRadix:
        ld hl,(DAC + 2)
        jp RadixText

; MathSgnexp: SGNEXP. DAC = BCDE ^ DAC (singles in, as the original takes them).
MathSgnexp:
        push bc
        push de
        call MoveDacToArg               ; the exponent to ARG (a double: the 4 bytes after it 0)
        ld hl,$0000
        ld (ARG + 4),hl
        ld (ARG + 6),hl
        pop de
        pop bc
        call MathMovfr                  ; the base to DAC
        ld hl,$0000
        ld (DAC + 4),hl
        ld (DAC + 6),hl
        jr MathDblexp

; MathIntexp: INTEXP. DAC = DE ^ HL (integers).
MathIntexp:
        push hl
        ld hl,(DAC)                     ; (an integer result leaves DAC's first two bytes as they were)
        ld (PowerKeep),hl
        pop hl
        push de
        ld (DAC + 2),hl
        ld a,TypeInteger
        ld (VALTYP),a
        call ForceDouble
        call MoveDacToArg
        pop de
        ld (DAC + 2),de
        ld a,TypeInteger
        ld (VALTYP),a
        call ForceDouble
        jr MathPower

; MathDblexp: DBLEXP. DAC = DAC ^ ARG (doubles).
MathDblexp:
        ld hl,(DAC)
        ld (PowerKeep),hl
MathPower:
        ld a,TypeDouble
        ld (VALTYP),a
        ld hl,DAC
        call WholeNumber
        ld b,a                          ; B = 1: the base is whole
        ld hl,ARG
        call WholeNumber
        and b
        ld b,a
        ld a,(ARG)
        and $80                         ; the exponent not below 0
        jr z,.sign
        ld b,$00
.sign:
        push bc
        call RealPower
        pop bc
        ld a,b
        or a
        ret z
        ld hl,DAC                       ; a whole result: an integer if it fits
        call FitsInteger
        ret nc
        call ForceInteger
        ld hl,(PowerKeep)
        ld (DAC),hl
        ret
PowerKeep       equ TEMP3               ; (DAC's first two bytes before an integer power)

; WholeNumber: A = 1 when the double at HL is a whole number (0 too), else 0. Keeps BC, HL.
WholeNumber:
        push bc
        push hl
        ld a,(hl)
        and $7F
        jr z,.whole                     ; 0
        sub $40                         ; A = the digits before the point
        jr c,.fraction
        jr z,.fraction
        cp 14
        jr nc,.whole
        ld c,a                          ; digits C to 13 must be 0
.digit:
        ld a,c
        srl a
        inc a
        ld e,a
        ld d,$00
        push hl
        add hl,de
        ld a,(hl)                       ; the byte of digit C (2 a byte, the high one first)
        pop hl
        bit 0,c
        jr nz,.low
        and $F0
        jr .test
.low:
        and $0F
.test:
        jr nz,.fraction
        inc c
        ld a,c
        cp 14
        jr c,.digit
.whole:
        ld a,$01
        jr .done
.fraction:
        xor a
.done:
        pop hl
        pop bc
        ret

; FitsInteger: carry when the whole double at HL is from -32768 to 32767. Keeps HL.
FitsInteger:
        ld a,(hl)
        and $7F
        scf
        ret z                           ; 0
        sub $40                         ; the digits before the point
        cp 6
        ret nc                          ; 6 or more: no
        cp 5
        ret c                           ; 4 or fewer: yes
        push hl                         ; 5: up to 32767 (32768 below 0)
        push de
        ld e,$70
        bit 7,(hl)
        jr z,.limit
        ld e,$80
.limit:
        inc hl
        ld a,(hl)                       ; digits 1-2
        cp $32
        jr nz,.done
        inc hl
        ld a,(hl)                       ; digits 3-4
        cp $76
        jr nz,.done
        inc hl
        ld a,(hl)                       ; digit 5
        and $F0
        cp e
        jr nz,.done
        scf                             ; (the limit itself)
.done:
        pop de
        pop hl
        ret
