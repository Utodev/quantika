; grpprt.asm: GRPPRT (008Dh) in SCREEN MODE (assembled with -DMODE=n): the block characters 219-223 (the
; same shapes in every font) from GRPACX = 3, GRPACY = 5 in the foreground colour, with CR, LF and a
; backspace between them, then a second pass with LOGOPR = 3 (XOR) over the first.
; Results: GRPACX / GRPACY after each character (their low bytes), then a hash of the VRAM from 0000h
; (HashEnd). ONEPASS: one pass, in a background colour that is not the paper's. NOPRINT: nothing printed.
        include "common.inc"
GRPPRT  equ $008D
NRDVRM  equ $0174
RDVRM   equ $004A
GRPACX  equ $FCB7
GRPACY  equ $FCB9
LOGOPR  equ $FB02
FORCLR  equ $F3E9
        if MODE == 3                    ; the hash: the patterns the mode uses (the rest of VRAM has what
HashEnd equ $06                         ; each BIOS left there before)
        elseif MODE == 2 || MODE == 4
HashEnd equ $18
        else
HashEnd equ $24
        endif
        TEST_START
        call ERAFNK
        ld hl,$0109                     ; FORCLR 9, BAKCLR 1
        if MODE == 8
        ld hl,$011C
        endif
        ld (FORCLR),hl
        ld a,$04                        ; BDRCLR 4 (the BIOSes start with different ones)
        ld ($F3EB),a
        ld a,MODE
        call CHGMOD
        xor a
        call CLS
        ifdef ONEPASS
        ld a,$02                        ; BAKCLR 2 now (the paper stays 1), ATRBYT 6
        ld ($F3EA),a
        ld a,$06
        ld ($F3F2),a
        endif
        ld ix,Results
        xor a
        call Pass
        ifndef ONEPASS
        ld a,$03                        ; XOR over the same places
        call Pass
        endif
        ld hl,$0000                     ; the hash: h = h * 33 + byte
        ld de,$0000
.hash:
        push hl                         ; (HL = the address, DE = h)
        push de
        if MODE < 4
        call RDVRM
        else
        call NRDVRM
        endif
        pop hl                          ; HL = h
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld e,a
        ld d,$00
        add hl,de
        ex de,hl
        pop hl
        inc hl
        ld a,h
        cp HashEnd
        jr nz,.hash
        ld (ix+0),e
        ld (ix+1),d
        jp TestEnd

; Pass: LOGOPR = A, the place back at 3, 5, then the characters of Text; IX takes GRPACX / GRPACY after
; each one (the first pass only: the second one would be the same).
Pass:
        ifdef NOPRINT
        ret
        endif
        ld (LOGOPR),a
        ld b,a
        ld hl,3
        ld (GRPACX),hl
        ld hl,5
        ld (GRPACY),hl
        ld hl,Text
.char:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        push bc
        call GRPPRT
        pop bc
        pop hl
        ld a,b
        or a
        jr nz,.char
        ld a,(GRPACX)
        ld (ix+0),a
        ld a,(GRPACY)
        ld (ix+1),a
        inc ix
        inc ix
        jr .char
Text:
        db 219, 220, 13, 221, 10, 222, 8, 223, 0
        TEST_END "../out/grpprt.bin"
