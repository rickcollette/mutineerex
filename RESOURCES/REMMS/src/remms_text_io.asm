remms_get_impl
; Authoritative raw dequeue. Connected carrier state is sensed before any
; queued or physical byte is exposed. FIFO bytes always precede later physical
; bytes, and no translation, filtering, echo, or string matching occurs here.
remms_raw_get_try
remms_raw_get_restart
        jsr remms_connected_carrier_check
        bcs remms_raw_get_none
        jsr remms_fifo_get
        bcc remms_raw_get_ready
        jsr remms_remote_ready_no_carrier
        beq remms_raw_get_none
        ; The status poll may have run the carrier probe, which queues the
        ; oldest physical byte. Serve the FIFO before reading past it.
        lda remms_fifo_count
        bne remms_raw_get_restart
        jsr remms_r_get_raw
        bcs remms_raw_get_none
        jsr remms_raw_accept_byte
        bcs remms_raw_get_restart
remms_raw_get_ready
        clc
        rts
remms_raw_get_none
        sec
        rts

; Translated text input is deliberately separate from raw GET. Terminal
; detection and binary transfer callers continue to use remms_get_impl.
remms_text_get_impl
remms_text_get_try
        lda remms_mode
        beq remms_text_get_local
remms_text_get_restart
        jsr remms_raw_get_try
        bcs remms_text_get_filtered
        sta remms_io_byte
        jsr remms_text_process_remote
        bcs remms_text_get_restart
        clc
        rts
remms_text_get_local
remms_text_get_local_keyboard
        lda CH
        cmp #$FF
        beq remms_text_get_filtered
        jsr remms_keyboard_get_atascii
        bcs remms_text_get_filtered
        sta remms_io_byte
        jmp remms_text_process_source_canonical

remms_text_process_remote
        ; Accept a telnet CR as text EOL in both ASCII and ATASCII modes. Also
        ; consume an optional LF/NUL after either CR or native ATASCII EOL so
        ; a transport-added suffix cannot leak into the next BASIC field.
        lda remms_text_after_cr
        beq remms_text_get_ascii_byte
        lda #0
        sta remms_text_after_cr
        lda remms_io_byte
        cmp #10
        beq remms_text_get_filtered
        cmp #0
        beq remms_text_get_filtered
remms_text_get_ascii_byte
        lda remms_io_byte
        cmp #13
        bne remms_text_get_no_crlf
        lda #1
        sta remms_text_after_cr
        lda #EOL
        sta remms_io_byte
        jmp remms_text_process_source_canonical

remms_text_get_no_crlf
        jsr remms_translate_input
        sta remms_io_byte
        jmp remms_text_process_source_canonical
remms_text_get_filtered
        sec
        rts

; MOE NEGTRAN semantics. The source table contained the historical duplicate
; $7D bell bug; the corrected BEL entry is ATASCII $FD.
remms_translate_input
        lda remms_session_block+REMMS_S_AMODE
        bne remms_translate_input_raw
        lda remms_io_byte
        cmp #32
        bcs remms_translate_input_done
        tax
        lda remms_input_translation,x
        rts
remms_translate_input_raw
        lda remms_io_byte
remms_translate_input_done
        rts

; Source adapters feed this one canonical policy. Remote ASCII has already
; been translated, remote ATASCII and local K: are already canonical.
remms_text_process_source_canonical
        lda remms_io_byte
        cmp #$13
        beq remms_text_get_filtered
        cmp #$03
        beq remms_text_get_filtered

; Canonical text editing and echo policy. BASIC owns only its field buffer.
; REMMS owns filtering, CR coalescing, accepted-byte echo, masking, and choice
; EOL consumption for both local and remote input.
remms_text_process_canonical
        lda remms_session_block+REMMS_S_TEXT_MODE
        cmp #REMMS_TEXT_EDITOR
        beq remms_text_editor_byte
        lda remms_io_byte
        cmp #$18
        beq remms_text_return_no_echo
        cmp #EOL
        bne remms_text_check_backspace
        jmp remms_text_canonical_eol
remms_text_check_backspace
        cmp #$7E
        bne remms_text_check_tab
        jmp remms_text_canonical_backspace
remms_text_check_tab
        cmp #$7F
        bne remms_text_check_zero
        jmp remms_text_canonical_tab
remms_text_check_zero
        cmp #0
        beq remms_text_canonical_filtered
        cmp #$7D
        beq remms_text_canonical_filtered
        cmp #28
        bcc remms_text_canonical_printable
        cmp #32
        bcc remms_text_canonical_filtered
        cmp #156
        bcc remms_text_canonical_printable
        cmp #160
        bcc remms_text_canonical_filtered
        cmp #253
        bcs remms_text_canonical_filtered
remms_text_canonical_printable
        lda remms_session_block+REMMS_S_TEXT_MODE
        cmp #REMMS_TEXT_CHOICE
        beq remms_text_choice_byte
        cmp #REMMS_TEXT_LINE
        beq remms_text_line_byte
        cmp #REMMS_TEXT_MASKED
        beq remms_text_masked_byte
remms_text_return_no_echo
        lda remms_io_byte
        clc
        rts
remms_text_editor_byte
        lda remms_io_byte
        beq remms_text_canonical_filtered
        clc
        rts
remms_text_canonical_filtered
        sec
        rts
remms_text_line_byte
        lda remms_session_block+REMMS_S_TEXT_STATE
        cmp #REMMS_TEXT_LINE_LIMIT
        bcs remms_text_canonical_filtered
        inc remms_session_block+REMMS_S_TEXT_STATE
        lda remms_io_byte
        jsr remms_text_echo_byte
        bcs remms_text_canonical_filtered
        lda remms_io_byte
        clc
        rts
remms_text_masked_byte
        lda remms_session_block+REMMS_S_TEXT_STATE
        cmp #REMMS_TEXT_MASKED_LIMIT
        bcs remms_text_canonical_filtered
        inc remms_session_block+REMMS_S_TEXT_STATE
        lda remms_io_byte
        pha
        lda #'*'
        jsr remms_text_echo_byte
        pla
        nop
        rts
remms_text_choice_byte
        lda remms_session_block+REMMS_S_TEXT_STATE
        bne remms_text_canonical_filtered
        lda remms_io_byte
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        lda #1
        sta remms_session_block+REMMS_S_TEXT_STATE
        lda remms_io_byte
        jsr remms_text_echo_byte
        sec
        rts
remms_text_canonical_eol
        inc remms_text_after_cr
        lda remms_session_block+REMMS_S_TEXT_MODE
        cmp #REMMS_TEXT_CHOICE
        beq remms_text_choice_eol
        cmp #REMMS_TEXT_LINE
        beq remms_text_line_eol
        cmp #REMMS_TEXT_MASKED
        bne remms_text_return_no_echo
remms_text_line_eol
        lda #EOL
        jsr remms_text_echo_byte
        bcs remms_text_canonical_filtered
        lda #0
        sta remms_session_block+REMMS_S_TEXT_STATE
        lda #EOL
        clc
        rts
remms_text_choice_eol
        lda remms_session_block+REMMS_S_TEXT_STATE
        beq remms_text_canonical_filtered
        lda #EOL
        jsr remms_text_echo_byte
        bcs remms_text_canonical_filtered
        lda #0
        sta remms_session_block+REMMS_S_TEXT_STATE
        lda remms_session_block+REMMS_S_TEXT_CHOICE
        pha
        lda #0
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        pla
        clc
        rts
remms_text_canonical_backspace
        lda remms_session_block+REMMS_S_TEXT_MODE
        cmp #REMMS_TEXT_LINE
        beq remms_text_backspace_edit
        cmp #REMMS_TEXT_MASKED
        beq remms_text_backspace_edit
        jmp remms_text_return_no_echo
remms_text_backspace_edit
        lda remms_session_block+REMMS_S_TEXT_STATE
        beq remms_text_backspace_filtered
        dec remms_session_block+REMMS_S_TEXT_STATE
        lda #$7E
        jsr remms_text_echo_byte
        bcs remms_text_backspace_filtered
        lda #$20
        jsr remms_text_echo_byte
        bcs remms_text_backspace_filtered
        lda #$7E
        jsr remms_text_echo_byte
        bcs remms_text_backspace_filtered
        lda #$7E
        clc
        rts
remms_text_backspace_filtered
        jmp remms_text_canonical_filtered
remms_text_canonical_tab
        lda #$20
        sta remms_io_byte
        jmp remms_text_canonical_printable
remms_text_echo_byte
        jsr remms_output_shared
        bcc remms_text_echo_done
        lda #REMMS_ERR_CIO
        sta remms_last_error
        sec
remms_text_echo_done
        rts
remms_put_impl
        sta remms_io_byte
        lda remms_mode
        beq remms_put_not_open
        lda remms_r_open
        beq remms_put_not_open
        lda remms_io_byte
        jmp remms_r_put_guarded
remms_put_not_open
        lda #REMMS_ERR_NOT_OPEN
        sta remms_last_error
        ldy #CIO_ERR
        sec
        rts

remms_remote_ready_no_carrier
        lda remms_mode
        beq remms_remote_not_ready
        lda remms_r_open
        beq remms_remote_not_ready
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_remote_not_ready_zero
        lda remms_raw_ready
        bne remms_remote_ready_cached
        jsr remms_r_status
        tya
        bmi remms_remote_not_ready
        lda #REMMS_ERR_NONE
        sta remms_last_error
remms_remote_ready_cached
        lda remms_raw_ready
        rts
remms_remote_not_ready
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_remote_not_ready_zero
        jsr remms_fail_cio
remms_remote_not_ready_zero
        lda #0
        rts

; Fast ownership guard. Physical CRX validation is performed by
; remms_connected_carrier_sense when the handler input reaches the small
; modem-result tail. It uses the tracked non-hangup suspend/reopen path because
; the 850 cannot accept an SIO command while its concurrent stream is active.
remms_connected_carrier_check
        lda remms_r_open
        beq remms_connected_stream_fail
        lda remms_public_physical_state
        cmp #REMMS_PHYS_OPEN
        bne remms_connected_stream_fail
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_CONNECTED
        beq remms_connected_stream_ok
        cmp #REMMS_CONFIG_WAIT_CALL
        bne remms_connected_stream_fail
remms_connected_stream_ok
        clc
        rts
remms_connected_stream_fail
        sec
        rts

; Burst-drain pending connected bytes into the bounded FIFO in order. A leading
; ASCII CR is modem-result framing and requests carrier validation; no printable
; result text is matched or discarded. The status snapshot settles for one frame
; before this routine, so a complete input line/result is owned before any
; tracked reopen. Confirm out of band by restarting connected mode with XIO 36
; CRX monitoring enabled. A real drop is confirmed by monitored XIO 40 failure.
; Binary XFER bypasses this path in remms_r_status.
remms_connected_carrier_sense
        lda remms_r_caps
        and #REMMS_R_CAP_CARRIER
        bne remms_carrier_sense_physical
        ldy #CIO_SUCC
        clc
        rts
remms_carrier_sense_physical
        lda #REMMS_OP_CARRIER_STATUS
        jsr remms_begin_operation
        jsr remms_fault_check
        bcs remms_carrier_sense_fault
        lda remms_raw_ready
        sta remms_host_poll_count
        ;##TRACE "REMMS carrier probe ready=%u" db(REMMS_RAW_READY)
        jsr remms_r_get_raw
        bcs remms_carrier_sense_io
        lda remms_cio_chr
        sta remms_filter_byte
        lda remms_cio_chr
        jsr remms_fifo_put
        bcs remms_carrier_sense_overflow
        dec remms_host_poll_count
        bne remms_carrier_sense_live_data
remms_carrier_sense_candidate
        lda remms_filter_byte
        cmp #13
        bne remms_carrier_sense_live_data
        ;##TRACE "REMMS carrier probe candidate"
        jsr remms_suspend_impl
        bcs remms_carrier_sense_io
        jsr remms_open_connected
        bcs remms_carrier_sense_reopen
remms_carrier_sense_live_data
        ldy #CIO_SUCC
        clc
        rts
remms_carrier_sense_fault
        jsr remms_record_cio_status
remms_carrier_sense_io
        jsr remms_fail_cio
        sec
        rts
remms_carrier_sense_reopen
        ;##TRACE "REMMS carrier reopen op=%u private=$%02X public=$%02X" db(REMMS_SESSION_BLOCK+REMMS_S_LAST_OPERATION) db(REMMS_LAST_STATUS) db(REMMS_PUBLIC_CIO_STATUS)
        lda remms_session_block+REMMS_S_LAST_OPERATION
        cmp #REMMS_OP_XIO40
        bne remms_carrier_sense_io
        ; remms_open_fail_close preserves the failed XIO status in the public
        ; lifecycle record after its cleanup CLOSE. Use that authoritative
        ; value; the private scratch can hold the cleanup result here.
        lda remms_public_cio_status
        cmp #$8B
        bne remms_carrier_sense_io
        jsr remms_mark_carrier_lost
        sec
        rts
remms_carrier_sense_overflow
        lda #REMMS_ERR_FIFO_OVERFLOW
        sta remms_last_error
        lda #REMMS_EXIT_FATAL
        jsr remms_failure_handoff
        sec
        rts

remms_r_get_raw
        ldx #REMMS_R_IOCB
        lda #CIO_GETCHR
        jsr remms_iocb_command_no_buffer
        lda #REMMS_OP_GET
        jsr remms_begin_operation
        lda #CIO_GETCHR
        jsr remms_ciov_preserve_dcb
        sta remms_cio_chr
        jsr remms_record_cio_status
        tya
        bmi remms_r_get_raw_fail
        lda remms_raw_ready
        beq remms_r_get_raw_value
        dec remms_raw_ready
remms_r_get_raw_value
        lda #REMMS_ERR_NONE
        sta remms_last_error
        lda remms_cio_chr
        clc
        rts
remms_r_get_raw_fail
        lda #0
        sta INBUFF
        jsr remms_fail_cio
        sec
        rts

remms_r_status
        ldx #REMMS_R_IOCB
        lda #CIO_STATUS
        jsr remms_iocb_command_no_buffer
        lda #REMMS_OP_STATUS
        jsr remms_begin_operation
        lda #CIO_STATUS
        jsr remms_ciov_preserve_dcb
        jsr remms_record_cio_status
        tya
        bmi remms_r_status_done
        lda INBUFF
        sta remms_raw_ready
        lda OUTBUFF
        sta remms_output_pending
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_CONNECTED
        bne remms_r_status_done
        lda remms_session_block+REMMS_S_XFER_PHASE
        bne remms_r_status_done
        lda remms_raw_ready
        beq remms_r_status_done
        lda remms_fifo_count
        cmp #REMMS_FIFO_WATERMARK
        bcs remms_r_status_done
        jsr remms_connected_carrier_sense
        bcc remms_r_status_done
        ldy #CIO_ERR
remms_r_status_done
        rts
