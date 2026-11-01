; bfiles.asm: disk BASIC's files: OPEN (FOR INPUT, OUTPUT, APPEND, or random with LEN), CLOSE, PRINT #,
; INPUT #, LINE INPUT #, INPUT$, EOF, LOC, LOF, FIELD, GET, PUT, LSET, RSET, MKI$ / MKS$ / MKD$, CVI / CVS /
; CVD, DSKI$ and DSKO$. FBASIC keeps a file's block (basic/files.asm: its mode, device, place in the buffer
; and a buffer of 256 bytes) and calls the hooks of common/diskapi.inc for a name that is no device of its
; own; this ROM keeps an FCB for each file number (FileSlots) and moves the buffer to and from the disk.
; A file being read is the cassette's way: 256 bytes at a time, 1Ah after its end; a file being written
; ends with 1Ah. Learned from the original as a black box: LOC is the bytes this OPEN has moved (a random
; file: the FCB's random record: the last record done; GET without a record reads the one after it), LOF
; the file's size; APPEND reads the file 256 bytes at a time up to the first
; block that has a 1Ah or is short, and writes from its 1Ah (or its end; a short block of none: the one
; before it, from its start).

; the block's places (basic/files.asm)
BlkMode         equ 0
BlkLength       equ 1                   ; 2: OPEN: LEN (0: not given)
BlkDevice       equ 4
BlkPosition     equ 7
BlkLoaded       equ 8
BlkBuffer       equ 9

; --- the hooks ---

; FileNameHook: H_PARD: OPEN's file name at DE (B characters), not a device of FBASIC's: a disk's file
; (into OpenFcb): A = its device (0), carry clear. Another device's name: the carry still set.
FileNameHook:
        ld a,b                          ; (a letter past H: Bad drive name here, as the original's OPEN)
        cp 2
        jr c,.parse
        inc de
        ld a,(de)
        dec de
        cp ':'
        jr nz,.parse
        ld a,(de)
        call UpperA
        cp 'I'
        jr c,.parse
        cp 'Z' + 1
        jp c,BadDriveName
.parse:
        push hl
        ld hl,OpenFcb
        xor a
        call ParseName
        pop hl
        ret c
        xor a
        ret

; FileOpenHook: H_NULO: the file of OpenFcb opened as file DE (its block) in mode B (1 input, 2 output, 4
; random, 8 append). Keeps BC, DE, HL.
FileOpenHook:
        push hl
        push de
        push bc
        ld a,b
        ld (FMode),a
        call FileEnter
        ex de,hl                        ; the name into the file's FCB
        ld hl,OpenFcb
        ld bc,FcbSize
        ldir
        ld de,OpenFcb                   ; (open as another file: File already open)
        ld a,ErrFileAlreadyOpen
        call CheckOpen
        ld a,(FMode)
        cp 2
        jr z,.create
        ld de,(FSlot)
        KERNEL $0F
        inc a
        jr nz,.opened
        ld a,(FMode)                    ; (only a random file is made when it is not there)
        cp 4
        jp nz,FileNotFound
.create:
        ld de,(FSlot)
        KERNEL $16
        inc a
        jp z,TooManyFiles
.opened:
        ld de,(FSlot)
        call ByteRecords                ; records of 1 byte from the start
        call ZeroLoc
        ld a,(FMode)
        dec a
        jr z,.input
        cp 8 - 1
        jr z,.append
        cp 4 - 1
        jr nz,.done
        ld hl,(FBlock)                  ; random: records of LEN bytes (256 when not given)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or e
        jr nz,.size
        inc d
.size:
        ld hl,(FSlot)                   ; (the buffer as it was: MAXFILES leaves zeros)
        ld bc,FcbRecSize
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        jr .done
.input:
        call FillBuffer                 ; (read at once: LOC counts it)
        jr .done
.append:
        call SeekAppend
.done:
        pop bc
        pop de
        pop hl
        or a
        ret

; FileFillHook: H_INDS: the buffer of file DE (being read) filled with the next 256 bytes, 1Ah after the
; file's end. Keeps BC, DE, HL.
FileFillHook:
        push hl
        push de
        push bc
        call FileEnter
        call FillBuffer
        jr FileHookDone

; FileFlushHook: H_FILO: the full buffer of file DE (being written) to the disk. Keeps BC, DE, HL.
FileFlushHook:
        push hl
        push de
        push bc
        call FileEnter
        ld hl,256
        call WriteChunk
        jp nz,DiskFull
FileHookDone:
        pop bc
        pop de
        pop hl
        or a
        ret

; FileCloseHook: H_NTFL: file DE closed (A = the mode it had): one being written gets what its buffer
; holds and 1Ah. Keeps BC, DE, HL.
FileCloseHook:
        push hl
        push de
        push bc
        ld (FMode),a
        call FileEnter
        ld a,(FMode)
        cp 2
        jr z,.flush
        cp 8
        jr z,.flush
        xor a
        jr .close
.flush:
        ld hl,(FBlock)
        ld bc,BlkPosition
        add hl,bc
        ld c,(hl)                       ; BC = the bytes in the buffer
        call BufferAddr
        add hl,bc
        ld (hl),$1A
        inc bc
        ld h,b
        ld l,c
        call WriteChunk
.close:
        push af
        ld de,(FSlot)
        KERNEL $10
        pop af
        jp nz,DiskFull
        jr FileHookDone

; FileGetPutHook: H_DGET: GET / PUT [#] n [, record] (C = the token): a record of a random file (the
; next one when none is given) to / from its buffer.
FileGetPutHook:
        push bc                         ; (C: an expression may use the variables below)
        call FileNumber                 ; DE = the block
        ld hl,BlkDevice
        add hl,de
        ld a,(hl)
        cp $FC
        ld a,ErrSequentialOnly
        jp nc,FileError
        ld a,(de)
        cp 4
        ld a,ErrBadFileMode
        jp nz,FileError
        push de
        call FileEnter
        call RandomAddr                 ; the next record: the FCB's random record + 1 (= LOC + 1)
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc de
        ld hl,(BText)
        call TextChar
        cp ','
        jr nz,.record
        call TextNext
        FBASIC SrvEvalAddress
        ld a,d
        or e
        jp z,IllegalFunction
.record:
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        pop hl
        push de
        ex de,hl
        call FileEnter
        pop de
        dec de
        call RandomAddr
        ld (hl),e                       ; (the kernel moves it on past a record done: LOC)
        inc hl
        ld (hl),d
        inc hl
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        call BufferAddr
        ld (DtaAddr),hl
        ld de,(FSlot)
        ld hl,1
        pop bc
        ld a,c
        cp TkPut
        jr z,.put
        KERNEL $27
        ld a,h
        or l
        ld a,ErrInputPastEnd
        jp z,FileError
        jr .done
.put:
        KERNEL $26
        or a
        jp nz,DiskFull
.done:
        ld hl,(BText)
        or a
        ret

; FileError: BASIC's error A.
FileError:
        ld e,a
        jp BasicError

; FileLocHook / FileLofHook: H_LOC / H_LOF: LOC / LOF of file DE (open): the carry still set when it is
; not a disk's. Keeps HL.
FileLocHook:
        call DiskFileOnly
        ret c
        push hl
        ld (FBlock),de
        call FileSlot
        ld (FSlot),hl
        call LocAddr
        ld a,(de)                       ; (a random file: the FCB's random record, the last record done)
        cp 4
        jr nz,FileLofHook.result
        call RandomAddr
        jr FileLofHook.result
FileLofHook:
        call DiskFileOnly
        ret c
        push hl
        call FileSlot
        ld bc,FcbSize_
        add hl,bc
.result:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        ex de,hl
        call NumberResult
        pop hl
        or a
        ret

; DiskFileOnly: carry when the file of block DE is not a disk's.
DiskFileOnly:
        push hl
        ld hl,BlkDevice
        add hl,de
        ld a,(hl)
        pop hl
        cp $FC
        ccf
        ret

; FieldHook: H_FIEL: FIELD [#] n, width AS string variable [, ...]: the variables made parts of the
; file's record buffer.
FieldHook:
        call FileNumber
        call DiskFileOnly
        ld a,ErrBadFileMode
        jp c,FileError
        ld a,(de)
        cp 4
        ld a,ErrBadFileMode
        jp nz,FileError
        ld hl,0
        ld (FOffset),hl
        ld hl,(BText)
.field:
        push de                         ; the block
        call Comma
        FBASIC SrvEvalByte
        push af                         ; the width
        call TextChar
        call UpperA
        cp 'A'
        jp nz,SyntaxErr
        call TextNext
        call UpperA
        cp 'S'
        jp nz,SyntaxErr
        call TextNext
        FBASIC SrvGetVariable           ; DE = its value
        ld a,(VALTYP)
        cp 3
        jp nz,TypeMismatch
        ld (BText),hl
        pop af
        pop hl
        push hl
        push de
        push af
        ex de,hl
        call FileEnter
        pop af                          ; its place: past the record's size: Field overflow
        ld c,a
        ld b,0
        push bc
        ld hl,(FOffset)
        push hl
        add hl,bc
        ld (FOffset),hl
        ex de,hl
        ld hl,(FSlot)
        ld bc,FcbRecSize
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        or a
        sbc hl,de
        jp c,FieldOverflow
        call BufferAddr
        pop de
        add hl,de
        ex de,hl                        ; DE = its characters
        pop bc
        pop hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        pop de                          ; the block
        ld hl,(BText)
        call TextChar
        cp ','
        jr z,.field
        or a
        ret

; SetFieldHook: H_LSET / H_RSET: LSET / RSET string variable = string (C = the token): the string into
; the variable's characters, spaces after it (LSET) or before it (RSET); a longer one is cut.
SetFieldHook:
        ld a,c
        push af                         ; (an expression may use FTok)
        FBASIC SrvGetVariable
        ld a,(VALTYP)
        cp 3
        jp nz,TypeMismatch
        push de
        call TextChar
        cp TkEqual
        jp nz,SyntaxErr
        call TextNext
        FBASIC SrvEvalString            ; B, DE
        ld (BText),hl
        pop hl
        pop af
        ld (FTok),a
        ld c,(hl)                       ; C = the variable's length, HL its characters
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,c
        or a
        jr z,.done
        ld a,(FTok)
        cp TkRset
        jr nz,.copy
        ld a,c
        sub b
        jr c,.copy
        jr z,.copy
        push bc
        ld b,a
.lead:
        ld (hl),' '
        inc hl
        djnz .lead
        pop bc
        ld c,b
.copy:
        ld a,b
        or a
        jr z,.pad
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        dec b
        dec c
        jr nz,.copy
        jr .done
.pad:
        ld (hl),' '
        inc hl
        dec c
        jr nz,.pad
.done:
        ld hl,(BText)
        or a
        ret

; MakeHook: H_MKIS / H_MKSS / H_MKDS: MKI$ / MKS$ / MKD$(number) (C = the function): its bytes as a
; string (2, 4 or 8).
MakeHook:
        ld a,c
        push af                         ; (an expression may use FTok)
        call OpenParen
        FBASIC SrvEvalExpression
        call CloseParen
        pop af
        cp FnMkiStr
        jr nz,.single
        FBASIC SrvForceInteger
        ld b,2
        ld hl,DAC + 2
        jr .make
.single:
        cp FnMksStr
        jr nz,.double
        FBASIC SrvForceSingle
        ld b,4
        jr .dac
.double:
        FBASIC SrvForceDouble
        ld b,8
.dac:
        ld hl,DAC
.make:
        ld de,FNum                      ; (a copy: making the string may move things)
        push de
        push bc
        ld c,b
        ld b,0
        ldir
        pop bc
        pop hl
        FBASIC SrvMakeString
        ld hl,(BText)
        or a
        ret

; ConvertHook: H_CVI / H_CVS / H_CVD: CVI / CVS / CVD(string) (C = the function): its first 2, 4 or 8
; bytes as a number (Illegal function call when it is shorter).
ConvertHook:
        ld a,c
        sub FnCvi - 1                   ; 1, 2, 3
        ld b,a
        ld a,1
.size:
        add a,a
        djnz .size
        push af                         ; 2, 4, 8
        call OpenParen
        FBASIC SrvEvalString
        call CloseParen
        pop af
        ld c,a
        ld a,b
        cp c
        jp c,IllegalFunction
        ld a,c
        ld (VALTYP),a
        ld b,0
        ex de,hl
        ld de,DAC
        cp 2
        jr nz,.copy
        ld de,DAC + 2
.copy:
        ldir
        ld hl,(BText)
        or a
        ret

; DskiHook: H_DSKI: DSKI$(drive, sector): the sector read into the buffer SECBUF points to; the result an
; empty string.
DskiHook:
        call OpenParen
        call DriveSector
        call CloseParen
        or a
        call AbsoluteSector
        ld b,0
        FBASIC SrvMakeString
        ld hl,(BText)
        or a
        ret

; DskoHook: H_DSKO: DSKO$ drive, sector: the sector written from the buffer SECBUF points to.
DskoHook:
        call DriveSector
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        scf
        call AbsoluteSector
        ld hl,(BText)
        or a
        ret

; DriveSector: drive, sector at HL: FDrive, FSector (Bad drive name for a drive not there).
DriveSector:
        FBASIC SrvEvalByte
        ld (FDrive),a
        call Comma
        FBASIC SrvEvalAddress
        ld (FSector),de
        ld (BText),hl
        ld a,(LogDrives)
        ld e,a
        ld a,(FDrive)
        cp e
        ret c
        ret z
        jp BadDriveName

; AbsoluteSector: FSector of FDrive (0 the default one) read (no carry) or written (carry) at SECBUF; a
; disk error is ignored (as the original: a sector past the disk, an empty drive).
AbsoluteSector:
        push af
        ld hl,IgnoreDiskVe
        ld (DISKVE),hl
        ld hl,(SECBUF)
        ld (DtaAddr),hl
        ld a,(FDrive)
        call RealDrive
        dec a
        ld l,a
        ld h,1
        ld de,(FSector)
        pop af
        ld c,$2F
        jr nc,.read
        inc c
.read:
        jp KernelEntry

IgnoreDiskVe:
        dw IgnoreDiskError
IgnoreDiskError:
        ld c,0
        ret

; OpenParen / CloseParen: '(' / ')' must be at HL (Syntax error); HL past it (CloseParen: BText too).
OpenParen:
        call TextChar
        cp '('
        jp nz,SyntaxErr
        jp TextNext
CloseParen:
        call TextChar
        cp ')'
        jp nz,SyntaxErr
        call TextNext
        ld (BText),hl
        ret

; --- the files ---

; FileNumber: [#] n at HL: DE = its block (open). Bad file number, File not OPEN. Out: BText past it.
FileNumber:
        call TextChar
        cp '#'
        jr nz,.number
        call TextNext
.number:
        FBASIC SrvEvalByte
        ld (BText),hl
        or a
        jr z,.bad
        ld hl,MAXFIL
        cp (hl)
        jr z,.ok
        jr nc,.bad
.ok:
        call BlockOf
        ex de,hl
        ld a,(de)
        or a
        ret nz
        ld a,ErrFileNotOpen
        jp FileError
.bad:
        ld a,ErrBadFileNumber
        jp FileError

; BlockOf: HL = the block of file A. Keeps BC.
BlockOf:
        add a,a
        ld e,a
        ld d,0
        ld hl,(FILTAB)
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; FileEnter: (DE = a file's block) FBlock, FSlot (HL too); disk errors are BASIC's. Keeps DE.
FileEnter:
        ld (FBlock),de
        call BasicEnter
        call FileSlot
        ld (FSlot),hl
        ret

; FileSlot: HL = the FCB of the file of block DE (FileSlots: one for each file number). Keeps BC, DE.
FileSlot:
        push bc
        push de
        ld hl,(FILTAB)
        ld c,0
.find:
        ld a,(hl)
        inc hl
        cp e
        ld a,(hl)
        inc hl
        jr nz,.next
        cp d
        jr z,.found
.next:
        inc c
        jr .find
.found:
        ld a,c
        call SlotOf
        pop de
        pop bc
        ret

; SlotOf: HL = the FCB of file A (1 - 15). Keeps BC.
SlotOf:
        ld hl,FileSlots - FileSlotSize
        ld de,FileSlotSize
        or a
        ret z
.add:
        add hl,de
        dec a
        jr nz,.add
        ret

; BufferAddr: HL = FBlock's buffer.
BufferAddr:
        push de
        ld hl,(FBlock)
        ld de,BlkBuffer
        add hl,de
        pop de
        ret

; RandomAddr: HL = FSlot's random record.
RandomAddr:
        push de
        ld hl,(FSlot)
        ld de,FcbRandom
        add hl,de
        pop de
        ret

; LocAddr: HL = FSlot's LOC (3 bytes).
LocAddr:
        push de
        ld hl,(FSlot)
        ld de,FcbSize
        add hl,de
        pop de
        ret

; ZeroLoc: FSlot's LOC = 0.
ZeroLoc:
        call LocAddr
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

; AddLoc: FSlot's LOC += HL.
AddLoc:
        ex de,hl
        call LocAddr
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        ret

; ReadChunk: up to 256 bytes of FSlot's file into FBlock's buffer. Out: HL = the bytes read (LOC on).
ReadChunk:
        call BufferAddr
        ld (DtaAddr),hl
        ld de,(FSlot)
        ld hl,256
        KERNEL $27
        push hl
        call AddLoc
        pop hl
        ret

; WriteChunk: HL bytes of FBlock's buffer to FSlot's file (LOC on by those written). NZ when the disk is
; full.
WriteChunk:
        push hl
        call BufferAddr
        ld (DtaAddr),hl
        pop hl
        ld de,(FSlot)
        KERNEL $26
        push af
        call AddLoc
        pop af
        or a
        ret

; FillBuffer: FBlock's buffer filled from FSlot's file, 1Ah after the end; FBASIC reads it from its start.
FillBuffer:
        call ReadChunk
        ld a,h
        or a
        jr nz,.loaded
        ld c,l
        ld b,0
        call BufferAddr
        add hl,bc
        ld (hl),$1A
.loaded:
        ld hl,(FBlock)
        ld bc,BlkPosition
        add hl,bc
        ld (hl),0
        inc hl
        ld (hl),1                       ; (BlkLoaded)
        ret

; SeekAppend: FSlot's file read 256 bytes at a time up to a block with a 1Ah or a short one: the file's
; place goes back to that block's start (a block of no bytes: the one before), the buffer's to the 1Ah
; (or the bytes it has). LOC 0.
SeekAppend:
        xor a
        ld (FStart),a
        ld (FStart + 1),a
        ld (FStart + 2),a
.block:
        ld hl,(FSlot)                   ; FPos = where this block starts
        ld bc,FcbRandom
        add hl,bc
        ld de,FPos
        ld bc,3
        ldir
        call ReadChunk                  ; HL = the bytes
        ld a,h
        or l
        jr z,.place                     ; (none: A = 0, the block before)
        push hl
        ld hl,FPos
        ld de,FStart
        ld bc,3
        ldir
        pop bc                          ; BC = the bytes
        push bc
        call BufferAddr
        push hl
        ld a,$1A
        cpir
        pop de
        pop bc
        jr nz,.no1A
        dec hl
        or a
        sbc hl,de
        ld a,l                          ; its place
        jr .place
.no1A:
        ld a,b                          ; a full block: on
        or a
        jr nz,.block
        ld a,c
.place:
        ld hl,(FBlock)
        ld bc,BlkPosition
        add hl,bc
        ld (hl),a
        ld hl,(FSlot)
        ld bc,FcbRandom
        add hl,bc
        ex de,hl
        ld hl,FStart
        ld bc,3
        ldir
        jp ZeroLoc

; CheckOpen: the error A when an open disk file is the file of the FCB at DE (its name may have '?').
CheckOpen:
        ld (FCheckErr),a
        ld (FCheckFcb),de
        ld a,(MAXFIL)
        or a
        ret z
        ld b,a
.file:
        ld a,b
        call BlockOf
        ld a,(hl)
        or a
        jr z,.next
        ld de,BlkDevice
        add hl,de
        ld a,(hl)
        cp $FC
        jr nc,.next
        ld a,b
        call SlotOf
        ld de,(FCheckFcb)
        call SameFile
        jr nz,.next
        ld a,(FCheckErr)
        jp FileError
.next:
        djnz .file
        ret

; SameFile: Z when the FCB at HL is a file the FCB at DE names ('?' any character). Keeps B.
SameFile:
        push bc
        ld a,(de)
        call RealDrive
        ld c,a
        ld a,(hl)
        call RealDrive
        cp c
        jr nz,.done
        ld b,11
.char:
        inc hl
        inc de
        ld a,(de)
        cp '?'
        jr z,.same
        cp (hl)
        jr nz,.done
.same:
        djnz .char
.done:
        pop bc
        ret

; NumberResult: C:HL (0 - 999999) as BASIC's result: an integer when it fits, else single precision.
NumberResult:
        ld a,c
        or a
        jr nz,.single
        bit 7,h
        jr nz,.single
        ld (DAC + 2),hl
        ld a,2
        ld (VALTYP),a
        ret
.single:
        push hl                         ; FDigits: the 6 decimal digits, then 6 zeros
        ld hl,FDigits
        ld b,12
.clear:
        ld (hl),0
        inc hl
        djnz .clear
        pop hl
        ld ix,Powers
        ld de,FDigits
        ld b,6
.digit:
        ld a,l
        sub (ix + 0)
        ld l,a
        ld a,h
        sbc a,(ix + 1)
        ld h,a
        ld a,c
        sbc a,(ix + 2)
        ld c,a
        jr c,.undo
        ex de,hl
        inc (hl)
        ex de,hl
        jr .digit
.undo:
        ld a,l
        add a,(ix + 0)
        ld l,a
        ld a,h
        adc a,(ix + 1)
        ld h,a
        ld a,c
        adc a,(ix + 2)
        ld c,a
        inc ix
        inc ix
        inc ix
        inc de
        djnz .digit
        ld hl,FDigits                   ; the first digit not 0
        ld b,6
.lead:
        ld a,(hl)
        or a
        jr nz,.first
        inc hl
        djnz .lead
.first:
        ld a,b
        add a,$40                       ; the exponent: as many as the digits
        ld de,DAC
        ld (de),a
        inc de
        ld b,3
.pack:
        ld a,(hl)
        inc hl
        rlca
        rlca
        rlca
        rlca
        or (hl)
        inc hl
        ld (de),a
        inc de
        djnz .pack
        ld a,4
        ld (VALTYP),a
        ret
Powers:
        db $A0, $86, $01                ; 100000
        db $10, $27, $00                ; 10000
        db $E8, $03, $00
        db $64, $00, $00
        db $0A, $00, $00
        db $01, $00, $00
