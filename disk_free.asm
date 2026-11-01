; disk_free.asm: a free disk interface ROM (16K, page 1 of its slot: 3-3 in emu80), written from the
; published standard, for the interface with the WD2793 controller whose registers are at 7FF8h-7FFFh
; (the controller's status / command, track, sector and data, then the side, the drive and the
; request lines). It works only with this project's main ROM (FBASIC): it reaches FBASIC through the
; service table of common/diskapi.inc and gets the disk's statements through the hooks described there.
; Build with build.sh.
;
; The layout: the header and the driver's entries (4000h-401Fh), then, up to 5601h, jumps at the places
; the disk operating system's first system file calls (the kernel's functions and a few more: it knows
; them by their addresses); the code fills the room between them (each piece checks it fits) and goes on
; from 5602h.

        device NOSLOT64K
        org $4000                       ; unused ROM bytes read FFh
        ds $4000, $FF

        include "hw.inc"
        include "sysvars.inc"
        include "diskapi.inc"
        include "errors.inc"
        include "tokens.inc"
        include "disk/diskvars.inc"

; --- the header (the main ROM's cartridge scan finds it) ---
        org $4000
        db "AB"
        dw DiskInit                     ; INIT
        dw DiskCallStatement            ; STATEMENT (CALL FORMAT, CALL SYSTEM)
        dw $0000                        ; no device
        dw $0000                        ; no BASIC program
        ds 6, 0

; --- the disk driver's entries, at the standard's addresses ---
        org $4010
        jp DiskIo                       ; 4010h DSKIO: read or write sectors
        jp DiskChange                   ; 4013h DSKCHG: has the disk been changed?
        jp GetDpb                       ; 4016h GETDPB: the drive parameter block of a media byte
        jp Choice                       ; 4019h CHOICE: the text of the format choice
        jp DiskFormat                   ; 401Ch DSKFMT: format a disk
        jp MotorOff                     ; 401Fh MTOFF: the drives' motors off

; --- the places the system file calls ---
        org $4022
        jp BootReturn
        org $4025
        jp DosFormat
        org $4030
        jp DosBottom
        org $4034
        jp DosConsoleStatus
        org $4078
        jp DosConsoleIn
        org $408F
        jp DosConsoleOut
        org $41EF
        jp KFunc0C                   ; function 0Ch
        org $436C
        jp KFunc13                   ; function 13h
        org $4392
        jp KFunc17                   ; function 17h
        org $4462
        jp KFunc0F                   ; function 0Fh
        org $456F
        jp KFunc10                   ; function 10h
        org $461D
        jp KFunc16                   ; function 16h
        org $46BA
        jp KFunc2F                   ; function 2Fh
        org $4720
        jp KFunc30                   ; function 30h
        org $4775
        jp KFunc14                   ; function 14h
        org $477D
        jp KFunc15                   ; function 15h
        org $4788
        jp KFunc21                   ; function 21h
        org $4793
        jp KFunc22                   ; function 22h
        org $47B2
        jp KFunc27                   ; function 27h
        org $47BE
        jp KFunc26                   ; function 26h
        org $47D1
        jp KFunc28                   ; function 28h
        org $4FB8
        jp KFunc11                   ; function 11h
        org $5006
        jp KFunc12                   ; function 12h
        org $501E
        jp KFunc23                   ; function 23h
        org $504E
        jp KFunc18                   ; function 18h
        org $5058
        jp KFunc1A                   ; function 1Ah
        org $505D
        jp KFunc1B                   ; function 1Bh
        org $509F
        jp KFunc0D                   ; function 0Dh
        org $50A9
        jp DosWarmStart
        org $50C4
        jp KFunc19                   ; function 19h
        org $50C8
        jp KFunc24                   ; function 24h
        org $50D5
        jp KFunc0E                   ; function 0Eh
        org $50E0
        jp KFunc0A                   ; function 0Ah
        org $5183
        jp DosNewLine
        org $535D
        jp DosNothing
        org $53A7
        jp KFunc02                   ; function 02h
        org $543C
        jp KFunc0B                   ; function 0Bh
        org $5445
        jp KFunc01                   ; function 01h
        org $544E
        jp KFunc08                   ; function 08h
        org $5454
        jp KFunc06                   ; function 06h
        org $5462
        jp KFunc07                   ; function 07h
        org $5465
        jp KFunc05                   ; function 05h
        org $546E
        jp KFunc03                   ; function 03h
        org $5474
        jp KFunc04                   ; function 04h
        org $553C
        jp KFunc2A                   ; function 2Ah
        org $5552
        jp KFunc2B                   ; function 2Bh
        org $55DB
        jp KFunc2C                   ; function 2Ch
        org $55E6
        jp KFunc2D                   ; function 2Dh
        org $55FF
        jp KFunc2E                   ; function 2Eh

; --- the code, in the room between them ---
        org $4092                       ; (up to 41EEh)
; the name emu80 knows this ROM by (it looks for it to pair the ROM with the main ROM)
DiskRomName:
        db "QUANTIKA disk ROM", 0
KFunc01:
        ld c,$01
        jp KernelEntry
KFunc02:
        ld c,$02
        jp KernelEntry
KFunc03:
        ld c,$03
        jp KernelEntry
KFunc04:
        ld c,$04
        jp KernelEntry
KFunc05:
        ld c,$05
        jp KernelEntry
KFunc06:
        ld c,$06
        jp KernelEntry
KFunc07:
        ld c,$07
        jp KernelEntry
KFunc08:
        ld c,$08
        jp KernelEntry
KFunc0A:
        ld c,$0A
        jp KernelEntry
KFunc0B:
        ld c,$0B
        jp KernelEntry
KFunc0C:
        ld c,$0C
        jp KernelEntry
KFunc0D:
        ld c,$0D
        jp KernelEntry
KFunc0E:
        ld c,$0E
        jp KernelEntry
KFunc0F:
        ld c,$0F
        jp KernelEntry
KFunc10:
        ld c,$10
        jp KernelEntry
KFunc11:
        ld c,$11
        jp KernelEntry
KFunc12:
        ld c,$12
        jp KernelEntry
KFunc13:
        ld c,$13
        jp KernelEntry
KFunc14:
        ld c,$14
        jp KernelEntry
KFunc15:
        ld c,$15
        jp KernelEntry
KFunc16:
        ld c,$16
        jp KernelEntry
KFunc17:
        ld c,$17
        jp KernelEntry
KFunc18:
        ld c,$18
        jp KernelEntry
KFunc19:
        ld c,$19
        jp KernelEntry
KFunc1A:
        ld c,$1A
        jp KernelEntry
KFunc1B:
        ld c,$1B
        jp KernelEntry
KFunc21:
        ld c,$21
        jp KernelEntry
KFunc22:
        ld c,$22
        jp KernelEntry
KFunc23:
        ld c,$23
        jp KernelEntry
KFunc24:
        ld c,$24
        jp KernelEntry
KFunc26:
        ld c,$26
        jp KernelEntry
KFunc27:
        ld c,$27
        jp KernelEntry
KFunc28:
        ld c,$28
        jp KernelEntry
KFunc2A:
        ld c,$2A
        jp KernelEntry
KFunc2B:
        ld c,$2B
        jp KernelEntry
KFunc2C:
        ld c,$2C
        jp KernelEntry
KFunc2D:
        ld c,$2D
        jp KernelEntry
KFunc2E:
        ld c,$2E
        jp KernelEntry
KFunc2F:
        ld c,$2F
        jp KernelEntry
KFunc30:
        ld c,$30
        jp KernelEntry
DosNothing:
        ret
.end:
        assert $ <= $41EF, "the room at 4092h is full"

        org $47D4                       ; (up to 4FB7h)
        include "disk/kernel.asm"
        include "disk/fat.asm"
        assert $ <= $4FB8, "the room at 47D4h is full"

        org $5602
        include "disk/init.asm"
        include "disk/driver.asm"
        include "disk/files.asm"
        include "disk/boot.asm"
        include "disk/basic.asm"
        include "disk/format.asm"
        include "disk/bfiles.asm"
        include "disk/resident.asm"
DiskCodeEnd:
        assert DiskCodeEnd <= $7FF8, "the code runs into the controller's registers"

        savebin "out/disk_free.rom", $4000, $4000
