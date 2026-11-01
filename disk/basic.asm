; basic.asm: disk BASIC's statements for programs and whole files: LOAD, MERGE, RUN "name", SAVE, BLOAD,
; BSAVE, FILES, LFILES, KILL, NAME, COPY and DSKF. FBASIC calls them through their hooks (the convention of
; common/diskapi.inc: carry set on the way in, HL on the operand; carry clear when this ROM did the work);
; a name of another device (CAS: and the like) is handed back with the carry still set. They work through
; the kernel (its FCB functions, the block ones with records of one byte) and reach FBASIC through its
; service table. The files: a program is FFh and then its lines as they are in memory (from TXTTAB to
; VARTAB), or text (SAVE ..., A: as LIST shows it, lines ended by CR LF, 1Ah after the last); a binary file
; is FEh, its start, end and run addresses, then the bytes.

; --- the hooks ---

; DiskLoadHook: H_MERG: LOAD "name" [, R], MERGE "name", RUN "name" (C = the statement's token).
DiskLoadHook:
        ld a,c
        ld (BTok),a
        push hl
        ld de,BFcb
        xor a                           ; (no wildcards)
        call TakeName
        jp c,Decline
        pop af
        ld b,0                          ; BFlags: bit 0 a new program, bit 1 run it
        ld a,(BTok)
        cp TkMerge
        jr z,.flags
        ld b,3
        cp TkRun
        jr z,.flags
        ld b,1
        call TextChar
        cp ','
        jr nz,.flags
        call TextNext
        cp 'R'
        jp nz,SyntaxErr
        call TextNext
        ld b,3
.flags:
        ld a,b
        ld (BFlags),a
        call TextChar
        jp nz,SyntaxErr
; LoadFile: the file of BFcb loaded as BTok and BFlags say (AUTOEXEC.BAS comes here).
LoadFile:
        call BasicEnter
        ld de,BFcb
        call OpenFile
        ld de,BTemp                     ; the first byte says what it is
        ld hl,1
        call ReadBytes
        ld a,h
        or l
        ld a,$1A                        ; (empty: an empty text)
        jr z,.ascii
        ld a,(BTemp)
        cp $FE
        jp z,BadFileMode                ; (a binary file)
        cp $FF
        jr nz,.ascii
        ld a,(BTok)                     ; a program as it is in memory (MERGE takes only text)
        cp TkMerge
        jp z,BadFileMode
        ld a,(BFcb + FcbSize_ + 2)
        ld hl,BFcb + FcbSize_ + 3
        or (hl)
        jp nz,OutOfMemory
        ld hl,(BFcb + FcbSize_)
        dec hl
        push hl                         ; the bytes after FFh
        ld hl,-256                      ; the room: up to 256 bytes under the stack
        add hl,sp
        ld de,(TXTTAB)
        or a
        sbc hl,de
        pop de
        jp c,OutOfMemory
        sbc hl,de
        jp c,OutOfMemory
        push de
        FBASIC SrvNewProgram
        pop hl
        ld de,(TXTTAB)
        call ReadBytes
        FBASIC SrvProgramLoaded
        jp LoadDone
.ascii:
        push af
        ld a,(BFlags)
        rrca
        jr nc,.keep
        FBASIC SrvNewProgram
.keep:
        ld hl,BUF
        ld (BLine),hl
        ld hl,0
        ld (BLeft),hl
        pop af
        jr .char
.block:
        ld de,BBuf
        ld hl,256
        call ReadBytes
        ld a,h
        or l
        jr z,.end
        ld (BLeft),hl
        ld hl,BBuf
        ld (BPtr),hl
.next:
        ld hl,(BLeft)
        ld a,h
        or l
        jr z,.block
        dec hl
        ld (BLeft),hl
        ld hl,(BPtr)
        ld a,(hl)
        inc hl
        ld (BPtr),hl
.char:
        cp $1A
        jr z,.end
        cp $0A
        jr z,.next
        cp $0D
        jr z,.line
        ld hl,(BLine)
        ld de,BUF + 255                 ; (a longer line: the rest is left out)
        or a
        sbc hl,de
        jr nc,.next
        add hl,de
        ld (hl),a
        inc hl
        ld (BLine),hl
        jr .next
.line:
        ld hl,(BLine)
        FBASIC SrvAsciiLine
        ld hl,BUF
        ld (BLine),hl
        jr .next
.end:
        ld hl,(BLine)                   ; the last line (if it had no CR)
        FBASIC SrvAsciiLine
LoadDone:
        ld a,(BFlags)
        and 2
        jr z,.ready
        FBASIC SrvRunLoaded
.ready:
        FBASIC SrvReady

; DiskSaveHook: H_SAVE: SAVE "name" [, A].
DiskSaveHook:
        xor a
        ld (BSaving),a
        push hl
        ld de,BFcb
        xor a
        call TakeName
        jp c,Decline
        pop af
        ld b,0
        call TextChar
        cp ','
        jr nz,.flags
        call TextNext
        cp 'A'
        jp nz,SyntaxErr
        call TextNext
        ld b,1
.flags:
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        ld a,b
        ld (BFlags),a
        call BasicEnter
        ld de,BFcb
        call CreateFile
        ld a,(BFlags)
        or a
        jr nz,.text
        ld a,$FF                        ; FFh, then the program as it is
        ld (BTemp),a
        ld de,BTemp
        ld hl,1
        call WriteBytes
        ld hl,(VARTAB)
        ld de,(TXTTAB)
        or a
        sbc hl,de
        call WriteBytes
        call CloseBFcb
        ld hl,(BText)
        or a
        ret
.text:
        ld a,1                          ; the listing, through H_SAVD (SaveFlushHook)
        ld (BSaving),a
        ld hl,BBuf
        FBASIC SrvListToBuffer
        xor a
        ld (BSaving),a
        ld (hl),$1A
        inc hl
        ld de,BBuf
        or a
        sbc hl,de
        call WriteBytes
        call CloseBFcb
        FBASIC SrvReady                 ; (as the original: the program stops)

; SaveFlushHook: H_SAVD: while SAVE writes text here, the 256 characters at HL to the file.
SaveFlushHook:
        ld a,(BSaving)
        or a
        scf
        ret z
        ex de,hl
        ld hl,256
        call WriteBytes
        or a
        ret

; DiskBsaveHook: H_BINS: BSAVE "name", start, end [, run address] [, S] (S: from the VRAM).
DiskBsaveHook:
        push hl
        ld de,BFcb
        xor a
        call TakeName
        jp c,Decline
        pop af
        call Comma
        FBASIC SrvEvalAddress
        ld (BStart),de
        ld (BExec),de
        call Comma
        FBASIC SrvEvalAddress
        ld (BEnd),de
        xor a
        ld (BVram),a
        call TextChar
        cp ','
        jr nz,.write
        call TextNext
        call OptionLetter
        cp 'S'
        jr z,.vram
        FBASIC SrvEvalAddress
        ld (BExec),de
        call TextChar
        cp ','
        jr nz,.write
        call TextNext
        call OptionLetter
        cp 'S'
        jp z,IllegalFunction            ; (a run address and S: not together, as the original)
        jp SyntaxErr
.vram:
        call TextNext
        ld a,1
        ld (BVram),a
.write:
        call TextChar                   ; (nothing more: checked before the file is made)
        jp nz,SyntaxErr
        ld (BText),hl
        ld a,(BVram)                    ; the RAM from 8000h only (the original's rule: pages 2 and 3)
        or a
        jr nz,.range
        ld a,(BStart + 1)
        cp $80
        jp c,IllegalFunction
.range:
        call BasicEnter
        call BinaryLength
        ld de,BFcb
        call CreateFile
        ld a,$FE
        ld (BHeader),a
        ld de,BHeader
        ld hl,7
        call WriteBytes
        ld a,(BVram)
        or a
        jr nz,.fromVram
        ld de,(BStart)
        ld hl,(BLength)
        call WriteBytes
        jr .done
.fromVram:
        call VramChunk                  ; BC = the next chunk (0: none)
        jr z,.done
        push bc
        ld hl,(BStart)
        ld de,BBuf
        ld ix,LDIRMV
        call CallBios
        pop hl
        push hl
        ld de,BBuf
        call WriteBytes
        pop bc
        call VramChunkDone
        jr .fromVram
.done:
        call CloseBFcb
        ld hl,(BText)
        or a
        ret

; DiskBloadHook: H_BINL: BLOAD "name" [, R] [, S] [, offset] (R: then run it; S: into the VRAM).
DiskBloadHook:
        push hl
        ld de,BFcb
        xor a
        call TakeName
        jp c,Decline
        pop af
        xor a
        ld (BVram),a
        ld (BRun),a
        ld de,0
        ld (BOffset),de
.option:
        call TextChar
        cp ','
        jr nz,.load
        call TextNext
        call OptionLetter
        cp 'R'
        jr z,.run
        cp 'S'
        jr z,.vram
        FBASIC SrvEvalAddress
        ld (BOffset),de
        jr .option
.run:
        call TextNext
        ld a,1
        ld (BRun),a
        jr .option
.vram:
        call TextNext
        ld a,1
        ld (BVram),a
        jr .option
.load:
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        call BasicEnter
        ld de,BFcb
        call OpenFile
        ld de,BHeader
        ld hl,7
        call ReadBytes
        ld de,7
        or a
        sbc hl,de
        jp nz,BadFileMode
        ld a,(BHeader)
        cp $FE
        jp nz,BadFileMode
        ld de,(BOffset)                 ; the addresses moved by the offset
        ld hl,(BStart)
        add hl,de
        ld (BStart),hl
        ld hl,(BEnd)
        add hl,de
        ld (BEnd),hl
        ld hl,(BExec)
        add hl,de
        ld (BExec),hl
        call BinaryLength
        ld a,(BVram)
        or a
        jr nz,.toVram
        ld de,(BStart)
        ld hl,(BLength)
        call ReadBytes
        jr .loaded
.toVram:
        call VramChunk
        jr z,.loaded
        push bc
        ld h,b
        ld l,c
        ld de,BBuf
        call ReadBytes
        pop bc
        push bc
        ld hl,BBuf
        ld de,(BStart)
        ld ix,LDIRVM
        call CallBios
        pop bc
        call VramChunkDone
        jr .toVram
.loaded:
        ld a,(BRun)
        or a
        jr z,.back
        ld ix,(BExec)                   ; ,R: with BASIC's ROM in page 1, as BLOAD from the tape
        call ResFbasic
.back:
        ld hl,(BText)
        or a
        ret

; BinaryLength: BLength = BEnd - BStart + 1 (Illegal function call when the end is under the start).
BinaryLength:
        ld hl,(BEnd)
        ld de,(BStart)
        or a
        sbc hl,de
        jp c,IllegalFunction
        inc hl
        ld (BLength),hl
        ret

; VramChunk: BC = the next piece (256 bytes at most) of BLength; Z when nothing is left.
VramChunk:
        ld bc,(BLength)
        ld a,b
        or c
        ret z
        ld a,b
        or a
        jr z,.small
        ld bc,256
.small:
        or $FF                          ; NZ
        ret
; VramChunkDone: BC bytes done: BStart on, BLength down.
VramChunkDone:
        ld hl,(BStart)
        add hl,bc
        ld (BStart),hl
        ld hl,(BLength)
        or a
        sbc hl,bc
        ld (BLength),hl
        ret

; DiskFilesHook: H_FILE: FILES ["name"] and LFILES ["name"] (C = the token): the names that match (all
; without one), as many on a line as fit (12 characters and a space each).
DiskFilesHook:
        ld a,c
        ld (BTok),a
        call TextChar
        jr nz,.name
        push hl
        ld hl,BFcb                      ; every file of the default drive
        ld b,0
        ld a,3
        call ParseName
        pop hl
        jr .list
.name:
        ld de,BFcb
        ld a,3
        call TakeName
        jp c,BadFileName                ; (anything after it: Syntax error once listed, as the original)
.list:
        ld (BText),hl
        call BasicEnter
        ld a,(BTok)
        cp TkLfiles
        ld a,80 + 1
        jr z,.printer
        ld a,(LINLEN)
        inc a
.printer:
        ld b,0                          ; B = the names a line takes
.perLine:
        inc b
        sub 13
        jr nc,.perLine
        dec b
        jr nz,.some
        inc b
.some:
        ld a,b
        ld (BPerLine),a
        ld a,(BTok)
        cp TkLfiles
        jr nz,.screen
        ld a,1
        ld (PRTFLG),a
.screen:
        xor a
        ld (BColumn),a
        ld hl,BBuf
        ld (DtaAddr),hl
        ld de,BFcb
        KERNEL $11
        inc a
        jp z,FileNotFound
        call NewLineIfNeeded            ; (from the start of a line)
.entry:
        ld hl,BBuf + 1
        ld b,8
.nameChar:
        ld a,(hl)
        rst $18
        inc hl
        djnz .nameChar
        ld a,(hl)                       ; "." when it has an extension
        cp ' '
        jr nz,.dot
        inc hl
        ld a,(hl)
        dec hl
        cp ' '
        jr nz,.dot
        inc hl
        inc hl
        ld a,(hl)
        dec hl
        dec hl
        cp ' '
        ld a,' '
        jr z,.ext
.dot:
        ld a,'.'
.ext:
        rst $18
        ld b,3
.extChar:
        ld a,(hl)
        rst $18
        inc hl
        djnz .extChar
        ld hl,BColumn                   ; a space after it, or the line ends
        inc (hl)
        ld a,(BPerLine)
        cp (hl)
        jr z,.lineFull
        ld a,' '
        rst $18
        jr .nextName
.lineFull:
        ld (hl),0
        call NewLineIfNeeded
.nextName:
        KERNEL $12
        inc a
        jr nz,.entry
        xor a
        ld (PRTFLG),a
        ld hl,(BText)
        or a
        ret

; DiskKillHook: H_KILL: KILL "name" (wildcards: every file that matches).
DiskKillHook:
        push hl
        ld de,BFcb
        ld a,1
        call TakeName
        jp c,Decline
        pop af
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        ld de,BFcb                      ; (an open file: File still open)
        ld a,ErrFileStillOpen
        call CheckOpen
        call BasicEnter
        ld de,BFcb
        KERNEL $13
        inc a
        jp z,FileNotFound
        ld hl,(BText)
        or a
        ret

; DiskNameHook: H_NAME: NAME "old" AS "new" (on the same drive).
DiskNameHook:
        push hl
        ld de,BFcb
        ld a,1
        call TakeName
        jp c,Decline
        pop af
        call TextChar
        cp 'A'
        jp nz,SyntaxErr
        call TextNext
        cp 'S'
        jp nz,SyntaxErr
        call TextNext
        ld de,BFcb2
        ld a,1
        call TakeName
        jp c,BadFileName
        ld (BText),hl                   ; (anything after it: Syntax error once renamed, as the original)
        ld a,(BFcb)
        call RealDrive
        ld b,a
        ld a,(BFcb2)
        or a
        jr z,.sameDrive
        call RealDrive
        cp b
        jp nz,RenameAcross
.sameDrive:
        ld a,(BFcb)
        ld (BFcb2),a
        ld de,BFcb                      ; (an open file: File still open)
        ld a,ErrFileStillOpen
        call CheckOpen
        call BasicEnter
        ld hl,BBuf
        ld (DtaAddr),hl
        ld de,BFcb                      ; the old one must be there
        KERNEL $11
        inc a
        jp z,FileNotFound
        ld de,BFcb2                     ; the new one must not
        KERNEL $11
        inc a
        jp nz,FileExists
        ld hl,BFcb2 + 1
        ld de,BFcb + FcbNewName
        ld bc,11
        ldir
        ld de,BFcb
        KERNEL $17
        inc a
        jp z,FileNotFound
        ld hl,(BText)
        or a
        ret

; DiskCopyHook: H_COPY: COPY "name" TO "name" (wildcards in both: "?" in the new name keeps the old
; name's character; a drive alone: the same names). Other forms of COPY (the screen's) go back to FBASIC.
DiskCopyHook:
        ld (BText),hl
        call TextChar
        cp '"'
        jr z,.string
        call IsLetter                   ; a string variable?
        jr c,.declined
.ident:
        inc hl
        ld a,(hl)
        call IsLetter
        jr nc,.ident
        cp '0'
        jr c,.notDigit
        cp '9' + 1
        jr c,.ident
.notDigit:
        cp '$'
        jr nz,.declined
.string:
        ld hl,(BText)
        ld de,BFcb
        ld a,1
        call TakeName
        jr c,.declined
        call TextChar
        cp TkTo
        jp nz,SyntaxErr
        call TextNext
        cp '('
        jr z,.declined
        ld de,BFcb2
        ld a,3
        call TakeName
        jp c,BadFileName
        call TextChar
        jp nz,SyntaxErr
        ld (BText),hl
        jp CopyFiles
.declined:
        ld hl,(BText)
        scf
        ret

; CopyFiles: the files that match BFcb copied as BFcb2 says (the names are gathered first, in the free
; memory over the variables; the rest of it, up to 512 bytes under the stack, is the buffer).
CopyFiles:
        call BasicEnter
        ld hl,BFcb2                     ; the new names' drive and pattern
        ld de,BCopyTo
        ld bc,12
        ldir
        ld a,(BCopyTo)
        or a
        jr nz,.toDrive
        ld a,(BFcb)
.toDrive:
        ld (BCopyTo),a
        ld a,(BFcb)
        ld (BCopyFrom),a
        ld hl,(STREND)
        ld (BList),hl
        ld (BPtr),hl
        ld hl,BBuf
        ld (DtaAddr),hl
        ld de,BFcb
        KERNEL $11
        inc a
        jp z,FileNotFound
.gather:
        ld hl,BBuf + 1
        ld de,(BPtr)
        ld bc,11
        ldir
        ld (BPtr),de
        call FreeUnder                  ; HL = the room left (carry: none)
        jp c,OutOfMemory
        KERNEL $12
        inc a
        jr nz,.gather
        call FreeUnder
        jp c,OutOfMemory
        ld de,512
        or a
        sbc hl,de
        jp c,OutOfMemory
        ld a,h                          ; (32K at most)
        cp $80
        jr c,.size
        ld hl,$8000
.size:
        ld (BBufSize),hl
.file:
        ld hl,(BList)
        ld de,(BPtr)
        or a
        sbc hl,de
        jp z,.done
        ld hl,BFcb                      ; the old file
        call ClearFcb
        ld a,(BCopyFrom)
        ld (BFcb),a
        ld hl,(BList)
        ld de,BFcb + 1
        ld bc,11
        ldir
        ld hl,BFcb2                     ; the new one
        call ClearFcb
        ld a,(BCopyTo)
        ld (BFcb2),a
        ld hl,(BList)
        ld de,BCopyTo + 1
        ld ix,BFcb2 + 1
        ld b,11
.newChar:
        ld a,(de)
        cp '?'
        jr nz,.given
        ld a,(hl)
.given:
        ld (ix),a
        inc hl
        inc de
        inc ix
        djnz .newChar
        ld (BList),hl
        ld a,(BFcb)                     ; a file onto itself: Illegal function call (as the original)
        call RealDrive
        ld b,a
        ld a,(BFcb2)
        call RealDrive
        cp b
        jr nz,.copy
        ld hl,BFcb + 1
        ld de,BFcb2 + 1
        ld b,11
.same:
        ld a,(de)
        cp (hl)
        jr nz,.copy
        inc hl
        inc de
        djnz .same
        jp IllegalFunction
.copy:
        ld de,BFcb
        call OpenFile
        ld de,BFcb2
        call CreateFile
.chunk:
        ld de,(BPtr)                    ; (the buffer: past the names)
        ld hl,(BBufSize)
        call ReadBytes
        ld a,h
        or l
        jr z,.closed
        push hl
        ld de,(BPtr)
        ld ix,BFcb2
        call WriteBytesTo
        pop hl
        ld de,(BBufSize)
        or a
        sbc hl,de
        jr z,.chunk
.closed:
        ld de,BFcb2
        KERNEL $10
        jp .file
.done:
        ld hl,(BText)
        or a
        ret

; FreeUnder: HL = the bytes from BPtr up to 512 under the stack; carry when there are none.
FreeUnder:
        ld hl,-512
        add hl,sp
        ld de,(BPtr)
        or a
        sbc hl,de
        ret

; DiskDskfHook: H_DSKF: DSKF(drive): the free clusters of the drive (0 the default one) as an integer.
DiskDskfHook:
        call TextChar
        cp '('
        jp nz,SyntaxErr
        call TextNext
        FBASIC SrvEvalByte
        push af
        call TextChar
        cp ')'
        jp nz,SyntaxErr
        call TextNext
        ld (BText),hl
        pop af
        ld e,a
        ld a,(LogDrives)
        cp e
        jp c,BadDriveName
        call BasicEnter
        KERNEL $1B
        ld (DAC + 2),hl
        ld a,2
        ld (VALTYP),a
        ld hl,(BText)
        or a
        ret

; Decline: (the stack: the text where the statement's operand starts) not a disk's file: back to FBASIC
; with the carry set and HL there.
Decline:
        pop hl
        scf
        ret

; --- names ---

; TakeName: a file name (a string expression at HL) into the FCB at DE; A: bit 0 wildcards may be in it,
; bit 1 no name stands for every file. Out: HL past the expression; carry when the name is another
; device's (not a disk's).
TakeName:
        push de
        push af
        FBASIC SrvEvalString
        ld (BNameText),hl
        pop af
        pop hl
        call ParseName
        ld hl,(BNameText)
        ret

; ParseName: the name at DE (B characters: [drive:]name[.ext]) into the FCB at HL (cleared first); A as
; TakeName says. Out: carry for a device's name ("XYZ:..."). Bad file name or Bad drive name otherwise.
ParseName:
        ld (BNameFlags),a
        call ClearFcb
        push de
        push bc
        ld c,0                          ; a ':' past the second character: a device
        ld a,b
        or a
        jr z,.notDevice
.colon:
        ld a,(de)
        cp ':'
        jr nz,.nextColon
        ld a,c
        cp 2
        jr nc,.device
.nextColon:
        inc de
        inc c
        djnz .colon
.notDevice:
        pop bc
        pop de
        ld a,b
        cp 2
        jr c,.name
        inc de
        ld a,(de)
        dec de
        cp ':'
        jr nz,.name
        ld a,(de)                       ; the drive's letter
        call UpperA
        sub 'A'
        jp c,BadFileName
        cp 8
        jp nc,BadFileName
        inc a
        ld c,a
        ld a,(LogDrives)
        cp c
        jp c,BadDriveName
        ld (hl),c
        inc de
        inc de
        dec b
        dec b
.name:
        push hl
        inc hl
        ld c,8
        call NamePart
        pop hl
        ld a,c
        cp 8
        jr nz,.taken
        ld a,b                          ; no name: only "every file", when it may be
        or a
        jp nz,BadFileName
        ld a,(BNameFlags)
        and 2
        jp z,BadFileName
        push hl
        inc hl
        ld b,11
.all:
        ld (hl),'?'
        inc hl
        djnz .all
        pop hl
        or a
        ret
.taken:
        ld a,b
        or a
        ret z                           ; (no carry)
        ld a,(de)
        cp '.'
        jr z,.dot
        jr .extension                   ; 8 characters and more with no '.': they are the extension (as the
                                        ; original: TOOLONGNAME is TOOLONGN.AME)
.dot:
        inc de                          ; the '.'
        dec b
.extension:
        push bc
        ld bc,9
        add hl,bc
        pop bc
        ld c,3
        call NamePart
        ld a,b
        or a
        ret z
        ld a,c                          ; the extension full: the rest is left out (AB.CDEF, AB.CDE.F are
        or a                            ; AB.CDE); a '.' before that: bad (X.Y.Z)
        ret z
        jp BadFileName
.device:
        pop bc
        pop de
        scf
        ret

; NamePart: up to C characters from DE (B left) into HL, up to a '.', the end, or C of them; '*' fills the
; rest with '?'. Out: C = the room left, DE and B on the '.', the end, or the first character not taken.
NamePart:
        ld a,b
        or a
        ret z
        ld a,(de)
        cp '.'
        ret z
        call UpperA
        cp '*'
        jr z,.star
        cp '?'
        jr z,.wild
        call BadChar
        jp c,BadFileName
.put:
        inc c
        dec c
        ret z                           ; full (DE on the character not taken)
        ld (hl),a
        inc hl
        dec c
        inc de
        dec b
        jr NamePart
.wild:
        call Wildcards
        jr .put
.star:
        call Wildcards
.fill:
        inc c
        dec c
        jr z,.skip
        ld (hl),'?'
        inc hl
        dec c
        jr .fill
.skip:
        inc de                          ; the rest of this part is left out
        dec b
        ret z
        ld a,(de)
        cp '.'
        jr nz,.skip
        ld c,1                          ; (on a '.': not "full", A*.*.* is bad)
        ret

; Wildcards: Bad file name unless the name may have them.
Wildcards:
        push af
        ld a,(BNameFlags)
        rrca
        jp nc,BadFileName
        pop af
        ret

; BadChar: carry when A cannot be in a name.
BadChar:
        cp ' ' + 1
        ret c
        push hl
        push bc
        ld hl,BadChars
        ld b,BadCharsEnd - BadChars
.compare:
        cp (hl)
        scf
        jr z,.done
        inc hl
        djnz .compare
        or a
.done:
        pop bc
        pop hl
        ret
BadChars:
        db '"', '.', '/', '\\', '[', ']', ':', ';', ',', '=', '+', '<', '>', '|', $7F
BadCharsEnd:

; UpperA: A in upper case (letters).
UpperA:
        cp 'a'
        ret c
        cp 'z' + 1
        ret nc
        sub $20
        ret

; IsLetter: carry when A is not a letter (A-Z, a-z).
IsLetter:
        push af
        call UpperA
        cp 'A'
        jr c,.no
        cp 'Z' + 1
        ccf
.no:
        pop bc                          ; (A back, the carry kept)
        ld a,b
        ret

; ClearFcb: the FCB at HL: zeros, its name spaces. Keeps BC, DE, HL.
ClearFcb:
        push hl
        push bc
        ld b,FcbSize
.zero:
        ld (hl),0
        inc hl
        djnz .zero
        pop bc
        pop hl
        push hl
        push bc
        inc hl
        ld b,11
.space:
        ld (hl),' '
        inc hl
        djnz .space
        pop bc
        pop hl
        ret

; RealDrive: A = the drive of an FCB's drive byte A (0: the default one), counted from 1.
RealDrive:
        or a
        ret nz
        ld a,(CurDrive)
        inc a
        ret

; --- the files ---

; OpenFile: the file of the FCB at DE opened for the block functions (records of 1 byte, from the start).
; File not found.
OpenFile:
        push de
        KERNEL $0F
        pop de
        inc a
        jp z,FileNotFound
        jr ByteRecords
; CreateFile: the file of the FCB at DE made (emptied when it was there). Too many files when it cannot
; be (the directory is full).
CreateFile:
        push de
        KERNEL $16
        pop de
        inc a
        jp z,TooManyFiles               ; (the directory is full)
ByteRecords:
        ld hl,FcbRecSize
        add hl,de
        ld (hl),1
        inc hl
        ld (hl),0
        ld hl,FcbRandom
        add hl,de
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ret

; ReadBytes: HL bytes of BFcb's file to DE. Out: HL = the bytes read (fewer at its end).
ReadBytes:
        ld (DtaAddr),de
        ld de,BFcb
        KERNEL $27
        ret

; WriteBytes: HL bytes from DE to BFcb's file (none: nothing). WriteBytesTo: to IX's. Disk full.
WriteBytes:
        ld ix,BFcb
WriteBytesTo:
        ld a,h
        or l
        ret z
        ld (DtaAddr),de
        push ix
        pop de
        KERNEL $26
        or a
        jp nz,DiskFull
        ret

; CloseBFcb: BFcb's file closed (its directory entry and the FAT written).
CloseBFcb:
        ld de,BFcb
        KERNEL $10
        ret

; --- the BASIC text (in the RAM) ---

; TextChar: A = the character at HL, past spaces (HL on it); Z at the statement's end (0 or ':').
; TextNext: from the next one.
TextNext:
        inc hl
TextChar:
        ld a,(hl)
        cp ' '
        jr z,TextNext
        or a
        ret z
        cp ':'
        ret

; Comma: a ',' must be there (Syntax error); HL past it.
Comma:
        call TextChar
        cp ','
        jp nz,SyntaxErr
        jr TextNext

; OptionLetter: A = the character at HL when it stands alone (a ',' or the statement's end after it: an
; option such as R or S), else 0 (an expression is there). HL stays on it.
OptionLetter:
        call TextChar
        push hl
        ld c,a
        call TextNext
        pop hl
        jr z,.alone
        cp ','
        jr z,.alone
        xor a
        ret
.alone:
        ld a,c
        ret

; NewLineIfNeeded: CR LF through OUTDO, unless the cursor (the printer's head, while PRTFLG is set) is at
; the start of a line already (a line just as wide as the screen moves the cursor down by itself).
NewLineIfNeeded:
        ld a,(PRTFLG)
        or a
        jr z,.screen
        ld a,(LPTPOS)
        or a
        ret z
        jr NewLine
.screen:
        ld a,(CSRX)
        dec a
        ret z
; NewLine: CR LF through OUTDO.
NewLine:
        ld a,13
        rst $18
        ld a,10
        rst $18
        ret

; --- errors ---

; BasicEnter: a disk error from here on is a BASIC error (BasicDiskError).
BasicEnter:
        ld hl,BasicDiskVe
        ld (DISKVE),hl
        ret
BasicDiskVe:
        dw BasicDiskError

; BasicDiskError: (the kernel's disk error handler while BASIC works with the disk) C = the error's code
; (bit 0: in a write): Disk write protected, Disk offline or Disk I/O error. The kernel's buffers and its
; call are given up.
BasicDiskError:
        ld a,c
        and $FE
        ld e,ErrWriteProtected
        jr z,.forget
        ld e,ErrDiskOffline
        cp 2
        jr z,.forget
        ld e,ErrDiskIO
.forget:
        ld a,$FF
        ld (FatDrive),a
        ld (DataDrive),a
        ld (DirDrive),a
        xor a
        ld (FatDirty),a
        ld (DataDirty),a
        ld (KDepth),a
        jr BasicError

SyntaxErr:        ld e,ErrSyntax : jr BasicError
IllegalFunction:  ld e,ErrIllegal : jr BasicError
OutOfMemory:      ld e,ErrOutOfMemory : jr BasicError
FileNotFound:     ld e,ErrFileNotFound : jr BasicError
BadFileName:      ld e,ErrBadFileName : jr BasicError
BadFileMode:      ld e,ErrBadFileMode : jr BasicError
BadDriveName:     ld e,ErrBadDriveName : jr BasicError
FileExists:       ld e,ErrFileExists : jr BasicError
DiskFull:         ld e,ErrDiskFull : jr BasicError
TooManyFiles:     ld e,ErrTooManyFiles : jr BasicError
TypeMismatch:     ld e,ErrTypeMismatch : jr BasicError
FieldOverflow:    ld e,ErrFieldOverflow : jr BasicError
RenameAcross:     ld e,ErrRenameAcross
; BasicError: BASIC's error E (does not come back).
BasicError:
        xor a
        ld (BSaving),a
        ld (PRTFLG),a                   ; (LFILES: the message on the screen)
        FBASIC SrvRaiseError
