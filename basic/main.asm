; main.asm: FBASIC starts here (after the BIOS has started the ROMs), and comes back to Ready after
; every direct statement, the end of a program and errors: the Ok prompt and the lines typed.

StringSpaceSize equ 200                 ; the string space at power on (CLEAR changes it)

; BasicColdStart: memory, the banner, NEW, and Ready.
BasicColdStart:
        ld hl,(BOTTOM)                  ; the program from BOTTOM + 1 (BOTTOM holds a 0)
        ld (hl),$00
        inc hl
        ld (TXTTAB),hl
        ld a,1                          ; MAXFILES = 1: the file blocks under HIMEM (the disk ROM may
        ld de,StringSpaceSize           ; have taken memory under it), then the string space
        call FileLayout
        ld sp,(STKTOP)
        ld a,':'
        ld (KBFMIN),a                   ; the direct line runs from here
        xor a
        ld (PRTFLG),a
        ld (TRCFLG),a
        ld hl,USRTAB                    ; USR with no DEFUSR: Illegal function call
        ld de,IllegalFunction
        ld b,10
.usr:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        djnz .usr
        call InitMusic
        call NewProgram
        ld hl,BasicBanner
        call PrintString
        call PrintMemory
; Ready: the Ok prompt, then lines are typed.
Ready:
        ld sp,(STKTOP)
        ld hl,$FFFF
        ld (CURLIN),hl
        xor a
        ld (PRTFLG),a
        ld (INSFLG),a
        call FreeTemps
        call H_READ
        call ForceTextMode              ; ("Ok" in a text mode)
        call NewLineIfNeeded
        ld hl,OkText
        call PromptText                 ; (SET PROMPT's text instead, at BUF)
        jr nz,.prompt
        ld hl,BUF
.prompt:
        call PrintString
DirectLoop:
        ld sp,(STKTOP)
        ld hl,$FFFF
        ld (CURLIN),hl
        call H_MAIN
        ld a,(AUTFLG)
        or a
        jr nz,AutoLine
        call InputLine
        jr c,DirectLoop                 ; CTRL+STOP
        ld hl,BUF
        call ThisChar
        jr c,.numbered                  ; it starts with a digit: a program line
        or a
        jr z,DirectLoop                 ; an empty line
        call Crunch
        ld hl,KBFMIN
        jp RunFrom
.numbered:
        ld de,$0000                     ; the line number
.digit:
        ld a,(hl)
        sub '0'
        jr c,.numberDone
        cp 10
        jr nc,.numberDone
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,a
        ld d,$00
        add hl,de
        ex de,hl
        pop hl
        inc hl
        ld a,d
        cp $FF                          ; above 65529: Syntax error
        jr c,.digit
        ld a,e
        cp $FA
        jp nc,SyntaxError
        jr .digit
.numberDone:
        push de
        call ThisChar                   ; the spaces after the number go
        call Crunch                     ; B = bytes
        pop de
        call StoreLine
        jp DirectLoop

; AutoLine: AUTO: the line's number is written first ('*' after it when the program has that line);
; what is typed after it is that line (nothing: the line stays as it is). CTRL+STOP ends AUTO.
AutoLine:
        ld hl,(AUTLIN)
        push hl
        call PrintUnsigned
        pop de
        call FindLine
        ld a,' '
        jr nc,.mark
        ld a,'*'
.mark:
        rst $18
        call InputLine
        jr c,.stop
        ld de,(AUTLIN)
        push de
        ld hl,(AUTINC)                  ; the next number (past 65529: AUTO ends)
        add hl,de
        jr c,.last
        ld de,65530
        rst $20
        jr c,.next
.last:
        xor a
        ld (AUTFLG),a
.next:
        ld (AUTLIN),hl
        pop de
        ld hl,BUF
        call ThisChar
        or a
        jp z,DirectLoop
        jp DirectLoop.numberDone
.stop:
        xor a
        ld (AUTFLG),a
        jp Ready

; StatementAuto: AUTO [first] [, increment] (10, 10).
StatementAuto:
        ld de,10
        ld bc,10
        call AtStatementEnd
        jr z,.set
        cp ','
        jr z,.step
        call GetLineNumber
        jp c,SyntaxError
        call ThisChar
        cp ','
        jr nz,.set
.step:
        rst $10
        push de
        call GetLineNumber
        jp c,SyntaxError
        ld b,d
        ld c,e
        pop de
        ld a,b
        or c
        jp z,IllegalFunction
.set:
        call AtStatementEnd
        jp nz,SyntaxError
        ld (AUTLIN),de
        ld (AUTINC),bc
        ld a,$01
        ld (AUTFLG),a
        jp DirectLoop

OkText:
        db "Ok",$0D,$0A,0
BasicBanner:                            ; (BUILD_STAMP: the build's date and time, out/buildstamp.inc)
        db "QUANTIKA ROM with FBASIC 1.0",$0D,$0A
        db "Build: ",BUILD_STAMP,$0D,$0A,0

; PrintMemory: the boot's line "RAM: nK VRAM: nK": the memory mapper's size and the VRAM's (MODE bits
; 2-1: 16K, 64K, 128K).
PrintMemory:
        ld hl,RamText
        call PrintString
        call MapperSize                 ; A = segments of 16K (0: 256)
        ld l,a
        ld h,$00
        or a
        jr nz,.segments
        inc h
.segments:
        add hl,hl                       ; * 16
        add hl,hl
        add hl,hl
        add hl,hl
        call PrintUnsigned
        ld hl,VramText
        call PrintString
        ld a,(MODE)
        and $06
        ld hl,16
        jr z,.vram
        ld hl,64
        cp $02
        jr z,.vram
        ld hl,128
.vram:
        call PrintUnsigned
        ld hl,KiloText
        jp PrintString
RamText:
        db "RAM: ",0
VramText:
        db "K VRAM: ",0
KiloText:
        db "K",$0D,$0A,0

; MapperSize: A = the memory mapper's segments of 16K (0 for 256). Each segment, from the last number to
; the first, gets its number at 8000h (page 2) after what was there is kept in BUF; reading them back
; from the first, the first one that does not keep its number is where the numbers wrap around. Then the
; bytes go back (from the first, so a segment ends with the byte it had before) and page 2 shows segment
; 1 again. Interrupts are off meanwhile.
MapperSize:
        di
        ld hl,$8000
        ld b,$00                        ; B = the segment: 255 down to 0
.mark:
        dec b
        ld a,b
        out (MapperPage2),a
        ld e,b
        ld d,$00
        push hl
        ld hl,BUF
        add hl,de
        ex de,hl
        pop hl
        ld a,(hl)
        ld (de),a
        ld (hl),b
        ld a,b
        or a
        jr nz,.mark
        ld c,$00                        ; C = the size: 0 (256) unless a segment lost its number
.find:
        inc b
        jr z,.restore
        ld a,b
        out (MapperPage2),a
        cp (hl)
        jr z,.find
        ld c,b
.restore:
        ld b,$00                        ; B = 0 to 255
.back:
        ld a,b
        out (MapperPage2),a
        ld e,b
        ld d,$00
        push hl
        ld hl,BUF
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc b
        jr nz,.back
        ld a,$01
        out (MapperPage2),a
        ei
        ld a,c
        ret

