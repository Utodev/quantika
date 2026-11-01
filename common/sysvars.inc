; sysvars.inc: the work area and hooks in RAM (page 3), at the addresses fixed by the standard.
; Programs read and write these directly, so they cannot move. All values are hexadecimal.

; --- Memory primitives copied from ROM at boot ---
RDPRIM          equ $F380       ; 5 bytes   read from a slot (OUT/LD/OUT/RET)
WRPRIM          equ $F385       ; 7 bytes   write to a slot
CLPRIM          equ $F38C       ; 14 bytes  call a routine in a slot
USRTAB          equ $F39A       ; 20 bytes  addresses of USR0..USR9

; --- Screen parameters ---
LINL40          equ $F3AE       ; width in SCREEN 0 (40 or 80)
LINL32          equ $F3AF       ; width in SCREEN 1
LINLEN          equ $F3B0       ; current width
CRTCNT          equ $F3B1       ; number of lines
CLMLST          equ $F3B2       ; column of the last tab stop
TXTNAM          equ $F3B3       ; SCREEN 0 name table
TXTCOL          equ $F3B5
TXTCGP          equ $F3B7
TXTATR          equ $F3B9
TXTPAT          equ $F3BB
T32NAM          equ $F3BD       ; SCREEN 1
T32COL          equ $F3BF
T32CGP          equ $F3C1
T32ATR          equ $F3C3
T32PAT          equ $F3C5
GRPNAM          equ $F3C7       ; SCREEN 2
GRPCOL          equ $F3C9
GRPCGP          equ $F3CB
GRPATR          equ $F3CD
GRPPAT          equ $F3CF
MLTNAM          equ $F3D1       ; SCREEN 3
MLTCOL          equ $F3D3
MLTCGP          equ $F3D5
MLTATR          equ $F3D7
MLTPAT          equ $F3D9
CLIKSW          equ $F3DB       ; key click on / off
CSRY            equ $F3DC       ; cursor row (1 based)
CSRX            equ $F3DD       ; cursor column (1 based)
CNSDFG          equ $F3DE       ; function key line shown
RG0SAV          equ $F3DF       ; copy of VDP registers 0-7
RG1SAV          equ $F3E0
RG2SAV          equ $F3E1
RG3SAV          equ $F3E2
RG4SAV          equ $F3E3
RG5SAV          equ $F3E4
RG6SAV          equ $F3E5
RG7SAV          equ $F3E6
STATFL          equ $F3E7       ; copy of VDP status register 0
TRGFLG          equ $F3E8       ; trigger buttons state
FORCLR          equ $F3E9       ; foreground colour
BAKCLR          equ $F3EA       ; background colour
BDRCLR          equ $F3EB       ; border colour
MAXUPD          equ $F3EC       ; (JP) used by the graphic routines
MINUPD          equ $F3EF
ATRBYT          equ $F3F2       ; attribute byte of the graphic routines
QUEUES          equ $F3F3       ; address of the sound queue table
FRCNEW          equ $F3F5       ; CLOAD / CLOAD? flag
SCNCNT          equ $F3F6       ; key scan interval counter
REPCNT          equ $F3F7       ; key repeat delay counter
PUTPNT          equ $F3F8       ; keyboard buffer write pointer
GETPNT          equ $F3FA       ; keyboard buffer read pointer
CS120           equ $F3FC       ; cassette parameters, 1200 baud
CS240           equ $F401       ; cassette parameters, 2400 baud
CasLow          equ $F406       ; LOW: cassette parameters in use (5 bytes, see bios/cassette.asm)
CasHigh         equ $F408       ; HIGH
CasHeader       equ $F40A       ; HEADER
ASPCT1          equ $F40B
ASPCT2          equ $F40D
ENDPRG          equ $F40F       ; 5 bytes, fake end of program
ERRFLG          equ $F414
LPTPOS          equ $F415       ; printer head column
PRTFLG          equ $F416       ; output to printer
NTSTDP          equ $F417       ; printer is not one of the standard
RAWPRT          equ $F418       ; raw printer output
VLZADR          equ $F419
VLZDAT          equ $F41B
CURLIN          equ $F41C       ; line being executed (FFFFh in direct mode)
KBFMIN          equ $F41E
KBUF            equ $F41F       ; crunched line buffer
BUFMIN          equ $F55D
BUF             equ $F55E       ; line input buffer (258 bytes)
ENDBUF          equ $F660
TTYPOS          equ $F661
DIMFLG          equ $F662
VALTYP          equ $F663       ; type of the value in DAC (2 integer, 3 string, 4 single, 8 double)
DORES           equ $F664
DONUM           equ $F665
CONTXT          equ $F666
CONSAV          equ $F668
CONTYP          equ $F669
CONLO           equ $F66A
MEMSIZ          equ $F672       ; highest BASIC memory address
STKTOP          equ $F674       ; top of the stack area
TXTTAB          equ $F676       ; start of the program text
TEMPPT          equ $F678
TEMPST          equ $F67A
DSCTMP          equ $F698
FRETOP          equ $F69B       ; top of free string space
TEMP3           equ $F69D
TEMP8           equ $F69F
ENDFOR          equ $F6A1
DATLIN          equ $F6A3
SUBFLG          equ $F6A5
FLGINP          equ $F6A6
TEMP            equ $F6A7
PTRFLG          equ $F6A9
AUTFLG          equ $F6AA
AUTLIN          equ $F6AB
AUTINC          equ $F6AD
SAVTXT          equ $F6AF       ; text pointer saved by STOP / END
SAVSTK          equ $F6B1
ERRLIN          equ $F6B3
DOT             equ $F6B5
ERRTXT          equ $F6B7
ONELIN          equ $F6B9       ; ON ERROR GOTO line
ONEFLG          equ $F6BB
TEMP2           equ $F6BC
OLDLIN          equ $F6BE
OLDTXT          equ $F6C0
VARTAB          equ $F6C2       ; start of simple variables
ARYTAB          equ $F6C4       ; start of arrays
STREND          equ $F6C6       ; end of variables / arrays
DATPTR          equ $F6C8
DEFTBL          equ $F6CA       ; 26 bytes, default type of each initial letter
PRMSTK          equ $F6E4
PRMLEN          equ $F6E6
PARM1           equ $F6E8
PRMPRV          equ $F74C
PRMLN2          equ $F74E
PARM2           equ $F750
PRMFLG          equ $F7B4
ARYTA2          equ $F7B5
NOFUNS          equ $F7B7
TEMP9           equ $F7B8
FUNACT          equ $F7BA
SWPTMP          equ $F7BC
TRCFLG          equ $F7C4
FBUFFR          equ $F7C5       ; number conversion buffer (43 bytes)
DECTMP          equ $F7F0
DECTM2          equ $F7F2
DECCNT          equ $F7F4
DAC             equ $F7F6       ; decimal accumulator, 16 bytes
HOLD8           equ $F806
HOLD2           equ $F836
HOLD            equ $F83E
ARG             equ $F847       ; second operand of the math pack, 16 bytes
RNDX            equ $F857
MAXFIL          equ $F85F       ; highest file number
FILTAB          equ $F860       ; address of the file control block table
NULBUF          equ $F862
PTRFIL          equ $F864
RUNFLG          equ $F866
FILNAM          equ $F866
FILNM2          equ $F871
NLONLY          equ $F87C
SAVEND          equ $F87D
FNKSTR          equ $F87F       ; function key strings, 10 x 16 bytes
CGPNT           equ $F91F
NAMBAS          equ $F922
CGPBAS          equ $F924
PATBAS          equ $F926
ATRBAS          equ $F928
CLOC            equ $F92A
CMASK           equ $F92C
MINDEL          equ $F92D
MAXDEL          equ $F92F
ASPECT          equ $F931
CENCNT          equ $F933
CLINEF          equ $F935
CNPNTS          equ $F936
CPLOTF          equ $F938
CPCNT           equ $F939
CPCNT8          equ $F93B
CRCSUM          equ $F93D
CSTCNT          equ $F93F
CSCLXY          equ $F941
CSAVEA          equ $F942
CSAVEM          equ $F944
CXOFF           equ $F945
CYOFF           equ $F947
LOHMSK          equ $F949
LOHDIR          equ $F94A
LOHADR          equ $F94B
LOHCNT          equ $F94D
SKPCNT          equ $F94F
MOVCNT          equ $F951
PDIREC          equ $F953
LFPROG          equ $F954
RTPROG          equ $F955
MCLTAB          equ $F956
MCLFLG          equ $F958
QUETAB          equ $F959       ; sound queue table
QUEBAK          equ $F971
VOICAQ          equ $F975       ; PSG voice queues, 128 bytes each
VOICBQ          equ $F9F5
VOICCQ          equ $FA75
DPPAGE          equ $FAF5       ; displayed page (V9938)
ACPAGE          equ $FAF6       ; active page (V9938)
AVCSAV          equ $FAF7
EXBRSA          equ $FAF8       ; slot of the sub-ROM
CHRCNT          equ $FAF9
ROMA            equ $FAFA
MODE            equ $FAFC
NORUSE          equ $FAFD
XSAVE           equ $FAFE
YSAVE           equ $FB00
LOGOPR          equ $FB02
PRSCNT          equ $FB35
SAVSP           equ $FB36
VOICEN          equ $FB38
SAVVOL          equ $FB39
MCLLEN          equ $FB3B
MCLPTR          equ $FB3C
QUEUEN          equ $FB3E
MUSICF          equ $FB3F
PLYCNT          equ $FB40
VCBA            equ $FB41       ; voice control blocks, 37 bytes each
VCBB            equ $FB66
VCBC            equ $FB8B
ENSTOP          equ $FBB0       ; warm start with CTRL+SHIFT+GRAPH+KANA
BASROM          equ $FBB1       ; BASIC in ROM, not the user's: CTRL+STOP is off when non zero
LINTTB          equ $FBB2       ; line terminator table, 24 bytes
FSTPOS          equ $FBCA
CODSAV          equ $FBCC
FNKSWI          equ $FBCD
FNKFLG          equ $FBCE       ; 10 bytes, function key ON KEY state
ONGSBF          equ $FBD8
CLIKFL          equ $FBD9
OLDKEY          equ $FBDA       ; 11 bytes, previous keyboard matrix
NEWKEY          equ $FBE5       ; 11 bytes, current keyboard matrix
KEYBUF          equ $FBF0       ; 40 bytes, circular key buffer
LINWRK          equ $FC18
PATWRK          equ $FC40
BOTTOM          equ $FC48       ; lowest RAM address
HIMEM           equ $FC4A       ; highest free RAM address
TRPTBL          equ $FC4C       ; 78 bytes, ON KEY / STOP / ... trap table
RTYCNT          equ $FC9A
INTFLG          equ $FC9B       ; set when CTRL+STOP / STOP pressed
PADY            equ $FC9C
PADX            equ $FC9D
JIFFY           equ $FC9E       ; frame counter
INTVAL          equ $FCA0
INTCNT          equ $FCA2
LOWLIM          equ $FCA4
WINWID          equ $FCA5
GRPHED          equ $FCA6
ESCCNT          equ $FCA7
INSFLG          equ $FCA8
CSRSW           equ $FCA9       ; cursor shown
CSTYLE          equ $FCAA
CAPST           equ $FCAB
KANAST          equ $FCAC
KANAMD          equ $FCAD
FLBMEM          equ $FCAE
SCRMOD          equ $FCAF       ; current screen mode
OLDSCR          equ $FCB0
CASPRV          equ $FCB1
BRDATR          equ $FCB2
GXPOS           equ $FCB3
GYPOS           equ $FCB5
GRPACX          equ $FCB7
GRPACY          equ $FCB9
DRWFLG          equ $FCBB
DRWSCL          equ $FCBC
DRWANG          equ $FCBD
RUNBNF          equ $FCBE
SAVENT          equ $FCBF
EXPTBL          equ $FCC1       ; 4 bytes, bit 7 set when the primary slot is expanded (FCC1 also holds the BIOS slot)
SLTTBL          equ $FCC5       ; 4 bytes, copy of the secondary slot register of each primary slot
SLTATR          equ $FCC9       ; 64 bytes, attributes of each slot (bit 7 BASIC ROM, 6 device, 5 statement)
SLTWRK          equ $FD09       ; 128 bytes, work area of each slot (8 bytes per page, 4 pages per slot)
PROCNM          equ $FD89       ; 16 bytes, name of the statement of CALL
DEVICE          equ $FD99

; --- Hooks: 5 bytes each, hold RET (C9h) at boot; a ROM or the disk interface patches in a jump.
;     The BIOS and FBASIC call each one at the point the standard says. ---
H_KEYI          equ $FD9A
H_TIMI          equ $FD9F
H_CHPU          equ $FDA4
H_DSPC          equ $FDA9
H_ERAC          equ $FDAE
H_DSPF          equ $FDB3
H_ERAF          equ $FDB8
H_TOTE          equ $FDBD
H_CHGE          equ $FDC2
H_INIP          equ $FDC7
H_KEYC          equ $FDCC
H_KYEA          equ $FDD1
H_NMI           equ $FDD6
H_PINL          equ $FDDB
H_QINL          equ $FDE0
H_INLI          equ $FDE5
H_ONGO          equ $FDEA
H_DSKO          equ $FDEF
H_SETS          equ $FDF4
H_NAME          equ $FDF9
H_KILL          equ $FDFE
H_IPL           equ $FE03
H_COPY          equ $FE08
H_CMD           equ $FE0D
H_DSKF          equ $FE12
H_DSKI          equ $FE17
H_ATTR          equ $FE1C
H_LSET          equ $FE21
H_RSET          equ $FE26
H_FIEL          equ $FE2B
H_MKIS          equ $FE30
H_MKSS          equ $FE35
H_MKDS          equ $FE3A
H_CVI           equ $FE3F
H_CVS           equ $FE44
H_CVD           equ $FE49
H_GETP          equ $FE4E
H_SETF          equ $FE53
H_NOFO          equ $FE58
H_NULO          equ $FE5D
H_NTFL          equ $FE62
H_MERG          equ $FE67
H_SAVE          equ $FE6C
H_BINS          equ $FE71
H_BINL          equ $FE76
H_FILE          equ $FE7B
H_DGET          equ $FE80
H_FILO          equ $FE85
H_INDS          equ $FE8A
H_RSLF          equ $FE8F
H_SAVD          equ $FE94
H_LOC           equ $FE99
H_LOF           equ $FE9E
H_EOF           equ $FEA3
H_FPOS          equ $FEA8
H_BAKU          equ $FEAD
H_PARD          equ $FEB2
H_NODE          equ $FEB7
H_POSD          equ $FEBC
H_DEVN          equ $FEC1
H_GEND          equ $FEC6
H_RUNC          equ $FECB
H_CLEA          equ $FED0
H_LOPD          equ $FED5
H_STKE          equ $FEDA
H_ISFL          equ $FEDF
H_OUTD          equ $FEE4
H_CRDO          equ $FEE9
H_DSKC          equ $FEEE
H_DOGR          equ $FEF3
H_PRGE          equ $FEF8
H_ERRP          equ $FEFD
H_ERRF          equ $FF02
H_READ          equ $FF07
H_MAIN          equ $FF0C
H_DIRD          equ $FF11
H_FINI          equ $FF16
H_FINE          equ $FF1B
H_CRUN          equ $FF20
H_CRUS          equ $FF25
H_ISRE          equ $FF2A
H_NTFN          equ $FF2F
H_NOTR          equ $FF34
H_SNGF          equ $FF39
H_NEWS          equ $FF3E
H_GONE          equ $FF43
H_CHRG          equ $FF48
H_RETU          equ $FF4D
H_PRTF          equ $FF52
H_COMP          equ $FF57
H_FINP          equ $FF5C
H_TRMN          equ $FF61
H_FRME          equ $FF66
H_NTPL          equ $FF6B
H_EVAL          equ $FF70
H_OKNO          equ $FF75
H_FING          equ $FF7A
H_ISMI          equ $FF7F
H_WIDT          equ $FF84
H_LIST          equ $FF89
H_BUFL          equ $FF8E
H_FRQI          equ $FF93
H_SCNE          equ $FF98
H_FRET          equ $FF9D
H_PTRG          equ $FFA2
H_PHYD          equ $FFA7
H_FORM          equ $FFAC
H_ERRO          equ $FFB1
H_LPTO          equ $FFB6
H_LPTS          equ $FFBB
H_SCRE          equ $FFC0
H_PLAY          equ $FFC5
HooksEnd        equ $FFCA       ; end of the hooks proper
EXTBIO          equ $FFCA       ; extended BIOS entry (5 bytes)
H_BGFD          equ $FFCF       ; before a disk access (disk ROM hook)
H_ENFD          equ $FFD4       ; after a disk access (disk ROM hook)
RetFilledEnd    equ $FFD9       ; FD9Ah-FFD8h are filled with RET at boot

; --- V9938 register copies ---
RG8SAV        equ $FFE7
RG9SAV        equ $FFE8
RG10SAV       equ $FFE9
RG11SAV       equ $FFEA
RG12SAV       equ $FFEB
RG13SAV       equ $FFEC
RG14SAV       equ $FFED
RG15SAV       equ $FFEE
RG16SAV       equ $FFEF
RG17SAV       equ $FFF0
RG18SAV       equ $FFF1
RG19SAV       equ $FFF2
RG20SAV       equ $FFF3
RG21SAV       equ $FFF4
RG22SAV       equ $FFF5
RG23SAV       equ $FFF6
MINROM          equ $FFF7       ; slot of the main ROM
SUBSLT          equ $FFF8       ; this ROM's own copy of EXBRSA (the sub-ROM's slot): a program can overwrite EXBRSA
RG25SAV         equ $FFFA
RG26SAV         equ $FFFB
RG27SAV         equ $FFFC

; --- Extended BIOS and others at the very end of page 3 ---
SLTSL           equ $FFFF       ; secondary slot register of the expanded slot in page 3
