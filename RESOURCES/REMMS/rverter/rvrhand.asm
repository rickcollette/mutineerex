; RVRHAND -- compact REMMS R: backend for direct POKEY R-Verter hardware.
;
; Build profiles:
;   RVR_FULL=1  motor-control output is DTR and PIA CRX/DSR inputs are wired.
;   RVR_FULL=0  RX/TX only; XIO 34 hangup uses guarded Hayes +++ / ATH.
;
; REMMS owns translation, modem state, text policy, and overflow recovery.
; This handler owns only raw serial transport and the physical control lines.

.ifndef RVR_FULL
RVR_FULL = 1
.endif

; exOS DEVICE and SpartaDOS X both load this relocatable block at MEMLO.
; Mutineer-eX packages it with a lowercase .sys extension for native EOSFS.
INSTALL smb 'INSTALL'
S_ADDIZ smb 'S_ADDIZ'

        blk sparta $3000
rvr_loader
        lda rvr_install_vector
        ldx rvr_install_vector+1
        jsr S_ADDIZ
        bcs rvr_loader_fail
        dec INSTALL
        jmp rvr_install
rvr_loader_fail
        rts
rvr_install_vector
        dta v(rvr_install)

; OS and CIO
DOSINI  = $000C
POKMSK  = $0010
RTCLOK2 = $0014
ICCOMZ  = $0022
ICBALZ  = $0024
ICBAHZ  = $0025
ICBLLZ  = $0028
ICBLHZ  = $0029
ICAX1Z  = $002A
ICAX2Z  = $002B
INVEC   = $020A
OUTVEC  = $020C
TDNVEC  = $020E
SSKCTL  = $0232
INITAD  = $02E2
MEMLO   = $02E7
DVSTAT  = $02EA
HATABS  = $031A

; POKEY and PIA
AUDF1   = $D200
AUDF2   = $D202
AUDF3   = $D204
AUDF4   = $D206
AUDCTL  = $D208
SERIN   = $D20D
SEROUT  = $D20D
IRQEN   = $D20E
SKCTL   = $D20F
PORTA   = $D300
PORTB   = $D301
PACTL   = $D302
PBCTL   = $D303

; Handler constants
CIO_SUCC       = 1
ERR_WRITE_ONLY = 131
ERR_NOT_OPEN   = 133
ERR_NO_DATA    = 136
ERR_TIMEOUT    = 138
ERR_NO_CARRIER = 139
ERR_UNSUPPORTED = 146

XIO_CONTROL    = 34
XIO_BAUD       = 36
XIO_TRANSLATE  = 38
XIO_CONCURRENT = 40
XIO_IDENTIFY   = 42

IRQ_TX_DONE = $08
IRQ_TX_READY = $10
IRQ_RX_READY = $20
IRQ_SERIAL_CLEAR = $C7

RVR_TX_SIZE = 32
RVR_WAIT_TICKS = 240
RVR_GUARD_TICKS = 60

RVR_CAP_EXTERNAL = $01
RVR_CAP_DTR      = $02
RVR_CAP_CARRIER  = $04
RVR_CAP_HANGUP   = $08
RVR_CAP_DRAIN    = $10

.if RVR_FULL
RVR_CAPS = RVR_CAP_EXTERNAL|RVR_CAP_DTR|RVR_CAP_CARRIER|RVR_CAP_HANGUP|RVR_CAP_DRAIN
.else
RVR_CAPS = RVR_CAP_EXTERNAL|RVR_CAP_HANGUP|RVR_CAP_DRAIN
.endif

        blk reloc main

rvr_entry
        jmp rvr_install

rvr_table
        dta a(rvr_open-1),a(rvr_close-1),a(rvr_get-1)
        dta a(rvr_put-1),a(rvr_status-1),a(rvr_special-1)
        jmp rvr_init

; Resident state. The receive bytes live in the XIO 40 buffer, not here.
rvr_mode             dta b(0)
rvr_concurrent       dta b(0)
rvr_io_on            dta b(0)
rvr_rx_capacity      dta b(0)
rvr_rx_head          dta b(0)
rvr_rx_tail          dta b(0)
rvr_rx_count         dta b(0)
rvr_rx_overflow      dta b(0)
rvr_rx_byte          dta b(0)
rvr_tx_head          dta b(0)
rvr_tx_tail          dta b(0)
rvr_tx_count         dta b(0)
rvr_tx_idle          dta b(1)
rvr_tx_done          dta b(0)
rvr_tx_byte_save     dta b(0)
rvr_wait_start       dta b(0)
rvr_handshake_mask   dta b(0)
rvr_line_retries     dta b(0)
rvr_baud_divisor     dta a(86)
rvr_old_pokmsk       dta b(0)
rvr_old_sskctl       dta b(0)
rvr_old_invec        dta a(0)
rvr_old_outvec       dta a(0)
rvr_old_tdnvec       dta a(0)
rvr_reloc_vectors    dta a(rvr_input_irq,rvr_output_irq,rvr_done_irq,rvr_table)
rvr_tx_buffer
        .rept RVR_TX_SIZE
        dta b(0)
        .endr

; ---------------------------------------------------------------------------
; CIO entries
; ---------------------------------------------------------------------------

rvr_open
        lda rvr_mode
        beq rvr_open_free
        jmp rvr_err_not_open
rvr_open_free
        lda ICAX1Z
        cmp #$0D
        beq rvr_open_mode_ok
        jmp rvr_err_unsupported
rvr_open_mode_ok
        sta rvr_mode
        lda #0
        sta rvr_concurrent
        sta rvr_rx_count
        sta rvr_rx_overflow
        sta rvr_tx_count
        sta rvr_tx_head
        sta rvr_tx_tail
        lda #1
        sta rvr_tx_idle
        jmp rvr_ok

rvr_close
        lda rvr_mode
        bne rvr_close_open
        jmp rvr_err_not_open
rvr_close_open
        lda rvr_io_on
        beq rvr_close_stop
        jsr rvr_tx_drain
        php
        jsr rvr_serial_stop
        plp
        bcc rvr_close_stop
        jmp rvr_err_timeout
rvr_close_stop
        lda #0
        sta rvr_mode
        sta rvr_concurrent
        jmp rvr_ok

rvr_get
        lda rvr_concurrent
        bne rvr_get_open
        jmp rvr_err_not_open
rvr_get_open
        php
        sei
        lda rvr_rx_count
        beq rvr_get_empty
        ldx rvr_rx_tail
rvr_rx_load
        lda $FFFF,x
        pha
        inx
        cpx rvr_rx_capacity
        bcc rvr_get_tail_ok
        ldx #0
rvr_get_tail_ok
        stx rvr_rx_tail
        dec rvr_rx_count
        pla
        plp
        ldy #CIO_SUCC
        rts
rvr_get_empty
        plp
        ldy #ERR_NO_DATA
        rts

rvr_put
        pha
        lda rvr_concurrent
        beq rvr_put_not_open
        pla
        jsr rvr_tx_byte
        bcc rvr_put_ok
        jmp rvr_err_timeout
rvr_put_ok
        jmp rvr_ok
rvr_put_not_open
        pla
        jmp rvr_err_not_open

rvr_status
        lda rvr_mode
        bne rvr_status_open
        jmp rvr_err_not_open
rvr_status_open
        lda rvr_rx_overflow
        bne rvr_status_overflow
        php
        sei
        lda rvr_rx_count
        sta DVSTAT+1
        lda #0
        sta DVSTAT+2
        lda rvr_tx_count
        ldx rvr_tx_idle
        bne rvr_status_tx_ready
        clc
        adc #1
rvr_status_tx_ready
        sta DVSTAT+3
        plp
        lda #0
        sta DVSTAT
        ldy #CIO_SUCC
        rts
rvr_status_overflow
        ldy #ERR_NO_DATA
        rts

rvr_special
        lda ICCOMZ
        cmp #XIO_IDENTIFY
        beq rvr_identify
        lda rvr_mode
        bne rvr_special_open
        jmp rvr_err_not_open
rvr_special_open
        lda rvr_concurrent
        beq rvr_special_block
        jmp rvr_err_unsupported
rvr_special_block
        lda ICCOMZ
        cmp #XIO_TRANSLATE
        beq rvr_xio_translate
        cmp #XIO_BAUD
        beq rvr_xio_baud
        cmp #XIO_CONTROL
        beq rvr_xio_control
        cmp #XIO_CONCURRENT
        beq rvr_xio_concurrent
        jmp rvr_err_unsupported

rvr_identify
        lda #'R'
        sta DVSTAT
        lda #'V'
        sta DVSTAT+1
        lda #1
        sta DVSTAT+2
        lda #RVR_CAPS
        sta DVSTAT+3
        ldy #CIO_SUCC
        rts

rvr_xio_translate
        lda ICAX1Z
        and #$30
        cmp #$20
        beq rvr_xio_translate_ok
        jmp rvr_err_unsupported
rvr_xio_translate_ok
        jmp rvr_ok

rvr_xio_baud
        lda ICAX1Z
        and #$0F
        asl
        tax
        lda rvr_baud_table,x
        sta rvr_baud_divisor
        lda rvr_baud_table+1,x
        sta rvr_baud_divisor+1
.if RVR_FULL
        ldx #0
        lda ICAX2Z
        and #$05
        beq rvr_baud_mask_ready
        cmp #1
        beq rvr_baud_crx
        cmp #4
        beq rvr_baud_dsr
        ldx #$88
        bne rvr_baud_mask_ready
rvr_baud_crx
        ldx #$08
        bne rvr_baud_mask_ready
rvr_baud_dsr
        ldx #$80
rvr_baud_mask_ready
        stx rvr_handshake_mask
.else
        lda #0
        sta rvr_handshake_mask
.endif
        jmp rvr_ok

rvr_xio_control
        lda ICAX1Z
        cmp #$80
        beq rvr_control_hangup
        cmp #$F0
        beq rvr_control_ready
        jmp rvr_err_unsupported
rvr_control_ready
.if RVR_FULL
        lda PACTL
        and #$F7
        sta PACTL
.endif
        jmp rvr_ok
rvr_control_hangup
.if RVR_FULL
        lda PACTL
        ora #$08
        sta PACTL
.else
        jsr rvr_hayes_hangup
        bcc rvr_control_hangup_ok
        jmp rvr_err_timeout
rvr_control_hangup_ok
.endif
        jmp rvr_ok

rvr_xio_concurrent
        lda ICBLHZ
        beq rvr_xio_length_low
        jmp rvr_err_unsupported
rvr_xio_length_low
        lda ICBLLZ
        bne rvr_xio_length_ok
        jmp rvr_err_unsupported
rvr_xio_length_ok
        sta rvr_rx_capacity
        lda ICBALZ
        sta rvr_rx_store+1
        sta rvr_rx_load+1
        lda ICBAHZ
        sta rvr_rx_store+2
        sta rvr_rx_load+2
        lda #0
        sta rvr_rx_head
        sta rvr_rx_tail
        sta rvr_rx_count
        sta rvr_rx_overflow
        sta rvr_tx_count
        sta rvr_tx_head
        sta rvr_tx_tail
.if RVR_FULL
        lda rvr_handshake_mask
        beq rvr_xio_start
        lda #3
        sta rvr_line_retries
rvr_xio_sample_lines
        jsr rvr_sample_lines
        and rvr_handshake_mask
        cmp rvr_handshake_mask
        beq rvr_xio_start
        dec rvr_line_retries
        bne rvr_xio_sample_lines
        jmp rvr_err_no_carrier
.endif
rvr_xio_start
        jsr rvr_serial_start
        lda #1
        sta rvr_concurrent
        jmp rvr_ok

rvr_ok
        ldy #CIO_SUCC
        rts
rvr_err_not_open
        ldy #ERR_NOT_OPEN
        rts
rvr_err_timeout
        ldy #ERR_TIMEOUT
        rts
rvr_err_no_carrier
        ldy #ERR_NO_CARRIER
        rts
rvr_err_unsupported
        ldy #ERR_UNSUPPORTED
        rts

rvr_init
        ldy #CIO_SUCC
        tya
        rts

; ---------------------------------------------------------------------------
; Serial engine
; ---------------------------------------------------------------------------

rvr_serial_start
        lda rvr_io_on
        beq rvr_serial_start_needed
        rts
rvr_serial_start_needed
        php
        sei
        lda POKMSK
        sta rvr_old_pokmsk
        lda SSKCTL
        sta rvr_old_sskctl
        lda INVEC
        sta rvr_old_invec
        lda INVEC+1
        sta rvr_old_invec+1
        lda OUTVEC
        sta rvr_old_outvec
        lda OUTVEC+1
        sta rvr_old_outvec+1
        lda TDNVEC
        sta rvr_old_tdnvec
        lda TDNVEC+1
        sta rvr_old_tdnvec+1
        lda rvr_reloc_vectors
        sta INVEC
        lda rvr_reloc_vectors+1
        sta INVEC+1
        lda rvr_reloc_vectors+2
        sta OUTVEC
        lda rvr_reloc_vectors+3
        sta OUTVEC+1
        lda rvr_reloc_vectors+4
        sta TDNVEC
        lda rvr_reloc_vectors+5
        sta TDNVEC+1
        lda #$78
        sta AUDCTL
        lda rvr_baud_divisor
        sta AUDF1
        sta AUDF3
        lda rvr_baud_divisor+1
        sta AUDF2
        sta AUDF4
        lda #$73
        sta SSKCTL
        sta SKCTL
        ; The OS 850 path gates serial I/O with the SIO motor-control line.
        ; It is DTR on full-handshake hardware and harmless when that wire is
        ; absent on a two-wire R-Verter, so assert it for both profiles.
        lda PACTL
        and #$F7
        sta PACTL
        lda rvr_old_pokmsk
        and #IRQ_SERIAL_CLEAR
        ora #IRQ_RX_READY
        sta POKMSK
        sta IRQEN
        lda #1
        sta rvr_tx_idle
        sta rvr_io_on
        plp
rvr_serial_started
        rts

rvr_serial_stop
        lda rvr_io_on
        beq rvr_serial_stopped
        php
        sei
        lda rvr_old_pokmsk
        sta POKMSK
        sta IRQEN
        lda rvr_old_invec
        sta INVEC
        lda rvr_old_invec+1
        sta INVEC+1
        lda rvr_old_outvec
        sta OUTVEC
        lda rvr_old_outvec+1
        sta OUTVEC+1
        lda rvr_old_tdnvec
        sta TDNVEC
        lda rvr_old_tdnvec+1
        sta TDNVEC+1
        lda rvr_old_sskctl
        sta SSKCTL
        sta SKCTL
        lda #0
        sta AUDCTL
        sta rvr_io_on
        sta rvr_concurrent
        plp
rvr_serial_stopped
        rts

; Queue A for transmission. Carry means the bounded queue wait expired.
rvr_tx_byte
        sta rvr_tx_byte_save
        php
        cli
        lda RTCLOK2
        sta rvr_wait_start
rvr_tx_retry
        sei
        lda rvr_tx_idle
        beq rvr_tx_enqueue
        lda rvr_tx_count
        bne rvr_tx_enqueue
        ; Arm TX-ready while IRQs are still masked, then hand the byte to
        ; POKEY. Doing this in the opposite order can lose the immediate
        ; ready transition for the last byte of a command. The modem still
        ; receives that byte, but rvr_tx_idle never returns to one and the
        ; next CLOSE times out while REMMS rebuilds the connected stream.
        lda #0
        sta rvr_tx_idle
        jsr rvr_enable_tx_irq
        lda rvr_tx_byte_save
        sta SEROUT
        plp
        clc
        rts
rvr_tx_enqueue
        lda rvr_tx_count
        cmp #RVR_TX_SIZE
        bcc rvr_tx_store
        cli
        lda RTCLOK2
        sec
        sbc rvr_wait_start
        cmp #RVR_WAIT_TICKS
        bcc rvr_tx_retry
        plp
        sec
        rts
rvr_tx_store
        ldx rvr_tx_head
        lda rvr_tx_byte_save
        sta rvr_tx_buffer,x
        inx
        cpx #RVR_TX_SIZE
        bcc rvr_tx_head_ok
        ldx #0
rvr_tx_head_ok
        stx rvr_tx_head
        inc rvr_tx_count
        jsr rvr_enable_tx_irq
        plp
        clc
        rts

rvr_enable_tx_irq
        lda POKMSK
        ora #IRQ_TX_READY
        sta POKMSK
        sta IRQEN
        rts

; Drain queued bytes and the final shift register. Carry means timeout.
rvr_tx_drain
        lda rvr_tx_count
        bne rvr_drain_begin
        lda rvr_tx_idle
        bne rvr_drain_empty
rvr_drain_begin
        php
        cli
        lda #$FF
        sta rvr_tx_done
        lda RTCLOK2
        sta rvr_wait_start
rvr_drain_wait
        lda rvr_tx_count
        bne rvr_drain_timeout_check
        lda rvr_tx_idle
        beq rvr_drain_timeout_check
        ; OUTVEC says the final byte has reached POKEY's shift register.
        ; Enable TDNVEC only now; enabling it while the queue is active races
        ; transmit-ready on real POKEY and can strand the last queued byte.
        lda #0
        sta rvr_tx_done
        lda POKMSK
        ora #IRQ_TX_DONE
        sta POKMSK
        sta IRQEN
rvr_drain_done_wait
        lda rvr_tx_done
        bne rvr_drain_ok
rvr_drain_timeout_check
        lda RTCLOK2
        sec
        sbc rvr_wait_start
        cmp #RVR_WAIT_TICKS
        bcs rvr_drain_timeout
        lda rvr_tx_done
        bmi rvr_drain_wait
        bpl rvr_drain_done_wait
rvr_drain_timeout
        lda POKMSK
        and #$F7
        sta POKMSK
        sta IRQEN
        plp
        sec
        rts
rvr_drain_ok
        plp
rvr_drain_empty
        clc
        rts

.if RVR_FULL
rvr_sample_lines
        ; CA1/CB1 expose latched transitions, not live levels. Re-arm them
        ; exactly as RHAND1C does: take the R-Verter inactive, clear both
        ; latches, select the edge, then reactivate it so asserted carrier
        ; and DSR lines produce fresh transitions. Without this sequence a
        ; CONNECT can be parsed successfully, but the selector-14 reopen
        ; rejects XIO 40 with ERR_NO_CARRIER because it samples stale flags.
        lda PACTL
        ora #$08
        sta PACTL
        ldx #4
        ldy #0
rvr_lines_off_wait
        dey
        bne rvr_lines_off_wait
        dex
        bne rvr_lines_off_wait
        lda PORTA
        lda PORTB
        lda PBCTL
        and #$FC
        sta PBCTL
        lda PACTL
        and #$FC
        sta PACTL
        and #$F7
        sta PACTL
        ldy #1
rvr_lines_on_wait
        iny
        bne rvr_lines_on_wait
        lda PBCTL
        and #$80
        sta rvr_rx_byte
        lda PACTL
        and #$80
        lsr
        lsr
        lsr
        lsr
        ora rvr_rx_byte
        rts
.else
; Two-wire hangup: one-second guards around +++, then ATH and CR.
rvr_hayes_hangup
        jsr rvr_serial_start
        jsr rvr_wait_guard
        lda #'+'
        jsr rvr_tx_byte
        bcs rvr_hayes_fail
        lda #'+'
        jsr rvr_tx_byte
        bcs rvr_hayes_fail
        lda #'+'
        jsr rvr_tx_byte
        bcs rvr_hayes_fail
        jsr rvr_tx_drain
        bcs rvr_hayes_fail
        jsr rvr_wait_guard
        ldx #0
rvr_hayes_ath_loop
        lda rvr_hayes_ath,x
        jsr rvr_tx_byte
        bcs rvr_hayes_fail
        inx
        cpx #4
        bcc rvr_hayes_ath_loop
        jsr rvr_tx_drain
        php
        jsr rvr_serial_stop
        plp
        rts
rvr_hayes_fail
        php
        jsr rvr_serial_stop
        plp
        sec
        rts
rvr_wait_guard
        php
        cli
        lda RTCLOK2
        sta rvr_wait_start
rvr_guard_loop
        lda RTCLOK2
        sec
        sbc rvr_wait_start
        cmp #RVR_GUARD_TICKS
        bcc rvr_guard_loop
        plp
        rts
rvr_hayes_ath
        dta c'ATH',b(13)
.endif

; ---------------------------------------------------------------------------
; POKEY IRQ handlers. The OS IRQ dispatcher has already pushed A.
; ---------------------------------------------------------------------------

rvr_input_irq
        tya
        pha
        txa
        pha
        lda SERIN
        sta rvr_rx_byte
        lda rvr_rx_count
        cmp rvr_rx_capacity
        bcs rvr_input_full
        ldy rvr_rx_head
        lda rvr_rx_byte
rvr_rx_store
        sta $FFFF,y
        iny
        cpy rvr_rx_capacity
        bcc rvr_input_head_ok
        ldy #0
rvr_input_head_ok
        sty rvr_rx_head
        inc rvr_rx_count
        bne rvr_input_done
rvr_input_full
        lda #1
        sta rvr_rx_overflow
rvr_input_done
        pla
        tax
        pla
        tay
        pla
        rti

rvr_output_irq
        tya
        pha
        txa
        pha
        lda rvr_tx_count
        beq rvr_output_idle
        ldx rvr_tx_tail
        lda rvr_tx_buffer,x
        sta SEROUT
        inx
        cpx #RVR_TX_SIZE
        bcc rvr_output_tail_ok
        ldx #0
rvr_output_tail_ok
        stx rvr_tx_tail
        dec rvr_tx_count
        jmp rvr_output_done
rvr_output_idle
        lda #1
        sta rvr_tx_idle
        lda POKMSK
        and #$EF
        sta POKMSK
        sta IRQEN
rvr_output_done
        pla
        tax
        pla
        tay
        pla
        rti

rvr_done_irq
        lda #1
        sta rvr_tx_done
        lda POKMSK
        and #$F7
        sta POKMSK
        sta IRQEN
        pla
        rti

rvr_baud_table
        dta a(2976,19661,17891,15727,11925,8128,6646,5958)
        ; Altirra's modem command channel remains at 9600 even when the
        ; negotiated connection rate is 19200. REMMS uses selector 15 while
        ; waiting/issuing AT commands and selector 14 after CONNECT.
        dta a(2976,1484,739,490,366,179,40,86)

; ---------------------------------------------------------------------------
; Installation
; ---------------------------------------------------------------------------

rvr_install
        cld
        lda #0
        sta rvr_mode
        sta rvr_concurrent
        sta rvr_io_on
        ldx #0
        ldy #12
rvr_find_handler
        lda HATABS,x
        beq rvr_handler_slot
        cmp #'R'
        beq rvr_handler_slot
        inx
        inx
        inx
        dey
        bne rvr_find_handler
        rts
rvr_handler_slot
        lda #'R'
        sta HATABS,x
        lda rvr_reloc_vectors+6
        sta HATABS+1,x
        lda rvr_reloc_vectors+7
        sta HATABS+2,x
rvr_install_done
        rts

RVR_END

        blk update address
        blk update symbols

        end
