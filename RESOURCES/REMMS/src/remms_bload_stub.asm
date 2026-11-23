; Relocatable BASIC string helper for non-display block reads.
; count=USR(ADR(BL$),iocb,address,length); callers use IOCB #1.

ICCOM  = $0342
ICBAL  = $0344
ICBAH  = $0345
ICBLL  = $0348
ICBLH  = $0349
ICBLLZ = $0028
FR0    = $00D4
CIOV   = $E456

        org $0000
remms_bload_stub
        cld
        pla
        pla
        pla
        ldx #$10
        pla
        sta ICBAH,x
        pla
        sta ICBAL,x
        pla
        sta ICBLH,x
        pla
        sta ICBLL,x
        lda ICBLL,x
        sta FR0
        lda ICBLH,x
        sta FR0+1
        lda #7
        sta ICCOM,x
        jsr CIOV
        tya
        bpl remms_bload_done
        lda ICBLLZ
        sta FR0
        lda ICBLLZ+1
        sta FR0+1
remms_bload_done
        rts
remms_bload_stub_end
        run remms_bload_stub
