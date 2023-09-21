# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
#

set pkgVersion 1.0
package provide core::db::schema $pkgVersion

# Dependencies
package require core::log          1.0
package require core::check        1.0
package require core::args         1.0
package require core::db           1.0
package require core::db::failover 1.0

core::args::register_ns \
	-namespace core::db::schema \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::db core::db::failover] \
	-docs      db/schema.xml

namespace eval core::db::schema {
	variable CFG
	variable INF_COL_PROPS
	variable INF_COL_TYPES

	set CFG(init)    0
	set CFG(schema)  {public}
	set CFG(package) INFORMIX
	set CFG(force)   0
	set CFG(cache)   100000

	# http://publib.boulder.ibm.com/infocenter/idshelp/v10/index.jsp?topic=/com.ibm.sqlr.doc/sqlrmst41.htm
	array set INF_COL_PROPS [list\
		NON_NULL          0x0100\
		HOST_VARIABLE     0x0200\
		FLOAT_TO_DECIMAL  0x0400\
		DISTINCT          0x0800\
		NAMED_ROW_TYPE    0x1000\
		DISTINCT_LVARCHAR 0x2000\
		DISTINCT_BOOLEAN  0x4000\
		CLIENT_COLLECTION 0x8000\
	]

	array set INF_COL_TYPES [list\
		0  CHAR\
		1  SMALLINT\
		2  INTEGER\
		3  FLOAT\
		4  SMALLFLOAT\
		5  DECIMAL\
		6  SERIAL\
		7  DATE\
		8  MONEY\
		9  NULL\
		10 DATETIME\
		11 BYTE\
		12 TEXT\
		13 VARCHAR\
		14 INTERVAL\
		15 NCHAR\
		16 NVARCHAR\
		17 INT8\
		18 SERIAL8\
		19 SET\
		20 MULTISET\
		21 LIST\
		22 UNNAMED_ROW\
		40 VARIABLE_LENGTH\
	]
}

core::args::register \
	-proc_name core::db::schema::init \
	-args [list \
		[list -arg -package   -mand 0 -check ASCII -default $::core::db::schema::CFG(package) -desc {Database package}] \
		[list -arg -schema    -mand 0 -check ASCII -default $::core::db::schema::CFG(schema)  -desc {Database schema name}] \
		[list -arg -force     -mand 0 -check BOOL  -default $::core::db::schema::CFG(force)   -desc {Force initialisation}] \
		[list -arg -cache     -mand 0 -check UINT  -default $::core::db::schema::CFG(cache)   -desc {Cache time}] \
	]

# Open a connection
# @param -package Database package
# @param -schema Database schema (Postgres only)
# @param -force Force initialisation
proc core::db::schema::init args {

	variable CFG

	array set ARGS [core::args::check core::db::schema::init {*}$args]

	if {$CFG(init) && !$ARGS(-force)} {
		core::log::write INFO {Already initialised core::db::schema}
		return
	}

	core::log::write INFO {Initialising core::db::schema}

	set CFG(package)   [string toupper $ARGS(-package)]
	set CFG(schema)    $ARGS(-schema)
	set CFG(cache)     $ARGS(-cache)
	set CFG(namespace) core::db::schema::$CFG(package)

	if {$CFG(package) ni {INFORMIX POSTGRESQL}} {
		error "Package $CFG(package) unavailable" {} UNKNOWN_PACKAGE
	}

	core::db::init

	_prep_queries.$CFG(package) $ARGS(-force)

	set CFG(init) 1

	return
}

# Does a table exist in the database?
core::args::register \
	-proc_name core::db::schema::table_exists \
	-args [list \
		[list -arg -table -mand 1 -check ASCII  -desc {Table to check}] \
	] \
	-body {
		return [_object_exists table [string tolower $ARGS(-table)]]
	}

# Does a column exist in the database?
core::args::register \
	-proc_name core::db::schema::table_column_exists \
	-args [list \
		[list -arg -table  -mand 1 -check ASCII  -desc {Table to check}] \
		[list -arg -column -mand 1 -check ASCII  -desc {Column to check}] \
	] \
	-body {
		return [_object_exists column \
			[list [string tolower $ARGS(-table)] [string tolower $ARGS(-column)]]]
	}

# Does a proc / function exist in the database?
core::args::register \
	-proc_name core::db::schema::proc_exists \
	-args [list \
		[list -arg -proc -mand 1 -check ASCII  -desc {Procedure to check}] \
	] \
	-body {
		return [_object_exists proc [string tolower $ARGS(-proc)]]
	}

core::args::register \
	-proc_name core::db::schema::proc_param_exists \
	-args [list \
		[list -arg -proc  -mand 1 -check ASCII -desc {Procedure to check}] \
		[list -arg -param -mand 1 -check ASCII -desc {Parameter to check}] \
	] \
	-body {
		return [_object_exists param \
			[list [string tolower $ARGS(-proc)] [string tolower $ARGS(-param)]]]
	}

# Checks if a specific procedures parameter id mandatory. This does not use the
# The standard _object_exists function as this is
#
# 1. Slightly more complicated than just exists/not exists
# 2. Neither informix nor postgreSQL have clever built in ways to detect this
# 3. Since the check is done via a less than ideal regexp we want to keep the code
#    separate
#
# Will get all parameters of a function and store the mandatory'ness in cache to
# save on future calls
core::args::register \
	-proc_name core::db::schema::proc_param_is_mandatory \
	-args [list \
		[list -arg -proc  -mand 1 -check ASCII -desc {Procedure to check}] \
		[list -arg -param -mand 1 -check ASCII -desc {Parameter to check}] \
	] \
	-body {
		variable CFG
		variable CACHE

		set check_proc  [string tolower $ARGS(-proc)]
		set check_param [string tolower $ARGS(-param)]

		set key_name [join [list $CFG(package) ${check_proc} ${check_param} mandatory] "."]

		# If this has been cached return the cache assuming the schema will not change once
		# the database has been loaded
		if {[info exists CACHE($key_name)]} {
			core::log::write DEBUG {$key_name CACHED mandatory=$CACHE($key_name)}
			return $CACHE($key_name)
		}

		# Get the argument definitions
		set params [core::db::schema::_get_parameter_definitions.$CFG(package) $check_proc]

		foreach arg $params {

			# Get the parameter name
			if {[regexp {^\s*(\w+)} $arg m param_name default]} {

				set param_name [string tolower $param_name]

				# Check whether param has a default set (not mandatory)
				if {[regexp -nocase -- {\sdefault\s} $arg]} {
					set mandatory 0
				} else {
					set mandatory 1
				}
				set CACHE($CFG(package).${check_proc}.${param_name}.mandatory) $mandatory
			}
		}

		if {[info exists CACHE($key_name)]} {
			core::log::write INFO {$key_name SCHEMA mandatory=$CACHE($key_name)}
			return $CACHE($key_name)
		}

		error "No such parameter $ARGS(-param) for proc $ARGS(-proc)"
	}


# Private proc to get the definitions in informix. Has to do this by
# getting the procedure body (across multiple rows) and stripping out
# the parameter definitions
proc core::db::schema::_get_parameter_definitions.INFORMIX {proc} {
	variable CFG

	# Get all body rows for this procedure
	if {[catch {
		set rs [core::db::exec_qry \
			-name INFORMIX.proc.body \
			-args [list $proc]]
	} err]} {
		core::log::write ERROR {ERROR: Unable to get proc body : $err}
		error $err $::errorInfo
	}

	set proc_sql {}
	set nrows    [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		set data [db_get_col $rs $i data]
		set padding [string repeat " " [expr {256 - [string length $data]}]]
		append proc_sql "${data}${padding}"
	}

	core::db::rs_close -rs $rs

	set params {}

	# Isolate the parameter definitions
	if {[regexp {[^()]*\(((?:[^()]|\([^()]*\))*)\)} $proc_sql m param_sql]} {

		# Remove new lines and split into individual parameter definitions
		set param_sql [string map [list "\n" {}] $param_sql]
		set params [split $param_sql ","]
	}

	return $params
}

# Private proc to get the definitions in postgreSQL. Does this using a
# built in procedure which returns the argument definitions.
proc core::db::schema::_get_parameter_definitions.POSTGRESQL {proc} {
	variable CFG

	# Get raw argument definitions
	if {[catch {
		set rs [core::db::exec_qry \
			-name POSTGRESQL.proc.arguments_def \
			-args [list $proc]]
	} err]} {
		core::log::write ERROR {ERROR: Unable to get proc arguments definition : $err}
		error $err $::errorInfo
	}

	set args_def [db_get_coln $rs 0 0]

	core::db::rs_close -rs $rs

	# Remove new lines and split into individual parameter definitions
	set param_sql [string map [list "\n" {}] $args_def]
	return [split $param_sql ","]
}


# Get the data type and data length of a column in a given table
# Will get the properties of the column and store in cache to
# save on future calls
#
core::args::register \
	-proc_name core::db::schema::get_col_definition \
	-args [list \
		[list -arg -table  -mand 1 -check ASCII  -desc {Table name}] \
		[list -arg -column -mand 1 -check ASCII  -desc {Column name}] \
	] \
	-body {
		variable CFG
		variable CACHE

		set tab_name  [string tolower $ARGS(-table)]
		set col_name  [string tolower $ARGS(-column)]

		# Check that table and column exist
		if {![core::db::schema::table_exists -table ${tab_name}] ||
		    ![core::db::schema::table_column_exists -table ${tab_name} -column ${col_name}]
		} {
			error "No such column ${col_name} in table ${tab_name}"
		}

		set key_name1 [join [list $CFG(package) col_def ${tab_name} ${col_name} data_type] "."]
		set key_name2 [join [list $CFG(package) col_def ${tab_name} ${col_name} data_length] "."]

		# If this has been cached return the cache assuming the schema will not change once
		# the database has been loaded
		if {[info exists CACHE($key_name1)] && [info exists CACHE($key_name2)]} {
			core::log::write DEBUG {$key_name1 CACHED data_type=$CACHE($key_name1)}
			core::log::write DEBUG {$key_name2 CACHED data_length=$CACHE($key_name2)}
			return [list 1 $CACHE($key_name1) $CACHE($key_name2)]
		}

		# Get the argument definitions
		foreach {type length}\
			[core::db::schema::_get_column_definition.$CFG(package) ${tab_name} ${col_name}] {break}

		if {$type != ""} {
			set CACHE($key_name1) $type
		}

		if {$length != ""} {
			set CACHE($key_name2) $length
		}

		if {[info exists CACHE($key_name1)] && [info exists CACHE($key_name2)]} {
			core::log::write DEBUG {$key_name1 SCHEMA data_type=$CACHE($key_name1)}
			core::log::write DEBUG {$key_name2 SCHEMA data_length=$CACHE($key_name2)}
			return [list 1 $CACHE($key_name1) $CACHE($key_name2)]
		}

		error "Cannot get definition for column ${col_name} in table ${tab_name}"
	}


# Private procedure to get the columns definitions in Informix.
# Need to interpret the coltype which is a smallint and translate that into
# a human readable text
proc core::db::schema::_get_column_definition.INFORMIX {tab col} {

	variable INF_COL_PROPS
	variable INF_COL_TYPES

	if {[catch {
		set rs [core::db::exec_qry \
			-name INFORMIX.column.definition \
			-args [list $tab $col]]
	} err]} {
		core::log::write ERROR {ERROR: Unable to get col def : $err}
		error $err $::errorInfo
	}

	set type   {}
	set length {}
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set length  [db_get_col $rs 0 collength]
		set coltype [db_get_col $rs 0 coltype]

		foreach {prop_name prop_hex} [array get INF_COL_PROPS] {
			if {[expr {$coltype & $prop_hex}]} {
				set coltype [expr {$coltype ^ $prop_hex}]
			}
		}

		if {[info exists INF_COL_TYPES($coltype)]} {
			set type $INF_COL_TYPES($coltype)
		}
	}

	core::db::rs_close -rs $rs

	return [list $type $length]
}


# Private procedure to get the columns definitions in POSTGRES.
#
proc core::db::schema::_get_column_definition.POSTGRESQL {tab col} {

	variable CFG

	if {[catch {
		set rs [core::db::exec_qry \
			-name POSTGRESQL.column.definition \
			-args [list $tab $col [string trimright $CFG(schema) .]]]
	} err]} {
		core::log::write ERROR {ERROR: Unable to get col def : $err}
		error $err $::errorInfo
	}

	set type   {}
	set length {}
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set type [string toupper [db_get_col $rs 0 data_type]]
		if {[set length  [db_get_col $rs 0 character_maximum_length]] == ""} {
			set length 999
		}
	}

	core::db::rs_close -rs $rs

	return [list $type $length]
}


# Create SQL based on existence of the column
core::args::register \
	-proc_name core::db::schema::add_sql_column \
	-args [list \
		[list -arg -table   -mand 1 -check ASCII  -desc {Table to verify}] \
		[list -arg -column  -mand 1 -check ASCII  -desc {Column to verify}] \
		[list -arg -alias   -mand 1 -check STRING -desc {SQL alias for column}] \
		[list -arg -default -mand 1 -check STRING -desc {Default if column does not exist}] \
	] \
	-body {
		if {[table_column_exists -table $ARGS(-table) -column $ARGS(-column)]} {
			return $ARGS(-alias)
		} else {
			return $ARGS(-default)
		}
	}

# Prepare queries
proc core::db::schema::_prep_queries.INFORMIX {{force 0}} {

	variable CFG

	core::log::write INFO {Preparing informix queries}

	core::db::store_qry \
		-name INFORMIX.table.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select 1 from systables where tabname = ?
		}

	core::db::store_qry \
		-name INFORMIX.column.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select 1
			from
				systables t,
				syscolumns c
			where
				t.tabname = ?
			and t.tabid   = c.tabid
			and c.colname = ?
		}

	core::db::store_qry \
		-name INFORMIX.proc.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select 1 from sysprocedures where procname = ?
		}

	core::db::store_qry \
		-name  INFORMIX.param.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select 1
				paramname
			from
				sysprocedures p,
				sysproccolumns c
			where
				p.procname = ?
				and p.procid = c.procid
				and c.paramattr = 1
				and c.paramname = ?
		}

	core::db::store_qry \
		-name  INFORMIX.proc.body \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select
				data
			from
				sysprocedures p,
				sysprocbody   b
			where
				p.procname = ?
				and b.procid = p.procid
				and b.datakey = 'T'
			order by
				b.seqno
		}

	core::db::store_qry \
		-name  INFORMIX.column.definition \
		-force $force\
		-cache $CFG(cache) \
		-qry {
			select
				c.coltype,
				c.collength
			from
				systables t,
				syscolumns c
			where
				t.tabname = ?
			and t.tabid   = c.tabid
			and c.colname = ?
		}
}

# Prepare queries
proc core::db::schema::_prep_queries.POSTGRESQL {{force 0}} {

	variable CFG

	core::log::write INFO {Preparing postgreSQL queries}

	core::db::store_qry \
		-name POSTGRESQL.table.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select
				1
			from
				information_schema.tables
			where
				table_name   = ?
			and table_schema = ?
		}

	core::db::store_qry \
		-name POSTGRESQL.column.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select
				1
			from
				information_schema.columns
			where
				table_name   = ?
			and column_name  = ?
			and table_schema = ?
		}

	core::db::store_qry \
		-name POSTGRESQL.proc.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select
				1
			from
				information_schema.routines
			where
				routine_name = ?
			and specific_schema NOT IN ('pg_catalog', 'information_schema')
			and routine_type = 'FUNCTION'
		}

	core::db::store_qry \
		-name  POSTGRESQL.param.exists \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			select
				parameter_name
			from
				information_schema.routines r,
				information_schema.parameters p
			where
				r.routine_name = ?
				and r.specific_schema NOT IN ('pg_catalog', 'information_schema')
				and r.routine_type = 'FUNCTION'
				and p.specific_name = r.specific_name
				and p.parameter_name = ?
				and p.parameter_mode = 'IN'
		}

	core::db::store_qry \
		-name  POSTGRESQL.proc.arguments_def \
		-force $force \
		-cache $CFG(cache) \
		-qry {
			SELECT pg_catalog.pg_get_function_arguments(?::regproc);
		}

	core::db::store_qry \
		-name  POSTGRESQL.column.definition \
		-force $force\
		-cache $CFG(cache) \
		-qry {
			select
				data_type,
				character_maximum_length
			from
				information_schema.columns
			where
				table_name       = ?
				and column_name  = ?
				and table_schema = ?
		}
}

# Check if an object exists in the database
proc core::db::schema::_object_exists {object params} {

	variable CFG
	variable CACHE

	set key_name [join $params .]

	switch -- $object {
		table -
		column {
			set key_name "${CFG(schema)}$key_name"
			if {$CFG(package) == {POSTGRESQL}} {
				lappend params [string trimright $CFG(schema) .]
			}
		}
	}

	# Assume that the schema hasn't changed since we started
	if {[info exists CACHE($key_name)]} {
		core::log::write DEBUG {$key_name CACHED [expr {$CACHE($key_name) ? "Exists" : "Missing"}]}
		return $CACHE($key_name)
	}

	if {[catch {
		set rs [core::db::exec_qry \
			-name $CFG(package).$object.exists \
			-args $params]
	} err]} {
		core::log::write ERROR {ERROR: Unable to check $key_name exists: $err}
		error $err $::errorInfo
	}

	if {![db_get_nrows $rs]} {
		core::db::rs_close -rs $rs
		core::log::write INFO {Schema Missing $object $key_name}
		set CACHE($key_name) 0
		return 0
	}

	set CACHE($key_name) 1

	core::db::rs_close -rs $rs

	return 1
}
