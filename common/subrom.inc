; subrom.inc: the entry points of the sub-ROM (called with EXTROM / SUBROM). Fixed by the
; standard; the free sub-ROM (sub_free.asm) puts its own routines behind them.
SubRomBasicPaint        equ $0069       ; BASIC statement handlers: HL = text pointer in and out
SubRomBasicPset         equ $006D
SubRomBasicAttrScan     equ $0071
SubRomBasicGline        equ $0075
SubRomBasicBoxFill      equ $0079
SubRomBasicLine         equ $007D
SubRomBasicBox          equ $0081
SubRomDrawLine          equ $0085       ; DOGRPH
SubRomGraphicPrint      equ $0089       ; GRPPRT
SubRomClipXY            equ $008D       ; SCALXY
SubRomMapXY             equ $0091       ; MAPXYC
SubRomReadPixel         equ $0095       ; READC
SubRomSetAttribute      equ $0099       ; SETATR
SubRomSetPixel          equ $009D       ; SETC
SubRomPixelRightTest    equ $00A1       ; TRIGHT
SubRomPixelRight        equ $00A5       ; RIGHTC
SubRomPixelLeftTest     equ $00A9       ; TLEFTC
SubRomPixelLeft         equ $00AD       ; LEFTC
SubRomPixelDownTest     equ $00B1       ; TDOWNC
SubRomPixelDown         equ $00B5       ; DOWNC
SubRomPixelUpTest       equ $00B9       ; TUPC
SubRomPixelUp           equ $00BD       ; UPC
SubRomScanRight         equ $00C1       ; SCANR
SubRomScanLeft          equ $00C5       ; SCANL
SubRomBox               equ $00C9       ; NVBXLN
SubRomBoxFill           equ $00CD       ; NVBXFL
SubRomChangeMode        equ $00D1       ; CHGMOD
SubRomInitText          equ $00D5       ; INITXT
SubRomInitText32        equ $00D9       ; INIT32
SubRomInitGraphic       equ $00DD       ; INIGRP
SubRomInitMulticolour   equ $00E1       ; INIMLT
SubRomSetText           equ $00E5       ; SETTXT
SubRomSetText32         equ $00E9       ; SETT32
SubRomSetGraphic        equ $00ED       ; SETGRP
SubRomSetMulticolour    equ $00F1       ; SETMLT
SubRomClearSprites      equ $00F5       ; CLRSPR
SubRomSpritePattern     equ $00F9       ; CALPAT
SubRomSpriteAttribute   equ $00FD       ; CALATR
SubRomSpriteSize        equ $0101       ; GSPSIZ
SubRomGetPattern        equ $0105       ; GETPAT
SubRomWriteVram         equ $0109       ; WRTVRM
SubRomReadVram          equ $010D       ; RDVRM
SubRomChangeColours     equ $0111       ; CHGCLR
SubRomCls               equ $0115       ; CLS
SubRomClearText         equ $0119       ; CLRTXT
SubRomShowFunctionKeys  equ $011D       ; DSPFNK
SubRomDeleteLine        equ $0121       ; DELLNO
SubRomInsertLine        equ $0125       ; INSLNO
SubRomPutVram           equ $0129       ; PUTVRM
SubRomWriteVdp          equ $012D       ; WRTVDP
SubRomVdpStatus         equ $0131       ; VDPSTA
SubRomKanaLock          equ $0135       ; KYKLOK
SubRomPutChr            equ $0139       ; PUTCHR
SubRomSetPage           equ $013D       ; SETPAG
SubRomInitPalette       equ $0141       ; INIPLT
SubRomRestorePalette    equ $0145       ; RSTPLT
SubRomGetPalette        equ $0149       ; GETPLT
SubRomSetPalette        equ $014D       ; SETPLT
SubRomBasicPutSprite    equ $0151
SubRomBasicColor        equ $0155
SubRomBasicScreen       equ $0159
SubRomBasicWidth        equ $015D
SubRomBasicVdp          equ $0161
SubRomBasicVdpFunction  equ $0165
SubRomBasicBase         equ $0169
SubRomBasicBaseFunction equ $016D
SubRomBasicVpoke        equ $0171
SubRomBasicVpeek        equ $0175
SubRomBasicSet          equ $0179
SubRomBeep              equ $017D       ; BEEP
SubRomPrompt            equ $0181       ; PROMPT
SubRomScreenFromClock   equ $0185       ; SDFSCR
SubRomSetScreen         equ $0189       ; SETSCR
SubRomBasicCopy         equ $018D
SubRomCopyVramVram      equ $0191       ; BLTVV
SubRomCopyRamVram       equ $0195       ; BLTVM
SubRomCopyVramRam       equ $0199       ; BLTMV
SubRomCopyDiskVram      equ $019D       ; BLTVD
SubRomCopyVramDisk      equ $01A1       ; BLTDV
SubRomCopyDiskRam       equ $01A5       ; BLTMD
SubRomCopyRamDisk       equ $01A9       ; BLTDM
SubRomNewPad            equ $01AD       ; NEWPAD
SubRomBasicGetPut       equ $01B1
SubRomChangeModePalette equ $01B5       ; CHGMDP
SubRomKanjiPrint        equ $01BD       ; KNJPRT
SubRomReadClock         equ $01F5       ; REDCLK
SubRomWriteClock        equ $01F9       ; WRTCLK
