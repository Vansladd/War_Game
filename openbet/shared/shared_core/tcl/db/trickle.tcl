#  $Header$
#  Runs  the trickle update
#
#

set pkgVersion 1.0

package provide core::db::trickle $pkgVersion
core::args::register_ns \
	-namespace core::db::trickle \
	-version   $pkgVersion \
	-docs      db/db_trickle.xml

namespace eval core::db::trickle {
	set CONF [dict create]
	set STATS [dict create]
	set ARG_DEF(-state_var)  [list -arg -state_var    -mand 1 -check ANY                  -desc {Variable to hold the state of a run,. Will be reset during init}]
	set ARG_DEF(-label)      [list -arg -label        -mand 1 -check ANY                  -desc {Label, as passed to prep()}]
	set ARG_DEF(-start_key)  [list -arg -start_key    -mand 0 -check ANY  -default ""     -desc {The value of key to start at - will effectivly do update tTable set ... where key > <start_key> ... Blank means pick first key (lowest or highest accoerding to order)}]
	set ARG_DEF(-batch)      [list -arg -batch        -mand 0 -check ANY  -default 100 -default_cfg DB_TRICKLE.BATCH -desc {Batch size - updates are resticted to ranges of this size} ]
	set ARG_DEF(-out_file)   [list -arg -out_file     -mand 0 -check ANY  -default {}     -desc {An output file to store the purged row. Will overwrite any existing file.}]
	set ARG_DEF(-where_args) [list -arg -where_args   -mand 0 -check ANY  -default [list] -desc {Additional arguments to provide to the where clause} ]
	set ARG_DEF(-dry_run)    [list -arg -dry_run      -mand 0 -check BOOL -default 0   -default_cfg DB_TRICKLE.DRY_RUN    -desc {Do not do updates/deletes. Just log the count of rows affected} ] \
}



core::args::register \
	-proc_name core::db::trickle::prep \
	-desc {Prepares a query referenced by -label for execution
!! Run by either calling
!!
!! core::db::trickle::run
!!
!! OR
!!
!! core::db::trickle::init
!! core::db::trickle::do_batch ....
!! core::db::trickle::end
	} \
	-args      [list \
		[list -arg -label        -mand 1 -check ANY  -default {}    -desc {Label to identify query}] \
		[list -arg -op           -mand 1 -check {ENUM -args {UPDATE DELETE}}  -default {}    -desc {Operation, update or delete}] \
		[list -arg -order        -mand 0 -check {ENUM -args {ASC DESC}}  -default {ASC}    -desc {Order to scan table, ASC is to process rows upwards. ASC is the default}] \
		[list -arg -table        -mand 1 -check ANY  -default {}    -desc {Table to do updates on}] \
		[list -arg -key          -mand 1 -check ANY  -default {}    -desc {Column on table (PK is ideal) to supply to where clause to batch updates. Must be indexed}] \
		[list -arg -where        -mand 0 -check ANY  -default {}    -desc {Where clause for updates, as in update tTable set .. where <where>;}] \
		[list -arg -update_set   -mand 0 -check ANY  -default {}    -desc {Update set clause  as in update tTable set <update> where ...;. Required for -op UPDATE}] \
		[list -arg -directive    -mand 0 -check ANY  -default {}    -desc {The directive to pass to all the queries, e.g. INDEX(tEvOc,ievoc_aud_x1) }] \
		[list -arg -copy_to      -mand 0 -check ANY  -default {}    -desc {Whether to copy all columns to this table - Blank means no copy}] \
		[list -arg -copy_select_cols -mand 0 -check ANY  -default {}    -desc {List of columns to copy - blank means copy all (i.e. insert into table1 select * from table2}] \
		[list -arg -copy_insert_cols -mand 0 -check ANY  -default {}    -desc {When -copy_tp specified, list of columns to use for the insert statement. blank means use -copy_select_cols}]\
] -body  {
	variable CONF

	set fn {core::db::trickle::prep}

	set label              $ARGS(-label)
	set op                 $ARGS(-op)
	set table              $ARGS(-table)
	set key                $ARGS(-key)
	set order              $ARGS(-order)
	set where              $ARGS(-where)
	set update_clause      $ARGS(-update_set)
	set directive          $ARGS(-directive)
	set copy_to            $ARGS(-copy_to)
	set copy_select_cols   $ARGS(-copy_select_cols)
	set copy_insert_cols   $ARGS(-copy_insert_cols)

	if {$where != ""} {
		set where_clause [subst {($where)}]
		set and_clause   {AND }

	} else {
		set where_clause {}
		set and_clause   {}
	}

	core::log::write INFO {$fn: Preparing table $table with key $key $order using label $label}
	core::log::write INFO {$fn: where clause: $where}
	core::log::write INFO {$fn: update clause: $update_clause}
	core::log::write INFO {$fn: directive: $directive}

	dict set CONF $label [dict create]
	dict set CONF $label table  $table
	dict set CONF $label op     $op
	dict set CONF $label key    $key
	dict set CONF $label order  $order
	dict set CONF $label where  $where_clause
	dict set CONF $label update $update_clause
	dict set CONF $label copy_to $copy_to

	switch -exact -- $order {
		"ASC" {set order_op ">"}
		"DESC" {set order_op "<"}
		default {error "$fn: unknown order '$order'"}
	}

	#  Strictly speaking we should include the where clause 
	#  in this query below to get truly accurate stats,
	#  but this would make the query way too slow to be usable
	_store_qry $label get_min_max [subst {
SELECT {+$directive}
	min($key) min_id,
	max($key) max_id,
	count(*) n_rows
FROM $table}]

	_store_qry $label first_id [subst {
SELECT {+$directive} FIRST 1
	$table.$key id
FROM $table
WHERE
	${where_clause}
ORDER BY id $order}]

	_store_qry $label next_id [subst {
SELECT {+$directive} FIRST 1
	$table.$key id
FROM $table
WHERE
	$table.$key $order_op ?
	${and_clause}${where_clause}
ORDER BY id $order}]

	_store_qry $label count_tab [subst {
SELECT {+$directive} count(*)
FROM $table
WHERE
	$table.$key between ? AND ?
	${and_clause}${where_clause}}]

	_store_qry $label select_tab [subst {
SELECT {+$directive} *
FROM $table
WHERE
	$table.$key between ? AND ?
	${and_clause}${where_clause}
ORDER BY $table.$key $order}]

	if {$copy_to != ""} {


		if {[llength $copy_select_cols] == 0} {
			set copy_insert_cols_sql ""
			set copy_select_cols_sql " *"
		} else {
			if {[llength $copy_insert_cols] == 0} {
				set copy_insert_cols $copy_select_cols
			}
			set copy_insert_cols_sql " ([join $copy_insert_cols ,])"
			set copy_select_cols_sql " [join $copy_select_cols ,]"
		}

		_store_qry $label copy_tab [subst {
INSERT INTO $copy_to${copy_insert_cols_sql}
SELECT {+$directive}$copy_select_cols_sql
FROM $table
WHERE
	$table.$key between ? AND ?
	${and_clause}${where_clause}}]
	}

	if {$op == "UPDATE"} {
	_store_qry $label upd_tab [subst {
UPDATE {+$directive} $table
SET $update_clause
WHERE
	$key between ? AND ?
	${and_clause}${where_clause}}]
} else {
	core::db::store_qry \
		-name  core::db::trickle::${label}::del_tab \
		-qry [subst {
DELETE {+$directive} $table
WHERE
	$key between ? AND ?
	${and_clause}${where_clause}}]
	}
}

core::args::register \
	-proc_name core::db::trickle::run \
	-desc {
		Runs through the query in batches, until we finish or run out of time
	} -args [list \
	$core::db::trickle::ARG_DEF(-state_var)  \
	$core::db::trickle::ARG_DEF(-label)      \
	$core::db::trickle::ARG_DEF(-start_key)  \
	$core::db::trickle::ARG_DEF(-batch)      \
	$core::db::trickle::ARG_DEF(-where_args) \
	$core::db::trickle::ARG_DEF(-out_file)   \
	$core::db::trickle::ARG_DEF(-dry_run)    \
	[list -arg -limit_sec    -mand 0 -check INT  -default 0          -desc {Limit of the number of seconds the  } ] \
	[list -arg -wait_ms      -mand 0 -check INT  -default 0 -default_cfg DB_TRICKLE.WAIT_MS   -desc {No of milliseconds to wait between batches} ] \
] -returns {
!! OK         - Finished normally
!! TIME_LIMIT - Time Limit exceeded.
	} -body {
	set fn {core::db::trickle::run}
	upvar $ARGS(-state_var) state

	set label       $ARGS(-label)
	set limit_sec   $ARGS(-limit_sec)
	set wait_ms     $ARGS(-wait_ms)
	set out_file    $ARGS(-out_file)
	set out_fd      {}

	core::log::write INFO {$fn: Init: [array get ARGS]}
	init \
			-state_var    state \
			-label        $ARGS(-label) \
			-start_key    $ARGS(-start_key) \
			-batch        $ARGS(-batch) \
			-where_args   $ARGS(-where_args) \
			-dry_run      $ARGS(-dry_run)

	if {$out_file != ""} {
		core::log::write INFO {$fn: Opening file $out_file}
		set out_fd [_open_file $out_file]
	}

	#  Work through batch until we finish, or run out of time.
	set ret OK
	while {[do_batch -state_var state -label $label -out_fd $out_fd]} {
		set elapsed [get -state_var state -param elapsed]
		if {$limit_sec > 0 && $elapsed > $limit_sec} {
			core::log::write WARNING {$fn: Elapsed limit of $limit_sec breached - Exiting}
			set ret TIME_LIMIT
			break
		}
		core::log::write INFO {$fn: Elapsed time $elapsed secs}

		if {$wait_ms > 0} {
			core::log::write INFO {Waiting $wait_ms ms}
			after $wait_ms
		}
	}
	if {$out_fd != ""} {
		_close_file $out_fd
		set U_STATE(out_fd) ""
	}
	core::log::write INFO {$fn: Finished in [get -state_var state -param elapsed] secs}
	return $ret
}



core::args::register \
	-proc_name core::db::trickle::init \
	-desc {Called at the start of a Trickle update/deletion run. Initialies the state variable} \
	-args      [list \
		$core::db::trickle::ARG_DEF(-state_var)  \
		$core::db::trickle::ARG_DEF(-label)      \
		$core::db::trickle::ARG_DEF(-start_key)  \
		$core::db::trickle::ARG_DEF(-batch)      \
		$core::db::trickle::ARG_DEF(-where_args) \
		$core::db::trickle::ARG_DEF(-dry_run)    \
	] -body {
	set fn {core::db::trickle::init}

	variable CONF
	upvar 1   $ARGS(-state_var) U_STATE

	unset -nocomplain U_STATE
	array set U_STATE [list]

	set label           $ARGS(-label)
	set order           [dict get $CONF $label order]

	if {$ARGS(-start_key) == {}} {
		set start_id         ""
	} else {
		switch -exact -- $order {
			"ASC" {
				set start_id  [expr {$ARGS(-start_key) -1}]
			}
			"DESC" {
				set start_id  [expr {$ARGS(-start_key) +1}]
			}
			default {
				error "$fn: Unknown order '$order'"
			}
		}
	}
	set U_STATE(label)       $label
	set U_STATE(batch)       $ARGS(-batch)
	set U_STATE(dry_run)     $ARGS(-dry_run)
	set U_STATE(where_args)  $ARGS(-where_args)
	set U_STATE(iterations)  0
	set U_STATE(last_rows)  ""
	set U_STATE(total_rows) 0
	set U_STATE(start_secs)    [clock seconds]

	#  Get the min, max and count for stats
	lassign [_run_qry core::db::trickle::${label}::get_min_max] min_id max_id nrows
	core::log::write INFO {$fn: Table stats min_id $min_id max_id $max_id nrows $nrows}
	if {$min_id == ""} {
		set min_id 0
		set max_id 0
	}

	set U_STATE(start_id) $start_id
	set U_STATE(curr_id)  $start_id
	set U_STATE(min_id) $min_id
	set U_STATE(max_id) $max_id
	set U_STATE(nrows)  $nrows
	_upd_stats U_STATE
	core::log::write INFO {$fn: U_STATE [array get U_STATE]}
}

core::args::register \
	-proc_name core::db::trickle::get \
	-desc {Returns info on requests
		-param:
			start_id   - Id run starts from
			iterations - No of iterations
			label      - Label
			batch      - Batch size
			curr_id    - Current Id we are processing
			last_rows  - number of rows affected by last batch update
			total_rows - Total number of rows affected by all batches
			elapsed    - Elapsed seconds since start
			done_perc  - Percentage done
			time_remaining - Seconds remaining
			etc            - Estimated time to completion in secs
			etc_str        - Estimated time to completion in string
	} -args      [list \
		[list -arg -state_var    -mand 1 -check ANY               -desc {Variable to hold the state of a run - will be reset during init}] \
		[list -arg -param        -mand 1 -check {ENUM -args {label start_id batch last_rows total_rows curr_id iterations elapsed done_perc time_remaining etc etc_str}}   -desc {Name of parameter}] \
	] -body {
		upvar $ARGS(-state_var) U_STATE
		set param $ARGS(-param)

		switch -- $param {
			default {
				set val $U_STATE($param)
			}
		}
		return $val
	}


core::args::register \
	-proc_name core::db::trickle::do_batch \
	-desc {Runs an iteration of the job, and updates the state_var with the current state} \
	-returns {Boolean, true if there are more rows, false if no more rows to update.} \
	-args      [list \
		$core::db::trickle::ARG_DEF(-state_var) \
		$core::db::trickle::ARG_DEF(-label)     \
		[list -arg -out_fd       -mand 0 -check ANY  -desc {If specified, the rows affected will be writted to this fd, in the dbaccess unload format}] \
		[list -arg -out_rs_var   -mand 0 -check ANY  -desc {If specified, variable to hold results set of the rows deleted. Note caller is responsible for deleting the rs}] \
	] -body {
	set fn {core::db::trickle::do_batch}
	variable CONF
	upvar 1   $ARGS(-state_var) U_STATE
	set label      $ARGS(-label)

	set where_args $U_STATE(where_args)
	set dry_run    $U_STATE(dry_run)

	if {$label != $U_STATE(label)} {
		error "$fn: -label $label does not match the state var $U_STATE(label)" {} BAD_PARAM
	}

	set do_out_rs 0

	#  If we are returning the rs then
	#  make sure we don't delete the rs it down below
	if {$ARGS(-out_rs_var) != ""} {
		set do_out_rs 1
		upvar $ARGS(-out_rs_var) out_rs
	} else {
		#  However in this case we must delete
		#  it as otherwise it will leak.
		set out_rs ""
	}

	set key     [dict get $CONF $label key]
	set op      [dict get $CONF $label op]
	set order   [dict get $CONF $label order]
	set copy_to [dict get $CONF $label copy_to]
	set prev_prefix [core::log::get_prefix]
	set batch       $U_STATE(batch)
	set out_fd      $ARGS(-out_fd)

	#  Note we select where key > $curr_id
	if {$U_STATE(curr_id) == {}} {
		set ret [_run_qry core::db::trickle::${label}::first_id [list {*}$where_args]]
	} else {
		set ret [_run_qry core::db::trickle::${label}::next_id [list $U_STATE(curr_id) {*}$where_args]]
	}
	set curr_id [lindex $ret 0]

	if {$curr_id == ""} {
		core::log::write INFO {$fn: No more rows - Exiting}
		_upd_stats U_STATE
		end -state_var U_STATE
		return 0
	}

	if {$U_STATE(curr_id) == {}} {
		core::log::write INFO {$fn: First ID $curr_id}
	} else {
		core::log::write INFO {$fn: Next ID $curr_id (skipped [expr {$curr_id - $U_STATE(curr_id)-1}])}
	}
	#  This is the upper bound of the key value
	#  inclusive of this value,
	#  which we will update
	#  i.e. where key between $curr_id and $next_id
	if {$order == "ASC"} {
		set next_id [expr {$curr_id + $batch - 1}]
		set lbetween_args [list $curr_id $next_id]
	} else {
		set next_id [expr {$curr_id - $batch + 1}]
		set lbetween_args [list $next_id $curr_id]
	}
	core::log::set_prefix "$prev_prefix:${label}:$U_STATE(iterations)"

	#  If required run the update.
	#  Note there is a small risk of this changing between the output and the
	#  being out of date between the unload and the dump,
	#  but this is minor.
	#  but saves us the cost and time of a temporary table
	if {$do_out_rs || $out_fd != ""} {
		set out_rs [core::db::exec_qry -name core::db::trickle::${label}::select_tab -args [list {*}$lbetween_args {*}$where_args]]

		if {$out_fd != ""} {
			_unload_rs_to_fd $out_fd $out_rs
		}

		#  If we are not returning the rs close here.
		if {!$do_out_rs} {
			core::db::rs_close -rs $out_rs
		}
	}

	#  Now do the update
	if {$dry_run} {
		set n_upd [_run_qry  core::db::trickle::${label}::count_tab [list {*}$lbetween_args {*}$where_args]]
		core::log::write INFO {$fn: ##DRY RUN## Would $op $n_upd rows}
	} else {

		core::db::begin_tran
		set catch_ret [catch {
			if {$copy_to != ""} {
				core::log::write INFO {$fn: Copying preimages to $copy_to}
				_run_qry  core::db::trickle::${label}::copy_tab [list {*}$lbetween_args {*}$where_args]
				set n_copy [core::db::garc -name core::db::trickle::${label}::copy_tab]
				core::log::write INFO {$fn: Copied $n_copy rows}
			}

			if {$op == "DELETE"} {
				#  Do batch delete
				_run_qry  core::db::trickle::${label}::del_tab [list {*}$lbetween_args {*}$where_args]
				set n_upd [core::db::garc -name core::db::trickle::${label}::del_tab]
				core::log::write INFO {$fn: Deleted $n_upd rows}
			} else {
				#  Do batch update
				_run_qry  core::db::trickle::${label}::upd_tab [list {*}$lbetween_args {*}$where_args]
				set n_upd [core::db::garc -name core::db::trickle::${label}::upd_tab]
				core::log::write INFO {$fn: Updated $n_upd rows}
			}
		} msg]
		switch -- $catch_ret {
			0 {
				core::db::commit_tran
			}
			default {
				core::log::write_error_info ERROR
				core::log::write ERROR {$fn: #### Rolling back due to ERROR: $msg}
				core::db::rollback_tran
				#  re-throw the error upwards
				return -code $catch_ret -errorinfo $::errorInfo -errorcode $::errorCode $msg
			}
		}
	}

	incr  U_STATE(iterations)
	set   U_STATE(last_rows)  $n_upd
	incr  U_STATE(total_rows) $n_upd

	# Swap here for next iteration
	set   U_STATE(curr_id) $next_id
	_upd_stats U_STATE
	core::log::write INFO {$fn: [format {Statistics: Rows upd %d, Compete %.0f%%, Remaining secs %0.2f} \
			[get -state_var U_STATE -param total_rows] \
			[get -state_var U_STATE -param done_perc]  \
			[get -state_var U_STATE -param time_remaining]  \
	]}
	core::log::write INFO {$fn: Estimated time to complete [get -state_var U_STATE -param etc_str]}

	core::log::set_prefix $prev_prefix
	return 1
}


core::args::register \
	-proc_name core::db::trickle::end \
	-desc {Cleans up after an iteration run} \
	-args      [list \
		[list -arg -state_var    -mand 1 -check ANY  -desc {Variable to hold the state of a run - will be reset during init}] \
	] -body {
	set fn {core::db::trickle::end}

	variable CONF
	upvar 1   $ARGS(-state_var) U_STATE
	core::log::write INFO {$fn: Ending - U_STATE [array get U_STATE]}
}

#
#
#
#
# Runs a query
# Returns results as a list
# of columns and rows concatenated
#
proc core::db::trickle::_run_qry {name {larg {}}} {
	set rs [core::db::exec_qry -name $name -args $larg]

	if {$rs == ""} {
		return {}
	}

	set lret [list]

	set nrows [db_get_nrows $rs]
	set ncols [db_get_ncols $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		for {set c 0} {$c < $ncols} {incr c} {
			lappend lret [db_get_coln $rs $i $c]
		}
	}
	core::db::rs_close -rs $rs
	return $lret
}

#  Escapes a value for unloading
#
proc core::db::trickle::_esc_unload {val} {
	set map [list "\n" "\\\n" "\r" "\\\r" "\\" "\\\\" "|" "\\|"]
	return [string map $map $val]
}

#   Opens a file
proc core::db::trickle::_open_file {out_file} {

	set fd [open $out_file a]
	fconfigure $fd -translation binary -buffering full
	return $fd
}

#   puts file - useful for unit testing
proc core::db::trickle::_puts_file {fd str} {
	puts -nonewline $fd $str
}

#   Flush file - useful for unit testing
proc core::db::trickle::_flush_file {fd} {
	flush $fd
}

#   Flush file - useful for unit testing
proc core::db::trickle::_close_file {fd} {
	close $fd
}


#   Writes a results set to a file
#   in an unload format.
proc core::db::trickle::_unload_rs_to_fd {fd rs} {
	set fn {core::db::trickle::_unload_rs_to_fd}

	set start_ms [OT_MicroTime]

	set nrows [db_get_nrows $rs]
	set ncols [db_get_ncols $rs]

	for {set i 0} {$i < $nrows} {incr i} {
		for {set c 0} {$c < $ncols} {incr c} {
			set val [db_get_coln $rs $i $c]
			_puts_file $fd [_esc_unload $val]
			_puts_file $fd  "|"
		}
		#  Newline
		_puts_file $fd "\n"
	}
	_flush_file $fd

	incr i
	core::log::write INFO {$fn: [format {Wrote %s rows in %.4f} $i [expr {[OT_MicroTime] - $start_ms}]]}
}

proc core::db::trickle::_store_qry {label name qry} {

	set qry_name core::db::trickle::${label}::${name}
	core::log::write INFO {== Query $qry_name ==}

	foreach l [split $qry "\n"] {
		core::log::write INFO {$name: $l}
	}

	core::db::store_qry \
		-name  $qry_name \
		-qry $qry
}

proc core::db::trickle::_upd_stats {state_var} {

	upvar $state_var U_STATE
	variable CONF

	set label $U_STATE(label)
	set order [dict get $CONF $label order]

	set min_id $U_STATE(min_id)
	set max_id $U_STATE(max_id)
	set id_range     [expr {$max_id - $min_id +1}]
	if {$U_STATE(curr_id) == {}} {
		set id_done      0
		set id_remaining $id_range
	} else {
		if {$order == "ASC"} {
			set id_done      [expr {$U_STATE(curr_id) - $min_id + 1}]
			set id_remaining [expr {$max_id - $U_STATE(curr_id)}]
		} else {
			set id_done      [expr {$max_id - $U_STATE(curr_id) + 1}]
			set id_remaining [expr {$U_STATE(curr_id) - $min_id}]
		}
	}
	set nrows    $U_STATE(nrows)
	set elapsed  [expr {[clock seconds] - $U_STATE(start_secs)}]

	if {$id_done < $id_range} {
		set done_perc [expr {$id_done/double($id_range)*100}]
		if {$id_done > 0} {
			set time_remaining [expr {$elapsed * $id_remaining / double($id_done)}]
		} else {
			set time_remaining 999
		}
	} else {
		set done_perc 100
		set time_remaining 0
	}

	set U_STATE(elapsed)        $elapsed
	set U_STATE(done_perc)      $done_perc
	set U_STATE(time_remaining) $time_remaining
	set U_STATE(etc) [expr {[clock seconds] + round($time_remaining)}]
	set U_STATE(etc_str)  [clock format $U_STATE(etc) -format {%Y-%m-%dT%H:%M:%S%z} ]
}
