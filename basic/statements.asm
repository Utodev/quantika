; statements.asm: the table of the statements (tokens 81h-D8h): the routine of each one.
; Those not written yet are a Syntax error (they come with the later stages).

StatementTable:
        dw StatementEnd           ; END
        dw StatementFor           ; FOR
        dw StatementNext          ; NEXT
        dw StatementData          ; DATA
        dw StatementInput         ; INPUT
        dw StatementDim           ; DIM
        dw StatementRead          ; READ
        dw StatementLet           ; LET
        dw StatementGoto          ; GOTO
        dw StatementRun           ; RUN
        dw StatementIf            ; IF
        dw StatementRestore       ; RESTORE
        dw StatementGosub         ; GOSUB
        dw StatementReturn        ; RETURN
        dw StatementRem           ; REM
        dw StatementStop          ; STOP
        dw StatementPrint         ; PRINT
        dw StatementClear         ; CLEAR
        dw StatementList          ; LIST
        dw StatementNew           ; NEW
        dw StatementOn            ; ON
        dw StatementWait          ; WAIT
        dw StatementDef           ; DEF
        dw StatementPoke          ; POKE
        dw StatementCont          ; CONT
        dw StatementCsave         ; CSAVE
        dw StatementCload         ; CLOAD
        dw StatementOut           ; OUT
        dw StatementLprint        ; LPRINT
        dw StatementLlist         ; LLIST
        dw StatementCls           ; CLS
        dw StatementWidth         ; WIDTH
        dw StatementElse          ; ELSE
        dw StatementTron          ; TRON
        dw StatementTroff         ; TROFF
        dw StatementSwap          ; SWAP
        dw StatementErase         ; ERASE
        dw StatementError         ; ERROR
        dw StatementResume        ; RESUME
        dw StatementDelete        ; DELETE
        dw StatementAuto          ; AUTO
        dw StatementRenum         ; RENUM
        dw StatementDefStr        ; DEFSTR
        dw StatementDefInt        ; DEFINT
        dw StatementDefSng        ; DEFSNG
        dw StatementDefDbl        ; DEFDBL
        dw StatementLine          ; LINE
        dw StatementOpen          ; OPEN
        dw StatementField         ; FIELD
        dw StatementGet           ; GET (DATE, TIME; the disk's: an error)
        dw StatementPut           ; PUT
        dw StatementClose         ; CLOSE
        dw StatementLoad          ; LOAD
        dw StatementMerge         ; MERGE
        dw StatementFiles         ; FILES
        dw StatementLset          ; LSET
        dw StatementRset          ; RSET
        dw StatementSave          ; SAVE
        dw StatementLfiles        ; LFILES
        dw StatementCircle        ; CIRCLE
        dw StatementColor         ; COLOR
        dw StatementDraw          ; DRAW
        dw StatementPaint         ; PAINT
        dw StatementBeep          ; BEEP
        dw StatementPlay          ; PLAY
        dw StatementPset          ; PSET
        dw StatementPreset        ; PRESET
        dw StatementSound         ; SOUND
        dw StatementScreen        ; SCREEN
        dw StatementVpoke         ; VPOKE
        dw StatementSprite        ; SPRITE
        dw StatementVdp           ; VDP
        dw StatementBase          ; BASE
        dw StatementCall          ; CALL
        dw StatementTime          ; TIME
        dw StatementKey           ; KEY
        dw StatementMax           ; MAX
        dw StatementMotor         ; MOTOR
        dw StatementBload         ; BLOAD
        dw StatementBsave         ; BSAVE
        dw StatementDsko          ; DSKO$
        dw StatementSet           ; SET
        dw StatementName          ; NAME
        dw StatementKill          ; KILL
        dw StatementIpl           ; IPL
        dw StatementCopy          ; COPY
        dw StatementCmd           ; CMD
        dw StatementLocate        ; LOCATE

; The disk's statements (FIELD, FILES, LSET, RSET, LFILES, DSKO$, NAME, KILL, IPL, CMD): a disk ROM takes
; them through their hooks (common/diskapi.inc); without one, Illegal function call (as the original).
StatementField:  ld c,TkField : ld ix,H_FIEL : jr DiskStatement
StatementFiles:  ld c,TkFiles : ld ix,H_FILE : jr DiskStatement
StatementLfiles: ld c,TkLfiles : ld ix,H_FILE : jr DiskStatement
StatementLset:   ld c,TkLset : ld ix,H_LSET : jr DiskStatement
StatementRset:   ld c,TkRset : ld ix,H_RSET : jr DiskStatement
StatementDsko:   ld c,TkDskoStr : ld ix,H_DSKO : jr DiskStatement
StatementName:   ld c,TkName : ld ix,H_NAME : jr DiskStatement
StatementKill:   ld c,TkKill : ld ix,H_KILL : jr DiskStatement
StatementIpl:    ld c,TkIpl : ld ix,H_IPL : jr DiskStatement
StatementCmd:    ld c,TkCmd : ld ix,H_CMD
; DiskStatement: (also the disk's functions) calls the hook IX with carry set, C = the token; carry still
; set when it comes back: no disk ROM took it, Illegal function call.
DiskStatement:
        call DiskHook
        ret nc
        jp IllegalFunction
; DiskHook: the hook IX with carry set (A, C, HL as the caller left them). Out: the hook's carry and HL.
DiskHook:
        scf
        jp (ix)
; FileHook: the same with the hook IY (the sub-ROM's file code calls it through CallMain, which takes IX).
FileHook:
        scf
        jp (iy)
