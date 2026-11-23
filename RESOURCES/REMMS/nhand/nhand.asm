; NHAND -- compact REMMS R: backend for FujiNet's N: and clock devices.
;
; The BBS and REMMS keep using the 850-shaped R: contract. This handler owns
; the translation to FujiNet SIO:
;   OPEN R:      -> OPEN N:TCP://:6507 (listening TCP server)
;   pending peer -> RING
;   ATA          -> NET_ACCEPT, CONNECT 19200
;   GET/PUT      -> NET_READ/NET_WRITE
;   XIO 34/$80   -> NET_CLOSE_CLIENT (listener remains open)
;   XIO 43       -> FujiNet clock APETIME_GETTIME into the caller's 6-byte buf
;
; exOS DEVICE loads the resident block into the same relocatable MEMLO slot
; used by SDX/RHND850. Mutineer-eX packages it as lowercase NHAND.sys.

INSTALL smb 'INSTALL'
S_ADDIZ smb 'S_ADDIZ'

        blk sparta $3000
nh_loader
        lda nh_install_vector
        ldx nh_install_vector+1
        jsr S_ADDIZ
        bcs nh_loader_fail
        dec INSTALL
        jmp nh_install
nh_loader_fail
        rts
nh_install_vector
        dta v(nh_install)

; OS/CIO/SIO
ICCOMZ  = $0022
ICBALZ  = $0024
ICBAHZ  = $0025
ICBLLZ  = $0028
ICBLHZ  = $0029
ICAX1Z  = $002A
ICAX2Z  = $002B
MEMLO   = $02E7
DVSTAT  = $02EA
HATABS  = $031A
DCB     = $0300
DDEVIC  = DCB
DUNIT   = DCB+1
DCOMND  = DCB+2
DSTATS  = DCB+3
DBUFL   = DCB+4
DBUFH   = DCB+5
DTIMLO  = DCB+6
DBYTL   = DCB+8
DBYTH   = DCB+9
DAUXL   = DCB+10
DAUXH   = DCB+11
SIOV    = $E459

; FujiNet SIO protocol, from third_party/fujinet-firmware.
FN_NET          = $71
FN_CLOCK        = $45
FN_OPEN         = 'O'
FN_CLOSE        = 'C'
FN_READ         = 'R'
FN_WRITE        = 'W'
FN_STATUS       = 'S'
FN_ACCEPT       = 'A'
FN_CLOSE_CLIENT = 'c'
FN_GET_TIME     = $93
SIO_READ        = $40
SIO_WRITE       = $80

; CIO contract
CIO_SUCC        = 1
ERR_NOT_OPEN    = 133
ERR_NO_DATA     = 136
ERR_TIMEOUT     = 138
ERR_NO_CARRIER  = 139
ERR_UNSUPPORTED = 146
XIO_CONTROL     = 34
XIO_BAUD        = 36
XIO_TRANSLATE   = 38
XIO_CONCURRENT  = 40
XIO_IDENTIFY    = 42
XIO_CLOCK       = 43
EOL             = $9B
CR              = 13
LF              = 10

NH_CLOSED = 0
NH_COMMAND = 1
NH_DATA = 2
NH_CAPS = $19                  ; external buffer, hangup, drain; no DTR/CRX

        blk reloc main

nh_entry
        jmp nh_install

nh_table
        dta a(nh_open-1),a(nh_close-1),a(nh_get-1)
        dta a(nh_put-1),a(nh_status-1),a(nh_special-1)
        jmp nh_init

; Resident state. RX bytes live in the buffer REMMS supplies with XIO 40.
nh_opened       dta b(0)
nh_network_open dta b(0)
nh_mode         dta b(NH_CLOSED)
nh_rx_capacity  dta b(0)
nh_rx_head      dta b(0)
nh_rx_tail      dta b(0)
nh_rx_count     dta b(0)
nh_cmd_pos      dta b(0)
nh_cmd_code     dta b(0)
nh_io_byte      dta b(0)
nh_count        dta a(0)
nh_net_status   dta b(0,0,0,0) ; avail lo/hi, connected, extended error
nh_reloc_vectors dta a(nh_table,nh_net_status,nh_io_byte,nh_listener_spec)

; ---------------------------------------------------------------------------
; CIO entries
; ---------------------------------------------------------------------------

nh_open
        lda nh_opened
        beq nh_open_free
        jmp nh_err_not_open
nh_open_free
        lda ICAX1Z
        cmp #$0D
        beq nh_open_mode_ok
        jmp nh_err_unsupported
nh_open_mode_ok
        lda nh_network_open
        bne nh_open_existing
        jsr nh_open_listener
        bcc nh_open_listener_ok
        rts
nh_open_listener_ok
        lda #1
        sta nh_network_open
        lda #NH_COMMAND
        sta nh_mode
nh_open_existing
        lda #$0D
        sta nh_opened
        jsr nh_clear_rx
        lda #0
        sta nh_cmd_pos
        sta nh_cmd_code
        jmp nh_ok

; CIO close releases only the Atari stream. REMMS closes and reopens R: while
; a caller is connected, so the FujiNet listener/client must survive it.
nh_close
        lda nh_opened
        bne nh_close_open
        jmp nh_err_not_open
nh_close_open
        lda #0
        sta nh_opened
        jsr nh_clear_rx
        jmp nh_ok

nh_get
        lda nh_opened
        bne nh_get_open
        jmp nh_err_not_open
nh_get_open
        lda nh_rx_count
        bne nh_get_ready
        jmp nh_err_no_data
nh_get_ready
        ldy nh_rx_head
nh_rx_load
        lda $FFFF,y
        sta nh_io_byte
        iny
        cpy nh_rx_capacity
        bcc nh_get_head_ok
        ldy #0
nh_get_head_ok
        sty nh_rx_head
        dec nh_rx_count
        bne nh_get_value
        lda #0
        sta nh_rx_head
        sta nh_rx_tail
nh_get_value
        lda nh_io_byte
        ldy #CIO_SUCC
        rts

nh_put
        sta nh_io_byte
        lda nh_opened
        bne nh_put_open
        jmp nh_err_not_open
nh_put_open
        lda nh_mode
        cmp #NH_DATA
        beq nh_put_data
        cmp #NH_COMMAND
        bne nh_put_closed
        jmp nh_put_command
nh_put_closed
        jmp nh_err_not_open

nh_put_data
        jmp nh_write_byte

nh_status
        lda nh_opened
        bne nh_status_open
        jmp nh_err_not_open
nh_status_open
        lda nh_mode
        cmp #NH_DATA
        bne nh_status_command
nh_status_data_poll
        lda nh_rx_count
        bne nh_status_report
        jsr nh_poll_network
        bcs nh_status_return
        lda nh_net_status+2
        bne nh_status_data_connected
        jmp nh_err_no_carrier
nh_status_data_connected
        lda nh_net_status
        ora nh_net_status+1
        beq nh_status_report
        jsr nh_read_network
        bcs nh_status_return
        jmp nh_status_report

nh_status_command
        lda nh_rx_count
        bne nh_status_report
        jsr nh_poll_network
        bcs nh_status_return
        lda nh_net_status+2
        bne nh_status_caller
        beq nh_status_report
nh_status_caller
        jsr nh_queue_ring

nh_status_report
        lda #0
        sta DVSTAT
        lda nh_rx_count
        sta DVSTAT+1
        lda #0
        ldx nh_mode
        cpx #NH_DATA
        bne nh_status_offline
        lda #1
nh_status_offline
        sta DVSTAT+2
        lda #0
        sta DVSTAT+3
        ldy #CIO_SUCC
nh_status_return
        rts

nh_special
        lda ICCOMZ
        cmp #XIO_IDENTIFY
        beq nh_identify
        cmp #XIO_CLOCK
        bne nh_special_not_clock
        jmp nh_clock
nh_special_not_clock
        lda nh_opened
        bne nh_special_open
        jmp nh_err_not_open
nh_special_open
        lda ICCOMZ
        cmp #XIO_TRANSLATE
        beq nh_special_ok
        cmp #XIO_BAUD
        beq nh_special_ok
        cmp #XIO_CONCURRENT
        beq nh_concurrent
        cmp #XIO_CONTROL
        beq nh_control
        cmp #15
        beq nh_special_ok
        jmp nh_err_unsupported
nh_special_ok
        jmp nh_ok

nh_concurrent
        lda ICBLHZ
        bne nh_special_bad
        lda ICBLLZ
        beq nh_special_bad
        sta nh_rx_capacity
        lda ICBALZ
        sta nh_rx_load+1
        sta nh_rx_store+1
        lda ICBAHZ
        sta nh_rx_load+2
        sta nh_rx_store+2
        jsr nh_clear_rx
        jmp nh_ok
nh_special_bad
        jmp nh_err_unsupported

nh_control
        lda ICAX1Z
        cmp #$F0
        beq nh_special_ok
        cmp #$80
        bne nh_special_bad
        jsr nh_close_client
        lda #NH_COMMAND
        sta nh_mode
        lda #0
        sta nh_cmd_pos
        sta nh_cmd_code
        jsr nh_clear_rx
        jmp nh_ok

nh_identify
        lda #'N'
        sta DVSTAT
        lda #'H'
        sta DVSTAT+1
        lda #1
        sta DVSTAT+2
        lda #NH_CAPS
        sta DVSTAT+3
        jmp nh_ok

; XIO 43 writes FujiNet's APETIME layout directly to the BASIC string passed
; as the XIO devicespec: day, month, year, hour, minute, second.
nh_clock
        lda #FN_CLOCK
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #FN_GET_TIME
        sta DCOMND
        lda #SIO_READ
        sta DSTATS
        lda ICBALZ
        sta DBUFL
        lda ICBAHZ
        sta DBUFH
        lda #6
        sta DBYTL
        lda #0
        sta DBYTH
        sta DAUXL
        sta DAUXH
        lda #$1F
        sta DTIMLO
        jsr SIOV
        ldy DSTATS
        rts

; ---------------------------------------------------------------------------
; Hayes command facade used by REMMS
; ---------------------------------------------------------------------------

nh_put_command
        lda nh_io_byte
        cmp #LF
        bne nh_command_byte
        jmp nh_ok
nh_command_byte
        cmp #CR
        beq nh_command_execute
        cmp #EOL
        beq nh_command_execute
        inc nh_cmd_pos
        ldx nh_cmd_pos
        cpx #3
        bcc nh_command_more
        cmp #'A'
        bne nh_command_more
        sta nh_cmd_code
nh_command_more
        jmp nh_ok

nh_command_execute
        lda nh_cmd_code
        cmp #'A'
        beq nh_command_answer
        jsr nh_queue_ok
        jmp nh_command_reset
nh_command_answer
        jsr nh_accept
        bcs nh_command_no_carrier
        lda #NH_DATA
        sta nh_mode
        jsr nh_queue_connect
        jmp nh_command_reset
nh_command_no_carrier
        jsr nh_queue_no_carrier
nh_command_reset
        lda #0
        sta nh_cmd_pos
        sta nh_cmd_code
        jmp nh_ok

; ---------------------------------------------------------------------------
; FujiNet network SIO operations
; ---------------------------------------------------------------------------

nh_open_listener
        lda #FN_NET
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #FN_OPEN
        sta DCOMND
        lda #SIO_WRITE
        sta DSTATS
        lda nh_reloc_vectors+6
        sta DBUFL
        lda nh_reloc_vectors+7
        sta DBUFH
        lda #0
        sta DBYTL
        lda #1
        sta DBYTH
        lda #12                    ; read/write
        sta DAUXL
        lda #0                    ; raw network bytes
        sta DAUXH
        lda #$1F
        sta DTIMLO
        jsr SIOV
        ldy DSTATS
        tya
        bmi nh_sio_fail
        clc
        rts
nh_sio_fail
        sec
        rts

nh_poll_network
        lda #FN_NET
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #FN_STATUS
        sta DCOMND
        lda #SIO_READ
        sta DSTATS
        lda nh_reloc_vectors+2
        sta DBUFL
        lda nh_reloc_vectors+3
        sta DBUFH
        lda #4
        sta DBYTL
        lda #0
        sta DBYTH
        sta DAUXL
        sta DAUXH
        lda #$1F
        sta DTIMLO
        jsr SIOV
        ldy DSTATS
        tya
        bmi nh_sio_fail
        clc
        rts

nh_read_network
        lda nh_net_status+1
        beq nh_read_low
        lda nh_rx_capacity
        bne nh_read_count
nh_read_low
        lda nh_net_status
        cmp nh_rx_capacity
        bcc nh_read_count
        lda nh_rx_capacity
nh_read_count
        sta nh_count
        lda #0
        sta nh_count+1
        sta nh_rx_head
        lda nh_count
        sta nh_rx_count
        sta nh_rx_tail
        cmp nh_rx_capacity
        bcc nh_read_tail_ok
        lda #0
        sta nh_rx_tail
nh_read_tail_ok
        lda #FN_NET
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #FN_READ
        sta DCOMND
        lda #SIO_READ
        sta DSTATS
        lda nh_rx_load+1
        sta DBUFL
        lda nh_rx_load+2
        sta DBUFH
        jsr nh_set_count
        jsr SIOV
        ldy DSTATS
        tya
        bmi nh_read_fail
        clc
        rts
nh_read_fail
        jsr nh_clear_rx
        sec
        rts

nh_write_byte
        lda #1
        sta nh_count
        lda #0
        sta nh_count+1
        lda #FN_NET
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #FN_WRITE
        sta DCOMND
        lda #SIO_WRITE
        sta DSTATS
        lda nh_reloc_vectors+4
        sta DBUFL
        lda nh_reloc_vectors+5
        sta DBUFH
        jsr nh_set_count
        jsr SIOV
        ldy DSTATS
        rts

nh_set_count
        lda nh_count
        sta DBYTL
        sta DAUXL
        lda nh_count+1
        sta DBYTH
        sta DAUXH
        lda #$1F
        sta DTIMLO
        rts

nh_accept
        lda #FN_ACCEPT
        bne nh_control_sio
nh_close_client
        lda nh_network_open
        beq nh_close_client_ok
        lda #FN_CLOSE_CLIENT
nh_control_sio
        sta DCOMND
        lda #FN_NET
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #0
        sta DSTATS
        sta DBUFL
        sta DBUFH
        sta DBYTL
        sta DBYTH
        sta DAUXL
        sta DAUXH
        lda #$1F
        sta DTIMLO
        jsr SIOV
        ldy DSTATS
        tya
        bmi nh_control_fail
nh_close_client_ok
        ldy #CIO_SUCC
        clc
        rts
nh_control_fail
        sec
        rts

; ---------------------------------------------------------------------------
; RX queue and modem result strings
; ---------------------------------------------------------------------------

nh_clear_rx
        lda #0
        sta nh_rx_head
        sta nh_rx_tail
        sta nh_rx_count
        rts

nh_queue_byte
        pha
        lda nh_rx_capacity
        beq nh_queue_drop
        lda nh_rx_count
        cmp nh_rx_capacity
        bcs nh_queue_drop
        ldy nh_rx_tail
        pla
nh_rx_store
        sta $FFFF,y
        iny
        cpy nh_rx_capacity
        bcc nh_queue_tail_ok
        ldy #0
nh_queue_tail_ok
        sty nh_rx_tail
        inc nh_rx_count
        rts
nh_queue_drop
        pla
        rts

nh_queue_ok
        ldx #0
nh_queue_ok_loop
        lda nh_rsp_ok,x
        beq nh_queue_done
        jsr nh_queue_byte
        inx
        bne nh_queue_ok_loop
nh_queue_ring
        ldx #0
nh_queue_ring_loop
        lda nh_rsp_ring,x
        beq nh_queue_done
        jsr nh_queue_byte
        inx
        bne nh_queue_ring_loop
nh_queue_connect
        ldx #0
nh_queue_connect_loop
        lda nh_rsp_connect,x
        beq nh_queue_done
        jsr nh_queue_byte
        inx
        bne nh_queue_connect_loop
nh_queue_no_carrier
        ldx #0
nh_queue_nc_loop
        lda nh_rsp_no_carrier,x
        beq nh_queue_done
        jsr nh_queue_byte
        inx
        bne nh_queue_nc_loop
nh_queue_done
        rts

nh_ok
        ldy #CIO_SUCC
        rts
nh_err_not_open
        ldy #ERR_NOT_OPEN
        rts
nh_err_no_data
        ldy #ERR_NO_DATA
        rts
nh_err_no_carrier
        ldy #ERR_NO_CARRIER
        rts
nh_err_unsupported
        ldy #ERR_UNSUPPORTED
        rts

nh_init
        ldy #CIO_SUCC
        tya
        rts

nh_listener_spec dta c'N:TCP://:6507',b(0)
nh_rsp_ok         dta b(CR,LF),c'OK',b(CR,LF,0)
nh_rsp_ring       dta b(CR,LF),c'RING',b(CR,LF,0)
nh_rsp_connect    dta b(CR,LF),c'CONNECT 19200',b(CR,LF,0)
nh_rsp_no_carrier dta b(CR,LF),c'NO CARRIER',b(CR,LF,0)

; ---------------------------------------------------------------------------
; Installation
; ---------------------------------------------------------------------------

nh_install
        cld
        lda #0
        sta nh_opened
        sta nh_network_open
        sta nh_mode
        sta nh_rx_capacity
        sta nh_rx_count
        ldx #0
        ldy #12
nh_find_handler
        lda HATABS,x
        beq nh_handler_slot
        cmp #'R'
        beq nh_handler_slot
        inx
        inx
        inx
        dey
        bne nh_find_handler
        rts
nh_handler_slot
        lda #'R'
        sta HATABS,x
        lda nh_reloc_vectors
        sta HATABS+1,x
        lda nh_reloc_vectors+1
        sta HATABS+2,x
        rts

NHAND_END

        blk update address
        blk update symbols

        end
