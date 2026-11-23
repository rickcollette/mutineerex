; ---------------------------------------------------------------------------
; EOS RAM-disk CIO bridge
; ---------------------------------------------------------------------------
;
; EOS exposes its extended-memory RAM disk as shell drive O:, but O: is not
; installed in Atari HATABS.  exBASIC consequently receives CIO error 130 for
; a normal OPEN/RUN of O:.  This resident adapter installs O: as a CIO device.
; OPEN is parsed by EOS's own library and sent to jkernel so drive O remains
; available even though CIO has claimed its letter; operations on the returned
; handle then use EOS's normal D: handler.  All earlier HATABS entries remain
; visible because O is installed at the first free slot.

remms_cache_install
        lda #'O'
        jsr remms_find_handler
        bcs remms_cache_find_free
        lda HATABS+1,x
        cmp #<remms_cache_table
        bne remms_cache_done
        lda HATABS+2,x
        cmp #>remms_cache_table
        bne remms_cache_done
        stx remms_cache_o_index
        rts

remms_cache_find_free
        jsr remms_cache_find_eos
        bcs remms_cache_done
        lda #'D'
        jsr remms_find_handler
        bcs remms_cache_done
        lda HATABS+1,x
        sta REMMS_ZP_PTR
        lda HATABS+2,x
        sta REMMS_ZP_PTR+1
        ldy #0
remms_cache_copy_d
        lda (REMMS_ZP_PTR),y
        sta remms_cache_d_table,y
        iny
        cpy #12
        bne remms_cache_copy_d

        ldx #0
remms_cache_free_loop
        lda HATABS,x
        beq remms_cache_use_slot
        inx
        inx
        inx
        cpx #36
        bcc remms_cache_free_loop
        rts
remms_cache_use_slot
        stx remms_cache_o_index
        lda #'O'
        sta HATABS,x
        lda #<remms_cache_table
        sta HATABS+1,x
        lda #>remms_cache_table
        sta HATABS+2,x
remms_cache_done
        rts

remms_cache_table
        dta v(remms_cache_open-1),v(remms_cache_close-1)
        dta v(remms_cache_get-1),v(remms_cache_put-1)
        dta v(remms_cache_status-1),v(remms_cache_special-1)
        jmp remms_cache_init

remms_cache_open
        stx remms_cache_x_in
        lda REMMS_ZP_PTR
        sta remms_cache_zp_save
        lda REMMS_ZP_PTR+1
        sta remms_cache_zp_save+1
        ldx remms_cache_o_index
        lda #0
        sta HATABS,x
        lda remms_cache_file_p
        sta REMMS_ZP_PTR
        lda remms_cache_file_p+1
        sta REMMS_ZP_PTR+1
        ldx remms_cache_x_in
        lda ICBAL,x
        ldy #0
        sta (REMMS_ZP_PTR),y
        iny
        lda ICBAH,x
        sta (REMMS_ZP_PTR),y
        lda ICAX1,x
        sta $0778              ; EOS kernel mode
        lda #$A0              ; include hidden files, as EOS's CIO D: does
        sta $0779              ; EOS kernel scan flags
        jsr $A01B              ; EOS L_GEFINA2: parse FILE_P, return status
        bcs remms_cache_open_error
        ldy #9                 ; EOS kd_open
        jsr $0703              ; jkernel
        bmi remms_cache_open_error
        ldx remms_cache_x_in
        lda $0760              ; EOS kernel file_id
        sta ICAX6,x
        ldy #1
        bne remms_cache_open_finish
remms_cache_open_error
        tay
remms_cache_open_finish
        sty remms_cache_y_out
        lda remms_cache_zp_save
        sta REMMS_ZP_PTR
        lda remms_cache_zp_save+1
        sta REMMS_ZP_PTR+1
        ldx remms_cache_o_index
        lda #'O'
        sta HATABS,x
        ldx remms_cache_x_in
        ldy remms_cache_y_out
        rts
remms_cache_close
        sta remms_cache_a_in
        lda #1
        jmp remms_cache_dispatch
remms_cache_get
        sta remms_cache_a_in
        lda #2
        jmp remms_cache_dispatch
remms_cache_put
        sta remms_cache_a_in
        lda #3
        jmp remms_cache_dispatch
remms_cache_status
        sta remms_cache_a_in
        lda #4
        jmp remms_cache_dispatch
remms_cache_special
        sta remms_cache_a_in
        lda #5

remms_cache_dispatch
        sta remms_cache_op
        stx remms_cache_x_in
        sty remms_cache_y_in

        ; CIO assigned O:'s default unit 1.  EOS's RAM disk is drive 15.
        ; EOS d_name reads the zero-page CIO shadow, not just the IOCB.
        lda ICDNOZ
        sta remms_cache_unit_save
        lda #15
        sta ICDNOZ
        sta ICDNO,x

remms_cache_target
        lda remms_cache_op
        asl
        tay
        clc
        lda remms_cache_d_table,y
        adc #1
        sta remms_cache_call+1
        iny
        lda remms_cache_d_table,y
        adc #0
        sta remms_cache_call+2

        ; O: is always appended at the former terminator.  Clearing it makes
        ; the direct EOS D: call see the original, terminated HATABS again.
        ldx remms_cache_o_index
        lda #0
        sta HATABS,x
        ldx remms_cache_x_in
        ldy remms_cache_y_in
        lda remms_cache_a_in
remms_cache_call
        jsr $FFFF
        sta remms_cache_a_out
        sty remms_cache_y_out
        lda remms_cache_unit_save
        sta ICDNOZ
        ldx remms_cache_o_index
        lda #'O'
        sta HATABS,x
        ldx remms_cache_x_in
        lda remms_cache_a_out
        ldy remms_cache_y_out
        rts

remms_cache_init
        rts

; EOS publishes its loader symbols through jfsymbol.  Requiring _EOSDRV
; keeps this CIO bridge out of SpartaDOS X; FILE_P is the two-byte pointer
; consumed by EOS's filename parser.
remms_cache_find_eos
        lda #<remms_cache_eos_name
        ldx #>remms_cache_eos_name
        jsr $07EB              ; jfsymbol
        beq remms_cache_not_eos
        lda #<remms_cache_file_p_name
        ldx #>remms_cache_file_p_name
        jsr $07EB
        beq remms_cache_not_eos
        sta remms_cache_file_p
        stx remms_cache_file_p+1
        clc
        rts
remms_cache_not_eos
        sec
        rts

remms_cache_eos_name
        dta c'_EOSDRV '
remms_cache_file_p_name
        dta c'FILE_P  '
remms_cache_file_p
        dta a(0)

remms_cache_d_table
        dta b(0,0,0,0,0,0,0,0,0,0,0,0)
remms_cache_o_index
        dta b(0)
remms_cache_a_in
        dta b(0)
remms_cache_x_in
        dta b(0)
remms_cache_y_in
        dta b(0)
remms_cache_a_out
        dta b(0)
remms_cache_y_out
        dta b(0)
remms_cache_op
        dta b(0)
remms_cache_zp_save
        dta a(0)
remms_cache_unit_save
        dta b(0)
