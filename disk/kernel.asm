; kernel.asm: the DOS kernel's functions (the published function calls 00h-30h, compatible with the first
; version of the disk system and with CP/M 2.2's): entered through BDOS (F37Dh), C = the function. The
; console's, the date's and time's, and the disk's settings are here; the files are in disk/files.asm, the
; disk's structures in disk/fat.asm. The kernel runs on a stack of its own (under HIMEM) with the interrupts
; on.

; KernelEntry: C = the function; DE, HL (and A, B) as it says. Out: as it says. The kernel may be entered
; again while it works (a disk error handler reads a key through it): the inner call stays on the kernel's
; stack, where it is, and keeps the outer call's stack pointer (KUserSP) on it.
KernelEntry:
        ei
        ld (KEntrySP),sp
        xor a                           ; the system file's flag at F306h: 0, so it gives back HL as the
        ld (DosScratch + 2),a           ; function leaves it (not B and A: the results here fill both ways)
        ld a,(KDepth)
        inc a
        ld (KDepth),a
        dec a
        jr nz,.inner
        ld sp,(KStackTop)
.inner:
        push hl
        ld hl,(KUserSP)                 ; the outer call's, kept
        ex (sp),hl
        push hl
        ld hl,(KEntrySP)
        ld (KUserSP),hl
        ld hl,KernelExit
        ex (sp),hl                      ; the functions return to KernelExit
        push hl
        ld a,c
        cp BdosFunctions
        jr nc,.none
        ld l,a
        ld h,0
        add hl,hl
        push de
        ld de,BdosTable
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ex (sp),hl                      ; the function's address on the stack, HL back
        ret
.none:
        pop hl
        jp BdosNothing

; KernelExit: back to the caller (A, BC, DE, HL, IX, IY and the flags as the function left them).
KernelExit:
        push af
        ld a,(KDepth)
        dec a
        ld (KDepth),a
        pop af
        ex (sp),hl                      ; HL = the outer call's stack pointer, the result's HL kept
        push hl
        ld hl,(KUserSP)
        ld (KEntrySP),hl                ; (this call's)
        pop hl
        ld (KUserSP),hl
        pop hl
        ld sp,(KEntrySP)
        ret

; KernelAbort: a function given up (a disk error aborted): to the abort handler BREAKV points to, when there
; is one (the system file's restarts its command interpreter); else A = FFh to the caller of the outermost
; call.
KernelAbort:
        xor a
        ld (KDepth),a
        ld hl,(BREAKV)
        ld a,h
        or l
        jr z,.none
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
.none:
        ld a,$FF
        ld l,a
        ld h,a
        ld b,a
        ld sp,(KUserSP)
        ret

BdosTable:
        dw BdosReset                    ; 00h terminate
        dw ConsoleIn                    ; 01h console input (shown)
        dw ConsoleOut                   ; 02h console output (E)
        dw AuxInput                     ; 03h auxiliary input
        dw BdosNothing                  ; 04h auxiliary output
        dw PrinterOut                   ; 05h printer output (E)
        dw DirectConsole                ; 06h direct console I/O (E = FFh: input)
        dw RawIn                        ; 07h direct input
        dw RawIn                        ; 08h input, not shown
        dw PrintString                  ; 09h the text at DE, ended by "$"
        dw LineInput                    ; 0Ah buffered line input at DE
        dw ConsoleStatus                ; 0Bh console status
        dw Version                      ; 0Ch version number
        dw DiskReset                    ; 0Dh disk reset
        dw SelectDisk                   ; 0Eh select disk (E)
        dw FcbOpen                      ; 0Fh open file
        dw FcbClose                     ; 10h close file
        dw SearchFirst                  ; 11h search for the first
        dw SearchNext                   ; 12h search for the next
        dw FcbDelete                    ; 13h delete file
        dw SeqRead                      ; 14h sequential read
        dw SeqWrite                     ; 15h sequential write
        dw FcbCreate                    ; 16h create file
        dw FcbRename                    ; 17h rename file
        dw LoginVector                  ; 18h login vector
        dw CurrentDrive                 ; 19h current drive
        dw SetDta                       ; 1Ah set the disk transfer address
        dw AllocInfo                    ; 1Bh allocation information
        dw BdosNothing                  ; 1Ch
        dw BdosNothing                  ; 1Dh
        dw BdosNothing                  ; 1Eh
        dw BdosNothing                  ; 1Fh
        dw BdosNothing                  ; 20h
        dw RandomRead                   ; 21h random read
        dw RandomWrite                  ; 22h random write
        dw FileSize                     ; 23h file size
        dw SetRandomRecord              ; 24h set the random record
        dw BdosNothing                  ; 25h
        dw BlockWrite                   ; 26h random block write
        dw BlockRead                    ; 27h random block read
        dw RandomWriteZero              ; 28h random write with zero fill
        dw BdosNothing                  ; 29h
        dw GetDate                      ; 2Ah get date
        dw SetDate                      ; 2Bh set date
        dw GetTime                      ; 2Ch get time
        dw SetTime                      ; 2Dh set time
        dw SetVerify                    ; 2Eh set the verify flag
        dw AbsoluteRead                 ; 2Fh absolute sector read
        dw AbsoluteWrite                ; 30h absolute sector write
BdosFunctions   equ ($ - BdosTable) / 2

; ResultA: L = A, H = 0, B = 0 (as CP/M returns a byte). ResultHL: A = L, B = H.
ResultA:
        ld l,a
        ld h,0
        ld b,h
        ret
ResultHL:
        ld a,l
        ld b,h
        ret

BdosNothing:
        xor a
        jr ResultA

; 00h: under BASIC, nothing more than a disk reset.
BdosReset:
        call DiskReset
        xor a
        jr ResultA

; --- the console (through the BIOS) ---

ConsoleIn:
        call WaitKeyBreak
        push af
        call ShowChar
        pop af
        jr ResultA

ConsoleOut:
        call OutputBreak
        ld a,e
        call ShowChar
        xor a
        jr ResultA

AuxInput:
        ld a,$1A                        ; (no auxiliary device: the end of a text)
        jr ResultA

PrinterOut:
        ld a,e
        ld ix,LPTOUT
        call CallBios
        xor a
        jr ResultA

DirectConsole:
        ld a,e
        inc a
        jr z,.input
        ld a,e
        call ShowChar
        xor a
        jr ResultA
.input:
        ld ix,CHSNS
        call CallBios
        jr z,ResultA                    ; (A = 0: no key)
RawIn:
        call WaitKey
        jr ResultA

ConsoleStatus:
        ld ix,CHSNS
        call CallBios
        ld a,0
        jr z,ResultA
        dec a
        jr ResultA

; WaitKeyBreak: as WaitKey, but CTRL+C shows "^C" (no new line, as the original) and gives the function up (KernelAbort: the abort handler).
WaitKeyBreak:
        call WaitKey
        cp 3
        ret nz
.ctrlC:
        ld a,'^'
        call ShowChar
        ld a,'C'
        call ShowChar
        jp KernelAbort                  ; (no new line: the program that takes the abort gives it)

; OutputBreak: before a character is shown: a CTRL+C waiting gives the function up (as WaitKeyBreak), a
; CTRL+S waits for a key (CTRL+C then too). Other keys stay in the buffer. Keeps AF, BC, DE, HL.
OutputBreak:
        push af
        push hl
        ld hl,(GETPNT)
        ld a,(PUTPNT)
        cp l
        jr nz,.key
        ld a,(PUTPNT + 1)
        cp h
        jr z,.none
.key:
        ld a,(hl)                       ; (looked at, not taken)
        cp 3
        jr z,.take
        cp 19
        jr nz,.none
        call WaitKey                    ; CTRL+S taken: a key
        call WaitKey
        cp 3
        jr z,.break
.none:
        pop hl
        pop af
        ret
.take:
        call WaitKey
.break:
        pop hl
        pop af
        jp WaitKeyBreak.ctrlC

; WaitKey: A = the next key (CHGET). ShowChar: A on the screen (CHPUT). Both keep BC, DE, HL.
WaitKey:
        push hl
        push de
        push bc
        ld ix,CHGET
        call CallBios
        pop bc
        pop de
        pop hl
        ret
ShowChar:
        push hl
        push de
        push bc
        ld ix,CHPUT
        call CallBios
        pop bc
        pop de
        pop hl
        ret

; 09h: the text at DE up to "$".
PrintString:
        ex de,hl
.next:
        call ReadUserByte
        cp '$'
        jr z,.done
        call OutputBreak
        call ShowChar
        inc hl
        jr .next
.done:
        xor a
        jp ResultA

; 0Ah: a line typed into the buffer at DE: [DE] = its size, [DE + 1] = the characters typed, then them,
; then a CR when there is room for it. BS takes the last one away; RETURN ends it.
LineInput:
        ld (KUser),de
        ex de,hl
        call ReadUserByte               ; the size
        ld c,a
        call GatherLine
        jr LineInputDone

; GatherLine: a line typed (C = the most characters) into SecBuf + 2: B = the characters. BS (or DEL) takes
; the last one away, RETURN ends it (not shown); a control character is kept and shown as ^ and a letter.
; CTRL+C gives the function up. HL after the characters. Keeps C.
GatherLine:
        ld b,0                          ; the characters so far
        ld hl,(SecBufAddr)              ; (they are gathered there)
        ld a,$FF
        ld (DirDrive),a
        inc hl
        inc hl
.key:
        call WaitKeyBreak
        cp 13
        ret z
        cp 8
        jr z,.back
        cp 127
        jr z,.back
        ld e,a
        ld a,b
        cp c
        jr nc,.key                      ; full
        ld (hl),e
        inc hl
        inc b
        ld a,e
        cp ' '
        jr nc,.show
        ld a,'^'
        call ShowChar
        ld a,e
        add a,'@'
.show:
        call ShowChar
        jr .key
.back:
        ld a,b
        or a
        jr z,.key
        dec hl
        dec b
        ld a,(hl)
        cp ' '
        call c,.erase                   ; (^ and a letter: two places)
        call .erase
        jr .key
.erase:
        ld a,8
        call ShowChar
        ld a,' '
        call ShowChar
        ld a,8
        jp ShowChar

LineInputDone:
        ld (hl),13                      ; a CR after them (not counted), when there is room for it
        ld a,13
        call ShowChar
        ld hl,(SecBufAddr)
        ld (hl),c
        inc hl
        ld (hl),b
        dec hl
        ld de,(KUser)
        ld a,b
        cp c
        ld c,b
        ld b,0
        inc bc
        inc bc
        jr nc,.full
        inc bc
.full:
        call CopyToUser
        ld a,13                         ; (A: the key that ended it)
        jp ResultA

; 0Ch: version 2.2 (as CP/M 2.2): HL = 0022h.
Version:
        ld hl,$0022
        jp ResultHL

; --- the disk's settings ---

; 0Dh: every buffer written, the default drive A:, the DTA at 0080h.
DiskReset:
        call FlushAll
        ld a,$FF
        ld (FatDrive),a
        ld (DataDrive),a
        ld (DirDrive),a
        xor a
        ld (CurDrive),a
        ld hl,$0080
        ld (DtaAddr),hl
        xor a
        jp ResultA

; 0Eh: the default drive E (0 A:). A = the number of drives.
SelectDisk:
        ld a,(LogDrives)
        dec a
        cp e
        jr c,.none
        ld a,e
        ld (CurDrive),a
.none:
        ld a,(LogDrives)
        jp ResultA

; 18h: HL = a bit for each drive there is.
LoginVector:
        ld a,(LogDrives)
        ld hl,1
        dec a
        jr z,ResultHL2
        ld l,3
ResultHL2:
        jp ResultHL

; 19h: A = the default drive.
CurrentDrive:
        ld a,(CurDrive)
        jp ResultA

; 1Ah: the DTA = DE.
SetDta:
        ld (DtaAddr),de
        xor a
        jp ResultA

; 2Eh: the verify flag = E (kept: the writes are not read back).
SetVerify:
        ld a,e
        ld (VerifyFlag),a
        xor a
        jp ResultA

; 1Bh: drive E (0 the default, 1 A:): A = sectors a cluster, BC = sector size, DE = clusters, HL = free
; clusters, IX = the DPB, IY = the FAT. A = FFh for a drive that is not there.
AllocInfo:
        ld a,e
        dec a                           ; (0 -> FFh: the default)
        call SelectKDrive
        jr c,.none
        call LoginDrive
        jr c,.none
        call CountFreeClusters
        ld iy,(KDpb)
        ld e,(iy + DpbMaxClus)
        ld d,(iy + DpbMaxClus + 1)
        dec de
        ld bc,512
        ld a,(iy + DpbClusMask)
        inc a
        push iy
        pop ix
        dec ix                          ; (the DPB's place: its drive's number first)
        push hl
        ld hl,(FatBufAddr)
        push hl
        pop iy
        pop hl
        ret
.none:
        ld a,$FF
        ret

; 2Fh / 30h: H sectors from DE of drive L (0 A:), at the DTA, with the drive's DPB as it is (the media
; byte of the last disk looked at: 720K until then).
AbsoluteRead:
        or a
        jr Absolute
AbsoluteWrite:
        scf
Absolute:
        push af
        ld a,l
        call SelectKDrive
        jr c,.none
        push hl
        push de
        call FlushAll                   ; (the disk is not looked at: its DPB as it is, a boot program reads
        ld a,$FF                        ; disks with no FAT; the buffers forgotten: the sectors may change)
        ld (DirDrive),a
        ld (DataDrive),a
        ld (FatDrive),a
        pop de
        pop hl
        ld b,h
        ld hl,(DtaAddr)
        pop af
        call DiskSectors
        xor a
        jp ResultA
.none:
        pop af
        ld a,$FF
        jp ResultA

; --- the date and the time (the clock chip, through the sub-ROM's REDCLK and WRTCLK; the registers of
;     block 0: seconds, minutes, hours, the day of the week, the day, the month, the year since 1980,
;     units then tens) ---

; ReadClock: A = the clock's register C (block 0). Keeps BC, DE, HL, IX, IY.
ReadClock:
        push hl
        push de
        push bc
        push ix                         ; (CALSLT takes IX and IY: IX may point to the FCB)
        push iy
        ld ix,REDCLK
        call CallSub
        pop iy
        pop ix
        and $0F
        pop bc
        pop de
        pop hl
        ret
; WriteClock: the clock's register C = A.
WriteClock:
        push hl
        push de
        push bc
        push ix                         ; (CALSLT takes IX and IY: IX may point to the FCB)
        push iy
        ld ix,WRTCLK
        call CallSub
        pop iy
        pop ix
        pop bc
        pop de
        pop hl
        ret
; ReadClockPair: A = the number in registers C (units) and C + 1 (tens). Keeps BC (C moved on by 2), DE, HL.
ReadClockPair:
        call ReadClock
        ld b,a
        inc c
        call ReadClock
        inc c
        add a,a
        ld d,a
        add a,a
        add a,a
        add a,d                         ; tens * 10
        add a,b
        ret
; WriteClockPair: registers C, C + 1 = A (0-99) as units and tens. C moved on by 2.
WriteClockPair:
        ld b,0
.tens:
        cp 10
        jr c,.units
        sub 10
        inc b
        jr .tens
.units:
        call WriteClock
        inc c
        ld a,b
        call WriteClock
        inc c
        ret

; 2Ah: HL = the year, D = the month, E = the day, A = the day of the week (0 Sunday).
GetDate:
        ld c,6
        call ReadClock
        push af
        ld c,7
        call ReadClockPair              ; the day
        ld e,a
        push de
        call ReadClockPair              ; the month
        pop de
        ld d,a
        push de
        call ReadClockPair              ; the year
        pop de
        ld l,a
        ld h,0
        ld bc,1980
        add hl,bc
        pop af
        ret

; 2Bh: HL = the year (1980-2079), D = the month, E = the day. A = FFh when the date is not valid.
SetDate:
        ld bc,-1980
        add hl,bc
        jr nc,.bad
        ld a,h
        or a
        jr nz,.bad
        ld a,l
        cp 100
        jr nc,.bad
        ld a,d
        dec a
        cp 12
        jr nc,.bad
        ld a,e
        dec a
        cp 31
        jr nc,.bad
        push hl
        ld c,7
        ld a,e
        push de
        call WriteClockPair
        pop de
        ld a,d
        call WriteClockPair
        pop hl
        ld a,l
        call WriteClockPair
        xor a
        jp ResultA
.bad:
        ld a,$FF
        jp ResultA

; 2Ch: H = the hours, L = the minutes, D = the seconds, E = hundredths (0).
GetTime:
        ld c,0
        call ReadClockPair              ; the seconds
        ld d,a
        push de
        call ReadClockPair              ; the minutes
        ld l,a
        push hl
        call ReadClockPair              ; the hours
        pop hl
        ld h,a
        pop de
        ld e,0
        xor a
        ret

; 2Dh: H = the hours, L = the minutes, D = the seconds. A = FFh when the time is not valid.
SetTime:
        ld a,h
        cp 24
        jr nc,.bad
        ld a,l
        cp 60
        jr nc,.bad
        ld a,d
        cp 60
        jr nc,.bad
        push hl
        ld c,0
        ld a,d
        call WriteClockPair
        pop hl
        push hl
        ld a,l
        call WriteClockPair
        pop hl
        ld a,h
        call WriteClockPair
        xor a
        jp ResultA
.bad:
        ld a,$FF
        jp ResultA

; DirDateTime: DE = the date and HL = the time, as the directory keeps them (from the clock).
DirDateTime:
        call GetTime                    ; H hours, L minutes, D seconds
        ld a,d
        srl a                           ; seconds / 2
        ld e,a
        ld a,l
        ld b,h
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl                       ; minutes << 5
        ld a,e
        or l
        ld l,a
        ld a,b
        add a,a
        add a,a
        add a,a                         ; hours << 3 (of the high byte)
        or h
        ld h,a
        push hl
        call GetDate                    ; HL year, D month, E day
        ld bc,-1980
        add hl,bc
        ld a,l
        add a,a                         ; (year - 1980) << 1: the high byte's bits 7-1
        ld b,a
        ld a,d                          ; the month: bits 8-5
        rrca
        rrca
        rrca
        ld c,a
        and $E0                         ; its low 3 bits at 7-5 of the low byte
        or e
        ld e,a
        ld a,c
        and $01                         ; its high bit at bit 0 of the high byte
        or b
        ld d,a
        pop hl
        ret

; --- disk errors ---

; DiskError: a disk error: C = its code (bit 0: in a write), KDrive the drive. The handler that DISKVE
; points to is asked (A = the drive, C = the code); it answers C = 0 ignore, 1 retry, 2 abort. Without one,
; abort. An abort never comes back: the function ends with A = FFh.
DiskError:
        ld hl,(DISKVE)
        ld a,h
        or l
        jr z,.abort
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(KDrive)
        push ix                         ; (the handler may change them: IX may point to the FCB)
        push iy
        push hl
        ld hl,.answer
        ex (sp),hl
        jp (hl)
.answer:
        pop iy
        pop ix
        ld a,c
        cp 2
        ret c
.abort:
        ld a,$FF                        ; nothing of the buffers is kept
        ld (FatDrive),a
        ld (DataDrive),a
        ld (DirDrive),a
        xor a
        ld (FatDirty),a
        ld (DataDirty),a
        jp KernelAbort

; --- the caller's memory (page 1 may be RAM under the disk system, while this ROM is there) ---

; ReadUserByte: A = the caller's byte at HL.
ReadUserByte:
        push hl
        push de
        push bc
        ld de,KTemp
        ld bc,1
        call CopyFromUser
        pop bc
        pop de
        pop hl
        ld a,(KTemp)
        ret

; CopyToUser: BC bytes from HL (this kernel's memory, page 3) to DE (the caller's). CopyFromUser: from HL
; (the caller's) to DE. Destroys AF, BC, DE, HL.
CopyToUser:
        push hl
        ld h,d
        ld l,e
        call TouchesPageOne
        pop hl
        jr c,.ram
        ldir
        ret
.ram:
        jp ResRamLdir
CopyFromUser:
        call TouchesPageOne
        jr c,CopyToUser.ram
        ldir
        ret

; TouchesPageOne: carry when the BC bytes from HL touch 4000h-7FFFh (and BC is not 0). Keeps BC, DE, HL.
TouchesPageOne:
        ld a,b
        or c
        ret z
        ld a,h
        cp $80
        jr nc,.no                       ; from 8000h
        push hl
        add hl,bc
        dec hl                          ; the last byte
        ld a,h
        pop hl
        jr c,.yes                       ; (past FFFFh: it goes through page 1... and on)
        cp $40
        ccf
        ret
.yes:
        scf
        ret
.no:
        or a
        ret

; CallSub: the sub-ROM's routine IX (CALSLT; interrupts as they were).
CallSub:
        push af
        ld a,i
        push af
        pop hl
        pop af
        push hl
        ld iy,(EXBRSA - 1)
        call CALSLT
        ex (sp),hl
        bit 2,l
        pop hl
        ret z
        ei
        ret
