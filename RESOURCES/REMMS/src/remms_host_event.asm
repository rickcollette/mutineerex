remms_host_reset
        lda #0
        sta remms_ring_match
        sta remms_connect_match
        sta remms_connect_seen
        sta remms_session_block+REMMS_S_RING_COUNT
        sta remms_nc_match
        sta remms_connect_skip_lf
        rts

remms_host_status_impl
        ; Printable modem-result parsing is legal only before CONNECT.
        ; State 0 is local; states 4+ are connected or terminal outcomes.
        lda remms_session_block+REMMS_S_CONNECTION_STATE
        beq remms_host_status_waiting
        cmp #REMMS_CONN_CONNECTED
        bcs remms_host_status_waiting
        lda #32
        sta remms_host_poll_count
remms_host_status_loop
        jsr remms_r_status
        tya
        bmi remms_host_status_fail
        lda remms_raw_ready
        beq remms_host_status_waiting
        jsr remms_r_get_raw
        bcs remms_host_status_error
        lda remms_cio_chr
        jsr remms_host_process_byte
        bcs remms_host_connected
        dec remms_host_poll_count
        bne remms_host_status_loop
remms_host_status_waiting
        lda #0
        clc
        rts
remms_host_connected
        lda remms_last_error
        bne remms_host_status_error
        ; Own every byte already behind CONNECT before closing the selector-15
        ; stream. The subsequent selector-14 reopen must not strand caller
        ; input that arrived in the same status snapshot.
        jsr remms_remote_burst
        bcs remms_host_status_error
        jsr remms_reopen_connected_stream
        bcs remms_host_status_error
        lda #1
        clc
        rts
remms_host_status_fail
        jsr remms_fail_cio
remms_host_status_error
        lda #0
        sec
        rts

remms_host_process_byte
        and #$7F
        cmp #'a'
        bcc remms_host_upper_done
        cmp #'z'+1
        bcs remms_host_upper_done
        and #$DF
remms_host_upper_done
        sta remms_filter_byte
        lda remms_connect_seen
        beq remms_host_check_nc
        lda remms_filter_byte
        cmp #13
        beq remms_host_set_connected
        cmp #10
        beq remms_host_set_connected
        cmp #EOL
        beq remms_host_set_connected
        clc
        rts
remms_host_set_connected
        lda #0
        sta remms_connect_skip_lf
        lda remms_filter_byte
        cmp #13
        bne remms_host_connected_terminator_ready
        inc remms_connect_skip_lf
remms_host_connected_terminator_ready
        lda #1
        sta remms_session_block+REMMS_S_ONLINE
        lda #REMMS_CONN_CONNECTED
        jsr remms_set_connection_state
        jsr remms_apply_snoop_route
        sec
        rts

; CONNECT owns its complete modem-result terminator. Capture bytes already
; behind it in the concurrent buffer into the raw FIFO, dropping only the LF
; half of a CRLF CONNECT terminator. Caller data remains byte-exact.
remms_host_check_nc
        ldx remms_nc_match
        lda remms_filter_byte
        cmp remms_nc_text,x
        beq remms_host_nc_advance
        cmp remms_nc_text
        beq remms_host_nc_restart
        lda #0
        sta remms_nc_match
        jmp remms_host_check_connect
remms_host_nc_restart
        lda #1
        sta remms_nc_match
        jmp remms_host_check_connect
remms_host_nc_advance
        inx
        cpx #10
        beq remms_host_no_carrier
        stx remms_nc_match
        jmp remms_host_check_connect
remms_host_no_carrier
        jsr remms_host_reset
        clc
        rts
remms_host_check_connect
        ldx remms_connect_match
        lda remms_filter_byte
        cmp remms_connect_text,x
        beq remms_host_connect_advance
        cmp remms_connect_text
        beq remms_host_connect_restart
        lda #0
        sta remms_connect_match
        jmp remms_host_check_ring
remms_host_connect_restart
        lda #1
        sta remms_connect_match
        jmp remms_host_check_ring
remms_host_connect_advance
        inx
        cpx #7
        beq remms_host_connect_seen
        stx remms_connect_match
        jmp remms_host_check_ring
remms_host_connect_seen
        lda #0
        sta remms_connect_match
        lda #1
        sta remms_connect_seen
        clc
        rts
remms_host_check_ring
        ldx remms_ring_match
        lda remms_filter_byte
        cmp remms_ring_text,x
        beq remms_host_ring_advance
        cmp remms_ring_text
        beq remms_host_ring_restart
        lda #0
        sta remms_ring_match
        clc
        rts
remms_host_ring_restart
        lda #1
        sta remms_ring_match
        clc
        rts
remms_host_ring_advance
        inx
        cpx #4
        beq remms_host_ring_seen
        stx remms_ring_match
        clc
        rts
remms_host_ring_seen
        lda #0
        sta remms_ring_match
        jsr remms_host_ring_started
        clc
        rts

remms_host_ring_started
        lda #REMMS_CONN_RINGING
        jsr remms_set_connection_state
        lda remms_session_block+REMMS_S_RING_COUNT
        cmp #9
        bcs remms_host_ring_count_ok
        clc
        adc #1
        sta remms_session_block+REMMS_S_RING_COUNT
remms_host_ring_count_ok
        lda remms_session_block+REMMS_S_RING_COUNT
        cmp remms_session_block+REMMS_S_ANSWER_RINGS
        bcc remms_host_ring_done
        ; A prior ATA without CONNECT is not success. Retry once per later
        ; RING so a dropped/ignored command cannot strand WFC indefinitely.
        jsr remms_answer_call
remms_host_ring_done
        rts

remms_answer_call
        lda #REMMS_CONN_ANSWERING
        jsr remms_set_connection_state
        lda #0
        sta remms_clear_index
remms_answer_call_loop
        ldx remms_clear_index
        lda remms_answer_command,x
        jsr remms_r_put_guarded
        bcs remms_answer_call_fail
        inc remms_clear_index
        lda remms_clear_index
        cmp #4
        bcc remms_answer_call_loop
        clc
        rts
remms_answer_call_fail
        ; Guarded output already recorded and reconciled the failure.
        sec
        rts

remms_r_put_try
        sta remms_io_byte
        ldx #REMMS_R_IOCB
        lda #REMMS_OP_PUT
        jsr remms_begin_operation
        jsr remms_fault_check
        bcs remms_r_put_record
        lda #CIO_PUTCHR
        jsr remms_iocb_command_no_buffer
        lda remms_io_byte
        jsr remms_ciov_preserve_dcb
remms_r_put_record
        jsr remms_record_cio_status
        tya
        bmi remms_r_put_fail
        lda #REMMS_ERR_NONE
        sta remms_last_error
        lda remms_io_byte
        clc
        rts
remms_r_put_fail
        ; During pre-concurrent OPEN, lifecycle cleanup owns the failure.
        ; Connected output uses the authoritative resident failure handoff.
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        beq remms_r_put_fail_return
        jsr remms_fail_cio
remms_r_put_fail_return
        sec
        rts

remms_r_put_guarded
        sta remms_io_byte
        lda #16
        sta remms_output_poll_count
remms_r_put_guarded_wait
        jsr remms_r_output_ready
        bcc remms_r_put_guarded_send
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_r_put_fail
        dec remms_output_poll_count
        bne remms_r_put_guarded_wait
        lda #REMMS_ERR_TIMEOUT
        sta remms_last_error
        lda #REMMS_EXIT_TIMEOUT
        jsr remms_failure_handoff
        sec
        rts
remms_r_put_guarded_send
        lda remms_io_byte
        jsr remms_r_put_try
        bcc remms_r_put_guarded_done
        bcs remms_r_put_fail
remms_r_put_guarded_done
        rts

remms_r_output_ready
        jsr remms_connected_carrier_check
        bcs remms_r_output_fail
        jsr remms_r_status
        tya
        bmi remms_r_output_fail
        lda remms_output_pending
        cmp #100
        bcc remms_r_output_ok
        sec
        rts
remms_r_output_ok
        clc
        rts
remms_r_output_fail
        sec
        rts

remms_mark_carrier_lost
        lda #REMMS_ERR_CARRIER_LOST
        sta remms_last_error
        lda #REMMS_EXIT_CARRIER
        jmp remms_failure_handoff

; One synchronous foreground event pass. There is deliberately no VBI or
; interrupt poller: BASIC and the E:/K: wrappers call this owner explicitly.
remms_event_poll
        lda remms_failure_pending
        beq remms_event_poll_begin
        lda #0
        sta remms_failure_pending
        rts
remms_event_poll_begin
        lda #REMMS_EVENT_NONE
        sta remms_session_block+REMMS_S_EVENT_KIND
        lda #0
        sta remms_session_block+REMMS_S_EVENT_VALUE
        jsr remms_console_impl
        beq remms_event_poll_modem
        tax
        lda #REMMS_EVENT_CONSOLE
        jmp remms_event_record
remms_event_poll_modem
        lda remms_session_block+REMMS_S_CONNECTION_STATE
        sta remms_event_previous_connection
        lda remms_mode
        beq remms_event_poll_local_text
        jsr remms_status_impl
        bcs remms_event_poll_error
        lda remms_session_block+REMMS_S_CONNECTION_STATE
        cmp remms_event_previous_connection
        beq remms_event_poll_remote_text
        tax
        lda #REMMS_EVENT_CALL_STATE
        jmp remms_event_record
remms_event_poll_remote_text
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_event_poll_done
        lda remms_session_block+REMMS_S_TEXT_MODE
        bne remms_event_poll_drain_text
        lda remms_raw_ready
        sta remms_session_block+REMMS_S_EVENT_VALUE
        rts
remms_event_poll_drain_text
        jsr remms_remote_burst
        bcs remms_event_poll_error
        bcc remms_event_poll_text
remms_event_poll_local_text
        lda remms_session_block+REMMS_S_TEXT_MODE
        beq remms_event_poll_done
remms_event_poll_text
        lda #REMMS_ERR_NONE
        sta remms_last_error
        jsr remms_text_get_impl
        bcs remms_event_poll_no_text
        tax
        lda #REMMS_EVENT_TEXT
        jmp remms_event_record
remms_event_poll_no_text
        lda remms_last_error
        beq remms_event_poll_done
        cmp #REMMS_ERR_NONE
        beq remms_event_poll_done
        cmp #REMMS_ERR_CIO
        beq remms_event_poll_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_event_poll_error
        cmp #REMMS_ERR_FIFO_OVERFLOW
        beq remms_event_poll_error
        bne remms_event_poll_done
remms_event_poll_error
        lda remms_last_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_event_poll_carrier
        cmp #REMMS_ERR_FIFO_OVERFLOW
        beq remms_event_poll_recoverable
        tax
        lda #REMMS_EVENT_FATAL
        jmp remms_event_record
remms_event_poll_recoverable
        tax
        lda #REMMS_EVENT_RECOVERABLE
        jmp remms_event_record
remms_event_poll_carrier
        tax
        lda #REMMS_EVENT_CARRIER
remms_event_record
        sta remms_session_block+REMMS_S_EVENT_KIND
        txa
        sta remms_session_block+REMMS_S_EVENT_VALUE
remms_event_sequence_advance
        inc remms_session_block+REMMS_S_EVENT_SEQ_LO
        bne remms_event_seq_done
        inc remms_session_block+REMMS_S_EVENT_SEQ_HI
remms_event_seq_done
        lda remms_session_block+REMMS_S_EVENT_SEQ_LO
        sta remms_public_event_seq_lo
        lda remms_session_block+REMMS_S_EVENT_SEQ_HI
        sta remms_public_event_seq_hi
remms_event_poll_done
        rts

; Drain one modem-status snapshot into the sole 64-byte raw FIFO. Ordinary
; text stops at the 60-byte watermark. The last four slots are reserved for
; pager controls. A near-full 128-byte R: queue is rejected as one unit before
; the handler can silently lose bytes.
remms_remote_burst
        lda remms_raw_ready
        sta remms_host_poll_count
        beq remms_remote_burst_done
        cmp #REMMS_R_INPUT_LIMIT
        bcs remms_remote_burst_input_overflow
remms_remote_burst_loop
        lda remms_fifo_count
        cmp #64
        bcs remms_remote_burst_overflow
        cmp #REMMS_FIFO_WATERMARK
        bcc remms_remote_burst_read_normal
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_ACTIVE
        bcc remms_remote_burst_done
        cmp #REMMS_PAGER_STATE_ABORTED
        bcs remms_remote_burst_done
        jsr remms_r_get_raw
        bcs remms_remote_burst_fail
        jsr remms_raw_queue_byte
        bcs remms_remote_burst_fail
        bcc remms_remote_burst_next
remms_remote_burst_read_normal
        jsr remms_r_get_raw
        bcs remms_remote_burst_fail
        jsr remms_raw_queue_byte
        bcs remms_remote_burst_fail
remms_remote_burst_next
        dec remms_host_poll_count
        bne remms_remote_burst_loop
remms_remote_burst_done
        clc
        rts
remms_remote_burst_overflow
remms_remote_burst_input_overflow
        jsr remms_fifo_reset
        sta remms_session_block+REMMS_S_TEXT_STATE
        jsr remms_suspend_impl
        bcs remms_remote_burst_fail
        jsr remms_open_connected
        bcs remms_remote_burst_fail
        lda #REMMS_ERR_FIFO_OVERFLOW
        sta remms_last_error
        lda #1
        sta remms_session_block+REMMS_S_FIFO_OVERFLOW
remms_remote_burst_fail
        ; Every burst failure already has an authoritative operation/status.
        ; Reuse the carrier classifier: XIO 40/$8B becomes carrier loss and
        ; every other failure follows its normal CIO failure handoff. This
        ; one-byte growth also covers FIFO recovery after a NO CARRIER tail.
        jmp remms_carrier_sense_reopen

; The connected channel has no printable-string parser. Every received byte is
; inserted directly into the one raw FIFO. The pager alone may use its
; reserved four slots.
remms_raw_queue_byte
        jsr remms_raw_accept_byte
        bcs remms_raw_queue_done
        sta remms_raw_input_byte
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_ACTIVE
        bcc remms_raw_queue_normal
        cmp #REMMS_PAGER_STATE_ABORTED
        bcs remms_raw_queue_normal
        lda remms_raw_input_byte
        jsr remms_fifo_put_reserved
        jmp remms_raw_queue_status
remms_raw_queue_normal
        lda remms_raw_input_byte
        jsr remms_fifo_put
remms_raw_queue_status
        bcs remms_raw_queue_fail
remms_raw_queue_done
        clc
        rts
remms_raw_queue_fail
        lda #REMMS_ERR_FIFO_OVERFLOW
        sta remms_last_error
        sec
        rts

; A CR-terminated CONNECT response may leave its LF in the concurrent input
; buffer. Consume that one protocol byte, and no other byte.
remms_raw_accept_byte
        sta remms_raw_input_byte
        lda remms_connect_skip_lf
        beq remms_raw_accept_ready
        lda #0
        sta remms_connect_skip_lf
        lda remms_raw_input_byte
        cmp #10
        beq remms_raw_accept_discard
remms_raw_accept_ready
        lda remms_raw_input_byte
        clc
        rts
remms_raw_accept_discard
        sec
        rts

remms_console_impl
        lda remms_public_console_polls
        bne remms_console_ready
        ;##TRACE "REMMS WFC console ready raw=$%02X current=%u last=%u action=%u" db(REMMS_PUBLIC_CONSOLE_RAW) db(REMMS_PUBLIC_CONSOLE_CURRENT) db(REMMS_PUBLIC_CONSOLE_LAST) db(REMMS_SESSION_BLOCK+REMMS_S_WFC_ACTION)
remms_console_ready
        inc remms_public_console_polls
        lda CONSOL
        and #$07
        sta remms_last_consol
        sta remms_public_console_raw
        cmp #7
        bne remms_console_physical
        lda #0
        sta remms_session_block+REMMS_S_CONSOLE_GATE
        jmp remms_console_none
remms_console_physical
        lda remms_session_block+REMMS_S_CONSOLE_GATE
        bne remms_console_gated
        lda #1
        sta remms_session_block+REMMS_S_CONSOLE_GATE
        lda remms_last_consol
remms_console_check_start
        and #$01
        beq remms_console_start
        lda remms_last_consol
        and #$02
        beq remms_console_select
        lda remms_last_consol
        and #$04
        beq remms_console_option
remms_console_none
        lda HELPFG
        beq remms_console_no_help
        sta remms_public_atachr
        ldx #0
        stx HELPFG
        cmp #$11
        beq remms_console_help
        cmp #$51
        beq remms_console_shift_help
        cmp #$91
        beq remms_console_ctrl_help
remms_console_no_help
        lda #REMMS_CMD_NONE
        jmp remms_console_record_command
remms_console_gated
        lda #REMMS_CMD_NONE
remms_console_record_command
        sta remms_public_console_current
        cmp #REMMS_CMD_NONE
        beq remms_console_none_done
        sta remms_public_console_last
        sta remms_session_block+REMMS_S_WFC_ACTION
        ;##TRACE "REMMS console raw=%u current=%u last=%u polls=%u action=%u" db(REMMS_PUBLIC_CONSOLE_RAW) db(REMMS_PUBLIC_CONSOLE_CURRENT) db(REMMS_PUBLIC_CONSOLE_LAST) db(REMMS_PUBLIC_CONSOLE_POLLS) db(REMMS_SESSION_BLOCK+REMMS_S_WFC_ACTION)
remms_console_none_done
        rts
remms_console_start
        lda #REMMS_CMD_START
        jmp remms_console_record_command
remms_console_select
        lda #REMMS_CMD_SELECT
        jmp remms_console_record_command
remms_console_option
        lda #REMMS_CMD_OPTION
        jmp remms_console_record_command
remms_console_help
        lda remms_session_block+REMMS_S_SNOOP
        eor #1
        sta remms_session_block+REMMS_S_SNOOP
        jsr remms_apply_snoop_route
        ;##TRACE "REMMS HELP snoop=%u route=%u" db(REMMS_SESSION_BLOCK+REMMS_S_SNOOP) db(REMMS_PUBLIC_BLOCK+REMMS_P_ROUTE)
        lda #REMMS_CMD_NONE
        rts
remms_console_shift_help
        lda #REMMS_CMD_SHIFT_HELP
        jmp remms_console_record_command
remms_console_ctrl_help
        lda #REMMS_CMD_CTRL_HELP
        jmp remms_console_record_command

; Local text and pager input use the saved K: handler directly. Console
; polling never calls this routine and therefore cannot consume normal keys.
remms_keyboard_get_atascii
        ldx #REMMS_K_IOCB
        lda #CIO_GETCHR
        jsr remms_iocb_command_no_buffer
        jsr remms_call_k_get
        sta remms_cio_chr
        sty remms_cio_status
        tya
        bmi remms_keyboard_get_fail
        lda remms_cio_chr
        clc
        rts
remms_keyboard_get_fail
        sec
        rts
