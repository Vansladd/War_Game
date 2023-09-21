# $Id: db-compat.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle database compatibility with non-package database APIs.
#
# The package provides wrappers for each of the older APIs which are potentially
# still been used within other shared_tcl files or the calling application.
# Avoid calling the wrapper APIs within your applications, always use the
# util_db package (ob_db namespace).
#
# The package should always be loaded when using util_db 4.5 package.
# Do not source db.tcl when using the database packages.
#
# Within standalone applications, always require the package after initialising
# the database via ob_db::sl_init, as this package initialises the database via
# non-standalone init procedure.
#
# Synopsis:
#     package require util_db_compat ?4.5?
#
# Procedures (all exported):
#    db_init                one time initialisation
#    db_store_qry           store query
#    db_unprep_qry          unprepared query
#    db_invalidate_stmt     invalidate statement
#    db_exec_qry            execute query
#    db_exec_qry_force      execute a forced named query
#    db_close               close a result set
#    db_garc                get number of rows effect by last stmt
#    db_get_serial          get serial number created by last insert
#    db_get_err_code        get last Informix error code
#    db_begin_tran          begin transaction
#    db_commit_tran         commit transaction
#    db_rollback_tran       rollback transaction
#    db_push_pdq            push PDQ
#    db_pop_pdq             pop PDQ
#    req_end                end a request
#

package provide util_db_compat 4.5


# Dependencies
# - auto initialise
#
package require util_db 4.5

ob_db::init



# Export the old namespace APIs
#
namespace eval OB_db {

	namespace export db_init
	namespace export db_store_qry
	namespace export db_unprep_qry
	namespace export db_invalidate_stmt
	namespace export db_exec_qry
	namespace export db_exec_qry_force
	namespace export db_close
	namespace export db_garc
	namespace export db_get_serial
	namespace export db_get_err_code
	namespace export db_begin_tran
	namespace export db_commit_tran
	namespace export db_rollback_tran
	namespace export db_push_pdq
	namespace export db_pop_pdq
	namespace export req_end
}



#--------------------------------------------------------------------------
# Old namespace wrappers
#--------------------------------------------------------------------------

# One time initialisation
#
proc OB_db::db_init {} {
}



# Store a named query.
#
#   name      - query name
#   qry       - SQL query
#   cache     - result set cache time (seconds)
#               disabled if DB_NO_CACHE cfg value is non-zero
#   qry_cache - not used
#
proc OB_db::db_store_qry {name qry {cache 0} {qry_cache -1}} {
	ob_db::store_qry $name $qry $cache
}



# Unprepare a query previously stored with db_store_qry.
#
#   name - query name
#
proc OB_db::db_unprep_qry {name} {
	ob_db::unprep_qry $name
}



# Mark a statement as invalid
#
#   name - query name
#
proc OB_db::db_invalidate_stmt {name} {
	ob_db::invalidate_qry $name
}



# Execute a query
#
#   name    - SQL query name
#   args    - query arguments
#   returns - query [cached] result set
#
proc OB_db::db_exec_qry {name args} {
	return [eval {ob_db::exec_qry $name} $args]
}



# Execute a named query, except that the query is run even if there
# is a suitable cached result set. Use with care.
#
#   name     - SQL query name
#   args     - query arguments
#   returns  - query [cached] result set
#
proc OB_db::db_exec_qry_force {name args} {
	return [eval {ob_db::exec_qry_force $name} $args]
}



# Close an un-cached result set.
#
#   rs - result set to close
#
proc OB_db::db_close rs {
	ob_db::rs_close $rs
}



# Get the number of rows affected by the last statement
#
#  name    - named SQL query
#  returns - number of rows affected by the last statement
#
proc OB_db::db_garc name {
	return [ob_db::garc $name]
}



# Get serial number created by the last insert
#
#   name    - stored query name
#   returns - serial number (maybe an empty string if no serial
#             number was associated with the last insert)
#
proc OB_db::db_get_serial name {
	return [ob_db::get_serial_number $name]
}



# Gets the last Informix error code
#
#   returns - last Informix error code
#
proc OB_db::db_get_err_code { {msg ""} } {
	return [ob_db::get_err_code]
}



# Begin a transaction.
#
proc OB_db::db_begin_tran args {
	ob_db::begin_tran
}



# Commit transaction
#
proc OB_db::db_commit_tran args {
	ob_db::commit_tran
}



# Rollback transaction
#
proc OB_db::db_rollback_tran args {
	ob_db::rollback_tran
}



# Set a PDQ priority.
#
#   pdq     - PDQ priority
#   returns - PDQ value set, or zero if setting of PDQs is disabled
#
proc OB_db::db_push_pdq {new_pdq} {
	return [ob_db::push_pdq $new_pdq]
}



# Reset the PDQ priority to previous setting.
#
#   returns  - PDQ value set, or zero if setting of PDQs is disabled, or the
#              list is exhausted
#
proc OB_db::db_pop_pdq {} {
	return [ob_db::pop_pdq]
}



# Denote an appserv request has ended.
#
proc OB_db::req_end {} {
	ob_db::req_end
}
