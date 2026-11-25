; BOOTWAIT.COM -- SDX AUTOEXEC startup gate.
;
; Return status 0 after five seconds so AUTOEXEC.BAT continues into the BBS.
; Any buffered console key is consumed and returns status 170; the generated
; batch skips its boot block on that status and reaches a normal SDX prompt.

RTCLOK1 = $0013
RTCLOK2 = $0014
PAL     = $0062
CH      = $02FC
CONSOL  = $D01F
ERR_ABORT = 170

ERRNO   smb 'ERRNO'

        blk sparta $3000
bootwait
        lda #$01
        sta limit_hi
        lda #$2C
        sta limit_lo
        lda PAL
        beq save_start
        lda #$00
        sta limit_hi
        lda #$FA
        sta limit_lo

save_start
        lda RTCLOK1
        sta start_tick_hi
        lda RTCLOK2
        sta start_tick_lo

wait_loop
        lda CONSOL
        and #$07
        cmp #$07
        bne drop_to_dos
        lda CH
        cmp #$FF
        bne drop_to_dos

        ; RTCLOK's low 16 bits count video frames: five seconds are 300 NTSC
        ; frames ($012C) or 250 PAL frames ($00FA).
        sec
        lda RTCLOK2
        sbc start_tick_lo
        sta elapsed_lo
        lda RTCLOK1
        sbc start_tick_hi
        cmp limit_hi
        bcc wait_loop
        bne boot_bbs
        lda elapsed_lo
        cmp limit_lo
        bcc wait_loop

boot_bbs
        lda #$00
        sta ERRNO
        rts

drop_to_dos
        lda #$FF
        sta CH
        lda #ERR_ABORT
        sta ERRNO
        rts

start_tick_hi
        dta b(0)
start_tick_lo
        dta b(0)
elapsed_lo
        dta b(0)
limit_hi
        dta b(0)
limit_lo
        dta b(0)

