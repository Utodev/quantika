; sub_free.asm: a free sub-ROM, written from the published standard: the entry points of
; common/subrom.inc with this ROM's own code behind them. It sits in page 0 of its slot (3-1 in emu80),
; where the main ROM is not visible: it reaches the main ROM through the RAM primitives (CLPRIM, RDPRIM).
; Build with build.sh.

        device NOSLOT64K
        org $0000
        ds $4000, $FF

        include "hw.inc"
        include "sysvars.inc"
        include "subrom.inc"
        include "mathpack.inc"
        include "tokens.inc"
        include "errors.inc"
        include "fbasicsub.inc"

; --- main ROM entries used here ---
MainInitText    equ $006C
MainInitText32  equ $006F
MainInitGraphic equ $0072
MainInitMulti   equ $0075
MainSetText     equ $0078
MainSetText32   equ $007B
MainSetGraphic  equ $007E
MainSetMulti    equ $0081
MainClearSprites equ $0069
MainChangeMode  equ $005F
MainCls         equ $00C3
MainBeep        equ $00C0
MainShowKeys    equ $00CF
MainFont        equ $1BBF

        org $0000
SubRomHeader:
        db "CD"                         ; (the main ROM finds the sub-ROM by these two letters)
        dw SubInit                      ; INIT
        dw $0000, $0000                 ; no statements, no device

; --- the RSTs: the code from the main ROM's BASIC that runs here uses them ---
;     (NextChar and OutputChar are wrappers into the main ROM: out/subwrappers.inc)
        org $0008
        jp SubSyntaxCheck
        org $0010
        jp NextChar
        org $0018
        jp OutputChar
        org $0020
CompareHLDE:                            ; DCOMPR
        ld a,h
        cp d
        ret nz
        ld a,l
        cp e
        ret

; --- the interrupt: while the sub-ROM is in page 0, RST 38h comes here: the main ROM's handler runs
;     (through CallMain; IX and the other AF, which CallMain uses, are kept) ---
        org $0038
SubInterrupt:
        push ix
        ex af,af'
        push af
        ex af,af'
        ld ix,$0038
        call CallMain
        ex af,af'
        pop af
        ex af,af'
        pop ix
        ret

; --- the entry points (4 bytes apart; a JP in each) ---
        macro SUB_ENTRY address, target
        org address
        jp target
        endm

        SUB_ENTRY SubRomBasicPaint, BasicHandler
        SUB_ENTRY SubRomBasicPset, BasicHandler
        SUB_ENTRY SubRomBasicAttrScan, BasicHandler
        SUB_ENTRY SubRomBasicGline, BasicHandler
        SUB_ENTRY SubRomBasicBoxFill, BasicHandler
        SUB_ENTRY SubRomBasicLine, BasicHandler
        SUB_ENTRY SubRomBasicBox, BasicHandler
        SUB_ENTRY SubRomDrawLine, NotWritten
        SUB_ENTRY SubRomGraphicPrint, GraphicPrint
        SUB_ENTRY SubRomClipXY, NotWritten
        SUB_ENTRY SubRomMapXY, NotWritten
        SUB_ENTRY SubRomReadPixel, NotWritten
        SUB_ENTRY SubRomSetAttribute, NotWritten
        SUB_ENTRY SubRomSetPixel, NotWritten
        SUB_ENTRY SubRomPixelRightTest, NotWritten
        SUB_ENTRY SubRomPixelRight, NotWritten
        SUB_ENTRY SubRomPixelLeftTest, NotWritten
        SUB_ENTRY SubRomPixelLeft, NotWritten
        SUB_ENTRY SubRomPixelDownTest, NotWritten
        SUB_ENTRY SubRomPixelDown, NotWritten
        SUB_ENTRY SubRomPixelUpTest, NotWritten
        SUB_ENTRY SubRomPixelUp, NotWritten
        SUB_ENTRY SubRomScanRight, NotWritten
        SUB_ENTRY SubRomScanLeft, NotWritten
        SUB_ENTRY SubRomBox, NotWritten
        SUB_ENTRY SubRomBoxFill, NotWritten
        SUB_ENTRY SubRomChangeMode, ChangeMode
        SUB_ENTRY SubRomInitText, InitText
        SUB_ENTRY SubRomInitText32, InitText32
        SUB_ENTRY SubRomInitGraphic, InitGraphic
        SUB_ENTRY SubRomInitMulticolour, InitMulticolour
        SUB_ENTRY SubRomSetText, SetText
        SUB_ENTRY SubRomSetText32, SetText32
        SUB_ENTRY SubRomSetGraphic, SetGraphic
        SUB_ENTRY SubRomSetMulticolour, SetMulticolour
        SUB_ENTRY SubRomClearSprites, ClearSprites
        SUB_ENTRY SubRomSpritePattern, SpritePattern
        SUB_ENTRY SubRomSpriteAttribute, SpriteAttribute
        SUB_ENTRY SubRomSpriteSize, SpriteSize
        SUB_ENTRY SubRomGetPattern, GetPattern
        SUB_ENTRY SubRomWriteVram, WriteVram
        SUB_ENTRY SubRomReadVram, ReadVram
        SUB_ENTRY SubRomChangeColours, ChangeColours
        SUB_ENTRY SubRomCls, ClearScreen
        SUB_ENTRY SubRomClearText, ClearText
        SUB_ENTRY SubRomShowFunctionKeys, ShowFunctionKeys
        SUB_ENTRY SubRomDeleteLine, NotWritten
        SUB_ENTRY SubRomInsertLine, NotWritten
        SUB_ENTRY SubRomPutVram, NotWritten
        SUB_ENTRY SubRomWriteVdp, WriteVdpReg
        SUB_ENTRY SubRomVdpStatus, VdpStatus
        SUB_ENTRY SubRomKanaLock, NotWritten
        SUB_ENTRY SubRomPutChr, NotWritten
        SUB_ENTRY SubRomSetPage, SetPage
        SUB_ENTRY SubRomInitPalette, InitPalette
        SUB_ENTRY SubRomRestorePalette, RestorePalette
        SUB_ENTRY SubRomGetPalette, GetPalette
        SUB_ENTRY SubRomSetPalette, SetPalette
        SUB_ENTRY SubRomBasicPutSprite, BasicHandler
        SUB_ENTRY SubRomBasicColor, BasicHandler
        SUB_ENTRY SubRomBasicScreen, BasicHandler
        SUB_ENTRY SubRomBasicWidth, BasicHandler
        SUB_ENTRY SubRomBasicVdp, BasicHandler
        SUB_ENTRY SubRomBasicVdpFunction, BasicHandler
        SUB_ENTRY SubRomBasicBase, BasicHandler
        SUB_ENTRY SubRomBasicBaseFunction, BasicHandler
        SUB_ENTRY SubRomBasicVpoke, BasicHandler
        SUB_ENTRY SubRomBasicVpeek, BasicHandler
        SUB_ENTRY SubRomBasicSet, BasicHandler
        SUB_ENTRY SubRomBeep, Beep
        SUB_ENTRY SubRomPrompt, NotWritten
        SUB_ENTRY SubRomScreenFromClock, NotWritten
        SUB_ENTRY SubRomSetScreen, NotWritten
        SUB_ENTRY SubRomBasicCopy, BasicHandler
        SUB_ENTRY SubRomCopyVramVram, NotWritten
        SUB_ENTRY SubRomCopyRamVram, NotWritten
        SUB_ENTRY SubRomCopyVramRam, NotWritten
        SUB_ENTRY SubRomCopyDiskVram, NotWritten
        SUB_ENTRY SubRomCopyVramDisk, NotWritten
        SUB_ENTRY SubRomCopyDiskRam, NotWritten
        SUB_ENTRY SubRomCopyRamDisk, NotWritten
        SUB_ENTRY SubRomNewPad, NewPad
        SUB_ENTRY SubRomBasicGetPut, BasicHandler
        SUB_ENTRY SubRomChangeModePalette, ChangeModePalette
        SUB_ENTRY SubRomKanjiPrint, NotWritten
        SUB_ENTRY SubRomReadClock, ReadClock
        SUB_ENTRY SubRomWriteClock, WriteClock
EntriesEnd:

; --- FBASIC's services (common/fbasicsub.inc) ---
        org FrsxServices
        jp StatementPset
        jp StatementPreset
        jp StatementLineGraphic
        jp StatementCircle
        jp StatementPaint
        jp StatementPut
        jp StatementSprite
        jp StatementColorPalette
        jp OperandPoint
        jp StatementDraw
        jp PrintUsing
        jp StatementDelete
        jp StatementRenum
        jp StatementSet
        jp StatementCopy
        jp StatementOpen
        jp StatementClose
        jp StatementMaxfiles
        jp FileLayout
        jp CloseAllFiles
        jp FileForOutput
        jp FileOutputChar
        jp InputFile
        jp LineInputFile
        jp InputFileChars
        jp FuncEof
        assert $ == FrsxServicesEnd

        include "sub/main.asm"
        include "sub/screen.asm"
        include "sub/palette.asm"
        include "sub/clock.asm"
; FBASIC's own code that lives here, and what it needs of the main ROM
        include "basic/graphics.asm"
        include "basic/draw.asm"
        include "basic/using.asm"
        include "basic/edit.asm"
        include "basic/copy.asm"
        include "basic/files.asm"
        include "out/subwrappers.inc"
SubRomEnd:
        assert SubRomEnd <= $4000, "the sub-ROM is too big"

        savebin "out/sub_free.rom", $0000, $4000
