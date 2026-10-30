; common.inc: BIOS entries and variables for the test programs (they run at C000h, see the test harness's exec)
CHPUT   equ $00A2
CHGMOD  equ $005F
INITXT  equ $006C
INIT32  equ $006F
ERAFNK  equ $00CC
DSPFNK  equ $00CF
POSIT   equ $00C6
CLS     equ $00C3
LINL40  equ $F3AE
LINL32  equ $F3AF
CSRSW   equ $FCA9
CSRX    equ $F3DD
CSRY    equ $F3DC
Results equ $D000

        macro TEST_START
        device NOSLOT64K
        org $C000
Start:
        di
        ld sp,$F000
        ei
        call ERAFNK                     ; a clean 40-column screen: the BIOSes' banners differ
        xor a
        ld (CSRSW),a
        ld a,40
        ld (LINL40),a
        call INITXT
        endm

        macro TEST_END name
TestEnd:
        jr TestEnd
Print:
        ld a,(hl)
        inc hl
        or a
        ret z
        call CHPUT
        jr Print
        savebin name, Start, $ - Start
        endm
