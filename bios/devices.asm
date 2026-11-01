; devices.asm: the printer (LPTOUT, LPTSTT, OUTDLP), the BASIC break checks for machine code (ISCNTC,
; CKCNTC), ISFLIO, the voice buffers' addresses (GETVCP, GETVC2), and the disk entries that only call their
; hooks (PHYDIO, FORMAT: a disk ROM takes them).

; PrinterOut: LPTOUT. A to the printer, once it is ready. Carry when CTRL+STOP gave up waiting. Destroys F.
PrinterOut:
        call H_LPTO
        push af
.wait:
        call CheckCtrlStop
        jr c,.stopped
        call PrinterStatusTest
        jr z,.wait
        pop af
        out (PrinterData),a
        push af
        xor a                           ; the strobe
        out (PrinterStatus),a
        inc a
        out (PrinterStatus),a
        pop af
        or a
        ret
.stopped:
        pop af
        scf
        ret

; PrinterStatusTest: LPTSTT. A = FFh and NZ when the printer is ready, A = 0 and Z when it is not.
PrinterStatusTest:
        call H_LPTS
        in a,(PrinterStatus)
        and $02                         ; busy?
        jr nz,.busy
        dec a                           ; A = FFh, NZ
        ret
.busy:
        xor a                           ; A = 0, Z
        ret

; PrinterOutFormatted: OUTDLP. A to the printer as BASIC prints: a tab is spaces to the next column of 8,
; LPTPOS counts the columns (CR: 0). Carry when it gave up (CTRL+STOP). Keeps AF.
PrinterOutFormatted:
        push af
        cp $09
        jr nz,.notTab
.space:
        ld a,' '
        call PrinterOutFormatted
        jr c,.done
        ld a,(LPTPOS)
        and $07
        jr nz,.space
        jr .done
.notTab:
        call PrinterOut
        jr c,.done
        cp $0D
        jr nz,.notReturn
        xor a
        ld (LPTPOS),a
        jr .done
.notReturn:
        cp ' '
        jr c,.done
        ld a,(LPTPOS)
        inc a
        ld (LPTPOS),a
        or a
.done:
        pop bc                          ; (the carry stays: A comes back as it was)
        ld a,b
        ret

; CheckStopBasic / CheckStopBasic2: ISCNTC / CKCNTC. In BASIC: STOP waits until it is pressed again,
; CTRL+STOP breaks the program (as between statements). Destroys AF.
CheckStopBasic:
CheckStopBasic2:
        ld a,(INTFLG)
        or a
        ret z
        jp CheckBreak

; IsFileIO: ISFLIO. NZ when BASIC's output goes to a file now (PTRFIL), Z when it does not. Destroys AF.
IsFileIO:
        call H_ISFL
        push hl
        ld hl,(PTRFIL)
        ld a,h
        or l
        pop hl
        ret

; VoiceBufferAddr: GETVCP. A = voice (0-2): HL = its voice buffer + 2. Destroys AF.
VoiceBufferAddr:
        ld l,$02
        jr VoiceOffset
; VoiceBufferAddr2: GETVC2. L = offset: HL = the voice buffer of VOICEN + L. Destroys AF.
VoiceBufferAddr2:
        ld a,(VOICEN)
VoiceOffset:
        push de
        ld e,l
        ld d,$00
        ld hl,VCBA
        push de
        ld de,VCBB - VCBA
.voice:
        or a
        jr z,.found
        add hl,de
        dec a
        jr .voice
.found:
        pop de
        add hl,de
        pop de
        ret

; PhysicalDiskIO / FormatDisk: PHYDIO / FORMAT: only their hooks (a disk ROM takes them; without one,
; nothing).
PhysicalDiskIO:
        jp H_PHYD
FormatDisk:
        jp H_FORM
