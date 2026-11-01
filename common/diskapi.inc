; diskapi.inc: how FBASIC and the free disk ROM (disk_free.asm) work together. The disk ROM runs only
; with this main ROM: it finds the service table below and, if it is not there, it installs nothing.
;
; FBASIC -> disk ROM: the disk's statements and functions call the standard's hooks, with this ROM's own
; convention (not the original's: nothing on the stack is looked at):
;   in:  carry set, HL on the item after the token (A = it, as NextChar leaves it), C = the statement's
;        token (a function: its number after FFh, DSKI$ its token)
;   out: carry clear when the disk ROM did the work, HL on the statement's end (a function: after its
;        operand, its result in DAC / VALTYP). Carry still set: no disk ROM took it (the hook is a RET):
;        FBASIC gives the error the original gives without a disk.
; The hooks so used: H_MERG (LOAD, MERGE, RUN "name": C tells them apart), H_SAVE, H_BINL (BLOAD), H_BINS
; (BSAVE), H_COPY (COPY: the disk ROM takes it only for files), H_FIEL (FIELD), H_FILE (FILES and LFILES),
; H_LSET, H_RSET, H_DSKO (DSKO$), H_NAME, H_KILL, H_IPL, H_CMD, H_DSKF, H_DSKI (DSKI$), H_CVI, H_CVS,
; H_CVD, H_MKIS, H_MKSS, H_MKDS, H_FPOS.
;
; The files of OPEN (basic/files.asm keeps each file's block: its mode, device, place in the buffer and the
; buffer; a device under FCh is the disk ROM's). These hooks are called with carry set too and clear it when
; they take the call; they keep BC, DE and HL:
;   H_PARD  OPEN's name (DE, B characters) is no device of FBASIC's: A = the disk ROM's device
;   H_NULO  open the file of that name as the file of block DE in mode B (1 input, 2 output, 4 random, 8
;           append); block + 1 = LEN (a word, 0 when not given); the mode is put in the block afterwards
;   H_INDS  fill the buffer of block DE (a file being read) with its next 256 bytes, 1Ah after the end
;   H_FILO  the full buffer of block DE (a file being written) to the disk
;   H_NTFL  close the file of block DE (A = the mode it had; the block is closed already)
;   H_DGET  GET / PUT (C = the token, HL on the file's number) of a random file
;   H_LOC, H_LOF  LOC / LOF of the file of block DE (open): the result in DAC; carry still set for another
;           device's file (Illegal function call)
;
; disk ROM -> FBASIC: CALBAS (0159h) with IX = the address of one of FBASIC's routines. The addresses
; are in a table (DW each) that the main ROM points to from a small header at a fixed place, its last 16
; bytes; the disk ROM's INIT copies the table into its work area. Entries are only ever added at the end;
; the header counts them.

DiskServices    equ $7FF0               ; the header (the main ROM's last 16 bytes)
DsSignature     equ DiskServices        ; 6 bytes: "FBDISK"
DsCount         equ DiskServices + 6    ; the number of entries
DsTable         equ DiskServices + 8    ; DW: where the table is

; the entries (their number in the table; each takes and returns as said)
SrvRaiseError   equ 0                   ; E = the error's number: as ERROR E (does not return)
SrvEvalString   equ 1                   ; a string expression at HL: B = its length, DE = its characters, HL
                                        ; past it (Type mismatch for a number)
SrvEvalAddress  equ 2                   ; a numeric expression at HL: DE = it as an address, HL past it
SrvEvalByte     equ 3                   ; a numeric expression at HL: A = it (0-255), HL past it
SrvNewProgram   equ 4                   ; NEW: no program, no variables
SrvAsciiLine    equ 5                   ; the text in BUF up to HL (a line of a program as text) into the
                                        ; program (Direct statement in file without a line number)
SrvProgramLoaded equ 6                  ; the lines just put from TXTTAB linked, VARTAB past them, no variables
SrvReady        equ 7                   ; to BASIC's direct mode ("Ok"; does not return)
SrvRunLoaded    equ 8                   ; RUN the program in memory (does not return)
SrvListToBuffer equ 9                   ; the program listed as text into the 256-byte buffer at HL; each time
                                        ; it is full, H_SAVD is called (carry set, HL = the buffer: the hook
                                        ; clears the carry when it takes it). Out: HL past the characters left
                                        ; in it

SrvGetVariable  equ 10                  ; the variable at HL (made when new): DE = its value, VALTYP its type, HL
                                        ; past it
SrvEvalExpression equ 11                ; an expression at HL: DAC / VALTYP, HL past it
SrvForceInteger equ 12                  ; DAC to an integer (DAC + 2; Overflow, Type mismatch)
SrvForceSingle  equ 13                  ; DAC to single precision
SrvForceDouble  equ 14                  ; DAC to double precision
SrvMakeString   equ 15                  ; a temporary string of B characters copied from HL: the result in DAC

SrvEntries      equ 16                  ; entries so far
