; sub/clock.asm: the RP-5C01 clock and its memory. C = address: block in bits 5-4, register in 3-0;
; a register holds 4 bits.

; SelectClock: the block of C in the mode register (timer on), then the register of C.
SelectClock:
        ld a,$0D
        out (RtcIndex),a
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and $03
        or $08
        out (RtcData),a
        ld a,c
        and $0F
        out (RtcIndex),a
        ret

; ReadClock: REDCLK. Out: A = the register's 4 bits.
ReadClock:
        di
        call SelectClock
        in a,(RtcData)
        ei
        and $0F
        ret

; WriteClock: WRTCLK. A = the value.
WriteClock:
        push af
        di
        call SelectClock
        pop af
        out (RtcData),a
        ei
        ret
