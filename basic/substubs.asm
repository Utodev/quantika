; substubs.asm: the FBASIC routines that live in the sub-ROM (common/fbasicsub.inc): each one calls
; there with EXTROM (AF, BC, DE, HL go and come back: the text pointer and NextChar's flags).

; SubRomCall: EXTROM, the interrupts on again afterwards (the slot call leaves them off; BASIC's traps,
; ON INTERVAL and the like, need them while a program runs).
SubRomCall:
        call CallSubRomDirect
        ei
        ret

StatementPset:
        ld ix,SubPset
        jp SubRomCall
StatementPreset:
        ld ix,SubPreset
        jp SubRomCall
StatementLineGraphic:
        ld ix,SubLineGraphic
        jp SubRomCall
StatementCircle:
        ld ix,SubCircle
        jp SubRomCall
StatementPaint:
        ld ix,SubPaint
        jp SubRomCall
StatementPut:
        ld ix,SubPut
        jp SubRomCall
StatementSprite:                        ; (SPRITE ON / OFF / STOP here: basic/traps.asm)
        cp '$'
        jr z,.pattern
        ld a,TrapSprite
        jp TrapState
.pattern:
        ld ix,SubSprite
        jp SubRomCall
StatementColorPalette:
        ld ix,SubColorPalette
        jp SubRomCall
OperandPoint:
        ld ix,SubPoint
        jp SubRomCall
StatementDraw:
        ld ix,SubDraw
        jp SubRomCall
PrintUsing:
        ld ix,SubPrintUsing
        jp SubRomCall
StatementDelete:
        ld ix,SubDelete
        jp SubRomCall
StatementRenum:
        ld ix,SubRenum
        jp SubRomCall
StatementSet:
        ld ix,SubSet
        jp SubRomCall
StatementCopy:
        ld c,TkCopy                     ; COPY "file" TO "file": the disk ROM's (H_COPY)
        ld ix,H_COPY
        call DiskHook
        ret nc
        call ThisChar
        ld ix,SubCopy
        jp SubRomCall
StatementOpen:
        ld ix,SubOpen
        jp SubRomCall
StatementClose:
        ld ix,SubClose
        jp SubRomCall
StatementMax:
        ld ix,SubMaxfiles
        jp SubRomCall
FileLayout:
        ld ix,SubFileLayout
        jp SubRomCall
CloseAllFiles:
        ld ix,SubCloseAll
        jp SubRomCall
FileForOutput:
        ld ix,SubFileForOutput
        jp SubRomCall
FileOutputChar:                         ; (OUTDO: every register kept)
        push ix
        ld ix,SubFileOutputChar
        call SubRomCall
        pop ix
        ret
InputFile:
        ld ix,SubInputFile
        jp SubRomCall
LineInputFile:
        ld ix,SubLineInputFile
        jp SubRomCall
InputFileChars:
        ld ix,SubInputFileChars
        jp SubRomCall
FuncEof:
        ld ix,SubEof
        jp SubRomCall
StatementGet:
        ld ix,SubGet
        jp SubRomCall
PromptText:
        ld ix,SubPromptText
        jp SubRomCall
OperandSprite:
        ld ix,SubSpriteFunction
        jp SubRomCall
