# $Id: err.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# ==============================================================
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

proc prep_err_qrys {} {

	db_store_qry get_db_AX_code {
	select
		 desc_eng
		from
		 tAXError
	where
		 ax_error_id = ?
	}
}

proc init_err {} {
	prep_err_qrys
}


#
# reset the err_list
#

proc err_reset {} {
	global ERR_LIST

	tpDelVar ERROR
	set ERR_LIST {}

}


#
# addd an error
#

proc err_add args {

	global ERR_LIST

	set err [join $args " "]
	lappend ERR_LIST $err
	tpSetVar ERROR [llength $ERR_LIST]

	OT_LogWrite 9 "Error: $err"
}

proc err_add_unique args {

	global ERR_LIST

	set err [join $args " "]

	set reg "^${err}\$"
	if {[lsearch -regexp $ERR_LIST $reg] == -1 } {
		lappend ERR_LIST $err
	}
	tpSetVar ERROR [llength $ERR_LIST]

	OT_LogWrite 9 "Error: $err"
}


#
# print the errorlist
#

proc err_get_list {} {
	global ERR_LIST

	return $ERR_LIST
}

proc err_numerrs {} {
	global ERR_LIST

	return [llength $ERR_LIST]
}


#pass the AX error code or a string containing that code
#returns the english description
proc get_db_AX_err {err_string} {
	if [regexp {AX([0-9]+)} $err_string all err_code] {
	set rs [db_exec_qry get_db_AX_code $err_code]
	if {[db_get_nrows $rs] == 1 } {
		set err_desc [db_get_col $rs 0 desc_eng]
		db_close $rs
		return $err_desc
	} else {
		db_close $rs
		return "Unknown database error"
	}
	} else {
	return "Unknown database error"
	}
}
