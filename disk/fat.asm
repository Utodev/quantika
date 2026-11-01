; fat.asm: the kernel's view of a disk: the drive's DPB, its FAT in a buffer, the root directory one sector
; at a time (in SecBuf) and the data one sector at a time (in the data buffer). Disk errors go to DiskError
; (disk/kernel.asm), which may never come back (the function is abandoned).

; --- the disk's sectors, with the disk error handling ---

; ReadSectors / WriteSectors: B sectors from DE of the drive KDrive (its media byte from its DPB), at HL.
; Keeps BC, DE, HL. A disk error that is retried is tried again; ignored, it is as if it went well.
ReadSectors:
        or a
        jr DiskSectors
WriteSectors:
        scf
DiskSectors:
        push bc
        push de
        push hl
        push af                         ; (the carry: write)
.again:
        pop af
        push af
        push bc
        push de
        push hl
        ld a,(KDrive)
        ld c,a
        ld iy,(KDpb)
        ld a,c
        ld c,(iy + DpbMedia)
        call DiskIo
        pop hl
        pop de
        pop bc
        jr nc,.done
        ld c,a                          ; the error's code
        pop af
        push af
        ld a,0
        rla
        or c                            ; bit 0: it was a write
        ld c,a
        call DiskError                  ; C: 0 ignore, 1 retry (abort never comes back)
        dec c
        jr z,.again
.done:
        pop af
        pop hl
        pop de
        pop bc
        or a
        ret

; --- the drive ---

; SelectKDrive: KDrive = A (0-based; FFh the default) and KDpb its DPB. Carry when there is no such drive.
; Keeps BC, DE, HL.
SelectKDrive:
        cp $FF
        jr nz,.given
        ld a,(CurDrive)
.given:
        push hl
        ld hl,LogDrives
        cp (hl)
        pop hl
        ccf
        ret c
        ld (KDrive),a
        push hl
        push de
        ld hl,DpbArea + 1
        or a
        jr z,.first
        ld hl,DpbArea + 21 + 1
.first:
        ld (KDpb),hl
        pop de
        pop hl
        or a
        ret

; LoginDrive: the disk in KDrive looked at again (it may have been changed): the buffers written, its DPB
; made from the media byte and its FAT read. Out: carry when the media byte is not one this kernel knows.
LoginDrive:
        call FlushAll
        ld a,$FF
        ld (DirDrive),a                 ; (DSKCHG reads into SecBuf)
        ld a,(DataDrive)
        ld hl,KDrive
        cp (hl)
        jr nz,.data
        ld a,$FF
        ld (DataDrive),a
.data:
        ld a,(KDrive)
        ld (FatDrive),a                 ; (until it is read)
        ld hl,(KDpb)
        dec hl                          ; the DPB's place
        ld (hl),a                       ; its drive
.change:
        ld a,(KDrive)
        ld b,0
        ld c,$F9
        push hl
        call DiskChange
        pop hl
        jr nc,.read
        ld c,a
        call DiskError
        dec c
        jr z,.change
        ld a,$FF                        ; ignored: no FAT
        ld (FatDrive),a
        scf
        ret
.read:
        ld iy,(KDpb)
        ld hl,(FatBufAddr)
        ld (iy + DpbFatAddr),l
        ld (iy + DpbFatAddr + 1),h
        ld a,(iy + DpbFatSize)
        ld b,a
        ld e,(iy + DpbFirstFat)
        ld d,(iy + DpbFirstFat + 1)
        call ReadSectors
        xor a
        ld (FatDirty),a
        ret

; EnsureFat: the FAT of KDrive in the buffer (logged in when another drive's is there).
EnsureFat:
        ld a,(FatDrive)
        ld hl,KDrive
        cp (hl)
        ret z
        jp LoginDrive

; FlushAll: the data buffer and the FAT written if they were changed.
FlushAll:
        call FlushData
        jp FlushFat

; FlushFat: the FAT (every copy) written when it was changed. Keeps KDrive, BC, DE, HL.
FlushFat:
        ld a,(FatDirty)
        or a
        ret z
        push bc
        push de
        push hl
        xor a
        ld (FatDirty),a
        ld a,(KDrive)
        push af
        ld hl,(KDpb)
        push hl
        ld a,(FatDrive)
        call SelectKDrive
        ld iy,(KDpb)
        ld e,(iy + DpbFirstFat)
        ld d,(iy + DpbFirstFat + 1)
        ld c,(iy + DpbFats)
.copy:
        ld b,(iy + DpbFatSize)
        ld hl,(FatBufAddr)
        call WriteSectors
        ld a,(iy + DpbFatSize)
        add a,e
        ld e,a
        jr nc,.next
        inc d
.next:
        dec c
        jr nz,.copy
        pop hl
        ld (KDpb),hl
        pop af
        ld (KDrive),a
        pop hl
        pop de
        pop bc
        ret

; --- the FAT (12-bit entries) ---

; FatEntryPlace: HL = the cluster -> HL = its entry's first byte in the buffer, carry when the cluster is odd.
; Destroys DE.
FatEntryPlace:
        ld d,h
        ld e,l
        srl h
        rr l                            ; cluster / 2, carry: odd
        push af
        add hl,de                       ; * 3 / 2
        ld de,(FatBufAddr)
        add hl,de
        pop af
        ret

; FatGet: HL = the FAT's entry of cluster HL. Destroys AF, DE.
FatGet:
        call FatEntryPlace
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jr nc,.even
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ret
.even:
        ld a,h
        and $0F
        ld h,a
        ret

; FatSet: the FAT's entry of cluster HL = DE. Destroys AF, BC, HL.
FatSet:
        push de
        call FatEntryPlace
        pop de
        jr nc,.even
        ld a,e                          ; odd: the high nibble of the first byte, then the second byte
        rlca
        rlca
        rlca
        rlca
        ld c,a
        and $F0
        ld b,a
        ld a,(hl)
        and $0F
        or b
        ld (hl),a
        inc hl
        ld a,c
        and $0F
        ld b,a
        ld a,d
        rlca
        rlca
        rlca
        rlca
        and $F0
        or b
        ld (hl),a
        jr .dirty
.even:
        ld (hl),e
        inc hl
        ld a,(hl)
        and $F0
        ld b,a
        ld a,d
        and $0F
        or b
        ld (hl),a
.dirty:
        ld a,1
        ld (FatDirty),a
        ret

; IsLastCluster: carry when HL is not a cluster of the file (the end of the chain, FF8h-FFFh, or 0 / 1).
; Keeps BC, DE, HL.
IsLastCluster:
        ld a,h
        or a
        jr nz,.high
        ld a,l
        cp 2
        ret                             ; carry for 0 and 1
.high:
        cp $0F
        ccf
        ret nc                          ; (under F00h)
        ld a,l
        cp $F8
        ccf
        ret

; FreeChain: the clusters from HL on marked free (to the end of the chain).
FreeChain:
        call IsLastCluster
        ret c
        push hl
        call FatGet
        ex (sp),hl                      ; HL = this one, the next on the stack
        ld de,0
        call FatSet
        pop hl
        jr FreeChain

; FindFreeCluster: HL = the first free cluster. Carry when there is none (the disk is full). Destroys AF, DE.
FindFreeCluster:
        ld hl,2
.try:
        ld iy,(KDpb)
        ld e,(iy + DpbMaxClus)
        ld d,(iy + DpbMaxClus + 1)
        inc de                          ; (clusters 2 ... MaxClus)
        ld a,l
        sub e
        ld a,h
        sbc a,d
        ccf
        ret c                           ; past the last one
        push hl
        call FatGet
        ld a,h
        or l
        pop hl
        ret z
        inc hl
        jr .try

; CountFreeClusters: HL = the free clusters. Destroys AF, BC, DE.
CountFreeClusters:
        ld bc,0
        ld hl,2
.count:
        ld iy,(KDpb)
        ld e,(iy + DpbMaxClus)
        ld d,(iy + DpbMaxClus + 1)
        inc de
        ld a,l
        sub e
        ld a,h
        sbc a,d
        jr nc,.done
        push hl
        call FatGet
        ld a,h
        or l
        pop hl
        jr nz,.used
        inc bc
.used:
        inc hl
        jr .count
.done:
        ld h,b
        ld l,c
        ret

; ClusterSector: DE = the first sector of cluster HL. Destroys AF, HL.
ClusterSector:
        dec hl
        dec hl
        ld iy,(KDpb)
        ld a,(iy + DpbClusShift)
.shift:
        dec a
        jr z,.shifted
        add hl,hl
        jr .shift
.shifted:
        ld e,(iy + DpbFirstData)
        ld d,(iy + DpbFirstData + 1)
        add hl,de
        ex de,hl
        ret

; --- the root directory (a sector at a time in SecBuf) ---

; DirEntry: HL = directory entry A of KDrive (its sector read into SecBuf when it is not there).
; Destroys AF, BC, DE.
DirEntry:
        ld (DirIndex),a
        push af
        rrca
        rrca
        rrca
        rrca
        and $0F                         ; the sector: entry / 16
        ld iy,(KDpb)
        add a,(iy + DpbFirstDir)
        ld e,a
        ld a,0
        adc a,(iy + DpbFirstDir + 1)
        ld d,a
        ld a,(DirDrive)
        ld hl,KDrive
        cp (hl)
        jr nz,.read
        ld hl,(DirSector)
        or a
        sbc hl,de
        jr z,.there
.read:
        call FlushData                  ; (a sector of the same disk may be waiting)
        ld hl,(SecBufAddr)
        ld b,1
        call ReadSectors
        ld (DirSector),de
        ld a,(KDrive)
        ld (DirDrive),a
.there:
        pop af
        and $0F
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                       ; * 32
        ld de,(SecBufAddr)
        add hl,de
        ret

; WriteDirSector: the directory sector in SecBuf written back.
WriteDirSector:
        ld de,(DirSector)
        ld hl,(SecBufAddr)
        ld b,1
        jp WriteSectors

; FindEntry: from entry A on, the first one that matches Pattern ('?' any character; not the volume's
; name, not a deleted one). Out: HL = it, A = its number (DirIndex); carry when there is none.
FindEntry:
        ld iy,(KDpb)
        cp (iy + DpbEntries)
        ccf
        ret c
        push af
        call DirEntry
        pop bc                          ; B = the number
        ld a,(hl)
        or a
        scf
        ret z                           ; the end of the directory
        cp $E5
        jr z,.next
        push hl
        ld de,11
        add hl,de
        bit 3,(hl)                      ; the volume's name
        pop hl
        jr nz,.next
        push hl
        ld de,Pattern
        ld c,11
.compare:
        ld a,(de)
        cp '?'
        jr z,.same
        cp (hl)
        jr nz,.differs
.same:
        inc hl
        inc de
        dec c
        jr nz,.compare
        pop hl
        ld a,b
        or a
        ret
.differs:
        pop hl
.next:
        ld a,b
        inc a
        jr FindEntry

; FindFreeEntry: HL = the first free directory entry (never used or deleted), A = its number. Carry when
; the directory is full.
FindFreeEntry:
        xor a
.try:
        ld iy,(KDpb)
        cp (iy + DpbEntries)
        ccf
        ret c
        push af
        call DirEntry
        pop bc
        ld a,(hl)
        or a
        jr z,.free
        cp $E5
        jr z,.free
        ld a,b
        inc a
        jr .try
.free:
        ld a,b
        or a
        ret

; --- the data (a sector at a time in the data buffer) ---

; DataSectorIn: HL = the data buffer with sector DE of KDrive in it (the one there written first when it
; was changed). With carry set, the sector is not read (it is going to be written whole). Destroys AF, BC.
DataSectorIn:
        push af
        ld a,(DataDrive)
        ld hl,KDrive
        cp (hl)
        jr nz,.other
        ld hl,(DataSector)
        or a
        sbc hl,de
        jr nz,.other
        pop af
        ld hl,(DataBufAddr)
        ret
.other:
        call FlushData
        ld a,(DirDrive)                 ; the directory sector in SecBuf may be this one: forget it
        ld hl,KDrive
        cp (hl)
        jr nz,.notDir
        ld hl,(DirSector)
        or a
        sbc hl,de
        jr nz,.notDir
        ld a,$FF
        ld (DirDrive),a
.notDir:
        pop af
        ld hl,(DataBufAddr)
        jr c,.noRead
        ld b,1
        call ReadSectors
.noRead:
        ld (DataSector),de
        ld a,(KDrive)
        ld (DataDrive),a
        ret

; FlushData: the data buffer written when it was changed. Keeps BC, DE, HL.
FlushData:
        ld a,(DataDirty)
        or a
        ret z
        push bc
        push de
        push hl
        xor a
        ld (DataDirty),a
        ld a,(KDrive)
        push af
        ld hl,(KDpb)
        push hl
        ld a,(DataDrive)
        call SelectKDrive
        ld de,(DataSector)
        ld hl,(DataBufAddr)
        ld b,1
        call WriteSectors
        pop hl
        ld (KDpb),hl
        pop af
        ld (KDrive),a
        pop hl
        pop de
        pop bc
        ret
