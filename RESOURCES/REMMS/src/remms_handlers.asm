remms_ciov_preserve_dcb
        sta remms_ciov_a_in
        jsr remms_save_dcb
        jsr remms_fault_check
        bcs remms_ciov_fault_fire
remms_ciov_call
        lda #1
        sta remms_r_internal
        lda remms_ciov_a_in
        jsr CIOV
        sta remms_ciov_a_out
        sty remms_ciov_y_out
        lda #0
        sta remms_r_internal
        jmp remms_ciov_restore
remms_ciov_fault_fire
        lda #0
        sta remms_ciov_a_out
        sty remms_ciov_y_out
remms_ciov_restore
        jsr remms_restore_dcb
        lda remms_ciov_a_out
        ldy remms_ciov_y_out
        rts

; Shared one-shot operation fault selector. Carry means the current operation
; must return the configured Y status without touching the physical device.
remms_fault_check
        lda remms_fault_operation
        beq remms_fault_none
        cmp remms_session_block+REMMS_S_LAST_OPERATION
        bne remms_fault_none
        lda remms_fault_skip
        beq remms_fault_fire
        dec remms_fault_skip
remms_fault_none
        clc
        rts
remms_fault_fire
        lda remms_fault_class
        sta remms_fault_fired_class
        lda #REMMS_FAULT_CLASS_FATAL
        sta remms_fault_class
        lda #0
        sta remms_fault_operation
        ldy remms_fault_status
        sec
        rts

remms_save_dcb
        ldy #0
remms_save_dcb_loop
        lda DCB,y
        sta remms_dcb_save,y
        iny
        cpy #16
        bne remms_save_dcb_loop
        rts

remms_restore_dcb
        ldy #0
remms_restore_dcb_loop
        lda remms_dcb_save,y
        sta DCB,y
        iny
        cpy #16
        bne remms_restore_dcb_loop
        rts

; ---------------------------------------------------------------------------
; E:/R: handler tables. K: is saved for direct local input calls but is not
; installed into HATABS.
; ---------------------------------------------------------------------------

remms_e_table
        dta v(remms_e_open-1),v(remms_e_close-1),v(remms_e_get-1)
        dta v(remms_e_put-1),v(remms_e_status-1),v(remms_e_special-1)
        jmp remms_h_init

remms_r_table
        dta v(remms_rh_open-1),v(remms_rh_close-1),v(remms_rh_get-1)
        dta v(remms_rh_put-1),v(remms_rh_status-1),v(remms_rh_special-1)
        jmp remms_h_init

remms_rh_open
        pha
        lda remms_r_internal
        beq remms_rh_open_tracked_pop
        pla
        jmp remms_call_r_open
remms_rh_open_tracked_pop
        pla
remms_rh_open_tracked
        stx remms_handler_x
        lda #REMMS_OP_OPEN
        jsr remms_handler_fault_check
        bcs remms_rh_open_error
        jsr remms_call_r_open
        jsr remms_record_cio_status
        tya
        bmi remms_rh_open_error
        jsr remms_physical_open_succeeded
        jmp remms_rh_open_return
remms_rh_open_error
        jsr remms_mark_physical_closed
        lda #REMMS_ERR_CIO
        sta remms_last_error
remms_rh_open_return
        ldx remms_handler_x
        rts

remms_rh_close
        pha
        lda remms_r_internal
        beq remms_rh_close_tracked_pop
        pla
        jmp remms_call_r_close
remms_rh_close_tracked_pop
        pla
remms_rh_close_tracked
        stx remms_handler_x
        lda #REMMS_OP_CLOSE
        jsr remms_handler_fault_check
        bcs remms_rh_close_fail
        jsr remms_call_r_close
        jsr remms_record_cio_status
        tya
        bmi remms_rh_close_fail
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_CONNECTED
        bne remms_rh_close_offline
        lda #REMMS_PHYS_RESUME_PENDING
        jsr remms_physical_release_succeeded
        lda #REMMS_TRANSITION_RUN
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        ldx remms_handler_x
        ldy #CIO_SUCC
        rts
remms_rh_close_offline
        lda #REMMS_PHYS_CLOSED
        jsr remms_physical_release_succeeded
        ldx remms_handler_x
        ldy #CIO_SUCC
        rts
remms_rh_close_fail
        jsr remms_physical_ownership_fault
        ldx remms_handler_x
        rts

remms_rh_get
        pha
        lda remms_r_internal
        beq remms_rh_get_tracked_pop
        pla
        jmp remms_call_r_get
remms_rh_get_tracked_pop
        pla
remms_rh_get_tracked
        stx remms_handler_x
        lda #REMMS_OP_GET
        jsr remms_handler_fault_check
        bcc remms_rh_get_call
        jmp remms_rh_io_fail
remms_rh_get_call
        jsr remms_call_r_get
        jmp remms_rh_io_return
remms_rh_put
        pha
        lda remms_r_internal
        beq remms_rh_put_tracked_pop
        pla
        jmp remms_call_r_put
remms_rh_put_tracked_pop
        pla
remms_rh_put_tracked
        stx remms_handler_x
        sta remms_io_byte
        lda #REMMS_OP_PUT
        jsr remms_handler_fault_check
        bcs remms_rh_io_fail
        lda remms_io_byte
        jsr remms_call_r_put
        jmp remms_rh_io_return
remms_rh_status
        pha
        lda remms_r_internal
        beq remms_rh_status_tracked_pop
        pla
        jmp remms_call_r_status
remms_rh_status_tracked_pop
        pla
remms_rh_status_tracked
        stx remms_handler_x
        lda #REMMS_OP_STATUS
        jsr remms_handler_fault_check
        bcs remms_rh_io_fail
        jsr remms_call_r_status
        jmp remms_rh_io_return
remms_rh_special
        pha
        lda remms_r_internal
        beq remms_rh_special_tracked_pop
        pla
        jmp remms_call_r_special
remms_rh_special_tracked_pop
        pla
remms_rh_special_tracked
        stx remms_handler_x
        lda ICCOM,x
        sta remms_io_byte
        cmp #CIO_XIO38
        beq remms_rh_special_op38
        cmp #CIO_XIO34
        beq remms_rh_special_op34
        cmp #CIO_XIO36
        beq remms_rh_special_op36
        cmp #CIO_XIO40
        beq remms_rh_special_op40
        lda #REMMS_OP_NONE
        jmp remms_rh_special_begin
remms_rh_special_op38
        lda #REMMS_OP_XIO38
        bne remms_rh_special_begin
remms_rh_special_op34
        lda #REMMS_OP_XIO34
        bne remms_rh_special_begin
remms_rh_special_op36
        lda #REMMS_OP_XIO36
        bne remms_rh_special_begin
remms_rh_special_op40
        lda #REMMS_OP_XIO40
remms_rh_special_begin
        jsr remms_handler_fault_check
        bcs remms_rh_io_fail
        lda remms_io_byte
        jsr remms_call_r_special
remms_rh_io_return
        sta remms_cio_chr
        jsr remms_record_cio_status
        tya
        bpl remms_rh_io_ok
        lda #REMMS_ERR_CIO
        sta remms_last_error
remms_rh_io_ok
        ldx remms_handler_x
        lda remms_cio_chr
        rts
remms_rh_io_fail
        lda #REMMS_ERR_CIO
        sta remms_last_error
        ldx remms_handler_x
        lda #0
        rts

remms_handler_fault_check
        jsr remms_begin_operation
        lda remms_fault_operation
        beq remms_handler_fault_none
        cmp remms_session_block+REMMS_S_LAST_OPERATION
        bne remms_handler_fault_none
        lda remms_fault_skip
        beq remms_handler_fault_fire
        dec remms_fault_skip
        clc
        rts
remms_handler_fault_fire
        lda remms_fault_class
        sta remms_fault_fired_class
        lda #REMMS_FAULT_CLASS_FATAL
        sta remms_fault_class
        lda #0
        sta remms_fault_operation
        ldy remms_fault_status
        jsr remms_record_cio_status
        sec
        rts
remms_handler_fault_none
        clc
        rts

remms_e_open
        stx remms_handler_x
        jsr remms_call_e_open
        jmp remms_handler_saved_return
remms_e_close
        stx remms_handler_x
        jsr remms_call_e_close
        jmp remms_handler_saved_return
remms_e_get
        stx remms_handler_x
        lda remms_mode
        bne remms_remote_get
; SDX's E: get re-resolves E: through HATABS, so chain with the saved entry
; restored; the saved return reinstalls the wrapper.
        jsr remms_restore_e_handler
        ldx remms_handler_x
        jsr remms_call_e_get
        jmp remms_handler_saved_return
remms_k_get
        stx remms_handler_x
        lda remms_mode
        bne remms_remote_get
        ldx remms_handler_x
        jsr remms_call_k_get
        jmp remms_handler_saved_return

remms_remote_get
        lda #REMMS_ERR_NONE
        sta remms_last_error
remms_remote_get_wait
        jsr remms_text_get_try
        bcc remms_remote_get_ok
        jsr remms_remote_read_can_wait
        bcc remms_remote_get_wait
remms_remote_get_fail
        jmp remms_handler_remote_failure
remms_remote_get_ok

remms_handler_remote_success
        ldx remms_handler_x
        ldy #CIO_SUCC
        clc
        rts

remms_handler_remote_failure
        jsr remms_remote_error_status
        lda #0
        ldx remms_handler_x
        sec
        rts
remms_e_put
        stx remms_handler_x
        ; CIO passes the PUT byte in A.  CIOCHR is an IOCB field used by the
        ; CIO entry point and is not part of the device-handler PUT contract.
        ; In particular, exOS 0.7 leaves CIOCHR untouched when dispatching the
        ; handler, so reloading it here turns every remote byte into $00.
        ; Preserve the former instruction's two bytes so the published
        ; fixed-address REMMS image and resident-memory ceiling do not move.
        nop
        nop
        jsr remms_output_shared
        sty remms_handler_y
        bcs remms_e_put_fail
        ldx remms_handler_x
        ldy #CIO_SUCC
        clc
        rts
remms_e_put_fail
        ldy remms_handler_y
        bmi remms_e_put_fail_status_ready
        jsr remms_remote_error_status
remms_e_put_fail_status_ready
        ldx remms_handler_x
        lda remms_io_byte
        sec
        rts

; Sole text-output implementation for E:, REMMS text echo, and pager output.
; It calls the saved E: handler directly, so resident output never re-enters
; CIOV through its own wrapper.
remms_output_shared
        sta remms_io_byte
        lda remms_mode
        beq remms_output_local
        lda remms_route
        cmp #REMMS_ROUTE_REMOTE
        beq remms_output_remote
        cmp #REMMS_ROUTE_BOTH
        beq remms_output_both
remms_output_local
        ldx #REMMS_E_IOCB
        lda remms_io_byte
        jsr remms_call_e_put
        tya
        bmi remms_output_fail
        lda remms_io_byte
        clc
        rts
remms_output_remote
        lda remms_io_byte
        jmp remms_e_put_remote_byte
remms_output_both
        lda remms_io_byte
        jsr remms_e_put_remote_byte
        bcs remms_output_fail
        bcc remms_output_local
remms_output_fail
        lda remms_io_byte
        sec
        rts

remms_e_put_remote_byte
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        beq remms_e_put_remote_online
        lda #REMMS_ERR_CARRIER_LOST
        sta remms_last_error
        jsr remms_mark_carrier_lost
        sec
        rts
remms_e_put_remote_online
        lda remms_io_byte
        sta remms_eol_save
        lda remms_session_block+REMMS_S_AMODE
        beq remms_e_put_remote_translate
        ; Mode 33 is raw ASCII text. Unlike binary/raw mode 32, it still
        ; honors LMODE for the CR line endings stored in .TXT screens.
        cmp #33
        bne remms_e_put_remote_raw
        lda remms_eol_save
        cmp #13
        beq remms_e_put_remote_eol
        bne remms_e_put_remote_raw
remms_e_put_remote_translate
        lda remms_eol_save
        cmp #EOL
        beq remms_e_put_remote_eol
        ; exBASIC under SDX emits an ASCII CR for PRINT's channel newline.
        ; Treat both forms as a logical EOL so LMODE can append the LF.
        cmp #13
        beq remms_e_put_remote_eol
        cmp #$7D
        beq remms_e_put_remote_clear
        ldx #2
remms_e_put_remote_map_loop
        cmp remms_output_translation_from,x
        beq remms_e_put_remote_mapped
        dex
        bpl remms_e_put_remote_map_loop
        bmi remms_e_put_remote_raw
remms_e_put_remote_eol
        lda #13
        jsr remms_r_put_try
        bcs remms_e_put_remote_fail
        lda remms_session_block+REMMS_S_LMODE
        beq remms_e_put_remote_done
        lda #10
        jsr remms_r_put_try
        bcs remms_e_put_remote_fail
        bcc remms_e_put_remote_done
remms_e_put_remote_mapped
        lda remms_output_translation_to,x
        jsr remms_r_put_try
        bcs remms_e_put_remote_fail
        bcc remms_e_put_remote_done
remms_e_put_remote_clear
        lda #0
        sta remms_clear_index
remms_e_put_remote_clear_loop
        ldx remms_clear_index
        lda remms_ansi_clear,x
        beq remms_e_put_remote_done
        ; The 850 concurrent PUT handler blocks while its 32-byte queue is
        ; full.  Do not call the foreground STATUS guard from this nested E:
        ; handler: CIO enters device handlers with IRQs masked, so the guard's
        ; RTCLOK settle wait cannot advance here.
        jsr remms_r_put_try
        bcs remms_e_put_remote_clear_fail
        inc remms_clear_index
        bne remms_e_put_remote_clear_loop
remms_e_put_remote_raw
        lda remms_eol_save
        jsr remms_r_put_try
        bcs remms_e_put_remote_fail
remms_e_put_remote_done
        clc
        bcc remms_e_put_remote_return
remms_e_put_remote_clear_fail
remms_e_put_remote_fail
        sec
remms_e_put_remote_return
        lda remms_eol_save
        sta remms_io_byte
        rts
remms_e_status
        stx remms_handler_x
        jsr remms_call_e_status
        jmp remms_handler_saved_return
remms_e_special
        stx remms_handler_x
        lda ICCOM,x
        jsr remms_call_e_special
        ; falls through

; Reinstall the wrappers after a chained call; Y and the handler's flags
; pass through unchanged.
remms_handler_saved_return
        php
        pha
        jsr remms_write_handlers
        ldx remms_handler_x
        pla
        plp
        rts

remms_remote_read_can_wait
        lda remms_failure_pending
        bne remms_remote_read_stop
        lda remms_last_error
        bne remms_remote_read_stop
        lda remms_mode
        cmp #REMMS_MODE_HOST
        bne remms_remote_read_stop
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_remote_read_stop
        lda remms_session_block+REMMS_S_CONNECTION_STATE
        cmp #REMMS_CONN_CONNECTED
        bne remms_remote_read_stop
        lda remms_session_block+REMMS_S_PHYSICAL_STATE
        cmp #REMMS_PHYS_OPEN
        bne remms_remote_read_stop
        lda remms_session_block+REMMS_S_CONFIG_PROFILE
        cmp #REMMS_CONFIG_CONNECTED
        bne remms_remote_read_stop
        clc
        rts
remms_remote_read_stop
        sec
        rts

remms_remote_error_status
        ldy remms_session_block+REMMS_S_CIO_STATUS
        bmi remms_remote_error_ready
        ldy #CIO_ERR
remms_remote_error_ready
        rts

; The original E:/K: handler entry points are called directly. Re-entering
; CIOV on the same IOCB changes an ordinary PUT into a second OPEN and is
; rejected by Atari CIO with error 129.
remms_call_e_open
        dta b($20)
remms_e_open_target
        dta a(0)
        rts
remms_call_e_close
        dta b($20)
remms_e_close_target
        dta a(0)
        rts
remms_call_e_get
        dta b($20)
remms_e_get_target
        dta a(0)
        rts
remms_call_e_put
        dta b($20)
remms_e_put_target
        dta a(0)
        rts
remms_call_e_status
        dta b($20)
remms_e_status_target
        dta a(0)
        rts
remms_call_e_special
        dta b($20)
remms_e_special_target
        dta a(0)
        rts

remms_call_k_get
        dta b($20)
remms_k_get_target
        dta a(0)
        rts

remms_call_r_open
        dta b($20)
remms_r_open_target
        dta a(0)
        rts
remms_call_r_close
        dta b($20)
remms_r_close_target
        dta a(0)
        rts
remms_call_r_get
        dta b($20)
remms_r_get_target
        dta a(0)
        rts
remms_call_r_put
        dta b($20)
remms_r_put_target
        dta a(0)
        rts
remms_call_r_status
        dta b($20)
remms_r_status_target
        dta a(0)
        rts
remms_call_r_special
        dta b($20)
remms_r_special_target
        dta a(0)
        rts
