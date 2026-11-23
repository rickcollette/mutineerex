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
