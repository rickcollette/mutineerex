; ---------------------------------------------------------------------------
; API jump table
; ---------------------------------------------------------------------------

remms_api
REMMS_API_INIT
        jmp remms_usr_init
REMMS_API_MODE
        jmp remms_usr_mode
REMMS_API_ROUTE
        jmp remms_usr_route
REMMS_API_OPEN
        jmp remms_usr_open
REMMS_API_CLOSE
        jmp remms_usr_close
REMMS_API_STATUS
        jmp remms_usr_status
REMMS_API_GET
        jmp remms_usr_get
REMMS_API_PUT
        jmp remms_usr_put
REMMS_API_CONSOLE
        jmp remms_usr_console
REMMS_API_TEXT_GET
        jmp remms_usr_text_get
REMMS_API_PAGER_BEGIN
        jmp remms_usr_pager_begin
REMMS_API_PAGER_PUT
        jmp remms_usr_pager_put
REMMS_API_PAGER_END
        jmp remms_usr_pager_end
REMMS_API_RESET
        jmp remms_usr_reset
REMMS_API_EVENT
        jmp remms_usr_event
REMMS_API_TEXT_BEGIN
        jmp remms_usr_text_begin
REMMS_API_TEXT_END
        jmp remms_usr_text_end
REMMS_API_FAIL
        jmp remms_usr_fail
REMMS_API_DETACH
        jmp remms_usr_detach
REMMS_API_CONSOLE_CONFIG
        jmp remms_usr_console_config

remms_record_cio_status
        sty remms_last_status
        sty remms_session_block+REMMS_S_CIO_STATUS
        sty remms_public_cio_status
        rts

remms_set_config_profile
        sta remms_session_block+REMMS_S_CONFIG_PROFILE
        ;##TRACE "REMMS config profile=%u" db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        rts

remms_ownership_advance
        inc remms_session_block+REMMS_S_OWNERSHIP_SEQ
        ;##TRACE "REMMS ownership seq=%u physical=%u profile=%u" db(REMMS_SESSION_BLOCK+REMMS_S_OWNERSHIP_SEQ) db(REMMS_PUBLIC_PHYSICAL_STATE) db(REMMS_SESSION_BLOCK+REMMS_S_CONFIG_PROFILE)
        rts

; The retired message/chat API slots leave a fixed-address hole before the
; public block. Empty the raw FIFO here without consuming tail resident space;
; returns A=0.
remms_fifo_reset
        lda #0
        sta remms_fifo_head
        sta remms_fifo_tail
        sta remms_fifo_count
        rts

; Small absolute-call helpers occupy the remainder of the retired API slots.
; Keeping them here leaves enough resident tail room for the RIP block sender.
remms_xfer_get_byte_impl
        jmp remms_get_impl
remms_h_init
        ldy #CIO_SUCC
        tya
        rts

        org REMMS_PUBLIC

; ---------------------------------------------------------------------------
; Public state
; ---------------------------------------------------------------------------

remms_public_block
        dta c'REMMS'
        dta b(REMMS_VERSION_MAJOR)
        dta b(REMMS_VERSION_MINOR)
remms_mode
        dta b(REMMS_MODE_LOCAL)
remms_route
        dta b(REMMS_ROUTE_LOCAL)
remms_r_open
        dta b(0)
remms_last_status
        dta b(0)
remms_last_error
        dta b(0)
remms_installed
        dta b(0)
remms_last_consol
        dta b(7)
        dta b(0,0)
remms_public_console_raw
        dta b(7)
remms_public_console_current
        dta b(0)
remms_public_console_last
        dta b(0)
remms_public_console_polls
        dta b(0)
remms_public_ch
        dta b($FF)
remms_public_atachr
        dta b(0)
remms_public_event_seq_lo
        dta b(0)
remms_public_event_seq_hi
        dta b(0)
remms_public_physical_state
        dta b(REMMS_PHYS_CLOSED)
remms_public_connection_state
        dta b(REMMS_CONN_LOCAL)
remms_public_last_operation
        dta b(0)
remms_public_cio_status
        dta b(0)
remms_public_transition
        dta b(REMMS_TRANSITION_NONE)
; Resident-private state occupies otherwise unused bytes in the fixed public
; allocation so it does not increase MEMLO.
remms_failure_active
        dta b(0)
remms_failure_pending
        dta b(0)
remms_failure_reason
        dta b(REMMS_EXIT_NONE)
remms_failure_operation
        dta b(REMMS_OP_NONE)
remms_failure_status
        dta b(0)
remms_failure_error
        dta b(REMMS_ERR_NONE)
remms_failure_cleanup_status
        dta b(0)
remms_fault_operation
        dta b(0)
remms_fault_status
        dta b($8B)
remms_fault_class
        dta b(REMMS_FAULT_CLASS_FATAL)
remms_fault_skip
        dta b(0)
remms_fault_fired_class
        dta b(REMMS_FAULT_CLASS_FATAL)
remms_handler_x
        dta b(0)
remms_handler_y
        dta b(CIO_SUCC)
remms_handler_a
        dta b(0)
remms_io_byte
        dta b(0)
remms_cio_chr
        dta b(0)
remms_cio_status
        dta b(0)
remms_open_required_profile
        dta b(REMMS_CONFIG_NONE)
remms_open_error_operation
        dta b(REMMS_OP_NONE)
remms_clear_index
        dta b(0)
remms_eol_save
        dta b(0)
remms_filter_byte
        dta b(0)
remms_nc_match
        dta b(0)
remms_output_pending
        dta b(0)
remms_connect_skip_lf
        dta b(0)
remms_raw_input_byte
        dta b(0)
remms_ring_match
        dta b(0)
remms_connect_match
        dta b(0)
remms_connect_seen
        dta b(0)
remms_host_poll_count
        dta b(0)
remms_output_poll_count
        dta b(0)
remms_xio_command
        dta b(0)
remms_xio_aux1
        dta b(0)
; Shared WFC/TD byte. Bit 0 is the WFC-view-loaded flag, bits 1-3 are
; TD status, bits 4-6 are TD source, and bit 7 is the active RIPscrip mode.
remms_public_wfc_td
        dta b(0)

        org REMMS_COMMAND
remms_command_block
remms_dcb_save
        dta b(0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0)

        org REMMS_SESSION
remms_session_block
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        dta b(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

; ---------------------------------------------------------------------------
; BASIC USR wrappers
; ---------------------------------------------------------------------------

remms_usr_init
        jsr remms_usr_drop_all_args
        jsr remms_install
        bcs remms_usr_init_error
        jmp remms_usr_return_zero
remms_usr_init_error
        lda remms_last_error
        jmp remms_usr_return_a

remms_usr_mode
        cld
        pla
        cmp #1
        beq remms_usr_mode_one_arg
        tax
remms_usr_mode_discard
        cpx #0
        beq remms_usr_mode_bad
        pla
        pla
        dex
        bne remms_usr_mode_discard
remms_usr_mode_bad
        jmp remms_usr_one_arg_error
remms_usr_mode_one_arg
        pla
        sta remms_arg_hi
        pla
        pha
        lda remms_arg_hi
        bne remms_usr_mode_range
        pla
        jsr remms_set_mode_impl
        bcc remms_usr_mode_ok
        jmp remms_usr_impl_error
remms_usr_mode_ok
        jmp remms_usr_return_zero
remms_usr_mode_range
        pla
        jmp remms_usr_one_arg_error

remms_usr_route
        cld
        pla
        cmp #1
        beq remms_usr_route_one_arg
        tax
remms_usr_route_discard
        cpx #0
        beq remms_usr_route_bad
        pla
        pla
        dex
        bne remms_usr_route_discard
remms_usr_route_bad
        jmp remms_usr_one_arg_error
remms_usr_route_one_arg
        pla
        sta remms_arg_hi
        pla
        pha
        lda remms_arg_hi
        bne remms_usr_route_range
        pla
        jsr remms_set_route_impl
        bcc remms_usr_route_ok
        jmp remms_usr_impl_error
remms_usr_route_ok
        jmp remms_usr_return_zero
remms_usr_route_range
        pla
        jmp remms_usr_one_arg_error

remms_usr_open
        jsr remms_usr_get_one_byte_arg
        bcc remms_usr_open_arg
        jmp remms_usr_one_arg_error
remms_usr_open_arg
        cmp #REMMS_OPEN_FRESH+1
        bcc remms_usr_open_range_ok
        jmp remms_usr_one_arg_error
remms_usr_open_range_ok
        sta remms_session_block+REMMS_S_OPEN_POLICY
        jsr remms_open_impl
        bcc remms_usr_open_ok
        jmp remms_usr_impl_error
remms_usr_open_ok
        jmp remms_usr_return_zero

remms_usr_close
        jsr remms_usr_get_one_byte_arg
        bcc remms_usr_close_arg
        jmp remms_usr_one_arg_error
remms_usr_close_arg
        cmp #1
        beq remms_usr_close_suspend
        bcc remms_usr_close_normal
        jmp remms_usr_one_arg_error
remms_usr_close_normal
        jsr remms_close_impl
        bcc remms_usr_close_ok
        jmp remms_usr_impl_error
remms_usr_close_suspend
        jsr remms_suspend_impl
        bcc remms_usr_close_ok
        jmp remms_usr_impl_error
remms_usr_close_ok
        jmp remms_usr_return_zero

remms_usr_status
        jsr remms_usr_drop_all_args
        jsr remms_status_impl
        jmp remms_usr_return_a

remms_usr_get
        jsr remms_usr_drop_all_args
        jsr remms_get_impl
        bcs remms_usr_get_none
        jmp remms_usr_return_a
remms_usr_get_none
        lda remms_last_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_usr_get_carrier
        cmp #REMMS_ERR_TIMEOUT
        beq remms_usr_get_timeout
        cmp #REMMS_ERR_CIO
        beq remms_usr_get_fatal
        lda #<REMMS_RESULT_NO_DATA
        jmp remms_usr_return_01xx
remms_usr_get_carrier
        lda #<REMMS_RESULT_CARRIER_LOST
        jmp remms_usr_return_01xx
remms_usr_get_fatal
        lda #<REMMS_RESULT_FATAL_IO
        jmp remms_usr_return_01xx
remms_usr_get_timeout
        lda #<REMMS_RESULT_TIMEOUT
        jmp remms_usr_return_01xx

remms_usr_text_get
        jsr remms_usr_drop_all_args
        jsr remms_text_get_impl
        bcs remms_usr_text_get_none
        jmp remms_usr_return_a
remms_usr_text_get_none
        lda remms_last_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_usr_get_carrier
        cmp #REMMS_ERR_TIMEOUT
        beq remms_usr_get_timeout
        cmp #REMMS_ERR_CIO
        beq remms_usr_get_fatal
        lda #<REMMS_RESULT_NO_DATA
        jmp remms_usr_return_01xx

remms_usr_put
        cld
        pla
        cmp #1
        beq remms_usr_put_one_arg
        tax
remms_usr_put_discard
        cpx #0
        beq remms_usr_put_bad
        pla
        pla
        dex
        bne remms_usr_put_discard
remms_usr_put_bad
        jmp remms_usr_one_arg_error
remms_usr_put_one_arg
        pla
        sta remms_arg_hi
        pla
        pha
        lda remms_arg_hi
        bne remms_usr_put_range
        pla
        jsr remms_put_impl
        bcc remms_usr_put_ok
        lda remms_last_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_usr_get_carrier
        cmp #REMMS_ERR_TIMEOUT
        beq remms_usr_get_timeout
        lda #<REMMS_RESULT_FATAL_IO
        jmp remms_usr_return_01xx
remms_usr_put_ok
        jmp remms_usr_return_zero
remms_usr_put_range
        pla
        jmp remms_usr_one_arg_error

remms_usr_console
        jsr remms_usr_drop_all_args
        jsr remms_console_impl
        jmp remms_usr_return_a

remms_usr_pager_begin
        jsr remms_usr_drop_all_args
        jsr remms_pager_begin_impl
        jmp remms_usr_return_a

remms_usr_pager_put
        jsr remms_usr_get_one_byte_arg
        bcc remms_usr_pager_put_arg_ready
        jmp remms_usr_one_arg_error
remms_usr_pager_put_arg_ready
        jsr remms_pager_put_impl
        jmp remms_usr_return_a

remms_usr_pager_end
        jsr remms_usr_drop_all_args
        jsr remms_pager_end_impl
        jmp remms_usr_return_a

remms_usr_reset
        jsr remms_usr_drop_all_args
        lda remms_r_open
        bne remms_usr_reset_busy
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_CLOSED
        bne remms_usr_reset_busy
        jsr remms_session_init
        jmp remms_usr_return_zero
remms_usr_reset_busy
        jmp remms_usr_one_arg_error

remms_usr_event
        jsr remms_usr_drop_all_args
        jsr remms_event_poll
        ;##TRACE "REMMS event return kind=%u value=%u" db(REMMS_SESSION_BLOCK+REMMS_S_EVENT_KIND) db(REMMS_SESSION_BLOCK+REMMS_S_EVENT_VALUE)
        lda remms_session_block+REMMS_S_EVENT_VALUE
        sta FR0
        lda remms_session_block+REMMS_S_EVENT_KIND
        sta FR0+1
        lda FR0
        ldy FR0+1
        rts

remms_usr_text_begin
        jsr remms_usr_get_one_byte_arg
        bcs remms_usr_one_arg_error
        cmp #REMMS_TEXT_EDITOR+1
        bcs remms_usr_one_arg_error
        sta remms_session_block+REMMS_S_TEXT_MODE
        lda #0
        sta remms_session_block+REMMS_S_TEXT_STATE
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        jsr remms_resume_text_input
        bcs remms_usr_impl_error
remms_usr_text_begin_ready
        jmp remms_usr_return_zero

remms_usr_text_end
        jsr remms_usr_drop_all_args
        lda #REMMS_TEXT_NONE
        sta remms_session_block+REMMS_S_TEXT_MODE
        lda #0
        sta remms_session_block+REMMS_S_TEXT_STATE
        sta remms_session_block+REMMS_S_TEXT_CHOICE
        jmp remms_usr_return_zero

remms_usr_fail
        jsr remms_usr_get_one_byte_arg
        bcc remms_usr_fail_arg_ready
        bcs remms_usr_one_arg_error
remms_usr_fail_arg_ready
        cmp #REMMS_EXIT_CARRIER
        bcc remms_usr_fail_bad
        cmp #REMMS_EXIT_APPLICATION+1
        bcs remms_usr_fail_bad
        cmp #REMMS_EXIT_RECOVERABLE
        beq remms_usr_fail_bad
remms_usr_fail_valid
        jsr remms_failure_handoff
        bcc remms_usr_fail_ok
        lda #<REMMS_RESULT_FATAL_IO
        jmp remms_usr_return_01xx
remms_usr_fail_ok
        jmp remms_usr_return_zero
remms_usr_fail_bad

remms_usr_detach
        jsr remms_usr_drop_all_args
        jsr remms_detach_impl
        bcs remms_usr_impl_error
        bcc remms_usr_return_zero

remms_usr_console_config
        jsr remms_usr_get_one_byte_arg
        bcs remms_usr_one_arg_error
        cmp #2
        bcs remms_usr_one_arg_error
        sta remms_session_block+REMMS_S_SNOOP
        jsr remms_apply_snoop_route
        jmp remms_usr_return_zero

remms_usr_one_arg_error
        lda #REMMS_ERR_BAD_ARG
        sta remms_last_error
        jmp remms_usr_return_a

remms_usr_impl_error
        lda remms_last_error

remms_usr_return_a
        sta FR0
        ldy #0
        sty FR0+1
        rts

remms_usr_return_zero
        lda #0
        jmp remms_usr_return_a

remms_usr_return_01xx
        sta FR0
        ldy #1
        sty FR0+1
        rts

remms_usr_get_one_byte_arg
        cld
        pla
        sta remms_usr_ret_lo
        pla
        sta remms_usr_ret_hi
        pla
        cmp #1
        beq remms_one_byte_arg
        tax
remms_one_byte_discard
        cpx #0
        beq remms_one_byte_bad
        pla
        pla
        dex
        bne remms_one_byte_discard
remms_one_byte_bad
        ldx #1
        jmp remms_one_byte_restore
remms_one_byte_arg
        pla
        sta remms_arg_hi
        pla
        pha
        lda remms_arg_hi
        bne remms_one_byte_range
        pla
        ldx #0
        jmp remms_one_byte_restore
remms_one_byte_range
        pla
        ldx #1
remms_one_byte_restore
        stx remms_arg_carry
        sta remms_arg_value
        lda remms_usr_ret_hi
        pha
        lda remms_usr_ret_lo
        pha
        lda remms_arg_value
        lsr remms_arg_carry
        rts

remms_usr_drop_all_args
        cld
        pla
        sta remms_usr_ret_lo
        pla
        sta remms_usr_ret_hi
        pla
        tax
remms_drop_args_loop
        cpx #0
        beq remms_drop_args_restore
        pla
        pla
        dex
        bne remms_drop_args_loop
remms_drop_args_restore
        lda remms_usr_ret_hi
        pha
        lda remms_usr_ret_lo
        pha
        rts

; Argument decoding is synchronous and restores the BASIC return address
; before any handler/CIO work starts, so these names deliberately reuse the
; otherwise idle handler scratch bytes.
remms_usr_ret_lo = remms_handler_a
remms_usr_ret_hi = remms_handler_y
remms_arg_hi = remms_handler_x
remms_arg_value = remms_cio_chr
remms_arg_carry = remms_cio_status
