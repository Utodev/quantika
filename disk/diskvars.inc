; diskvars.inc: the disk interface's registers and the disk ROM's own variables.

; --- the interface's registers (in page 1, over the ROM's last bytes; also seen at BFF8h) ---
FdcCommand      equ $7FF8               ; write: a command for the controller
FdcStatus       equ $7FF8               ; read: its status
FdcTrack        equ $7FF9
FdcSector       equ $7FFA
FdcData         equ $7FFB
FdcSide         equ $7FFC               ; bit 0: the side
FdcDrive        equ $7FFD               ; bits 1-0: the drive (0 A:, 1 B:, 3 none); bit 7 the motor
FdcLines        equ $7FFF               ; read: bit 7 low = data request, bit 6 low = the command ended

; --- the main ROM's entries (its jump table) ---
RDSLT           equ $000C               ; A = slot ID, HL = address: A = the byte there
WRSLT           equ $0014
CALSLT          equ $001C
ENASLT          equ $0024
CHPUT           equ $00A2
CHGET           equ $009F
KILBUF          equ $0156
SNSMAT          equ $0141
CHSNS           equ $009C
ERAFNK          equ $00CC
LDIRMV          equ $0059               ; BC bytes from the VRAM at HL to DE
LDIRVM          equ $005C               ; BC bytes from HL to the VRAM at DE
DSPFNK          equ $00CF
CLS             equ $00C3               ; (with the zero flag set)
LPTOUT          equ $00A5
REDCLK          equ $01F5               ; (the sub-ROM's)
WRTCLK          equ $01F9
CALBAS          equ $0159

; --- the disk system's work area: F1C9h-F37Fh, as the standard leaves it to the disk system (the main
;     ROM's boot stack is under it). Some places there are fixed: programs on disks (the disk operating
;     system's own system file among them, the DOS file) use them: F1C9h (a routine: the text at DE up to "$"), F23Bh, F23Dh
;     (the disk transfer address), F304h-F308h (the DOS file's own), F323h on (the standard's). This ROM's
;     variables fill the rest: block A (F1CCh-F23Ah), block B (F23Fh-F303h), block C (F309h-F322h). ---
DiskWork        equ $F1C9
BootStackRoom   equ 128                 ; under DiskWork: the main ROM's boot stack (its INIT and H_STKE run on it)
PrintTextEntry  equ $F1C9               ; 3: JP ResPrintText
WaitFlag        equ $F23B               ; 1: (the DOS file reads it at a warm start: 0)
DtaAddr         equ $F23D               ; 2: the disk transfer address
DosScratch      equ $F304               ; 5: the DOS file's (its stack at a call, a flag, the FCB of a search)

; block A
BlockA          equ $F1CC
SrvCopy         equ BlockA              ; the service table (common/diskapi.inc), copied by INIT: DW each
SrvCopyEnd      equ SrvCopy + 2 * 32    ; room for 32 entries
MySlot          equ SrvCopyEnd          ; 1: this ROM's slot ID
RamSlot1        equ MySlot + 1          ; 1: the RAM's slot ID for page 1 (a transfer there goes to the RAM)
DrvTracks       equ RamSlot1 + 1        ; 2: the head's track in drive A: and B: (FFh unknown)
LastDrive       equ DrvTracks + 2       ; 1: the drive the controller's track register is of (FFh none)
IoDrive         equ LastDrive + 1       ; 1: DSKIO's drive
IoMedia         equ IoDrive + 1         ; 1: its media byte
IoWrite         equ IoMedia + 1         ; 1: 0 read, 1 write
IoCount         equ IoWrite + 1         ; 1: the sectors left
IoDone          equ IoCount + 1         ; 1: the sectors done
IoSector        equ IoDone + 1          ; 2: the next logical sector
IoBuffer        equ IoSector + 2        ; 2: where it goes / comes from
IoTrack         equ IoBuffer + 2        ; 1: its cylinder
IoSide          equ IoTrack + 1         ; 1: its side
IoRecord        equ IoSide + 1          ; 1: its sector number on the track (from 1)
IoTries         equ IoRecord + 1        ; 1: tries left
IoStatus        equ IoTries + 1         ; 1: the controller's status after the last command
SecBufAddr      equ IoStatus + 1        ; 2: the sector buffer (512 bytes)
PhysDrives      equ SecBufAddr + 2      ; 1: the drives connected (1 or 2)
LogDrives       equ PhysDrives + 1      ; 1: the drives the system sees (2 with one drive: B: is the same
                                        ;    drive, the disk changed at a prompt; 1 when CTRL was held at boot)
PhantomDrive    equ LogDrives + 1       ; 1: with one drive: the drive (0 A:, 1 B:) its disk is now
DiskLetter      equ PhantomDrive + 1    ; 1: (AskForDisk)
BiosSlots       equ DiskLetter + 1      ; 1: the primary slots' register with the main ROM in page 0 (bits 1-0)
BootSP          equ BiosSlots + 1       ; 2: the stack at the boot (4022h goes back to it)
BlockAEnd       equ BootSP + 2
        assert BlockAEnd <= WaitFlag, "block A of the work area is full"

; block B: the kernel (disk/kernel.asm, disk/fat.asm, disk/files.asm)
BlockB          equ DtaAddr + 2
KUserSP         equ BlockB              ; 2: the caller's stack at the kernel's entry
KStackTop       equ KUserSP + 2         ; 2: the kernel's own stack
FatBufAddr      equ KStackTop + 2       ; 2: the FAT buffer (FatBufSize bytes)
DataBufAddr     equ FatBufAddr + 2      ; 2: the data buffer (512 bytes)
CurDrive        equ DataBufAddr + 2     ; 1: the default drive (0 A:)
VerifyFlag      equ CurDrive + 1        ; 1
KDrive          equ VerifyFlag + 1      ; 1: the drive the function works on
KDpb            equ KDrive + 1          ; 2: its DPB (the 20 bytes after the drive's number)
FatDrive        equ KDpb + 2            ; 1: the drive whose FAT is in the buffer (FFh none)
FatDirty        equ FatDrive + 1        ; 1: it was changed
DataDrive       equ FatDirty + 1        ; 1: the drive of the sector in the data buffer (FFh none)
DataSector      equ DataDrive + 1       ; 2: that sector
DataDirty       equ DataSector + 2      ; 1: it was changed
DirDrive        equ DataDirty + 1       ; 1: the drive of the directory sector in SecBuf (FFh none)
DirSector       equ DirDrive + 1        ; 2: that sector
DirIndex        equ DirSector + 2       ; 1: the directory entry being looked at
SearchIndex     equ DirIndex + 1        ; 1: the next entry SEARCH NEXT looks at
SearchDrive     equ SearchIndex + 1     ; 1: its drive
Pattern         equ SearchDrive + 1     ; 11: the name looked for ('?' any character)
KFcbAddr        equ Pattern + 11        ; 2: the caller's FCB
KFcb            equ KFcbAddr + 2        ; FcbSize: a copy of it, worked on
KPos            equ KFcb + FcbSize      ; 4: the byte of the file a transfer starts at
KCount          equ KPos + 4            ; 2: the bytes to move
KDone           equ KCount + 2          ; 2: the bytes moved
KUser           equ KDone + 2           ; 2: where in the caller's memory
KWrite          equ KUser + 2           ; 1: 0 read, 1 write
KCluster        equ KWrite + 1          ; 2: (temporary)
KRecSize        equ KCluster + 2        ; 2: the record size of a block transfer
KRecords        equ KRecSize + 2        ; 2: the records asked for
KTemp           equ KRecords + 2        ; 4: (temporary)
DpbArea         equ KTemp + 4           ; 2 * 21: the drives' DPBs (the drive's number, then 20 bytes)
KDepth          equ DpbArea + 2 * 21    ; 1: the kernel's calls in progress (one inside another: 2)
KEntrySP        equ KDepth + 1          ; 2: (the stack pointer at an entry or an exit)
BlockBEnd       equ KEntrySP + 2
        assert BlockBEnd <= DosScratch, "block B of the work area is full"

DateFormat      equ $F30E               ; 1: how the system file shows dates: 0 Y-M-D, 1 M-D-Y, 2 D-M-Y (the
                                        ;    main ROM's byte 2Bh, bits 6-4)

; block C
BlockC          equ DateFormat + 1
ReadHookSave    equ BlockC              ; 5: H_READ as it was before this ROM took it (the first "Ok")
BlockCEnd       equ ReadHookSave + 5
        assert BlockCEnd <= $F323, "block C of the work area is full"

; --- the memory under the work area, fixed (the main ROM's boot stack between): from the top down ---
DiskTop         equ DiskWork - BootStackRoom
SecBuf          equ DiskTop - 512       ; the sector buffer
DataBuf         equ SecBuf - 512        ; the data buffer
FatBufSize      equ 3 * 512             ; the largest FAT of the formats (720K: 3 sectors)
FatBuf          equ DataBuf - FatBufSize
KStackSize      equ 256
KStack          equ FatBuf              ; the kernel's stack (its top)
ResCode         equ KStack - KStackSize - ResRoom  ; the resident routines (disk/resident.asm)
ResRoom         equ 512
DevArea         equ ResCode - DevRoom   ; the devices' (disk/files.asm): CON's line
DevRoom         equ 132
DevLeft         equ DevArea             ; 1: the bytes of the line not read yet
DevPtr          equ DevLeft + 1         ; 2: the next of them
DevBuf          equ DevPtr + 2          ; 129: the line typed (127 characters at most), CR, LF
        assert DevBuf + 129 <= ResCode, "the devices' area is full"
BasicArea       equ DevArea - BasicRoom ; disk BASIC's (disk/basic.asm)
BasicRoom       equ 440
FileArea        equ BasicArea - FileRoom ; disk BASIC's files (disk/bfiles.asm)
FileSlotSize    equ 37 + 3              ; a file number's FCB (FcbSize), then its LOC (3 bytes)
FileRoom        equ 15 * FileSlotSize + 80 + 37
DiskBottom      equ $DE79               ; the lowest byte the disk system takes: HIMEM, and what 4030h says (as
        assert FileArea >= DiskBottom, "the disk system takes more than the original"   ; the original's: the
                                        ; same memory left to BASIC)

; disk BASIC's variables and buffers
BFcb            equ BasicArea           ; FcbSize: the file worked on (COPY: the old one)
BFcb2           equ BFcb + FcbSize      ; FcbSize: NAME, COPY: the new one
BBuf            equ BFcb2 + FcbSize     ; 256: a buffer (the DTA of the searches, a block of text, of VRAM)
BCopyTo         equ BBuf + 256          ; 12: COPY: the new names' drive and pattern
BHeader         equ BCopyTo + 12        ; 7: a binary file's header: FEh, then:
BStart          equ BHeader + 1         ;    2: its start
BEnd            equ BHeader + 3         ;    2: its end
BExec           equ BHeader + 5         ;    2: its run address
BTemp           equ BHeader + 7         ; 1
BTok            equ BTemp + 1           ; 1: the statement's token
BFlags          equ BTok + 1            ; 1: LOAD: bit 0 a new program, bit 1 run it; SAVE: 1 as text
BSaving         equ BFlags + 1          ; 1: SAVE "...", A is writing text (H_SAVD takes the blocks)
BVram           equ BSaving + 1         ; 1: BLOAD, BSAVE: ,S
BRun            equ BVram + 1           ; 1: BLOAD: ,R
BOffset         equ BRun + 1            ; 2: BLOAD: the offset
BLength         equ BOffset + 2         ; 2: the bytes of a binary file
BText           equ BLength + 2         ; 2: the BASIC text where the statement goes on
BNameText       equ BText + 2           ; 2: (TakeName)
BNameFlags      equ BNameText + 2       ; 1: (ParseName)
BLine           equ BNameFlags + 1      ; 2: LOAD: the end of the line in BUF
BLeft           equ BLine + 2           ; 2: LOAD: the bytes left in BBuf
BPtr            equ BLeft + 2           ; 2: LOAD: the next of them; COPY: the end of the names
BList           equ BPtr + 2            ; 2: COPY: the next name
BBufSize        equ BList + 2           ; 2: COPY: its buffer's size
BCopyFrom       equ BBufSize + 2        ; 1: COPY: the old files' drive
BPerLine        equ BCopyFrom + 1       ; 1: FILES: the names on a line
BColumn         equ BPerLine + 1        ; 1: FILES: the names on this line so far
FmtDrive        equ BColumn + 1         ; 1: the format: the drive
FmtTwoSides     equ FmtDrive + 1        ; 1: ... 0 one side, 1 two
BootFrames      equ FmtTwoSides + 1     ; 32: the boot stack's top at H_STKE (BootReturn puts it back: BASIC
                                        ;    starts again from there after CALL SYSTEM)
BootDiskOk      equ BootFrames + 32     ; 1: the boot sector could be read at power on (AUTOEXEC.BAS)
ReadArmed       equ BootDiskOk + 1      ; 1: FirstReady is on H_READ
FmtInts         equ ReadArmed + 1       ; 1: the format: the interrupts were on
BasicAreaEnd    equ FmtInts + 1
        assert BasicAreaEnd <= DevArea, "disk BASIC's area is full"

; disk BASIC's files (disk/bfiles.asm)
FileSlots       equ FileArea            ; 15 * FileSlotSize: files 1 - 15
OpenFcb         equ FileSlots + 15 * FileSlotSize ; FcbSize: OPEN's name
FBlock          equ OpenFcb + 37        ; 2: the file's block (FBASIC's)
FSlot           equ FBlock + 2          ; 2: its FCB
FMode           equ FSlot + 2           ; 1: OPEN, CLOSE: the mode
FTok            equ FMode + 1           ; 1: the statement's token, a function's, a width, a size
FOffset         equ FTok + 1            ; 2: FIELD: the place in the record
FStart          equ FOffset + 2         ; 3: APPEND: where the last block read starts
FPos            equ FStart + 3          ; 3: APPEND: where this block starts
FCheckErr       equ FPos + 3            ; 1: CheckOpen's error
FCheckFcb       equ FCheckErr + 1       ; 2: CheckOpen's FCB
FDigits         equ FCheckFcb + 2       ; 12: NumberResult's digits
FNum            equ FDigits + 12        ; 8: MKI$ and the like: the number's bytes
FDrive          equ FNum + 8            ; 1: DSKI$, DSKO$: the drive
FSector         equ FDrive + 1          ; 2: ... and the sector
FileAreaEnd     equ FSector + 2
        assert FileAreaEnd <= BasicArea, "the files' area is full"


; --- the FCB (37 bytes) ---
FcbDrive        equ 0                   ; 0 the default drive, 1 A:, 2 B:
FcbName         equ 1                   ; 8 + 3
FcbBlock        equ 12                  ; 2: the current block (128 records)
FcbRecSize      equ 14                  ; 2: the record size of the block functions
FcbSize_        equ 16                  ; 4: the file's size
FcbDate         equ 20                  ; 2
FcbTime         equ 22                  ; 2
FcbFlags        equ 24                  ; 1: (this kernel's) 40h + the drive (0-based) when open; bit 7: changed
FcbEntry        equ 25                  ; 1: (this kernel's) its directory entry
FcbFirst        equ 26                  ; 2: its first cluster
FcbRelCl        equ 28                  ; 2: (this kernel's) the cluster last reached: its place in the file
FcbAbsCl        equ 30                  ; 2: ... and its number
FcbRecord       equ 32                  ; 1: the current record in the block
FcbRandom       equ 33                  ; 4: the random record
FcbSize         equ 37
        assert FileSlotSize == FcbSize + 3, "FileSlotSize and FcbSize differ"
FcbNewName      equ 17                  ; (rename: the new name, 8 + 3)

; --- the DPB's fields (from the byte after the drive's number) ---
DpbMedia        equ 0
DpbSecSize      equ 1
DpbDirMask      equ 3
DpbDirShift     equ 4
DpbClusMask     equ 5
DpbClusShift    equ 6
DpbFirstFat     equ 7
DpbFats         equ 9
DpbEntries      equ 10
DpbFirstData    equ 11
DpbMaxClus      equ 13
DpbFatSize      equ 15
DpbFirstDir     equ 16
DpbFatAddr      equ 18

; --- the standard's variables of the disk system ---
DISKVE          equ $F323               ; 2: points to the address of the disk error handler (0: none)
BREAKV          equ $F325               ; 2: points to the address of the CTRL+C handler
AuxIn           equ $F327               ; 3: the auxiliary device's input (LD A,1AH / RET)
AuxRest         equ $F32A               ; 7: its output and the rest (RET each)
BdosBody        equ $F331               ; 5: RST 30h, MASTER, the kernel's entry, RET: BDOS jumps here
ClockFlag       equ $F338               ; 1: FFh: the machine has a clock (the system file's command
                                        ;    interpreter asks for the date at its start when it is 0)
BootFlag        equ $F340               ; 1: 0 until the DOS file has started once (it shows its name then)
EnableRom       equ $F368               ; 3: JP: this ROM in page 1 (keeps all but AF; interrupts off)
EnableRam       equ $F36B               ; 3: JP: the RAM in page 1 (as EnableRom)
RamLdir         equ $F36E               ; 3: JP: LDIR with the RAM in page 1, then this ROM there again
BDOS            equ $F37D               ; 3: JP to the kernel (BdosBody)

; --- the standard's variables of the disk system (fixed addresses) ---
RAMAD0          equ $F341               ; the RAM's slot ID in page 0
RAMAD1          equ $F342               ; ... page 1
RAMAD2          equ $F343               ; ... page 2
RAMAD3          equ $F344               ; ... page 3
MASTER          equ $F348               ; the slot ID of the disk ROM that runs the disk system
SECBUF          equ $F351               ; 2: a sector buffer (DSKI$, DSKO$): this ROM's SecBuf
DRVTBL          equ $FB21               ; 4 pairs: the drives of an interface, its slot ID

; KERNEL function: the kernel's function (C), as BDOS does (DE, HL as it says).
        macro KERNEL function
        ld c,function
        call KernelEntry
        endm

; FBASIC name: calls FBASIC's service (common/diskapi.inc) with the main ROM in page 1 (ResFbasic: a
; service may be in page 0 or 1). Registers as the service says (IX and IY are lost).
        macro FBASIC entry
        ld ix,(SrvCopy + 2 * entry)
        call ResFbasic
        endm
