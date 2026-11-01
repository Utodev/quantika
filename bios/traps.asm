; traps.asm: the events of ON KEY / STOP / SPRITE / STRIG / INTERVAL GOSUB, as the interrupt sees them
; (BASIC runs them: basic/traps.asm). TRPTBL has 3 bytes a trap: the state (bit 0 ON, bit 1 STOP,
; bit 2 it has happened) and the address of the line to GOSUB. A trap happens when it is on or stopped;
; ONGSBF tells BASIC there may be one to run. The keys F1-F10 are traps instead of their texts while
; FNKFLG says so (KEY(n) ON) and a program runs; CTRL+STOP too while STOP is ON.

TrapKey         equ 0                   ; (trap numbers) 0-9: F1-F10
TrapStop        equ 10
TrapSprite      equ 11
TrapStrig       equ 12                  ; 12-16: STRIG(0)-STRIG(4)
TrapInterval    equ 17
TrapCount       equ 26
TrapOn          equ 0                   ; (bits of a trap's state)
TrapStopped     equ 1
TrapHappened    equ 2

; TrapEntry: HL = the TRPTBL entry of trap A. Keeps BC, DE.
TrapEntry:
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,$00
        push de
        ld de,TRPTBL
        add hl,de
        pop de
        ret

; RaiseTrap: trap A has happened (it counts when the trap is on or stopped). Keeps BC, DE.
RaiseTrap:
        call TrapEntry
        ld a,(hl)
        and (1 << TrapOn) | (1 << TrapStopped)
        ret z
        set TrapHappened,(hl)
        ld a,$01
        ld (ONGSBF),a
        ret

; ProgramRunning: Z when BASIC is in direct mode (CURLIN = FFFFh). Keeps BC, DE, HL.
ProgramRunning:
        push hl
        ld hl,(CURLIN)
        ld a,h
        and l
        inc a
        pop hl
        ret

; FunctionKeyTrap: function key A (0-9) is a trap (KEY(n) ON while a program runs)? Carry when it was.
FunctionKeyTrap:
        ld e,a
        call ProgramRunning
        ld a,e
        ret z
        ld hl,FNKFLG
        ld d,$00
        add hl,de
        ld a,(hl)
        or a
        ld a,e
        ret z
        call RaiseTrap
        scf
        ret

; StopKeyTrap: CTRL+STOP is a trap (STOP ON while a program runs)? Carry when it was.
StopKeyTrap:
        call ProgramRunning
        ret z
        ld a,(TRPTBL + 3 * TrapStop)
        rrca                            ; (bit 0: ON)
        ret nc
        ld a,TrapStop
        call RaiseTrap
        scf
        ret

; InterruptTraps: in the interrupt, after the keys (A = S#0): sprites that touch, the triggers, the
; interval. Destroys all.
InterruptTraps:
        bit 5,a                         ; S#0 bit 5: two sprites touch
        jr z,.noSprite
        ld a,TrapSprite
        call RaiseTrap
.noSprite:
        ld a,(TRPTBL + 3 * TrapInterval)
        and (1 << TrapOn) | (1 << TrapStopped)
        jr z,.noInterval
        ld hl,(INTCNT)
        dec hl
        ld a,h
        or l
        jr nz,.count
        ld a,TrapInterval
        call RaiseTrap
        ld hl,(INTVAL)
.count:
        ld (INTCNT),hl
.noInterval:
        ld b,$00                        ; STRIG(0)-(4): while a trigger is down
        ld hl,TRPTBL + 3 * TrapStrig
.trigger:
        ld a,(hl)
        inc hl
        inc hl
        inc hl
        and (1 << TrapOn) | (1 << TrapStopped)
        jr z,.nextTrigger
        push hl
        ld a,b
        or a
        jr nz,.joystick
        ld a,(NEWKEY + 8)               ; the space bar (0 = down)
        cpl
        and $01
        jr .pressed
.joystick:
        push bc
        call GetTrigger
        pop bc
        or a
.pressed:
        jr z,.triggerDone
        ld a,b
        add a,TrapStrig
        call RaiseTrap
.triggerDone:
        pop hl
.nextTrigger:
        inc b
        ld a,b
        cp 5
        jr c,.trigger
        ret
