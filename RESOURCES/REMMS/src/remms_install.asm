; ---------------------------------------------------------------------------
; Install and discovery
; ---------------------------------------------------------------------------

remms_boot_install
        cld
        jsr remms_raise_memlo
        jsr remms_publish_discovery
        jsr remms_session_init
        clc
        rts

remms_install
        lda remms_installed
        beq remms_install_cold
        jsr remms_publish_discovery
        jsr remms_refresh_handlers
        bcs remms_install_no_handler
        jsr remms_write_handlers
        lda #REMMS_ERR_NONE
        sta remms_last_error
        clc
        rts
remms_install_cold
        jsr remms_raise_memlo
        jsr remms_publish_discovery
        lda #'E'
        jsr remms_find_handler
        bcs remms_install_no_handler
        stx remms_e_index
        lda #'K'
        jsr remms_find_handler
        bcs remms_install_no_handler
        stx remms_k_index
        lda #'R'
        jsr remms_find_handler
        bcs remms_install_no_handler
        stx remms_r_index
        jsr remms_save_e_handler
        jsr remms_save_k_handler
        jsr remms_save_r_handler
        jsr remms_set_local_route
        lda #0
        sta remms_r_open
        sta remms_last_status
        sta remms_last_error
        sta remms_arg_value
        lda #7
        sta remms_last_consol
        lda #1
        sta remms_installed
        jsr remms_write_handlers
        jsr remms_session_init
        clc
        rts
remms_install_no_handler
        lda #REMMS_ERR_NO_HANDLER
        sta remms_last_error
        sec
        rts

remms_refresh_handlers
        lda #'E'
        jsr remms_find_handler
        bcs remms_refresh_fail
        stx remms_e_index
        lda HATABS+1,x
        cmp #<remms_e_table
        bne remms_refresh_save_e
        lda HATABS+2,x
        cmp #>remms_e_table
        beq remms_refresh_k
remms_refresh_save_e
        jsr remms_save_e_handler
remms_refresh_k
        lda #'K'
        jsr remms_find_handler
        bcs remms_refresh_fail
        stx remms_k_index
        jsr remms_save_k_handler
remms_refresh_r
        lda #'R'
        jsr remms_find_handler
        bcs remms_refresh_fail
        stx remms_r_index
        lda HATABS+1,x
        cmp #<remms_r_table
        bne remms_refresh_save_r
        lda HATABS+2,x
        cmp #>remms_r_table
        beq remms_refresh_ok
remms_refresh_save_r
        jsr remms_save_r_handler
remms_refresh_ok
        clc
        rts
remms_refresh_fail
        sec
        rts

remms_raise_memlo
        lda MEMLO+1
        cmp #>REMMS_END
        bcc remms_set_memlo
        bne remms_memlo_done
        lda MEMLO
        cmp #<REMMS_END
        bcs remms_memlo_done
remms_set_memlo
        lda #<REMMS_END
        sta MEMLO
        lda #>REMMS_END
        sta MEMLO+1
remms_memlo_done
        rts

; Byte +3 ($03EB, OS CARTCK) belongs to the 850 R: handler at runtime, so
; REMMS never writes it; the version lives in the public block (+5/+6).
remms_publish_discovery
        ldx #15
remms_publish_discovery_loop
        cpx #3
        beq remms_publish_discovery_next
        lda remms_discovery_image,x
        sta REMMS_DISCOVERY,x
remms_publish_discovery_next
        dex
        bpl remms_publish_discovery_loop
        rts
remms_discovery_image
        dta c'REM',b(0)
        dta a(remms_api),a(remms_public_block),a(REMMS_END)
        dta a(remms_session_block),a(remms_xfer_native_table)
        dta a(remms_session_block+REMMS_XFR_BASE)

remms_session_init
        lda #0
        ldx #0
remms_session_clear_loop
        sta remms_session_block,x
        inx
        bne remms_session_clear_loop
        ldx #0
remms_session_clear_high_loop
        sta remms_session_block+$100,x
        inx
        cpx #REMMS_SESSION_SIZE-$100
        bne remms_session_clear_high_loop
        lda #REMMS_SESSION_MAGIC
        sta remms_session_block+REMMS_S_MAGIC
        lda #REMMS_SESSION_VERSION
        sta remms_session_block+REMMS_S_VERSION
        lda #1
        sta remms_session_block+REMMS_S_ANSWER_RINGS
        sta remms_session_block+REMMS_S_SNOOP
        jsr remms_pager_defaults
        jsr remms_set_local_route
        ; Public console/event/status bytes through the failure scratch and
        ; fault operation are contiguous; raw, CH, physical, connection and
        ; transition are rewritten below.
        lda #0
        ldx #remms_fault_operation-remms_public_console_raw
remms_session_clear_public_loop
        sta remms_public_console_raw,x
        dex
        bpl remms_session_clear_public_loop
        sta remms_r_open
        sta remms_last_status
        sta remms_last_error
        sta remms_text_after_cr
        jsr remms_fifo_reset
        sta remms_connect_skip_lf
        sta remms_fault_skip
        sta remms_fault_class
        sta remms_fault_fired_class
        lda #7
        sta remms_last_consol
        sta remms_public_console_raw
        lda #$FF
        sta remms_public_ch
        lda #REMMS_PHYS_CLOSED
        jsr remms_set_physical_state
        lda #REMMS_CONN_LOCAL
        jsr remms_set_connection_state
        lda #REMMS_TRANSITION_NONE
        sta remms_session_block+REMMS_S_TRANSITION
        sta remms_public_transition
        jmp remms_host_reset

remms_find_handler
        sta remms_find_device
        ldx #0
remms_find_loop
        lda HATABS,x
        beq remms_find_fail
        cmp remms_find_device
        beq remms_find_ok
        inx
        inx
        inx
        cpx #36
        bcc remms_find_loop
remms_find_fail
        sec
        rts
remms_find_ok
        clc
        rts

remms_save_e_handler
        jsr remms_save_zp
        ldx remms_e_index
        lda HATABS+1,x
        sta remms_original_e_table
        sta REMMS_ZP_PTR
        lda HATABS+2,x
        sta remms_original_e_table+1
        sta REMMS_ZP_PTR+1
        ldy #0
remms_copy_e_loop
        lda (REMMS_ZP_PTR),y
        sta remms_saved_e_table,y
        iny
        cpy #12
        bne remms_copy_e_loop
        jsr remms_make_e_targets
        jmp remms_restore_zp

remms_save_k_handler
        jsr remms_save_zp
        ldx remms_k_index
        lda HATABS+1,x
        sta REMMS_ZP_PTR
        lda HATABS+2,x
        sta REMMS_ZP_PTR+1
        ldy #4
        lda (REMMS_ZP_PTR),y
        clc
        adc #1
        sta remms_k_get_target
        iny
        lda (REMMS_ZP_PTR),y
        adc #0
        sta remms_k_get_target+1
        jmp remms_restore_zp

remms_save_r_handler
        jsr remms_save_zp
        ldx remms_r_index
        lda HATABS+1,x
        sta remms_original_r_table
        sta REMMS_ZP_PTR
        lda HATABS+2,x
        sta remms_original_r_table+1
        sta REMMS_ZP_PTR+1
        ldy #0
remms_copy_r_loop
        lda (REMMS_ZP_PTR),y
        sta remms_saved_r_table,y
        iny
        cpy #12
        bne remms_copy_r_loop
        jsr remms_make_r_targets
        jmp remms_restore_zp

remms_save_zp
        lda REMMS_ZP_PTR
        sta remms_zp_saved
        lda REMMS_ZP_PTR+1
        sta remms_zp_saved+1
        rts

remms_restore_zp
        lda remms_zp_saved
        sta REMMS_ZP_PTR
        lda remms_zp_saved+1
        sta REMMS_ZP_PTR+1
        rts

remms_patch_handlers

; The saved HATABS indexes are transient session bytes that a BASIC program
; switch clears, so every rewrite locates the device entry by its letter.
remms_write_handlers
        lda #'E'
        jsr remms_find_handler
        lda #<remms_e_table
        sta HATABS+1,x
        lda #>remms_e_table
        sta HATABS+2,x
        lda #'R'
        jsr remms_find_handler
        lda #<remms_r_table
        sta HATABS+1,x
        lda #>remms_r_table
        sta HATABS+2,x
        rts

remms_restore_handlers
        lda #'R'
        jsr remms_find_handler
        lda remms_original_r_table
        sta HATABS+1,x
        lda remms_original_r_table+1
        sta HATABS+2,x
remms_restore_e_handler
        lda #'E'
        jsr remms_find_handler
        lda remms_original_e_table
        sta HATABS+1,x
        lda remms_original_e_table+1
        sta HATABS+2,x
        rts

remms_make_e_targets
        lda #<remms_saved_e_table
        sta REMMS_ZP_PTR
        lda #>remms_saved_e_table
        sta REMMS_ZP_PTR+1
        lda #<remms_e_open_target
        ldy #>remms_e_open_target
        jmp remms_make_targets

remms_make_r_targets
        lda #<remms_saved_r_table
        sta REMMS_ZP_PTR
        lda #>remms_saved_r_table
        sta REMMS_ZP_PTR+1
        lda #<remms_r_open_target
        ldy #>remms_r_open_target
remms_make_targets
        sta remms_make_dst_lo+1
        sty remms_make_dst_lo+2
        clc
        adc #1
        sta remms_make_dst_hi+1
        tya
        adc #0
        sta remms_make_dst_hi+2
        ldy #0
        ldx #6
remms_make_targets_loop
        clc
        lda (REMMS_ZP_PTR),y
        adc #1
remms_make_dst_lo
        sta $FFFF
        iny
        lda (REMMS_ZP_PTR),y
        adc #0
remms_make_dst_hi
        sta $FFFF
        iny
        clc
        lda remms_make_dst_lo+1
        adc #4
        sta remms_make_dst_lo+1
        bcc remms_make_targets_hi
        inc remms_make_dst_lo+2
remms_make_targets_hi
        clc
        lda remms_make_dst_hi+1
        adc #4
        sta remms_make_dst_hi+1
        bcc remms_make_targets_next
        inc remms_make_dst_hi+2
remms_make_targets_next
        dex
        bne remms_make_targets_loop
        rts
