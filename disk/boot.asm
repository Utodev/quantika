; boot.asm: the boot from a disk (through H_STKE, once the cartridges are started: the boot sector's
; program at C01Eh, first as it is, then with RAM in page 0, for the disk operating system's system file),
; and the entries at fixed places of this ROM that the disk operating system's system file calls.

; BootDisk: H_STKE. The boot sector of drive A: is read into C000h; when it holds a program (it starts with
; a jump: EBh or E9h) C01Eh is called with the carry clear (a game may stay there), then, with RAM in page
; 0 and its entries filled in, with the carry set: the system file is loaded there and started. When it
; comes back (or jumps to 4022h: BootReturn), BASIC starts. Both calls: A = 0, DE = EnableRom (F368h), HL
; = DISKVE (F323h): the boot program's disk error handler goes there.
BootDisk:
        ld hl,H_STKE                    ; once
        ld b,5
.ret:
        ld (hl),$C9
        inc hl
        djnz .ret
        ld (BootSP),sp
        ld hl,0                         ; (a copy of the frames on the stack: CALL SYSTEM comes back here)
        add hl,sp
        ld de,BootFrames
        ld bc,32
        ldir
        in a,($A8)                      ; the main ROM's slot in page 0 (the RAM takes its place later)
        and $03
        ld (BiosSlots),a
        xor a
        ld (BootDiskOk),a
        call ReadBootSector
        ret c                           ; (no disk: BASIC)
        ld a,1
        ld (BootDiskOk),a
        ld a,(SecBuf)
        cp $EB
        jr z,BootProgram
        cp $E9
        ret nz
BootProgram:
        call ERAFNK                     ; (the bottom line free: the boot program has the whole screen)
        ld hl,SecBuf
        ld de,$C000
        ld bc,512
        ldir
        or a
        call BootCall                   ; carry clear
BootDos:
        di                              ; the disk operating system, with RAM in page 0
        call ResPageZeroRam
        ld hl,ResDosBdos
        ld (BDOS + 1),hl
        ei
        scf
        call BootCall
        jr BootReturn                   ; the boot program came back (no system file)

; ReadBootSector: the boot sector of drive A: into SecBuf. Out: carry when it could not be read.
ReadBootSector:
        xor a                           ; the boot sector (sector 0 of drive A:)
        ld b,1
        ld c,$F9
        ld de,0
        ld hl,SecBuf
        call DiskIo
        ld a,$FF
        ld (DirDrive),a                 ; (SecBuf holds something else now)
        ret

; BootReturn (4022h): back to BASIC: the main ROM in page 0 again, BDOS as BASIC has it, the boot
; program's error handler forgotten; then to the main ROM, from H_STKE.
BootReturn:
        di
        ld hl,BootFrames                ; the stack as H_STKE left it (after CALL SYSTEM it was used since)
        ld de,(BootSP)
        ld bc,32
        ldir
        ld sp,(BootSP)
        call ResPageZeroRom
        call ArmFirstReady              ; (this ROM's line under the banner again)
        ld a,(BootFlag)                 ; after the disk operating system: no AUTOEXEC.BAS (as the original)
        or a
        jr z,.auto
        xor a
        ld (BootDiskOk),a
.auto:
        ld hl,BdosBody
        ld (BDOS + 1),hl
        ld hl,0
        ld (DISKVE),hl
        ld (BREAKV),hl
        ei
        xor a                           ; a clear screen, the bottom line back (BASIC starts as it does
        call CLS                        ; without a disk)
        jp DSPFNK

; BootCall: C01Eh with A = 0, DE = EnableRom, HL = DISKVE (the carry as it is).
BootCall:
        ld a,0
        ld de,EnableRom
        ld hl,DISKVE
        jp $C01E

; --- the entries the system file calls ---

; DosBottom (4030h): HL = the lowest byte the disk system takes (the system file goes under it).
DosBottom:
        ld hl,DiskBottom
        ret

; DosConsoleStatus (4034h): zero flag when no key is waiting (A = 0), else A = FFh.
DosConsoleStatus:
        push bc
        push de
        push hl
        ld ix,CHSNS
        call CallBios
        pop hl
        pop de
        pop bc
        ld a,0
        ret z
        dec a
        ret

; DosConsoleIn (4078h): A = the next key.
DosConsoleIn:
        push bc
        push de
        push hl
        ld ix,CHGET
        call CallBios
        pop hl
        pop de
        pop bc
        ret

; DosConsoleOut (408Fh): A on the console.
DosConsoleOut:
        jp ShowChar

; DosWarmStart (50A9h): at each warm start of the system: the buffers written, the disks looked at again.
DosWarmStart:
        call FlushAll
        ld a,$FF
        ld (FatDrive),a
        ld (DataDrive),a
        ld (DirDrive),a
        xor a
        ret

; DosNewLine (5183h): CR and LF on the console.
DosNewLine:
        ld a,13
        call ShowChar
        ld a,10
        jp ShowChar

; ConsoleChar: A on the console (the resident routines' way to it).
ConsoleChar     equ ShowChar

; FirstReady: H_READ, the first time BASIC is ready (after its banner): H_READ as it was, this ROM's line
; under the banner, then H_READ's former owner.
FirstReady:
        push hl
        ld hl,ReadHookSave
        ld de,H_READ
        ld bc,5
        ldir
        xor a
        ld (ReadArmed),a
        ld hl,DiskBasicBanner
        call PrintText
        ld a,(BootDiskOk)               ; AUTOEXEC.BAS (at power on only): RUN "AUTOEXEC.BAS"
        or a
        jr z,.basic
        xor a
        ld (BootDiskOk),a
        ld hl,0                         ; (no error handler: an error is "not there")
        ld (DISKVE),hl
        ld hl,BFcb
        call ClearFcb
        ld de,BFcb + 1
        ld hl,AutoexecName
        ld bc,11
        ldir
        ld de,BFcb
        KERNEL $0F
        inc a
        jr z,.basic
        ld a,TkRun
        ld (BTok),a
        ld a,3
        ld (BFlags),a
        jp LoadFile
.basic:
        pop hl
        jp H_READ
AutoexecName:
        db "AUTOEXECBAS"

; ArmFirstReady: H_READ to FirstReady (once: its former contents kept). Destroys AF, BC, DE, HL.
ArmFirstReady:
        ld a,(ReadArmed)
        or a
        ret nz
        inc a
        ld (ReadArmed),a
        ld hl,H_READ
        ld de,ReadHookSave
        ld bc,5
        ldir
        ld hl,H_READ
        ld de,FirstReady
        jp SetHook

; SystemStatement: CALL SYSTEM: back to the disk operating system (when it has run since power on: its
; system file is loaded from drive A: again, and its command interpreter). Illegal function call when it
; has not.
SystemStatement:
        ld a,(BootFlag)
        or a
        jp z,IllegalFunction
        call ReadBootSector
        jp c,IllegalFunction
        ld a,(SecBuf)
        cp $EB
        jr z,.boot
        cp $E9
        jp nz,IllegalFunction
.boot:
        di
        ld hl,BootFrames
        ld de,(BootSP)
        ld bc,32
        ldir
        ld sp,(BootSP)
        ld hl,SecBuf
        ld de,$C000
        ld bc,512
        ldir
        jp BootDos
DiskBasicBanner:
        db "QUANTIKA Disk BASIC extension 1.0", 13, 10, 0
