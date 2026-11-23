; REMMS exOS/SpartaDOS-X-compatible resident load file. exOS intentionally
; accepts these absolute segments and runs INITAD after loading.

.ifndef REMMS_BASE
REMMS_BASE = $1E00
.endif

        org REMMS_BASE
remms_core_base
        icl 'remms.asm'

        org MEMLO
        dta a(REMMS_END)

        org INITAD
        dta a(remms_boot_install)

        end

