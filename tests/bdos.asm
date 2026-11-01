; bdos.asm: a test of the disk system's kernel functions through BDOS (F37Dh), so the same binary runs on
; the original ROMs and on the free ones (the emulator's test harness: exec, with a disk in drive A: that
; has HELLO.TXT (1000 bytes), DATA.BIN (5000) and EMPTY.DAT (0)). The results, a byte (or two) each, go
; from D000h on; the disk is compared afterwards (its files, their sizes and their bytes).
        device NOSLOT64K
        org $C000
BDOS    equ $F37D
Buffer  equ $9000                       ; the DTA
Pattern equ $A000                       ; 4K of a pattern
Out     equ $D000

        macro FUNC n
        ld c,n
        call BDOS
        endm

Start:
        di
        ld sp,$C000
        ei
        ld hl,Out
        ld de,Out + 1
        ld bc,255
        ld (hl),0
        ldir
        ld hl,Out
        ld (Res),hl
        ld hl,Pattern                   ; the pattern: byte i = i * 7 + i / 256
        ld bc,0
.pat:
        ld a,c
        add a,a
        add a,a
        add a,a
        sub c
        add a,b
        ld (hl),a
        inc hl
        inc bc
        ld a,b
        cp $10
        jr nz,.pat

        FUNC $19                        ; the current drive
        call Put
        FUNC $0C                        ; the version
        call PutHL
        ld de,Buffer
        FUNC $1A

        ; a file written record by record: 12 records (whole sectors: what a sector holds past a file's end
        ; is left out of the comparison)
        ld de,Fcb1
        FUNC $16                        ; create
        call Put
        ld hl,Pattern
        ld b,12
.write:
        push bc
        push hl
        ld de,Buffer
        ld bc,128
        ldir
        ld de,Fcb1
        FUNC $15
        call Put
        pop hl
        ld de,128
        add hl,de
        pop bc
        djnz .write
        ld de,Fcb1
        FUNC $10                        ; close
        call Put

        ; open it again and read it
        call ClearFcb2
        ld hl,Name1
        call NameFcb2
        ld de,Fcb2
        FUNC $0F
        call Put
        ld a,(Fcb2 + 16)                ; its size
        call Put
        ld a,(Fcb2 + 17)
        call Put
        ld b,3
.read:
        push bc
        ld de,Fcb2
        FUNC $14
        call Put
        call SumBuffer128
        pop bc
        djnz .read
        ld hl,7                         ; random read: record 7
        ld (Fcb2 + 33),hl
        ld de,Fcb2
        FUNC $21
        call Put
        call SumBuffer128
        ld de,Fcb2                      ; sequential again: record 7 again
        FUNC $14
        call Put
        call SumBuffer128
        ld hl,99                        ; past the end
        ld (Fcb2 + 33),hl
        ld de,Fcb2
        FUNC $21
        call Put

        ; block read: records of 100 bytes from record 5, 7 of them (the file has 1536 bytes: 10 whole)
        ld hl,100
        ld (Fcb2 + 14),hl
        ld hl,5
        ld (Fcb2 + 33),hl
        ld hl,0
        ld (Fcb2 + 35),hl
        ld de,Fcb2
        ld hl,7
        FUNC $27
        call Put
        call PutHL
        ld hl,Buffer
        ld bc,700
        call Sum
        ld a,(Fcb2 + 33)
        call Put
        ld de,Fcb2                      ; and past the end: 4 asked, 3 there (and a part)
        ld hl,4
        FUNC $27
        call Put
        call PutHL
        ld hl,Buffer
        ld bc,400
        call Sum

        ; a random write past the end: record 20 (the file grows to 21 records; 12-19 are not written)
        ld hl,Pattern + 256
        ld de,Buffer
        ld bc,128
        ldir
        ld hl,20
        ld (Fcb1 + 33),hl
        xor a
        ld (Fcb1 + 35),a
        ld de,Fcb1
        FUNC $22
        call Put
        ld de,Fcb1
        FUNC $10
        call Put

        ; a block write: 3000 bytes in records of 1 byte
        call ClearFcb2
        ld hl,Name2
        call NameFcb2
        ld de,Fcb2
        FUNC $16
        call Put
        ld hl,1
        ld (Fcb2 + 14),hl
        ld de,Pattern
        FUNC $1A
        ld de,Fcb2
        ld hl,3000
        FUNC $26
        call Put
        call PutHL
        ld de,Fcb2
        FUNC $10
        call Put
        ld de,Buffer
        FUNC $1A

        ; a file made shorter: DATA.BIN to 2000 bytes (a block write of 0 records)
        call ClearFcb2
        ld hl,Name3
        call NameFcb2
        ld de,Fcb2
        FUNC $0F
        call Put
        ld hl,1
        ld (Fcb2 + 14),hl
        ld hl,2000
        ld (Fcb2 + 33),hl
        ld hl,0
        ld (Fcb2 + 35),hl
        ld de,Fcb2
        ld hl,0
        FUNC $26
        call Put
        ld de,Fcb2
        FUNC $10
        call Put

        ; the size of DATA.BIN in records (23h): 2000 / 128, rounded up: 16
        call ClearFcb2
        ld hl,Name3
        call NameFcb2
        ld de,Fcb2
        FUNC $23
        call Put
        ld a,(Fcb2 + 33)
        call Put
        ld a,(Fcb2 + 34)
        call Put

        ; rename HELLO.TXT to GREET.TXT, delete EMPTY.DAT, open what is not there
        ld de,FcbRename
        FUNC $17
        call Put
        ld de,FcbDelete
        FUNC $13
        call Put
        ld de,FcbDelete
        FUNC $0F
        call Put
        ld de,FcbDelete
        FUNC $13
        call Put

        ; search: every file (the names, in the directory's order), then *.BIN
        ld de,FcbAll
        FUNC $11
.search:
        call Put
        inc a
        jr z,.searched
        ld hl,Buffer
        ld a,(hl)                       ; the drive's number
        call Put
        inc hl
        ld bc,11
        call Sum
        ld de,FcbAll
        FUNC $12
        jr .search
.searched:
        ld de,FcbBin
        FUNC $11
        call Put
        ld a,(Buffer + 1)
        call Put
        ld de,FcbBin
        FUNC $12
        call Put
        ld a,(Buffer + 1)
        call Put
        ld de,FcbBin
        FUNC $12
        call Put

        ; the allocation (1Bh): A, BC, DE, HL
        ld e,0
        FUNC $1B
        push hl
        push de
        push bc
        call Put
        pop hl
        call PutHL
        pop hl
        call PutHL
        pop hl
        call PutHL

        ; an absolute read: sectors 0-1 (the boot sector and the FAT's first)
        ld de,Buffer
        FUNC $1A
        ld de,0
        ld hl,$0200                     ; H = 2 sectors, L = drive A:
        FUNC $2F
        call Put
        ld hl,Buffer
        ld bc,1024
        call Sum
        ld a,$AA                        ; the end
        call Put
        jr $

; Put: A at the next result's place. PutHL: HL (low first). Keep everything but the flags.
Put:
        push hl
        ld hl,(Res)
        ld (hl),a
        inc hl
        ld (Res),hl
        pop hl
        ret
PutHL:
        ld a,l
        call Put
        ld a,h
        jr Put

; Sum: the 16-bit sum of BC bytes from HL, put. SumBuffer128: of the DTA's 128 bytes.
SumBuffer128:
        ld hl,Buffer
        ld bc,128
Sum:
        ld de,0
.add:
        ld a,(hl)
        add a,e
        ld e,a
        jr nc,.nc
        inc d
.nc:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.add
        ex de,hl
        jr PutHL

ClearFcb2:
        ld hl,Fcb2
        ld de,Fcb2 + 1
        ld bc,36
        ld (hl),0
        ldir
        ret
NameFcb2:
        ld de,Fcb2 + 1
        ld bc,11
        ldir
        ret

Res:    dw 0
Name1:  db "TEST1   DAT"
Name2:  db "BLOCK   BIN"
Name3:  db "DATA    BIN"
Fcb1:   db 0, "TEST1   DAT"
        ds 25, 0
Fcb2:   ds 37, 0
FcbRename:
        db 1, "HELLO   TXT", 0, 0, 0, 0, 0, "GREET   TXT"
        ds 9, 0
FcbDelete:
        db 0, "EMPTY   DAT"
        ds 25, 0
FcbAll: db 0, "???????????"
        ds 25, 0
FcbBin: db 0, "????????BIN"
        ds 25, 0

        savebin "../out/bdos.bin", Start, $ - Start
