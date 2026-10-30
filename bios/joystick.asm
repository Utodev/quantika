; joystick.asm: the cursor keys and the two joystick ports (through PSG register 14, port selected
; with bit 6 of register 15; lines are 0 when pressed).

; GetStick: GTSTCK. In: A = 0 cursor keys, 1 joystick 1, 2 joystick 2.
; Out: A = direction, 0 none, 1 up, then clockwise to 8 up-left. Destroys all.
GetStick:
        or a
        jr nz,.joystick
        ld a,$08                        ; row 8: right, down, up, left in bits 7-4
        call ReadKeyRow
        cpl
        ld b,$00                        ; B = up 1, down 2, left 4, right 8
        rla
        rl c                            ; (C = right)
        rla
        jr nc,.noDown
        set 1,b
.noDown:
        rla
        jr nc,.noUp
        set 0,b
.noUp:
        rla
        jr nc,.noLeft
        set 2,b
.noLeft:
        bit 0,c
        jr z,.lookUp
        set 3,b
        jr .lookUp
.joystick:
        call ReadJoystickPort           ; bits 0-3: up, down, left, right (1 = pressed)
        and $0F
        ld b,a
.lookUp:
        ld hl,DirectionTable
        ld a,l
        add a,b
        ld l,a
        jr nc,.noCarry
        inc h
.noCarry:
        ld a,(hl)
        ret

; Direction for each combination of up (1), down (2), left (4), right (8): opposite lines cancel.
DirectionTable:
        db 0, 1, 5, 0, 7, 8, 6, 7, 3, 2, 4, 3, 0, 1, 5, 0

; GetTrigger: GTTRIG. In: A = 0 space bar, 1 / 2 button A of joystick 1 / 2, 3 / 4 button B.
; Out: A = FFh pressed, 0 not. Destroys all.
GetTrigger:
        or a
        jr nz,.joystick
        ld a,$08
        call ReadKeyRow
        and $01                         ; the space bar
        jr .result
.joystick:
        ld c,$10                        ; button A: bit 4 of the port
        cp $03
        jr c,.portChosen
        ld c,$20                        ; button B: bit 5
        sub $02
.portChosen:
        push bc
        call ReadJoystickPort
        cpl                             ; back to 0 = pressed
        pop bc
        and c
.result:
        sub $01                         ; 0 (pressed) -> FFh with carry
        sbc a,a
        ret

; ReadJoystickPort: In: A = 1 or 2. Out: A = the port's lines inverted (1 = pressed). Destroys BC, E.
ReadJoystickPort:
        ld b,a
        di
        ld a,PsgPortB
        out (PsgAddress),a
        in a,(PsgRead)
        and $BF                         ; bit 6: 0 port 1, 1 port 2
        djnz .port2Chosen
        jr .select
.port2Chosen:
        or $40
.select:
        out (PsgWrite),a
        ld a,PsgPortA
        out (PsgAddress),a
        in a,(PsgRead)
        ei
        cpl
        ret

; GetPad / GetPaddle: GTPAD / GTPDL. No touch pad or paddles: 0.
GetPad:
GetPaddle:
        xor a
        ret
