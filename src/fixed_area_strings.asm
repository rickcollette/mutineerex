; Area-path strings are linked only into WFC, MESSAGE, and FILES. Keeping
; them out of MAINBBS and door programs preserves those modules' EOS heap.

        .export BIND_AREA_STRINGS
        .import fb_str_AREAPATH, fb_str_AREALINE
        .import fb_var_017_NORMALIZEAREAPATH_0T

.macro bind var, buffer
        lda     #<buffer
        sta     var
        lda     #>buffer
        sta     var+1
        lda     #0
        sta     buffer
.endmacro

        .code
.proc BIND_AREA_STRINGS
        bind fb_str_AREAPATH, buf_areapath
        bind fb_str_AREALINE, buf_arealine
        bind fb_var_017_NORMALIZEAREAPATH_0T, buf_normalized
        ldx     #0
        rts
.endproc

        .segment "HEAPA"
buf_areapath: .res 31
buf_arealine: .res 81
buf_normalized: .res 31
