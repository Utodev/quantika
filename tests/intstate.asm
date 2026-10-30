; intstate.asm: does each BIOS routine leave interrupts as they were? With DI before the call, the
; result is IFF2 after it (04h = enabled) for WRTVDP, SETWRT, SETRD, WRTVRM, RDVRM, FILVRM, LDIRVM,
; WRTPSG, RDPSG, SNSMAT, GTSTCK, GTTRIG, RDSLT, ENASLT (then the same with EI before)
        include "common.inc"
        TEST_START
        ld ix,Results
        ld b,2
.pass:
        push bc
        ld hl,Calls
.next:
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.passDone
        push hl
        ld a,b
        cp 2
        jr nz,.withEi
        di
        jr .call
.withEi:
        ei
.call:
        ld (.target + 1),de
        ld hl,$0100                     ; harmless arguments for all of them
        ld de,$C800
        ld bc,$0101
        ld a,$00
.target:
        call $0000
        ld a,i
        ld a,0
        jp po,.off
        ld a,4
.off:
        ld (ix+0),a
        inc ix
        ei
        pop hl
        jr .next
.passDone:
        pop bc
        djnz .pass
        jp TestEnd
Calls:
        dw $0047, $0053, $0050, $004D, $004A, $0056, $005C, $0093, $0096, $0141, $00D5, $00D8, $000C
        dw 0
        TEST_END "../out/intstate.bin"
