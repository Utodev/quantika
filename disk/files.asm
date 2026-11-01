; files.asm: the kernel's file functions on FCBs (disk/kernel.asm's table). The caller's FCB is copied into
; KFcb (IX points to it) and back at the end; the files are in the root directory.

; FcbIn: KFcb = the caller's FCB at DE; IX = KFcb; KDrive / KDpb = its drive. Carry when the drive is not
; there.
FcbIn:
        ld (KFcbAddr),de
        ex de,hl
        ld de,KFcb
        ld bc,FcbSize
        call CopyFromUser
        ld ix,KFcb
        ld a,(ix + FcbDrive)
        and $7F                         ; (bit 7 is not looked at: the command interpreter's DIR sets it)
        dec a                           ; (0 -> FFh: the default)
        jp SelectKDrive

; FcbOut: the caller's FCB = KFcb.
FcbOut:
        ld hl,KFcb
        ld de,(KFcbAddr)
        ld bc,FcbSize
        jp CopyToUser

; PatternFromFcb: Pattern = the FCB's name and extension (IX). Keeps IX.
PatternFromFcb:
        push ix
        pop hl
        inc hl
        ld de,Pattern
        ld bc,11
        ldir
        ret

; FillFcbFromEntry: the FCB (IX) from the directory entry HL (A = its number): the size, the date, the
; time, the first cluster, opened (the flags), the cluster cache at the start, the record size 128.
FillFcbFromEntry:
        ld (ix + FcbEntry),a
        push hl
        pop iy
        ld a,(iy + 28)
        ld (ix + FcbSize_),a
        ld a,(iy + 29)
        ld (ix + FcbSize_ + 1),a
        ld a,(iy + 30)
        ld (ix + FcbSize_ + 2),a
        ld a,(iy + 31)
        ld (ix + FcbSize_ + 3),a
        ld a,(iy + 24)
        ld (ix + FcbDate),a
        ld a,(iy + 25)
        ld (ix + FcbDate + 1),a
        ld a,(iy + 22)
        ld (ix + FcbTime),a
        ld a,(iy + 23)
        ld (ix + FcbTime + 1),a
        ld a,(iy + 26)
        ld (ix + FcbFirst),a
        ld a,(iy + 27)
        ld (ix + FcbFirst + 1),a
OpenedFcb:
        ld a,(KDrive)
        or $40
        ld (ix + FcbFlags),a
        xor a
        ld (ix + FcbRelCl),a
        ld (ix + FcbRelCl + 1),a
        ld a,(ix + FcbFirst)
        ld (ix + FcbAbsCl),a
        ld a,(ix + FcbFirst + 1)
        ld (ix + FcbAbsCl + 1),a
        ld (ix + FcbRecSize),128
        ld (ix + FcbRecSize + 1),0
        ret

; FcbResult: KFcb back to the caller, A = the result (FFh: the drive is not there, and nothing else).
FcbResultFF:
        ld a,$FF
.ret:
        jp ResultA
FcbResult:
        push af
        call FcbOut
        pop af
        jp ResultA

; --- 0Fh: open ---
FcbOpen:
        call FcbIn
        jr c,FcbResultFF
        call IsDevice
        jp nc,OpenDevice
        call LoginDrive
        jr c,FcbResultFF
        call PatternFromFcb
        xor a
        call FindEntry
        jr c,.none
        call FillFcbFromEntry
        xor a
        ld (ix + FcbBlock),a
        ld (ix + FcbBlock + 1),a
        ld (ix + FcbRecord),a
        jr FcbResult
.none:
        ld a,$FF
        jr FcbResult

; --- 16h: create (an old file of that name is emptied) ---
FcbCreate:
        call FcbIn
        jr c,FcbResultFF
        call IsDevice
        jp nc,OpenDevice
        call LoginDrive
        jr c,FcbResultFF
        call PatternFromFcb
        xor a
        call FindEntry
        jr nc,.old
        call FindFreeEntry
        jr c,.full
        push hl                         ; a new entry: the name, attributes 0, the rest 0
        push af
        ld d,h
        ld e,l
        push ix
        pop hl
        inc hl
        ld bc,11
        ldir
        ex de,hl
        ld b,21
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        pop af
        pop hl
        jr .stamp
.old:
        push hl                         ; an old one: its clusters freed, its size 0
        push af
        ld de,26
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call FreeChain
        pop af
        pop hl
        push hl
        push af
        ld de,26
        add hl,de
        ld b,6
.empty:
        ld (hl),0
        inc hl
        djnz .empty
        pop af
        pop hl
.stamp:
        push af
        push hl
        call DirDateTime
        ex (sp),hl                      ; HL = the entry, the time on the stack
        push hl
        pop iy
        pop hl
        ld (iy + 22),l
        ld (iy + 23),h
        ld (iy + 24),e
        ld (iy + 25),d
        push iy
        call WriteDirSector
        call FlushFat
        pop hl
        pop af
        call FillFcbFromEntry
        xor a
        ld (ix + FcbBlock),a
        ld (ix + FcbBlock + 1),a
        ld (ix + FcbRecord),a
        jp FcbResult
.full:
        ld a,$FF
        jp FcbResult

; --- 10h: close (the directory entry brought up to date when the file was written) ---
FcbClose:
        call FcbIn
        jp c,FcbResultFF
        ld a,(ix + FcbFlags)
        and $C0
        cp $40
        jr c,.notOpen
        bit 5,(ix + FcbFlags)
        jr nz,.done                     ; a device: nothing to do
        bit 7,(ix + FcbFlags)
        jr z,.done                      ; not written: nothing to do
        call EnsureFat
        call FlushData
        call TrimChain
        ld a,(ix + FcbEntry)
        call DirEntry
        push hl
        pop iy
        ld a,(ix + FcbSize_)
        ld (iy + 28),a
        ld a,(ix + FcbSize_ + 1)
        ld (iy + 29),a
        ld a,(ix + FcbSize_ + 2)
        ld (iy + 30),a
        ld a,(ix + FcbSize_ + 3)
        ld (iy + 31),a
        ld a,(ix + FcbFirst)
        ld (iy + 26),a
        ld a,(ix + FcbFirst + 1)
        ld (iy + 27),a
        push iy
        call DirDateTime
        pop iy
        ld (iy + 22),l
        ld (iy + 23),h
        ld (iy + 24),e
        ld (iy + 25),d
        ld (ix + FcbTime),l
        ld (ix + FcbTime + 1),h
        ld (ix + FcbDate),e
        ld (ix + FcbDate + 1),d
        call WriteDirSector
        call FlushFat
        res 7,(ix + FcbFlags)
.done:
        xor a
        jp FcbResult
.notOpen:
        ld a,$FF
        jp FcbResult

; TrimChain: the chain of the file (IX) cut to what its size needs: the clusters past it freed (a block
; write of no records makes a file shorter). The cluster cache back at the start.
TrimChain:
        ld iy,(KDpb)
        ld l,(iy + DpbClusMask)         ; the bytes of a cluster - 1: (the mask + 1) * 512 - 1
        inc l
        ld a,l
        add a,a
        dec a
        ld h,a
        ld l,$FF
        ld e,(ix + FcbSize_)            ; + the size: D:E:H:L
        ld d,(ix + FcbSize_ + 1)
        add hl,de
        ex de,hl                        ; (DE = the low word)
        ld l,(ix + FcbSize_ + 2)
        ld h,(ix + FcbSize_ + 3)
        jr nc,.noCarry
        inc hl
.noCarry:
        ld a,l                          ; A:H:L = the sum / 256
        ld l,d
        ld h,a
        ld a,(ix + FcbSize_ + 3)
        ld b,(iy + DpbClusShift)        ; / 2 (to 512), then by the sectors of a cluster
.shift:
        srl a
        rr h
        rr l
        djnz .shift
        ld (KCluster),hl                ; the clusters the file needs
        xor a
        ld (ix + FcbRelCl),a
        ld (ix + FcbRelCl + 1),a
        ld a,(ix + FcbFirst)
        ld (ix + FcbAbsCl),a
        ld a,(ix + FcbFirst + 1)
        ld (ix + FcbAbsCl + 1),a
        ld a,h
        or l
        jr nz,.walk
        ld l,(ix + FcbFirst)            ; none: all of them freed
        ld h,(ix + FcbFirst + 1)
        call FreeChain
        xor a
        ld (ix + FcbFirst),a
        ld (ix + FcbFirst + 1),a
        ld (ix + FcbAbsCl),a
        ld (ix + FcbAbsCl + 1),a
        ret
.walk:
        ld bc,(KCluster)
        ld l,(ix + FcbFirst)
        ld h,(ix + FcbFirst + 1)
.next:
        dec bc
        ld a,b
        or c
        jr z,.last
        push bc
        call FatGet
        pop bc
        call IsLastCluster
        ret c                           ; (the chain is shorter: nothing to cut)
        jr .next
.last:
        push hl
        call FatGet                     ; HL = the one after the last
        call IsLastCluster
        pop de
        ret c                           ; the chain ends there
        push hl
        ex de,hl
        ld de,$0FFF
        call FatSet
        pop hl
        jp FreeChain

; --- 11h / 12h: search: the entry found goes to the DTA, after the drive's number (1 A:) ---
SearchFirst:
        call FcbIn
        jp c,FcbResultFF
        call IsDevice
        call nc,NoWildcards
        jp nc,SearchDevice
        call LoginDrive
        jp c,FcbResultFF
        call PatternFromFcb
        ld a,(KDrive)
        ld (SearchDrive),a
        xor a
        jr Search
SearchNext:
        ld a,(SearchDrive)
        call SelectKDrive
        jp c,FcbResultFF.ret
        call EnsureFat
        ld a,(SearchIndex)
Search:
        call FindEntry
        jr c,.none
        push hl
        inc a
        ld (SearchIndex),a
        ld a,(KDrive)                   ; the DTA: the drive's number (1 A:), then the entry
        inc a
        ld (KTemp),a
        ld hl,KTemp
        ld de,(DtaAddr)
        ld bc,1
        call CopyToUser
        pop hl
        push hl
        ld de,(DtaAddr)
        inc de
        ld bc,32
        call CopyToUser
        pop iy                          ; bytes 12-15 as an FCB has them: 0, the attributes, 0, the records
        xor a                           ; of 128 bytes the file takes (80h at most)
        ld (KTemp),a
        ld (KTemp + 2),a
        ld a,(iy + 11)
        ld (KTemp + 1),a
        ld l,(iy + 28)
        ld h,(iy + 29)
        ld de,127
        add hl,de
        ld a,(iy + 30)
        adc a,(iy + 31)                 ; (any of the high bytes: more than 80h)
        jr nz,.many
        jr c,.many
        add hl,hl                       ; (size + 127) / 128 in H
        jr c,.many
        ld a,h
        cp $81
        jr c,.records
.many:
        ld a,$80
.records:
        ld (KTemp + 3),a
        ld hl,KTemp
        ld de,(DtaAddr)
        ld bc,12
        ex de,hl
        add hl,bc
        ex de,hl
        ld bc,4
        call CopyToUser
        xor a
        jp ResultA
.none:
        ld a,$FF
        jp ResultA

; NoWildcards: carry when the FCB's name and extension (IX) have a '?'. Keeps IX.
NoWildcards:
        push ix
        pop hl
        inc hl
        ld b,11
.char:
        ld a,(hl)
        cp '?'
        scf
        ret z
        inc hl
        djnz .char
        or a
        ret

; SearchDevice: a device's name found (as the FCB has it: no wildcards): at the DTA the drive's number, then
; an entry of its own (no attributes, the date and the time now, no cluster, size 0). SEARCH NEXT finds no
; more.
SearchDevice:
        ld a,$FF
        ld (SearchIndex),a
        ld (DirDrive),a                 ; (built in SecBuf)
        ld a,(KDrive)
        ld (SearchDrive),a
        ld hl,(SecBufAddr)
        push hl
        ld b,33
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        pop hl
        push hl
        ld a,(KDrive)
        inc a
        ld (hl),a
        inc hl
        ex de,hl
        push ix
        pop hl
        inc hl
        ld bc,11
        ldir
        call DirDateTime
        pop iy
        ld (iy + 1 + 22),l
        ld (iy + 1 + 23),h
        ld (iy + 1 + 24),e
        ld (iy + 1 + 25),d
        push iy
        pop hl
        ld de,(DtaAddr)
        ld bc,33
        call CopyToUser
        xor a
        jp ResultA

; --- 13h: delete (every file that matches) ---
FcbDelete:
        call FcbIn
        jp c,FcbResultFF
        call LoginDrive
        jp c,FcbResultFF
        call PatternFromFcb
        ld c,$FF                        ; the result: FFh until one is deleted
        xor a
.next:
        push bc
        call FindEntry
        pop bc
        jr c,.done
        ld (hl),$E5
        push af
        push bc
        push hl
        call WriteDirSector
        pop hl
        ld de,26
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        call FreeChain
        pop bc
        pop af
        ld c,0
        inc a
        jr .next
.done:
        push bc
        call FlushFat
        pop bc
        ld a,c
        jp ResultA

; --- 17h: rename: the name at FCB + 1 becomes the one at FCB + 17 ('?' there keeps the character) ---
FcbRename:
        call FcbIn
        jp c,FcbResultFF
        call LoginDrive
        jp c,FcbResultFF
        ld c,$FF
        xor a
.next:
        push bc
        push af
        call PatternFromFcb
        pop af
        call FindEntry
        pop bc
        jr c,.done
        push bc
        push af
        push hl                         ; the new name: '?' keeps the old character
        ld de,Pattern
        ld b,11
        push ix
        pop iy
.make:
        ld a,(iy + FcbNewName)
        cp '?'
        jr nz,.char
        ld a,(hl)
.char:
        ld (de),a
        inc hl
        inc de
        inc iy
        djnz .make
        pop hl
        push hl
        xor a                           ; is there a file of the new name? (only another one)
        call FindEntry
        pop de                          ; DE = the entry being renamed
        jr c,.free
        ld a,(DirIndex)
        pop bc                          ; B = its number
        push bc
        cp b
        jr nz,.taken
.free:
        pop af
        push af
        call DirEntry                   ; (its sector again)
        ex de,hl
        ld hl,Pattern
        ld bc,11
        ldir
        call WriteDirSector
        pop af
        pop bc
        ld c,0
        inc a
        jr .next
.taken:
        pop af
        pop bc
.done:
        ld a,c
        jp ResultA

; --- the transfers ---

; Transfer: KCount bytes of the file (IX) from KPos, to / from the caller's KUser (KWrite). Reading stops at
; the file's end; writing makes the file longer (clusters taken as needed). Out: KDone = the bytes moved;
; carry when a write found the disk full.
Transfer:
        bit 5,(ix + FcbFlags)
        jp nz,DeviceTransfer
        ld hl,0
        ld (KDone),hl
        ld a,(KWrite)
        or a
        jr nz,.loop
        ; a read: no more than what is left of the file
        call BytesLeft                  ; HL = min(the bytes left, FFFFh); zero flag when none
        ret z
        ex de,hl
        ld hl,(KCount)
        or a
        sbc hl,de
        jr c,.loop
        ld (KCount),de
.loop:
        ld hl,(KCount)
        ld a,h
        or l
        jp z,.end
        call PosCluster                 ; HL = the cluster of KPos (taken when writing), carry: full
        ret c
        call ClusterSector              ; DE = its first sector
        ld a,(KPos + 1)                 ; + the sector in the cluster: (KPos / 512) AND the mask
        srl a
        ld iy,(KDpb)
        and (iy + DpbClusMask)
        add a,e
        ld e,a
        jr nc,.sector
        inc d
.sector:
        ld hl,(KPos)                    ; the offset in the sector, and the bytes there: N = min(512 - it, KCount)
        ld a,h
        and $01
        ld h,a
        ld (KTemp),hl
        ex de,hl
        ld (KTemp + 2),hl               ; (the sector)
        ld hl,512
        ld de,(KTemp)
        or a
        sbc hl,de                       ; 512 - offset
        ex de,hl
        ld hl,(KCount)
        or a
        sbc hl,de
        jr nc,.whole
        add hl,de                       ; KCount is less
        ex de,hl
.whole:
        ld b,d
        ld c,e                          ; BC = N
        ld de,(KTemp + 2)               ; DE = the sector
        ld hl,(KTemp)
        ld a,h
        or l
        jr nz,.part
        ld a,b
        cp 2
        jr nz,.part
        ; a whole sector: straight between the disk and the caller's memory
        push bc
        call ForgetDataSector
        ld hl,(KUser)
        ld b,1
        ld a,(KWrite)
        or a
        jr nz,.wholeWrite
        call ReadSectors
        jr .moved
.wholeWrite:
        call WriteSectors
        jr .moved
.part:
        push bc
        or a                            ; (a part: the sector is read first)
        call DataSectorIn               ; HL = the buffer with it
        ld de,(KTemp)
        add hl,de                       ; + the offset
        ld de,(KUser)
        pop bc
        push bc
        ld a,(KWrite)
        or a
        jr nz,.partWrite
        call CopyToUser
        jr .moved
.partWrite:
        ex de,hl
        call CopyFromUser
        ld a,1
        ld (DataDirty),a
.moved:
        pop bc                          ; N: KPos, KUser, KDone += N, KCount -= N
        ld hl,(KPos)
        add hl,bc
        ld (KPos),hl
        jr nc,.posHigh
        ld hl,(KPos + 2)
        inc hl
        ld (KPos + 2),hl
.posHigh:
        ld hl,(KUser)
        add hl,bc
        ld (KUser),hl
        ld hl,(KDone)
        add hl,bc
        ld (KDone),hl
        ld hl,(KCount)
        or a
        sbc hl,bc
        ld (KCount),hl
        jp .loop
.end:
        ld a,(KWrite)
        or a
        ret z
        ; a write: the size is the end of it if that is further; the file changed
        set 7,(ix + FcbFlags)
        ld hl,(KPos + 2)
        ld e,(ix + FcbSize_ + 2)
        ld d,(ix + FcbSize_ + 3)
        or a
        sbc hl,de
        jr c,.kept
        jr nz,.longer
        ld hl,(KPos)
        ld e,(ix + FcbSize_)
        ld d,(ix + FcbSize_ + 1)
        or a
        sbc hl,de
        jr c,.kept
        jr z,.kept
.longer:
        ld hl,(KPos)
        ld (ix + FcbSize_),l
        ld (ix + FcbSize_ + 1),h
        ld hl,(KPos + 2)
        ld (ix + FcbSize_ + 2),l
        ld (ix + FcbSize_ + 3),h
.kept:
        or a
        ret

; ForgetDataSector: the data buffer forgets sector DE of KDrive (written first when it was changed: a whole
; sector is about to be moved past it). Keeps BC, DE.
ForgetDataSector:
        ld a,(DataDrive)
        ld hl,KDrive
        cp (hl)
        ret nz
        ld hl,(DataSector)
        or a
        sbc hl,de
        ret nz
        push bc
        push de
        call FlushData
        pop de
        pop bc
        ld a,$FF
        ld (DataDrive),a
        ret

; BytesLeft: HL = the file's size - KPos (FFFFh when more; 0 when KPos is at or past the end), zero flag
; when it is 0.
BytesLeft:
        ld l,(ix + FcbSize_)
        ld h,(ix + FcbSize_ + 1)
        ld de,(KPos)
        or a
        sbc hl,de
        ld (KTemp),hl
        ld l,(ix + FcbSize_ + 2)
        ld h,(ix + FcbSize_ + 3)
        ld de,(KPos + 2)
        sbc hl,de
        jr c,.none
        ld a,h
        or l
        jr nz,.many
        ld hl,(KTemp)
        ld a,h
        or l
        ret
.many:
        ld hl,$FFFF
        ld a,h
        or a
        ret
.none:
        ld hl,0
        xor a
        ret

; PosCluster: HL = the cluster that holds byte KPos of the file (IX), from the cluster cache or walking
; the chain. Writing, the clusters missing are taken (the first one too: the file's first cluster).
; Carry when the disk is full (or, reading, the chain is broken).
PosCluster:
        ; the place of the cluster in the file: KPos / 512 / the sectors of a cluster
        ld hl,(KPos + 1)                ; KPos / 256 (KPos is under 16M)
        ld a,(KPos + 3)
        srl a
        rr h
        rr l                            ; / 512
        ld iy,(KDpb)
        ld a,(iy + DpbClusShift)
.shift:
        dec a
        jr z,.place
        srl h
        rr l
        jr .shift
.place:
        ld (KCluster),hl                ; the place wanted
        ; from the cache when it is not past it, else from the start
        ld e,(ix + FcbRelCl)
        ld d,(ix + FcbRelCl + 1)
        or a
        sbc hl,de
        jr c,.fromStart
        ld b,h
        ld c,l                          ; BC = the steps
        ld l,(ix + FcbAbsCl)
        ld h,(ix + FcbAbsCl + 1)
        jr .walk
.fromStart:
        ld bc,(KCluster)
        ld de,0
        ld l,(ix + FcbFirst)
        ld h,(ix + FcbFirst + 1)
.walk:
        ; HL = the cluster at place DE... (DE = KCluster - BC), BC steps more
        push hl
        call IsLastCluster
        pop hl
        jr nc,.have
        ; no cluster here: a write takes one (linked from the one before, or the first)
        ld a,(KWrite)
        or a
        scf
        ret z
        push bc
        call FindFreeCluster
        pop bc
        ret c                           ; full
        push bc
        push hl
        ld de,$0FFF
        call FatSet                     ; the end of the chain
        pop hl
        pop bc
        push hl
        ld a,(ix + FcbFirst)
        or (ix + FcbFirst + 1)
        jr nz,.link
        ld (ix + FcbFirst),l
        ld (ix + FcbFirst + 1),h
        jr .linked
.link:
        ld e,l
        ld d,h
        ld l,(ix + FcbAbsCl)            ; the one before is in the cache
        ld h,(ix + FcbAbsCl + 1)
        push bc
        call FatSet
        pop bc
.linked:
        pop hl
        ld (ix + FcbAbsCl),l            ; (the cache points to the new one, at the place before + 1)
        ld (ix + FcbAbsCl + 1),h
        jr .step
.have:
        ld (ix + FcbAbsCl),l
        ld (ix + FcbAbsCl + 1),h
.step:
        ; the cache's place = KCluster - BC
        push hl
        ld hl,(KCluster)
        or a
        sbc hl,bc
        ld (ix + FcbRelCl),l
        ld (ix + FcbRelCl + 1),h
        pop hl
        ld a,b
        or c
        ret z                           ; there (no carry)
        dec bc
        push bc
        push hl
        call FatGet                     ; the next one
        pop de
        pop bc
        push hl
        call IsLastCluster
        pop hl
        jr nc,.next
        ; the chain ends: the cache stays on the last one (DE); a write takes a new one
        ld (ix + FcbAbsCl),e
        ld (ix + FcbAbsCl + 1),d
        ld a,(KWrite)
        or a
        scf
        ret z
        inc bc                          ; (the step is not made yet)
        push bc
        call FindFreeCluster
        pop bc
        ret c
        push bc
        push hl
        ld de,$0FFF
        call FatSet
        pop hl
        push hl
        ex de,hl
        ld l,(ix + FcbAbsCl)
        ld h,(ix + FcbAbsCl + 1)
        call FatSet                     ; the last one -> the new one
        pop hl
        pop bc
        dec bc
        ld (ix + FcbAbsCl),l
        ld (ix + FcbAbsCl + 1),h
        jr .step
.next:
        ld (ix + FcbAbsCl),l
        ld (ix + FcbAbsCl + 1),h
        jr .step

; --- the record functions ---

; RecordPos: KPos = DE:HL (a record's number) * KRecSize. Destroys AF, BC, DE, HL.
RecordPos:
        ld (KTemp),hl
        ld (KTemp + 2),de
        ld hl,0
        ld (KPos),hl
        ld (KPos + 2),hl
        ld bc,(KRecSize)
.bit:
        ld a,b
        or c
        ret z
        srl b
        rr c
        jr nc,.double
        ld hl,(KPos)                    ; KPos += KTemp
        ld de,(KTemp)
        add hl,de
        ld (KPos),hl
        ld hl,(KPos + 2)
        ld de,(KTemp + 2)
        adc hl,de
        ld (KPos + 2),hl
.double:
        ld hl,(KTemp)                   ; KTemp *= 2
        add hl,hl
        ld (KTemp),hl
        ld hl,(KTemp + 2)
        adc hl,hl
        ld (KTemp + 2),hl
        jr .bit

; SeqRecord: DE:HL = the sequential record (the current block * 128 + the current record).
SeqRecord:
        ld l,(ix + FcbBlock)
        ld h,(ix + FcbBlock + 1)
        ld de,0
        ld b,7
.shift:
        add hl,hl
        rl e
        rl d
        djnz .shift
        ld a,(ix + FcbRecord)
        or l
        ld l,a
        ret

; SetSeqRecord: the current block and record from DE:HL.
SetSeqRecord:
        ld a,l
        and $7F
        ld (ix + FcbRecord),a
        ld b,7
.shift:
        srl d
        rr e
        rr h
        rr l
        djnz .shift
        ld (ix + FcbBlock),l
        ld (ix + FcbBlock + 1),h
        ret

; Record128: one record of 128 bytes at DE:HL, to / from the DTA (KWrite: 0 read, 1 write). A part of a
; record read at the file's end is completed with zeros. Out: A = 0 done, 1 the end of the file (nothing
; read) or the disk full.
Record128:
        ld bc,128
        ld (KRecSize),bc
        call RecordPos
        ld hl,128
        ld (KCount),hl
        ld hl,(DtaAddr)
        ld (KUser),hl
        call FileFat
        call Transfer
        ld a,1
        ret c                           ; full
        ld hl,(KDone)
        ld a,h
        or l
        ld a,1
        ret z                           ; nothing moved
        ld a,(KWrite)
        or a
        ld a,0
        ret nz                          ; written
        ld de,128                       ; a part read: the rest of the record zero
        ex de,hl
        or a
        sbc hl,de
        ret z
        ld b,h
        ld c,l
        ld hl,(KUser)
        ex de,hl
        call ZeroUser
        xor a
        ret

; ZeroUser: BC bytes of the caller's memory from DE set to 0.
ZeroUser:
        push bc
        push de
        xor a
        ld (KTemp),a
        ld hl,KTemp
        ld bc,1
        call CopyToUser
        pop de
        pop bc
        inc de
        dec bc
        ld a,b
        or c
        jr nz,ZeroUser
        ret

; 14h / 15h: sequential read / write of a record at the DTA; the record moves on.
SeqRead:
        xor a
        jr Sequential
SeqWrite:
        ld a,1
Sequential:
        ld (KWrite),a
        call FcbIn
        jp c,FcbResultFF
        call SeqRecord
        push de
        push hl
        call Record128
        pop hl
        pop de
        or a
        jr nz,.result
        ld bc,1                         ; the next record
        add hl,bc
        jr nc,.set
        inc de
.set:
        call SetSeqRecord
        xor a
.result:
        jp FcbResult

; 21h / 22h / 28h: random read / write of the record at FCB + 33 (3 bytes); the current block and record
; are set to it.
RandomRead:
        xor a
        jr Random
RandomWrite:
RandomWriteZero:
        ld a,1
Random:
        ld (KWrite),a
        call FcbIn
        jp c,FcbResultFF
        ld l,(ix + FcbRandom)
        ld h,(ix + FcbRandom + 1)
        ld e,(ix + FcbRandom + 2)
        ld d,0
        push de
        push hl
        call SetSeqRecord
        pop hl
        pop de
        call Record128
        jp FcbResult

; 23h: the random record = the file's size in records of 128 bytes (rounded up). A = FFh when there is no
; such file.
FileSize:
        call FcbIn
        jp c,FcbResultFF
        call LoginDrive
        jp c,FcbResultFF
        call PatternFromFcb
        xor a
        call FindEntry
        jr c,.none
        ld de,28
        add hl,de
        ld e,(hl)                       ; size: (low byte, + 127) / 128
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)
        ex de,hl
        ld de,127
        add hl,de
        jr nc,.noCarry
        inc bc
.noCarry:
        ld a,l
        rla                             ; bit 7 into the carry
        ld a,h
        rla
        ld (ix + FcbRandom),a
        ld a,c
        rla
        ld (ix + FcbRandom + 1),a
        ld a,b
        rla
        ld (ix + FcbRandom + 2),a
        ld (ix + FcbRandom + 3),0
        xor a
        jp FcbResult
.none:
        ld a,$FF
        jp FcbResult

; 24h: the random record = the current block * 128 + the current record.
SetRandomRecord:
        call FcbIn
        jp c,FcbResultFF
        call SeqRecord
        ld (ix + FcbRandom),l
        ld (ix + FcbRandom + 1),h
        ld (ix + FcbRandom + 2),e
        ld (ix + FcbRandom + 3),0
        xor a
        jp FcbResult

; 27h / 26h: HL records of the record size (FCB + 14) from the random record (FCB + 33: 4 bytes when the
; size is under 64, else 3), to / from the DTA; the random record moves on. Out: HL = the records moved (a
; part of one at the file's end counts), A = 0 all of them, 1 not all. A write of 0 records sets the
; file's size to the random record * the record size.
BlockRead:
        xor a
        jr Block
BlockWrite:
        ld a,1
Block:
        ld (KWrite),a
        ld (KRecords),hl
        xor a
        ld (KTemp + 3),a
        call FcbIn
        jp c,FcbResultFF
        call FileFat
        ld l,(ix + FcbRecSize)
        ld h,(ix + FcbRecSize + 1)
        ld a,h
        or l
        jr nz,.size
        ld hl,128                       ; (0: 128)
.size:
        ld (KRecSize),hl
        ld l,(ix + FcbRandom)
        ld h,(ix + FcbRandom + 1)
        ld e,(ix + FcbRandom + 2)
        ld d,(ix + FcbRandom + 3)
        ld a,(KRecSize + 1)
        or a
        jr nz,.three
        ld a,(KRecSize)
        cp 64
        jr c,.four
.three:
        ld d,0
.four:
        call RecordPos
        ld hl,(KRecords)
        ld a,h
        or l
        jr z,.setSize
        ; the bytes: records * size (no more than 64K - 1)
        ld de,(KRecSize)
        call Multiply                   ; HL = HL * DE, carry when it does not fit
        jr nc,.count
        ld hl,$FFFF
.count:
        ld (KCount),hl
        ld hl,(DtaAddr)
        ld (KUser),hl
        call Transfer
        ld a,0
        rla
        ld (KTemp + 3),a                ; (1: the disk is full)
        ; the records moved: KDone / size, rounded up
        ld hl,(KDone)
        ld de,(KRecSize)
        call Divide                     ; HL = HL / DE, DE = the rest
        ld a,d
        or e
        jr z,.exact
        inc hl
        push hl                         ; a part of a record read: the rest of it zero
        ld hl,(KRecSize)
        or a
        sbc hl,de
        ld b,h
        ld c,l
        ld de,(KUser)
        call ZeroUser
        pop hl
.exact:
        ; the random record += the records moved
        push hl
        ld e,(ix + FcbRandom)
        ld d,(ix + FcbRandom + 1)
        add hl,de
        ld (ix + FcbRandom),l
        ld (ix + FcbRandom + 1),h
        jr nc,.carried
        inc (ix + FcbRandom + 2)
        jr nz,.carried
        inc (ix + FcbRandom + 3)
.carried:
        pop hl
        push hl
        ld de,(KRecords)
        or a
        sbc hl,de
        ld a,0
        jr z,.all
        inc a
.all:
        pop hl
        ld b,a
        ld a,(KTemp + 3)
        or b
        push hl
        push af
        call FcbOut
        pop af
        pop hl
        ld b,h
        ret
.setSize:
        ld hl,(KPos)
        ld (ix + FcbSize_),l
        ld (ix + FcbSize_ + 1),h
        ld hl,(KPos + 2)
        ld (ix + FcbSize_ + 2),l
        ld (ix + FcbSize_ + 3),h
        set 7,(ix + FcbFlags)
        call FcbOut
        ld hl,0
        ld b,h
        xor a
        ret

; FileFat: the FAT of the file's drive in (EnsureFat), not for a device.
FileFat:
        bit 5,(ix + FcbFlags)
        ret nz
        jp EnsureFat

; --- the devices: CON (the screen and the keyboard), PRN and LST (the printer), NUL (nothing), AUX (no
;     device: nothing out, the end of a text in). Any drive, any extension: open and create take them; the
;     FCB is marked (bit 5 of the flags, the device's number in its first cluster). ---

DeviceNames:
        db "CON     PRN     LST     NUL     AUX     "
DevCon          equ 0
DevNul          equ 3
DevAux          equ 4
DeviceCount     equ 5

; IsDevice: the FCB's name (IX) is a device's: carry clear, A = its number. Keeps IX.
IsDevice:
        ld hl,DeviceNames
        ld c,0
.name:
        push ix
        pop de
        inc de
        ld b,8
.char:
        ld a,(de)
        cp (hl)
        jr nz,.next
        inc hl
        inc de
        djnz .char
        ld a,c
        or a
        ret
.next:
        ld a,l                          ; (the rest of that name)
        add a,b
        ld l,a
        jr nc,.carried
        inc h
.carried:
        inc c
        ld a,c
        cp DeviceCount
        jr c,.name
        scf
        ret

; OpenDevice: the FCB (IX) opened on the device A: its size 0, the date and the time now.
OpenDevice:
        ld (ix + FcbFirst),a
        xor a
        ld (ix + FcbFirst + 1),a
        ld (ix + FcbSize_),a
        ld (ix + FcbSize_ + 1),a
        ld (ix + FcbSize_ + 2),a
        ld (ix + FcbSize_ + 3),a
        ld (ix + FcbBlock),a
        ld (ix + FcbBlock + 1),a
        ld (ix + FcbRecord),a
        call DirDateTime
        ld (ix + FcbTime),l
        ld (ix + FcbTime + 1),h
        ld (ix + FcbDate),e
        ld (ix + FcbDate + 1),d
        call OpenedFcb
        set 5,(ix + FcbFlags)
        xor a
        jp FcbResult

; DeviceTransfer: Transfer for a device (KCount bytes to / from KUser; KDone the bytes moved). A read of CON
; gives the lines typed (each ended by CR LF; a line that starts with CTRL+Z gives the end of the text, 1Ah,
; and the read stops); AUX gives 1Ah; the others nothing. A write: CON shows the bytes, PRN and LST print them
; (up to a 1Ah), NUL and AUX take them.
DeviceTransfer:
        push ix                         ; (the BIOS's CALSLT takes IX: the FCB)
        call .moves
        pop ix
        ret
.moves:
        ld hl,0
        ld (KDone),hl
        ld a,(KWrite)
        or a
        jp nz,DeviceWrite
        ld a,(ix + FcbFirst)
        or a                            ; (DevCon)
        jr z,ConRead
        cp DevAux
        ret nz                          ; PRN, LST, NUL: nothing (the end of the file)
        ld hl,(KCount)
        ld a,h
        or l
        ret z
        ld a,$1A
        call DevToUser
        or a
        ret

; DevToUser: A to the caller's KUser; KUser, KDone + 1, KCount - 1.
DevToUser:
        ld (KTemp),a
        ld hl,KTemp
        ld de,(KUser)
        ld bc,1
        call CopyToUser
        ld bc,1
DevMoved:                               ; (BC bytes moved)
        ld hl,(KUser)
        add hl,bc
        ld (KUser),hl
        ld hl,(KDone)
        add hl,bc
        ld (KDone),hl
        ld hl,(KCount)
        or a
        sbc hl,bc
        ld (KCount),hl
        ret

ConRead:
        ld hl,(KCount)
        ld a,h
        or l
        ret z                           ; (carry clear)
        ld a,(DevLeft)
        or a
        jr nz,.take
        ld c,127
        call GatherLine                 ; B characters at SecBuf + 2
        ld a,13
        call ShowChar
        ld a,10
        call ShowChar
        ld hl,(SecBufAddr)
        inc hl
        inc hl
        ld a,b
        or a
        jr z,.line
        ld a,(hl)
        cp $1A
        jr nz,.line
        call DevToUser                  ; the end of the text
        or a
        ret
.line:
        ld de,DevBuf
        ld c,b
        ld b,0
        ld a,c
        or a
        jr z,.empty
        ldir
.empty:
        ex de,hl
        ld (hl),13
        inc hl
        ld (hl),10
        add a,2
        ld (DevLeft),a
        ld hl,DevBuf
        ld (DevPtr),hl
.take:
        ld a,(DevLeft)                  ; BC = min(DevLeft, KCount)
        ld c,a
        ld b,0
        ld hl,(KCount)
        ld a,h
        or a
        jr nz,.some
        ld a,l
        cp c
        jr nc,.some
        ld c,a
.some:
        push bc
        ld hl,(DevPtr)
        ld de,(KUser)
        call CopyToUser
        pop bc
        ld hl,(DevPtr)
        add hl,bc
        ld (DevPtr),hl
        ld a,(DevLeft)
        sub c
        ld (DevLeft),a
        call DevMoved
        jr ConRead

DeviceWrite:
        xor a
        ld (KTemp + 1),a                ; (1: a 1Ah was met: no more out)
.byte:
        ld hl,(KCount)
        ld a,h
        or l
        ret z                           ; (carry clear)
        ld hl,(KUser)
        call ReadUserByte
        ld e,a
        ld a,(ix + FcbFirst)
        cp DevNul
        jr nc,.moved                    ; NUL, AUX
        ld a,(KTemp + 1)
        or a
        jr nz,.moved
        ld a,e
        cp $1A
        jr nz,.out
        ld a,1
        ld (KTemp + 1),a
        jr .moved
.out:
        ld a,(ix + FcbFirst)
        or a                            ; (DevCon)
        ld a,e
        jr nz,.printer
        push ix
        call OutputBreak
        call ShowChar
        pop ix
        jr .moved
.printer:
        push ix
        ld ix,LPTOUT
        call CallBios
        pop ix
.moved:
        ld bc,1
        call DevMoved
        jr .byte

; Multiply: HL = HL * DE (16 bits); carry when the product does not fit. Destroys AF, BC, DE.
Multiply:
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.bit:
        add hl,hl
        ret c
        sla e
        rl d
        jr nc,.noAdd
        add hl,bc
        ret c
.noAdd:
        dec a
        jr nz,.bit
        or a
        ret

; Divide: HL = HL / DE, DE = the rest (DE not 0). Destroys AF, BC.
Divide:
        ld b,h
        ld c,l
        ld hl,0
        ld a,16
.bit:
        sla c
        rl b
        adc hl,hl
        sbc hl,de
        jr nc,.fits
        add hl,de
        jr .next
.fits:
        inc c
.next:
        dec a
        jr nz,.bit
        ex de,hl                        ; DE = the rest
        ld h,b
        ld l,c
        ret
