; TDAPE -- position-independent BASIC USR helper for FujiNet APETime.
;
; status=USR(address,buffer) writes day,month,year,hour,minute,second to
; the six-byte buffer. The helper preserves the complete OS DCB on the CPU
; stack so it cannot disturb REMMS or the next DOS operation.

        org $0000

FR0     = $00D4
ARGLO   = $00D6
ARGHI   = $00D7
DCB     = $0300
SIOV    = $E459

        pla                     ; argument count (one by contract)
        pla
        sta ARGHI
        pla
        sta ARGLO

        ldy #0
save_dcb
        lda DCB,y
        pha
        iny
        cpy #16
        bne save_dcb

        lda #$45                ; FujiNet clock device
        sta DCB
        lda #1
        sta DCB+1
        lda #$93                ; APETime GETTIME
        sta DCB+2
        lda #$40                ; SIO read
        sta DCB+3
        lda ARGLO
        sta DCB+4
        lda ARGHI
        sta DCB+5
        lda #$02                ; short absent-device timeout (about two seconds)
        sta DCB+6
        lda #0
        sta DCB+7
        lda #6
        sta DCB+8
        lda #0
        sta DCB+9
        sta DCB+10
        sta DCB+11
        jsr SIOV
        sty FR0

        ldy #15
restore_dcb
        pla
        sta DCB,y
        dey
        bpl restore_dcb
        lda #0
        sta FR0+1
        rts

