; jumptable.asm: the BIOS entry points at fixed addresses (0000h-0179h).
; The addresses are the standard's interface: every program and ROM calls them by number.
; What sits behind each JP is free BIOS code, anywhere in the ROM.

        org $0000
Rst00_Boot:                     ; RST 00h / CHKRAM: power on
        di
        jp ColdStart
CharSetAddress:                 ; CGTABL: address of the character set in this ROM
        dw FontData
VdpReadPort:                    ; VDP.DR: the port to read the VDP from
        db VdpData
VdpWritePort:                   ; VDP.DW: the port to write the VDP to
        db VdpData

        org $0008
Rst08_SyntaxCheck:              ; SYNCHR: check the character after the RST is the one at (HL)
        jp SyntaxCheck
        org $000C
Bios_RDSLT:     jp ReadSlot             ; read a byte from any slot
        org $0010
Rst10_NextChar:                 ; CHRGTR: next character of the BASIC text
        jp NextChar
        org $0014
Bios_WRSLT:     jp WriteSlot            ; write a byte to any slot
        org $0018
Rst18_Output:                   ; OUTDO: output a character to the current device
        jp OutputChar
        org $001C
Bios_CALSLT:    jp CallSlot             ; inter-slot call
        org $0020
Rst20_CompareHLDE:              ; DCOMPR: compare HL with DE
        jp CompareHLDE
        org $0024
Bios_ENASLT:    jp EnableSlot           ; switch a page to a slot
        org $0028
Rst28_GetType:                  ; GETYPR: type of the value in DAC
        jp GetValueType
        org $002B
IdByte1:        db $A1                  ; bit 7: 50 Hz; bits 6-4: date as day-month-year; bits 3-0: international characters
IdByte2:        db $01                  ; international keyboard
MachineVersion: db $01                  ; 01h: the standard's second version
MidiFlags:      db $00
        org $0030
Rst30_FarCall:                  ; CALLF: inter-slot call with the slot and address inline
        jp FarCall
        org $0038
Rst38_Interrupt:                ; KEYINT: the maskable interrupt
        jp InterruptHandler
Bios_INITIO:    jp InitIO               ; 003B  initialise the PSG and the parallel port
Bios_INIFNK:    jp InitFunctionKeys     ; 003E
Bios_DISSCR:    jp DisableScreen        ; 0041
Bios_ENASCR:    jp EnableScreen         ; 0044
Bios_WRTVDP:    jp WriteVdpReg          ; 0047
Bios_RDVRM:     jp ReadVram             ; 004A
Bios_WRTVRM:    jp WriteVram            ; 004D
Bios_SETRD:     jp SetVramRead          ; 0050
Bios_SETWRT:    jp SetVramWrite         ; 0053
Bios_FILVRM:    jp FillVram             ; 0056
Bios_LDIRMV:    jp CopyVramToRam        ; 0059
Bios_LDIRVM:    jp CopyRamToVram        ; 005C
Bios_CHGMOD:    jp ChangeScreenMode     ; 005F
Bios_CHGCLR:    jp ChangeColours        ; 0062
        db 0
        org $0066
Bios_NMI:       jp NmiHandler           ; 0066
Bios_CLRSPR:    jp ClearSprites         ; 0069
Bios_INITXT:    jp InitText40           ; 006C
Bios_INIT32:    jp InitText32           ; 006F
Bios_INIGRP:    jp InitGraphic          ; 0072
Bios_INIMLT:    jp InitMulticolour      ; 0075
Bios_SETTXT:    jp SetText40            ; 0078
Bios_SETT32:    jp SetText32            ; 007B
Bios_SETGRP:    jp SetGraphic           ; 007E
Bios_SETMLT:    jp SetMulticolour       ; 0081
Bios_CALPAT:    jp SpritePatternAddr    ; 0084
Bios_CALATR:    jp SpriteAttributeAddr  ; 0087
Bios_GSPSIZ:    jp SpriteSize           ; 008A
Bios_GRPPRT:    jp GraphicPrintChar     ; 008D
Bios_GICINI:    jp InitPsg              ; 0090
Bios_WRTPSG:    jp WritePsg             ; 0093
Bios_RDPSG:     jp ReadPsg              ; 0096
Bios_STRTMS:    jp StartMusic           ; 0099
Bios_CHSNS:     jp KeyAvailable         ; 009C
Bios_CHGET:     jp GetKey               ; 009F
Bios_CHPUT:     jp PutChar              ; 00A2
Bios_LPTOUT:    jp PrinterOut           ; 00A5
Bios_LPTSTT:    jp PrinterStatusTest    ; 00A8
Bios_CNVCHR:    jp ConvertGraphicChar   ; 00AB
Bios_PINLIN:    jp InputLine            ; 00AE
Bios_INLIN:     jp InputLineAtCursor    ; 00B1
Bios_QINLIN:    jp InputLineQuestion    ; 00B4
Bios_BREAKX:    jp CheckCtrlStop        ; 00B7
Bios_ISCNTC:    jp CheckStopBasic       ; 00BA
Bios_CKCNTC:    jp CheckStopBasic2      ; 00BD
Bios_BEEP:      jp Beep                 ; 00C0
Bios_CLS:       jp ClearScreen          ; 00C3
Bios_POSIT:     jp SetCursor            ; 00C6
Bios_FNKSB:     jp FunctionKeysIfOn     ; 00C9
Bios_ERAFNK:    jp HideFunctionKeys     ; 00CC
Bios_DSPFNK:    jp ShowFunctionKeys     ; 00CF
Bios_TOTEXT:    jp ForceTextMode        ; 00D2
Bios_GTSTCK:    jp GetStick             ; 00D5
Bios_GTTRIG:    jp GetTrigger           ; 00D8
Bios_GTPAD:     jp GetPad               ; 00DB
Bios_GTPDL:     jp GetPaddle            ; 00DE
Bios_TAPION:    jp TapeInStart          ; 00E1
Bios_TAPIN:     jp TapeInByte           ; 00E4
Bios_TAPIOF:    jp TapeInStop           ; 00E7
Bios_TAPOON:    jp TapeOutStart         ; 00EA
Bios_TAPOUT:    jp TapeOutByte          ; 00ED
Bios_TAPOOF:    jp TapeOutStop          ; 00F0
Bios_STMOTR:    jp SetTapeMotor         ; 00F3
Bios_LFTQ:      jp QueueFree            ; 00F6
Bios_PUTQ:      jp QueuePut             ; 00F9
Bios_RIGHTC:    jp PixelRight           ; 00FC
Bios_LEFTC:     jp PixelLeft            ; 00FF
Bios_UPC:       jp PixelUp              ; 0102
Bios_TUPC:      jp PixelUpTest          ; 0105
Bios_DOWNC:     jp PixelDown            ; 0108
Bios_TDOWNC:    jp PixelDownTest        ; 010B
Bios_SCALXY:    jp ClipXY               ; 010E
Bios_MAPXY:     jp MapXY                ; 0111
Bios_FETCHC:    jp FetchPixelAddr       ; 0114
Bios_STOREC:    jp StorePixelAddr       ; 0117
Bios_SETATR:    jp SetPixelColour       ; 011A
Bios_READC:     jp ReadPixel            ; 011D
Bios_SETC:      jp SetPixel             ; 0120
Bios_NSETCX:    jp SetPixelRun          ; 0123
Bios_GTASPC:    jp GetAspect            ; 0126
Bios_PNTINI:    jp PaintInit            ; 0129
Bios_SCANR:     jp PaintScanRight       ; 012C
Bios_SCANL:     jp PaintScanLeft        ; 012F
Bios_CHGCAP:    jp SetCapsLed           ; 0132
Bios_CHGSND:    jp SetOneBitSound       ; 0135
Bios_RSLREG:    jp ReadPrimarySlots     ; 0138
Bios_WSLREG:    jp WritePrimarySlots    ; 013B
Bios_RDVDP:     jp ReadVdpStatus        ; 013E
Bios_SNSMAT:    jp ReadKeyRow           ; 0141
Bios_PHYDIO:    jp PhysicalDiskIO       ; 0144
Bios_FORMAT:    jp FormatDisk           ; 0147
Bios_ISFLIO:    jp IsFileIO             ; 014A
Bios_OUTDLP:    jp PrinterOutFormatted  ; 014D
Bios_GETVCP:    jp VoiceBufferAddr      ; 0150
Bios_GETVC2:    jp VoiceBufferAddr2     ; 0153
Bios_KILBUF:    jp ClearKeyBuffer       ; 0156
Bios_CALBAS:    jp CallBasic            ; 0159
; --- the second version's additions ---
Bios_SUBROM:    jp CallSubRom           ; 015C  call the sub-ROM (address in IX, registers pushed by the caller)
Bios_EXTROM:    jp CallSubRomDirect     ; 015F  call the sub-ROM (address in IX)
Bios_CHKSLZ:    jp FindSlots            ; 0162
Bios_CHKNEW:    jp IsNewScreenMode      ; 0165
Bios_EOL:       jp EraseToEndOfLine     ; 0168
Bios_BIGFIL:    jp FillVramBig          ; 016B
Bios_NSETRD:    jp SetVramReadBig       ; 016E
Bios_NSTWRT:    jp SetVramWriteBig      ; 0171
Bios_NRDVRM:    jp ReadVramBig          ; 0174
Bios_NWRVRM:    jp WriteVramBig         ; 0177
JumpTableEnd:
