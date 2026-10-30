; cassette.asm: the cassette, in the standard's format: frequency shift keying where a 0 bit is one
; cycle of 1200 Hz and a 1 bit two cycles of 2400 Hz (2400 / 4800 Hz at 2400 baud); a byte is a 0 start
; bit, eight bits from bit 0 and two 1 stop bits; a block starts with a header of short cycles.
;
; Reading (this BIOS's way): every half cycle is timed with a counting loop and called short or long
; against a limit learnt from the header (one and a half short halves, kept in LOWLIM). A 0 bit is two
; long halves, a 1 bit four short ones, so the phase of the signal does not matter.
; Writing: CS120 / CS240 hold, for each speed, the loop counts of the high and the low half of a long
; cycle (LOW), of a short cycle (HIGH), and the header's length (HEADER: a short header is HEADER * 256
; short cycles, a long one four times that); SelectBaud copies one of them to LOW, HIGH and HEADER, which
; the writing uses. A loop takes 18 T-states (with the wait state of each M1); the low halves are a few
; loops shorter for the instructions between two cycles. CTRL+STOP is looked at inside a half whose loop
; is shortened by the time it takes, so no half grows.
; Interrupts are off from TAPION / TAPOON to TAPIOF / TAPOOF.

HalfTimeout     equ $00                 ; 256 loops (about 3 ms) without an edge: no signal
HeaderCycles    equ 200                 ; short halves in a row that make a header
StopCheckLoops  equ 12                  ; loops that CheckCtrlStop takes when nothing is pressed
JunctionLoops   equ 9                   ; loops the caller takes between two bytes (TAPOUT's return to
                                        ; its next call)

; TapeInStart: TAPION. Motor on, wait for a header and learn its speed.
; Out: carry when CTRL+STOP was pressed (then the motor is off). Destroys all.
TapeInStart:
        ld a,$01
        call SetTapeMotor
        di
        ld a,PsgPortA
        out (PsgAddress),a
.restart:
        call ReadLevel
        call ReadHalf                   ; the half under way is cut: not measured
        jr c,.silence
        ld h,HeaderCycles               ; H = halves still wanted
        ld de,$0000                     ; DE = their total length
        ld l,$00                        ; L = the length of the first half: the reference
.half:
        call ReadHalf
        jr nc,.edge
.silence:
        call CheckCtrlStop              ; silence: the only time to look at the keys
        jr c,.stopped
        jr .restart
.edge:
        ld a,l
        or a
        jr nz,.compare
        ld l,c
        jr .half
.compare:
        push bc                         ; (B is the input level)
        ld a,l                          ; within a quarter of the reference (and one)?
        srl a
        srl a
        inc a
        ld b,a
        ld a,c
        sub l
        jr nc,.positive
        neg
.positive:
        cp b
        pop bc
        jr nc,.restart
        ld a,e
        add a,c
        ld e,a
        jr nc,.noCarry
        inc d
.noCarry:
        dec h
        jr nz,.half
        ; DE / 200 = the short half; the limit is one and a half of it: DE * 3 / 400
        ex de,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de                       ; HL = 3 * total
        ld de,400
        ld c,$00
.divide:
        or a
        sbc hl,de
        jr c,.divided
        inc c
        jr .divide
.divided:
        ld a,c
        ld (LOWLIM),a
        or a
        ret
.stopped:
        call TapeInStop
        scf
        ret

; TapeInByte: TAPIN. Out: A = the next byte; carry on CTRL+STOP or a broken signal. Destroys all
; but IX, IY.
TapeInByte:
        ld a,PsgPortA
        out (PsgAddress),a
        call ReadLevel
        ld a,(LOWLIM)
        ld d,a                          ; D = short / long limit
.waitStart:                             ; the stop bits and what is left of the header: short halves
        call ReadHalf
        jr nc,.edge
        call CheckCtrlStop              ; silence: keep waiting unless CTRL+STOP
        ret c
        jr .waitStart
.edge:
        ld a,c
        cp d
        jr c,.waitStart
        call ReadHalf                   ; the second half of the start bit
        ret c
        ld e,$08                        ; E = bits to go, L = the byte
.bit:
        call ReadHalf
        ret c
        ld a,c
        cp d
        jr nc,.zero
        call ReadHalf                   ; a 1: three more short halves
        ret c
        call ReadHalf
        ret c
        call ReadHalf
        ret c
        scf
        jr .store
.zero:
        call ReadHalf
        ret c
        or a
.store:
        rr l
        dec e
        jr nz,.bit
        ld a,l
        or a
        ret

; ReadLevel: B = the cassette input now (bit 7). Destroys A. (PSG register 14 selected)
ReadLevel:
        in a,(PsgRead)
        and $80
        ld b,a
        ret

; ReadHalf: time one half cycle: loops until the input changes. In: B = level. Out: C = loops (45 T-states
; each), B = new level; carry when nothing changed for 256 loops. Destroys A.
ReadHalf:
        ld c,HalfTimeout
.wait:
        inc c
        jr z,.timeout
        in a,(PsgRead)
        and $80
        cp b
        jr z,.wait
        ld b,a
        or a
        ret
.timeout:
        scf
        ret

; TapeInStop: TAPIOF. Motor off, interrupts on.
TapeInStop:
TapeOutStop:                            ; TAPOOF: the same
        push af
        xor a
        call SetTapeMotor
        pop af
        ei
        ret

; SetTapeMotor: STMOTR. In: A = 0 stop, 1 start, FFh the other way. Destroys AF.
SetTapeMotor:
        or a
        jr z,.off
        inc a
        jr z,.toggle
.on:
        ld a,$08                        ; 8255 bit reset of C4: motor on
        out (PpiMode),a
        ret
.off:
        ld a,$09                        ; bit set: motor off
        out (PpiMode),a
        ret
.toggle:
        in a,(PpiControl)
        and $10
        jr nz,.on
        jr .off

; SelectBaud: copy the parameters of a speed to LOW / HIGH / HEADER. In: A = 1 1200 baud, 2 2400.
; Destroys AF, BC, DE, HL.
SelectBaud:
        ld hl,CS120
        dec a
        jr z,.copy
        ld hl,CS240
.copy:
        ld de,CasLow
        ld bc,$0005
        ldir
        ret

; TapeOutStart: TAPOON. Motor on and a header. In: A = 0 short header, else long. Out: carry on
; CTRL+STOP. Destroys all.
TapeOutStart:
        push af
        ld a,$01
        call SetTapeMotor
        ld bc,$0000                     ; about a second for the motor to run
.spinUp:
        ex (sp),hl
        ex (sp),hl
        dec bc
        ld a,b
        or c
        jr nz,.spinUp
        pop af
        di
        ld h,a                          ; HL = the cycles: HEADER * 256 (short), * 1024 (long)
        ld a,(CasLow + 4)
        inc h
        dec h
        ld h,a
        ld l,$00
        jr z,.cycle
        add hl,hl
        add hl,hl
.cycle:
        ld de,(CasLow + 2)              ; a short cycle
        ld a,l
        or a
        jr nz,.plain
        ld a,d                          ; every 256 cycles the keys, after a low half shortened for them
        sub StopCheckLoops
        ld d,a
        call WriteCycle
        call CheckCtrlStop
        jr nc,.next
        call TapeOutStop
        scf
        ret
.plain:
        call WriteCycle
.next:
        dec hl
        ld a,h
        or l
        jr nz,.cycle
        ret

; TapeOutByte: TAPOUT. In: A = byte. Out: carry on CTRL+STOP. Destroys all.
TapeOutByte:
        ld l,a
        ld a,$0B                        ; the start bit's high half: the keys are looked at in it
        out (PpiMode),a
        call CheckCtrlStop
        jr c,.stopped
        ld de,(CasLow)
        ld a,e
        sub StopCheckLoops
        ld c,a
.high:
        dec c
        jr nz,.high
        ld a,$0A
        out (PpiMode),a
        ld c,d
.low:
        dec c
        jr nz,.low
        ld h,$08
.bit:
        rr l
        call c,WriteOne
        call nc,WriteZero
        dec h
        jr nz,.bit
        call WriteOne                   ; two stop bits, the last low half shortened for the caller
        ld de,(CasLow + 2)
        ld a,d
        sub JunctionLoops
        ld d,a
        call WriteCycle
        or a
        ret
.stopped:
        ld a,$0A
        out (PpiMode),a
        scf
        ret

; WriteZero / WriteOne: one bit. WriteOne returns with carry set and WriteZero with it clear, so the
; CALL C / CALL NC pair in TapeOutByte writes only one of them. Destroy A, C, D, E.
WriteZero:
        ld de,(CasLow)                  ; a long cycle
        call WriteCycle
        or a
        ret
WriteOne:
        ld de,(CasLow + 2)              ; two short ones
        call WriteCycle
        call WriteCycle
        scf
        ret

; WriteCycle: the output high for E loops, then low for D loops. Keeps the carry. Destroys A, C.
WriteCycle:
        ld a,$0B                        ; 8255 bit set of C5
        out (PpiMode),a
        ld c,e
.high:
        dec c
        jr nz,.high
        ld a,$0A
        out (PpiMode),a
        ld c,d
.low:
        dec c
        jr nz,.low
        ret
