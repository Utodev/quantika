; hw.inc: I/O ports and hardware constants of the machine (the one emu80 emulates).
; All values are hexadecimal.

; --- Video display processor (V9938) ---
VdpData         equ $98         ; VRAM data (read / write)
VdpCommand      equ $99         ; write: register / address setup, read: status register
VdpPalette      equ $9A         ; palette data (two writes per colour)
VdpIndirect     equ $9B         ; indirect register write (register number in R#17)

; --- Programmable sound generator (AY-3-8910 compatible) ---
PsgAddress      equ $A0         ; register select
PsgWrite        equ $A1         ; register write
PsgRead         equ $A2         ; register read

; --- Parallel interface (8255) ---
PpiSlotSelect   equ $A8         ; port A: primary slot of each 16K page (2 bits per page)
PpiKeyRow       equ $A9         ; port B: keyboard matrix row (read, 0 = pressed)
PpiControl      equ $AA         ; port C: bits 0-3 keyboard row, 4 cassette motor (0 = on), 5 cassette out, 6 caps LED, 7 click
PpiMode         equ $AB         ; mode / bit set-reset register

PpiMotorBit     equ 4
PpiCasOutBit    equ 5
PpiCapsBit      equ 6
PpiClickBit     equ 7

; --- Real time clock (RP-5C01) ---
RtcIndex        equ $B4
RtcData         equ $B5

; --- Memory mapper (one 16K segment number per page) ---
MapperPage0     equ $FC
MapperPage1     equ $FD
MapperPage2     equ $FE
MapperPage3     equ $FF

; --- PSG register numbers ---
PsgMixer        equ $07         ; tone / noise enable, bits 6 and 7 drive the joystick port select / I/O direction
PsgPortA        equ $0E         ; joystick and cassette input (bit 7 = cassette in)
PsgPortB        equ $0F         ; joystick port select and trigger lines

; --- Secondary slot selection register (visible in page 3 of an expanded slot) ---
SecondarySlotReg equ $FFFF
PrinterStatus   equ $90                 ; printer: read bit 1 = busy; write bit 0 = strobe (0: on)
PrinterData     equ $91                 ; printer: the byte to print
