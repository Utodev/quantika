; traps.asm (BASIC): ON KEY / STOP / SPRITE / STRIG / INTERVAL GOSUB, the statements that turn the traps
; on, off or stop them, and running them between statements (bios/traps.asm has the table and what the
; interrupt does). A trap's GOSUB is like any other but its marker's high byte is the trap's number + 1;
; the trap is stopped until its RETURN, which turns it on again.
;
; INTERVAL is not a keyword: the tokenizer makes it INT, "ER", VAL (FFh 85h 'E' 'R' FFh 94h).

; RunTraps: (from NewStatement, when ONGSBF is set) a trap that is on, not stopped and has happened:
; GOSUB to its line. HL = the text; it comes back with it when there is none (and ONGSBF clear).
RunTraps:
        call ProgramRunning
        ret z
        push hl
        ld hl,TRPTBL
        ld b,$00
.entry:
        ld a,(hl)
        and (1 << TrapOn) | (1 << TrapStopped) | (1 << TrapHappened)
        cp (1 << TrapOn) | (1 << TrapHappened)
        jr z,.found
.next:
        inc hl
        inc hl
        inc hl
        inc b
        ld a,b
        cp TrapCount
        jr c,.entry
        xor a
        ld (ONGSBF),a
        pop hl
        ret
.found:
        res TrapHappened,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        dec hl
        ld a,d
        or e
        jr z,.next                      ; no line for it: forgotten
        set TrapStopped,(hl)
        pop hl                          ; the text
        pop af                          ; (the return into NewStatement)
        dec sp                          ; (the GOSUB frame's unused byte)
        push hl                         ; the frame: the text, the line, the marker with the trap
        ld hl,(CURLIN)
        push hl
        inc b
        ld h,b
        ld l,TkGosub
        push hl
        call CheckStackRoom
        ex de,hl                        ; the line's address
        dec hl                          ; on the 0 before it: NewStatement reads the line from there
        ld bc,$0000
        ld (CURLIN),bc
        jp NewStatement

; TrapReturned: RETURN from trap A - 1: on again if it is still on. Keeps BC, DE, IX.
TrapReturned:
        dec a
        call TrapEntry
        bit TrapOn,(hl)
        ret z
        res TrapStopped,(hl)
        bit TrapHappened,(hl)
        ret z
        ld a,$01
        ld (ONGSBF),a
        ret

; TrapState: ON, OFF or STOP after the name of trap A (FNKFLG follows KEY(n) ON).
TrapState:
        push af
        call ThisChar
        ld c,1 << TrapOn
        cp TkOn
        jr z,.state
        ld c,$00
        cp TkOff
        jr z,.state
        ld c,1 << TrapStopped
        cp TkStop
        jp nz,SyntaxError
.state:
        rst $10
        pop af
        push hl
        ld b,a
        call TrapEntry
        ld a,c
        or a
        jr z,.set                       ; OFF: what happened is forgotten
        ld a,(hl)
        and 1 << TrapHappened
        or c
        cp (1 << TrapOn) | (1 << TrapHappened)
        jr nz,.set
        ld (hl),a                       ; on, and it has happened: BASIC runs it
        ld a,$01
        ld (ONGSBF),a
        jr .key
.set:
        ld (hl),a
.key:
        ld a,b                          ; F1-F10: FNKFLG
        cp 10
        jr nc,.done
        ld e,a
        ld d,$00
        ld hl,FNKFLG
        add hl,de
        ld a,c
        and 1 << TrapOn
        ld (hl),a
.done:
        pop hl
        ret

; KeyTrapState: KEY(n) ON / OFF / STOP (HL on the bracket).
KeyTrapState:
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld a,e
        dec a
        cp 10
        jp nc,IllegalFunction
        jr TrapState

; StatementFunctionToken: a statement that starts with FFh: STRIG(n) / INTERVAL ON / OFF / STOP, or
; MID$(...) = (HL on the FFh).
StatementFunctionToken:
        inc hl
        ld a,(hl)
        dec hl
        cp FnStrig
        jr z,.strig
        cp FnInt
        jr z,.interval
        ld a,TkFunction
        jp StatementMidAssign
.strig:
        call StrigNumber
        jr TrapState
.interval:
        call IntervalWord
        ld a,TrapInterval
        jr TrapState

; StrigNumber: STRIG(n) (HL on the FFh). Out: A = its trap.
StrigNumber:
        inc hl
        rst $10
        call ParenInteger
        ld a,d
        or a
        jp nz,IllegalFunction
        ld a,e
        cp 5
        jp nc,IllegalFunction
        add a,TrapStrig
        ret

; IntervalWord: INTERVAL (HL on its first FFh): Syntax error when it is not. Out: HL past it.
IntervalWord:
        push de
        ld de,IntervalTokens
        ld b,6
.byte:
        ld a,(de)
        cp (hl)
        jp nz,SyntaxError
        inc de
        inc hl
        djnz .byte
        pop de
        jp ThisChar
IntervalTokens:
        db TkFunction, FnInt, 'E', 'R', TkFunction, FnVal

; OnTrap: ON KEY / STOP / SPRITE / STRIG / INTERVAL = n GOSUB lines (HL on the trap's name, A = it).
; Carry when it is none of them (an ON value GOTO / GOSUB).
OnTrap:
        ld bc,(TrapKey << 8) | 10
        cp TkKey
        jr z,.lines
        ld bc,(TrapStop << 8) | 1
        cp TkStop
        jr z,.lines
        ld bc,(TrapSprite << 8) | 1
        cp TkSprite
        jr z,.lines
        cp TkFunction
        scf
        ret nz
        inc hl
        ld a,(hl)
        dec hl
        cp FnStrig
        jr z,.strig
        cp FnInt
        scf
        ret nz
        call IntervalWord               ; INTERVAL = period
        rst $08
        db TkEqual
        call EvalInteger
        ld a,d
        or e
        jp z,IllegalFunction
        ld (INTVAL),de
        ld (INTCNT),de
        ld bc,(TrapInterval << 8) | 1
        jr .gosub
.strig:
        inc hl
        ld bc,(TrapStrig << 8) | 5
.lines:
        rst $10
.gosub:
        rst $08
        db TkGosub
.line:
        call ThisChar
        cp ','
        jr z,.next                      ; none: that trap stays as it is
        call AtStatementEnd
        jr z,.done
        push bc
        call GetLineNumber
        jp c,SyntaxError
        ld a,d
        or e
        jr z,.store                     ; line 0: none
        push hl
        call FindLine                   ; BC = its address
        ld e,ErrUndefinedLine
        jp nc,RaiseError
        ld d,b
        ld e,c
        pop hl
.store:
        pop bc
        push hl
        ld a,b
        call TrapEntry
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        pop hl
.next:
        inc b
        dec c
        jr z,.done
        call ThisChar
        cp ','
        jr nz,.done
        rst $10
        jr .line
.done:
        or a
        ret
