# $Id: audit.tcl,v 1.1 2011/10/04 12:26:34 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Provies support for fairly generic auditing. It takes that table
# name and uses database introspection to find out the primary keys for the
# table. Some tables don't have primary keys, you may specify the columns
# that should be filtered upon instead using the variable AUDIT.
#
# This is based on the admin screens version, but some functionality has been
# removed. Please don't feel you should add this back in, it has been excluded
# for several different reasons. The following has been removed.
#
#   * Special request argument names (e.g. EvMktId).
#     Arguments must be specified, there is not reason to specify the names,
#     using their real column names is clearer.
#   * Hidden columns.
#     All Columns are shown by default, this means that no information is
#     hidden.
#   * You do not have to specify a back action explicitly.
#     Use the following fragment of code instead:
#
#     ##TP_IF {[reqGetArg back] != ""}##
#     <a href="##TP_TCL {reqGetArg back}##">Back</a>
#     ##TP_ELSE##">
#     <a href="javascript: history.back();">Back</a>
#     ##TP_ENDIF##
#
# You will need to provide you own function to bind the array. The level of
# end device interfacing is left to you.
#
# Synopsis:
#   package require admin_audit ?4.5?
#
# Configuration:
#   ADMIN_AUDIT_PERMISSION - name of the admin permission action required
#                            (ViewAudit)
#
# Procedures:
#   ob_admin_audit::init      - initialise
#   ob_admin_audit::get_audit - geterate an audit
#

package provide admin_audit 4.5
package require util_log
package require util_db
package require admin_login



# Variables
#
namespace eval ob_admin_audit {

	asSetAct ob_admin_audit::go_audit [namespace code go_audit]

	# Configuration
	#
	variable CFG

	# initialised
	#
	variable INIT 0

	# Used to keep special values for primary keys. Table names must be
	# lowercase. This serves the same purpose as AUDIT_INFO in the admin
	# screens.
	#
	variable AUDIT
	array set AUDIT {
		tb2burl,primary_key {url_id url}
	}
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Initialise
#
proc ob_admin_audit::init args {

	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	ob_log::init
	ob_db::init
	ob_admin_login::init

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		permission ViewAudit
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet ADMIN_AUDIT_[string toupper $n] $v]
		}
	}

	if {![info exists ::admin_screens] || !$::admin_screens} {
		error "This package may only be loaded with admin screens"
	}

	_prep_qrys

	set INIT 1
}



# Prepare queries
#
proc ob_admin_audit::_prep_qrys {} {

	# get a list of a tables primary key columns
	ob_db::store_qry ob_admin_audit::sel_primary_key {
		select
			i.part1,
			i.part2,
			i.part3,
			i.part4,
			i.part5,
			i.part6,
			i.part7,
			i.part7,
			i.part8,
			i.part9,
			i.part10,
			i.part11,
			i.part12,
			i.part13,
			i.part14,
			i.part15,
			i.part16,
			s.rowid
		from
			sysTables      t,
			sysConstraints s,
			sysIndexes     i
		where
			t.tabname      = ?
		and t.tabid        = s.tabid
		and s.constrtype   = 'P'
		and s.idxname      = i.idxname
		order by
			-- just in case there are more than 16 columns making up the
			-- primary key, this is a slightly crazy situation
			s.rowid
	}

	# get the name of a column fro a column number
	ob_db::store_qry ob_admin_audit::sel_column {
		select
			c.colname
		from
			sysTables      t,
			sysColumns     c
		where
			t.tabid        = c.tabid
		and t.tabname      = ?
		and c.colno        = ?
	}

	# select details of an admin user
	ob_db::store_qry ob_admin_audit::sel_admin_user {
		select
			username
		from
			tAdminUser
		where
			user_id = ?
	}

	# select the details of an audit
	ob_db::store_qry ob_admin_audit::sel {
		select
			*
		from
			%s_aud
		where
			%s
		order by
			aud_order
	}
}



#--------------------------------------------------------------------------
# Procedures
#--------------------------------------------------------------------------

# Get the username of an admin user.
#
#   user_id  - the admin users id
#   returns  - the username of an admin user
#
proc ob_admin_audit::_get_admin_username {user_id} {

	# Both of these are 'special' users. 0 is for legacy data, as audits
	# should not be created with aud_id of 0 or -1
	if {[lsearch {-1 0} $user_id] >= 0} {
		return System
	}

	set rs    [ob_db::exec_qry ob_admin_audit::sel_admin_user $user_id]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set username [db_get_col $rs 0 username]
	} else {
		set username Unknown
	}

	ob_db::rs_close $rs

	return $username
}



# Private procedure to get a list of primary keys for a table.
#
#   tabname - table name
#   returns - list of columns that comprise the table's primary key
#
proc ob_admin_audit::get_primary_key {tabname} {

	variable AUDIT

	set tabname [string tolower $tabname]

	# we may already know this, it might have been set explicitly, or
	# it may have be used before
	if {[info exists AUDIT($tabname,primary_key)]} {
		return $AUDIT($tabname,primary_key)
	}

	set rs    [ob_db::exec_qry ob_admin_audit::sel_primary_key $tabname]
	set nrows [db_get_nrows $rs]

	# the ordering of this list is important
	set colnos [list]
	for {set r 0} {$r < $nrows} {incr r} {
		for {set p 1} {$p <= 16} {incr p} {

			# each part is a column number, related to part of the primary keys
			# in a real situation, we only expect one or maybe two values to be
			# populated, is the odd situation there maybe a lot, for example
			# summary tables (though we would not expect these to be audited)
			# A check shows that there doesn't appear to be any tables where
			# there are between 9 and 16 columns comprising the primary key.

			set colno [db_get_col $rs $r part$p]

			# column no zero means that there is no column
			if {$colno > 0} {
				lappend colnos $colno
			}
		}
	}

	ob_db::rs_close $rs

	ob_log::write DEV {ob_admin_audit: colnos for '$tabname' are '$colnos'}

	if {[llength $colnos] == 0} {
		error "'$tabname' does not appear to have a primary key constraint"
	}

	# we need the actual names now
	set primary_key [list]
	foreach colno $colnos {
		set rs [ob_db::exec_qry ob_admin_audit::sel_column $tabname $colno]

		lappend primary_key [db_get_col $rs 0 colname]

		ob_db::rs_close $rs
	}

	ob_log::write DEV \
		{ob_admin_audit: primary key for $tabname is '$primary_key'}

	# lets not calculate this small piece of information repeatedly
	set AUDIT($tabname,primary_key) $primary_key

	return $primary_key
}



# Get audit information for a tabname.
#
#   tabname            - tabname name
#   primary_key_value  - a list of values of the primary key columns, in the
#                        same order as the primary key
#   DATA_ARR           - array to populated
#
proc ob_admin_audit::get_audit {tabname primary_key_value DATA_ARR} {

	variable CFG

	init

	upvar 1 $DATA_ARR DATA
	array unset DATA

	if {![ob_admin_login::has_permission $CFG(permission)]} {
		error "you do not have the correct permissions to view audit"
	}

	set tabname [string tolower $tabname]

	# these maybe explicitly defined
	set primary_key [get_primary_key $tabname]

	if {[llength $primary_key] != [llength $primary_key_value]} {
		error "expected the # of values and the primary key to be same length"
	}

	set where [list]
	set argz [list]
	foreach colname $primary_key colvalue $primary_key_value {
		lappend where "$colname = ?"
		lappend argz  $colvalue
	}

	set where [join $where " and "]

	ob_log::write DEV {ob_admin_audit: $where, $argz}

	# you've got to be REALLY carefull with eval
	set rs [eval [list ob_db::exec_qry ob_admin_audit::sel $tabname $where] \
		$argz]

	set DATA(nrows)    [db_get_nrows $rs]
	set DATA(ncols)    [db_get_ncols $rs]
	set DATA(colnames) [db_get_colnames $rs]

	for {set c 0} {$c < $DATA(ncols)} {incr c} {
		set DATA($c,name)  [db_get_colname $rs $c]
	}

	for {set r 0} {$r < $DATA(nrows)} {incr r} {
		for {set c 0} {$c < $DATA(ncols)} {incr c} {

			set DATA($r,$c,value) [db_get_coln $rs $r $c]

			# if this is an admin user, populate it
			if {$DATA($c,name) == "aud_id"} {
				set DATA($r,$c,admin_user) [_get_admin_username \
					$DATA($r,$c,value)]
			}
		}
	}

	ob_db::rs_close $rs

	ob_log::write_array DEV DATA
}
