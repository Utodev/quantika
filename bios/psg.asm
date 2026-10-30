; psg.asm: the sound chip (and through it the joystick ports and the cassette input).

; InitPsg: GICINI. Silence: tones 0, volumes 0, mixer with port A as input and port B as output.
; Destroys AF, E.
InitPsg:
        xor a
        ld e,a
.nextRegister:
        call WritePsg
        inc a
        cp $0E
        jr c,.nextRegister
        ld a,PsgMixer
        ld e,$B8                        ; tones on, noise off, port A in, port B out
        call WritePsg
        ld a,PsgPortB
        ld e,$8F                        ; kana lamp off, joystick port 1, all pins high
        jp WritePsg

; WritePsg: WRTPSG. In: A = register, E = value. Preserves all.
WritePsg:
        di
        out (PsgAddress),a
        push af
        ld a,e
        out (PsgWrite),a
        pop af
        ei
        ret

; ReadPsg: RDPSG. In: A = register. Out: A = value.
ReadPsg:
        out (PsgAddress),a
        in a,(PsgRead)
        ret
