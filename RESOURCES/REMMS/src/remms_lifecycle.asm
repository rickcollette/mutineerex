; ---------------------------------------------------------------------------
; Mode, route, console, and R: implementation
; ---------------------------------------------------------------------------

remms_set_physical_state
        sta remms_session_block+REMMS_S_PHYSICAL_STATE
        sta remms_public_physical_state
        ;##TRACE "REMMS physical state=%u" db(REMMS_PUBLIC_PHYSICAL_STATE)
        rts

remms_set_connection_state
        sta remms_session_block+REMMS_S_CONNECTION_STATE
        sta remms_public_connection_state
        ;##TRACE "REMMS connection state=%u" db(REMMS_PUBLIC_CONNECTION_STATE)
        rts

remms_begin_operation
        sta remms_session_block+REMMS_S_LAST_OPERATION
        sta remms_public_last_operation
        lda #REMMS_FAULT_CLASS_FATAL
        sta remms_fault_fired_class
        rts

; The physical OPEN has succeeded. Ownership is real immediately, while the
; configuration remains NONE until every setup XIO has succeeded.
remms_physical_open_succeeded
        lda #1
        sta remms_r_open
        lda #REMMS_CONFIG_NONE
        jsr remms_set_config_profile
        lda #REMMS_PHYS_OPEN
        jsr remms_set_physical_state
        jmp remms_ownership_advance

; A physical CLOSE has succeeded. A contains CLOSED or RESUME_PENDING.
remms_physical_release_succeeded
        pha
        lda #0
        sta remms_r_open
        lda #REMMS_CONFIG_NONE
        jsr remms_set_config_profile
        pla
        jsr remms_set_physical_state
        jmp remms_ownership_advance

; A failed CLOSE leaves ownership uncertain. Keep remms_r_open set so a later
; fresh lifecycle must reconcile the physical IOCB before claiming success.
remms_physical_ownership_fault
        lda #1
        sta remms_r_open
        lda #REMMS_CONFIG_NONE
        jsr remms_set_config_profile
        lda #REMMS_PHYS_FAULT
        jsr remms_set_physical_state
        lda #REMMS_ERR_CIO
        sta remms_last_error
        rts

remms_set_mode_impl
        cmp #REMMS_MODE_LOCAL
        beq remms_set_mode_ok
        cmp #REMMS_MODE_HOST
        beq remms_set_mode_ok
        lda #REMMS_ERR_BAD_MODE
        sta remms_last_error
        sec
        rts
remms_set_mode_ok
        sta remms_mode
        cmp #REMMS_MODE_LOCAL
        bne remms_set_mode_finish
        lda #REMMS_ROUTE_LOCAL
        sta remms_route
remms_set_mode_finish
        lda #REMMS_ERR_NONE
        sta remms_last_error
        clc
        rts

remms_set_route_impl
        cmp #REMMS_ROUTE_LOCAL
        beq remms_set_route_ok
        cmp #REMMS_ROUTE_REMOTE
        beq remms_set_route_ok
        cmp #REMMS_ROUTE_BOTH
        beq remms_set_route_ok
        lda #REMMS_ERR_BAD_ROUTE
        sta remms_last_error
        sec
        rts
remms_set_route_ok
        sta remms_route
        lda #REMMS_ERR_NONE
        sta remms_last_error
        clc
        rts

remms_apply_snoop_route
        lda remms_mode
        cmp #REMMS_MODE_HOST
        bne remms_apply_snoop_local
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_apply_snoop_local
        lda remms_session_block+REMMS_S_SNOOP
        beq remms_apply_snoop_remote
        lda #REMMS_ROUTE_BOTH
        bne remms_apply_snoop_store
remms_apply_snoop_remote
        lda #REMMS_ROUTE_REMOTE
        bne remms_apply_snoop_store
remms_apply_snoop_local
        lda #REMMS_ROUTE_LOCAL
remms_apply_snoop_store
        sta remms_route
        rts

remms_detach_impl
        jsr remms_close_impl
        bcs remms_detach_fail
        jsr remms_restore_handlers
        lda #REMMS_TEXT_NONE
        sta remms_session_block+REMMS_S_TEXT_MODE
        lda #0
        sta remms_session_block+REMMS_S_TEXT_STATE
        sta remms_session_block+REMMS_S_PAGER_STATE
        sta remms_session_block+REMMS_S_ONLINE
        sta remms_installed
        clc
remms_detach_fail
        rts

remms_open_impl
        lda remms_session_block+REMMS_S_OPEN_POLICY
        cmp #REMMS_OPEN_FRESH
        beq remms_open_require_fresh
        lda #REMMS_CONFIG_CONNECTED
        sta remms_open_required_profile
        lda remms_r_open
        beq remms_open_cold
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_OPEN
        bne remms_open_resume_reconcile
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_CONNECTED
        beq remms_open_already
remms_open_resume_reconcile
        jsr remms_close_physical
        bcs remms_open_existing_fail
        bcc remms_open_cold
remms_open_already
remms_success_return
        lda #REMMS_ERR_NONE
        sta remms_last_error
        clc
        rts
remms_open_require_fresh
        lda #REMMS_CONFIG_WAIT_CALL
        sta remms_open_required_profile
        lda remms_r_open
        beq remms_open_fresh_path
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_OPEN
        bne remms_open_fresh_path
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_WAIT_CALL
        beq remms_open_already
remms_open_fresh_path
        jsr remms_close_impl
        bcc remms_open_cold
remms_open_existing_fail
        sec
        rts
; Rebuild the connected concurrent stream; falls into the cold open.
remms_open_connected
        lda #REMMS_CONFIG_CONNECTED
        sta remms_open_required_profile
remms_open_cold
        lda #REMMS_PHYS_OPENING
        jsr remms_set_physical_state
        jsr remms_open_device
        bpl remms_open_cio_ok
        jsr remms_mark_physical_closed
        lda #REMMS_ERR_CIO
        sta remms_last_error
        ;##TRACE "REMMS open failure op=%u status=$%02X physical=%u owner=%u profile=%u" db(REMMS_PUBLIC_LAST_OPERATION) db(REMMS_PUBLIC_CIO_STATUS) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_R_OPEN) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        sec
        rts
remms_open_device
        ldx #REMMS_R_IOCB
        lda #$FF
        sta ICHID,x
        lda #CIO_OPEN
        sta ICCOM,x
        lda #<remms_r_name
        sta ICBAL,x
        lda #>remms_r_name
        sta ICBAH,x
        lda #REMMS_R_OPEN_AUX
        sta ICAX1,x
        lda #0
        sta ICAX2,x
        lda #REMMS_OP_OPEN
        jsr remms_begin_operation
        lda #CIO_OPEN
        jsr remms_ciov_preserve_dcb
        jsr remms_record_cio_status
        tya
        rts

; Own the modem's AT response before WFC can accept a call. Echo and CR/LF
; framing vary across real modems, so drain through the K in OK and one clock
; tick beyond it instead of depending on Altirra's exact nine-byte reply.
remms_sync_drain_response
        lda #0
        sta remms_output_poll_count
remms_sync_drain_wait
        jsr remms_r_status
        tya
        bmi remms_sync_drain_fail
        lda remms_raw_ready
        bne remms_sync_drain_get
        lda remms_output_poll_count
        bmi remms_sync_drain_grace
        inc remms_clear_index
        bne remms_sync_drain_wait
        lda #REMMS_ERR_TIMEOUT
        sta remms_last_error
        sec
        rts
remms_sync_drain_grace
        eor RTCLOK2
        and #$7F
        beq remms_sync_drain_wait
        ;##TRACE "REMMS fresh modem sync complete"
        clc
        rts
remms_sync_drain_get
        jsr remms_r_get_raw
        bcs remms_sync_drain_fail
        cmp #'K'
        bne remms_sync_drain_wait
        lda RTCLOK2
        ora #$80
        sta remms_output_poll_count
        bne remms_sync_drain_wait
remms_sync_drain_fail
        sec
        rts
remms_open_cio_ok
        jmp remms_open_setup_begin
remms_open_setup_fail
        jmp remms_open_fail_close
remms_open_setup_begin
        jsr remms_physical_open_succeeded
        jsr remms_r_probe_backend
        lda #CIO_XIO38
        ldy #$20
        ldx #0
        jsr remms_r_xio_simple
        bmi remms_open_setup_fail
        lda #CIO_XIO34
        ldy #REMMS_R_CONTROL_READY
        ldx #0
        jsr remms_r_xio_simple
        bmi remms_open_setup_fail
        ldy #REMMS_R_BAUD_CODE
        ldx #0
        lda remms_open_required_profile
        cmp #REMMS_CONFIG_WAIT_CALL
        beq remms_open_wait_baud
        lda remms_r_caps
        and #REMMS_R_CAP_CARRIER
        beq remms_open_baud_ready
        inx
        bne remms_open_baud_ready
remms_open_wait_baud
        ldy #REMMS_R_WAIT_BAUD_CODE
remms_open_baud_ready
        lda #CIO_XIO36
        jsr remms_r_xio_simple
        bmi remms_open_setup_fail
        lda #CIO_XIO40
        jsr remms_r_xio_concurrent
        ;##TRACE "REMMS XIO40 result CIO=$%02X ERR=$%02X PHYS=$%02X" db(REMMS_LAST_STATUS) db(REMMS_LAST_ERROR) db(REMMS_PUBLIC_PHYSICAL_STATE)
        bmi remms_open_setup_fail
        jsr remms_sync_fresh_modem
        bcs remms_open_setup_fail
        lda remms_open_required_profile
        jsr remms_set_config_profile
        cmp #REMMS_CONFIG_CONNECTED
        beq remms_open_resume_connected
        jsr remms_host_reset
        lda remms_session_block+REMMS_S_ANSWER_RINGS
        beq remms_open_answer_policy_default
        cmp #10
        bcc remms_open_answer_policy_ok
remms_open_answer_policy_default
        lda #1
        sta remms_session_block+REMMS_S_ANSWER_RINGS
remms_open_answer_policy_ok
        lda #REMMS_CONN_WAIT_CALL
        jsr remms_set_connection_state
        lda #0
        sta remms_session_block+REMMS_S_ONLINE
        lda #REMMS_MODE_HOST
        sta remms_mode
        lda #REMMS_ROUTE_LOCAL
        sta remms_route
        jmp remms_success_return
remms_open_resume_connected
        lda #REMMS_TRANSITION_RESUME
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        lda #REMMS_CONN_CONNECTED
        jsr remms_set_connection_state
        lda #REMMS_MODE_HOST
        sta remms_mode
        jsr remms_apply_snoop_route
        jmp remms_success_return

; The modem PUT path owns X, so preserve the command index on the CPU stack.
remms_sync_fresh_modem
        lda remms_open_required_profile
        cmp #REMMS_CONFIG_WAIT_CALL
        bne remms_sync_fresh_done
        ;##TRACE "REMMS fresh modem sync begin"
        ldx #0
remms_sync_fresh_loop
        txa
        pha
        lda remms_sync_command,x
        jsr remms_r_put_try
        pla
        tax
        bcs remms_sync_fresh_fail
        inx
        cpx #3
        bcc remms_sync_fresh_loop
        jmp remms_sync_drain_response
remms_sync_fresh_done
        clc
remms_sync_fresh_fail
        rts

; Disk ownership pauses input until the next text field is ready. Do not send
; in-band XOFF/XON: modern ASCII/RIP terminals can render those bytes as
; visible triangle/!! glyphs. Stale typeahead is discarded by rebuilding the
; concurrent stream instead.
remms_resume_text_input
        lda remms_input_paused
        beq remms_resume_text_ready
        jsr remms_r_status
        tya
        bmi remms_resume_text_fail
        lda remms_raw_ready
        ora remms_fifo_count
        beq remms_resume_text_send
        jsr remms_close_physical
        bcs remms_resume_text_fail
        jsr remms_open_connected
        bcs remms_resume_text_fail
remms_resume_text_send
        jsr remms_fifo_reset
        lda #0
        sta remms_raw_ready
        sta remms_text_after_cr
        lda #0
        sta remms_input_paused
remms_resume_text_ready
        clc
remms_resume_text_fail
        rts
remms_open_fail_close
        sty remms_cio_status
        lda remms_session_block+REMMS_S_LAST_OPERATION
        sta remms_open_error_operation
        jsr remms_close_physical
        ldy remms_cio_status
        jsr remms_record_cio_status
        lda remms_open_error_operation
        jsr remms_begin_operation
remms_open_fail
        lda #REMMS_ERR_CIO
        sta remms_last_error
        ;##TRACE "REMMS open failure op=%u status=$%02X physical=%u owner=%u profile=%u" db(REMMS_PUBLIC_LAST_OPERATION) db(REMMS_PUBLIC_CIO_STATUS) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_R_OPEN) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        sec
        rts

; End the wait-for-call concurrent stream without changing DTR, then rebuild
; it with the connected 9600 selector. This is a physical release/acquisition,
; not a hangup and not an application RUN transition.
remms_reopen_connected_stream
        jsr remms_close_physical
        bcs remms_reopen_connected_fail
        lda #0
        sta remms_raw_ready
        jsr remms_open_connected
        bcs remms_reopen_connected_fail
        clc
        rts
remms_reopen_connected_fail
        sec
        rts

; Preserve a live modem connection while BASIC performs disk I/O. The next
; ROPEN,RESUME rebuilds the connected concurrent stream without a hangup.
remms_suspend_impl
        ;##TRACE "REMMS suspend request physical=%u profile=%u online=%u" db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE) db(REMMS_SESSION_BLOCK+REMMS_S_ONLINE)
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_suspend_close
        lda remms_input_paused
        bne remms_suspend_close
        lda #1
        sta remms_input_paused
remms_suspend_close
        jsr remms_close_physical
        bcs remms_suspend_fail
        lda #REMMS_PHYS_RESUME_PENDING
        jsr remms_set_physical_state
        lda #REMMS_TRANSITION_SUSPEND
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        clc
remms_suspend_fail
        rts

remms_close_physical
        lda remms_r_open
        beq remms_close_physical_done
        lda #REMMS_PHYS_CLOSING
        jsr remms_set_physical_state
        ldx #REMMS_R_IOCB
        lda #CIO_CLOSE
        sta ICCOM,x
        lda #REMMS_OP_CLOSE
        jsr remms_begin_operation
        lda #CIO_CLOSE
        jsr remms_ciov_preserve_dcb
        jsr remms_record_cio_status
        tya
        bmi remms_close_physical_fail
        lda #REMMS_PHYS_CLOSED
        jsr remms_physical_release_succeeded
        clc
        rts
remms_close_physical_done
        jsr remms_mark_physical_closed
        clc
        rts
remms_close_physical_fail
        jsr remms_physical_ownership_fault
        sec
        rts

remms_r_xio_simple
        sta remms_xio_command
        sty remms_xio_aux1
        stx remms_xio_aux2
        ldx #REMMS_R_IOCB
        lda remms_xio_command
        sta ICCOM,x
        lda #<remms_r_name
        sta ICBAL,x
        lda #>remms_r_name
        sta ICBAH,x
        lda #0
        sta ICBLL,x
        sta ICBLH,x
        lda remms_xio_aux1
        sta ICAX1,x
        lda remms_xio_aux2
        sta ICAX2,x
        lda remms_xio_command
        cmp #CIO_XIO38
        beq remms_r_xio_op38
        cmp #CIO_XIO34
        beq remms_r_xio_op34
        cmp #CIO_XIO36
        beq remms_r_xio_op36
        lda #REMMS_OP_NONE
        beq remms_r_xio_begin
remms_r_xio_op38
        lda #REMMS_OP_XIO38
        bne remms_r_xio_begin
remms_r_xio_op34
        lda #REMMS_OP_XIO34
        bne remms_r_xio_begin
remms_r_xio_op36
        lda #REMMS_OP_XIO36
remms_r_xio_begin
        jsr remms_begin_operation
        lda remms_xio_command
        jsr remms_ciov_preserve_dcb
        jsr remms_record_cio_status
        tya
        rts

; RVRHAND identifies itself through XIO 42 and DVSTAT="RV",version,caps.
; The 850 rejects that command, so its established full contract is the
; conservative default. Probe failure is intentionally superseded by XIO 38.
remms_r_probe_backend
        lda #REMMS_R_CAP_850_DEFAULT
        sta remms_r_caps
        lda #CIO_XIO42
        ldy #0
        ldx #0
        jsr remms_r_xio_simple
        bmi remms_r_probe_done
        lda DVSTAT+3
        sta remms_r_caps
remms_r_probe_done
        rts

remms_r_xio_concurrent
        ldx #REMMS_R_IOCB
        sta ICCOM,x
        lda #<REMMS_R_CONCURRENT_BUFFER
        sta ICBAL,x
        lda #>REMMS_R_CONCURRENT_BUFFER
        sta ICBAH,x
        lda #REMMS_R_CONCURRENT_LENGTH
        sta ICBLL,x
        lda #0
        sta ICBLH,x
        lda #REMMS_R_OPEN_AUX
        sta ICAX1,x
        lda #0
        sta ICAX2,x
        lda #REMMS_OP_XIO40
        jsr remms_begin_operation
        lda #CIO_XIO40
        jsr remms_ciov_preserve_dcb
        jsr remms_record_cio_status
        tya
        rts

remms_close_impl
        lda #0
        sta remms_close_error_flag
        lda remms_r_open
        beq remms_close_physical_step
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_close_physical_step
        ; XIO 34 is illegal while the 850 is in concurrent mode. End that
        ; stream, acquire a short block-mode session, drop DTR, then close.
        jsr remms_close_physical
        bcc remms_close_hangup_reopen
        jmp remms_close_failed
remms_close_hangup_reopen
        lda #REMMS_PHYS_OPENING
        jsr remms_set_physical_state
        jsr remms_open_device
        bpl remms_close_hangup_open
        lda #1
        sta remms_close_error_flag
        sty remms_close_error_status
        lda remms_session_block+REMMS_S_LAST_OPERATION
        sta remms_close_error_operation
        jmp remms_close_state_only
remms_close_hangup_open
        ;##TRACE "REMMS block hangup open"
        jsr remms_physical_open_succeeded
        jsr remms_r_hangup
        bcc remms_close_physical_step
        lda #1
        sta remms_close_error_flag
        sty remms_close_error_status
        lda remms_session_block+REMMS_S_LAST_OPERATION
        sta remms_close_error_operation
remms_close_physical_step
        jsr remms_close_physical
        bcc remms_close_state_only
        lda remms_close_error_flag
        beq remms_close_failed
        ; The hangup error was the first failure and remains authoritative.
        ldy remms_close_error_status
        jsr remms_record_cio_status
        lda remms_close_error_operation
        jsr remms_begin_operation
        jmp remms_close_failed
remms_close_state_only
        lda #0
        sta remms_text_after_cr
        jsr remms_set_local_route
        lda #REMMS_TRANSITION_CLOSE
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        lda remms_close_error_flag
        beq remms_close_success
        ldy remms_close_error_status
        jsr remms_record_cio_status
        lda remms_close_error_operation
        jsr remms_begin_operation
        lda #REMMS_CONN_ERROR
        jsr remms_set_connection_state
        lda #REMMS_ERR_CIO
        sta remms_last_error
        ;##TRACE "REMMS close failure op=%u status=$%02X physical=%u owner=%u profile=%u" db(REMMS_PUBLIC_LAST_OPERATION) db(REMMS_PUBLIC_CIO_STATUS) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_R_OPEN) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        sec
        rts
remms_close_success
        jsr remms_host_reset
        lda #REMMS_CONN_LOCAL
        jsr remms_set_connection_state
        jmp remms_success_return
remms_close_failed
        jsr remms_set_local_route
        lda #REMMS_CONN_ERROR
        jsr remms_set_connection_state
        lda #REMMS_TRANSITION_CLOSE
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        lda #REMMS_ERR_CIO
        sta remms_last_error
        ;##TRACE "REMMS close failure op=%u status=$%02X physical=%u owner=%u profile=%u" db(REMMS_PUBLIC_LAST_OPERATION) db(REMMS_PUBLIC_CIO_STATUS) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_R_OPEN) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        sec
        rts

remms_r_hangup
        lda #CIO_XIO34
        ldy #$80
        ldx #0
        jsr remms_r_xio_simple
        bmi remms_r_hangup_fail
        clc
        rts
remms_r_hangup_fail
        lda #REMMS_ERR_CIO
        sta remms_last_error
        sec
        rts

; Record one authoritative terminal modem/application failure. The original
; operation, CIO status, and REMMS error remain primary even if physical
; cleanup also fails.
remms_failure_handoff
        sta remms_failure_reason
        lda remms_failure_active
        beq remms_failure_begin
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_FAULT
        rts
remms_failure_begin
        lda remms_session_block+REMMS_S_LAST_OPERATION
        sta remms_failure_operation
        lda remms_session_block+REMMS_S_CIO_STATUS
        sta remms_failure_status
        lda #REMMS_ERR_CIO
        ldx remms_failure_reason
        cpx #REMMS_EXIT_CARRIER
        bne remms_failure_check_timeout
        lda #REMMS_ERR_CARRIER_LOST
        bne remms_failure_error_ready
remms_failure_check_timeout
        cpx #REMMS_EXIT_TIMEOUT
        bne remms_failure_error_ready
        lda #REMMS_ERR_TIMEOUT
remms_failure_error_ready
        sta remms_failure_error

        ; Close while ONLINE is still set, so a live call is hung up (DTR
        ; drop) like any other close. Closing alone leaves the caller
        ; connected, and the next WFC modem sync would reach them as data.
        jsr remms_close_impl
        bcc remms_failure_cleanup_done
        lda remms_session_block+REMMS_S_CIO_STATUS
        sta remms_failure_cleanup_status
remms_failure_cleanup_done
        ; Set only now: remms_close_impl clears its error flag, which shares
        ; this byte, so a repeated handoff stays a no-op until the next close.
        inc remms_failure_active
        lda #0
        sta remms_session_block+REMMS_S_ONLINE
        sta remms_session_block+REMMS_S_TEXT_STATE
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        jsr remms_fifo_reset
        sta remms_raw_ready
        sta remms_input_paused
        sta remms_nc_match
        sta remms_connect_skip_lf
        sta remms_text_after_cr
        lda #REMMS_TEXT_NONE
        sta remms_session_block+REMMS_S_TEXT_MODE

        ldy remms_failure_status
        jsr remms_record_cio_status
        lda remms_failure_operation
        jsr remms_begin_operation
        lda remms_failure_error
        sta remms_last_error

        lda remms_failure_reason
        sta remms_session_block+REMMS_S_EXIT_REASON
        cmp #REMMS_EXIT_CARRIER
        bne remms_failure_connection_error
        lda #REMMS_CONN_LOST
        bne remms_failure_connection_ready
remms_failure_connection_error
        lda #REMMS_CONN_ERROR
remms_failure_connection_ready
        jsr remms_set_connection_state
        lda #REMMS_MODE_LOCAL
        sta remms_mode
        sta remms_route
        lda #REMMS_TRANSITION_CLOSE
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition

        lda remms_failure_reason
        cmp #REMMS_EXIT_APPLICATION
        bne remms_failure_event_ready
        lda #REMMS_EVENT_FATAL
remms_failure_event_ready
        sta remms_session_block+REMMS_S_EVENT_KIND
        lda remms_failure_error
        sta remms_session_block+REMMS_S_EVENT_VALUE
        lda #1
        sta remms_failure_pending
        jsr remms_event_sequence_advance
        ;##TRACE "REMMS failure reason=%u op=%u status=$%02X cleanup=$%02X physical=%u connection=%u exit=%u xfer=%u" db(REMMS_FAILURE_REASON) db(REMMS_FAILURE_OPERATION) db(REMMS_FAILURE_STATUS) db(REMMS_FAILURE_CLEANUP_STATUS) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_PUBLIC_CONNECTION_STATE) db(REMMS_SESSION_BLOCK+REMMS_S_EXIT_REASON) db(REMMS_SESSION_BLOCK+REMMS_S_XFER_PHASE)
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_FAULT
        rts

; Record a CIO error and fall into the authoritative failure path.
remms_fail_cio
        lda #REMMS_ERR_CIO
        sta remms_last_error
remms_failure_from_cio
        lda remms_fault_fired_class
        cmp #REMMS_FAULT_CLASS_CARRIER
        beq remms_failure_from_cio_carrier
        lda #REMMS_EXIT_FATAL
        jmp remms_failure_handoff
remms_failure_from_cio_carrier
        lda #REMMS_EXIT_CARRIER
        jmp remms_failure_handoff

remms_status_impl
        lda remms_mode
        beq remms_status_local
        lda remms_r_open
        beq remms_status_local
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        beq remms_status_online
        jmp remms_host_status_impl
remms_status_online
        jsr remms_connected_carrier_check
        bcs remms_status_fail_done
        jsr remms_r_status
        tya
        bmi remms_status_fail
        lda #REMMS_ERR_NONE
        sta remms_last_error
        lda remms_raw_ready
        beq remms_status_waiting
        lda #1
        clc
        rts
remms_status_waiting
        lda #0
        clc
        rts
remms_status_fail
        jsr remms_fail_cio
remms_status_fail_done
        lda #0
        sec
        rts
remms_status_local
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_status_local_zero
        lda #REMMS_EXIT_FATAL
        jsr remms_failure_handoff
        lda #0
        sec
        rts
remms_status_local_zero
        lda #0
        sta remms_last_status
        sta remms_last_error
        clc
        rts
