; Compact string storage for RDCONF.
;
; exBASIC otherwise allocates 256 bytes on first assignment to every string.
; RDCONF runs below a mapped SDX/EOS cartridge while resident handlers may
; also be present, so bind its known-length settings and work strings before
; their first assignment.

        .export BIND_RDCONF_STRINGS

        .import fb_str_SYSOPNAME, fb_str_MODEMINIT
        .import fb_str_DATADRIVE, fb_str_MSGDRIVE
        .import fb_str_TEXTDRIVE, fb_str_FILEDRIVE
        .import fb_str_CFGFILE, fb_str_CFGTAG
        .import fb_str_IN, fb_str_S, fb_str_T, fb_str_F
        .import fb_str_NAME, fb_str_SPEC, fb_str_EXT, fb_str_DRIVE
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
.proc BIND_RDCONF_STRINGS
        bind fb_str_SYSOPNAME,  buf_sysopname
        bind fb_str_MODEMINIT,  buf_modeminit
        bind fb_str_DATADRIVE,  buf_datadrive
        bind fb_str_MSGDRIVE,   buf_msgdrive
        bind fb_str_TEXTDRIVE,  buf_textdrive
        bind fb_str_FILEDRIVE,  buf_filedrive
        bind fb_str_CFGFILE,    buf_cfgfile
        bind fb_str_CFGTAG,     buf_cfgtag
        bind fb_str_IN,         buf_in
        bind fb_str_S,          buf_s
        bind fb_str_T,          buf_t
        bind fb_str_F,          buf_f
        bind fb_str_NAME,       buf_name
        bind fb_str_SPEC,       buf_spec
        bind fb_str_EXT,        buf_ext
        bind fb_str_DRIVE,      buf_drive
        bind fb_str_AREAPATH,   buf_areapath
        bind fb_str_AREALINE,   buf_arealine
        bind fb_var_017_NORMALIZEAREAPATH_0T, buf_normalized
        ldx     #0
        rts
.endproc

; One length byte followed by the maximum number of characters.
; HEAPA is below EXB_FREE, so these buffers are part of the linked image and
; are not allocated from RDCONF's runtime heap.
        .segment "HEAPA"
buf_sysopname:  .res 41         ; 40
buf_modeminit:  .res 81         ; 80
buf_datadrive:  .res 31         ; 30
buf_msgdrive:   .res 31         ; 30
buf_textdrive:  .res 31         ; 30
buf_filedrive:  .res 31         ; 30
buf_cfgfile:    .res 17         ; D1:BBS.CFG
buf_cfgtag:     .res 15         ; MUTINREX CFG 1
buf_in:         .res 17         ; menu input
buf_s:          .res 121        ; directory/manifest line
buf_t:          .res 49         ; extension or cache target
buf_f:          .res 49         ; source path
buf_name:       .res 13         ; 8.3 name
buf_spec:       .res 49         ; source path
buf_ext:        .res 4          ; three-character extension
buf_drive:      .res 49         ; cache target path
buf_areapath:   .res 31         ; configured storage folder
buf_arealine:   .res 81         ; registry record
buf_normalized: .res 31         ; canonicalized area path
