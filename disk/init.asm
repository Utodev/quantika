; init.asm: what the disk ROM does when the main ROM's cartridge scan calls it (INIT), and its CALL
; statements.

; DiskInit: INIT. Runs only when the main ROM has FBASIC's service table (common/diskapi.inc): with any
; other main ROM the interface stays silent (no drive), so the machine still boots.
DiskInit:
        call FindServices
        ret nz                          ; not FBASIC: nothing installed
        ld a,6                          ; SHIFT held: no disk system (the interface stays silent)
        call SNSMAT
        rra
        ret nc
        call CopyServices
        call FindSlots
        ld hl,(HIMEM)                   ; HIMEM under what the disk system takes (fixed places: its buffers,
        ld de,DiskBottom                ; its stack and its resident routines, under the main ROM's boot stack)
        or a
        sbc hl,de
        jr c,.himem
        ld (HIMEM),de
.himem:
        ld hl,SecBuf
        ld (SecBufAddr),hl
        ld hl,DataBuf
        ld (DataBufAddr),hl
        ld hl,FatBuf
        ld (FatBufAddr),hl
        ld hl,KStack
        ld (KStackTop),hl
        ld hl,$FFFF                     ; the heads' tracks not known
        ld (DrvTracks),hl
        ld a,$FF
        ld (LastDrive),a
        ld hl,ResImage                  ; the resident routines
        ld de,ResCode
        ld bc,ResImageLength
        ldir
        call KernelInit
        call CountDrives
        ld a,(RamSlot1)                 ; the RAM: the memory mapper's slot in every page
        ld hl,RAMAD0
        ld b,4
.ramad:
        ld (hl),a
        inc hl
        djnz .ramad
        ld a,(MySlot)
        ld (MASTER),a
        call AddToDrvtbl
        ld hl,H_PHYD                    ; PHYDIO and FORMAT (the main ROM's entries call their hooks)
        ld de,DiskIo
        call SetHook
        ld hl,H_FORM
        ld de,DiskFormat
        call SetHook
        jp DeselectDrive

; KernelInit: the kernel's variables, the standard's places in the work area (BDOS among them), the boot
; through H_STKE.
KernelInit:
        ld hl,FixedPlaces               ; the standard's places in the work area
.place:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.placed
        ld c,(hl)
        inc hl
        ld b,0
        ldir
        jr .place
.placed:
        ld a,(MySlot)                   ; BDOS's body: RST 30h, this ROM's slot, the kernel's entry, RET
        ld (BdosBody + 1),a
        ld a,$FF
        ld (FatDrive),a
        ld (DataDrive),a
        ld (DirDrive),a
        xor a
        ld (FatDirty),a
        ld (DataDirty),a
        ld (CurDrive),a
        ld (VerifyFlag),a
        ld (SearchIndex),a
        ld (SearchDrive),a
        ld (DpbArea),a
        inc a
        ld (DpbArea + 21),a
        ld hl,DpbArea                   ; both DPBs: 720K (F9h) until a disk is looked at
        ld bc,$F9F9
        xor a
        call GetDpb
        ld hl,DpbArea + 21
        ld bc,$F9F9
        ld a,1
        call GetDpb
        ld a,$FF
        ld (ClockFlag),a
        ld a,($002B)                    ; (the main ROM is in page 0 now)
        rrca
        rrca
        rrca
        rrca
        and $07
        ld (DateFormat),a
        xor a
        ld (KDepth),a
        ld (BootFlag),a
        ld (WaitFlag),a
        ld hl,$0080
        ld (DtaAddr),hl
        ld hl,0
        ld (DISKVE),hl
        ld (BREAKV),hl
        ld hl,BasicHooks                ; disk BASIC's statements
.hook:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.hooked
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ex de,hl
        ld d,b
        ld e,c
        call SetHook
        pop hl
        jr .hook
.hooked:
        xor a                           ; the first "Ok": this ROM's line under BASIC's banner
        ld (ReadArmed),a
        call ArmFirstReady
        ld hl,H_STKE                    ; the boot, once the cartridges are started
        ld de,BootDisk
        jp SetHook

; BasicHooks: DW the hook, DW the routine; DW 0 ends.
BasicHooks:
        dw H_MERG, DiskLoadHook
        dw H_SAVE, DiskSaveHook
        dw H_SAVD, SaveFlushHook
        dw H_BINL, DiskBloadHook
        dw H_BINS, DiskBsaveHook
        dw H_FILE, DiskFilesHook
        dw H_KILL, DiskKillHook
        dw H_NAME, DiskNameHook
        dw H_COPY, DiskCopyHook
        dw H_DSKF, DiskDskfHook
        dw H_PARD, FileNameHook
        dw H_NULO, FileOpenHook
        dw H_NTFL, FileCloseHook
        dw H_FILO, FileFlushHook
        dw H_INDS, FileFillHook
        dw H_DGET, FileGetPutHook
        dw H_LOC, FileLocHook
        dw H_LOF, FileLofHook
        dw H_FIEL, FieldHook
        dw H_LSET, SetFieldHook
        dw H_RSET, SetFieldHook
        dw H_MKIS, MakeHook
        dw H_MKSS, MakeHook
        dw H_MKDS, MakeHook
        dw H_CVI, ConvertHook
        dw H_CVS, ConvertHook
        dw H_CVD, ConvertHook
        dw H_DSKI, DskiHook
        dw H_DSKO, DskoHook
        dw 0

; FixedPlaces: DW the place, DB the length, the bytes; DW 0 ends.
FixedPlaces:
        dw PrintTextEntry
        db 3
        jp ResPrintText
        dw AuxIn
        db 10
        ld a,$1A
        ret
        ret
        ret
        ret
        ret
        ret
        ret
        ret
        dw BdosBody
        db 5
        rst $30
        db 0                            ; (the slot: KernelInit puts it)
        dw KernelEntry
        ret
        dw EnableRom
        db 9
        jp ResEnableRom
        jp ResEnableRam
        jp ResRamLdir
        dw BDOS
        db 3
        jp BdosBody
        dw SECBUF
        db 2
        dw SecBuf
        dw 0

; CountDrives: PhysDrives (drive B: is there when a restore on it ends), LogDrives (2, or 1 when CTRL is
; held: one drive and no second one on it), PhantomDrive (A:). Destroys all.
CountDrives:
        xor a
        ld (PhantomDrive),a
        ld (IoSide),a
        ld (IoTrack),a
        inc a
        ld (IoDrive),a
        call SeekTrack                  ; (a restore: the track is not known)
        ld a,1
        jr c,.one
        inc a
.one:
        ld (PhysDrives),a
        ld hl,$FFFF                     ; the heads' tracks not known again (B:'s restore moved the
        ld (DrvTracks),hl               ; controller's track register)
        ld a,$FF
        ld (LastDrive),a
        ld a,6
        call SNSMAT
        and $02                         ; CTRL held: one drive only
        ld a,1
        jr z,.logical
        ld a,2
.logical:
        ld (LogDrives),a
        ret

; AddToDrvtbl: this interface's drives and slot into the first free pair of DRVTBL. Destroys AF, B, HL.
AddToDrvtbl:
        ld hl,DRVTBL
        ld b,4
.find:
        ld a,(hl)
        or a
        jr z,.free
        inc hl
        inc hl
        djnz .find
        ret
.free:
        ld a,(LogDrives)
        ld (hl),a
        inc hl
        ld a,(MySlot)
        ld (hl),a
        ret

; SetHook: the hook at HL calls DE in this ROM (RST 30h, the slot, the address, RET). Destroys A, HL.
SetHook:
        ld (hl),$F7
        inc hl
        ld a,(MySlot)
        ld (hl),a
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),$C9
        ret

; FindSlots: MySlot (this ROM's slot: page 1's now) and RamSlot1 (the RAM's for page 1: the memory
; mapper's, the slot of page 3). Destroys AF, BC, HL.
FindSlots:
        in a,($A8)
        rrca
        rrca
        call SlotOfPrimary              ; page 1: bits 3-2 of the subslot register
        ld (MySlot),a
        in a,($A8)
        rlca
        rlca
        ld c,a                          ; (page 3 in bits 1-0)
        call SlotOfPrimary.page3
        ld (RamSlot1),a
        ret

; SlotOfPrimary: the slot ID of page 1 for the primary slot A (bits 1-0); .page3 for page 3 (C = A).
; Destroys BC, HL.
SlotOfPrimary:
        and $03
        ld c,a
        call .expanded
        ret z
        ld a,(hl)                       ; SLTTBL: the subslot register
        and $0C                         ; page 1's subslot, already in bits 3-2
        or c
        or $80
        ret
.page3:
        ld a,c
        and $03
        ld c,a
        call .expanded
        ret z
        ld a,(hl)
        rrca
        rrca
        rrca
        rrca                            ; page 3's subslot into bits 3-2
        and $0C
        or c
        or $80
        ret
.expanded:                              ; Z when primary C is not expanded (A = C); HL = its SLTTBL
        ld hl,EXPTBL
        ld b,0
        add hl,bc
        ld a,(hl)
        ld hl,SLTTBL
        add hl,bc
        and $80
        ld a,c
        ret



; FindServices: Z when the main ROM has the service table's header ("FBDISK" at DsSignature) and it has
; every entry this ROM needs. Destroys AF, BC, DE, HL.
FindServices:
        ld hl,DsSignature
        ld de,ServicesSignature
        ld b,6
.compare:
        call ReadMain
        ex de,hl
        cp (hl)
        ex de,hl
        ret nz
        inc hl
        inc de
        djnz .compare
        ld hl,DsCount
        call ReadMain
        cp SrvEntries
        jr c,.tooFew
        xor a
        ret
.tooFew:
        or $FF                          ; NZ
        ret
ServicesSignature:
        db "FBDISK"

; CopyServices: the service table's addresses into SrvCopy (the ones this ROM knows).
; Destroys AF, BC, DE, HL.
CopyServices:
        ld hl,DsTable
        call ReadMain
        ld e,a
        inc hl
        call ReadMain
        ld d,a
        ex de,hl                        ; HL = the table in the main ROM
        ld de,SrvCopy
        ld b,2 * SrvEntries
.copy:
        call ReadMain
        ld (de),a
        inc hl
        inc de
        djnz .copy
        ret

; ReadMain: A = the main ROM's byte at HL. Keeps BC, DE, HL. (Interrupts disabled.)
ReadMain:
        push bc
        push de
        ld a,(EXPTBL)                   ; the main ROM's slot
        call RDSLT
        pop de
        pop bc
        ret

; DiskCallStatement: CALL name (PROCNM): FORMAT, SYSTEM. Carry: not this ROM's.
DiskCallStatement:
        push hl
        ld hl,CallFormatName
        call SameName
        pop hl
        jp z,FormatStatement
        push hl
        ld hl,CallSystemName
        call SameName
        pop hl
        jp z,SystemStatement
        scf
        ret
; SameName: Z when PROCNM holds the name at HL (both ended by 0).
SameName:
        ld de,PROCNM
.char:
        ld a,(de)
        cp (hl)
        ret nz
        or a
        ret z
        inc hl
        inc de
        jr .char
CallFormatName:
        db "FORMAT", 0
CallSystemName:
        db "SYSTEM", 0
