# ==============================================================
# $Id: export.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc create_export_file {{dest "I"} {sort ""} {type ""}} {

    global xgaQry

    if {$dest == "I"} {
		set filename [reqGetArg filename]
		set sort     [reqGetArg sort]
		set type     [reqGetArg type]
    } else {
		set filename "EXP"
    }

    set cr_date [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    if {$filename != ""} {
		append filename ".$cr_date"
    } else {
		set    filename   $cr_date
    }

    OT_LogWrite 20 "create_export_file: filename=$filename"

    if [catch {set rs [xg_exec_qry $xgaQry(create_export_file) $filename $sort $type]} msg] {
		return [handle_err "create_export_file" "error: $msg"]        
    }
    db_close $rs
    
    if {$dest == "I"} {
		X_play_file filecreated.html
    } else {

		if [catch {set rs [xg_exec_qry $xgaQry(get_export_files)]} msg] {
			return [handle_err "get_export_files" "error: $msg"]        
		} 
	
		export_file "F" [db_get_col $rs 0 xgame_ex_file_id]
    }
    
}

proc H_GoViewExportFiles args {
    global xgaQry
	global XGAME_TYPES EXPORT_FILES

    if [catch {set rs [xg_exec_qry $xgaQry(get_export_files)]} msg] {
		return [handle_err "get_export_files" "error: $msg"]        
    }

    set nrows [db_get_nrows $rs]

	tpSetVar NumExportFiles $nrows

    for {set i 0} {$i < $nrows} {incr i} {
		set EXPORT_FILES($i,file_id) [db_get_col $rs $i xgame_ex_file_id]
		set EXPORT_FILES($i,type)    [db_get_col $rs $i type]
		set EXPORT_FILES($i,cr_date) [db_get_col $rs $i cr_date]
		set EXPORT_FILES($i,name)    [db_get_col $rs $i filename]
    }

    db_close $rs

	tpBindVar FILE_ID   EXPORT_FILES file_id file_idx
	tpBindVar FILE_TYPE EXPORT_FILES type    file_idx
	tpBindVar FILE_DATE EXPORT_FILES cr_date file_idx
	tpBindVar FILE_NAME EXPORT_FILES name    file_idx

    bind_game_type_dropdown

    X_play_file viewexportfiles.html
}
