; Compact string storage for the BBS.
;
; exBASIC normally allocates 256 bytes on the first assignment to every
; string variable.  AMIS has known field limits (the original BASIC used
; DIM L$(120), NAME$(40), MSGNO$(4), and so on), so point the variables at
; buffers sized for those limits.  The BASIC code still uses ordinary
; string assignment, comparison, INPUT/PRINT and ADR operations.

        .export BIND_FIXED_STRINGS, REMMS_CALL0, REMMS_CALL1

        .import fb_str_SYSOPNAME, fb_str_MODEMINIT
        .import fb_str_DATADRIVE, fb_str_MSGDRIVE
        .import fb_str_TEXTDRIVE, fb_str_FILEDRIVE
        .import fb_str_CFGFILE, fb_str_CFGTAG
        .import fb_str_L, fb_str_S, fb_str_T, fb_str_SPEC
        .import fb_str_NAME, fb_str_ADDR, fb_str_PROMPT
        .import fb_str_NOWDATE, fb_str_NOWTIME
        .import fb_str_MSGNO, fb_str_SUBJ, fb_str_MARKER
        .import fb_str_MDATE, fb_str_MTIME
        .import fb_str_FROM, fb_str_TOWHO, fb_str_FILENAME
        .import fb_str_BASENAME, fb_str_BASEDESC, fb_str_CTRLMSG
        .import fb_str_MIF, fb_str_MDF, fb_str_CDF
        .import fb_str_USERFILE, fb_str_SYSTEMFILE, fb_str_USERPASS

.macro bind var, buffer
        lda     #<buffer
        sta     var
        lda     #>buffer
        sta     var+1
        lda     #0
        sta     buffer          ; empty string: length byte is zero
.endmacro

        .code
.proc BIND_FIXED_STRINGS
        bind fb_str_SYSOPNAME,  buf_sysopname
        bind fb_str_MODEMINIT,  buf_modeminit
        bind fb_str_DATADRIVE,  buf_datadrive
        bind fb_str_MSGDRIVE,   buf_msgdrive
        bind fb_str_TEXTDRIVE,  buf_textdrive
        bind fb_str_FILEDRIVE,  buf_filedrive
        bind fb_str_CFGFILE,    buf_cfgfile
        bind fb_str_CFGTAG,     buf_cfgtag
        bind fb_str_L,          buf_l
        bind fb_str_S,          buf_s
        bind fb_str_T,          buf_t
        bind fb_str_SPEC,       buf_spec
        bind fb_str_NAME,       buf_name
        bind fb_str_ADDR,       buf_addr
        bind fb_str_PROMPT,     buf_prompt
        bind fb_str_NOWDATE,    buf_nowdate
        bind fb_str_NOWTIME,    buf_nowtime
        bind fb_str_MSGNO,      buf_msgno
        bind fb_str_SUBJ,       buf_subj
        bind fb_str_MARKER,     buf_marker
        bind fb_str_MDATE,      buf_mdate
        bind fb_str_MTIME,      buf_mtime
        bind fb_str_FROM,       buf_from
        bind fb_str_TOWHO,      buf_towho
        bind fb_str_FILENAME,   buf_filename
        bind fb_str_BASENAME,   buf_basename
        bind fb_str_BASEDESC,   buf_basedesc
        bind fb_str_CTRLMSG,    buf_ctrlmsg
        bind fb_str_MIF,        buf_mif
        bind fb_str_MDF,        buf_mdf
        bind fb_str_CDF,        buf_cdf
        bind fb_str_USERFILE,   buf_userfile
        bind fb_str_SYSTEMFILE, buf_systemfile
        bind fb_str_USERPASS,   buf_userpass
        ldx     #0
        rts
.endproc

; REMMS 1.10 deliberately publishes the Atari BASIC USR convention: its
; entry points pull an argument count and arguments from the CPU stack and
; return the 16-bit value in FR0.  exBASIC instead pushes only its 16-bit
; arguments and expects A/X.  These two small thunks translate the calling
; convention without changing the public REMMS ABI or any EOS driver.
FR0 = $00D4

.proc REMMS_CALL0
        pla                         ; target high
        sta     remms_target+1
        pla                         ; target low
        sta     remms_target
        lda     #>(remms_return-1)
        pha
        lda     #<(remms_return-1)
        pha
        lda     #0                  ; Atari BASIC argument count
        pha
        jmp     (remms_target)
.endproc

.proc REMMS_CALL1
        pla                         ; value high
        sta     remms_value+1
        pla                         ; value low
        sta     remms_value
        pla                         ; target high
        sta     remms_target+1
        pla                         ; target low
        sta     remms_target
        lda     #>(remms_return-1)
        pha
        lda     #<(remms_return-1)
        pha
        lda     remms_value         ; Atari BASIC pushes low, high, count
        pha
        lda     remms_value+1
        pha
        lda     #1
        pha
        jmp     (remms_target)
.endproc

remms_return:
        lda     FR0
        ldx     FR0+1
        rts

remms_target:  .word 0
remms_value:   .word 0

; One length byte followed by the maximum number of characters.
; HEAPA is below EXB_FREE, so FRE() automatically excludes these buffers.
        .segment "HEAPA"
buf_sysopname:  .res 41         ; 40
buf_modeminit:  .res 81         ; 80
buf_datadrive:  .res 31         ; 30
buf_msgdrive:   .res 31         ; 30
buf_textdrive:  .res 31         ; 30
buf_filedrive:  .res 31         ; 30
buf_cfgfile:    .res 17         ; 16
buf_cfgtag:     .res 15         ; MUTINREX CFG 1 (14)
buf_l:          .res 121        ; 120, original L$
buf_s:          .res 256        ; unrestricted disk/work input
buf_t:          .res 121        ; 120, original TEMP$
buf_spec:       .res 121        ; command number list
buf_name:       .res 41         ; 40
buf_addr:       .res 41         ; 40
buf_prompt:     .res 46         ; 45
buf_nowdate:    .res 11         ; MM/DD/YYYY
buf_nowtime:    .res 9          ; HH:MM:SS
buf_msgno:      .res 5          ; 4 digits
buf_subj:       .res 34         ; 33
buf_marker:     .res 2          ; + or *
buf_mdate:      .res 11         ; MM/DD/YYYY
buf_mtime:      .res 9          ; HH:MM:SS
buf_from:       .res 41         ; 40
buf_towho:      .res 41         ; 40
buf_filename:   .res 65         ; 30-char drive/folder + 12-char name
buf_basename:   .res 33         ; 32
buf_basedesc:   .res 71         ; 70
buf_ctrlmsg:    .res 47         ; original CTRL$(46)
buf_mif:        .res 49         ; message index path
buf_mdf:        .res 49         ; message data path
buf_cdf:        .res 49         ; callers path
buf_userfile:   .res 49         ; users path
buf_systemfile: .res 49         ; system metadata path
buf_userpass:   .res 7          ; PASSWORD,LEVEL while reading
