; Disk-backed text display service. The complete helper is confined to page six.

        org $0600
remms_load_return
        rts

; BASIC prepares the first 64 work bytes with an EOL-terminated path, then calls:
; result=USR($0601,ADR(path),LEN(path),ADR(work256),flags)
remms_text_file
        pla
remms_tf_args
        pla
        pla
        pla
        pla
        pla
        tax
        sta ICBAH+$10
        pla
        sta ICBAL+$10
        clc
        adc #64
        sta remms_tf_data+1
        bcc remms_tf_arg_flags
        inx
remms_tf_arg_flags
        stx remms_tf_data+2
        lda #REMMS_R_CONCURRENT_LENGTH
        sta remms_tf_limit+1
        pla
        pla
        pha
        and #1
        beq remms_tf_pager
        lda #$7D
        jsr remms_output_shared
remms_tf_pager
        pla
        and #2
        bne remms_tf_pager_begin
        lda #REMMS_PAGER_STATE_CONTINUOUS
        sta remms_session_block+REMMS_S_PAGER_STATE
        bne remms_tf_after_pager
remms_tf_pager_begin
        jsr remms_pager_begin_impl
remms_tf_after_pager
        jsr remms_tf_suspend
        bcc remms_tf_open
        jmp remms_tf_output
remms_tf_open
        ldx #$10
        lda #CIO_OPEN
        sta ICCOM,x
        lda #4
        sta ICAX1,x
        lsr
        sta ICAX2,x
        jsr CIOV
        bpl remms_tf_read
        lda #3
        bne remms_tf_cleanup
remms_tf_read
        ldx #$10
        lda remms_tf_data+1
        sta ICBAL,x
        lda remms_tf_data+2
        sta ICBAH,x
        lda #CIO_GETCHR
        sta ICCOM,x
remms_tf_read_length
        lda #REMMS_R_CONCURRENT_LENGTH
        sta ICBLL,x
        lda #0
        sta ICBLH,x
        jsr CIOV
        bmi remms_tf_short
        bne remms_tf_resume_chunk
remms_tf_short
        cpy #CIO_ERR
        bne remms_tf_disk
        lda ICBLLZ
        sta remms_tf_limit+1
        jsr remms_tf_close
remms_tf_resume_chunk
        jsr remms_tf_resume
        bcs remms_tf_output
        bit remms_public_wfc_td
        bmi remms_tf_rip_block
        ldy #0
remms_tf_emit
remms_tf_limit
        cpy #REMMS_R_CONCURRENT_LENGTH
        beq remms_tf_chunk_done
remms_tf_data
        lda $FFFF,y
        sty remms_tf_restore_y+1
        jsr remms_pager_put_impl
        bne remms_tf_pager_result
remms_tf_restore_y
        ldy #0
        iny
        bne remms_tf_emit
remms_tf_pager_result
        cmp #REMMS_PAGER_USER_ABORT
        bne remms_tf_output
        beq remms_tf_cleanup
remms_tf_chunk_done
        cpy #REMMS_R_CONCURRENT_LENGTH
        bne remms_tf_success
remms_tf_chunk_full
        jsr remms_tf_suspend
        bcc remms_tf_read
        bcs remms_tf_output
remms_tf_rip_block
        lda #CIO_PUTCHR
        jsr remms_rip_put_block
        lda ICHID+$10
        bpl remms_tf_chunk_full
remms_tf_success
        jsr remms_pager_end_impl
        jmp remms_usr_return_zero
remms_tf_disk
        lda #4
        bne remms_tf_cleanup
remms_tf_output
        lda #5
remms_tf_cleanup
        pha
        jsr remms_tf_close
        jsr remms_tf_resume
        pla
remms_tf_finish
        jmp remms_usr_return_a

remms_tf_suspend
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_tf_ok
        jmp remms_suspend_impl
remms_tf_resume
        lda remms_session_block+REMMS_S_ONLINE
        cmp #1
        bne remms_tf_ok
        lda #REMMS_OPEN_RESUME
        sta remms_session_block+REMMS_S_OPEN_POLICY
        jmp remms_open_impl
remms_tf_ok
        rts
remms_tf_close
        lda #CIO_CLOSE
        sta ICCOM+$10
        jmp CIOV

remms_text_file_end
        run remms_load_return
