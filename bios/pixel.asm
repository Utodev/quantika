; pixel.asm: the main ROM's pixel primitives for machine code (RIGHTC ... SCANL): the sub-ROM's do the work
; (sub/pixel.asm, for every screen mode); FETCHC, STOREC and GTASPC are here.

        macro TO_SUB address
        push ix
        ld ix,address
        call CallSubRomDirect
        pop ix
        ret
        endm

PixelRight:     TO_SUB SubRomPixelRight         ; RIGHTC
PixelLeft:      TO_SUB SubRomPixelLeft          ; LEFTC
PixelUp:        TO_SUB SubRomPixelUp            ; UPC
PixelUpTest:    TO_SUB SubRomPixelUpTest        ; TUPC
PixelDown:      TO_SUB SubRomPixelDown          ; DOWNC
PixelDownTest:  TO_SUB SubRomPixelDownTest      ; TDOWNC
ClipXY:         TO_SUB SubRomClipXY             ; SCALXY
MapXY:          TO_SUB SubRomMapXY              ; MAPXY
SetPixelColour: TO_SUB SubRomSetAttribute       ; SETATR
ReadPixel:      TO_SUB SubRomReadPixel          ; READC
SetPixel:       TO_SUB SubRomSetPixel           ; SETC
SetPixelRun:    TO_SUB SubNsetcx                ; NSETCX
PaintInit:      TO_SUB SubPntini                ; PNTINI
PaintScanRight: TO_SUB SubRomScanRight          ; SCANR
PaintScanLeft:  TO_SUB SubRomScanLeft           ; SCANL

; FetchPixelAddr: FETCHC. A = CMASK, HL = CLOC.
FetchPixelAddr:
        ld a,(CMASK)
        ld hl,(CLOC)
        ret

; StorePixelAddr: STOREC. CMASK = A, CLOC = HL.
StorePixelAddr:
        ld (CMASK),a
        ld (CLOC),hl
        ret

; GetAspect: GTASPC. DE = ASPCT1, HL = ASPCT2.
GetAspect:
        ld de,(ASPCT1)
        ld hl,(ASPCT2)
        ret
