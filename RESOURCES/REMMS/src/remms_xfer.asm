; ---------------------------------------------------------------------------
; Native external-transfer service table
; ---------------------------------------------------------------------------

remms_xfer_native_table
REMMS_XFER_CLAIM
        jmp remms_xfer_claim_impl
REMMS_XFER_RELEASE
        jmp remms_xfer_release_impl
REMMS_XFER_GET_BYTE
        jmp remms_xfer_get_byte_impl
REMMS_XFER_PUT_BYTE
        jmp remms_xfer_put_byte_impl
REMMS_XFER_GET_STATUS
        jmp remms_xfer_get_status_impl
REMMS_XFER_PUMP_EVENTS
        jmp remms_xfer_pump_events_impl
REMMS_XFER_SET_PHASE
        jmp remms_xfer_set_phase_impl
REMMS_XFER_SET_ERROR
        jmp remms_xfer_set_error_impl
REMMS_XFER_ADD_BYTES
        jmp remms_xfer_add_bytes_impl
REMMS_XFER_CHECK_CANCEL
        jmp remms_xfer_check_cancel_impl
REMMS_XFER_FLUSH_INPUT
        jmp remms_xfer_flush_input_impl
REMMS_XFER_FLUSH_OUTPUT
        jmp remms_xfer_flush_output_impl
REMMS_XFER_BEGIN_BINARY
        jmp remms_xfer_begin_binary_impl
REMMS_XFER_END_BINARY
        jmp remms_xfer_end_binary_impl

remms_xfer_claim_impl
        lda remms_session_block+REMMS_XFR_SIGNATURE+0
        cmp #'X'
        bne remms_xfer_bad_request
        lda remms_session_block+REMMS_XFR_SIGNATURE+1
        cmp #'F'
        bne remms_xfer_bad_request
        lda remms_session_block+REMMS_XFR_SIGNATURE+2
        cmp #'R'
        bne remms_xfer_bad_request
        lda remms_session_block+REMMS_XFR_SIGNATURE+3
        cmp #'1'
        bne remms_xfer_bad_request
        lda remms_session_block+REMMS_XFR_VERSION
        cmp #REMMS_XFR_STRUCT_VERSION
        bne remms_xfer_bad_request
        lda #REMMS_XFR_STATE_INITIALIZING
        sta remms_session_block+REMMS_XFR_STATE
        lda #REMMS_XFR_RESULT_OK
        sta remms_session_block+REMMS_XFR_RESULT_CLASS
        sta remms_session_block+REMMS_XFR_RESULT_DETAIL
        sta remms_session_block+REMMS_XFR_DOS_STATUS
        clc
        rts

remms_xfer_bad_request
        lda #REMMS_XFR_RESULT_BAD_REQUEST
        sta remms_session_block+REMMS_XFR_RESULT_CLASS
        lda #REMMS_XFR_STATE_FAILED
        sta remms_session_block+REMMS_XFR_STATE
        sec
        rts

remms_xfer_release_impl
        lda #REMMS_XFR_STATE_IDLE
        sta remms_session_block+REMMS_XFR_STATE
        clc
        rts

remms_xfer_put_byte_impl
        jsr remms_r_put_try
        bcs remms_xfer_put_fail
        rts
remms_xfer_put_fail
        lda remms_last_status
        sta remms_session_block+REMMS_XFR_RESULT_DETAIL
        lda #REMMS_XFR_RESULT_IO
        sta remms_session_block+REMMS_XFR_RESULT_CLASS
        sec
        rts

remms_xfer_get_status_impl
        jmp remms_status_impl

remms_xfer_pump_events_impl
        jmp remms_event_poll

remms_xfer_set_phase_impl
        sta remms_session_block+REMMS_XFR_STATE
        clc
        rts

remms_xfer_set_error_impl
        sta remms_session_block+REMMS_XFR_RESULT_CLASS
        sty remms_session_block+REMMS_XFR_RESULT_DETAIL
        stx remms_session_block+REMMS_XFR_DOS_STATUS
        lda #REMMS_XFR_STATE_FAILED
        sta remms_session_block+REMMS_XFR_STATE
        clc
        rts

remms_xfer_add_bytes_impl
        clc
        adc remms_session_block+REMMS_XFR_BYTES+0
        sta remms_session_block+REMMS_XFR_BYTES+0
        lda remms_session_block+REMMS_XFR_BYTES+1
        adc #0
        sta remms_session_block+REMMS_XFR_BYTES+1
        lda remms_session_block+REMMS_XFR_BYTES+2
        adc #0
        sta remms_session_block+REMMS_XFR_BYTES+2
        lda remms_session_block+REMMS_XFR_BYTES+3
        adc #0
        sta remms_session_block+REMMS_XFR_BYTES+3
        clc
        rts

remms_xfer_check_cancel_impl
        lda CH
        cmp #REMMS_LOCAL_KEY_ABORT
        beq remms_xfer_cancel_ready
        cmp #$03
        beq remms_xfer_cancel_ready
        clc
        rts
remms_xfer_cancel_ready
        lda #REMMS_XFR_STATE_CANCELED_LOCAL
        sta remms_session_block+REMMS_XFR_STATE
        sec
        rts

remms_xfer_flush_input_impl
        jsr remms_raw_get_try
        bcc remms_xfer_flush_input_impl
        clc
        rts

remms_xfer_begin_binary_impl
        lda #REMMS_TEXT_NONE
        sta remms_session_block+REMMS_S_TEXT_MODE
        sta remms_session_block+REMMS_S_TEXT_STATE
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        lda #REMMS_XFR_STATE_NEGOTIATING
        sta remms_session_block+REMMS_XFR_STATE
        clc
        rts

remms_xfer_end_binary_impl
        lda #REMMS_TEXT_NONE
        sta remms_session_block+REMMS_S_TEXT_MODE
        lda remms_session_block+REMMS_XFR_RESULT_CLASS
        bne remms_xfer_end_binary_done
        lda #REMMS_XFR_STATE_COMPLETED
        sta remms_session_block+REMMS_XFR_STATE
remms_xfer_flush_output_impl
remms_xfer_end_binary_done
        clc
        rts
