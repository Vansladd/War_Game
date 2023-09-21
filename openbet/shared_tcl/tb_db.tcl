# $Id: tb_db.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $

#
# allows sql (and ultimately tcl) to be shared between customer screens
# and the admin screens - since they use different methods generating
# result sets
#
# just set USE_DB_STORE_QRY in your config file
#


namespace eval tb_db {


namespace export tb_exec_qry
namespace export tb_unprep_qry
namespace export tb_close
namespace export tb_begin_tran
namespace export tb_rollback_tran
namespace export tb_commit_tran


variable STORED_QRYS


proc tb_begin_tran {} {

	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		OB_db::db_begin_tran
	} else {
		global DB
		inf_begin_tran $DB
	}
}

proc tb_rollback_tran {} {

	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		OB_db::db_rollback_tran
	} else {
		global DB
		inf_rollback_tran $DB
	}
}

proc tb_commit_tran {} {

	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		OB_db::db_commit_tran
	} else {
		global DB
		inf_commit_tran $DB
	}
}

proc tb_store_qry { sql_proc sql {cache 0} } {
	global SHARED_SQL

	set SHARED_SQL($sql_proc) $sql
	set SHARED_SQL(cache,$sql_proc) $cache
}

proc tb_exec_qry {sql_proc args} {

	global SHARED_SQL

	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {

		variable STORED_QRYS
		if {![info exists STORED_QRYS($sql_proc)]} {
			## tb_db now has caching of query result sets

			if {[info exists SHARED_SQL(cache,$sql_proc)]} {
				set query_cache $SHARED_SQL(cache,$sql_proc)
			} else {
				set query_cache 0
			}

			OB_db::db_store_qry $sql_proc $SHARED_SQL($sql_proc) $query_cache
			set STORED_QRYS($sql_proc) 1
		}
		return [eval [list OB_db::db_exec_qry $sql_proc] $args]

	} else {

		global DB
		set stmt [inf_prep_sql $DB $SHARED_SQL($sql_proc)]
		set res  [eval "inf_exec_stmt $stmt $args"]
		inf_close_stmt $stmt
		ob::log::write INFO {DB: executing -$sql_proc- with args: $args}
		return $res

	}
}

# Un-prepare a query.
#
#   qry - The query name.
#
proc tb_unprep_qry {qry} {
	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		OB_db::db_unprep_qry $qry
	}
}

proc tb_close {rs} {

	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		OB_db::db_close $rs
	} else {
		db_close $rs
	}
}

#
# get the number of rows affected by the last statement
#
proc tb_garc name {
	if {[OT_CfgGet USE_DB_STORE_QRY 1]} {
		return [OB_db::db_garc $name]
	} else {
		# No way of knowing how many rows were affected, so return 0
		# in the hope that the calling code isn't too picky
		return 0
	}
}

# end namespace
}

