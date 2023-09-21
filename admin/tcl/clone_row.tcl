# $Id: clone_row.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CLONE_ROW {

	variable TABLES
	variable last_inserted
}


#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# One off initialisation
#
proc ADMIN::CLONE_ROW::init {} {

	_setup_tables
}



# setup table structure for copying rows.
# EVENT MARKET
proc ADMIN::CLONE_ROW::_setup_tables {} {

	variable TABLES

	set TABLES(tevtype) 1
	set TABLES(tevtype,pk_cols) [list ev_type_id]
	set TABLES(tevtype,children) [list tevocgrp]
	set TABLES(tevtype,additionnal_cols) [list ]
	set TABLES(tevtype,additionnal_vals) [list ]

	set TABLES(tevocgrp) 1
	set TABLES(tevocgrp,pk_cols) [list ev_oc_grp_id]
	set TABLES(tevocgrp,children) [list ]
	set TABLES(tevocgrp,additionnal_cols) [list ]
	set TABLES(tevocgrp,additionnal_vals) [list ]

	set TABLES(tevmkt) 1
	set TABLES(tevmkt,pk_cols) [list ev_mkt_id]
	set TABLES(tevmkt,children) [list tevmktconstr tlaytolose tevoc]
	set TABLES(tevmkt,additionnal_cols) [list ]
	set TABLES(tevmkt,additionnal_vals) [list ]

	set TABLES(tevmktconstr) 1
	set TABLES(tevmktconstr,pk_cols) [list ev_mkt_id]
	set TABLES(tevmktconstr,children) [list ]
	set TABLES(tevmktconstr,additionnal_cols) [list ]
	set TABLES(tevmktconstr,additionnal_vals) [list ]

	set TABLES(tlaytolose) 1
	set TABLES(tlaytolose,pk_cols) [list ev_mkt_id]
	set TABLES(tlaytolose,children) [list ]
	set TABLES(tlaytolose,additionnal_cols) [list ]
	set TABLES(tlaytolose,additionnal_vals) [list ]

	set TABLES(tevoc) 1
	set TABLES(tevoc,pk_cols) [list ev_oc_id]
	set TABLES(tevoc,children) [list tevocconstr]
	set TABLES(tevoc,additionnal_cols) [list ]
	set TABLES(tevoc,additionnal_vals) [list ]

	set TABLES(tevocconstr) 1
	set TABLES(tevocconstr,pk_cols) [list ev_oc_id]
	set TABLES(tevocconstr,children) [list ]
	set TABLES(tevocconstr,additionnal_cols) [list ]
	set TABLES(tevocconstr,additionnal_vals) [list ]

}

proc ADMIN::CLONE_ROW::reset_additionnal_values { tablename additionnal_cols additionnal_vals } {

	variable TABLES

	if { ![info exists TABLES($tablename) ] } {
		return
	}

	set TABLES($tablename,additionnal_cols) $additionnal_cols
	set TABLES($tablename,additionnal_vals) $additionnal_vals

}

#-------------------------------------------------------------------------------
# Clone row methods
#-------------------------------------------------------------------------------

# clone the row in 'table_name' that identified by the values in pk_vals
#
proc ADMIN::CLONE_ROW::clone_row {table_name pk_vals} {

	global DB

	set extra_cols [_get additionnal_cols $table_name]
	set extra_vals [_get additionnal_vals $table_name]

	inf_begin_tran $DB

	set c [catch {
		_clone_row $table_name $pk_vals $extra_cols $extra_vals
	} msg]

	if {$c == 0} {
		inf_commit_tran $DB
	} else {
		catch {inf_rollback_tran $DB}
		err_bind $msg
		OT_LogWrite CRITICAL "Rolled back transaction. Couln't clone $table_name : \n $msg"
	}

}



#  clone a row
#
#   table_name - table that contains the row
#   pk_vals    - the identifier for the row to clone
#   extra_cols - if specified, don't copy these from db but use passed vals
#   extra_vals - the values for extra_cols
#
proc ADMIN::CLONE_ROW::_clone_row {table_name pk_vals extra_cols extra_vals} {

	set pk_cols [_get pk_cols $table_name]

	# make a 'shallow' copy of the row
	set new_pk_vals [_shallow_copy $table_name $pk_vals $extra_cols $extra_vals]

	#Perform special operations on that new row that cannot be done only by
	#copying a row from the DB. Use with caution, and only in that situation.
	_do_special_op $table_name $new_pk_vals

	# now find all child table
	foreach child_table [_get children $table_name] {

		#get columns that won't be copied across in child tables.
		#these list will be the combination of
		# 1) the primary key of the parent tables, that will have to be made of
		#    the new primary keys.
		# 2) Any additionnal columns configured in TABLES.

		# 1) Initialise with parent's pk
		set child_extra_cols $pk_cols
		set child_extra_vals $new_pk_vals

		# 2) add stuff from TABLES array
		set child_extra_cols [concat $child_extra_cols [_get additionnal_cols $child_table]]
		set child_extra_vals [concat $child_extra_vals [_get additionnal_vals $child_table]]

		# find all 'child' rows of row just copied
		foreach child_row_pk_vals\
			[get_rows_where $child_table $pk_cols $pk_vals] {
			_clone_row $child_table\
					 $child_row_pk_vals\
					 $child_extra_cols\
					 $child_extra_vals
		}
	}

	return $new_pk_vals
}




# Make a shallow copy of a row (don't copy any child tables)
#
#   table_name - table that contains the row
#   pk_vals    - identifier for the row to copy
#   extra_cols - if specified, don't copy these from db but use passed vals
#   extra_vals - the values for extra_cols
#
#   returns    - a list which is the primary key for the new row
#
proc ADMIN::CLONE_ROW::_shallow_copy {table_name pk_vals extra_cols extra_vals} {

	# get all col names that aren't serial and don't need to be copied from
	# extra_vals
	set cols_to_copy [_get_columns $table_name $extra_cols]

	# get the qualifier for the row we wish to copy
	set qualifier [_build_where_clause [_get pk_cols $table_name] $pk_vals ]

	# get the values from the pre-existing row to copy
	set sql "select [join $cols_to_copy ,] from $table_name	where $qualifier"
	set rs [_run_sql $sql]

	set vals_to_copy [list ]
    set cols_to_actually_copy [list]
	foreach col $cols_to_copy {
		set val [db_get_col $rs 0 $col]
		# assume that an empty string means null
        set val_to_ins $val
        if {$val_to_ins != "null" && $val_to_ins != ""} {
            lappend cols_to_actually_copy "$col"
            lappend vals_to_copy "$val_to_ins"
        }
	}


	# combine the columns, values just got from the db with those passed
	foreach col $extra_cols val $extra_vals {
        if {$val != "null" && $val != ""} {
            lappend cols_to_actually_copy $col
            lappend vals_to_copy $val
        }
	}

    set params_place_holders [list]
    foreach col $cols_to_actually_copy {
        lappend params_place_holders "?"
    }

	# insert the new clone row
	set sql "insert into $table_name (
		[join $cols_to_actually_copy ,]
	) values (
		[join $params_place_holders ,]
	)"

	_run_sql $sql $vals_to_copy 1

	# return a serial number (if any was inserted)
	return [list [_get_serial]]
}



# utility proc to get the primary key values for a row where cols = vals
#
#   child_table - the table in which to search
#   cols        - the columns to check
#   vals        - the values for which to check
#
proc ADMIN::CLONE_ROW::get_rows_where {child_table cols vals} {

	set cols_to_get [_get pk_cols $child_table]

	set sql "select [join $cols_to_get ,] from $child_table where
		[_build_where_clause $cols $vals]"

	set rs [_run_sql $sql]
	set result [list ]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set temp [list ]
		foreach col $cols_to_get {
			lappend temp [db_get_col $rs $i $col]
		}
		lappend result $temp
	}
	_close $rs
	return $result
}



# utility proc to build up a where clause
#
#   cols - a list of columns
#   vals - a list of values
#
proc ADMIN::CLONE_ROW::_build_where_clause {cols vals} {

	set result [list ]
	foreach col $cols val $vals {
		lappend result "$col='[string map {' ''} $val]'"
	}
	return [join $result { and }]
}



# utility proc to get some info about a table (namely pk_cols or children)
#
#   type       - the type of information (pk etc)
#   table_name - the name of the table for which to get info
#
proc ADMIN::CLONE_ROW::_get {type table_name} {
	variable TABLES
	return $TABLES($table_name,$type)
}



# return a list of all column names
#
#   table_name      - the table for which to get the columns
#   cols_to_exclude - the columns to exclude
#
#   returns - a list of cols, exluding those specified, and serial cols
#
proc ADMIN::CLONE_ROW::_get_columns {table_name cols_to_exclude} {

	# quote each in cols_to_exclude
	set quoted_cols_to_excludes [list ]
	foreach col $cols_to_exclude {
		lappend quoted_cols_to_exclude "'$col'"
	}

	set cols_to_exclude_clause {}
	if {[llength $cols_to_exclude] > 0} {
		set cols_to_exclude_clause [subst {
			and colname not in ([join $quoted_cols_to_exclude ,])
		}]
	}

	# 262 is the column type of a serial
	set sql [subst {
		select
			colname
		from
			syscolumns c,
			systables t
		where
			t.tabname = '$table_name'
		and c.tabid   = t.tabid
		and c.coltype <> 262
		$cols_to_exclude_clause
	}]

	set rs [_run_sql $sql]
	set result [list ]
	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		lappend result [db_get_col $rs $i colname]
	}
	_close $rs

	return $result
}



# run some arbitrary sql
#
#   sql        - the sql statement to run
#   get_serial - whether to record the last serial number if sql has an insert
#
proc ADMIN::CLONE_ROW::_run_sql {sql {params ""} {get_serial 0}} {
	variable last_inserted
	_log "$sql <br>"

	global DB
	set stmt [inf_prep_sql $DB $sql]
    set rs [eval inf_exec_stmt $stmt $params]

	set last_inserted 0
	if {$get_serial} {
		set last_inserted [inf_get_serial $stmt]
	}

	inf_close_stmt $stmt
	return $rs
}

# After copying, do some other stuff on the DB.
# table_name :
# tevoc -- > initialise price history tEvOcPrice. When copying a selection,
# treat the price as the first ever price entered.
proc ADMIN::CLONE_ROW::_do_special_op { table_name new_pk_val } {

	global USERID

	switch $table_name {
		tevoc {
			set sql [subst {
				select
					m.lp_avail,
					NVL(o.lp_num,0) as lp_num,
					NVL(o.lp_den,0) as lp_den
				from
					tEvMkt m,
					tEvOc o
				where
					o.ev_oc_id = $new_pk_val and
					o.ev_mkt_id = m.ev_mkt_id
			}]

			#no need to catch here 'cause this proc should be called inside a
			#caught transaction
			set rs [_run_sql $sql]

			set lp_num [db_get_col $rs 0 lp_num]
			set lp_den [db_get_col $rs 0 lp_den]

			if {[db_get_col $rs lp_avail] == "Y" && $lp_num > 0 && $lp_den > 0 } {
				set sql [subst {
					insert into tEvOcPrice
						(
						user_id,
						ev_oc_id,
						p_num,
						p_den
						)
					values
						(
						$USERID,
						$new_pk_val,
						$lp_num,
						$lp_den
						);
				}]
				set res [_run_sql $sql]
				_close $res
			}
			_close $rs
		}
		tevmkt {
			set sql [subst {
				select
					ew_avail,
					ew_with_bet,
					ev_mkt_id,
					NVL(ew_fac_num,0) as ew_fac_num,
					NVL(ew_fac_den,0) as ew_fac_den,
					NVL(ew_places,0)  as ew_places
				from
					tEvMkt
				where
					ev_mkt_id = $new_pk_val
			}]

			set rs [_run_sql $sql]

			foreach c [db_get_colnames $rs] {
				set $c [db_get_col $rs 0 $c]
			}

			if {$ew_avail == "Y" && $ew_with_bet == "Y" &&\
				$ew_fac_num != 0 &&\
				$ew_fac_den != 0 &&\
				$ew_places  != 0} {

				set sql [subst {
				insert into tEachWayTerms
					(
					ev_mkt_id,
					ew_fac_num,
					ew_fac_den,
					ew_places
					)
				values
					(
					$ev_mkt_id,
					$ew_fac_num,
					$ew_fac_den,
					$ew_places
					);
				}]

				set res [_run_sql $sql]
				_close $res
			}
			_close $rs
		}
		default {
			return
		}
	}
}

# close a result set
#
#   rs - the result set to close
#
proc ADMIN::CLONE_ROW::_close {rs} {
	ob_db::rs_close $rs
}



# get the value of the last serial inserted (by _run_sql)
#
#   returns - the value of the last serial
#
proc ADMIN::CLONE_ROW::_get_serial {} {
	variable last_inserted
	return $last_inserted
}



# log something as level DEV
#
#   str - the message to log
#
proc ADMIN::CLONE_ROW::_log {str} {
	ob_log::write DEV $str
}

#initialised when sourced
ADMIN::CLONE_ROW::init

