; core.asm: small helpers of the jump table that need no hardware.

; CompareHLDE: DCOMPR. Flags as for HL - DE (Z equal, C when HL < DE). Destroys A.
CompareHLDE:
        ld a,h
        cp d
        ret nz
        ld a,l
        cp e
        ret

; ReadPrimarySlots: RSLREG. A = the primary slot register.
ReadPrimarySlots:
        in a,(PpiSlotSelect)
        ret

; WritePrimarySlots: WSLREG. Set the primary slot register from A.
WritePrimarySlots:
        out (PpiSlotSelect),a
        ret

; GetValueType: GETYPR (RST 28h). The type of the value in DAC from VALTYP:
; integer M + NZ + C, string Z + C, single P + NZ + C, double P + NZ + NC. Destroys A.
GetValueType:
        ld a,(VALTYP)
        cp $08
        jr nc,.double
        sub $03
        or a
        scf
        ret
.double:
        sub $03
        or a
        ret

; InitIO: INITIO. The sound chip and the printer port.
InitIO:
        jp InitPsg
