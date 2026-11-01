; format.asm: formatting a disk. CHOICE and DSKFMT (the driver's entries), the interactive format that
; CALL FORMAT and the disk operating system's FORMAT (through 4025h) use, and the boot sector this ROM
; writes on the disks it formats (its own boot program: the disk operating system's system file is loaded
; from the disk and started, as the standard's boot sector does).
;
; The formats: 1 one side (360K: media F8h, 2 sectors of FAT), 2 two sides (720K: F9h, 3 sectors); 80
; tracks of 9 sectors of 512 bytes, 2 sectors a cluster, 112 entries in the root directory.

CmdWriteTrack   equ $F0

; Choice: CHOICE. Out: HL = the text that offers the formats (in this ROM).
Choice:
        ld hl,ChoiceText
        ret
ChoiceText:
        db "1 - Single Side", 13, 10, "2 - Double Side", 13, 10, 0

; DiskFormat: DSKFMT. In: A = the choice (1 or 2), D = the drive. Out: carry and A = the error's code
; when it failed. The tracks are written, then the boot sector, the FATs and the root directory.
DiskFormat:
        dec a
        cp 2
        jr nc,.bad
        ld (FmtTwoSides),a
        ld a,d
        ld (FmtDrive),a
        call PhysicalDrive
        ret c
        ld (IoDrive),a
        ld a,i                          ; P/V = the interrupts were on (they are off only while a track is
        ld a,0                          ; written: the keys typed meanwhile are kept)
        jp po,.off
        inc a
.off:
        ld (FmtInts),a
        call FormatTracks
        push af
        call DeselectDrive
        pop af
        ret c
        jp FormatSystemArea
.bad:
        ld a,ErrOther
        scf
        ret

; FormatTracks: every track of IoDrive (one or both sides) written as empty sectors (E5h).
FormatTracks:
        xor a
        ld (IoTrack),a
.track:
        xor a
        ld (IoSide),a
.side:
        call SeekTrack
        ret c
        di
        call WriteTrack
        push af
        ld a,(FmtInts)
        or a
        jr z,.off
        ei
.off:
        pop af
        ret c
        ld a,(FmtTwoSides)
        ld b,a
        ld a,(IoSide)
        cp b
        jr nc,.next
        inc a
        ld (IoSide),a
        jr .side
.next:
        ld a,(IoTrack)
        inc a
        ld (IoTrack),a
        cp 80
        jr c,.track
        or a
        ret

; WriteTrack: the track IoTrack, side IoSide, written (the controller's write track: the gaps, the ID
; fields of sectors 1-9 and their data fields). Out: carry and A = the error's code.
WriteTrack:
        ld a,CmdWriteTrack
        ld (FdcCommand),a
        ld hl,TrackStart
        call TrackRuns
        jr c,.ended
        ld c,1                          ; C = the sector
.sector:
        ld hl,IdStart
        call TrackRuns
        jr c,.ended
        ld a,(IoTrack)
        call TrackByte
        jr c,.ended
        ld a,(IoSide)
        call TrackByte
        jr c,.ended
        ld a,c
        call TrackByte
        jr c,.ended
        ld a,2                          ; 512 bytes
        call TrackByte
        jr c,.ended
        ld hl,SectorRest
        call TrackRuns
        jr c,.ended
        inc c
        ld a,c
        cp 10
        jr c,.sector
.gap:                                   ; the rest of the track: 4Eh until the controller ends
        ld a,(FdcLines)
        add a,a
        jr nc,.gapByte
        jp m,.gap
        jr .ended
.gapByte:
        ld a,$4E
        ld (FdcData),a
        jr .gap
.ended:
        ld a,(FdcStatus)
        ld c,ErrWriteProtect
        bit 6,a
        jr nz,.error
        ld c,ErrNotReady
        bit 7,a
        jr nz,.error
        ld c,ErrOther
        bit 2,a                         ; lost data
        jr nz,.error
        or a
        ret
.error:
        ld a,c
        scf
        ret

; TrackRuns: the runs at HL (a count, a byte; a count of 0 ends them) to the controller. Carry: it ended
; first. Destroys AF, B, E, HL.
TrackRuns:
        ld b,(hl)
        inc b
        dec b
        ret z
        inc hl
        ld e,(hl)
        inc hl
.byte:
        ld a,(FdcLines)
        add a,a
        jr nc,.put
        jp m,.byte
        scf
        ret
.put:
        ld a,e
        ld (FdcData),a
        djnz .byte
        jr TrackRuns

; TrackByte: A to the controller. Carry: it ended first. Keeps BC, DE, HL.
TrackByte:
        push af
.wait:
        ld a,(FdcLines)
        add a,a
        jr nc,.put
        jp m,.wait
        pop af
        scf
        ret
.put:
        pop af
        ld (FdcData),a
        or a
        ret

; (the write track's bytes: F5h writes the sync byte A1h, F6h C2h, F7h the CRC)
TrackStart:
        db 80, $4E, 12, $00, 3, $F6, 1, $FC, 50, $4E, 0
IdStart:
        db 12, $00, 3, $F5, 1, $FE, 0
SectorRest:
        db 1, $F7, 22, $4E, 12, $00, 3, $F5, 1, $FB
        db 128, $E5, 128, $E5, 128, $E5, 128, $E5
        db 1, $F7, 84, $4E, 0

; FormatSystemArea: sector 0 (the boot sector), the FATs and the root directory of the new disk (FmtDrive,
; FmtTwoSides). Out: carry and A = the error's code.
FormatSystemArea:
        ld a,$FF                        ; (the kernel's buffers: SecBuf is used here; FmtDrive's FAT and DPB
        ld (DirDrive),a                 ; are read again when it is next used)
        ld (FatDrive),a
        ld (DataDrive),a
        xor a
        ld (FatDirty),a
        ld (DataDirty),a
        ld hl,(SecBufAddr)              ; the boot sector
        call ZeroSector
        ld hl,BootImage
        ld de,(SecBufAddr)
        ld bc,BootImageLength
        ldir
        ld hl,(SecBufAddr)              ; the system file's name (kept in this ROM one up)
        ld de,BootName - BootImage
        add hl,de
        ld b,11
.name:
        dec (hl)
        inc hl
        djnz .name
        ld a,(FmtTwoSides)
        or a
        ld hl,BpbOneSide
        jr z,.bpb
        ld hl,BpbTwoSides
.bpb:
        ld de,(SecBufAddr)
        ld a,e
        add a,$0B
        ld e,a
        jr nc,.place
        inc d
.place:
        ld bc,BpbLength
        ldir
        ld de,0
        ld b,1
        call SystemSector
        ret c
        ld hl,(SecBufAddr)              ; the FATs, then the directory: zeros
        call ZeroSector
        ld a,(FmtTwoSides)              ; DE = the sectors from 1 up to the data, B = one FAT's sectors
        or a
        ld b,2
        ld c,1 + 2 * 2 + 7
        jr z,.sizes
        ld b,3
        ld c,1 + 2 * 3 + 7
.sizes:
        ld de,1
.sector:
        push bc
        ld hl,(SecBufAddr)              ; the first sector of each FAT starts with the media byte, FFh, FFh
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,e
        cp 1
        jr z,.fatStart
        sub b
        cp 1
        jr nz,.write
.fatStart:
        ld hl,(SecBufAddr)
        ld a,(FmtTwoSides)
        add a,$F8
        ld (hl),a
        inc hl
        ld (hl),$FF
        inc hl
        ld (hl),$FF
.write:
        push de
        ld b,1
        call SystemSector
        pop de
        pop bc
        ret c
        inc de
        ld a,e
        cp c
        jr c,.sector
        or a
        ret

; SystemSector: the sector DE of FmtDrive written from SecBuf (B = 1), the new media byte.
SystemSector:
        ld a,(FmtTwoSides)
        add a,$F8
        ld c,a
        ld a,(FmtDrive)
        ld hl,(SecBufAddr)
        scf
        jp DiskIo

; ZeroSector: 512 zeros at HL.
ZeroSector:
        ld b,0
.zero:
        ld (hl),0
        inc hl
        ld (hl),0
        inc hl
        djnz .zero
        ret

; the volume's parameters (from 0Bh of the boot sector)
BpbOneSide:
        dw 512                          ; bytes a sector
        db 2                            ; sectors a cluster
        dw 1                            ; reserved sectors (the boot sector)
        db 2                            ; FATs
        dw 112                          ; root directory entries
        dw 720                          ; sectors
        db $F8                          ; media
        dw 2                            ; sectors a FAT
        dw 9                            ; sectors a track
        dw 1                            ; sides
        dw 0                            ; hidden sectors
BpbLength       equ $ - BpbOneSide
BpbTwoSides:
        dw 512
        db 2
        dw 1
        db 2
        dw 112
        dw 1440
        db $F9
        dw 3
        dw 9
        dw 2
        dw 0

; --- the interactive format ---

; FormatDialog: asks for the drive (again, on a new line, until it is one there is) and the format (a key
; 1-9: one past those offered: "Bad parameter"), waits for a key, formats. The outcome is told on the screen
; ("Format complete" or what went wrong), as the original does: no error is given back.
FormatDialog:
        ld hl,DriveText
        call PrintText
        ld a,(LogDrives)
        dec a
        ld hl,OneDriveText
        jr z,.drives
        ld hl,TwoDrivesText
.drives:
        call PrintText
        call WaitBiosKey
        call UpperA
        push af
        call PrintChar
        call PrintCrLf
        pop af
        sub 'A'
        jr c,FormatDialog
        ld hl,LogDrives
        cp (hl)
        jr nc,FormatDialog
        ld (FmtDrive),a
        call Choice
        call PrintText
        ld hl,ChoiceAskText
        call PrintText
.choiceKey:
        call WaitBiosKey
        cp '1'
        jr c,.choiceKey
        cp '9' + 1
        jr nc,.choiceKey
        push af
        call PrintChar
        call PrintCrLf
        ld hl,StrikeText
        call PrintText
        call WaitBiosKey
        call PrintCrLf
        pop af
        sub '0'
        ld hl,BadParamText
        cp 3
        jr nc,.told
        push af
        ld a,(FatDirty)                 ; what the kernel has not written yet, written first
        ld hl,DataDirty
        or (hl)
        call nz,FlushAll
        pop af
        ld hl,FmtDrive
        ld d,(hl)
        call DiskFormat
        ld hl,CompleteText
        jr nc,.told
        and $FE
        ld hl,ProtectedText
        jr z,.told
        cp ErrNotReady
        ld hl,NotReadyText
        jr z,.told
        ld hl,FailedText
.told:
        call PrintText
        or a
        ret

; WaitBiosKey: A = the next key (CHGET).
WaitBiosKey:
        push hl
        ld ix,CHGET
        call CallBios
        pop hl
        ret

; PrintCrLf: a new line on the screen.
PrintCrLf:
        ld a,13
        call PrintChar
        ld a,10
        jp PrintChar

DriveText:
        db "Drive name? ", 0
OneDriveText:
        db "(A) ", 0
TwoDrivesText:
        db "(A,B) ", 0
ChoiceAskText:
        db "? ", 0
StrikeText:
        db "Strike a key when ready", 0
CompleteText:
        db "Format complete", 13, 10, 0
BadParamText:
        db "Bad parameter", 13, 10, 0
ProtectedText:
        db "Write protected", 13, 10, 0
NotReadyText:
        db "Not ready", 13, 10, 0
FailedText:
        db "Disk error", 13, 10, 0

; DosFormat (4025h): the disk operating system's FORMAT (HL, BC: a work area it offers: not needed).
DosFormat:
        jp FormatDialog

; FormatStatement: CALL FORMAT (BASIC): the dialog; then the end of the statement.
FormatStatement:
        push hl
        call FormatDialog
        pop hl
        or a
        ret

; --- the boot sector ---

; BootImage: the first bytes of the boot sector of a disk this ROM formats (the rest: zeros). It starts
; with a jump (the boot program is there), the volume's parameters go at 0Bh, the boot program at 1Eh
; (C01Eh when it runs). The program: with the carry clear, nothing; with it set (RAM in page 0, the BDOS
; ready) the system file is opened, loaded at 0100h and started there. With no system file, back to BASIC
; (4022h) on the first try; a disk error then: a message, a key, and it tries again.
BootImage:
        db $EB, $FE, $90                ; (JR $: a jump: there is a boot program)
        db "QUANTIKA"
        ds $1E - ($ - BootImage), 0
        disp $C01E
BsStart:
        ret nc
        ld (BsEnableRom + 1),de         ; (DE: F368h, this ROM back in page 1 for the error handler)
        ld (BsTries),a                  ; (A: 0 at a boot)
        ld (hl),low BsHandlerPtr        ; (HL: DISKVE) the disk errors here
        inc hl
        ld (hl),high BsHandlerPtr
BsLoad:
        ld sp,$C400
        ld de,BsFcb
        ld c,$0F                        ; open
        call $F37D
        inc a
        jr z,BsFailed
        ld de,$0100                     ; the DTA
        ld c,$1A
        call $F37D
        ld hl,1                         ; records of one byte
        ld (BsFcb + 14),hl
        ld hl,$3F00
        ld de,BsFcb
        ld c,$27                        ; random block read
        call $F37D
        jp $0100
BsFailed:
        ld a,(BsTries)
        or a
        jp z,$4022                      ; BASIC
BsMessage:
        ld de,BsText
        ld c,$09
        call $F37D
        ld c,$08                        ; a key
        call $F37D
        ld a,1
        ld (BsTries),a
        jr BsLoad
BsHandlerPtr:
        dw BsHandler
BsHandler:                              ; C = the error's code
BsEnableRom:
        call $0000
        ld a,c
        and $FE
        cp 2                            ; not ready on the first try: BASIC
        jr nz,BsMessage
        jr BsFailed
BsTries:
        db 0
BsText:
        db "Cannot boot from this disk", 13, 10, "Strike a key to try again", 13, 10, "$"
BsFcb:
        db 0
        ent
BootName:
        db "N" + 0, "T", "Y", "E", "P", "T", "!", "!", "T", "Z", "T"  ; the system file's name, one up
        ds 25, 0                        ; (the rest of the FCB)
BootImageLength equ $ - BootImage
        assert BootImageLength <= 512, "the boot sector's image is too long"
