; main_free.asm: a free main ROM (BIOS + FBASIC), written from the published
; standard, compatible with the original at the documented interface
; Build with build.sh (sjasmplus). 32K: page 0 the BIOS, page 1 FBASIC.
;

        device NOSLOT64K
        org $0000                       ; unused ROM bytes read FFh
        ds $8000, $FF
        include "hw.inc"
        include "sysvars.inc"
        include "subrom.inc"
        include "mathpack.inc"
        include "tokens.inc"
        include "buildstamp.inc"        ; (written by build.sh: BUILD_STAMP)
        include "errors.inc"
        include "fbasicsub.inc"

        include "bios/jumptable.asm"
        include "bios/boot.asm"
        include "bios/core.asm"
        include "bios/slots.asm"
        include "bios/interrupt.asm"
        include "bios/vdp.asm"
        include "bios/psg.asm"
        include "bios/keyboard.asm"
        include "bios/joystick.asm"
        include "bios/screen.asm"
        include "bios/cassette.asm"
        include "bios/editor.asm"
        include "bios/stubs.asm"
FixedCodeEnd:
        assert FixedCodeEnd <= FontAddress, "the BIOS code runs into the font"

; The character set sits at 1BBFh as in every BIOS of the standard: CGTABL (0004h) points to it, but games
; read it there directly.
FontAddress     equ $1BBF
        org FontAddress
        include "data/font.asm"
        include "data/keymap.asm"
FontAndKeysEnd:
        assert FontAndKeysEnd <= DECSUB, "the font and the keys run into the Math-Pack"

; --- the Math-Pack at its fixed addresses, its code after it ---
        include "basic/mathpack.asm"
        include "basic/compat.asm"

; --- the modules that can go anywhere: tools/pack.py places them (layout_main.txt) ---
        include "out/layout_main.inc"

        savebin "out/main_free.rom", $0000, $8000
