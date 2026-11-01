; driver.asm: the disk driver's entries (the standard's DSKIO, DSKCHG, GETDPB, CHOICE, DSKFMT, MTOFF) for
; the WD2793 interface (disk/diskvars.inc). The disks have 512-byte sectors, 8 or 9 a track, one or two
; sides, 40 or 80 cylinders: the media byte (F8h-FFh) tells which.

; the errors DSKIO and DSKCHG give (in A, with carry)
ErrWriteProtect equ 0
ErrNotReady     equ 2
ErrCrc          equ 4
ErrSeek         equ 6
ErrNotFound     equ 8
ErrWriteFault   equ 10
ErrOther        equ 12

; the controller's commands (stepping at the fastest rate)
CmdRestore      equ $03
CmdSeek         equ $13
CmdRead         equ $80
CmdWrite        equ $A0
CmdForceInt     equ $D0

; DiskIo: DSKIO. In: A = drive, B = sectors, C = media byte, DE = first sector, HL = the buffer,
; carry set to write. Out: carry and A = the error's code when it failed, B = the sectors not done (0 when all
; went well, as the original's). A buffer in page 1 is the RAM's there. Keeps the interrupts as they were.
DiskIo:
        push af
        ld a,0
        rla                             ; the carry: write
        ld (IoWrite),a
        pop af
        call PhysicalDrive
        jr nc,.drive
        ld b,0                          ; (no such drive)
        ret
.drive:
        ld (IoDrive),a
        ld (IoSector),de
        ld (IoBuffer),hl
        ld a,c
        ld (IoMedia),a
        ld a,b
        ld (IoCount),a
        xor a
        ld (IoDone),a
        ld a,i                          ; P/V = the interrupts were on
        push af
        di
        call .check
        call nc,TransferSectors
        ld e,a                          ; the result: E = A, D = the carry
        ld a,0
        rla
        ld d,a
        call DeselectDrive
        ld a,(IoCount)
        ld b,a
        pop af
        jp po,.noEi
        ei
.noEi:
        ld a,d
        rra                             ; the carry back
        ld a,e
        ret
.check:
        ld a,(IoMedia)
        cp $F8
        ret nc
.bad:
        ld a,ErrOther
        scf
        ret

; PhysicalDrive: the drive that holds the disk of drive A (0 A:, 1 B:). With one drive and two seen, both are
; drive 0: when the other one is asked for, the user is asked to change the disk. Out: A; carry and
; A = ErrOther for a drive that is not there. Keeps BC, DE, HL.
PhysicalDrive:
        push hl
        ld hl,LogDrives
        cp (hl)
        jr nc,.none
        ld h,a
        ld a,(PhysDrives)
        dec a
        ld a,h
        jr nz,.ok                       ; two drives: as it is
        ld hl,PhantomDrive
        cp (hl)
        jr z,.same
        ld (hl),a
        call AskForDisk
.same:
        xor a
.ok:
        or a
        pop hl
        ret
.none:
        pop hl
        ld a,ErrOther
        scf
        ret

; AskForDisk: "Put in the disk of drive X: / and press a key" (A = the drive), and a key waited for.
; Keeps BC, DE, HL.
AskForDisk:
        push bc
        push de
        push hl
        add a,'A'
        ld (DiskLetter),a
        ld hl,AskText
        call PrintText
        ld a,(DiskLetter)
        call PrintChar
        ld hl,AskText2
        call PrintText
        ld ix,KILBUF
        call CallBios
        ld ix,CHGET
        call CallBios
        ld hl,CrLfText
        call PrintText
        pop hl
        pop de
        pop bc
        ret
AskText:
        db 13, 10, "Put in the disk of drive ", 0
AskText2:
        db ":", 13, 10, "and press a key", 0
CrLfText:
        db 13, 10, 0

; PrintText: the text at HL (ended by 0) through the BIOS's CHPUT. PrintChar: A.
PrintText:
        ld a,(hl)
        or a
        ret z
        call PrintChar
        inc hl
        jr PrintText
PrintChar:
        push hl
        ld ix,CHPUT
        call CallBios
        pop hl
        ret

; CallBios: the main ROM's routine IX (whatever is in page 0: under the disk system it is RAM).
; Registers as CALSLT (AF, BC, DE, HL go and come back); interrupts as they were.
CallBios:
        push af
        ld a,i                          ; P/V = the interrupts were on
        jp pe,.on
        pop af
        ld iy,(EXPTBL - 1)
        jp CALSLT
.on:
        pop af
        ld iy,(EXPTBL - 1)
        call CALSLT
        ei
        ret

; TransferSectors: IoCount sectors from IoSector, at IoBuffer. Out: carry and A = the error's code.
TransferSectors:
        ld a,(IoCount)
        or a
        ret z
        call SectorPlace
        jr c,.error
        call PageOneBuffer
        jr c,.bounce
        ld hl,(IoBuffer)
        call SectorWithRetries
        jr c,.error
        jr .next
.bounce:
        ld a,(IoWrite)                  ; through the sector buffer, from / to page 1's RAM
        or a
        jr z,.bounceRead
        ld hl,(IoBuffer)
        ld de,(SecBufAddr)
        call CopyPageOne
        ld hl,(SecBufAddr)
        call SectorWithRetries
        jr c,.error
        jr .next
.bounceRead:
        ld hl,(SecBufAddr)
        call SectorWithRetries
        jr c,.error
        ld hl,(SecBufAddr)
        ld de,(IoBuffer)
        call CopyPageOne
.next:
        ld hl,(IoBuffer)
        inc h
        inc h                           ; + 512
        ld (IoBuffer),hl
        ld hl,(IoSector)
        inc hl
        ld (IoSector),hl
        ld hl,IoDone
        inc (hl)
        ld hl,IoCount
        dec (hl)
        jr TransferSectors
.error:
        scf
        ret

; PageOneBuffer: carry when the 512 bytes at IoBuffer touch page 1 (4000h-7FFFh).
PageOneBuffer:
        ld hl,(IoBuffer)
        ld a,h
        cp $80
        jr nc,.no                       ; from 8000h on
        ld de,$01FF
        add hl,de                       ; the last byte
        ld a,h
        cp $40
        ccf                             ; carry: it is at 4000h or more
        ret
.no:
        or a
        ret

; CopyPageOne: 512 bytes from HL to DE with the RAM in page 1 (ResRamLdir, in page 3).
CopyPageOne:
        ld bc,512
        jp ResRamLdir

; SectorPlace: the cylinder, side and sector (IoTrack, IoSide, IoRecord) of IoSector by the media byte.
; Carry and A = ErrNotFound when it is past the disk's end.
SectorPlace:
        ld a,(IoMedia)
        ld c,9                          ; bit 1 set: 8 sectors a track
        bit 1,a
        jr z,.perTrack
        dec c
.perTrack:
        ld hl,(IoSector)
        ld b,16
        xor a                           ; HL / C: HL = the track, A = the sector in it
.divide:
        add hl,hl
        rla
        cp c
        jr c,.noSub
        sub c
        inc l
.noSub:
        djnz .divide
        inc a
        ld (IoRecord),a
        ld a,(IoMedia)
        rra                             ; bit 0: two sides
        jr nc,.oneSide
        srl h
        rr l
        ld a,0
        rla                             ; the side: the track's lowest bit
        jr .side
.oneSide:
        xor a
.side:
        ld (IoSide),a
        ld a,h                          ; the cylinder must fit (40 or 80 cylinders: bit 2 of the media byte)
        or a
        jr nz,.past
        ld a,(IoMedia)
        and $04
        ld a,80
        jr z,.limit
        ld a,40
.limit:
        dec a
        cp l
        jr c,.past
        ld a,l
        ld (IoTrack),a
        or a
        ret
.past:
        ld a,ErrNotFound
        scf
        ret

; SectorWithRetries: the sector of IoTrack / IoSide / IoRecord read into, or written from, HL; tried again
; (the head brought back to track 0 halfway) when it fails. Out: carry and A = the error's code.
SectorWithRetries:
        ld a,6
        ld (IoTries),a
.try:
        push hl
        call SeekTrack
        jr c,.failed
        pop hl
        push hl
        call SectorCommand
        jr nc,.done
.failed:
        pop hl
        cp ErrWriteProtect              ; (no use trying again)
        jr z,.fail
        cp ErrNotReady
        jr z,.fail
        push hl
        ld hl,IoTries
        dec (hl)
        pop hl
        jr z,.fail
        ld a,(IoTries)
        cp 3
        call z,ForgetTrack              ; halfway: back to track 0
        jr .try
.done:
        pop hl
        ret
.fail:
        scf
        ret

; ForgetTrack: the drive's track unknown (the next seek starts with a restore).
ForgetTrack:
        ld a,(IoDrive)
        ld hl,DrvTracks
        add a,l
        ld l,a
        jr nc,.set
        inc h
.set:
        ld (hl),$FF
        ret

; SelectDrive: the drive IoDrive on (with its motor) and the side IoSide; the track register holds the
; drive's track. Out: HL = its place in DrvTracks.
SelectDrive:
        ld a,(IoSide)
        ld (FdcSide),a
        ld a,(IoDrive)
        or $80                          ; the motor
        ld (FdcDrive),a
        and $01
        ld hl,DrvTracks
        add a,l
        ld l,a
        jr nc,.place
        inc h
.place:
        ld a,(IoDrive)
        ld b,a
        ld a,(LastDrive)
        cp b
        ret z
        ld a,b
        ld (LastDrive),a
        ld a,(hl)
        ld (FdcTrack),a
        ret

; DeselectDrive: the drives' select and motor lines off (the motor stops; MTOFF does the same).
DeselectDrive:
        ld a,$03
        ld (FdcDrive),a
        ret

; SeekTrack: the head of IoDrive on IoTrack (a restore first when its track is not known). Out: carry and
; A = the error's code.
SeekTrack:
        call SelectDrive
        ld a,(hl)
        cp $FF
        jr nz,.known
        push hl
        ld a,CmdRestore
        call TypeOneCommand
        pop hl
        ret c
        ld a,(IoStatus)
        and $04                         ; track 0
        jr z,.seekError
        xor a
        ld (hl),a
.known:
        ld a,(IoTrack)
        cp (hl)
        ret z                           ; (no carry)
        ld (FdcData),a
        push hl
        ld a,CmdSeek
        call TypeOneCommand
        pop hl
        ret c
        ld a,(IoStatus)
        and $10                         ; seek error
        jr nz,.seekError
        ld a,(IoTrack)
        ld (hl),a
        ret
.seekError:
        ld (hl),$FF
        ld a,ErrSeek
        scf
        ret

; TypeOneCommand: a restore or a seek (A), waited for (about a second at most: a drive that is not there
; never ends a restore). Out: IoStatus; carry and A = ErrNotReady when it did not end.
TypeOneCommand:
        ld (FdcCommand),a
        ld bc,0
        ld e,1                          ; 65536 turns of the loop: about a second
.wait:
        ld a,(FdcLines)
        and $40                         ; the command ended (low)
        jr z,.ended
        dec bc
        ld a,b
        or c
        jr nz,.wait
        dec e
        jr nz,.wait
        ld a,CmdForceInt
        ld (FdcCommand),a
        ld a,ErrNotReady
        scf
        ret
.ended:
        ld a,(FdcStatus)
        ld (IoStatus),a
        or a
        ret

; SectorCommand: read the sector IoRecord into HL, or write it from HL (IoWrite). Out: carry and A = the
; error's code.
SectorCommand:
        ld a,(IoRecord)
        ld (FdcSector),a
        ld bc,FdcData
        ld de,512                       ; the bytes still to move
        ld a,(IoWrite)
        or a
        jr nz,.write
        ld a,CmdRead
        ld (FdcCommand),a
.readWait:
        ld a,(FdcLines)
        add a,a                         ; carry: no data request; sign: not ended
        jr nc,.readByte
        jp m,.readWait
        jr .ended
.readByte:
        ld a,(bc)
        ld (hl),a
        inc hl
        dec de
        jp .readWait
.write:
        ld a,CmdWrite
        ld (FdcCommand),a
.writeWait:
        ld a,(FdcLines)
        add a,a
        jr nc,.writeByte
        jp m,.writeWait
        jr .ended
.writeByte:
        ld a,(hl)
        ld (bc),a
        inc hl
        dec de
        jp .writeWait
.ended:
        ld a,(FdcStatus)
        ld (IoStatus),a
        ld c,ErrWriteProtect
        bit 6,a
        jr nz,.error
        ld c,ErrNotReady
        bit 7,a
        jr nz,.error
        ld c,ErrNotFound
        bit 4,a
        jr nz,.error
        ld c,ErrCrc
        bit 3,a
        jr nz,.error
        ld c,ErrOther
        bit 2,a                         ; lost data
        jr nz,.error
        ld a,d                          ; it ended before the sector was whole: no disk
        or e
        ld c,ErrNotReady
        jr nz,.error
        or a
        ret
.error:
        ld a,c
        scf
        ret

; DiskChange: DSKCHG. In: A = drive, B = 0, C = media byte, HL = the DPB's place. Out: B = 1 not
; changed, 0 unknown, FFh changed; carry and A = the error's code when it failed. The interface cannot
; tell a change: always "unknown", with the DPB made again from the media byte in the FAT's first byte.
DiskChange:
        push hl
        push af
        ld b,1                          ; the FAT's first sector (sector 1: the same place in every format)
        ld c,$F9
        ld de,1
        ld hl,(SecBufAddr)
        or a
        call DiskIo
        pop bc                          ; B = the drive
        pop hl
        ret c
        ld a,b
        ld de,(SecBufAddr)
        ld a,(de)
        ld b,a                          ; the media byte
        ld c,a
        push bc
        call GetDpb
        pop bc
        ret c
        ld a,c                          ; A = the media byte (as the original leaves it)
        ld b,0                          ; unknown
        ret

; GetDpb: GETDPB. In: A = drive, B = the first byte of the FAT, C = media byte, HL = the DPB's place.
; Out: HL + 1 ... the DPB of that media byte (F8h-FFh); carry and A = ErrOther for another one.
GetDpb:
        ld a,b
        sub $F8
        jr c,.bad
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl                       ; * 4
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl                       ; * 16
        add hl,de                       ; * 20
        ld de,DpbTable
        add hl,de
        pop de
        inc de
        ld bc,DpbSize
        ldir
        or a
        ret
.bad:
        ld a,ErrOther
        scf
        ret

; The drive parameter blocks: media byte, sector size, directory mask and shift, cluster mask and
; shift, first FAT sector, FATs, directory entries, first data sector, clusters + 1, sectors a FAT,
; first directory sector, the FAT's address (filled in by the kernel)
DpbSize         equ 20
        macro DPB media, spc, shift, fats, entries, fatsize, total
        db media
        dw 512
        db 15, 4
        db spc - 1, shift
        dw 1
        db fats
        db entries
        dw 1 + fats * fatsize + entries / 16
        dw (total - (1 + fats * fatsize + entries / 16)) / spc + 1
        db fatsize
        dw 1 + fats * fatsize
        dw 0
        endm
DpbTable:
        DPB $F8, 2, 2, 2, 112, 2, 720   ; 80 cylinders, 1 side, 9 sectors
        DPB $F9, 2, 2, 2, 112, 3, 1440  ; 80 cylinders, 2 sides, 9 sectors
        DPB $FA, 2, 2, 2, 112, 1, 640   ; 80 cylinders, 1 side, 8 sectors
        DPB $FB, 2, 2, 2, 112, 2, 1280  ; 80 cylinders, 2 sides, 8 sectors
        DPB $FC, 1, 1, 2, 64, 2, 360    ; 40 cylinders, 1 side, 9 sectors
        DPB $FD, 2, 2, 2, 112, 2, 720   ; 40 cylinders, 2 sides, 9 sectors
        DPB $FE, 1, 1, 2, 64, 1, 320    ; 40 cylinders, 1 side, 8 sectors
        DPB $FF, 2, 2, 2, 112, 1, 640   ; 40 cylinders, 2 sides, 8 sectors

; MotorOff: MTOFF. The motors of both drives off.
MotorOff:
        jp DeselectDrive
