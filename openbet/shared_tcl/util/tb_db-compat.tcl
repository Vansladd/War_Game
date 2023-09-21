# $Id: tb_db-compat.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# This package provide methods to be backwards compatible with telebet style
# initialisation of queries.
#
# If you use this package, you may find you need to make one or two minor
# changes. Firstly, you will need to 'package require' this. Secondly, it is
# likely that you will need 'namespace import ::tb_db::*' to get access to the
# procedures. You should do this inside the namespace of the file requiring
# backwards compatibility, not in the global scope.
#
# Note: you do not need to set USE_DB_STORE_QRY to 1, the correct DB backend
# is choosen automatically.
#
# Synposis:
#   package require util_tb_db_compat ?4.5?
#
# Configuration:
#   none
#
# Procedures (all exported):
#   tb_db::tb_exec_qry      - execute a query
#   tb_db::tb_close         - close a result set
#   tb_db::tb_begin_tran    - begin a transation
#   tb_db::tb_rollback_tran - rollback a transaction
#   tb_db::tb_commit_tran   - commit a transaction
#
# See also:
#   util/db.tcl
#   tb_db.tcl
#



# Dependecies
#
package provide util_tb_db_compat 4.5

package require util_db
package require util_log



# Variables
#
namespace eval tb_db {

	namespace export tb_exec_qry
	namespace export tb_close
	namespace export tb_begin_tran
	namespace export tb_rollback_tran
	namespace export tb_commit_tran

	# This is really clever, and allows us to prepare the
	# queries on initialisation rather than wait until
	# they are first called. This means that real database
	# package can completely manage the query plans.
	#
	trace variable ::SHARED_SQL w ::tb_db::_trace_shared_sql
}



# Trace a write to the global variable SHARED_SQL, and store
# a query using it.
#
#   varname - name of the variable (SHARED_SQL)
#   index   - index in the array (the query name)
#   op      - operation (r)
#
proc tb_db::_trace_shared_sql {varname index op} {

	global SHARED_SQL

	ob_log::init
	ob_db::init

	if {$varname != "SHARED_SQL" || $op != "w"} {
		error "This proc is only for tracing writes to SHARED_SQL, \
			not $op to $varname"
	}


	# lets log a little detail about the namespace that is doing in this
	# legacy fashion
	set ns [uplevel 1 {namespace current}]

	if { [regexp {^cache,([^,]+)$} $index "" qry] } {

		ob_log::write DEV \
			{DB: Setting cache-time for $qry using variable trace for $ns}

		ob_db::cache_qry $qry $SHARED_SQL($index)

	} else {

		ob_log::write DEV {DB: Preparing $index using variable trace for $ns}

		if {[catch {
			ob_db::store_qry $index $SHARED_SQL($index)
		} msg]} {
			# some silly people might try and set the array twice,
			# lets deal with that here, but lets log the warning so they
			# can determine where any problems may occur if, for example,
			# the two queries with the same name are different queries
			if {[string match "*Query * already exists*" $msg]} {
				ob_log::write WARNING {DB: $msg}
			} else {
				error $msg $::errorInfo $::errorCode
			}
		}

	}

	# we no longer require this, so lets un-prepared it
	unset SHARED_SQL($index)
}



# Start a transaction
#
proc tb_db::tb_begin_tran {} {

	ob_db::init

	ob_db::begin_tran
}



# Rollback the current transation
#
proc tb_db::tb_rollback_tran {} {

	ob_db::init

	ob_db::rollback_tran
}


# Commit the current transation
#
proc tb_db::tb_commit_tran {} {

	ob_db::init

	ob_db::commit_tran
}




# Execute a query
#
#   name - name of the query
#   args - arguments
#
proc tb_db::tb_exec_qry {name args} {

	global SHARED_SQL

	ob_db::init
	
	# We are making the assumption that the first time the query is run, that
	# we know all we need to know about the query. 
	#
	if {[info exists SHARED_SQL($name)]} {
		# Assume people are in-capable of using the correct (un-specified)
		# method of caching, and check both.
		#
		if {[info exists SHARED_SQL(cache,$name)]} {
			set cache $SHARED_SQL(cache,$name)
			unset SHARED_SQL(cache,$name)
		} elseif {[info exists SHARED_SQL($name,cache)]} {
			set cache $SHARED_SQL($name,cache)
			unset SHARED_SQL($name,cache)
		} else {
			set cache 0
		}
		
		# If the query is re-created after this, someone has re-used the name
		# of the query - then we have a problem. We might have has a problem 
		# anyway.
		#
		ob_db::store_qry $name $SHARED_SQL($name) $cache
		unset SHARED_SQL($name)
	}
		

	return [eval ob_db::exec_qry $name $args]
}



# Close a result set
#
#   rs - the result set to close
#
proc tb_db::tb_close {rs} {

	ob_db::init

	ob_db::rs_close $rs
}



# Return the number of rows probably effected by the query
#
#   name    - query name
#   returns - number of rows
#
proc tb_garc name {

	ob_db::init

	return [ob_db::db_garc $name]
}
