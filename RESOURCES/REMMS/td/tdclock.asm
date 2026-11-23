; TDCLOCK -- compact REMMS-owned holdover clock with a COMTAB facade.
;
; SpartaDOS uses COMTAB+13..+18 as file timestamp workspace during CIO.  The
; six-byte shadow below is therefore the canonical ticking state.  TDCLOCK_GET
; restores that state to COMTAB before a BBS consumer reads it; TDCLOCK_SET
; seeds the shadow from COMTAB after WFC acquires a hardware/manual time.

.ifndef REMMS_EMBED
        org $1600
.endif

.ifndef REMMS_EMBED
FR0     = $00D4
.endif
PTRLO   = $00D6
PTRHI   = $00D7
COMTAB  = $000A
VVBLKD  = $0224
PALNTS  = $0062
SETVBV  = $E45C

tdclock_load_return
        rts

tdclock_get
        pla
        pla
        pla
        jsr tdclock_shadow_to_comtab
        lda tdclock_installed
        sta FR0
        lda #0
        sta FR0+1
        rts

tdclock_installed
        dta b($FF)
tdclock_frames
        dta b(60)
tdclock_month_days
        dta b(31,28,31,30,31,30,31,31,30,31,30,31)
tdclock_shadow
        dta b(1,1,0,0,0,0)

tdclock_set
        pla
        pla
        pla
        jsr tdclock_comtab_to_shadow
        lda tdclock_installed
        beq tdclock_set_ready
        lda VVBLKD
        sta tdclock_chain+1
        lda VVBLKD+1
        sta tdclock_chain+2
        lda #7
        ldx #>tdclock_vbi
        ldy #<tdclock_vbi
        jsr SETVBV
        inc tdclock_installed
tdclock_set_ready
        lda #0
        sta FR0
        sta FR0+1
        rts

tdclock_shadow_to_comtab
        lda COMTAB
        sta PTRLO
        lda COMTAB+1
        sta PTRHI
        ldx #5
        ldy #18
tdclock_shadow_copy_loop
        lda tdclock_shadow,x
        sta (PTRLO),y
        dey
        dex
        bpl tdclock_shadow_copy_loop
        rts

tdclock_comtab_to_shadow
        lda COMTAB
        sta PTRLO
        lda COMTAB+1
        sta PTRHI
        ldx #5
        ldy #18
tdclock_comtab_copy_loop
        lda (PTRLO),y
        sta tdclock_shadow,x
        dey
        dex
        bpl tdclock_comtab_copy_loop
        rts

tdclock_reset_frames
        lda #60
        ldx PALNTS
        beq tdclock_store_frames
        lda #50
tdclock_store_frames
        sta tdclock_frames
        rts

tdclock_vbi
        dec tdclock_frames
        beq tdclock_tick
        jmp tdclock_chain
tdclock_tick
        jsr tdclock_reset_frames
        inc tdclock_shadow+5
        lda tdclock_shadow+5
        cmp #60
        bcc tdclock_chain
        lda #0
        sta tdclock_shadow+5
        inc tdclock_shadow+4
        lda tdclock_shadow+4
        cmp #60
        bcc tdclock_chain
        lda #0
        sta tdclock_shadow+4
        inc tdclock_shadow+3
        lda tdclock_shadow+3
        cmp #24
        bcc tdclock_chain
        lda #0
        sta tdclock_shadow+3
        inc tdclock_shadow
        ldx tdclock_shadow+1
        dex
        lda tdclock_month_days,x
        cpx #1
        bne tdclock_compare_day
        lda tdclock_shadow+2
        and #3
        bne tdclock_feb_common
        lda #29
        bne tdclock_compare_day
tdclock_feb_common
        lda #28
tdclock_compare_day
        cmp tdclock_shadow
        bcs tdclock_chain
        lda #1
        sta tdclock_shadow
        inc tdclock_shadow+1
        lda tdclock_shadow+1
        cmp #13
        bcc tdclock_chain
        lda #1
        sta tdclock_shadow+1
        inc tdclock_shadow+2
        lda tdclock_shadow+2
        cmp #100
        bcc tdclock_chain
        lda #0
        sta tdclock_shadow+2
tdclock_chain
        jmp $FFFF
tdclock_end

.ifndef REMMS_EMBED
        run tdclock_load_return
.endif
