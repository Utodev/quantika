; stubs.asm: entry points that are not written yet (stage 0). Each one returns at once with carry
; clear and A = 0; they are replaced by real code stage by stage (see emu80's notes on the free ROMs).

StartMusic:
PrinterOut:
PrinterStatus:
CheckStopBasic:
CheckStopBasic2:
QueueFree:
QueuePut:
PixelRight:
PixelLeft:
PixelUp:
PixelUpTest:
PixelDown:
PixelDownTest:
ClipXY:
MapXY:
FetchPixelAddr:
StorePixelAddr:
SetPixelColour:
ReadPixel:
SetPixel:
SetPixelRun:
GetAspect:
PaintInit:
PaintScanRight:
PaintScanLeft:
PhysicalDiskIO:
FormatDisk:
IsFileIO:
PrinterOutFormatted:
VoiceBufferAddr:
VoiceBufferAddr2:
        xor a
        ret
