; keyboard.asm: the keyboard matrix (11 rows of 8 keys, 0 = pressed) read through the 8255.

; ScanKeyboard: OLDKEY = NEWKEY, then NEWKEY = the 11 rows now. Destroys AF, BC, DE, HL.
ScanKeyboard:
        ld hl,NEWKEY
        ld de,OLDKEY
        ld bc,$000B
        ldir
        ld hl,NEWKEY
        in a,(PpiControl)
        and $F0
        ld c,a                          ; C = port C with row 0 (its other bits kept)
        ld b,$0B
.nextRow:
        ld a,c
        out (PpiControl),a
        in a,(PpiKeyRow)
        ld (hl),a
        inc hl
        inc c
        djnz .nextRow
        ret

; ReadKeyRow: SNSMAT. In: A = row (0-10). Out: A = its eight keys (bit 0 = pressed). Destroys C.
ReadKeyRow:
        ld c,a
        in a,(PpiControl)
        and $F0
        or c
        out (PpiControl),a
        in a,(PpiKeyRow)
        ret

; KeyAvailable: CHSNS. Z when the key buffer is empty. Destroys AF.
KeyAvailable:
        push hl
        push de
        ld hl,(GETPNT)
        ld de,(PUTPNT)
        rst $20                         ; DCOMPR
        pop de
        pop hl
        ret

; ClearKeyBuffer: KILBUF. Forget the keys typed. Destroys HL.
ClearKeyBuffer:
        ld hl,(PUTPNT)
        ld (GETPNT),hl
        ret

; SetCapsLed: CHGCAP. In: A = 0 lamp off, else on. Destroys AF.
SetCapsLed:
        or a
        ld a,$0D                        ; 8255 bit set of C6: lamp off
        jr z,.write
        dec a                           ; bit reset: lamp on
.write:
        out (PpiMode),a
        ret

; SetOneBitSound: CHGSND. In: A = 0 low, else high (the click output). Destroys AF.
SetOneBitSound:
        or a
        ld a,$0E                        ; 8255 bit reset of C7
        jr z,.write
        inc a                           ; bit set
.write:
        out (PpiMode),a
        ret

; --- key codes ---

KeyRepeatDelay  equ 25                  ; frames before a held key repeats
KeyRepeatRate   equ 3                   ; frames between repeats
KeyBufferEnd    equ KEYBUF + 40

; ProcessKeys: after ScanKeyboard, in the interrupt: STOP / CTRL+STOP, CAPS, the keys pressed since the
; last frame and the repeat of a held key, into the key buffer. Destroys all.
ProcessKeys:
        ld hl,NEWKEY + 7                ; STOP: INTFLG = 4, with CTRL 3 (unless BASROM forbids it)
        ld a,(OLDKEY + 7)
        cpl
        or (hl)
        bit 4,a
        jr nz,.noStop
        ld a,(BASROM)
        or a
        jr nz,.noStop
        ld a,(NEWKEY + 6)
        bit 1,a
        ld a,$04
        jr nz,.setStop
        call StopKeyTrap                ; (ON STOP GOSUB)
        jr c,.noStop
        call ClearKeyBuffer
        ld a,$03                        ; (and the code 03h, which ends a line being typed)
        call PutKeyCode
        ld a,$03
.setStop:
        ld (INTFLG),a
.noStop:
        ld hl,NEWKEY + 6                ; CAPS: the lock and its lamp
        ld a,(OLDKEY + 6)
        cpl
        or (hl)
        bit 3,a
        jr nz,.noCaps
        ld a,(CAPST)
        cpl
        ld (CAPST),a
        call SetCapsLed
.noCaps:
        ld hl,OLDKEY
        ld de,NEWKEY
        ld bc,$0B00                     ; B = rows, C = number of the row's first key
.row:
        push bc
        ld a,(de)
        cpl
        and (hl)                        ; down now, up the frame before
        ld b,a
        ld a,c
        cp 6 * 8
        jr nz,.notModifiers
        ld a,b
        and $E0                         ; row 6: only F1-F3 give codes
        ld b,a
.notModifiers:
        cp 7 * 8
        jr nz,.notStopRow
        res 4,b                         ; STOP is done above
.notStopRow:
        ld a,b                          ; (most rows have nothing new)
        or a
        jr z,.rowDone
        push hl
        push de
        ld e,c
        ld d,$08
.bit:
        srl b
        jr nc,.nextBit
        push bc
        push de
        ld a,e
        call KeyDown
        pop de
        pop bc
        ld a,KeyRepeatDelay
        ld (REPCNT),a
.nextBit:
        inc e
        dec d
        jr nz,.bit
        pop de
        pop hl
.rowDone:
        pop bc
        inc hl
        inc de
        ld a,c
        add a,$08
        ld c,a
        djnz .row
        ; repeat
        call FindHeldKey
        jr nc,.held
        xor a
        ld (REPCNT),a
        ret
.held:
        ld b,a
        ld hl,REPCNT
        ld a,(hl)
        or a
        ret z
        dec (hl)
        ret nz
        ld (hl),KeyRepeatRate
        ld a,b
        jp KeyDown

; FindHeldKey: the first key held that can repeat (not a modifier, a function key or STOP).
; Out: A = key number (row * 8 + bit), carry when there is none. Destroys BC, HL.
FindHeldKey:
        ld hl,NEWKEY
        ld c,$00
.row:
        ld a,(hl)
        cpl
        ld b,a
        ld a,c
        cp 6 * 8
        jr nz,.notRow6
        ld b,$00
.notRow6:
        cp 7 * 8
        jr nz,.notRow7
        ld a,b
        and $EC                         ; not F4, F5, STOP
        ld b,a
.notRow7:
        ld a,b
        or a
        jr nz,.found
        inc hl
        ld a,c
        add a,$08
        ld c,a
        cp 11 * 8
        jr c,.row
        scf
        ret
.found:
        ld a,c
.findBit:
        srl b
        jr c,.done
        inc a
        jr .findBit
.done:
        or a                            ; no carry: found
        ret

; KeyDown: the code(s) of a key into the buffer. In: A = key number (row * 8 + bit). Destroys all.
KeyDown:
        cp 6 * 8
        jr nc,.special
        ld c,a
        ld b,$00
        ld a,(NEWKEY + 6)               ; modifiers: bit 0 SHIFT, 1 CTRL, 2 GRAPH, 4 CODE (0 = down)
        ld d,a
        ld hl,KeysGraph
        bit 2,d
        jr z,.layer
        ld hl,KeysCode
        bit 4,d
        jr z,.layer
        ld hl,KeysNormal
        bit 0,d
        jr nz,.plain
        ld hl,KeysShift
.plain:
        add hl,bc
        ld a,(hl)
        or a
        ret z
        bit 1,d
        jr nz,.noControl
        cp $40                          ; CTRL: letters and @ [ \ ] ^ _ to control codes
        jp c,PutKeyCode
        and $1F
        jr PutKeyCode
.noControl:
        ld e,a
        ld a,(CAPST)
        or a
        ld a,e
        jr z,PutKeyCode
        or $20                          ; CAPS: letters in capitals (with SHIFT too, as the original)
        cp 'a'
        ld a,e
        jr c,PutKeyCode
        or $20
        cp 'z' + 1
        ld a,e
        jr nc,PutKeyCode
        and $DF
        jr PutKeyCode
.layer:
        bit 0,d                         ; GRAPH / CODE with SHIFT: the next table
        jr nz,.layerPlain
        ld de,48
        add hl,de
.layerPlain:
        add hl,bc
        ld a,(hl)
        or a
        ret z
        cp $20
        jr nc,PutKeyCode
        push af                         ; codes below 20h: 01h, then code + 40h
        ld a,$01
        call PutKeyCode
        pop af
        add a,$40
        jr PutKeyCode
.special:
        sub 6 * 8
        ld c,a
        ld b,$00
        ld hl,KeysSpecial
        add hl,bc
        ld a,(hl)
        or a
        ret z
        cp $06
        jr c,.functionKey
        cp $0B                          ; SHIFT + HOME: clear screen
        jr nz,PutKeyCode
        ld e,a
        ld a,(NEWKEY + 6)
        rrca
        ld a,e
        jr c,PutKeyCode
        ld a,$0C
        jr PutKeyCode
.functionKey:
        dec a
        ld e,a
        ld a,(NEWKEY + 6)
        rrca
        ld a,e
        jr c,.keyChosen
        add a,$05                       ; SHIFT: F6-F10
.keyChosen:
        call FunctionKeyTrap            ; (ON KEY GOSUB)
        ret c
        ld l,a
        ld h,$00
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,FNKSTR
        add hl,bc
        ld b,15
.keyChar:
        ld a,(hl)
        or a
        ret z
        push hl
        push bc
        call PutKeyCode
        pop bc
        pop hl
        inc hl
        djnz .keyChar
        ret

; PutKeyCode: one code into the key buffer (dropped when it is full), with the key click.
; In: A. Destroys AF, DE, HL.
PutKeyCode:
        ld hl,(PUTPNT)
        ld (hl),a
        call NextBufferPos
        ld de,(GETPNT)
        rst $20
        ret z                           ; full
        ld (PUTPNT),hl
        ld a,(CLIKSW)
        or a
        ret z
        ld a,$0F                        ; click: bit 7 of port C up and down
        out (PpiMode),a
        ld a,$20
.delay:
        dec a
        jr nz,.delay
        ld a,$0E
        out (PpiMode),a
        ret

; NextBufferPos: HL one place on in the circular key buffer. Destroys AF, DE.
NextBufferPos:
        inc hl
        ld de,KeyBufferEnd
        rst $20
        ret nz
        ld hl,KEYBUF
        ret

; GetKey: CHGET. Waits for a key, showing the cursor (in the text modes) while it waits; the status line
; (the date and time) is drawn again when the minute changes. Out: A = code. Preserves the others.
GetKey:
        push hl
        push de
        push bc
        call H_CHGE
        call KeyAvailable
        jr nz,.take
        ld a,(CSRSW)
        or a
        call z,DrawCursor
.wait:
        ei
        halt
        ld a,(CNSDFG)
        or a
        jr z,.sameMinute
        ld a,$02                        ; the minute (BCD) against the one shown
        call ClockPair
        ld hl,FNKSWI
        cp (hl)
        call nz,ShowFunctionKeys
.sameMinute:
        call KeyAvailable
        jr z,.wait
        ld a,(CSRSW)
        or a
        call z,EraseCursor
.take:
        ld hl,(GETPNT)
        ld a,(hl)
        push af
        call NextBufferPos
        ld (GETPNT),hl
        pop af
        pop bc
        pop de
        pop hl
        ret

; CheckCtrlStop: BREAKX. Reads the keyboard itself (it works with interrupts off): carry when CTRL and
; STOP are down, and then the key buffer is emptied. Destroys AF.
CheckCtrlStop:
        push bc
        ld a,$07
        call ReadKeyRow
        and $10
        jr nz,.notPressed
        ld a,$06
        call ReadKeyRow
        and $02
        jr nz,.notPressed
        push hl
        call ClearKeyBuffer
        pop hl
        pop bc
        scf
        ret
.notPressed:
        pop bc
        or a
        ret

; Beep: BEEP, as SET BEEP chose it (the clock's memory, block 2 register 10: (tone - 1) * 4 + volume - 1;
; the volume starts at 4, 7, 10 or 15), as the original sounds: tone 1 a short beep, 2 three voices dying
; away together, 3 two notes and 4 three short ones, each dying away. Destroys all.
Beep:
        ld a,$0D                        ; the setting (block 2), then block 0 again
        out (RtcIndex),a
        ld a,$0A
        out (RtcData),a
        out (RtcIndex),a
        in a,(RtcData)
        ld c,a
        ld a,$0D
        out (RtcIndex),a
        ld a,$08
        out (RtcData),a
        ld a,c
        and $03
        ld hl,BeepLevels
        add a,l
        ld l,a
        jr nc,.level
        inc h
.level:
        ld d,(hl)                       ; D = the volume to start at
        ld a,c
        rrca
        rrca
        and $03                         ; the tone - 1
        jr z,.one
        dec a
        jr z,.chorus
        ld hl,BeepThreeNotes            ; tone 4: three notes of 6 frames
        ld bc,$0300 + 6 * 4
        dec a
        jr nz,.notes
        ld hl,BeepTwoNotes              ; tone 3: two notes of 18 frames
        ld bc,$0200 + 18 * 4
.notes:
        ld a,PsgMixer
        ld e,$BE                        ; tone A only
        call WritePsg
.note:
        xor a
        ld e,(hl)
        inc hl
        call WritePsg
        inc a
        ld e,$00
        call WritePsg
        call BeepDecay
        djnz .note
        jr BeepEnd
.chorus:
        ld a,PsgMixer                   ; tone 2: three voices a little apart, 18 frames
        ld e,$B8
        call WritePsg
        ld hl,BeepChorus
        ld b,6
.voice:
        ld a,(hl)                       ; register, value
        inc hl
        ld e,(hl)
        inc hl
        call WritePsg
        djnz .voice
        ld c,18 * 4
        call BeepDecay
        jr BeepEnd
.one:
        xor a                           ; tone 1: a short beep
        ld e,$55
        call WritePsg
        inc a
        ld e,$00
        call WritePsg
        ld a,PsgMixer
        ld e,$BE
        call WritePsg
        ld a,$08
        ld e,d
        call WritePsg
        ld a,10
        call BeepWait
BeepEnd:
        ld e,$00                        ; silence, the three tones on as they were left
        ld a,$08
        call WritePsg
        inc a
        call WritePsg
        inc a
        call WritePsg
        ld a,PsgMixer
        ld e,$B8
        jp WritePsg
BeepLevels:
        db 4, 7, 10, 15
BeepTwoNotes:
        db $2A, $35
BeepThreeNotes:
        db $6B, $47, $55
BeepChorus:                             ; B A7h, C A8h, A A6h
        db 2, $A7, 3, $00, 4, $A8, 5, $00, 0, $A6, 1, $00

; BeepDecay: the three volumes from D down to 1, the whole fall C quarter frames long. Keeps B, D, HL.
BeepDecay:
        push bc
        push hl
        ld a,c                          ; each volume: C / D quarter frames
        ld c,$00
.divide:
        inc c
        sub d
        jr nc,.divide
        dec c
        jr nz,.time
        inc c
.time:
        ld e,d
.step:
        ld a,$08
        call WritePsg
        inc a
        call WritePsg
        inc a
        call WritePsg
        ld a,c
        call BeepWait
        dec e
        jr nz,.step
        pop hl
        pop bc
        ret

; BeepWait: about A quarters of a frame (the interrupt's time counted too). Keeps BC, DE, HL.
BeepWait:
        push bc
.quarter:
        ld c,4
.loop:
        ld b,$00
.inner:
        djnz .inner
        dec c
        jr nz,.loop
        ld b,96
.more:
        djnz .more
        dec a
        jr nz,.quarter
        pop bc
        ret
