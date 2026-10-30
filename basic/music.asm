; music.asm: the part of PLAY that runs in the interrupt; it must be in page 0 (a cartridge may be in
; page 1 when the interrupt comes). See play.asm.

; QueueEntry: HL = voice C's QUETAB entry (3 bytes).
QueueEntry:
        ld a,c
        add a,a
        add a,c
        ld hl,QUETAB
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; QueueAddress: IY = voice C's queue + A. Keeps BC.
QueueAddress:
        push bc
        ld e,a
        ld d,$00
        ld iy,VOICAQ
        ld a,c
        or a
        jr z,.got
        ld iy,VOICBQ
        dec a
        jr z,.got
        ld iy,VOICCQ
.got:
        add iy,de
        pop bc
        ret

; PlayMusic: in the interrupt: each voice counts its frames down and takes its next event. Only while
; PLAY's music runs (MUSICF and PLYCNT say so: programs that are not BASIC use this RAM for themselves);
; MUSICF goes back to 0 when every voice is quiet.
MusicSignature  equ $5A                 ; in PLYCNT while PLAY's music runs

PlayMusic:
        ld a,(MUSICF)                   ; MUSICF = 1 and PLYCNT = 5Ah: a program that is not BASIC is
        dec a                           ; not likely to leave both in this RAM by chance
        ret nz
        ld a,(PLYCNT)
        cp MusicSignature
        ret nz
        ld b,$00                        ; B = voices still busy
        ld c,$00
.voice:
        call QueueEntry
        inc hl
        inc hl
        ld a,(hl)                       ; frames left
        or a
        jr z,.next
        dec (hl)
        jr nz,.voiceDone
.next:
        dec hl
        dec hl
        ld a,(hl)                       ; empty?
        inc hl
        cp (hl)
        jr z,.silent
        ld a,(hl)                       ; the event at get
        push af
        push hl
        call QueueAddress
        pop hl
        pop af
        add a,4
        and $7F
        ld (hl),a                       ; get moves on
        inc hl
        ld a,(iy+3)
        ld (hl),a                       ; its frames
        ld a,c                          ; PSG: period (registers 2C, 2C+1), volume (8 + C)
        add a,a
        ld e,(iy+0)
        call WritePsg
        inc a
        ld e,(iy+1)
        call WritePsg
        ld a,c
        add a,$08
        ld e,(iy+2)
        call WritePsg
        jr .voiceDone
.silent:
        ld a,c                          ; nothing more: the voice goes quiet
        add a,$08
        ld e,$00
        call WritePsg
        jr .nextVoice
.voiceDone:
        inc b
.nextVoice:
        inc c
        ld a,c
        cp $03
        jr c,.voice
        ld a,b
        or a
        ret nz
        ld (MUSICF),a                   ; all quiet
        ret

