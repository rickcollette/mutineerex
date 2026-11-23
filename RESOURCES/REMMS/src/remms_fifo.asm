; ---------------------------------------------------------------------------
; Translated input FIFO
; ---------------------------------------------------------------------------

; Pager polling reads R: before RTGET does. Non-pager bytes are translated once
; and held here so pager controls never require a second BASIC-side buffer.
remms_fifo_get
        lda remms_fifo_count
        beq remms_fifo_get_empty
        ldx remms_fifo_head
        lda remms_fifo_buffer,x
        pha
        inx
        cpx #64
        bcc remms_fifo_get_head_ready
        ldx #0
remms_fifo_get_head_ready
        stx remms_fifo_head
        dec remms_fifo_count
        pla
        clc
        rts
remms_fifo_get_empty
        sec
        rts

; The FIFO contains raw transport bytes. Translation and filtering occur only
; when a text consumer removes a byte. Pager consumers can therefore inspect
; controls without corrupting later RTGET input.
remms_fifo_put
        pha
        lda remms_fifo_count
        cmp #REMMS_FIFO_WATERMARK
        bcs remms_fifo_put_full
        bcc remms_fifo_put_store
remms_fifo_put_reserved
        pha
        lda remms_fifo_count
        cmp #64
        bcs remms_fifo_put_full
remms_fifo_put_store
        ldx remms_fifo_tail
        pla
        sta remms_fifo_buffer,x
        inx
        cpx #64
        bcc remms_fifo_put_tail_ready
        ldx #0
remms_fifo_put_tail_ready
        stx remms_fifo_tail
        inc remms_fifo_count
        clc
        rts
remms_fifo_put_full
        pla
        lda #1
        sta remms_session_block+REMMS_S_FIFO_OVERFLOW
        sec
        rts

; Shared resident helpers. Each replaces a repeated inline sequence and
; leaves A, X and flags exactly as the inline code did.

; A = CIO command, X = IOCB. Clears the buffer length; returns A=0.
remms_iocb_command_no_buffer
        sta ICCOM,x
        lda #0
        sta ICBLL,x
        sta ICBLH,x
        rts

remms_set_local_route
        lda #REMMS_MODE_LOCAL
        sta remms_mode
        lda #REMMS_ROUTE_LOCAL
        sta remms_route
        rts

remms_mark_physical_closed
        lda #REMMS_CONFIG_NONE
        jsr remms_set_config_profile
        lda #REMMS_PHYS_CLOSED
        jmp remms_set_physical_state
