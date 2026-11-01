; boot.asm: power on. Find RAM for page 3 (with no stack, since there is no RAM yet) and page 2,
; learn which slots are expanded, fill the work area, set up the chips, find the sub-ROM and start
; the ROMs in the slots. If none takes the machine, the banner (FBASIC comes in stage 5).

BootStack       equ $F1C9               ; the stack grows down from under the disk ROM's work area (F1C9h-F37Fh,
                                        ; which its INIT fills while the cartridges are scanned); a disk ROM leaves
                                        ; 128 bytes under it for this stack. (Lower, D000h, broke a game whose
                                        ; INIT keeps this stack: Donkey Kong.)
RamTestAddr     equ $E000               ; the byte of page 3 tried for RAM
ScanHeader      equ BUF                 ; boot only: the 16 bytes of the ROM header being looked at
ScanSlot        equ BUF + $10           ; boot only: its slot
ScanPage        equ BUF + $11           ; boot only: its page (1 or 2)

ColdStart:
        di
        im 1
        ld a,$82                        ; 8255: port A out (slots), B in (keyboard), C out
        out (PpiMode),a
        ld a,$50                        ; cassette motor off, caps lamp off, keyboard row 0
        out (PpiControl),a
        ld a,$03                        ; memory mapper: segments 3, 2, 1, 0 for pages 0 to 3
        out (MapperPage0),a
        dec a
        out (MapperPage1),a
        dec a
        out (MapperPage2),a
        dec a
        out (MapperPage3),a

; --- RAM for page 3, slot by slot, primary 0 to 3 and their subslots. No stack yet. ---
; B = primary, C = subslot register value tried (0, 55h, AAh, FFh), D = 80h when expanded.
        ld b,$00
.tryPrimary:
        ld a,b
        rrca
        rrca                            ; page 3 on primary B, pages 0-2 on slot 0 (this ROM)
        out (PpiSlotSelect),a
        ld hl,SLTSL
        ld (hl),$0F                     ; an expanded slot reads its register back complemented
        ld a,(hl)
        cp $F0
        ld c,$00
        ld d,$00
        jr nz,.tryRam
        ld d,$80
.trySubslot:
        ld (hl),c
.tryRam:
        ld a,$A5
        ld (RamTestAddr),a
        ld a,(RamTestAddr)
        cp $A5
        jr nz,.notRam
        ld a,$5A
        ld (RamTestAddr),a
        ld a,(RamTestAddr)
        cp $5A
        jr z,.foundRam
.notRam:
        bit 7,d
        jr z,.nextPrimary
        ld a,c
        add a,$55
        ld c,a
        jr nc,.trySubslot               ; FFh + 55h carries: the four subslots are done
.nextPrimary:
        inc b
        bit 2,b
        jr z,.tryPrimary
.noRam:                                 ; no RAM at all: nothing can run
        halt
        jr .noRam

.foundRam:
        ; E = slot ID of the RAM in page 3: primary B, subslot from C, D = 80h when expanded
        ld a,c
        and $0C
        or b
        or d
        ld e,a
        ld sp,BootStack
        ; the work area (F380h-FFFEh: FFFFh may be the secondary slot register)
        ld hl,RDPRIM
        ld (hl),$00
        push de
        ld de,RDPRIM + 1
        ld bc,SLTSL - RDPRIM - 1
        ldir
        pop de

; --- Which primary slots are expanded: EXPTBL. Their registers go to 0 (all pages on subslot 0),
;     except the RAM's, which keeps the subslot found. Again no stack while page 3 is elsewhere. ---
        ld b,$00
.testExpanded:
        ld a,b
        rrca
        rrca
        ld h,a
        in a,(PpiSlotSelect)
        ld l,a                          ; L = A8 to come back to
        and $3F
        or h
        out (PpiSlotSelect),a           ; no stack from here...
        ld a,$0F
        ld (SLTSL),a
        ld a,(SLTSL)
        cp $F0
        ld h,$00
        jr nz,.notExpanded
        ld h,$80
        ld a,e
        and $03
        cp b
        ld a,$00
        jr nz,.setRegister
        ld a,c                          ; the RAM's own primary slot: its subslot stays
.setRegister:
        ld (SLTSL),a
.notExpanded:
        ld a,l
        out (PpiSlotSelect),a           ; ...to here
        ld a,b
        add a,low EXPTBL
        ld l,a
        ld a,h
        ld h,high EXPTBL
        ld (hl),a
        inc b
        bit 2,b
        jr z,.testExpanded
        ld a,e                          ; SLTTBL of the RAM's slot
        and $03
        add a,low SLTTBL
        ld l,a
        ld h,high SLTTBL
        ld (hl),c
        ld a,(EXPTBL)                   ; this ROM is in slot 0 (subslot 0 if expanded)
        ld (MINROM),a

        call InitWorkArea
        ld a,e
        call FindRamPage2
        call InitVdp
        call InitPsg
        call InitText40
        call FindSlots
        ei
        call ScanCartridges
        call InitFunctionKeys
        ld ix,SubRomScreenFromClock     ; SDFSCR: the settings of SET SCREEN, ADJUST... (the clock's memory)
        call CallSubRomDirect
        ld ix,SubRomPrompt              ; PROMPT: the password of SET PASSWORD, if there is one
        call CallSubRomDirect
        call H_STKE                     ; a ROM that wants to run once BASIC is ready hooks this
        jp BasicColdStart

; InitWorkArea: the hooks (RET), the RAM primitives and the variables that have a value at power on.
; Destroys AF, BC, HL. Preserves DE.
InitWorkArea:
        push de
        ld hl,H_KEYI
        ld (hl),$C9
        ld de,H_KEYI + 1
        ld bc,RetFilledEnd - H_KEYI - 1
        ldir
        ld hl,RamPrimitives
        ld de,RDPRIM
        ld bc,RamPrimitivesSize
        ldir
        ld hl,WorkAreaDefaults
.nextBlock:
        ld e,(hl)                       ; blocks: DW address, DB length, the bytes; DW 0 ends
        inc hl
        ld d,(hl)
        inc hl
        ld a,d
        or e
        jr z,.done
        ld c,(hl)
        ld b,$00
        inc hl
        ldir
        jr .nextBlock
.done:
        ld hl,KEYBUF                    ; the key buffer is empty
        ld (PUTPNT),hl
        ld (GETPNT),hl
        pop de
        ret

; FindRamPage2: page 2 on RAM: the slot of page 3's RAM first, then every slot in order.
; In: A = slot ID of page 3's RAM. Sets BOTTOM. Destroys all.
FindRamPage2:
        call .tryOne
        ret z
        xor a
        call FirstSlotOfPrimary
.nextSlot:
        push af
        call .tryOne
        pop bc                          ; (B = the slot ID tried, flags of the test kept)
        ret z
        ld a,b
        call NextSlotId
        jr nc,.nextSlot
        ret                             ; no RAM in page 2: BASIC will have none
.tryOne:
        push af
        ld hl,$8000
        call EnableSlot
        pop af
        ld hl,$BF00
        ld b,(hl)
        ld a,b
        cpl
        ld (hl),a
        cp (hl)
        ld (hl),b
        ret nz
        ld hl,$8000
        ld (BOTTOM),hl
        ret

; InitVdp: the V9938 registers that the screen modes do not set: 128K VRAM type, PAL, 192 lines.
InitVdp:
        ld bc,$0808                     ; R#8: VRAM is 64K chips, sprites on
        call WriteVdpReg
        ld bc,$0209                     ; R#9: PAL (50 Hz), 192 lines
        call WriteVdpReg
        ld bc,$000E                     ; R#14: VRAM bank 0
        call WriteVdpReg
        ld bc,$3B15                     ; R#21 and R#22: the V9938's own values
        call WriteVdpReg
        ld bc,$0516
        call WriteVdpReg
        ld a,$04                        ; 128K of VRAM
        ld (MODE),a
        jp SetDefaultPalette

; FindSlots: CHKSLZ. Look for the sub-ROM (a "CD" header at 0000h of some slot) and keep its slot in
; EXBRSA and in this ROM's own copy SUBSLT (0 when there is none). Destroys all.
FindSlots:
        xor a
        ld (EXBRSA),a
        ld (SUBSLT),a
        call FirstSlotOfPrimary
.nextSlot:
        push af
        ld hl,$0000
        call ReadSlot
        cp 'C'
        jr nz,.notThis
        pop af
        push af
        ld hl,$0001
        call ReadSlot
        cp 'D'
        jr nz,.notThis
        pop af
        ld (EXBRSA),a
        ld (SUBSLT),a
        ei
        ret
.notThis:
        pop af
        call NextSlotId
        jr nc,.nextSlot
        ei
        ret

; ScanCartridges: every slot, pages 1 and 2: a ROM with the "AB" header gets its attributes in SLTATR
; and its INIT called (a game's INIT usually never comes back).
ScanCartridges:
        xor a
        call FirstSlotOfPrimary
.nextSlot:
        push af
        ld h,$40
        call CheckRomHeader
        pop af
        push af
        ld h,$80
        call CheckRomHeader
        pop af
        call NextSlotId
        jr nc,.nextSlot
        ret

; CheckRomHeader: In: A = slot ID, H = 40h or 80h. Destroys all.
CheckRomHeader:
        ld (ScanSlot),a
        ld a,h
        rlca
        rlca
        and $03
        ld (ScanPage),a
        ld l,$00
        ld de,ScanHeader
        ld b,$10
.copy:
        push bc
        push de
        ld a,(ScanSlot)
        call ReadSlot
        pop de
        ld (de),a
        inc de
        inc hl
        pop bc
        djnz .copy
        ei
        ld hl,(ScanHeader)
        ld de,'A' + 'B' * $100
        or a
        sbc hl,de
        ret nz
        ; SLTATR + primary * 16 + subslot * 4 + page: bit 5 CALL statements, 6 a device, 7 BASIC text
        ld a,(ScanSlot)
        ld b,a
        and $03
        rlca
        rlca
        rlca
        rlca
        ld c,a
        ld a,b
        and $0C
        or c
        ld c,a
        ld a,(ScanPage)
        or c
        add a,low SLTATR
        ld l,a
        ld a,high SLTATR
        adc a,$00
        ld h,a
        ld c,$00
        ld de,(ScanHeader + 4)          ; STATEMENT
        ld a,d
        or e
        jr z,.noStatement
        set 5,c
.noStatement:
        ld de,(ScanHeader + 6)          ; DEVICE
        ld a,d
        or e
        jr z,.noDevice
        set 6,c
.noDevice:
        ld de,(ScanHeader + 8)          ; TEXT
        ld a,d
        or e
        jr z,.noText
        set 7,c
.noText:
        ld (hl),c
        ld hl,(ScanHeader + 2)          ; INIT
        ld a,h
        or l
        ret z
        push hl
        pop ix
        ld a,(ScanSlot)
        push af
        pop iy                          ; IYh = slot
        call CallSlot
        ei
        ret

; Values of the work area at power on: DW address, DB length, bytes; DW 0 ends.
WorkAreaDefaults:
        dw LINL40 : db 3 : db 37, 29, 37             ; LINL40, LINL32, LINLEN (WIDTH 37, as the original BASIC starts)
        dw CRTCNT : db 2 : db 24, 14                 ; CRTCNT, CLMLST
        dw TXTNAM : db 10 : dw $0000, $0800, $0800, $0000, $0000        ; SCREEN 0 tables
        dw T32NAM : db 10 : dw $1800, $2000, $0000, $1B00, $3800        ; SCREEN 1
        dw GRPNAM : db 10 : dw $1800, $2000, $0000, $1B00, $3800        ; SCREEN 2
        dw MLTNAM : db 10 : dw $0800, $0000, $0000, $1B00, $3800        ; SCREEN 3
        dw CGPNT : db 11 : db $00 : dw FontData                         ; the character set: slot, address
        dw $0000, $0800, $3800, $1B00                                   ; NAMBAS, CGPBAS, PATBAS, ATRBAS
        dw CLIKSW : db 3 : db 1, 1, 1                ; key click on, cursor at row 1, column 1
        dw RG0SAV : db 8 : db $00, $60, $00, $00, $01, $00, $00, $F1
        dw FORCLR : db 3 : db 15, 4, 4               ; white on dark blue, as the original
        dw HIMEM : db 2 : dw $F380                    ; (a disk ROM lowers it)
        dw MAXFIL : db 1 : db 1
        dw CS120 : db 15 : db 82, 75, 40, 37, $0F           ; cassette: 1200 baud (bios/cassette.asm)
        db 40, 33, 20, 15, $1F                              ; 2400 baud
        db 82, 75, 40, 37, $0F                              ; LOW, HIGH, HEADER: 1200 baud
        dw 0
