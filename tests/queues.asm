; queues.asm: GETVCP, GETVC2 (VOICEN 1, offset 5), LPTSTT, ISFLIO, LFTQ before and after three PUTQ to
; queue 0, PUTQ to queue 3 (no size: full), and QUETAB. Results: HL, A + F (Z and C) as each gives them.
        include "common.inc"
VOICEN  equ $FB38
QUETAB  equ $F959
        TEST_START
        ld iy,Results
        xor a
        call $0150                      ; GETVCP 0, 1, 2
        call SaveHl
        ld a,1
        call $0150
        call SaveHl
        ld a,2
        call $0150
        call SaveHl
        ld a,1
        ld (VOICEN),a
        ld l,5
        call $0153                      ; GETVC2
        call SaveHl
        call $00A8                      ; LPTSTT
        call SaveAf
        call $014A                      ; ISFLIO
        call SaveAf
        xor a
        call $00F6                      ; LFTQ 0
        call SaveHl
        ld b,3
.put:
        push bc
        ld a,b
        add a,$40
        ld e,a
        xor a
        call $00F9                      ; PUTQ 0, 43h 42h 41h
        call SaveF
        pop bc
        djnz .put
        xor a
        call $00F6
        call SaveHl
        ld a,3
        ld e,$55
        call $00F9                      ; PUTQ 3: full
        call SaveF
        ld hl,QUETAB                    ; QUETAB, and the first bytes of queue 0
        ld b,24
.copy:
        ld a,(hl)
        ld (iy+0),a
        inc iy
        inc hl
        djnz .copy
        ld hl,($F959 + 4)
        ld b,4
.queue:
        ld a,(hl)
        ld (iy+0),a
        inc iy
        inc hl
        djnz .queue
        jp TestEnd

SaveHl:
        ld (iy+0),l
        ld (iy+1),h
        inc iy
        inc iy
        ret
SaveF:                                  ; (PUTQ: only the flags are given)
        push af
        pop hl
        ld a,l
        and $41
        ld (iy+0),a
        inc iy
        ret
SaveAf:
        push af
        pop hl
        ld (iy+0),h
        ld a,l
        and $41
        ld (iy+1),a
        inc iy
        inc iy
        ret
        TEST_END "../out/queues.bin"
