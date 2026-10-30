; mathpack.asm: the Math-Pack's entry points at their fixed addresses (common/mathpack.inc). Each one
; jumps to this ROM's routine; where two entries are a byte apart, the first does its one extra step
; and runs into the second. The space between them is free for other code (not used yet).

        macro MATH_ENTRY address, target
        org address
        jp target
        endm

        MATH_ENTRY DECSUB, DecSubtract
        MATH_ENTRY DECADD, DecAdd
        MATH_ENTRY DECNRM, NormaliseDac
        MATH_ENTRY DECROU, RoundDac
        MATH_ENTRY DECMUL, DecMultiply
        MATH_ENTRY DECDIV, DecDivide
        MATH_ENTRY COS, CosDac
        MATH_ENTRY SIN, SinDac
        MATH_ENTRY TAN, TanDac
        MATH_ENTRY ATN, AtnDac
        MATH_ENTRY LOG, LogDac
        MATH_ENTRY SQR, SqrDac
        MATH_ENTRY EXP, ExpDac
        MATH_ENTRY RND, RndDac
        MATH_ENTRY MAF, MoveDacToArg
        MATH_ENTRY MAM, MoveToArg
        MATH_ENTRY MOV8DH, Move8
        MATH_ENTRY MFA, MoveArgToDac
        MATH_ENTRY MFM, MoveToDac
        MATH_ENTRY MMF, MoveDacTo
        MATH_ENTRY MOV8HD, Move8Reverse
        MATH_ENTRY XTF, MathNotYet
        MATH_ENTRY PHA, MathNotYet
        MATH_ENTRY PHF, MathNotYet
        MATH_ENTRY PPA, MathNotYet
        MATH_ENTRY PPF, MathNotYet
        MATH_ENTRY SIGN, SignOfDac
        MATH_ENTRY ABSFN, AbsDac
        MATH_ENTRY NEG, NegateRealDac
        MATH_ENTRY SGN, SgnDac
        MATH_ENTRY PUSHF, MathNotYet
        MATH_ENTRY MOVFM, MoveSingleToDac
        MATH_ENTRY MOVFR, MathNotYet
        MATH_ENTRY MOVRF, MathNotYet
        MATH_ENTRY MOVRMI, MathNotYet
        MATH_ENTRY MOVRM, MathNotYet
        MATH_ENTRY MOVMF, MoveDacToSingle
        MATH_ENTRY MOVE, MoveSingleReverse
        MATH_ENTRY VMOVAM, MoveVtToArg
        org MOVVFM                      ; (DE) = (HL): the other way round of VMOVE, one byte before it
        ex de,hl
        assert $ == VMOVE
        MATH_ENTRY VMOVE, MoveVtReverse
        MATH_ENTRY VMOVFA, MoveVtArgToDac
        MATH_ENTRY VMOVFM, MoveVtToDac
        MATH_ENTRY VMOVAF, MoveVtDacToArg
        MATH_ENTRY VMOVMF, MoveVtDacTo
        MATH_ENTRY FCOMP, CompareSingles
        MATH_ENTRY ICOMP, CompareIntegers
        MATH_ENTRY XDCOMP, CompareDoubles
        MATH_ENTRY FRCINT, ForceInteger
        MATH_ENTRY FRCSNG, ForceSingle
        MATH_ENTRY FRCDBL, ForceDouble
        MATH_ENTRY FIXER, FixDac
        MATH_ENTRY UMULT, UnsignedMultiply
        MATH_ENTRY ISUB, IntSubtract
        MATH_ENTRY IADD, IntAdd
        MATH_ENTRY IMULT, IntMultiply
        MATH_ENTRY IDIV, IntDivide
        MATH_ENTRY IMOD, IntModulo
        MATH_ENTRY FIN, FinNumber
        org FOUT                        ; FOUT: PUFOUT with no format, one byte before it
        xor a
        assert $ == PUFOUT
        MATH_ENTRY PUFOUT, FormatNumber
        MATH_ENTRY FOUTB, MathNotYet
        MATH_ENTRY FOUTO, MathNotYet
        MATH_ENTRY FOUTH, MathNotYet
        MATH_ENTRY SGNEXP, MathNotYet
        MATH_ENTRY DBLEXP, MathNotYet
        MATH_ENTRY INTEXP, MathNotYet
MathPackEnd:
