; files.asm: the files of BASIC on the devices of the machine: CRT: (the text screen), GRP: (the
; graphic screen, from GRPACX / GRPACY in the foreground colour), LPT: (the printer), CAS: (the cassette,
; one file at a time, FOR INPUT or FOR OUTPUT: an ASCII file as SAVE writes it). OPEN, CLOSE, MAXFILES,
; PRINT # (OUTDO sends a character here while PTRFIL points to a file), INPUT #, LINE INPUT #, EOF and
; INPUT$(n, #) (PTRFIL points to the file being read while they run).
;
; As the original lays them out: MAXFILES + 1 file control blocks (file 0 is BASIC's own) of 265 bytes
; just under HIMEM, FILTAB (a table of their addresses) under them, MEMSIZ two bytes under FILTAB, and
; NULBUF = file 0's buffer. A block: +0 the mode (0 closed, 1 input, 2 output, 4 random: OPEN without
; FOR, 8 append), +4 the device (FFh CAS:, FDh CRT:, FEh LPT:, FCh GRP:), +6 the column printed to, +7 and
; +8 the cassette's place in the buffer and whether it holds a block, +9 the buffer (a block of the tape).

FileMode        equ 0                   ; (offsets in a file control block; FileColumn: fbasicsub.inc)
FileDevice      equ 4
FilePosition    equ 7                   ; CAS: the place of the next character in the buffer
FileLoaded      equ 8                   ; CAS: (input) 1 while the buffer holds a block of the tape
FileBuffer      equ 9
FileBlockSize   equ FileBuffer + 256

DeviceCas       equ $FF
DeviceCrt       equ $FD
DeviceLpt       equ $FE
DeviceGrp       equ $FC
FileTypeAscii   equ $EA                 ; (a cassette file's type: basic/cassette.asm)

; FileLayout: the blocks for MAXFILES = A under HIMEM: FILTAB, NULBUF, MAXFIL, MEMSIZ, and STKTOP = MEMSIZ
; - DE (the string space's size: STKTOP + 1 to MEMSIZ, as the original). Every file closed.
FileLayout:
        ld (MAXFIL),a
        push de
        ld hl,(HIMEM)                   ; HIMEM - (MAXFILES + 1) * (2 + 265)
        ld a,(MAXFIL)
        inc a
        ld b,a
        ld de,2 + FileBlockSize
.block:
        or a
        sbc hl,de
        djnz .block
        ld (FILTAB),hl
        dec hl
        dec hl
        ld (MEMSIZ),hl
        pop de
        or a
        sbc hl,de
        jp c,OutOfMemory
        ld (STKTOP),hl
        ld hl,(FILTAB)                  ; the table: the blocks one after another past it
        ld a,(MAXFIL)
        inc a
        ld b,a
        add a,a
        ld e,a
        ld d,$00
        push hl
        add hl,de
        ex de,hl                        ; DE = the first block
        pop hl
.entry:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        xor a                           ; closed
        ld (de),a
        push hl
        ld hl,FileBlockSize
        add hl,de
        ex de,hl
        pop hl
        djnz .entry
        ld hl,(FILTAB)                  ; NULBUF: file 0's buffer
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,9
        add hl,de
        ld (NULBUF),hl
        ld hl,$0000
        ld (PTRFIL),hl
        ret

; FileBlock: the control block of file A (0 - MAXFIL). Out: HL; Bad file number past MAXFIL.
; Keeps BC, DE.
FileBlock:
        ld hl,MAXFIL
        cp (hl)
        jr z,.ok
        jr c,.ok
        ld e,ErrBadFileNumber
        jp RaiseError
.ok:
        push de
        add a,a
        ld e,a
        ld d,$00
        ld hl,(FILTAB)
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        pop de
        ret

; FileNumber: [#] n (1 - MAXFIL). Out: A = n, DE = its block.
FileNumber:
        call ThisChar
        cp '#'
        jr nz,.number
        rst $10
.number:
        call EvalByte
        or a
        jr nz,.notZero
        ld e,ErrBadFileNumber
        jp RaiseError
.notZero:
        push hl
        push af
        call FileBlock
        ex de,hl
        pop af
        pop hl
        ret

; FileForOutput: PRINT # n [,]: the file must be open to be written: PTRFIL = its block.
FileForOutput:
        call FileNumber                 ; DE = the block
        ld a,(de)
        or a
        jr nz,.open
        ld e,ErrFileNotOpen
        jp RaiseError
.open:
        cp $01
        jr nz,.writable
        ld e,ErrBadFileNumber           ; (being read)
        jp RaiseError
.writable:
        ld (PTRFIL),de
        call ThisChar
        cp ','
        ret nz
        rst $10
        ret

; StatementOpen: OPEN "device:[name]" [FOR INPUT | OUTPUT | APPEND] AS [#] n [LEN = size]. CAS: looks
; for the file on the tape (input) or writes its header (output) here.
StatementOpen:
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        push bc
        push de
        call FileDeviceOf               ; A = the device (Bad file name for another)
        pop hl
        pop bc
        cp DeviceCas
        jr nz,.notCas
        push af
        ld a,b                          ; FILNAM: the name after "CAS:"
        sub $04
        ld b,a
        inc hl
        inc hl
        inc hl
        inc hl
        call CasNameCopy
        pop af
.notCas:
        pop hl
        ld c,a
        ld b,$04                        ; B = the mode: none given
        call ThisChar
        cp TkFor
        jr nz,.as
        rst $10
        ld b,$01
        cp TkInput
        jr z,.modeTaken
        ld b,$02
        cp TkOut                        ; OUTPUT is crunched OUT PUT
        jr nz,.append
        rst $10
        cp TkPut
        jp nz,SyntaxError
        jr .modeTaken
.append:
        ld b,$08                        ; APPEND is crunched A P P END
        ld de,AppendText
.appendChar:
        ld a,(de)
        cp (hl)
        jp nz,SyntaxError
        inc de
        inc hl
        cp TkEnd
        jr nz,.appendChar
        dec hl
.modeTaken:
        rst $10
.as:
        ld a,(hl)                       ; AS (the letters)
        cp 'A'
        jp nz,SyntaxError
        rst $10
        cp 'S'
        jp nz,SyntaxError
        rst $10
        push bc
        call FileNumber                 ; DE = the block
        pop bc
        ld a,(de)
        or a
        jr z,.free
        ld e,ErrFileAlreadyOpen
        jp RaiseError
.free:
        ld a,c
        cp DeviceCas
        ld a,b
        jr nz,.writer
        cp $04                          ; the cassette: FOR INPUT or FOR OUTPUT
        jr nc,.badName
        jr .length
.writer:
        cp $01                          ; the screens and the printer only write
        jr z,.badName
        cp $08
        jr z,.badName
.length:
        call ThisChar                   ; LEN = size (read: no use without a disk)
        cp TkFunction
        jr nz,.opened
        inc hl
        ld a,(hl)
        cp FnLen
        jp nz,SyntaxError
        rst $10
        rst $08
        db TkEqual
        push bc
        push de
        call EvalByte
        pop de
        pop bc
.opened:
        ld a,c
        cp DeviceCas
        call z,CasOpen
        ld a,b
        ld (de),a                       ; the mode
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld a,c
        ld (de),a                       ; the device
        inc de
        xor a
        ld (de),a
        inc de
        ld (de),a                       ; the column
        inc de
        ld (de),a                       ; the place in the buffer
        inc de
        ld (de),a                       ; no block in it
        ret
.badName:
        ld e,ErrBadFileName
        jp RaiseError
AppendText:
        db 'A', 'P', 'P', TkEnd

; CasOpen: the cassette's part of OPEN: B = the mode (1 input: the file FILNAM is looked for, 2 output:
; its header written). Keeps BC, DE, HL.
CasOpen:
        push hl
        push de
        push bc
        ld a,FileTypeAscii
        dec b
        jr nz,.output
        call FindCasFile
        jr .done
.output:
        call WriteCasHeader
.done:
        pop bc
        pop de
        pop hl
        ret

; FileDeviceOf: the device of the file name at DE (B characters): CAS:, CRT:, LPT:, GRP: (in any case;
; a name after them does not matter here). Out: A. Bad file name for anything else.
FileDeviceOf:
        ld a,b
        cp 4
        jr c,.bad
        ld hl,DeviceNames
.device:
        ld a,(hl)
        or a
        jr z,.bad
        push de
        push hl
        ld b,4
.char:
        ld a,(de)
        call UpperCaseSub
        cp (hl)
        jr nz,.next
        inc de
        inc hl
        djnz .char
        ld a,(hl)                       ; the device's code
        pop hl
        pop de
        ret
.next:
        pop hl
        pop de
        ld bc,5
        add hl,bc
        jr .device
.bad:
        ld e,ErrBadFileName
        jp RaiseError
DeviceNames:
        db "CAS:", DeviceCas
        db "CRT:", DeviceCrt
        db "LPT:", DeviceLpt
        db "GRP:", DeviceGrp
        db 0

; StatementClose: CLOSE [[#] n [, [#] n ...]]: those files (every file without numbers).
StatementClose:
        call AtStatementEnd
        jr z,CloseAllFiles
.file:
        call FileNumber
        call CloseFile
        call ThisChar
        cp ','
        ret nz
        rst $10
        jr .file

; CloseAllFiles: every file of the program closed (END, RUN, NEW, CLEAR, MAXFILES). Keeps HL.
CloseAllFiles:
        push hl
        ld a,(MAXFIL)
        or a
        jr z,.done
.file:
        push af
        call FileBlock
        ex de,hl
        call CloseFile
        pop af
        dec a
        jr nz,.file
.done:
        pop hl
        ret

; CloseFile: the file of block DE closed (closed first: a tape error leaves it so). A CAS: file being
; written ends with 1Ah, its last block filled with it. Keeps HL, DE.
CloseFile:
        ld a,(de)
        push af
        xor a
        ld (de),a
        pop af
        cp $02
        ret nz
        push hl
        ld hl,FileDevice
        add hl,de
        ld a,(hl)
        cp DeviceCas
        jr nz,.done
        ld a,$1A
.pad:
        call CasPutChar
        ld hl,FilePosition
        add hl,de
        ld a,(hl)
        or a
        ld a,$1A
        jr nz,.pad
.done:
        pop hl
        ret

; StatementMaxfiles: MAX FILES = n (0 - 15): the blocks laid out again, every file closed, the
; variables gone (as CLEAR).
StatementMaxfiles:
        cp TkFiles
        jp nz,SyntaxError
        rst $10
        rst $08
        db TkEqual
        call EvalByte
        cp 16
        jp nc,IllegalFunction
        ld b,a
        call AtStatementEnd
        jp nz,SyntaxError
        push hl
        ld hl,(MEMSIZ)                  ; (the string space keeps its size)
        ld de,(STKTOP)
        or a
        sbc hl,de
        ex de,hl
        ld a,b
        call FileLayout
        call ClearVariables
        pop hl
        ld sp,(STKTOP)                  ; the stack starts again
        jp NewStatement

; FileOutputChar: OUTDO with PTRFIL set: A to the file's device. Keeps every register.
FileOutputChar:
        push hl
        push de
        push bc
        push af
        ld hl,(PTRFIL)
        ld de,FileColumn                ; the column: back to 0 at a carriage return
        add hl,de
        cp $0D
        jr nz,.column
        ld (hl),$FF
.column:
        inc (hl)
        ld hl,(PTRFIL)
        ld de,FileDevice
        add hl,de
        ld b,a
        ld a,(hl)
        cp DeviceCas
        ld a,b
        jr z,.cassette
        ld a,(hl)
        cp DeviceGrp
        ld a,b
        jr z,.graphic
        ld a,(hl)
        cp DeviceLpt
        ld a,b
        jr z,.printer
        call PutChar                    ; CRT:
        jr .done
.printer:
        call PrinterOutFormatted
        jr .done
.graphic:
        call GraphicChar
        jr .done
.cassette:
        ld de,(PTRFIL)
        call CasPutChar
.done:
        pop af
        pop bc
        pop de
        pop hl
        ret

; GraphicChar: GRP:'s character A (GraphicCharOp with no logical operation, whatever LOGOPR says;
; Illegal function call in a text mode).
GraphicChar:
        cp ' '
        jr c,GraphicCharOp              ; (a control character: nothing is drawn)
        ld b,a
        ld a,(SCRMOD)
        cp $02
        jp c,IllegalFunction            ; (a text mode)
        ld a,(LOGOPR)
        push af
        xor a
        ld (LOGOPR),a
        ld a,b
        call GraphicCharOp
        pop af
        ld (LOGOPR),a
        ret

; GraphicPrint: the sub-ROM's GRPPRT: GraphicCharOp with LOGOPR as it is; nothing in a text mode. Keeps
; every register.
GraphicPrint:
        push hl
        push de
        push bc
        push af
        ld b,a
        ld a,(SCRMOD)
        cp $02
        ld a,b
        call nc,GraphicCharOp
        pop af
        pop bc
        pop de
        pop hl
        ret

; GraphicCharOp: character A on a graphic screen at GRPACX / GRPACY with the logical operation of
; LOGOPR, as the original draws it: SCREEN 2 and 4 only the character's dots in
; the foreground colour (the rest stays), SCREEN 3 the same with a block of 4 x 4 for each dot, SCREEN 5-8
; the whole cell (its dots in the foreground colour, the rest in the background's). The point moves one
; character to the right; a carriage return goes to the start of the next row of characters (x 0, y one
; character down); the other control characters do nothing.
GraphicCharOp:
        cp $0D
        jr nz,.notReturn
        ld hl,$0000
        ld (GRPACX),hl
        call CharSize
        ld hl,(GRPACY)
        add hl,de
        ld (GRPACY),hl
        ret
.notReturn:
        cp ' '
        ret c
        call GetPattern                 ; its 8 rows at PATWRK
        ld a,(ATRBYT)
        push af
        ld hl,PATWRK
        ld de,(GRPACY)
        ld c,8                          ; C = rows
.row:
        ld a,(hl)
        push hl
        ld hl,(GRPACX)
        ld b,8
.dot:
        add a,a
        push af
        ld a,(FORCLR)
        jr c,.colour
        ld a,(SCRMOD)
        cp $05
        jr c,.next                      ; (the character's dots only)
        ld a,(BAKCLR)
.colour:
        ld (ATRBYT),a
        push bc
        push de
        push hl
        ld b,h
        ld c,l
        call PlotPixel
        pop hl
        pop de
        pop bc
.next:
        call DotSize
        add a,l
        ld l,a
        jr nc,.sameX
        inc h
.sameX:
        pop af
        djnz .dot
        pop hl
        inc hl
        call DotSize
        add a,e
        ld e,a
        jr nc,.sameY
        inc d
.sameY:
        dec c
        jr nz,.row
        call CharSize
        ld hl,(GRPACX)
        add hl,de
        ld (GRPACX),hl
        pop af
        ld (ATRBYT),a
        ret

; DotSize: A = the coordinates a character's dot takes: 4 in SCREEN 3 (blocks of 4 x 4), else 1.
DotSize:
        ld a,(SCRMOD)
        cp $03
        ld a,$01
        ret nz
        ld a,$04
        ret

; CharSize: DE = the coordinates a character takes (8 dots). Keeps HL, BC.
CharSize:
        call DotSize
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,$00
        ret

; CasPutChar: A into the buffer of the CAS: file of block DE; a full buffer goes to the tape. Keeps DE.
CasPutChar:
        ld hl,FilePosition
        add hl,de
        ld c,(hl)
        inc (hl)
        ld b,$00
        ld hl,FileBuffer
        add hl,de
        add hl,bc
        ld (hl),a
        ld a,c
        inc a
        ret nz
        push de
        ld hl,FileBuffer
        add hl,de
        call WriteTapeBlock
        pop de
        ret

; --- reading (only a CAS: file can be read) ---

; FileToRead: [#] n of a file to read: PTRFIL = its block. A file open for something else: the error E
; (GRP: always Illegal function call, as the original).
FileToRead:
        ld a,e
        push af
        call FileNumber                 ; DE = the block
        pop bc                          ; B = the error
        ld a,(de)
        or a
        jr nz,.open
        ld e,ErrFileNotOpen
        jp RaiseError
.open:
        dec a
        jr nz,.notInput
        ld (PTRFIL),de
        ret
.notInput:
        push hl
        ld hl,FileDevice
        add hl,de
        ld a,(hl)
        pop hl
        ld e,ErrIllegal
        cp DeviceGrp
        jp z,RaiseError
        ld e,b
        jp RaiseError

; EndFileInput: PTRFIL back to 0 (the reading is over). Keeps all but... nothing else goes.
EndFileInput:
        push de
        ld de,$0000
        ld (PTRFIL),de
        pop de
        ret

; CasPeek: A = the next character of the file being read (PTRFIL), which stays the next one: the tape's
; next block is read when the buffer has none. Keeps BC, DE, HL.
CasPeek:
        push hl
        push de
        push bc
        ld de,(PTRFIL)
        ld hl,FileLoaded
        add hl,de
        ld a,(hl)
        or a
        jr nz,.loaded
        push de
        ld hl,FileBuffer
        add hl,de
        call ReadTapeBlock
        pop de
        ld hl,FileLoaded
        add hl,de
        ld (hl),$01
.loaded:
        ld hl,FilePosition
        add hl,de
        ld c,(hl)
        ld b,$00
        ld hl,FileBuffer
        add hl,de
        add hl,bc
        ld a,(hl)
        pop bc
        pop de
        pop hl
        ret

; CasNext: past the next character of the file being read. Keeps all.
CasNext:
        push af
        push hl
        push de
        ld de,(PTRFIL)
        ld hl,FilePosition
        add hl,de
        inc (hl)
        jr nz,.done
        inc hl                          ; (FileLoaded) the block is over
        ld (hl),$00
.done:
        pop de
        pop hl
        pop af
        ret

; CasGet: the next character of the file being read, taken. Input past end at the end (1Ah).
CasGet:
        call CasPeek
        cp $1A
        jp nz,CasNext
InputPastEnd:
        ld e,ErrInputPastEnd
        jp RaiseError

; InputFile: INPUT # n, variable [, variable ...] (HL on '#').
InputFile:
        ld e,ErrBadFileNumber
        call FileToRead
        call Comma
.variable:
        call GetVariable
        push hl
        push de
        ld a,(VALTYP)
        push af
        call ReadField                  ; BUF = the field's text
        pop af
        push af
        ld hl,BUF
        cp TypeString
        jr nz,.number
        call StringFromZeroEnded
        jr .assign
.number:
        call ThisChar
        call FinNumber                  ; (not a number: 0)
.assign:
        pop af
        pop de
        call AssignValue
        pop hl
        call ThisChar
        cp ','
        jp nz,EndFileInput
        rst $10
        jr .variable

; ReadField: the next field of the file being read into BUF (ended by 0; up to 255 characters) for a
; variable of type A. Spaces, CR and LF in front are passed over (Input past end at the end of the file).
; A string in quotes goes up to the next quote (CR and LF are characters there), any other string up to
; ',' or CR (the spaces before them stay in it), a number up to ',', CR or a space. Then the spaces after
; it are passed over, and one ',' or CR (with the LF after it) taken.
ReadField:
        ld c,a                          ; C = the type
.skip:
        call CasPeek
        cp ' '
        jr z,.skipIt
        cp $0D
        jr z,.skipIt
        cp $0A
        jr nz,.start
.skipIt:
        call CasNext
        jr .skip
.start:
        cp $1A
        jr z,InputPastEnd
        ld hl,BUF
        ld b,$FF
        ld a,c
        cp TypeString
        jr nz,.numberChar
        call CasPeek
        cp '"'
        jr nz,.plainChar
        call CasNext                    ; the opening quote
.quotedChar:
        call CasPeek
        cp $1A
        jr z,.end
        call CasNext
        cp '"'
        jr z,.end
        ld (hl),a
        inc hl
        djnz .quotedChar
        jr .end
.plainChar:
        call CasPeek
        call .fieldEnd
        jr z,.end
        call CasNext
        ld (hl),a
        inc hl
        djnz .plainChar
        jr .end
.numberChar:
        call CasPeek
        cp ' '
        jr z,.end
        call .fieldEnd
        jr z,.end
        call CasNext
        ld (hl),a
        inc hl
        djnz .numberChar
.end:
        ld (hl),$00
.tail:
        call CasPeek
        cp ' '
        jr nz,.notSpace
        call CasNext
        jr .tail
.notSpace:
        cp ','
        jp z,CasNext
        cp $0D
        ret nz
        call CasNext
        call CasPeek
        cp $0A
        ret nz
        jp CasNext
.fieldEnd:                              ; Z for 1Ah, ',' or CR
        cp $1A
        ret z
        cp ','
        ret z
        cp $0D
        ret

; LineInputFile: LINE INPUT # n, string variable (HL on '#'): the characters up to CR (taken, with the LF
; after it) or the end of the file; up to 255.
LineInputFile:
        ld e,ErrBadFileNumber
        call FileToRead
        call Comma
        call GetVariable
        ld a,(VALTYP)
        cp TypeString
        jp nz,TypeMismatch
        push hl
        push de
        call CasPeek
        cp $1A
        jp z,InputPastEnd
        ld hl,BUF
        ld b,$FF
.char:
        call CasPeek
        cp $1A
        jr z,.end
        call CasNext
        cp $0D
        jr z,.return
        ld (hl),a
        inc hl
        djnz .char
        jr .end
.return:
        call CasPeek
        cp $0A
        call z,CasNext
.end:
        ld (hl),$00
        ld hl,BUF
        call StringFromZeroEnded
        pop de
        ld a,TypeString
        call AssignValue
        pop hl
        jp EndFileInput

; InputFileChars: INPUT$(n, [#] f) once n is read (B, HL on ','): the next n characters of the file.
InputFileChars:
        rst $10
        push bc
        ld e,ErrInputPastEnd
        call FileToRead
        call CloseBracket
        pop bc
        ld c,' '
        call RepeatedString             ; the room for them
        push hl
        ld hl,(DAC + 2)                 ; its descriptor: length, address
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
.char:
        call CasGet
        ld (de),a
        inc de
        djnz .char
        pop hl
        jp EndFileInput

; FuncEof: EOF(n): -1 when the file being read is at its end, else 0 (0 for a CAS: file being written;
; Illegal function call for the other devices).
FuncEof:
        call ThisChar
        rst $08
        db '('
        call FileNumber                 ; DE = the block
        call CloseBracket
        ld a,(de)
        or a
        jr nz,.open
        ld e,ErrFileNotOpen
        jp RaiseError
.open:
        push hl
        dec a
        jr nz,.notInput
        ld (PTRFIL),de
        call CasPeek
        call EndFileInput
        ld de,$0000
        cp $1A
        jr nz,.result
        dec de
        jr .result
.notInput:
        ld hl,FileDevice
        add hl,de
        ld a,(hl)
        cp DeviceCas
        jp nz,IllegalFunction
        ld de,$0000
.result:
        pop hl
        jp SetIntegerResult
