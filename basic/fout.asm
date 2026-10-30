; fout.asm: FOUT / PUFOUT, the number in DAC as text in FBUFFR. Unformatted (as PRINT and STR$ show
; numbers): a space or a minus, then the digits without the zeros at the end; a whole number with up to
; 14 digits, or a fraction with at most one zero after the point, in plain digits (.5, .0123), others
; as d.dddE+nn. Single precision shows 6 digits at most, double precision 14.

FoutBuffer      equ FBUFFR + 1          ; the text starts here (FBUFFR is the byte before)

; FormatNumber: PUFOUT. In: A = format (bit 7 = formatted, as PRINT USING: stage 6), B, C = digits
; before and after the point. Out: HL = the text (ends with 0). Destroys all.
FormatNumber:
        ld hl,FoutBuffer
        ld a,(VALTYP)
        cp TypeInteger
        jr nz,.real
        ld de,(DAC + 2)                 ; integer: the sign, then the digits
        ld (hl),' '
        bit 7,d
        jr z,.intPositive
        ld (hl),'-'
        ex de,hl
        call NegateHL                   ; (8000h read unsigned is 32768)
        ex de,hl
.intPositive:
        inc hl
        ex de,hl
        call PutUnsigned                ; HL = value, DE = text
        jr .end
.real:
        ld (hl),' '
        ld a,(DAC)
        or a
        jp p,.realPositive
        ld (hl),'-'
.realPositive:
        inc hl
        and $7F
        jr nz,.notZero
        ld (hl),'0'
        inc hl
        jr .end
.notZero:
        push hl
        call CountDigits                ; C = digits to show (no zeros at the end)
        pop hl
        ld a,(DAC)
        and $7F
        sub $40                         ; A = position of the point
        ld b,a
        cp -1
        jp m,.scientific                ; (below -1)
        cp 15
        jp p,.scientific
        ; plain digits
        or a
        jp m,.leadingZero
        jr nz,.wholeDigits
        ld (hl),'.'                     ; 0.ddd: the point first
        inc hl
        ld e,$00                        ; E = digit number
        jr .rest
.leadingZero:
        ld (hl),'.'
        inc hl
        ld (hl),'0'
        inc hl
        ld e,$00
        jr .rest
.wholeDigits:
        ld e,$00
.integerPart:
        call DigitE
        ld (hl),a
        inc hl
        inc e
        dec b
        jr nz,.integerPart
        ld a,e                          ; any digits after the point?
        cp c
        jr nc,.end
        ld (hl),'.'
        inc hl
.rest:
        ld a,e
        cp c
        jr nc,.end
        call DigitE
        ld (hl),a
        inc hl
        inc e
        jr .rest
.end:
        ld (hl),$00
        ld hl,FoutBuffer
        ret
.scientific:
        ld e,$00
        call DigitE                     ; d
        ld (hl),a
        inc hl
        inc e
        ld a,c
        cp $02
        jr c,.exponent
        ld (hl),'.'                     ; .ddd
        inc hl
.fraction:
        call DigitE
        ld (hl),a
        inc hl
        inc e
        ld a,e
        cp c
        jr c,.fraction
.exponent:
        ld (hl),'E'
        inc hl
        ld a,b                          ; exponent = point position - 1
        dec a
        ld (hl),'+'
        jp p,.positiveExponent
        ld (hl),'-'
        neg
.positiveExponent:
        inc hl
        ld c,'0' - 1                    ; two digits
.tens:
        inc c
        sub 10
        jr nc,.tens
        add a,'0' + 10
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        jr .end

; DigitE: A = the ASCII digit number E (from 0) of DAC's mantissa. Preserves the others.
DigitE:
        push hl
        push de
        ld a,e
        srl a
        ld e,a
        ld d,$00
        ld hl,DAC + 1
        add hl,de
        pop de
        bit 0,e
        ld a,(hl)
        jr nz,.low
        rrca
        rrca
        rrca
        rrca
.low:
        and $0F
        add a,'0'
        pop hl
        ret

; CountDigits: C = how many digits of DAC to show: 6 or 14 by VALTYP, less the zeros at the end.
; Destroys AF, E, HL.
CountDigits:
        ld a,(VALTYP)
        cp TypeDouble
        ld c,6
        jr nz,.drop
        ld c,14
.drop:
        ld e,c
        dec e
        call DigitE
        cp '0'
        ret nz
        dec c
        jr nz,.drop                     ; (a mantissa of zeros does not get here)
        inc c
        ret

; PutUnsigned: the decimal digits of HL (unsigned, no leading zeros) at DE. Out: HL = after them.
; Destroys AF, BC, DE.
PutUnsigned:
        push de
        ld de,PowersOfTen
        ld b,$05
        ld c,$00                        ; C = a digit has been written
.power:
        push bc
        ld a,(de)
        ld c,a
        inc de
        ld a,(de)
        ld b,a
        inc de
        xor a
.count:
        or a
        sbc hl,bc
        jr c,.counted
        inc a
        jr .count
.counted:
        add hl,bc
        pop bc
        ex (sp),hl                      ; HL = text, the value on the stack
        or a
        jr nz,.write
        bit 0,c
        jr nz,.write
        ld a,b
        dec a
        jr nz,.skip                     ; leading 0 (the units always show)
        xor a
.write:
        add a,'0'
        ld (hl),a
        inc hl
        set 0,c
.skip:
        ex (sp),hl
        djnz .power
        pop hl
        ret
