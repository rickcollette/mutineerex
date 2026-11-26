; Compact global strings used by CONFIG and the area registry.  CONFIG runs
; with the EOS cartridge mapped, so ordinary 256-byte allocations for these
; known-size fields would exhaust the heap before its menu appears.

        .export BIND_CONFIG_STRINGS

        .import fb_str_SYSOPNAME, fb_str_MODEMINIT
        .import fb_str_DATADRIVE, fb_str_MSGDRIVE
        .import fb_str_TEXTDRIVE, fb_str_FILEDRIVE
        .import fb_str_CFGFILE, fb_str_CFGTAG
        .import fb_str_IN, fb_str_F, fb_str_S, fb_str_T
        .import fb_str_NAME, fb_str_DESC, fb_str_CITY, fb_str_PASS
        .import fb_str_TARGET, fb_str_NEWNAME, fb_str_OLDNAME
        .import fb_str_BASENAME, fb_str_BASEDESC
        .import fb_str_AREAPATH, fb_str_AREALINE
        .import fb_var_09_AREATITLE_0R, fb_var_05_ONOFF_0R
        .import fb_var_05_RNAME_0R, fb_var_09_CLOCKNAME_0R
        .import fb_var_012_CATEGORYNAME_0R
        .import fb_str_012_LOADSETTINGS_VALUE
        .import fb_var_017_NORMALIZEAREAPATH_0T
        .import fb_var_08_ASKDRIVE_0T
        .import fb_var_00__0T, fb_var_013_GENERALCONFIG_0T
        .import fb_var_011_EDITSETTING_0T
        .import fb_var_018_MESSAGEBASEMANAGER_0T
        .import fb_var_09_ASKBASEID_0T
        .import fb_var_015_FILEAREAMANAGER_0T
        .import fb_var_011_CATALOGFIND_0T
        .import fb_var_014_CATALOGREWRITE_0T
        .import fb_var_015_ASKFILEMETADATA_0T
        .import fb_var_017_ADDCONTROLLEDFILE_0T
        .import fb_var_018_EDITCONTROLLEDFILE_0T
        .import fb_var_020_REMOVECONTROLLEDFILE_0T

.macro bind var, buffer
        lda     #<buffer
        sta     var
        lda     #>buffer
        sta     var+1
        lda     #0
        sta     buffer
.endmacro

        .code
.proc BIND_CONFIG_STRINGS
        bind fb_str_SYSOPNAME, buf_sysopname
        bind fb_str_MODEMINIT, buf_modeminit
        bind fb_str_DATADRIVE, buf_datadrive
        bind fb_str_MSGDRIVE,  buf_msgdrive
        bind fb_str_TEXTDRIVE, buf_textdrive
        bind fb_str_FILEDRIVE, buf_filedrive
        bind fb_str_CFGFILE,   buf_cfgfile
        bind fb_str_CFGTAG,    buf_cfgtag
        bind fb_str_IN,        buf_in
        bind fb_str_F,         buf_f
        bind fb_str_S,         buf_s
        bind fb_str_T,         buf_t
        bind fb_str_NAME,      buf_name
        bind fb_str_DESC,      buf_desc
        bind fb_str_CITY,      buf_city
        bind fb_str_PASS,      buf_pass
        bind fb_str_TARGET,    buf_target
        bind fb_str_NEWNAME,   buf_newname
        bind fb_str_OLDNAME,   buf_oldname
        bind fb_str_BASENAME,  buf_basename
        bind fb_str_BASEDESC,  buf_basedesc
        bind fb_str_AREAPATH,  buf_areapath
        bind fb_str_AREALINE,  buf_arealine
        bind fb_var_09_AREATITLE_0R, buf_areatitle
        bind fb_var_05_ONOFF_0R, buf_onoff
        bind fb_var_05_RNAME_0R, buf_rname
        bind fb_var_09_CLOCKNAME_0R, buf_clockname
        bind fb_var_012_CATEGORYNAME_0R, buf_categoryname
        bind fb_str_012_LOADSETTINGS_VALUE, buf_settingvalue
        bind fb_var_017_NORMALIZEAREAPATH_0T, buf_normalized
        bind fb_var_08_ASKDRIVE_0T, buf_askdrive
        bind fb_var_00__0T, buf_main_temp
        bind fb_var_013_GENERALCONFIG_0T, buf_general_temp
        bind fb_var_011_EDITSETTING_0T, buf_editsetting_temp
        bind fb_var_018_MESSAGEBASEMANAGER_0T, buf_message_menu_temp
        bind fb_var_09_ASKBASEID_0T, buf_baseid_temp
        bind fb_var_015_FILEAREAMANAGER_0T, buf_file_menu_temp
        bind fb_var_011_CATALOGFIND_0T, buf_catalogfind_temp
        bind fb_var_014_CATALOGREWRITE_0T, buf_catalogrewrite_temp
        bind fb_var_015_ASKFILEMETADATA_0T, buf_filemeta_temp
        bind fb_var_017_ADDCONTROLLEDFILE_0T, buf_addfile_temp
        bind fb_var_018_EDITCONTROLLEDFILE_0T, buf_editfile_temp
        ; The two file-entry commands never nest, and each temporary lives
        ; for one statement, so they share one buffer.
        bind fb_var_020_REMOVECONTROLLEDFILE_0T, buf_editfile_temp
        ldx     #0
        rts
.endproc

        .segment "HEAPA"
buf_sysopname: .res 41
buf_modeminit: .res 81
buf_datadrive: .res 31
buf_msgdrive:  .res 31
buf_textdrive: .res 31
buf_filedrive: .res 31
buf_cfgfile:   .res 17
buf_cfgtag:    .res 15
buf_in:        .res 81
buf_f:         .res 81
buf_s:         .res 121
buf_t:         .res 121
buf_name:      .res 41
buf_desc:      .res 71
buf_city:      .res 31
buf_pass:      .res 7
buf_target:    .res 49
buf_newname:   .res 49
buf_oldname:   .res 49
buf_basename:  .res 33
buf_basedesc:  .res 71
buf_areapath:  .res 31
buf_arealine:  .res 81
buf_areatitle: .res 13
buf_onoff:     .res 4
buf_rname:     .res 22
buf_clockname: .res 10
buf_categoryname: .res 9
buf_settingvalue: .res 81
buf_normalized: .res 31
buf_askdrive:  .res 31
buf_main_temp: .res 81
buf_general_temp: .res 81
buf_editsetting_temp: .res 81
buf_message_menu_temp: .res 81
buf_baseid_temp: .res 81
buf_file_menu_temp: .res 81
buf_catalogfind_temp: .res 13
buf_catalogrewrite_temp: .res 13
buf_filemeta_temp: .res 81
buf_addfile_temp: .res 81
buf_editfile_temp: .res 81
