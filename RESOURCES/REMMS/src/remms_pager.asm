; ---------------------------------------------------------------------------
; Pager
; ---------------------------------------------------------------------------

remms_pager_defaults
        lda #REMMS_PAGER_DEFAULT_ENABLED
        sta remms_session_block+REMMS_S_PAGER_ENABLED
        lda #REMMS_PAGER_DEFAULT_ROWS
        sta remms_session_block+REMMS_S_PAGER_ROWS
        lda #REMMS_PAGER_DEFAULT_TOP
        sta remms_session_block+REMMS_S_PAGER_TOP
        lda #REMMS_PAGER_DEFAULT_BOTTOM
        sta remms_session_block+REMMS_S_PAGER_BOTTOM
        lda #REMMS_PAGER_DEFAULT_FLAGS
        sta remms_session_block+REMMS_S_PAGER_FLAGS
        lda #REMMS_PAGER_DEFAULT_LINES
        sta remms_session_block+REMMS_S_PAGER_LINES
        rts

remms_pager_begin_impl
        lda #REMMS_PAGER_OK
        sta remms_pager_begin_status
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_DEFAULTED
        beq remms_pager_validate_enabled
        lda #REMMS_PAGER_INVALID_CONFIG
        sta remms_pager_begin_status
remms_pager_validate_enabled
        lda remms_session_block+REMMS_S_PAGER_ENABLED
        cmp #2
        bcs remms_pager_config_bad
        lda remms_session_block+REMMS_S_PAGER_ROWS
        beq remms_pager_config_bad
        cmp #61
        bcs remms_pager_config_bad
        sec
        sbc remms_session_block+REMMS_S_PAGER_TOP
        beq remms_pager_config_bad
        bcc remms_pager_config_bad
        sec
        sbc remms_session_block+REMMS_S_PAGER_BOTTOM
        beq remms_pager_config_bad
        bcc remms_pager_config_bad
        sta remms_session_block+REMMS_S_PAGER_LINES
        lda remms_session_block+REMMS_S_PAGER_FLAGS
        and #$F8
        bne remms_pager_config_bad
        beq remms_pager_config_ready
remms_pager_config_bad
        jsr remms_pager_defaults
        lda #REMMS_PAGER_META_DEFAULTED
        sta remms_session_block+REMMS_S_PAGER_META
        lda #REMMS_PAGER_INVALID_CONFIG
        sta remms_pager_begin_status
remms_pager_config_ready
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_DEFAULTED
        sta remms_session_block+REMMS_S_PAGER_META
        lda #REMMS_PAGER_OK
        sta remms_session_block+REMMS_S_PAGER_RESULT
        lda #0
        sta remms_session_block+REMMS_S_PAGER_COUNT
        sta remms_session_block+REMMS_S_PAGER_COLUMN
        sta remms_pager_prompt_index
        lda remms_session_block+REMMS_S_PAGER_LINES
        sta remms_pager_limit
        lda remms_session_block+REMMS_S_PAGER_ENABLED
        beq remms_pager_begin_continuous
        lda #REMMS_PAGER_STATE_ACTIVE
        bne remms_pager_begin_state
remms_pager_begin_continuous
        lda #REMMS_PAGER_STATE_CONTINUOUS
remms_pager_begin_state
        sta remms_session_block+REMMS_S_PAGER_STATE
        jsr remms_pager_check_connection
        bcc remms_pager_begin_return
        rts
remms_pager_begin_return
        lda remms_pager_begin_status
        rts

remms_pager_put_impl
        sta remms_pager_output_byte
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_ABORTED
        beq remms_pager_put_saved_result
        cmp #REMMS_PAGER_STATE_DONE
        beq remms_pager_put_saved_result
        cmp #REMMS_PAGER_STATE_OFF
        beq remms_pager_put_saved_result
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_CONTINUOUS
        beq remms_pager_put_poll
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_PENDING
        beq remms_pager_put_poll
        jsr remms_pager_prompt
        bcs remms_pager_put_return
remms_pager_put_poll
        lda remms_pager_output_byte
        cmp #EOL
        beq remms_pager_put_poll_now
        inc remms_pager_prompt_index
        lda remms_pager_prompt_index
        and #$0F
        bne remms_pager_put_output
remms_pager_put_poll_now
        jsr remms_pager_poll_active
        bcs remms_pager_put_return
remms_pager_put_output
        lda remms_pager_output_byte
        jsr remms_pager_output_direct
        bcc remms_pager_put_count
        jsr remms_pager_set_output_error
        jmp remms_pager_put_return
remms_pager_put_count
        lda remms_pager_output_byte
        jsr remms_pager_count_byte
        lda #REMMS_PAGER_OK
remms_pager_put_return
        rts
remms_pager_put_saved_result
        lda remms_session_block+REMMS_S_PAGER_RESULT
        rts

remms_pager_end_impl
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_DEFAULTED
        sta remms_session_block+REMMS_S_PAGER_META
        lda remms_session_block+REMMS_S_PAGER_RESULT
        bne remms_pager_end_saved
        jsr remms_pager_check_connection
        bcs remms_pager_end_return
        lda #REMMS_PAGER_STATE_DONE
        sta remms_session_block+REMMS_S_PAGER_STATE
        lda #REMMS_PAGER_END_OF_FILE
        sta remms_session_block+REMMS_S_PAGER_RESULT
remms_pager_end_return
        rts
remms_pager_end_saved
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_ABORTED
        beq remms_pager_end_return_saved
        lda #REMMS_PAGER_STATE_DONE
        sta remms_session_block+REMMS_S_PAGER_STATE
remms_pager_end_return_saved
        lda remms_session_block+REMMS_S_PAGER_RESULT
        rts

remms_pager_check_connection
        lda remms_route
        cmp #REMMS_ROUTE_LOCAL
        beq remms_pager_connection_ok
        lda remms_mode
        cmp #REMMS_MODE_HOST
        bne remms_pager_connection_lost
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_pager_connection_lost
        jsr remms_r_status
        tya
        bmi remms_pager_connection_io
remms_pager_connection_ok
        lda #REMMS_PAGER_OK
        clc
        rts
remms_pager_connection_lost
        jsr remms_mark_carrier_lost
        lda #REMMS_PAGER_CARRIER_LOST
        jmp remms_pager_set_stopped
remms_pager_connection_io
        jsr remms_fail_cio
        lda remms_last_error
        cmp #REMMS_ERR_CARRIER_LOST
        beq remms_pager_connection_lost_recorded
        lda #REMMS_PAGER_INPUT_ERROR
        jmp remms_pager_set_stopped
remms_pager_connection_lost_recorded
        lda #REMMS_PAGER_CARRIER_LOST
        jmp remms_pager_set_stopped

remms_pager_set_abort
        lda #REMMS_PAGER_USER_ABORT
        jmp remms_pager_set_stopped

remms_pager_set_output_error
        lda #REMMS_PAGER_OUTPUT_ERROR
        jmp remms_pager_set_stopped

remms_pager_set_input_error
        lda #REMMS_PAGER_INPUT_ERROR
remms_pager_set_stopped
        sta remms_session_block+REMMS_S_PAGER_RESULT
        pha
        lda #REMMS_PAGER_STATE_ABORTED
        sta remms_session_block+REMMS_S_PAGER_STATE
        pla
        sec
        rts

remms_pager_poll_active
        jsr remms_pager_poll_key
        bcs remms_pager_poll_active_stop
        cmp #REMMS_PAGER_KEY_NONE
        beq remms_pager_poll_active_done
        cmp #REMMS_PAGER_KEY_QUIT
        beq remms_pager_poll_active_abort
        cmp #REMMS_PAGER_KEY_PAUSE
        beq remms_pager_poll_active_pause
        cmp #REMMS_PAGER_KEY_OTHER
        bne remms_pager_poll_active_done
        jsr remms_pager_preserve_remote_key
        bcs remms_pager_poll_active_stop
remms_pager_poll_active_done
        lda #REMMS_PAGER_OK
        clc
        rts
remms_pager_poll_active_pause
        lda remms_session_block+REMMS_S_PAGER_STATE
        sta remms_pager_resume_state
        jmp remms_pager_wait_resume
remms_pager_poll_active_abort
        jmp remms_pager_set_abort
remms_pager_poll_active_stop
        rts

remms_pager_wait_resume
        lda #REMMS_PAGER_STATE_PAUSED
        sta remms_session_block+REMMS_S_PAGER_STATE
remms_pager_wait_resume_loop
        jsr remms_pager_poll_key
        bcs remms_pager_wait_resume_stop
        cmp #REMMS_PAGER_KEY_NONE
        beq remms_pager_wait_resume_loop
        cmp #REMMS_PAGER_KEY_QUIT
        beq remms_pager_wait_resume_abort
        cmp #REMMS_PAGER_KEY_RESUME
        beq remms_pager_wait_resume_ok
        cmp #REMMS_PAGER_KEY_PAUSE
        beq remms_pager_wait_resume_ok
        cmp #REMMS_PAGER_KEY_ENTER
        beq remms_pager_wait_resume_ok
        cmp #REMMS_PAGER_KEY_PAGE
        bne remms_pager_wait_resume_other
        lda remms_pager_raw_byte
        cmp #$20
        beq remms_pager_wait_resume_ok
remms_pager_wait_resume_other
        cmp #REMMS_PAGER_KEY_OTHER
        bne remms_pager_wait_resume_loop
        jsr remms_pager_preserve_remote_key
        bcs remms_pager_wait_resume_stop
        bcc remms_pager_wait_resume_loop
remms_pager_wait_resume_ok
        lda remms_pager_resume_state
        sta remms_session_block+REMMS_S_PAGER_STATE
        lda #REMMS_PAGER_OK
        clc
        rts
remms_pager_wait_resume_abort
        jmp remms_pager_set_abort
remms_pager_wait_resume_stop
        rts

remms_pager_prompt
        lda #REMMS_PAGER_STATE_PROMPT
        sta remms_session_block+REMMS_S_PAGER_STATE
        jsr remms_pager_show_prompt
        bcc remms_pager_prompt_wait
        jmp remms_pager_set_output_error
remms_pager_prompt_wait
        jsr remms_pager_poll_key
        bcc remms_pager_prompt_have_key
        jmp remms_pager_prompt_stop
remms_pager_prompt_have_key
        cmp #REMMS_PAGER_KEY_NONE
        beq remms_pager_prompt_wait
        cmp #REMMS_PAGER_KEY_QUIT
        beq remms_pager_prompt_abort
        cmp #REMMS_PAGER_KEY_PAUSE
        beq remms_pager_prompt_pause
        cmp #REMMS_PAGER_KEY_ENTER
        beq remms_pager_prompt_line
        cmp #REMMS_PAGER_KEY_PAGE
        beq remms_pager_prompt_page
        cmp #REMMS_PAGER_KEY_CONTINUOUS
        beq remms_pager_prompt_continuous
        cmp #REMMS_PAGER_KEY_RESUME
        beq remms_pager_prompt_continuous
        jsr remms_pager_preserve_remote_key
        bcs remms_pager_prompt_stop
        bcc remms_pager_prompt_wait
remms_pager_prompt_pause
        lda #REMMS_PAGER_STATE_PROMPT
        sta remms_pager_resume_state
        jsr remms_pager_wait_resume
        bcs remms_pager_prompt_stop
        bcc remms_pager_prompt_wait
remms_pager_prompt_line
        lda remms_session_block+REMMS_S_PAGER_FLAGS
        and #REMMS_PAGER_FLAG_LINE
        beq remms_pager_prompt_page
        lda #1
        sta remms_pager_limit
        jmp remms_pager_prompt_continue
remms_pager_prompt_page
        lda remms_session_block+REMMS_S_PAGER_LINES
        sta remms_pager_limit
remms_pager_prompt_continue
        jsr remms_pager_erase_prompt
        bcs remms_pager_prompt_output_error
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_DEFAULTED
        sta remms_session_block+REMMS_S_PAGER_META
        lda #0
        sta remms_session_block+REMMS_S_PAGER_COUNT
        lda #REMMS_PAGER_STATE_ACTIVE
        sta remms_session_block+REMMS_S_PAGER_STATE
        lda #REMMS_PAGER_OK
        clc
        rts
remms_pager_prompt_continuous
        lda remms_session_block+REMMS_S_PAGER_FLAGS
        and #REMMS_PAGER_FLAG_CONTINUOUS
        beq remms_pager_prompt_wait
        jsr remms_pager_erase_prompt
        bcs remms_pager_prompt_output_error
        lda remms_session_block+REMMS_S_PAGER_META
        and #REMMS_PAGER_META_DEFAULTED
        sta remms_session_block+REMMS_S_PAGER_META
        lda #REMMS_PAGER_STATE_CONTINUOUS
        sta remms_session_block+REMMS_S_PAGER_STATE
        lda #REMMS_PAGER_OK
        clc
        rts
remms_pager_prompt_abort
        jsr remms_pager_erase_prompt
        bcs remms_pager_prompt_output_error
        jmp remms_pager_set_abort
remms_pager_prompt_output_error
        jmp remms_pager_set_output_error
remms_pager_prompt_stop
        rts

remms_pager_show_prompt
        lda #0
        sta remms_pager_prompt_index
remms_pager_show_prompt_loop
        ldx remms_pager_prompt_index
        lda remms_pager_prompt_text,x
        beq remms_pager_show_prompt_done
        jsr remms_pager_output_direct
        bcs remms_pager_show_prompt_fail
        inc remms_pager_prompt_index
        bne remms_pager_show_prompt_loop
remms_pager_show_prompt_done
        clc
        rts
remms_pager_show_prompt_fail
        sec
        rts

remms_pager_erase_prompt
        lda #$7E
        jsr remms_pager_erase_pass
        bcs remms_pager_erase_fail
        lda #$20
        jsr remms_pager_erase_pass
        bcs remms_pager_erase_fail
        lda #$7E
remms_pager_erase_pass
        sta remms_pager_direct_byte
        lda #0
        sta remms_pager_prompt_index
remms_pager_erase_pass_loop
        lda remms_pager_direct_byte
        jsr remms_pager_output_direct
        bcs remms_pager_erase_fail
        inc remms_pager_prompt_index
        lda remms_pager_prompt_index
        cmp #remms_pager_prompt_end-remms_pager_prompt_text
        bcc remms_pager_erase_pass_loop
        clc
        rts
remms_pager_erase_fail
        sec
        rts

remms_pager_output_direct
        sta remms_pager_direct_byte
        lda remms_pager_direct_byte
        jsr remms_output_shared
        bcs remms_pager_output_direct_fail
        lda remms_pager_direct_byte
        clc
        rts
remms_pager_output_direct_fail
        sec
        rts

remms_pager_count_byte
        cmp #EOL
        beq remms_pager_count_newline
        cmp #$7D
        beq remms_pager_count_clear
        cmp #$7E
        beq remms_pager_count_backspace
        cmp #$FD
        beq remms_pager_count_done
        cmp #$20
        bcc remms_pager_count_done
        cmp #$FE
        bcs remms_pager_count_done
        inc remms_session_block+REMMS_S_PAGER_COLUMN
        lda remms_session_block+REMMS_S_PAGER_COLUMN
        cmp #REMMS_PAGER_WIDTH
        bcc remms_pager_count_done
        lda remms_session_block+REMMS_S_PAGER_FLAGS
        and #REMMS_PAGER_FLAG_WRAP
        beq remms_pager_count_clamp
        lda #0
        sta remms_session_block+REMMS_S_PAGER_COLUMN
        jmp remms_pager_line_complete
remms_pager_count_clamp
        lda #REMMS_PAGER_WIDTH-1
        sta remms_session_block+REMMS_S_PAGER_COLUMN
remms_pager_count_done
        rts
remms_pager_count_newline
        lda #0
        sta remms_session_block+REMMS_S_PAGER_COLUMN
        jmp remms_pager_line_complete
remms_pager_count_clear
        lda #0
        sta remms_session_block+REMMS_S_PAGER_COLUMN
        sta remms_session_block+REMMS_S_PAGER_COUNT
        rts
remms_pager_count_backspace
        lda remms_session_block+REMMS_S_PAGER_COLUMN
        beq remms_pager_count_done
        dec remms_session_block+REMMS_S_PAGER_COLUMN
        rts
remms_pager_line_complete
        lda remms_session_block+REMMS_S_PAGER_COUNT
        cmp #$FF
        beq remms_pager_line_compare
        inc remms_session_block+REMMS_S_PAGER_COUNT
remms_pager_line_compare
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_CONTINUOUS
        beq remms_pager_line_done
        lda remms_session_block+REMMS_S_PAGER_COUNT
        cmp remms_pager_limit
        bcc remms_pager_line_done
        lda remms_session_block+REMMS_S_PAGER_META
        ora #REMMS_PAGER_META_PENDING
        sta remms_session_block+REMMS_S_PAGER_META
remms_pager_line_done
        rts

remms_pager_poll_key
        lda #0
        sta remms_pager_key_remote
        jsr remms_pager_check_connection
        bcc remms_pager_poll_key_connected
        jmp remms_pager_poll_key_stop
remms_pager_poll_key_connected
        lda remms_mode
        cmp #REMMS_MODE_HOST
        bne remms_pager_poll_local
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_pager_poll_local
        jsr remms_raw_get_try
        bcc remms_pager_poll_fifo_byte
        lda remms_last_error
        beq remms_pager_poll_local
        cmp #REMMS_ERR_CARRIER_LOST
        bne remms_pager_poll_key_input_error
        lda #REMMS_PAGER_CARRIER_LOST
        jmp remms_pager_set_stopped
remms_pager_poll_key_input_error
        jmp remms_pager_set_input_error
remms_pager_poll_fifo_byte
        sta remms_pager_raw_byte
        lda #1
        sta remms_pager_key_remote
remms_pager_poll_remote_translate
        lda remms_text_after_cr
        beq remms_pager_poll_remote_cr
        lda #0
        sta remms_text_after_cr
        lda remms_pager_raw_byte
        cmp #10
        beq remms_pager_poll_none
        cmp #0
        beq remms_pager_poll_none
remms_pager_poll_remote_cr
        lda remms_pager_raw_byte
        cmp #13
        beq remms_pager_poll_mark_eol
        cmp #EOL
        bne remms_pager_poll_classify
remms_pager_poll_mark_eol
        inc remms_text_after_cr
remms_pager_poll_classify
        lda remms_pager_raw_byte
        jsr remms_pager_classify_key
        clc
        rts
remms_pager_poll_local
        lda CH
        cmp #$FF
        beq remms_pager_poll_none
        cmp #REMMS_LOCAL_KEY_ABORT
        beq remms_pager_poll_local_abort
        cmp #REMMS_LOCAL_KEY_PAUSE
        beq remms_pager_poll_local_pause
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_ACTIVE
        beq remms_pager_poll_none
        cmp #REMMS_PAGER_STATE_CONTINUOUS
        beq remms_pager_poll_none
        jsr remms_keyboard_get_atascii
        bcs remms_pager_poll_none
        sta remms_pager_raw_byte
        jsr remms_pager_classify_key
        clc
        rts
remms_pager_poll_local_abort
        lda #$FF
        sta CH
        lda #REMMS_REMOTE_KEY_ABORT
        sta remms_pager_raw_byte
        lda #REMMS_PAGER_KEY_QUIT
        clc
        rts
remms_pager_poll_local_pause
        lda #$FF
        sta CH
        lda #REMMS_REMOTE_KEY_PAUSE
        sta remms_pager_raw_byte
        lda #REMMS_PAGER_KEY_PAUSE
        clc
        rts
remms_pager_poll_none
        lda #REMMS_PAGER_KEY_NONE
        clc
        rts
remms_pager_poll_key_stop
        rts

remms_pager_classify_key
        cmp #REMMS_REMOTE_KEY_ABORT
        beq remms_pager_return_key_quit
        cmp #REMMS_REMOTE_KEY_PAUSE
        beq remms_pager_return_key_pause
        cmp #REMMS_REMOTE_KEY_RESUME
        beq remms_pager_return_key_resume
        lda remms_session_block+REMMS_S_PAGER_STATE
        cmp #REMMS_PAGER_STATE_PROMPT
        beq remms_pager_classify_prompt
        cmp #REMMS_PAGER_STATE_PAUSED
        beq remms_pager_classify_prompt
        lda #REMMS_PAGER_KEY_OTHER
        rts
remms_pager_classify_prompt
        lda remms_pager_raw_byte
        cmp #13
        beq remms_pager_return_key_enter
        cmp #10
        beq remms_pager_return_key_enter
        cmp #EOL
        beq remms_pager_return_key_enter
        cmp #$20
        beq remms_pager_return_key_page
        lda #REMMS_PAGER_KEY_OTHER
        rts
remms_pager_return_key_enter
        lda #REMMS_PAGER_KEY_ENTER
        rts
remms_pager_return_key_page
        lda #REMMS_PAGER_KEY_PAGE
        rts
remms_pager_return_key_quit
        lda #REMMS_PAGER_KEY_QUIT
        rts
remms_pager_return_key_pause
        lda #REMMS_PAGER_KEY_PAUSE
        rts
remms_pager_return_key_resume
        lda #REMMS_PAGER_KEY_RESUME
        rts

remms_pager_preserve_remote_key
        lda remms_pager_key_remote
        beq remms_pager_preserve_done
        lda remms_pager_raw_byte
        jsr remms_fifo_put_reserved
        bcc remms_pager_preserve_done
        jsr remms_pager_set_input_error
        sec
        rts
remms_pager_preserve_done
        clc
        rts
