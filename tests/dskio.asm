; dskio.asm: a test of the disk driver's DSKIO (4010h of the disk interface in slot 3-3) through CALSLT, so
; the same binary runs on the original ROMs and on the free ones (the emulator's test harness: exec, with
; a disk in drive A:). Results from D000h:
;   default: sectors 0-14 of a 720K disk read into 9000h: their 16-bit sums (30 bytes), then A and B
;   -DWRITE: sectors 1000-1002 written with a pattern, the buffer cleared, read back: the write's A, B,
;            carry, the read's A, B, carry, the three sums, then 1 if the bytes read are the ones written
;   -DDRIVEB: one sector of drive B: (none connected or no disk): A, B, carry
;   -DDPB: GETDPB for the media bytes F8h-FFh, 24 bytes apart from D000h (the block at +1), then DSKCHG of
;          drive A: at D0C0h (its block at +1; A, B and carry after it at D0E0h)
;   -DPHYDIO: (with any of the others) through the BIOS's PHYDIO (0144h), which the disk ROM hooks
;   -DPAGE1: sectors 7-8 read into 7F00h (page 1: the RAM there, as under the disk system), then read back
;            from the RAM's slot (that of page 3) with RDSLT: A, B, carry, the two sums (the free ROM only)
        device NOSLOT64K
        org $C000
CALSLT  equ $001C
DiskSlot equ $8F                        ; 3-3
Buffer  equ $9000
Out     equ $D000

Start:
        di
        ld sp,$C000                     ; (under HIMEM: the disk ROM takes the memory from there up)
        ei
        ld hl,Out
        ld de,Out + 1
        ld bc,63
        ld (hl),0
        ldir
    ifdef DPB
        ld b,$F8
        ld hl,Out
.media:
        push bc
        push hl
        ld a,0
        ld c,b
        ld iy,DiskSlot * 256
        ld ix,$4016
        call CALSLT
        ei
        pop hl
        ld de,24
        add hl,de
        pop bc
        inc b
        jr nz,.media
        ld a,0
        ld b,0
        ld c,$F9
        ld hl,Out + $C0
        ld iy,DiskSlot * 256
        ld ix,$4013
        call CALSLT
        ei
        ld ix,Out + $E0
        ld (ix + 0),a
        ld (ix + 1),b
        ld a,0
        rla
        ld (ix + 2),a
    else
    ifdef PAGE1
        ld a,0
        ld b,2
        ld c,$F9
        ld de,7
        ld hl,$7F00
        or a
        call Dskio
        ld ix,Out
        ld (ix + 0),a
        ld (ix + 1),b
        ld (ix + 2),c
    ifdef NOREAD
        jp .end
    endif
        in a,($A8)                      ; the RAM's slot: page 3's
        rlca
        rlca
        and $03
        ld c,a
        ld hl,$FCC1                     ; EXPTBL
        add a,l
        ld l,a
        ld a,(hl)
        and $80
        or c
        ld c,a
        jp p,.notExpanded
        ld a,($FCC5 + 3)                ; (SLTTBL of slot 3: the RAM's primary in emu80): page 3's subslot
        rrca
        rrca
        rrca
        rrca
        and $0C
        or c
        ld c,a
.notExpanded:
        ld hl,$7F00
        ld de,Buffer
.copy:
        push bc
        push de
        ld a,c
        call $000C                      ; RDSLT
        pop de
        pop bc
        ld (de),a
        inc hl
        inc de
        ld a,h
        cp $83
        jr nz,.copy
        ei
        ld hl,Buffer
        ld de,Out + 3
        ld b,2
        call Sums
    else
    ifdef DRIVEB
        ld a,1
        ld b,1
        ld c,$F9
        ld de,0
        ld hl,Buffer
        or a
        call Dskio
        ld (Out),a
        ld a,b
        ld (Out + 1),a
        ld a,c
        ld (Out + 2),a
    else
    ifdef WRITE
        ld hl,Buffer                    ; the pattern: (address * 7 + high byte) for 3 sectors
        ld bc,3 * 512
.fill:
        ld a,l
        add a,a
        add a,a
        add a,a
        sub l
        add a,h
        ld (hl),a
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.fill
        ld b,3
        ld de,1000
        scf
        call DskioA
        ld ix,Out
        ld (ix + 0),a
        ld (ix + 1),b
        ld (ix + 2),c
        ld hl,Buffer
        ld de,Buffer + 1
        ld bc,3 * 512 - 1
        ld (hl),0
        ldir
        ld b,3
        ld de,1000
        or a
        call DskioA
        ld ix,Out
        ld (ix + 3),a
        ld (ix + 4),b
        ld (ix + 5),c
        ld hl,Buffer
        ld de,Out + 6
        ld b,3
        call Sums
        ld hl,Buffer                    ; the same as written?
        ld bc,3 * 512
        ld e,1
.check:
        ld a,l
        add a,a
        add a,a
        add a,a
        sub l
        add a,h
        cp (hl)
        jr z,.same
        ld e,0
.same:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.check
        ld a,e
        ld (Out + 12),a
    else
        ld b,15
        ld de,0
        or a
        call DskioA
        ld (Out + 30),a
        ld a,b
        ld (Out + 31),a
        ld hl,Buffer
        ld de,Out
        ld b,15
        call Sums
    endif
    endif
    endif
    endif
.end:
        jr .end

; DskioA: DSKIO on drive A:, media F9h (B sectors from DE at Buffer; carry to write). Out: A, B, C = 1 if
; carry.
DskioA:
        ld a,0
        ld c,$F9
        ld hl,Buffer
; Dskio: DSKIO with A, B, C, DE, HL and the carry as given. Out: A, B, C = 1 if carry.
Dskio:
    ifdef PHYDIO
        call $0144
    else
        ld iy,DiskSlot * 256
        ld ix,$4010
        call CALSLT
    endif
        ei
        ld c,0
        ret nc
        inc c
        ret

; Sums: the 16-bit sums of B sectors from HL, stored at DE.
Sums:
        push bc
        push de
        ld bc,512
        ld de,0
.add:
        ld a,(hl)
        add a,e
        ld e,a
        jr nc,.noCarry
        inc d
.noCarry:
        inc hl
        dec bc
        ld a,b
        or c
        jr nz,.add
        ex de,hl
        ex (sp),hl                      ; HL = where it goes, the sum on the stack
        pop bc
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ex de,hl                        ; DE = the next place, HL = the next sector
        pop bc
        djnz Sums
        ret

        savebin "../out/dskio.bin", Start, $ - Start
