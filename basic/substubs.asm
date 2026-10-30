; substubs.asm: the FBASIC routines that live in the sub-ROM (common/fbasicsub.inc): each one calls
; there with EXTROM (AF, BC, DE, HL go and come back: the text pointer and NextChar's flags).

StatementPset:
        ld ix,SubPset
        jp CallSubRomDirect
StatementPreset:
        ld ix,SubPreset
        jp CallSubRomDirect
StatementLineGraphic:
        ld ix,SubLineGraphic
        jp CallSubRomDirect
StatementCircle:
        ld ix,SubCircle
        jp CallSubRomDirect
StatementPaint:
        ld ix,SubPaint
        jp CallSubRomDirect
StatementPut:
        ld ix,SubPut
        jp CallSubRomDirect
StatementSprite:                        ; (SPRITE ON / OFF / STOP here: basic/traps.asm)
        cp '$'
        jr z,.pattern
        ld a,TrapSprite
        jp TrapState
.pattern:
        ld ix,SubSprite
        jp CallSubRomDirect
StatementColorPalette:
        ld ix,SubColorPalette
        jp CallSubRomDirect
OperandPoint:
        ld ix,SubPoint
        jp CallSubRomDirect
StatementDraw:
        ld ix,SubDraw
        jp CallSubRomDirect
PrintUsing:
        ld ix,SubPrintUsing
        jp CallSubRomDirect
StatementDelete:
        ld ix,SubDelete
        jp CallSubRomDirect
StatementRenum:
        ld ix,SubRenum
        jp CallSubRomDirect
StatementSet:
        ld ix,SubSet
        jp CallSubRomDirect
StatementCopy:
        ld ix,SubCopy
        jp CallSubRomDirect
StatementOpen:
        ld ix,SubOpen
        jp CallSubRomDirect
StatementClose:
        ld ix,SubClose
        jp CallSubRomDirect
StatementMax:
        ld ix,SubMaxfiles
        jp CallSubRomDirect
FileLayout:
        ld ix,SubFileLayout
        jp CallSubRomDirect
CloseAllFiles:
        ld ix,SubCloseAll
        jp CallSubRomDirect
FileForOutput:
        ld ix,SubFileForOutput
        jp CallSubRomDirect
FileOutputChar:                         ; (OUTDO: every register kept)
        push ix
        ld ix,SubFileOutputChar
        call CallSubRomDirect
        pop ix
        ret
InputFile:
        ld ix,SubInputFile
        jp CallSubRomDirect
LineInputFile:
        ld ix,SubLineInputFile
        jp CallSubRomDirect
InputFileChars:
        ld ix,SubInputFileChars
        jp CallSubRomDirect
FuncEof:
        ld ix,SubEof
        jp CallSubRomDirect
