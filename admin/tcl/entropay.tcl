# $Id: entropay.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) Orbis Technology Ltd. All rights reserved.

# insert into tAdminOp(action, desc, type) values ("ViewEntropayCardNum", "View card numbers of Entropay cards", "CSV");

# NAMESPACE_MAP = {entropay                 {shared_tcl/entropay.tcl entropay.tcl}}


# wrappers for the db_ commands in shared_tcl/db.tcl for use with admin screens for entropay ONLY
# unlike OB_db, this cleans up statement after use so that memory get freed

proc entropay::db_store_qry args {
	variable SQL

	# just store the sql
	set name [lindex $args 0]
	set sql  [lindex $args 1]

	set SQL($name)  $sql
}

proc entropay::db_exec_qry args {
	global DB
	variable SQL
	variable STMT

	# recall the sql
	set name [lindex $args 0]
	set sql  $SQL($name)

	set stmt [inf_prep_sql $DB $sql]
	set rs   [eval inf_exec_stmt $stmt [lrange $args 1 end]]

	# keep this for clean up later
	set STMT($rs) $stmt

	return $rs
}

proc entropay::db_close {rs} {
	variable STMT

	set ret [::db_close $rs]
	inf_close_stmt $STMT($rs)

	unset STMT($rs)

	if {[array size STMT] > 0} {
		ob::log::write WARNING {more that one stmt is open}
	}

	# i'm pretty confident this won't happen, but just in case (unexpected errors not cleaned up)
	# we close them all and log it
	if {[array size STMT] > 10} {
		ob::log::write ERROR {more that 10 statements are open, closing one of them, you should check your code}
		set rs [lindex [array names STMT] 0]
		db_close $rs
	}
	return $ret
}
