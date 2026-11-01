; queue.asm: the queues of QUETAB for machine code (the standard's layout: for each queue the put and get
; offsets, a byte kept 0, the size less one and the address; basic/play.asm puts PLAY's music in the first
; three): LFTQ, PUTQ, and STRTMS, which starts the music in them.

; QueueTableEntry: HL = queue A's QUETAB entry. Destroys AF.
QueueTableEntry:
        ld l,a
        add a,a
        add a,l
        add a,a
        ld hl,QUETAB
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; QueueFree: LFTQ. A = queue: HL = the bytes free in it. Destroys AF, BC.
QueueFree:
        call QueueTableEntry
        ld b,(hl)                       ; B = put
        inc hl
        ld a,(hl)                       ; get - put - 1, within the size
        sub b
        dec a
        inc hl
        inc hl
        and (hl)
        ld l,a
        ld h,$00
        ret

; QueuePut: PUTQ. A = queue, E = byte: put moves on, the byte goes there (as the original), NZ; Z (and
; nothing put) when it is full. Destroys AF, BC, HL.
QueuePut:
        call QueueTableEntry
        ld a,(hl)
        inc a
        inc hl
        inc hl
        inc hl
        and (hl)                        ; the next put
        dec hl
        dec hl
        cp (hl)                         ; = get: full
        ret z
        dec hl
        ld (hl),a
        ld b,a                          ; B = the new put
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,(hl)                       ; the address + put
        inc hl
        ld h,(hl)
        add a,b
        ld l,a
        jr nc,.store
        inc h
.store:
        ld (hl),e
        or $FF                          ; NZ
        ret

; StartMusic: STRTMS. The music in the voices' queues starts playing (in the interrupt) if it is not
; already. Destroys AF, BC, HL.
StartMusic:
        ld c,$00
.voice:
        ld a,c
        call QueueTableEntry
        ld a,(hl)
        inc hl
        cp (hl)
        jr nz,.play
        inc c
        ld a,c
        cp $03
        jr c,.voice
        ret
.play:
        di
        ld a,MusicSignature
        ld (PLYCNT),a
        ld a,$01
        ld (MUSICF),a
        ei
        ret
