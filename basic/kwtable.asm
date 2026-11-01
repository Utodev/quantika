; kwtable.asm: the keyword table where the standard has it, in its documented format, for the programs
; that read it (Abracadabra's adventure system lists its tokenized text with it). 3A3Eh: for each
; letter A-Z the address of its block; 3A72h: the blocks, each keyword without its first letter, the
; last character with bit 7 set, then its token (functions: the byte after FFh); a 0 ends a block;
; 3D26h: the ten one-character keywords (bit 7 set, as a last letter) and their tokens, 0 at the end. FBASIC's tokenizer
; uses the keyword blocks too (basic/crunch.asm).
StdKeywordIndex    equ $3A3E
        org StdKeywordIndex
        dw StdKeywordsA
        dw StdKeywordsB
        dw StdKeywordsC
        dw StdKeywordsD
        dw StdKeywordsE
        dw StdKeywordsF
        dw StdKeywordsG
        dw StdKeywordsH
        dw StdKeywordsI
        dw StdKeywordsJ
        dw StdKeywordsK
        dw StdKeywordsL
        dw StdKeywordsM
        dw StdKeywordsN
        dw StdKeywordsO
        dw StdKeywordsP
        dw StdKeywordsQ
        dw StdKeywordsR
        dw StdKeywordsS
        dw StdKeywordsT
        dw StdKeywordsU
        dw StdKeywordsV
        dw StdKeywordsW
        dw StdKeywordsX
        dw StdKeywordsY
        dw StdKeywordsZ
        org $3A72
StdKeywordsA:
        db "UT", 'O' | $80, $A9 ; AUTO
        db "N", 'D' | $80, $F6 ; AND
        db "B", 'S' | $80, $06 ; ABS
        db "T", 'N' | $80, $0E ; ATN
        db "S", 'C' | $80, $15 ; ASC
        db "TTR", '$' | $80, $E9 ; ATTR$
        db 0
StdKeywordsB:
        db "AS", 'E' | $80, $C9 ; BASE
        db "SAV", 'E' | $80, $D0 ; BSAVE
        db "LOA", 'D' | $80, $CF ; BLOAD
        db "EE", 'P' | $80, $C0 ; BEEP
        db "IN", '$' | $80, $1D ; BIN$
        db 0
StdKeywordsC:
        db "AL", 'L' | $80, $CA ; CALL
        db "LOS", 'E' | $80, $B4 ; CLOSE
        db "OP", 'Y' | $80, $D6 ; COPY
        db "ON", 'T' | $80, $99 ; CONT
        db "LEA", 'R' | $80, $92 ; CLEAR
        db "LOA", 'D' | $80, $9B ; CLOAD
        db "SAV", 'E' | $80, $9A ; CSAVE
        db "SRLI", 'N' | $80, $E8 ; CSRLIN
        db "IN", 'T' | $80, $1E ; CINT
        db "SN", 'G' | $80, $1F ; CSNG
        db "DB", 'L' | $80, $20 ; CDBL
        db "V", 'I' | $80, $28 ; CVI
        db "V", 'S' | $80, $29 ; CVS
        db "V", 'D' | $80, $2A ; CVD
        db "O", 'S' | $80, $0C ; COS
        db "HR", '$' | $80, $16 ; CHR$
        db "IRCL", 'E' | $80, $BC ; CIRCLE
        db "OLO", 'R' | $80, $BD ; COLOR
        db "L", 'S' | $80, $9F ; CLS
        db "M", 'D' | $80, $D7 ; CMD
        db 0
StdKeywordsD:
        db "ELET", 'E' | $80, $A8 ; DELETE
        db "AT", 'A' | $80, $84 ; DATA
        db "I", 'M' | $80, $86 ; DIM
        db "EFST", 'R' | $80, $AB ; DEFSTR
        db "EFIN", 'T' | $80, $AC ; DEFINT
        db "EFSN", 'G' | $80, $AD ; DEFSNG
        db "EFDB", 'L' | $80, $AE ; DEFDBL
        db "SKO", '$' | $80, $D1 ; DSKO$
        db "E", 'F' | $80, $97 ; DEF
        db "SKI", '$' | $80, $EA ; DSKI$
        db "SK", 'F' | $80, $26 ; DSKF
        db "RA", 'W' | $80, $BE ; DRAW
        db 0
StdKeywordsE:
        db "LS", 'E' | $80, $A1 ; ELSE
        db "N", 'D' | $80, $81 ; END
        db "RAS", 'E' | $80, $A5 ; ERASE
        db "RRO", 'R' | $80, $A6 ; ERROR
        db "R", 'L' | $80, $E1 ; ERL
        db "R", 'R' | $80, $E2 ; ERR
        db "X", 'P' | $80, $0B ; EXP
        db "O", 'F' | $80, $2B ; EOF
        db "Q", 'V' | $80, $F9 ; EQV
        db 0
StdKeywordsF:
        db "O", 'R' | $80, $82 ; FOR
        db "IEL", 'D' | $80, $B1 ; FIELD
        db "ILE", 'S' | $80, $B7 ; FILES
        db 'N' | $80, $DE ; FN
        db "R", 'E' | $80, $0F ; FRE
        db "I", 'X' | $80, $21 ; FIX
        db "PO", 'S' | $80, $27 ; FPOS
        db 0
StdKeywordsG:
        db "OT", 'O' | $80, $89 ; GOTO
        db "O T", 'O' | $80, $89 ; GO TO
        db "OSU", 'B' | $80, $8D ; GOSUB
        db "E", 'T' | $80, $B2 ; GET
        db 0
StdKeywordsH:
        db "EX", '$' | $80, $1B ; HEX$
        db 0
StdKeywordsI:
        db "NPU", 'T' | $80, $85 ; INPUT
        db 'F' | $80, $8B ; IF
        db "NST", 'R' | $80, $E5 ; INSTR
        db "N", 'T' | $80, $05 ; INT
        db "N", 'P' | $80, $10 ; INP
        db "M", 'P' | $80, $FA ; IMP
        db "NKEY", '$' | $80, $EC ; INKEY$
        db "P", 'L' | $80, $D5 ; IPL
        db 0
StdKeywordsJ:
        db 0
StdKeywordsK:
        db "IL", 'L' | $80, $D4 ; KILL
        db "E", 'Y' | $80, $CC ; KEY
        db 0
StdKeywordsL:
        db "PRIN", 'T' | $80, $9D ; LPRINT
        db "LIS", 'T' | $80, $9E ; LLIST
        db "PO", 'S' | $80, $1C ; LPOS
        db "E", 'T' | $80, $88 ; LET
        db "OCAT", 'E' | $80, $D8 ; LOCATE
        db "IN", 'E' | $80, $AF ; LINE
        db "OA", 'D' | $80, $B5 ; LOAD
        db "SE", 'T' | $80, $B8 ; LSET
        db "IS", 'T' | $80, $93 ; LIST
        db "FILE", 'S' | $80, $BB ; LFILES
        db "O", 'G' | $80, $0A ; LOG
        db "O", 'C' | $80, $2C ; LOC
        db "E", 'N' | $80, $12 ; LEN
        db "EFT", '$' | $80, $01 ; LEFT$
        db "O", 'F' | $80, $2D ; LOF
        db 0
StdKeywordsM:
        db "OTO", 'R' | $80, $CE ; MOTOR
        db "ERG", 'E' | $80, $B6 ; MERGE
        db "O", 'D' | $80, $FB ; MOD
        db "KI", '$' | $80, $2E ; MKI$
        db "KS", '$' | $80, $2F ; MKS$
        db "KD", '$' | $80, $30 ; MKD$
        db "ID", '$' | $80, $03 ; MID$
        db "A", 'X' | $80, $CD ; MAX
        db 0
StdKeywordsN:
        db "EX", 'T' | $80, $83 ; NEXT
        db "AM", 'E' | $80, $D3 ; NAME
        db "E", 'W' | $80, $94 ; NEW
        db "O", 'T' | $80, $E0 ; NOT
        db 0
StdKeywordsO:
        db "PE", 'N' | $80, $B0 ; OPEN
        db "U", 'T' | $80, $9C ; OUT
        db 'N' | $80, $95 ; ON
        db 'R' | $80, $F7 ; OR
        db "CT", '$' | $80, $1A ; OCT$
        db "F", 'F' | $80, $EB ; OFF
        db 0
StdKeywordsP:
        db "RIN", 'T' | $80, $91 ; PRINT
        db "U", 'T' | $80, $B3 ; PUT
        db "OK", 'E' | $80, $98 ; POKE
        db "O", 'S' | $80, $11 ; POS
        db "EE", 'K' | $80, $17 ; PEEK
        db "SE", 'T' | $80, $C2 ; PSET
        db "RESE", 'T' | $80, $C3 ; PRESET
        db "OIN", 'T' | $80, $ED ; POINT
        db "AIN", 'T' | $80, $BF ; PAINT
        db "D", 'L' | $80, $24 ; PDL
        db "A", 'D' | $80, $25 ; PAD
        db "LA", 'Y' | $80, $C1 ; PLAY
        db 0
StdKeywordsQ:
        db 0
StdKeywordsR:
        db "ETUR", 'N' | $80, $8E ; RETURN
        db "EA", 'D' | $80, $87 ; READ
        db "U", 'N' | $80, $8A ; RUN
        db "ESTOR", 'E' | $80, $8C ; RESTORE
        db "E", 'M' | $80, $8F ; REM
        db "ESUM", 'E' | $80, $A7 ; RESUME
        db "SE", 'T' | $80, $B9 ; RSET
        db "IGHT", '$' | $80, $02 ; RIGHT$
        db "N", 'D' | $80, $08 ; RND
        db "ENU", 'M' | $80, $AA ; RENUM
        db 0
StdKeywordsS:
        db "CREE", 'N' | $80, $C5 ; SCREEN
        db "PRIT", 'E' | $80, $C7 ; SPRITE
        db "TO", 'P' | $80, $90 ; STOP
        db "WA", 'P' | $80, $A4 ; SWAP
        db "E", 'T' | $80, $D2 ; SET
        db "AV", 'E' | $80, $BA ; SAVE
        db "PC", '(' | $80, $DF ; SPC(
        db "TE", 'P' | $80, $DC ; STEP
        db "G", 'N' | $80, $04 ; SGN
        db "Q", 'R' | $80, $07 ; SQR
        db "I", 'N' | $80, $09 ; SIN
        db "TR", '$' | $80, $13 ; STR$
        db "TRING", '$' | $80, $E3 ; STRING$
        db "PACE", '$' | $80, $19 ; SPACE$
        db "OUN", 'D' | $80, $C4 ; SOUND
        db "TIC", 'K' | $80, $22 ; STICK
        db "TRI", 'G' | $80, $23 ; STRIG
        db 0
StdKeywordsT:
        db "HE", 'N' | $80, $DA ; THEN
        db "RO", 'N' | $80, $A2 ; TRON
        db "ROF", 'F' | $80, $A3 ; TROFF
        db "AB", '(' | $80, $DB ; TAB(
        db 'O' | $80, $D9 ; TO
        db "IM", 'E' | $80, $CB ; TIME
        db "A", 'N' | $80, $0D ; TAN
        db 0
StdKeywordsU:
        db "SIN", 'G' | $80, $E4 ; USING
        db "S", 'R' | $80, $DD ; USR
        db 0
StdKeywordsV:
        db "A", 'L' | $80, $14 ; VAL
        db "ARPT", 'R' | $80, $E7 ; VARPTR
        db "D", 'P' | $80, $C8 ; VDP
        db "POK", 'E' | $80, $C6 ; VPOKE
        db "PEE", 'K' | $80, $18 ; VPEEK
        db 0
StdKeywordsW:
        db "IDT", 'H' | $80, $A0 ; WIDTH
        db "AI", 'T' | $80, $96 ; WAIT
        db 0
StdKeywordsX:
        db "O", 'R' | $80, $F8 ; XOR
        db 0
StdKeywordsY:
        db 0
StdKeywordsZ:
        db 0
        assert $ == $3D26
        db '+' | $80, $F1, '-' | $80, $F2, '*' | $80, $F3, '/' | $80, $F4, '^' | $80, $F5
        db $DC, $FC, "'" | $80, $E6, '>' | $80, $EE, '=' | $80, $EF, '<' | $80, $F0, 0           ; (DCh: "\" with bit 7)
        assert $ == $3D3B
