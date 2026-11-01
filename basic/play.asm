; play.asm: PLAY and the music that plays in the background. PLAY compiles the music macro language of
; each voice into events of 4 bytes (PSG period low, high, volume, frames) in that voice's queue
; (VOICAQ, VOICBQ, VOICCQ: 128 bytes, 32 events); the interrupt plays them one after another. A full
; queue makes PLAY wait. The language: A-G (# + - after), lengths and dots, R, O, L, T, V, N, < >;
; S and M (the envelope) are read and ignored. The state of each voice (octave, length, tempo,
; volume) stays from one PLAY to the next, in its voice block (VCBA, VCBB, VCBC).
;
; The queues' pointers are in QUETAB, laid out as the standard has it (the BIOS's LFTQ and PUTQ use them): for
; each queue (the three voices and a fourth one) the put and get offsets, a byte kept 0, the size less one
; (7Fh) and the queue's address. The frames left of the event being played are in the voice block.

VoiceOctave     equ 0                   ; (offsets in a voice block)
VoiceLength     equ 1
VoiceTempo      equ 2
VoiceVolume     equ 3
VoiceFramesLeft equ 4

; InitMusic: the voices silent, the queues empty, the voice blocks at O4 L4 T120 V8.
InitMusic:
        xor a
        ld (MUSICF),a
        ld hl,QUETAB
        ld b,24
.clear:
        ld (hl),$00
        inc hl
        djnz .clear
        ld hl,QUETAB + 3                ; the voices' queues: size less one, address
        ld de,VOICAQ
        ld b,3
.queue:
        ld (hl),$7F
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc hl
        inc hl
        inc hl
        ld a,e
        add a,$80
        ld e,a
        jr nc,.sameHigh
        inc d
.sameHigh:
        djnz .queue
        ld hl,VCBA
        call .voice
        ld hl,VCBB
        call .voice
        ld hl,VCBC
.voice:
        ld (hl),4
        inc hl
        ld (hl),4
        inc hl
        ld (hl),120
        inc hl
        ld (hl),8
        inc hl
        ld (hl),0                       ; (frames left)
        ret

; StatementPlay: PLAY string [, string [, string]].
StatementPlay:
        ld c,$00                        ; C = the voice
.voice:
        push bc
        call ThisChar
        cp ','
        jr z,.skip
        call EvalExpression
        push hl
        call StringOperand              ; B = length, DE = characters
        pop hl
        ld a,b
        pop bc                          ; C = the voice
        push bc
        push hl
        ld b,a
        ex de,hl
        call CompileVoice               ; C = voice, HL = text, B = length
        pop hl
.skip:
        pop bc
        call ThisChar
        cp ','
        ret nz
        rst $10
        inc c
        ld a,c
        cp $03
        jr c,.voice
        jp SyntaxError

; VoiceBlock: IX = the voice block of voice C.
VoiceBlock:
        push de
        ld ix,VCBA
        ld de,VCBB - VCBA
        ld a,c
.next:
        or a
        jr z,.done
        add ix,de
        dec a
        jr .next
.done:
        pop de
        ret

; CompileVoice: the macro language at HL (B characters) for voice C, into its queue.
CompileVoice:
        call VoiceBlock
.command:
        ld a,b
        or a
        ret z
        ld a,(hl)
        inc hl
        dec b
        call UpperCase
        cp 'A'
        jr c,.other
        cp 'H'
        jr c,.note
.other:
        cp 'R'
        jp z,.rest
        cp 'O'
        jp z,.octave
        cp 'L'
        jp z,.length
        cp 'T'
        jp z,.tempo
        cp 'V'
        jp z,.volume
        cp 'N'
        jp z,.number
        cp '<'
        jr z,.down
        cp '>'
        jr z,.up
        cp 'S'
        jr z,.ignoreNumber
        cp 'M'
        jr z,.ignoreNumber
        jr .command                     ; spaces and the rest: nothing
.ignoreNumber:
        call MmlNumber
        jr .command
.down:
        ld a,(ix+VoiceOctave)
        dec a
        jr z,.command
        ld (ix+VoiceOctave),a
        jr .command
.up:
        ld a,(ix+VoiceOctave)
        cp 8
        jr nc,.command
        inc a
        ld (ix+VoiceOctave),a
        jr .command
.note:
        sub 'A'                         ; A-G: semitones from C
        push hl
        ld e,a
        ld d,$00
        ld hl,NoteSemitones
        add hl,de
        ld e,(hl)                       ; E = semitone
        pop hl
        ld a,b                          ; # + sharp, - flat
        or a
        jr z,.noAccidental
        ld a,(hl)
        cp '#'
        jr z,.sharp
        cp '+'
        jr z,.sharp
        cp '-'
        jr nz,.noAccidental
        dec e
        jr .accidental
.sharp:
        inc e
.accidental:
        inc hl
        dec b
.noAccidental:
        ld d,(ix+VoiceOctave)
        call NotePeriod                 ; DE = period
        push de
        call NoteFrames                 ; A = frames (length after the note, dots)
        pop de
        jr .emit
.rest:
        call NoteFrames
        ld de,$0000
.emit:
        call QueueEvent                 ; DE = period (0: rest), A = frames
        jp .command
.octave:
        call MmlNumber
        cp 1
        jp c,.command
        cp 9
        jp nc,.command
        ld (ix+VoiceOctave),a
        jp .command
.length:
        call MmlNumber
        or a
        jp z,.command
        cp 65
        jp nc,.command
        ld (ix+VoiceLength),a
        jp .command
.tempo:
        call MmlNumber
        cp 32
        jp c,.command
        ld (ix+VoiceTempo),a
        jp .command
.volume:
        call MmlNumber
        cp 16
        jp nc,.command
        ld (ix+VoiceVolume),a
        jp .command
.number:                                ; N0-96: N0 a rest
        call MmlNumber
        or a
        jr z,.restN
        dec a                           ; N1 = O1 C
        ld d,1
.octaves:
        cp 12
        jr c,.inOctave
        sub 12
        inc d
        jr .octaves
.inOctave:
        ld e,a
        call NotePeriod
        push de
        ld a,(ix+VoiceLength)
        call FramesOf
        pop de
        jr .emit
.restN:
        ld a,(ix+VoiceLength)
        call FramesOf
        ld de,$0000
        jr .emit

NoteSemitones:                          ; A B C D E F G
        db 9, 11, 0, 2, 4, 5, 7

; MmlNumber: the digits at HL (B characters left). Out: A = their value (0 when none, at most 255).
MmlNumber:
        ld e,$00
.digit:
        ld a,b
        or a
        jr z,.done
        ld a,(hl)
        sub '0'
        jr c,.done
        cp 10
        jr nc,.done
        ld d,a
        ld a,e
        add a,a
        add a,a
        add a,e
        add a,a                         ; * 10
        add a,d
        ld e,a
        inc hl
        dec b
        jr .digit
.done:
        ld a,e
        ret

; NoteFrames: the length written after a note (or the voice's L) and its dots, in frames.
NoteFrames:
        call MmlNumber
        or a
        jr nz,.given
        ld a,(ix+VoiceLength)
.given:
        call FramesOf
        ld e,a                          ; dots: + half each time
        ld d,a
.dot:
        ld a,b
        or a
        jr z,.dotsDone
        ld a,(hl)
        cp '.'
        jr nz,.dotsDone
        inc hl
        dec b
        srl d
        ld a,e
        add a,d
        ld e,a
        jr .dot
.dotsDone:
        ld a,e
        ret

; FramesOf: the frames of a note of length A at the voice's tempo: 12000 / (length * tempo) at 50 Hz.
FramesOf:
        push hl
        push bc
        ld c,(ix+VoiceTempo)
        ld b,$00
        ld l,a
        ld h,$00
        push de
        ex de,hl
        call UnsignedMultiplyChecked    ; DE = length * tempo
        ld hl,12000
        ld c,$00                        ; (a division by subtraction: the quotient is small)
.divide:
        or a
        sbc hl,de
        jr c,.divided
        inc c
        jr .divide
.divided:
        ld a,c
        or a
        jr nz,.notZero
        inc a                           ; at least one frame
.notZero:
        pop de
        pop bc
        pop hl
        ret

; NotePeriod: the PSG period of semitone E (may be -1 or 12) in octave D. Out: DE. Keeps the others.
NotePeriod:
        push hl
        push bc
        ld a,e
        bit 7,a
        jr z,.notBelow
        add a,12                        ; C flat: B of the octave below
        dec d
.notBelow:
        cp 12
        jr c,.inRange
        sub 12                          ; B sharp: C above
        inc d
.inRange:
        add a,a
        ld e,a
        push de
        ld d,$00
        ld hl,OctaveOnePeriods
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop bc                          ; B = octave
        ex de,hl
.shift:
        dec b
        jr z,.shifted
        jp m,.shifted                   ; (octave 0: as octave 1)
        srl h
        rr l
        jr .shift
.shifted:
        ex de,hl
        pop bc
        pop hl
        ret

OctaveOnePeriods:                       ; 111861 / frequency, octave 1 (A = 55 Hz)
        dw 3421, 3229, 3047, 2876, 2715, 2562, 2419, 2283, 2155, 2034, 1920, 1812

; QueueEvent: the event (period DE, the voice's volume, A frames) into voice C's queue; waits while it
; is full. Keeps BC, HL.
QueueEvent:
        push hl
        push af
.wait:
        call QueueEntry                 ; HL = QUETAB entry
        ld a,(hl)                       ; put + 4 = get: full
        add a,4
        and $7F
        inc hl
        cp (hl)
        dec hl
        jr nz,.room
        ei
        halt
        ld a,(INTFLG)                   ; CTRL+STOP breaks the wait
        cp $03
        jp z,CheckBreak
        jr .wait
.room:
        push de
        ld a,(hl)                       ; the place: queue + put
        push hl
        call QueueAddress
        pop hl
        pop de
        ld (iy+0),e
        ld (iy+1),d
        ld a,d
        or e
        ld a,(ix+VoiceVolume)
        jr nz,.sound
        xor a                           ; a rest: silent
.sound:
        ld (iy+2),a
        pop af
        ld (iy+3),a
        di                              ; put moves on (the interrupt reads it)
        ld a,(hl)
        add a,4
        and $7F
        ld (hl),a
        ld a,MusicSignature
        ld (PLYCNT),a
        ld a,$01
        ld (MUSICF),a                   ; the interrupt plays
        ei
        pop hl
        ret

; OperandPlay: PLAY(n): -1 while voice n (1-3; 0: any) still has music, else 0.
OperandPlay:
        call ParenInteger
        push hl
        ld a,e
        ld c,$00
        ld b,$03
        or a
        jr z,.check
        cp 4
        jp nc,IllegalFunction
        dec a
        ld c,a
        ld b,$01
.check:
        push bc
        call QueueEntry
        ld a,(hl)
        inc hl
        cp (hl)
        jr nz,.busy
        call FramesLeft
        ld a,(hl)
        or a
        jr nz,.busy
        pop bc
        inc c
        djnz .check
        ld de,$0000
        jr .result
.busy:
        pop bc
        ld de,$FFFF
.result:
        pop hl
        jp SetIntegerResult
