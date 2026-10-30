; cassette.asm: the cassette statements: CLOAD, CSAVE, BLOAD, BSAVE, LOAD, SAVE, MERGE, RUN "file",
; MOTOR. The cassette files (the standard's format):
;   a header block: 10 bytes of the type (D3h tokenized BASIC, D0h binary, EAh ASCII), 6 of the name
;   tokenized BASIC: one block, the program as it is in memory, then zeros (the end is 00 00 00)
;   binary: one block: start, end, run address (2 bytes each), then the bytes from start to end
;   ASCII: blocks of 256 bytes of text (lines ended by CR LF), the end of the text marked by 1Ah
; A file name is "CAS:NAME" (the device may be left out: the cassette is the only one here; a disk ROM
; takes the other names through its hooks). Up to 6 characters; none means the first file of its type.

CasTypeBasic    equ $D3
CasTypeBinary   equ $D0
CasTypeAscii    equ $EA
CasNameLength   equ 6

; FileSpec: a string expression with a file name: FILNAM = the name (6 characters, spaces after).
; Bad file name for a device other than CAS:. Keeps HL moving past the expression.
FileSpec:
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        ex de,hl                        ; HL = the characters
        ld a,b
        cp $04                          ; "CAS:" in front?
        jr c,.name
        push hl
        push bc
        ld de,CasDevice
        ld b,$04
.device:
        ld a,(hl)
        call UpperCase
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,.notCas
        inc hl
        inc de
        djnz .device
        pop bc
        pop af                          ; (the start: dropped)
        ld a,b
        sub $04
        ld b,a
        jr .name
.notCas:
        pop bc
        pop hl
        push hl                         ; another device ("X:" in the first characters): not here
        push bc
        ld a,b
        cp $02
        jr c,.noDevice
        inc hl
        ld a,(hl)
        cp ':'
        ld e,ErrBadFileName
        jp z,RaiseError
.noDevice:
        pop bc
        pop hl
.name:
        call CasNameCopy
        pop hl
        ret
CasDevice:
        db "CAS:"

; CasNameCopy: FILNAM = the B characters at HL (the first 6; spaces after them).
CasNameCopy:
        push hl
        ld hl,FILNAM
        ld c,CasNameLength
.clear:
        ld (hl),' '
        inc hl
        dec c
        jr nz,.clear
        pop hl
        ld de,FILNAM
        ld a,b
        or a
        ret z
        cp CasNameLength + 1
        jr c,.copy
        ld b,CasNameLength
.copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        djnz .copy
        ret

; FindCasFile: the next header of type A whose name is FILNAM (any when FILNAM is spaces) on the tape;
; "Skip :" for the other files, "Found:" for it (only in direct mode). A block that is not a header (its
; first 10 bytes are not all alike: a file's data) is passed over without a word. Device I/O error on
; CTRL+STOP.
FindCasFile:
        ld (CasFileType),a
.header:
        call TapeInStart
        jp c,CasStopped
        ld b,10                         ; type (10 bytes) then name (6 bytes)
        ld c,$00                        ; C = bytes unlike the first one
.typeByte:
        push bc
        call TapeInByte
        pop bc
        jp c,CasStopped
        ld e,a
        ld a,b
        cp 10
        jr nz,.notFirst
        ld a,e
        ld (FILNM2),a                   ; (the first one, until the name comes)
.notFirst:
        ld a,(FILNM2)
        cp e
        jr z,.alike
        inc c
.alike:
        djnz .typeByte
        ld a,c
        or a
        jr z,.isHeader
        call TapeInStop                 ; data: not a header
        jr .header
.isHeader:
        ld a,(CasFileType)              ; C = 1 for a file of another type
        cp e
        jr z,.typeOk
        inc c
.typeOk:
        ld hl,FILNM2
        ld b,CasNameLength
.nameByte:
        push bc
        push hl
        call TapeInByte
        pop hl
        pop bc
        jp c,CasStopped
        ld (hl),a
        inc hl
        djnz .nameByte
        call TapeInStop
        ld a,c
        or a
        jr nz,.skip                     ; another type
        ld hl,FILNAM                    ; the name asked for: none (spaces) or the same
        ld a,(hl)
        cp ' '
        jr z,.found
        ld de,FILNM2
        ld b,CasNameLength
.compare:
        ld a,(de)
        cp (hl)
        jr nz,.skip
        inc hl
        inc de
        djnz .compare
.found:
        ld hl,FoundText
        call PrintTapeName
        ret
.skip:
        ld hl,SkipText
        call PrintTapeName
        jr .header
CasFileType     equ TEMP8               ; the type looked for (one byte)

; PrintTapeName: the text at HL, then the 6 characters of FILNM2, then a new line; only in direct mode
; (a program says nothing). Destroys all.
PrintTapeName:
        push hl
        ld hl,(CURLIN)
        ld a,h
        and l
        inc a
        pop hl
        ret nz
        call PrintString
        ld hl,FILNM2
        ld b,CasNameLength
.char:
        ld a,(hl)
        rst $18
        inc hl
        djnz .char
        jp PrintCrLf
FoundText:
        db "Found:",0
SkipText:
        db "Skip :",0

CasStopped:
        call TapeInStop
        ld e,ErrDeviceIO
        jp RaiseError

; ReadTapeByte: one byte of the data block (Device I/O error on a broken signal). Keeps BC, DE, HL.
ReadTapeByte:
        push hl
        push de
        push bc
        call TapeInByte
        pop bc
        pop de
        pop hl
        jp c,CasStopped
        ret

; --- CLOAD / CSAVE ---

; StatementCload: CLOAD ["name"] (CLOAD? compares instead: the program in memory stays).
StatementCload:
        cp '?'
        jp z,SyntaxError                ; (CLOAD? : not written)
        call FilenameOrNone
        push hl
        ld a,CasTypeBasic
        call FindCasFile
        call NewProgram
        call TapeInStart
        jp c,CasStopped
        ld hl,(TXTTAB)
        ld c,$00                        ; C = zeros in a row
.byte:
        call ReadTapeByte
        ld (hl),a
        inc hl
        or a
        jr nz,.notZero
        inc c
        ld a,c
        cp $03
        jr z,.end                       ; 00 00 00: the end of the program
        jr .room
.notZero:
        ld c,$00
.room:
        push hl                         ; the program must stay under the stack
        ld de,$0100
        add hl,de
        ex de,hl
        ld hl,$0000
        add hl,sp
        rst $20
        pop hl
        jr nc,.byte
        call TapeInStop
        call NewProgram
        jp OutOfMemory
.end:
        call TapeInStop
        call LinkLines
        inc hl
        inc hl
        ld (VARTAB),hl
        call ClearVariables
        pop hl
        jp Ready                        ; (Ok)

; FilenameOrNone: a file name if the statement has one, else FILNAM = spaces.
FilenameOrNone:
        call AtStatementEnd
        jp nz,FileSpec
        push hl
        ld hl,FILNAM
        ld b,CasNameLength
.space:
        ld (hl),' '
        inc hl
        djnz .space
        pop hl
        ret

; StatementCsave: CSAVE "name".
StatementCsave:
        call FileSpec
        push hl
        ld a,CasTypeBasic
        call WriteCasHeader
        xor a                           ; the data block
        call TapeOutStart
        jp c,CasStoppedOut
        ld hl,(TXTTAB)
        ld de,(VARTAB)
.byte:
        rst $20
        jr nc,.zeros
        ld a,(hl)
        call WriteTapeByte
        inc hl
        jr .byte
.zeros:
        ld b,$07
.zero:
        xor a
        call WriteTapeByte
        djnz .zero
        call TapeOutStop
        pop hl
        ret

; WriteCasHeader: the header block of type A with FILNAM.
WriteCasHeader:
        push af
        ld a,$01                        ; a long header
        call TapeOutStart
        jp c,CasStoppedOut
        pop af
        ld b,10
.type:
        call WriteTapeByte
        djnz .type
        ld hl,FILNAM
        ld b,CasNameLength
.name:
        ld a,(hl)
        call WriteTapeByte
        inc hl
        djnz .name
        jp TapeOutStop

; WriteTapeByte: A to the tape (Device I/O error on CTRL+STOP). Keeps AF, BC, DE, HL.
WriteTapeByte:
        push hl
        push de
        push bc
        push af
        call TapeOutByte
        pop bc
        ld a,b
        pop bc
        pop de
        pop hl
        ret nc
CasStoppedOut:
        call TapeOutStop
        ld e,ErrDeviceIO
        jp RaiseError

; --- BLOAD / BSAVE ---

; StatementBload: BLOAD "name" [, R] [, offset].
StatementBload:
        call FileSpec
        ld de,$0000
        ld (TEMP2),de                   ; offset
        xor a
        ld (TEMP3),a                    ; run it?
.option:
        call ThisChar
        cp ','
        jr nz,.load
        rst $10
        cp 'R'
        jr nz,.offset
        rst $10
        ld a,$01
        ld (TEMP3),a
        jr .option
.offset:
        call EvalAddress
        ld (TEMP2),de
        jr .option
.load:
        push hl
        ld a,CasTypeBinary
        call FindCasFile
        call TapeInStart
        jp c,CasStopped
        call ReadTapeWord               ; start
        push de
        call ReadTapeWord               ; end
        push de
        call ReadTapeWord               ; run address
        ld (TEMP9),de
        pop de                          ; end
        pop hl                          ; start
        ld bc,(TEMP2)                   ; with the offset
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
.byte:
        call ReadTapeByte
        ld (hl),a
        rst $20                         ; start - end
        inc hl
        jr nz,.byte
        call TapeInStop
        pop hl
        ld a,(TEMP3)
        or a
        ret z
        push hl                         ; ,R: run it (it may come back to BASIC)
        ld hl,(TEMP9)
        ld bc,(TEMP2)
        add hl,bc
        ld de,.back
        push de
        jp (hl)
.back:
        pop hl
        ret

; ReadTapeBlock: a block of 256 bytes from the tape to HL (its own short header first). Device I/O error
; on CTRL+STOP or a broken signal. Destroys all.
ReadTapeBlock:
        push hl
        call TapeInStart
        pop hl
        jp c,CasStopped
        ld b,$00
.byte:
        call ReadTapeByte
        ld (hl),a
        inc hl
        djnz .byte
        jp TapeInStop

; WriteTapeBlock: the 256 bytes at HL to the tape, after a short header. Destroys all.
WriteTapeBlock:
        push hl
        xor a
        call TapeOutStart
        pop hl
        jp c,CasStoppedOut
        ld b,$00
.byte:
        ld a,(hl)
        call WriteTapeByte
        inc hl
        djnz .byte
        jp TapeOutStop

; ReadTapeWord: DE = two bytes of the tape (low first).
ReadTapeWord:
        call ReadTapeByte
        ld e,a
        call ReadTapeByte
        ld d,a
        ret

; StatementBsave: BSAVE "name", start, end [, run address].
StatementBsave:
        call FileSpec
        call Comma
        call EvalAddress
        push de
        call Comma
        call EvalAddress
        push de
        pop bc                          ; BC = end
        pop de                          ; DE = start
        push de
        push bc
        ld (TEMP9),de                   ; the run address: the start by default
        call ThisChar
        cp ','
        jr nz,.write
        rst $10
        call EvalAddress
        ld (TEMP9),de
.write:
        pop bc
        pop de
        push hl
        push de
        push bc
        ld a,CasTypeBinary
        call WriteCasHeader
        xor a
        call TapeOutStart
        jp c,CasStoppedOut
        pop bc
        pop de
        push de
        push bc
        ld a,e                          ; start, end, run
        call WriteTapeByte
        ld a,d
        call WriteTapeByte
        ld a,c
        call WriteTapeByte
        ld a,b
        call WriteTapeByte
        ld a,(TEMP9)
        call WriteTapeByte
        ld a,(TEMP9 + 1)
        call WriteTapeByte
        pop de                          ; end
        pop hl                          ; start
.byte:
        ld a,(hl)
        call WriteTapeByte
        rst $20
        inc hl
        jr nz,.byte
        call TapeOutStop
        pop hl
        ret

; --- LOAD / RUN "file" / MERGE (ASCII) and SAVE ---

; StatementLoad: LOAD "name" [, R]. StatementMerge: MERGE "name" (the program in memory stays).
StatementMerge:
        call FileSpec
        xor a
        jr LoadAscii.keep
StatementLoad:
        call FileSpec
        ld a,$01                        ; bit 0: new program
        push af
        call ThisChar
        cp ','
        jr nz,.noRun
        rst $10
        rst $08
        db 'R'
        pop af
        or $02                          ; bit 1: run it
        push af
.noRun:
        pop af
LoadAscii:
.keep:
        ld (LoadFlags),a
        push hl
        ld a,CasTypeAscii
        call FindCasFile
        ld a,(LoadFlags)
        rrca
        call c,NewProgram
        ld hl,BUF                       ; the line being read
        ld (LoadPointer),hl
.block:
        ld hl,(STKTOP)                  ; the block's buffer: under the stack's own room (read first,
        ld de,$0180                     ; then used)
        or a
        sbc hl,de
        ld (LoadBlock),hl
        call ReadTapeBlock
        ld hl,(LoadBlock)
        ld b,$00
.char:
        ld a,(hl)
        inc hl
        cp $1A
        jr z,.endOfFile
        cp $0A
        jr z,.next
        cp $0D
        jr z,.endOfLine
        push hl
        ld hl,(LoadPointer)
        ld (hl),a
        inc hl
        ld (LoadPointer),hl
        pop hl
        jr .next
.endOfLine:
        push hl
        push bc
        call AsciiLine
        pop bc
        pop hl
.next:
        djnz .char
        jr .block
.endOfFile:
        call AsciiLine                  ; the last line (if it had no CR)
        pop hl
        ld a,(LoadFlags)
        and $02
        jp z,Ready
        ld hl,(TXTTAB)                  ; ,R: RUN
        dec hl
        ld sp,(STKTOP)
        call ClearVariables
        ld bc,$0000
        ld (CURLIN),bc
        jp NewStatement

; AsciiLine: the text gathered in BUF as a program line (Direct statement in file without a number).
AsciiLine:
        ld hl,(LoadPointer)
        ld (hl),$00
        ld hl,BUF
        ld (LoadPointer),hl
        call ThisChar
        jr c,.numbered
        or a
        ret z                           ; an empty line
        ld hl,$FFFF                     ; (said as in direct mode: the program is not what it was)
        ld (CURLIN),hl
        ld e,ErrDirectInFile
        jp RaiseError
.numbered:
        ld de,$0000
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
        jr .digit
.numberDone:
        push de
        call ThisChar
        call Crunch
        pop de
        jp StoreLine

LoadBlock       equ SWPTMP              ; the 256-byte block's buffer (an address)
LoadPointer     equ SWPTMP + 2          ; where the next character of the line goes
LoadFlags       equ SWPTMP + 4          ; bit 0: a new program, bit 1: RUN after

; RunFile: RUN "name": LOAD "name", R.
RunFile:
        call FileSpec
        ld a,$03
        jp LoadAscii.keep

; StatementSave: SAVE "name": the program as text (an ASCII file) in blocks of 256 bytes.
StatementSave:
        call FileSpec
        push hl
        ld a,CasTypeAscii
        call WriteCasHeader
        ld hl,(STKTOP)
        ld de,$0180
        or a
        sbc hl,de
        ld (LoadBlock),hl
        ld (LoadPointer),hl
        ld a,$80                        ; OUTDO sends the listing to the tape buffer
        ld (PRTFLG),a
        ld de,$0000
        ld bc,$FFFF
        call ListRange
        ld a,$1A
        call TapeBufferChar
        call FlushTapeBufferLast
        xor a
        ld (PRTFLG),a
        pop hl
        ret

; TapeBufferChar: one character of SAVE's text into the 256-byte buffer; a full buffer is written.
; Keeps all.
TapeBufferChar:
        push af
        push hl
        push bc
        push de
        ld hl,(LoadPointer)
        ld (hl),a
        inc hl
        ld (LoadPointer),hl
        ld de,(LoadBlock)
        or a
        sbc hl,de
        ld a,h
        or a
        call nz,FlushTapeBuffer         ; 256 characters
        pop de
        pop bc
        pop hl
        pop af
        ret

; FlushTapeBuffer: the 256-byte block to the tape.
FlushTapeBuffer:
        ld hl,(LoadBlock)
        call WriteTapeBlock
        ld hl,(LoadBlock)
        ld (LoadPointer),hl
        ret
; FlushTapeBufferLast: the rest padded with 1Ah to 256, then written.
FlushTapeBufferLast:
        ld hl,(LoadPointer)
        ld de,(LoadBlock)
        or a
        sbc hl,de
        ld a,h
        or l
        ret z                           ; (just written)
        ld a,$1A
        call TapeBufferChar
        jr FlushTapeBufferLast

; StatementMotor: MOTOR [ON | OFF]: the cassette motor (no argument: the other way).
StatementMotor:
        ld e,$FF
        call AtStatementEnd
        jr z,.set
        ld e,$01
        cp TkOn
        jr z,.word
        ld e,$00
        cp TkOff
        jp nz,SyntaxError
.word:
        rst $10
.set:
        push hl
        ld a,e
        call SetTapeMotor
        pop hl
        ret
