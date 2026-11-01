; diskservices.asm: the table of FBASIC's routines that the disk ROM calls (through CALBAS); the header
; at the end of the ROM (main_free.asm, DiskServices) points to it. common/diskapi.inc says what each entry
; takes and does. Entries are only added at the end.

DiskServiceTable:
        dw RaiseError                   ; SrvRaiseError
        dw DsEvalString                 ; SrvEvalString
        dw EvalAddress                  ; SrvEvalAddress
        dw EvalByte                     ; SrvEvalByte
        dw NewProgram                   ; SrvNewProgram
        dw DsAsciiLine                  ; SrvAsciiLine
        dw DsProgramLoaded              ; SrvProgramLoaded
        dw Ready                        ; SrvReady
        dw RunLoaded                    ; SrvRunLoaded
        dw DsListToBuffer               ; SrvListToBuffer
        dw GetVariable                  ; SrvGetVariable
        dw EvalExpression               ; SrvEvalExpression
        dw ForceInteger                 ; SrvForceInteger
        dw ForceSingle                  ; SrvForceSingle
        dw ForceDouble                  ; SrvForceDouble
        dw MakeString                   ; SrvMakeString
DiskServiceTableEnd:
        assert DiskServiceTableEnd - DiskServiceTable == 2 * SrvEntries, "the service table and diskapi.inc differ"

; DsEvalString: a string expression at HL. Out: B = its length, DE = its characters, HL past it.
DsEvalString:
        call EvalExpression
        push hl
        call StringOperand
        pop hl
        ret

; DsAsciiLine: the text in BUF up to HL as a program line (as LOAD reads a text file).
DsAsciiLine:
        ld (LoadPointer),hl
        jp AsciiLine

; DsProgramLoaded: the program's lines just put from TXTTAB: linked, VARTAB past them, no variables.
DsProgramLoaded:
        call LinkLines
        inc hl
        inc hl
        ld (VARTAB),hl
        jp ClearVariables

; DsListToBuffer: the program listed (as SAVE writes it) into the 256-byte buffer at HL; each time it is
; full it goes to H_SAVD. Out: HL past the last character in it.
DsListToBuffer:
        ld (LoadBlock),hl
        ld (LoadPointer),hl
        ld a,$80
        ld (PRTFLG),a
        ld de,$0000
        ld bc,$FFFF
        call ListRange
        xor a
        ld (PRTFLG),a
        ld hl,(LoadPointer)
        ret
