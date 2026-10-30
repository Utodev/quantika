; draw.asm: DRAW, the graphics macro language. The string is read one command at a time from MCLPTR
; (MCLLEN characters left); X runs another string in the middle (the outer place is kept on the
; stack). The commands:
;   U D L R E F G H [n]   n steps up, down, left, right and the four diagonals (1 by default)
;   M x,y                 to (x, y); with a sign before x, by (x, y) from here
;   B, N (before a move)  B: move without drawing; N: come back here after drawing
;   C n                   the colour (ATRBYT, which DRAW and the other graphic statements share)
;   S n                   the scale: steps of n / 4 pixels (S0: of 1 pixel, as S4)
;   A n                   the angle: n * 90 degrees anticlockwise (0-3)
;   X string$;            the commands of a string variable
; A number may be "=variable;" instead of digits. Spaces and ';' between commands do nothing. The
; current point is GRPACX / GRPACY, as for the other statements; DRWSCL, DRWANG and DRWFLG (bit 7 B,
; bit 6 N) keep the state.

DrawFlagNoDraw  equ 7                   ; (bits of DRWFLG)
DrawFlagReturn  equ 6

; StatementDraw: DRAW string.
StatementDraw:
        call IsGraphicMode
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        call DrawString
        pop hl
        ret

; DrawString: the commands of the string at DE (B characters); MCLPTR / MCLLEN come back as they were.
DrawString:
        ld hl,(MCLPTR)
        push hl
        ld a,(MCLLEN)
        push af
        ld (MCLPTR),de
        ld a,b
        ld (MCLLEN),a
        call DrawCommands
        pop af
        ld (MCLLEN),a
        pop hl
        ld (MCLPTR),hl
        ret

DrawCommands:
        call DrawGet
        ret c
        cp ' '
        jr z,DrawCommands
        cp ';'
        jr z,DrawCommands
        ld hl,DRWFLG
        cp 'B'
        jr nz,.notB
        set DrawFlagNoDraw,(hl)
        jr DrawCommands
.notB:
        cp 'N'
        jr nz,.notN
        set DrawFlagReturn,(hl)
        jr DrawCommands
.notN:
        ld hl,DrawDirections            ; a step command?
        ld b,8
.direction:
        cp (hl)
        jr z,.step
        inc hl
        inc hl
        inc hl
        djnz .direction
        cp 'M'
        jr z,.move
        cp 'C'
        jr z,.colour
        cp 'S'
        jr z,.scale
        cp 'A'
        jr z,.angle
        cp 'X'
        jp z,.execute
        jp IllegalFunction
.step:
        inc hl
        ld a,(hl)                       ; the unit step
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        call DrawNumber
        jr nc,.count
        ld de,$0001
.count:
        call DrawScale                  ; DE = the steps in pixels
        pop hl
        ld bc,$0000                     ; BC = x * DE, then DE = y * DE
        ld a,l
        call DrawTimesUnit
        push bc
        ld a,h
        call DrawTimesUnit
        ld d,b
        ld e,c
        pop bc
        jr .relative
.move:
        call DrawSkipSpaces
        jp c,IllegalFunction
        cp '+'
        jr z,.moveBy
        cp '-'
        jr z,.moveBy
        call DrawPair                   ; to (x, y)
        call DrawTo
        jr DrawCommands
.moveBy:
        call DrawPair
        push bc
        call DrawScale
        pop bc
        push de
        ld d,b
        ld e,c
        call DrawScale
        ld b,d
        ld c,e
        pop de
.relative:                              ; BC, DE: by so much (turned by the angle)
        call DrawRotate
        ld hl,(GRPACX)
        add hl,bc
        ld b,h
        ld c,l
        ld hl,(GRPACY)
        add hl,de
        ex de,hl
        call DrawTo
        jp DrawCommands
.colour:
        call DrawNeedNumber
        ld a,e
        ld (ATRBYT),a
        jp DrawCommands
.scale:
        call DrawNeedNumber
        ld a,e
        ld (DRWSCL),a
        jp DrawCommands
.angle:
        call DrawNeedNumber
        ld a,e
        cp $04
        jp nc,IllegalFunction
        ld (DRWANG),a
        jp DrawCommands
.execute:
        call DrawVariable               ; the string variable
        call StringOperand
        call DrawString
        jp DrawCommands

DrawDirections:                         ; letter, x step, y step
        db 'U', $00, $FF
        db 'D', $00, $01
        db 'L', $FF, $00
        db 'R', $01, $00
        db 'E', $01, $FF
        db 'F', $01, $01
        db 'G', $FF, $01
        db 'H', $FF, $FF

; DrawTimesUnit: BC = DE times A (-1, 0 or 1). Keeps DE, HL.
DrawTimesUnit:
        ld bc,$0000
        or a
        ret z
        ld b,d
        ld c,e
        dec a
        ret z
        jr DrawNegateBC

; DrawTo: the current point goes to BC, DE (kept on the screen: a point beyond an edge stays on it): a
; line from the old one unless B came before; back to the old one after N.
DrawTo:
        call ClampPoint
        ld hl,(GRPACX)
        push hl
        ld hl,(GRPACY)
        push hl
        ld (GRPACX),bc
        ld (GRPACY),de
        ld a,(DRWFLG)
        bit DrawFlagNoDraw,a
        jr nz,.moved
        pop de                          ; from the old point
        pop bc
        push bc
        push de
        call DrawLine
.moved:
        pop de
        pop bc
        ld a,(DRWFLG)
        bit DrawFlagReturn,a
        jr z,.stay
        ld (GRPACX),bc
        ld (GRPACY),de
.stay:
        xor a
        ld (DRWFLG),a
        ret

; DrawRotate: BC, DE (x, y) turned DRWANG times 90 degrees anticlockwise: (x, y) -> (y, -x) each time.
DrawRotate:
        ld a,(DRWANG)
        and $03
        ret z
.turn:
        push af
        ld h,b                          ; HL = x
        ld l,c
        ld b,d                          ; BC = y
        ld c,e
        ex de,hl
        call DrawNegateDE               ; DE = -x
        pop af
        dec a
        jr nz,.turn
        ret

DrawNegateBC:
        xor a
        sub c
        ld c,a
        sbc a,a
        sub b
        ld b,a
        ret
DrawNegateDE:
        xor a
        sub e
        ld e,a
        sbc a,a
        sub d
        ld d,a
        ret

; DrawScale: DE (signed) times DRWSCL / 4, when DRWSCL is not 0. Keeps HL.
DrawScale:
        ld a,(DRWSCL)
        or a
        ret z
        push hl
        ld c,a
        bit 7,d
        push af
        jr z,.positive
        call DrawNegateDE
.positive:
        ld hl,$0000                     ; HL = DE * C
        ld b,8
.bit:
        add hl,hl
        rlc c
        jr nc,.noAdd
        add hl,de
.noAdd:
        djnz .bit
        srl h                           ; / 4
        rr l
        srl h
        rr l
        ex de,hl
        pop af
        call nz,DrawNegateDE
        pop hl
        ret

; DrawPair: "x,y" (a sign may come before each). Out: BC = x, DE = y.
DrawPair:
        call DrawSigned
        push de
        call DrawSkipSpaces
        jp c,IllegalFunction
        cp ','
        jp nz,IllegalFunction
        call DrawGet
        call DrawSigned
        pop bc
        ret

; DrawSigned: a number with an optional sign before it. Out: DE.
DrawSigned:
        call DrawSkipSpaces
        jp c,IllegalFunction
        cp '+'
        jr z,.plus
        cp '-'
        jr nz,DrawNeedNumber
        call DrawGet
        call DrawNeedNumber
        jr DrawNegateDE
.plus:
        call DrawGet
; DrawNeedNumber: a number must come. Out: DE.
DrawNeedNumber:
        call DrawNumber
        ret nc
        jp IllegalFunction

; DrawNumber: digits or "=variable;". Out: DE, carry when there is none.
DrawNumber:
        call DrawSkipSpaces
        ret c
        cp '='
        jr z,.variable
        sub '0'
        cp 10
        ccf
        ret c
        ld de,$0000
.digit:
        call DrawGet                    ; (the digit itself)
        sub '0'
        push hl
        ld h,d                          ; DE = DE * 10 + digit
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,a
        ld d,$00
        add hl,de
        ex de,hl
        pop hl
        call DrawPeek
        ccf
        ret nc                          ; the end of the string
        sub '0'
        cp 10
        jr c,.digit
        or a
        ret
.variable:
        call DrawGet                    ; past '='
        call DrawVariable
        call ForceInteger               ; DE = its value
        ld de,(DAC + 2)
        or a
        ret

; DrawVariable: the name before the next ';' (an expression, in fact), its value in DAC.
DrawVariable:
        ld de,BUF
.char:
        call DrawGet
        jp c,IllegalFunction
        cp ';'
        jr z,.name
        call UpperCaseSub
        ld (de),a
        inc de
        jr .char
.name:
        xor a
        ld (de),a
        ld hl,BUF
        jp EvalExpression

UpperCaseSub:
        cp 'a'
        ret c
        cp 'z' + 1
        ret nc
        sub $20
        ret

; DrawSkipSpaces: the next character that is not a space, not taken. Out: A, carry at the end.
DrawSkipSpaces:
        call DrawPeek
        ret c
        cp ' '
        ret nz
        call DrawGet
        jr DrawSkipSpaces

; DrawPeek: A = the next character (upper case), not taken; carry at the end. Keeps BC, DE, HL.
DrawPeek:
        ld a,(MCLLEN)
        or a
        scf
        ret z
        push hl
        ld hl,(MCLPTR)
        ld a,(hl)
        pop hl
        call UpperCaseSub
        or a
        ret

; DrawGet: A = the next character (upper case), taken; carry at the end. Keeps BC, DE, HL.
DrawGet:
        call DrawPeek
        ret c
        push hl
        ld hl,(MCLPTR)
        inc hl
        ld (MCLPTR),hl
        ld hl,MCLLEN
        dec (hl)
        pop hl
        or a
        ret
