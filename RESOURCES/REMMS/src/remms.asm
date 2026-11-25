; REMMS resident core.
;
; Correctness rule: local mode never touches R:.

        icl 'os.inc'
        icl 'constants.inc'

REMMS_ZP_PTR = $D6
REMMS_E_IOCB = 3*16

REMMS_PAGER_KEY_NONE       = 0
REMMS_PAGER_KEY_ENTER      = 1
REMMS_PAGER_KEY_PAGE       = 2
REMMS_PAGER_KEY_CONTINUOUS = 3
REMMS_PAGER_KEY_QUIT       = 4
REMMS_PAGER_KEY_PAUSE      = 5
REMMS_PAGER_KEY_RESUME     = 6
REMMS_PAGER_KEY_OTHER      = 7


        icl 'remms_api.asm'
        icl 'remms_xfer.asm'
        icl 'remms_install.asm'
        icl 'remms_lifecycle.asm'
        icl 'remms_text_io.asm'
        icl 'remms_host_event.asm'
        icl 'remms_fifo.asm'
        icl 'remms_pager.asm'
        icl 'remms_handlers.asm'
        icl 'remms_data.asm'
        icl 'remms_eos_cache.asm'

; Authoritative discovery contract.  Unlike the legacy page-three mirror,
; this record is covered by MEMLO and survives every DOS executable load.
        org REMMS_LOCATOR
remms_locator_record
        dta c'RLOC'
        dta b(REMMS_LOCATOR_VERSION)
        dta b(REMMS_VERSION_MAJOR),b(REMMS_VERSION_MINOR)
        dta b(REMMS_SESSION_VERSION)
        dta a(remms_api),a(remms_public_block)
        dta a(remms_session_block),a(REMMS_END)

REMMS_END

; SpartaDOS X runs binary load files after loading. Keep the resident API jump
; table from being executed as a program by providing a harmless run stub.
; Page six is outside BASIC's allocated program/string area.
.ifndef REMMS_RELOC
        icl 'remms_text_file.asm'
.endif
