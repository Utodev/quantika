; fbasicsub.inc: the services of FBASIC that live in the free sub-ROM (a JP each at a fixed address,
; called from the main ROM with EXTROM). The routines are the same source as if they were in the main
; ROM (basic/*.asm); tools/mksubwrappers.py makes the sub-ROM reach what they call in the main ROM.
FrsxServices    equ $0300
SubPset         equ FrsxServices + 0
SubPreset       equ FrsxServices + 3
SubLineGraphic  equ FrsxServices + 6
SubCircle       equ FrsxServices + 9
SubPaint        equ FrsxServices + 12
SubPut          equ FrsxServices + 15
SubSprite       equ FrsxServices + 18
SubColorPalette equ FrsxServices + 21
SubPoint        equ FrsxServices + 24
SubDraw         equ FrsxServices + 27
SubPrintUsing   equ FrsxServices + 30
SubDelete       equ FrsxServices + 33
SubRenum        equ FrsxServices + 36
SubSet          equ FrsxServices + 39
SubCopy         equ FrsxServices + 42
SubOpen         equ FrsxServices + 45
SubClose        equ FrsxServices + 48
SubMaxfiles     equ FrsxServices + 51
SubFileLayout   equ FrsxServices + 54
SubCloseAll     equ FrsxServices + 57
SubFileForOutput equ FrsxServices + 60
SubFileOutputChar equ FrsxServices + 63
SubInputFile    equ FrsxServices + 66
SubLineInputFile equ FrsxServices + 69
SubInputFileChars equ FrsxServices + 72
SubEof          equ FrsxServices + 75
SubNsetcx       equ FrsxServices + 78      ; (the main ROM's NSETCX and PNTINI: bios/pixel.asm)
SubPntini       equ FrsxServices + 81
SubGet          equ FrsxServices + 84
SubPromptText   equ FrsxServices + 87      ; (SET PROMPT's text at BUF, Z; NZ for "Ok")
SubSpriteFunction equ FrsxServices + 90
FrsxServicesEnd equ FrsxServices + 93

FileColumn      equ 6                   ; (a file control block's column, basic/files.asm)
