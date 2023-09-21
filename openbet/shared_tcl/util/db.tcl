# $Id: db.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Wrapper for Informix C API.
# Uses the util_db_multi package with the connection name 'PRIMARY'
#
# Required Configuration:
#    DB_SERVER            database server
#    DB_DATABASE          database
#    DB_USERNAME          username                              - (0)
#    DB_PASSWORD          password                              - (0)
#
# Optional Configuration:
#    DB_PREP_ONDEMAND     prepare statements on first use       - (1)
#    DB_NO_CACHE          globally disable result set cache     - (0)
#    DB_LOG_QRY_TIME      enable log query times                - (1)
#    DB_LOG_LONGQ         log all queries with exe time > value - (99999999.9)
#    DB_WAIT_TIME         set lock wait time                    - (20)
#    DB_ISOLATION_LEVEL   set isolation level                   - (0)
#    DB_DEFAULT_PDQ       the default pdq priority to use       - (0)
#    DB_MAX_PDQ           the max pdq priorities that can be    - (0)
#                         set through the interfaces
#    DB_LOG_ERR           list of error codes to log
#
# Synopsis:
#     package require util_db ?4.5?
#
# If not using the package within appserv, then load libOT_InfTcl.so and
# libOT_Tcl.so.
#
# Procedures:
#	ob_db::init                   one time initialisation (uses config file)
#	ob_db::disconnect             disconnect from the database connection
#	ob_db::sl_init                standalone one-time initialisation
#	ob_db::store_qry              stored a named query
#	ob_db::check_qry              check if a query has already been stored
#	ob_db::unprep_qry             unprepare stored named query
#	ob_db::invalidate_qry         invalidate a query
#	ob_db::exec_qry               execute a named query
#	ob_db::exec_qry_force         execute a forced named query
#	ob_db::rs_close               close a result set
#	ob_db::foreachrow             for each row procedure
#	ob_db::garc                   get number of rows effect by last stmt
#	ob_db::get_serial_number      get serial number created by last insert
#	ob_db::begin_tran             begin transaction
#	ob_db::commit_tran            commit transaction
#	ob_db::rollback_tran          rollback transaction
#	ob_db::req_end                end a request
#	ob_db::push_pdq               push PDQ
#	ob_db::pop_pdq                pop PDQ
#	ob_db::get_err_code           get last Informix error code
#   ob_db::get_column_info        get details for a given column
#

package provide util_db 4.5


# Dependencies
package require util_db_multi 4.5



# Variables
#
namespace eval ob_db {

	variable CFG
	variable INIT

	# initialised
	set INIT 0
}



# exported database connection
#
global DB



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Initialise the package and connect to request database. The database
# information is taken from a configuration file,
#
proc ob_db::init args {

	global DB
	variable CFG
	variable INIT

	# initialised the package?
	if {$INIT} {
		return
	}

	set CFG(conn_name) [OT_CfgGet DB_CONN_NAME "PRIMARY"]

	# init connection
	ob_db_multi::init $CFG(conn_name) [OT_CfgGet DB_SERVER] [OT_CfgGet DB_DATABASE]\
		-username          [OT_CfgGet DB_USERNAME         0]\
		-password          [OT_CfgGet DB_PASSWORD         0]\
		-db_port           [OT_CfgGet DB_PORT             {}]\
		-prep_ondemand     [OT_CfgGet DB_PREP_ONDEMAND    1]\
		-no_cache          [OT_CfgGet DB_NO_CACHE         0]\
		-log_qry_time      [OT_CfgGet DB_LOG_QRY_TIME     1]\
		-log_longq         [OT_CfgGet DB_LONGQ            99999999.9]\
		-log_bufreads      [OT_CfgGet DB_BUFREADS         0]\
		-log_explain       [OT_CfgGet DB_EXPLAIN          0]\
		-log_on_error      [OT_CfgGet DB_LOG_ON_ERROR     1]\
		-wait_time         [OT_CfgGet DB_WAIT_TIME        20]\
		-isolation_level   [OT_CfgGet DB_ISOLATION_LEVEL  0]\
		-default_pdq       [OT_CfgGet DB_DEFAULT_PDQ      0]\
		-max_pdq           [OT_CfgGet DB_MAX_PDQ          0]\
		-package           [OT_CfgGet DB_PACKAGE          "informix"]\
		-restart_on_error  [OT_CfgGet DB_RESTART_ON_ERROR 1]\
		-statement_timeout [OT_CfgGet DB_STMT_TIMEOUT     0]\
		-use_fetch         [OT_CfgGet DB_USE_FETCH        1]

	# backward compliance
	set DB $ob_db_multi::CONN($CFG(conn_name))

	# initialised
	set INIT 1
}



# Disconnect from the database connection
proc ob_db::disconnect {{conn_name ""}} {

	variable CFG
	variable INIT

	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::disconnect $conn_name

	set INIT 0
}



# One time initialisation.
# Initialise the package and connect to request database. The database
# information is taken from a series of arguments, allowing 'standalone'
# applications which do not support, or use, configuration files to use the
# package.
#
# NB: Caller should initialise the log file prior to using the database package,
#     as standalone log-file initialisation requires parameters which are not
#     supported in this proc.
#
#    server    - database server name
#    database  - database name
#    args      - series of name value pairs which define the optional
#                configuration
#                the name is any of the package configuration names where DB_
#                is replaced by -, e.g. DB_PREP_ONDEMAND is -prep_ondemand
#
proc ob_db::sl_init { server database args } {

	global DB
	variable CFG
	variable INIT

	# initialised the package?
	if {$INIT} {
		return
	}

	set CFG(conn_name) [OT_CfgGet DB_CONN_NAME "PRIMARY"]

	# init connection
	eval {ob_db_multi::init $CFG(conn_name) $server $database} $args

	# backward compliance
	set DB $ob_db_multi::CONN($CFG(conn_name))

	# initialised
	set INIT 1
}



#--------------------------------------------------------------------------
# Prepare Queries
#--------------------------------------------------------------------------

# Store a named query.
# If DB_PREP_ONDEMAND cfg value is set to zero, then the named query will
# be prepared. If value is set to non-zero, the query will be prepared
# the 1st time it's used.
#
#   name  - query name
#   qry   - SQL query
#   cache - result set cache time (seconds)
#           disabled if DB_NO_CACHE cfg value is non-zero
#
proc ob_db::store_qry { name qry {cache 0} {conn_name ""}} {

	variable CFG

	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::store_qry $conn_name $name $qry $cache
}



# Set the cache-time for a named query.
#
#   name      - query name
#   cache     - result set cache time (seconds)
#               disabled if DB_NO_CACHE cfg value is non-zero
#
proc ob_db::cache_qry { name cache } {
	ob_db_multi::cache_qry $name $cache
}



# Check if a name query has been stored
#
#   name - query name
#
proc ob_db::check_qry { name } {
	ob_db_multi::check_qry $name
}



# Unprepare a stored name query.
#
#   name - query name
#
proc ob_db::unprep_qry { name } {
	ob_db_multi::unprep_qry $name
}



# Invalidated a named query.
#
#   name - query name
#
proc ob_db::invalidate_qry { name } {
	ob_db_multi::invalidate_qry $name
}



#--------------------------------------------------------------------------
# Execute Queries
#--------------------------------------------------------------------------

# Execute a named query.
# The first 'arg' may include the -inc-type specifier which identifies the
# parameter types for CLOB/BLOB support.
#
#   name    - SQL query name
#   args    - query arguments
#   returns - query [cached] result set
#
proc ob_db::exec_qry {name args} {
	return [eval {ob_db_multi::exec_qry $name} $args]
}



# Execute a named query, except that the query is run even if there
# is a suitable cached result set. Use with care.
# The first 'arg' may include the -inc-type specifier which identifies the
# parameter types for CLOB/BLOB support.
#
#   name     - SQL query name
#   args     - query arguments
#   returns  - query [cached] result set
#
proc ob_db::exec_qry_force {name args} {
	return [eval {ob_db_multi::exec_qry_force $name} $args]
}



# Execute a query using each row methodology.
# See db-admin.tcl for detailed arguments.
#
# foreachrow ?-fetch? ?-force? ?-colnamesvar colnames? ?-rowvar r?
#   ?-nrowsvar nrows? qry ?arg...? tcl
#
proc ob_db::foreachrow args {

	variable CFG

	return [eval ob_db_multi::foreachrow $CFG(conn_name) $args]
}



#--------------------------------------------------------------------------
# Transactions
#--------------------------------------------------------------------------

# Begin a transaction.
# If a connection related error occurs, the procedure will establish a new
# connection and re-attempt the begin transaction. If this fails, then
# asRestart (appserv restart command) is called.
# Any other failure, will result in calling asRestart!
#
# When calling this procedure, make sure that either ob_db::commit_tran
# or ob_db::rollback_tran is called.
#
proc ob_db::begin_tran {{conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::begin_tran $conn_name
}



# Commit a transaction.
# ob_db::begin_tran must have been called to allow a transaction to be
# committed. Make sure commit_tran is called if the transaction is wanted,
# else call ob_db::rollback_tran.
#
proc ob_db::commit_tran {{conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::commit_tran $conn_name
}



# Rollback a transaction.
# ob_db::begin_tran must have been called to allow a transaction to be
# rolled back. Make sure that rollback_tran is called if the transaction
# is not wanted, else call ob_db::commit_tran
#
proc ob_db::rollback_tran {{conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::rollback_tran $conn_name
}



#--------------------------------------------------------------------------
# Request
#--------------------------------------------------------------------------

# Denote an appserv request has ended.
# This procedure MUST be called at the end of every request. Performs important
# cleanup of the result set cache.
# Attempts to rollback a transaction, if this succeeds, the procedure will
# raise an error.
#
proc ob_db::req_end args {
	ob_db_multi::req_end
}



#--------------------------------------------------------------------------
# Result Sets
#--------------------------------------------------------------------------

# Close an un-cached result set.
#
#   rs - result set to close
#
proc ob_db::rs_close {rs {conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::rs_close $rs $conn_name
}



# Get the number of rows affected by the last statement
#
#  name    - named SQL query
#  returns - number of rows affected by the last statement
#
proc ob_db::garc name {
	return [ob_db_multi::garc $name]
}



# Get serial number created by the last insert
#
#   name    - stored query name
#   returns - serial number (maybe an empty string if no serial
#             number was associated with the last insert)
#
proc ob_db::get_serial_number { name } {
	return [ob_db_multi::get_serial_number $name]
}



#--------------------------------------------------------------------------
# PDQ
#--------------------------------------------------------------------------

# Set a PDQ priority.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0. The priority will be limited
# to DB_MAX_PDQ cfg value.
# The PDQ is pushed onto an internal stack, use ob_log::pop_pdq to remove the
# PDQ from the list and reset to the previous priority.
#
#   pdq     - PDQ priority
#   returns - PDQ value set, or zero if setting of PDQs is disabled
#
proc ob_db::push_pdq { pdq {conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	return [ob_db_multi::push_pdq $pdq $conn_name]
}



# Reset the PDQ priority to previous setting.
# The PDQ will be set if DB_MAX_PDQ cfg value > 0, and the PDQ stack is
# not exhausted.
#
#   returns  - PDQ value set, or zero if setting of PDQs is disabled, or the
#              list is exhausted
#
proc ob_db::pop_pdq {{conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	return [ob_db_multi::pop_pdq $conn_name]
}



#--------------------------------------------------------------------------
# Utilities
#--------------------------------------------------------------------------

# Gets the last error code
#
#   returns - last error code
#
proc ob_db::get_err_code {{conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	return [ob_db_multi::get_err_code $conn_name]
}



# Get the column type and max length for a column
#
#   returns - last error code
#
proc ob_db::get_column_info {table column {conn_name ""}} {
	# Todo
}



# Allow switchable options in the db code to be changed
#
#   returns - last error code
#
proc ob_db::reconfigure {cfg_name cfg_value {conn_name ""}} {

	variable CFG
	if {$conn_name == ""} {
		set conn_name $CFG(conn_name)
	}

	ob_db_multi::reconfigure $conn_name $cfg_name $cfg_value
}
