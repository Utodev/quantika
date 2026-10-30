; mathpack.inc: the entry points of the Math-Pack, the BCD arithmetic of BASIC, fixed by the standard
; (the published technical handbook, appendix 2). Machine code programs call them by address.
DECSUB          equ $268C       ; DAC = DAC - ARG (double precision)
DECADD          equ $269A       ; DAC = DAC + ARG
DECNRM          equ $26FA       ; normalise DAC
DECROU          equ $273C       ; round DAC
DECMUL          equ $27E6       ; DAC = DAC * ARG
DECDIV          equ $289F       ; DAC = DAC / ARG
COS             equ $2993
SIN             equ $29AC
TAN             equ $29FB
ATN             equ $2A14
LOG             equ $2A72
SQR             equ $2AFF
EXP             equ $2B4A
RND             equ $2BDF
MAF             equ $2C4D       ; ARG = DAC (8 bytes)
MAM             equ $2C50       ; ARG = (HL)
MOV8DH          equ $2C53       ; (DE) = (HL)
MFA             equ $2C59       ; DAC = ARG
MFM             equ $2C5C       ; DAC = (HL)
MMF             equ $2C67       ; (HL) = DAC
MOV8HD          equ $2C6A       ; (HL) = (DE)
XTF             equ $2C6F       ; (SP) <-> DAC
PHA             equ $2CC7
PHF             equ $2CCC
PPA             equ $2CDC
PPF             equ $2CE1
SIGN            equ $2E71       ; A = sign of DAC
ABSFN           equ $2E82       ; DAC = ABS(DAC)
NEG             equ $2E8D       ; DAC = -DAC
SGN             equ $2E97       ; DAC = SGN(DAC) as an integer
PUSHF           equ $2EB1       ; single precision moves (4 bytes)
MOVFM           equ $2EBE       ; DAC = (HL)
MOVFR           equ $2EC1       ; DAC = registers
MOVRF           equ $2ECC       ; registers = DAC
MOVRMI          equ $2ED6
MOVRM           equ $2EDF
MOVMF           equ $2EE8       ; (HL) = DAC
MOVE            equ $2EEB       ; (HL) = (DE)
VMOVAM          equ $2EEF       ; moves of VALTYP bytes: ARG = (HL)
MOVVFM          equ $2EF2       ; (DE) = (HL)
VMOVE           equ $2EF3       ; (HL) = (DE)
VMOVFA          equ $2F05       ; DAC = ARG
VMOVFM          equ $2F08       ; DAC = (HL)
VMOVAF          equ $2F0D       ; ARG = DAC
VMOVMF          equ $2F10       ; (HL) = DAC
FCOMP           equ $2F21       ; compare single precision: registers with DAC
ICOMP           equ $2F4D       ; compare integers: DE with HL
XDCOMP          equ $2F5C       ; compare double precision: ARG with DAC
FRCINT          equ $2F8A       ; DAC to integer
FRCSNG          equ $2FB2       ; DAC to single precision
FRCDBL          equ $303A       ; DAC to double precision
FIXER           equ $30BE       ; DAC = SGN(DAC) * INT(ABS(DAC))
UMULT           equ $314A       ; DE = BC * DE
ISUB            equ $3167       ; HL = DE - HL
IADD            equ $3172       ; HL = DE + HL
IMULT           equ $3193       ; HL = DE * HL
IDIV            equ $31E6       ; HL = DE / HL
IMOD            equ $323A       ; HL = DE MOD HL
FIN             equ $3299       ; text to number
FOUT            equ $3425       ; number to text
PUFOUT          equ $3426       ; number to text with a format
FOUTB           equ $371A       ; integer to binary text
FOUTO           equ $371E       ; integer to octal text
FOUTH           equ $3722       ; integer to hexadecimal text
SGNEXP          equ $37C8       ; DAC ^ ARG, single precision
DBLEXP          equ $37D7       ; DAC ^ ARG, double precision
INTEXP          equ $383F       ; DE ^ HL, integers

; Value types (VALTYP)
TypeInteger     equ 2
TypeString      equ 3
TypeSingle      equ 4
TypeDouble      equ 8

