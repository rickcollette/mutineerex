; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------

; Private transient bytes live in gaps that are reserved but otherwise unused
; by session contract 9. Session initialization clears them with the rest of
; the session block, and no value is required across a BASIC program switch.
remms_find_device               = remms_clear_index
remms_e_index                   = remms_session_block+89
remms_k_index                   = remms_session_block+94
remms_r_index                   = remms_session_block+95
remms_zp_saved                  = remms_session_block+98
remms_xio_aux2                  = remms_session_block+101
; Close bookkeeping is synchronous and may reuse the resident failure scratch.
; Keep session +103..+106 exclusively owned by the BASIC statistics contract.
remms_close_error_flag          = remms_failure_active
remms_close_error_status        = remms_failure_status
remms_close_error_operation     = remms_failure_operation
; Event STATUS polling never enters the translated output path, so its one-byte
; before/after snapshot may share the otherwise idle EOL translation scratch.
remms_event_previous_connection = remms_eol_save
remms_ciov_a_in                 = remms_session_block+107
remms_ciov_a_out                = remms_session_block+108
remms_ciov_y_out                = remms_session_block+109
remms_r_internal                = remms_session_block+110
remms_r_caps                    = remms_session_block+111
remms_raw_ready                 = remms_session_block+112
remms_input_paused              = remms_session_block+113
remms_pager_begin_status        = remms_session_block+116
remms_pager_limit               = remms_session_block+117
remms_pager_output_byte         = remms_session_block+118
remms_pager_direct_byte         = remms_session_block+119
remms_pager_raw_byte            = remms_session_block+120
remms_pager_key_remote          = remms_session_block+121
; The transfer display field currently exposes 24 bytes. Its unused tail is
; private REMMS scratch and keeps the fixed 352-byte resident session intact.
remms_pager_resume_state        = remms_session_block+315
remms_pager_prompt_index        = remms_session_block+316

; FIFO occupancy is private session state. These holes are outside every
; published BASIC/native field and are cleared by session initialization.
remms_fifo_head                 = remms_session_block+100
remms_fifo_tail                 = remms_session_block+114
remms_fifo_count                = remms_session_block+115

remms_saved_e_table
        dta b(0,0,0,0,0,0,0,0,0,0,0,0)
remms_saved_r_table
        dta b(0,0,0,0,0,0,0,0,0,0,0,0)
remms_original_e_table
        dta a(0)
remms_original_r_table
        dta a(0)

; Text/pager input and binary transfer are mutually exclusive. Reuse the
; transfer path field as the 64-byte FIFO instead of consuming resident RAM.
remms_fifo_buffer = remms_session_block+REMMS_XFR_PATH

remms_pager_prompt_text
        dta c'--More--'
remms_pager_prompt_end
        dta b(0)

; ASCII $00-$1F to ATASCII, matching MOE's ATATAB with corrected bell.
remms_input_translation
        dta b($00,$01,$02,$03,$04,$05,$06,$FD)
        dta b($7E,$7F,$20,$0B,$7D,$9B,$0E,$0F)
        dta b($10,$11,$12,$13,$14,$15,$16,$17)
        dta b($18,$19,$1A,$1B,$20,$20,$20,$20)
remms_output_translation_from
        dta b($7E,$7F,$FD)
remms_output_translation_to
        dta b($08,$20,$07)
remms_ansi_clear
        dta b(27),c'[2J',b(27),c'[H',b(0)

remms_r_name
        dta c'R:',b(EOL)
remms_nc_text
        dta c'NO CARRIER'
remms_ring_text
        dta c'RING'
remms_connect_text
        dta c'CONNECT'
remms_text_after_cr
        dta b(0)
remms_answer_command
        dta c'ATA',b(13)
remms_sync_command
        dta c'AT',b(13)

; RIP assets are already 7-bit transport data. Copy the disk IOCB's buffer
; pointer to R:, whose length is set by RTEXT from its verified disk read,
; then let CIO perform one buffered PUT for the complete chunk. This removes
; REMMS's per-character pager and bookkeeping overhead while preserving the
; handler's normal blocking/error behavior.
remms_rip_put_block
        ldx #REMMS_R_IOCB
        sta ICCOM,x
        ldy #1
remms_rip_put_copy_iocb
        lda ICBAL+$10,y
        sta ICBAL+$50,y
        dey
        bpl remms_rip_put_copy_iocb
        jmp CIOV

; TDCLOCK_GET and TDCLOCK_SET are fixed public entry points used by BASIC at
; $3BFB and $3C1F. Keep their addresses stable after resident code shrinkage.
        dta b(0,0)
REMMS_EMBED = 1
        icl '..\td\tdclock.asm'
