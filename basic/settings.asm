; settings.asm: SET (ADJUST, BEEP, DATE, PAGE, PASSWORD, PROMPT, SCREEN, TIME, TITLE, VIDEO) and GET DATE /
; GET TIME, with the clock and its memory (as the original keeps them, black box):
;   block 0: the time (registers 0-12: seconds, minutes, hours, day of the week, day, month, year - 1980,
;     a digit a register, units first); block 1: the alarm (minutes 2-3, hours 4-5, day 7-8)
;   block 2: the settings: 0 = 0Ah (they are there), 1 and 2 = -x and -y of ADJUST, 3 = the text mode
;     (+ 2 with interlace), 4-5 = WIDTH (units nibble first), 6-8 = the colours, 9 = KEY ON (bit 0), key
;     click (1), printer (2), 2400 baud (3), 10 = BEEP's (tone - 1) * 4 + volume - 1, 11 and 12 kept
;   block 3: 0 = what follows: 0 a title, 1 a password (1, 2, 3, then its CRC-16 in 4 nibbles), 2 a prompt;
;     a text is up to 6 characters, each in two registers (low nibble first)

CmosSettings    equ $20                 ; (clock addresses: block * 16 + register)
CmosText        equ $30

; StatementSet: SET word ...
StatementSet:
        cp TkBeep
        jp z,SetBeep
        cp TkScreen
        jp z,SetScreen
        cp TkTime
        jp z,SetTime
        ld de,SetWords
.word:
        ld a,(de)
        or a
        jp z,SyntaxError
        push hl
        call MatchWord
        jr z,.found
        pop hl
.skip:
        ld a,(de)                       ; past the word's 0 and its address
        inc de
        or a
        jr nz,.skip
        inc de
        inc de
        jr .word
.found:
        pop af                          ; (the text before the word: not needed)
        ex de,hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ex de,hl
        push de
        ret                             ; to the word's routine, HL past the word
SetWords:
        db "ADJUST", 0 : dw SetAdjust
        db "DATE", 0 : dw SetDate
        db "PAGE", 0 : dw SetPageStatement
        db "PASSW", TkOr, "D", 0 : dw SetPassword
        db "PROMPT", 0 : dw SetPrompt
        db "TITLE", 0 : dw SetTitle
        db "VIDEO", 0 : dw SetVideo
        db 0

; MatchWord: Z when the text at HL starts with the word at DE (ended by 0): HL past it, DE past the 0.
; NZ otherwise (HL and DE somewhere in them).
MatchWord:
        ld a,(de)
        inc de
        or a
        ret z
        cp (hl)
        ret nz
        inc hl
        jr MatchWord

; SetAdjust: SET ADJUST (x, y) (-7 to 8 each): the picture moves (R#18) and the clock keeps it.
SetAdjust:
        call ThisChar
        rst $08
        db '('
        call AdjustValue
        push af
        call Comma
        call AdjustValue
        push af
        call ThisChar
        rst $08
        db ')'
        pop de                          ; D = y's nibble
        pop bc                          ; B = x's nibble
        push hl
        ld a,b
        ld c,CmosSettings + 1
        call WriteClock
        ld a,d
        inc c
        call WriteClock
        ld a,d
        rlca
        rlca
        rlca
        rlca
        or b
        ld b,a
        ld c,18
        call WriteVdpReg
        pop hl
        ret
; AdjustValue: a number from -7 to 8: A = minus it, 4 bits.
AdjustValue:
        call EvalInteger
        push hl
        ld hl,7
        add hl,de
        ld a,h
        or a
        jp nz,IllegalFunction
        ld a,l
        cp 16
        jp nc,IllegalFunction
        pop hl
        ld a,e
        neg
        and $0F
        ret

; SetBeep: SET BEEP [tone] [, volume] (1-4 each; the one not given stays).
SetBeep:
        rst $10
        call AtStatementEnd
        jr nz,.args
        ld e,ErrMissingOperand
        jp RaiseError
.args:
        push hl
        ld c,CmosSettings + 10
        call ReadClock
        pop hl
        ld b,a                          ; B = (tone - 1) * 4 + volume - 1
        call ThisChar
        cp ','
        jr z,.volume
        push bc
        call BeepValue
        pop bc
        rlca
        rlca
        ld c,a
        ld a,b
        and $03
        or c
        ld b,a
.volume:
        call ThisChar
        cp ','
        jr nz,.store
        rst $10
        push bc
        call BeepValue
        pop bc
        ld c,a
        ld a,b
        and $0C
        or c
        ld b,a
.store:
        push hl
        ld a,b
        ld c,CmosSettings + 10
        call WriteClock
        pop hl
        ret
; BeepValue: 1-4: A = it - 1.
BeepValue:
        call EvalByte
        dec a
        cp 4
        jp nc,IllegalFunction
        ret

; SetTitle: SET TITLE string [, colour 1-4] (the text is kept first, as the original does: then the colour,
; less one, in block 2's register 11). SetPrompt: SET PROMPT string. SetPassword: SET PASSWORD string.
SetTitle:
        call SettingText
        xor a                           ; type 0: a title
        call StoreText
        call ThisChar
        cp ','
        ret nz
        rst $10
        call EvalByte
        dec a
        cp $04
        jp nc,IllegalFunction
        push hl
        ld c,CmosSettings + 11
        call WriteClock
        pop hl
        ret
SetPrompt:
        call SettingText
        ld a,$02
        jr StoreText
SetPassword:
        call SettingText
        push hl
        push bc                         ; its CRC-16 after 1, 2, 3
        call Crc16
        ld c,CmosText
        ld a,$01
        call WriteClock
        ld b,3
        ld a,1
.digits:
        inc c
        call WriteClock
        inc a
        djnz .digits
        ld b,4
.crc:
        inc c
        ld a,l
        and $0F
        call WriteClock
        push bc
        ld b,4
.shift:
        srl h
        rr l
        djnz .shift
        pop bc
        djnz .crc
        ld b,5
.zero:
        inc c
        xor a
        call WriteClock
        djnz .zero
        pop bc
        pop hl
        ret
; SettingText: the string of SET TITLE / PROMPT / PASSWORD: B = length (6 at most), DE = characters.
SettingText:
        call EvalExpression
        push hl
        call StringOperand
        pop hl
        ld a,b
        cp 7
        ret c
        ld b,6
        ret
; StoreText: A = type, B characters at DE to block 3. Keeps HL.
StoreText:
        push hl
        ld c,CmosText
        call WriteClock
        ld h,6
.char:
        ld a,b
        or a
        jr z,.zero
        ld a,(de)
        inc de
        dec b
        jr .put
.zero:
        xor a
.put:
        push af
        inc c
        and $0F
        call WriteClock
        pop af
        rrca
        rrca
        rrca
        rrca
        and $0F
        inc c
        call WriteClock
        dec h
        jr nz,.char
        pop hl
        ret

; Crc16: HL = the CRC-16 (x^16 + x^15 + x^2 + 1, from 0, each byte from its high bit) of the B bytes at DE.
Crc16:
        ld hl,$0000
        ld a,b
        or a
        ret z
.byte:
        ld a,(de)
        inc de
        xor h
        ld h,a
        push bc
        ld b,8
.bit:
        add hl,hl
        jr nc,.next
        ld a,h
        xor $80
        ld h,a
        ld a,l
        xor $05
        ld l,a
.next:
        djnz .bit
        pop bc
        djnz .byte
        ret

; SetScreen: SET SCREEN: the text mode, its WIDTH, the colours, KEY ON / OFF, the key click, the printer,
; the cassette's speed and the interlace go to the clock's memory (the next boot starts with them).
SetScreen:
        rst $10
        call AtStatementEnd
        jp nz,SyntaxError
        push hl
        ld a,(SCRMOD)                   ; the text mode (from a graphic one: the last text mode)
        cp $02
        jr c,.text
        ld a,(OLDSCR)
.text:
        ld e,a
        ld a,(RG9SAV)                   ; + 2 with interlace
        and $08
        rrca
        rrca
        or e
        ld c,CmosSettings + 3
        call WriteClock
        ld a,e
        or a
        ld a,(LINL40)
        jr z,.width
        ld a,(LINL32)
.width:
        ld b,a
        and $0F
        inc c
        call WriteClock
        ld a,b
        rrca
        rrca
        rrca
        rrca
        and $0F
        inc c
        call WriteClock
        ld hl,FORCLR
        ld b,3
.colour:
        ld a,(hl)
        inc hl
        inc c
        call WriteClock
        djnz .colour
        ld b,$00                        ; KEY ON, click, printer, 2400 baud
        ld a,(CNSDFG)
        or a
        jr z,.noKeys
        set 0,b
.noKeys:
        ld a,(CLIKSW)
        or a
        jr z,.noClick
        set 1,b
.noClick:
        ld a,(NTSTDP)
        or a
        jr z,.standard
        set 2,b
.standard:
        ld a,(CasLow + 4)               ; (the header's length: 2400 baud has the longer one)
        cp $10
        jr c,.slow
        set 3,b
.slow:
        ld a,b
        inc c
        call WriteClock
        pop hl
        ret

; SetVideo: SET VIDEO [mode] [, Ym] [, CB] [, sync] [, voice] [, video input] [, AV control]: mode (0-3:
; R#9's bits 5-4 0, 1, 1, 2, and mode 1 R#8's bit 5) and CB (R#8's bit 4) change the VDP; the others (0-1,
; voice 0-3) are checked and have nothing to change here.
SetVideo:
        ld b,7                          ; B = the arguments left
        ld c,$00                        ; C = which one
.argument:
        call ThisChar
        cp ','
        jr z,.next
        call AtStatementEnd
        ret z
        push bc
        call EvalByte
        pop bc
        push hl
        push bc
        call VideoArgument
        pop bc
        pop hl
.next:
        call ThisChar
        cp ','
        ret nz
        rst $10
        inc c
        djnz .argument
        jp SyntaxError
; VideoArgument: argument C of SET VIDEO = A.
VideoArgument:
        ld e,a
        ld a,c
        or a
        jr z,.mode
        cp $02
        jr z,.colourBus
        cp $04
        ld a,e
        jr z,.voice
        cp $02                          ; (the others: 0 or 1)
        jp nc,IllegalFunction
        ret
.voice:
        cp $04
        jp nc,IllegalFunction
        ret
.mode:
        ld a,e
        cp $04
        jp nc,IllegalFunction
        ld d,$00                        ; D = R#9's bits 5-4
        or a
        jr z,.r9
        ld d,$10
        cp $03
        jr nz,.r9
        ld d,$20
.r9:
        push af
        ld a,(RG9SAV)
        and $CF
        or d
        ld b,a
        ld c,9
        call WriteVdpReg
        pop af
        cp $01                          ; R#8's bit 5 for mode 1
        ld d,$00
        jr nz,.r8
        ld d,$20
.r8:
        ld a,(RG8SAV)
        and $DF
        or d
        ld b,a
        ld c,8
        jp WriteVdpReg
.colourBus:
        ld a,e
        cp $02
        jp nc,IllegalFunction
        rrca
        rrca
        rrca
        rrca                            ; (bit 4)
        ld d,a
        ld a,(RG8SAV)
        and $EF
        or d
        ld b,a
        ld c,8
        jp WriteVdpReg

; SetTime / SetDate: SET TIME "HH:MM:SS" [, A] / SET DATE "MM/DD/YY" [, A] (A: the alarm, block 1). The
; string must be exactly so (Syntax error), the numbers in range (Illegal function call).
SetTime:
        rst $10
        ld a,':'
        call ClockString                ; D, E, C = the three numbers
        ld a,d
        cp 24
        jp nc,IllegalFunction
        ld a,e
        cp 60
        jp nc,IllegalFunction
        ld a,c
        cp 60
        jp nc,IllegalFunction
        call AlarmOrTime                ; B = the block's address
        push hl
        ld a,b
        or a
        ld a,c                          ; seconds (not in the alarm)
        ld c,b
        call z,WriteDecimal
        inc c
        inc c
        ld a,e
        call WriteDecimal               ; minutes
        inc c
        inc c
        ld a,d
        call WriteDecimal               ; hours
        pop hl
        ret
SetDate:
        ld a,'/'
        call ClockString                ; D = month, E = day, C = year
        ld a,d
        or a
        jp z,IllegalFunction
        cp 13
        jp nc,IllegalFunction
        ld a,e
        or a
        jp z,IllegalFunction
        cp 32
        jp nc,IllegalFunction
        ld a,c
        cp 100
        jp nc,IllegalFunction
        call AlarmOrTime
        push hl
        push bc
        ld a,b
        add a,7
        ld c,a
        ld a,e
        call WriteDecimal               ; the day
        pop bc
        ld a,b
        or a
        jr nz,.done                     ; (the alarm has only the day)
        ld a,c                          ; the year: since 1980
        sub 80
        jr nc,.year
        add a,100
.year:
        ld c,11
        call WriteDecimal
        ld a,d
        ld c,9
        call WriteDecimal               ; the month
.done:
        pop hl
        ret
; AlarmOrTime: B = 00h (block 0) or 10h (", A": block 1, the alarm).
AlarmOrTime:
        ld b,$00
        call ThisChar
        cp ','
        ret nz
        rst $10
        rst $08
        db 'A'
        ld b,$10
        ret
; ClockString: the string "nn?nn?nn" (? = A): D, E, C = its numbers. Syntax error for anything else.
ClockString:
        push af
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        pop hl
        ld a,b
        cp 8
        jp nz,SyntaxError
        pop af
        push hl
        ex de,hl
        ld b,a                          ; B = the separator
        call TwoDigits
        ld d,a
        call Separator
        call TwoDigits
        ld e,a
        call Separator
        call TwoDigits
        ld c,a
        pop hl
        ret
Separator:
        ld a,(hl)
        inc hl
        cp b
        ret z
        jp SyntaxError
TwoDigits:
        call Digit
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,a
        ld c,a
        call Digit
        add a,c
        ret
Digit:
        ld a,(hl)
        inc hl
        sub '0'
        jp c,SyntaxError
        cp 10
        jp nc,SyntaxError
        ret
; WriteDecimal: A (0-99) to the clock: units at address C, tens at C + 1. Keeps BC, DE, HL.
WriteDecimal:
        push bc
        ld b,$FF
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,10
        call WriteClock
        inc c
        ld a,b
        call WriteClock
        pop bc
        ret

; StatementGet: GET TIME string variable [, A] / GET DATE string variable [, A]; the other GETs belong to
; the disk (GET # file: a disk ROM's, through H_DGET; without one File not OPEN when it is not open, else
; Illegal function call, as the original).
StatementGet:
        cp TkTime
        jr z,GetTime
        push hl
        ld de,DateWord
        call MatchWord
        jr z,.date
        pop hl
        ld c,TkGet                      ; GET [#] n: a disk ROM's (H_DGET)
        ld iy,H_DGET
        call FileHook
        ret nc
        call FileNumber                 ; (GET [#] n)
        ld a,(de)
        or a
        ld e,ErrFileNotOpen
        jp z,RaiseError
        jp IllegalFunction
.date:
        pop af
        jr GetDate
DateWord:
        db "DATE", 0

GetTime:
        rst $10
        call GetVariable
        push de
        call AlarmOrTime                ; B = the block
        push hl
        ld hl,BUF
        ld e,':'
        ld a,b
        add a,4
        ld c,a
        call ReadDecimal                ; hours
        dec c
        dec c
        call ReadDecimal                ; minutes
        ld a,b
        or a
        ld a,$00                        ; (the alarm has no seconds)
        jr nz,.last
        ld c,$00
        call ReadClockDecimal           ; seconds
.last:
        call PutDecimal
        jr TextDone
GetDate:
        call GetVariable
        push de
        call AlarmOrTime
        push hl
        ld hl,BUF
        ld e,'/'
        ld a,b
        or a
        jr nz,.alarm
        ld c,9
        call ReadDecimal                ; month
        ld c,7
        call ReadDecimal                ; day
        ld c,11                         ; year: since 1980
        call ReadClockDecimal
        add a,80
        cp 100
        jr c,.year
        sub 100
.year:
        call PutDecimal
        jr TextDone
.alarm:
        xor a                           ; (the alarm has only the day)
        call PutDecimal
        ld (hl),e
        inc hl
        ld c,$17
        call ReadDecimal
        xor a
        call PutDecimal
TextDone:
        ld (hl),$00
        ld hl,BUF
        call StringFromZeroEnded
        pop hl
        pop de
        ld a,TypeString
        jp AssignValue
; ReadDecimal: the two digits at clock address C (units) and C + 1 to HL, then the separator E. Keeps BC, E.
ReadDecimal:
        call ReadClockDecimal
        call PutDecimal
        ld (hl),e
        inc hl
        ret
; ReadClockDecimal: A = the number at clock address C (units) and C + 1 (tens). Keeps BC, DE, HL.
ReadClockDecimal:
        push bc
        push de
        inc c
        call ReadClock
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a
        ld b,a
        dec c
        call ReadClock
        add a,b
        pop de
        pop bc
        ret
; PutDecimal: A (0-99) as two digits to HL. Keeps BC.
PutDecimal:
        push bc
        ld b,'0' - 1
.tens:
        inc b
        sub 10
        jr nc,.tens
        add a,'0' + 10
        ld (hl),b
        inc hl
        ld (hl),a
        inc hl
        pop bc
        ret

; PromptText: the prompt of SET PROMPT (block 3 says 2): its characters at BUF, ended by CR LF 0, and Z;
; NZ when there is none ("Ok" then).
PromptText:
        push hl
        push de
        push bc
        ld c,CmosText
        call ReadClock
        cp $02
        jr nz,.none
        ld hl,BUF
        ld b,6
.char:
        inc c
        call ReadClock
        ld e,a
        inc c
        call ReadClock
        rlca
        rlca
        rlca
        rlca
        or e
        jr z,.end
        ld (hl),a
        inc hl
        djnz .char
.end:
        ld (hl),$0D
        inc hl
        ld (hl),$0A
        inc hl
        ld (hl),$00
        xor a
        jr .done
.none:
        or $FF
.done:
        pop bc
        pop de
        pop hl
        ret

; --- at boot ---

; CmosCheck: when the clock's memory has no settings (block 2's register 0 is not 0Ah), the standard's
; ones (as the original writes them) and no text in block 3. Destroys AF, BC, HL.
CmosCheck:
        ld c,CmosSettings
        call ReadClock
        cp $0A
        ret z
        ld hl,CmosDefaults
        ld b,13
.setting:
        ld a,(hl)
        inc hl
        call WriteClock
        inc c
        djnz .setting
        ld c,CmosText
        ld b,13
.text:
        xor a
        call WriteClock
        inc c
        djnz .text
        ret
CmosDefaults:                           ; set, ADJUST 0 0, SCREEN 0, WIDTH 37, colours 15 4 4, KEY ON and
        db $0A, 0, 0, 0, 5, 2, 15, 4, 4, 3, 1, 0, 2     ; click, BEEP 1 2

; ScreenFromClock: SDFSCR (and SETSCR). The settings of the clock's memory (see CmosCheck) to the machine:
; WIDTH, the colours, KEY ON, the key click, the printer, the cassette's speed, the interlace and ADJUST,
; then their text mode (with the status line when KEY ON).
ScreenFromClock:
        push hl
        push de
        push bc
        call CmosCheck
        ld c,CmosSettings + 4           ; WIDTH
        call ReadClock
        ld e,a
        inc c
        call ReadClock
        rlca
        rlca
        rlca
        rlca
        or e
        ld e,a                          ; E = WIDTH
        ld c,CmosSettings + 3
        call ReadClock
        ld d,a                          ; D = mode + 2 * interlace
        ld a,e
        bit 0,d
        jr nz,.width32
        ld (LINL40),a
        jr .colours
.width32:
        ld (LINL32),a
.colours:
        ld hl,FORCLR
        ld c,CmosSettings + 6
        ld b,3
.colour:
        call ReadClock
        ld (hl),a
        inc hl
        inc c
        djnz .colour
        call ReadClock                  ; register 9: KEY ON, click, printer, 2400 baud
        ld e,a
        ld a,$00
        bit 0,e
        jr z,.keys
        dec a
.keys:
        ld (CNSDFG),a
        ld a,e
        rrca
        and $01
        ld (CLIKSW),a
        ld a,e
        rrca
        rrca
        and $01
        ld (NTSTDP),a
        ld a,e
        rrca
        rrca
        rrca
        and $01
        inc a
        push de
        call SelectBaud                 ; 1: 1200, 2: 2400
        pop de
        ld a,(RG9SAV)                   ; the interlace
        and $F7
        bit 1,d
        jr z,.interlace
        or $08
.interlace:
        ld b,a
        ld c,9
        call WriteVdpReg
        ld c,CmosSettings + 1           ; ADJUST
        call ReadClock
        ld b,a
        inc c
        call ReadClock
        rlca
        rlca
        rlca
        rlca
        or b
        ld b,a
        ld c,18
        call WriteVdpReg
        ld a,d
        and $01
        call ChangeMode                 ; the text mode (the status line comes with it)
        pop bc
        pop de
        pop hl
        ret

; PasswordPrompt: PROMPT. When the clock's memory has a password (block 3 says 1): "Password:" and a line
; typed (not shown) until its CRC-16 is the one kept; then the screen is cleared.
PasswordPrompt:
        ld c,CmosText
        call ReadClock
        cp $01
        ret nz
.ask:
        ld hl,PasswordText
.text:
        ld a,(hl)
        inc hl
        or a
        jr z,.typed
        call PutChar
        jr .text
.typed:
        ld hl,BUF                       ; the keys up to RETURN (BS takes one back)
        ld b,$00
.key:
        call GetKey
        cp $0D
        jr z,.check
        cp $08
        jr nz,.store
        ld a,b
        or a
        jr z,.key
        dec hl
        dec b
        jr .key
.store:
        ld c,a
        ld a,b
        inc a
        jr z,.key                       ; (255 at most)
        ld (hl),c
        inc hl
        inc b
        jr .key
.check:
        ld a,$0D
        call PutChar
        ld a,$0A
        call PutChar
        ld de,BUF
        call Crc16                      ; HL = the CRC of what was typed
        ld c,CmosText + 4
        ld b,4
.nibble:
        call ReadClock
        ld e,a
        ld a,l
        and $0F
        cp e
        jr nz,.ask
        push bc
        ld b,4
.shift:
        srl h
        rr l
        djnz .shift
        pop bc
        inc c
        djnz .nibble
        xor a                           ; (Z: CLS clears)
        jp ClearScreen
PasswordText:
        db "Password:", 0
