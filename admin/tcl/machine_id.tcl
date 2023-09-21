# $Id: machine_id.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
namespace eval ADMIN::MACHINE_ID {

	asSetAct ADMIN::MACHINE_ID::Home               [namespace code home]

	asSetAct ADMIN::MACHINE_ID::ViewBlockList      [namespace code machine_list]
	asSetAct ADMIN::MACHINE_ID::AddBlock           [namespace code add_machine]
	asSetAct ADMIN::MACHINE_ID::ViewMachine        [namespace code view_machine]
	asSetAct ADMIN::MACHINE_ID::UpdateMachine      [namespace code update_machine]
	asSetAct ADMIN::MACHINE_ID::UpdStatus          [namespace code upd_status]
	asSetAct ADMIN::MACHINE_ID::ChangedBlock       [namespace code changed_block]
	asSetAct ADMIN::MACHINE_ID::DoAddEdit          [namespace code do_add_edit]

	# These should probably be commented out in the live environment
	asSetAct ADMIN::MACHINE_ID::GenerateMachines   [namespace code generate_machines]
	asSetAct ADMIN::MACHINE_ID::AssociateCustomers [namespace code associate_customers]

	variable CFG
	set CFG(results_per_page) [OT_CfgGet MACHINE_ID_NO_RESULTS 20]
	set CFG(search_for)       [OT_CfgGet MACHINE_ID_SEARCH     "machine_list"]
}



# Shows the home page for machine blocking with a search box and a search
# results section.
proc ADMIN::MACHINE_ID::home args {

	if {[catch {
		set html_file [_search_machines]
	} msg]} {
		OT_LogWrite 8 $::errorInfo
		err_bind [string map {"\n" "<br />"} $msg]
		asPlayFile machine_id/list.html
		return
	}

	asPlayFile -nocache $html_file
}



# Shows the details of a single machine given by [reqGetArg machine_id]
proc ADMIN::MACHINE_ID::view_machine args {
	tpBindString Title "Machine Details"
	if {[reqGetArg machine_id] == ""} {
		err_bind "Must supply a machine_id"
	} else {
		_bind_machine_details [reqGetArg machine_id]
	}
	asPlayFile -nocache machine_id/view.html
}



# Shows the add/edit machine page
proc ADMIN::MACHINE_ID::add_machine {} {
	tpBindString Title "Add Machine"
	asPlayFile -nocache machine_id/add_edit.html
}



# Shows the add/edit machine page
# with pre-populated information for machine_id
proc ADMIN::MACHINE_ID::update_machine {} {
	tpBindString Title "Update Machine"
	_bind_machine_details [reqGetArg machine_id]
	asPlayFile -nocache machine_id/add_edit.html
}



# Performs the database insert/update
proc ADMIN::MACHINE_ID::do_add_edit {} {

	set machine_id   [reqGetArg machine_id]
	set machine_code [reqGetArg machine_code]
	set comment      [reqGetArg comment]

	if {$machine_id == ""} {
		# This is an add
		set action_string "added"
		if {[catch {
			set rs [_exec_qry add_machine $machine_code $comment]
		} msg]} {
			set msg "Machine was not added: $msg"
			OT_LogWrite 1 $msg
			err_bind $msg
			add_machine
			return
		} else {
			msg_bind "The machine was added successfully"
		}
	} else {
		# This is an update
		if {[catch {
			set rs [_exec_qry update_machine $machine_code $comment $machine_id]
		} msg]} {
			set msg "Machine was not updated: $msg"
			OT_LogWrite 1 $msg
			err_bind $msg
			update_machine
			return
		} else {
			msg_bind "The machine was updated successfully"
		}
	}

	db_close $rs
	home
}



# Update machine status
proc ADMIN::MACHINE_ID::upd_status args {

	set id     [reqGetArg machine_id]
	set status [reqGetArg machine_status]
	set note   [reqGetArg machine_desc]

	switch -- $status {
		S {
			if {![string length $note]} {
				err_bind "Please add a note when blocking a machine."
				home
				return
			}
			set desc "blocked"
		}
		A {set desc "unblocked"}
		X {set desc "deleted"}
	}

	if {[catch {
		_exec_qry upd_status $status $note $id
	} msg]} {
		err_bind $msg
	} else {
		msg_bind "Machine $id $desc."
	}

	home
}



# Returns the first non-empty value
proc ADMIN::MACHINE_ID::_nvl {args} {
	foreach arg $args {
		if {$arg != ""} {
			return $arg
		}
	}
}



# Execures query_name with args and returns the result set
proc ADMIN::MACHINE_ID::_exec_qry {qry args} {

	global   DB
	variable QRY

	if {[info exists QRY($qry)]} {
		set qry $QRY($qry)
	}

	if {[catch {
		set stmt [inf_prep_sql $DB $qry]
	} msg]} {
		error "Error preparing query: $msg, query=$qry"
	}

	if {[catch {
		set rs [eval inf_exec_stmt $stmt $args]
	} msg]} {
		inf_close_stmt $stmt
		error "Error executing query: $msg"
	}
	inf_close_stmt $stmt

	catch {
		OT_LogWrite 8 "_exec_qry: [db_get_nrows $rs] rows returned."
	}

	return $rs
}



# Binds a result set
# Takes an optional transform_function parameter which will be applied to
# each data element individually. Transform function must be of the form:
#   proc ADMIN::MACHINE_ID::trans {value colname row}
# The transformed value will be bound to colname_str.
#
# If display_order is non-empty then the resultset will be bound in the
# opposite order.
proc ADMIN::MACHINE_ID::_bind_rs {rs array_name idx {transform_function {}} {display_order {desc}}} {

	global $array_name

	OT_LogWrite 8 "-->id_blocking::_bind_rs array_name=$array_name"

	if {$display_order == "desc"} {
		set row_expr {$row}
	} else {
		# Order is reversed
		set row_expr {[expr {[db_get_nrows $rs] - 1 - $row}]}
	}

	for {set row 0} {$row < [db_get_nrows $rs]} {incr row} {

		foreach colname [db_get_colnames $rs] {
			set ${array_name}($row,$colname) [eval db_get_col $rs $row_expr $colname]

			if {$transform_function != ""} {
				set ${array_name}($row,${colname}_str)\
					[$transform_function [eval db_get_col $rs $row_expr $colname] \
					$colname $row]
			}
		}
	}

	foreach colname [db_get_colnames $rs] {
		tpBindVar $colname $array_name $colname $idx

		if {$transform_function != ""} {
			tpBindVar ${colname}_str $array_name ${colname}_str $idx
		}
	}
}



# Transforms the database values to how we like to display them
proc ADMIN::MACHINE_ID::_machine_db_transform {value colname row} {
	switch $colname {
		"status" {
			switch $value {
				"A" { return "Not blocking" }
				"S" { return "Blocking" }
				"X" { return "Deleted" }
			}
		}
		"cr_date" {
			return  [lindex [split $value { }] 0]
		}
	}
	return $value
}



# Binds the details for a single machine given by machine_id
proc ADMIN::MACHINE_ID::_bind_machine_details {machine_id} {

	if {[catch {
		set rs [_exec_qry get_machine_by_id [reqGetArg machine_id]]
	} msg]} {
		err_bind $msg
		return
	}

	if {[db_get_nrows $rs] != 1} {
		err_bind "Query returned not exactly one row. [db_get_nrows $rs] \
		          rows were returned for machine_id=$machine_id"
		return
	}

	foreach colname [db_get_colnames $rs] {
		tpBindString $colname \
			[_machine_db_transform [db_get_col $rs 0 $colname] $colname 0]
	}
}



# Converts search_action 'next' and 'prev' to the
# appropriate query/search ordering
proc ADMIN::MACHINE_ID::_get_search_order {query_index} {

	variable QRY

	if {$QRY($query_index,order) == "asc"} {
		if {[reqGetArg search_action] == "prev"} {
			return "desc"
		} else {
			return "asc"
		}

	} else {
		# Desc
		if {[reqGetArg search_action] == "prev"} {
			return "asc"
		} else {
			return "desc"
		}
	}
}



# Rebinds the search preferences and search query strings
proc ADMIN::MACHINE_ID::_rebind_search_params {} {

	variable CFG
	variable QRY

	if {[reqGetArg search_machine_code_exact] == "on"} {
		tpBindString search_machine_code_exact "checked"
	} else {
		tpBindString search_machine_code_exact ""
	}

	if {[reqGetArg search_username_exact] == "on"} {
		tpBindString search_username_exact "checked"
	} else {
		tpBindString search_username_exact ""
	}

	# Query parameters
	tpBindString search_query [join [list \
		"search_username=[reqGetArg search_username]" \
		"search_username_exact=[reqGetArg search_username_exact]" \
		"search_machine_code=[reqGetArg search_machine_code]" \
		"search_machine_code_exact=[reqGetArg search_machine_code_exact]" \
		"search_for=[reqGetArg search_for]"] \
		"&"] ;# Join with the ampersand

	# Default search
	set search_for [_nvl [reqGetArg search_for] $CFG(search_for)]

	switch --  $search_for {
		"machine_list" {
			set id_colname_list $QRY(machine_list,id_colname)
		}
		"machine_login_history" {
			set id_colname_list $QRY(login_history,id_colname)
		}
		"machine_account_summary" {
			set id_colname_list $QRY(account_summary,id_colname)
		}
		default {
			set msg "Invalid search_for ([reqGetArg search_for]) must be:\
				machine_list, machine_login_history, machine_account_summary"
			err_bind $msg
			error $msg
		}
	}

	# Paging parameters
	for {set i 0} {$i < [expr [llength $id_colname_list]-1]} {incr i} {
		set id_colname [lindex $id_colname_list $i]
		lappend search_page "${id_colname_list}_gte=[reqGetArg ${id_colname_list}_gte]"
		lappend search_page "${id_colname_list}_lte=[reqGetArg ${id_colname_list}_lte]"
	}

	set id_colname [lindex $id_colname_list $i]
	lappend search_page "${id_colname_list}_gt=[reqGetArg ${id_colname_list}_gt]"
	lappend search_page "${id_colname_list}_lt=[reqGetArg ${id_colname_list}_lt]"

	tpBindString search_page [join $search_page "&"]

	# Search settings
	tpBindString search_settings "results_per_page=[reqGetArg results_per_page]"
}



# Performs the search given by query_index by substituting appropriate
# values from the search form
proc ADMIN::MACHINE_ID::_execute_search_query {
	query_index results_per_page machine_code username
} {

	variable QRY

	# page_zero is inferred to be true if there are no id limits
	# This will be set to 0 if an id limit is found
	set page_zero 1

	if {[catch {
		set id_colname_list  $QRY($query_index,id_colname)
		set table_alias_list $QRY($query_index,table_alias)
		set query            $QRY($query_index)
	} msg]} {
		set msg "QRY not configured correctly: $msg"
		OT_LogWrite 1 $msg
		error $msg
	}

	# Generate the query by substitution
	#
	#
	# Generate the order_by clause
	set search_order [_get_search_order $query_index]
	tpBindString order $search_order

	for {set i 0} {$i < [llength $table_alias_list]} {incr i} {
		lappend column_list "[lindex $table_alias_list $i].[lindex $id_colname_list $i]"
	}
	set order_by "order by [join $column_list ","] $search_order"

	# Generate the id limits based on table_alias_list and id_colname_list
	set where [list ]

	for {set i 0} {$i < [expr [llength $table_alias_list]-1]} {incr i} {
		set table_alias [lindex $table_alias_list $i]
		set id_colname  [lindex $id_colname_list $i]

		set id_gte [reqGetArg ${id_colname}_gte]
		set id_lte [reqGetArg ${id_colname}_lte]

		if {$id_gte != ""} {
			lappend where "${table_alias}.${id_colname} >= $id_gte"
			set page_zero 0
		}

		if {$id_lte != ""} {
			lappend where "${table_alias}.${id_colname} <= $id_lte"
			set page_zero 0
		}
	}

	set table_alias [lindex $table_alias_list $i]
	set id_colname  [lindex $id_colname_list $i]

	set id_gt [reqGetArg ${id_colname}_gt]
	set id_lt [reqGetArg ${id_colname}_lt]

	if {$id_gt != ""} {
		lappend where "${table_alias}.${id_colname} > $id_gt"
		set page_zero 0
	}

	if {$id_lt != ""} {
		lappend where "${table_alias}.${id_colname} < $id_lt"
		set page_zero 0
	}

	set where [join $where " and "]


	# Substitute variables into the query
	set query [subst $query]

	OT_LogWrite 10 "query $query"

	# Execute the query with given parameters
	set rs [_exec_qry $query $machine_code $username]

	# If we have more than one row bind the paging variables
	if {[db_get_nrows $rs] > 1} {
		# Bind the paging variables

		for {set i 0} {$i < [expr [llength $id_colname_list]-1]} {incr i} {
			set id_colname  [lindex $id_colname_list $i]

			# Store the highest and lowest ids
			# We have one more row than displayed, so the last_id is end-2
			if {$search_order == "asc"} {
				set lowest_id   [db_get_col $rs 0 $id_colname]
				set highest_id  [db_get_col $rs [expr [db_get_nrows $rs]-2] $id_colname]
			} else {
				set highest_id  [db_get_col $rs 0 $id_colname]
				set lowest_id   [db_get_col $rs [expr [db_get_nrows $rs]-2] $id_colname]
			}

			if {$QRY($query_index,order) == "desc"} {
				lappend search_next "${id_colname}_gte=${highest_id}"
				lappend search_prev "${id_colname}_lte=${lowest_id}"
			} else {
				lappend search_next "${id_colname}_gte=${lowest_id}"
				lappend search_prev "${id_colname}_lte=${highest_id}"
			}
		}

		set id_colname  [lindex $id_colname_list $i]
		if {$search_order == "asc"} {
			set lowest_id   [db_get_col $rs 0 $id_colname]
			set highest_id  [db_get_col $rs [expr [db_get_nrows $rs]-2] $id_colname]
		} else {
			set highest_id  [db_get_col $rs 0 $id_colname]
			set lowest_id   [db_get_col $rs [expr [db_get_nrows $rs]-2] $id_colname]
		}

		if {$QRY($query_index,order) == "asc"} {
			lappend search_next "${id_colname}_gt=${highest_id}"
			lappend search_prev "${id_colname}_lt=${lowest_id}"
		} else {
			lappend search_next "${id_colname}_lt=${lowest_id}"
			lappend search_prev "${id_colname}_gt=${highest_id}"
		}

		lappend search_next "search_action=next"
		lappend search_prev "search_action=prev"

		tpBindString search_next_page [join $search_next "&"]
		tpBindString search_prev_page [join $search_prev "&"]
	}

	# Bind the total number of rows for this query with id limits
	# (if this kind of count query is available)
	if {[db_get_nrows $rs] < $results_per_page && $page_zero} {
		tpBindString total_rows [db_get_nrows $rs]
	} elseif {[info exists QRY($query_index,count)] &&
			  ($machine_code != "%" || $username != "%")} {
		set total_rs [_exec_qry $query_index,count $machine_code $username]
		tpBindString total_rows [db_get_col $total_rs 0 count]
	} else {
		tpBindString total_rows "'unknown'"
	}

	# Are there more pages available?
	# Paging works by assuming that if we got the number of rows we asked
	# for, then there are more pages in the direction we are going.
	# There are always more pages in the opposite direction, unless we are
	# on the first page.
	if {$search_order == $QRY($query_index,order)} {

		if {$page_zero == 0} {
			tpBindString more_prev 1
		}

		if {[db_get_nrows $rs] == $results_per_page} {
			tpBindString more_next 1
			db_del_row $rs [expr [db_get_nrows $rs] - 1]
		} else {
			tpBindString more_next 0
		}
	} else {
		tpBindString more_next 1

		if {[db_get_nrows $rs] == $results_per_page} {
			tpBindString more_prev 1
			db_del_row $rs [expr [db_get_nrows $rs] - 1]
		} else {
			tpBindString more_prev 0
		}
	}

	# Rebind search parameters
	_rebind_search_params

	return $rs
}



# Processes the machine search form.
# Returns the name of the html file that should be played to display the
# results.
proc ADMIN::MACHINE_ID::_search_machines args {

	variable CFG
	variable QRY

	set log_prefix {ADMIN::MACHINE_ID::_search_machines}

	OT_LogWrite 8 "$log_prefix"
	OT_LogWrite 8 "$log_prefix: machine_code = [reqGetArg search_machine_code]"
	OT_LogWrite 8 "$log_prefix: m_exact      = [reqGetArg search_machine_code_exact]"
	OT_LogWrite 8 "$log_prefix: username     = [reqGetArg search_username]"
	OT_LogWrite 8 "$log_prefix: u_exact      = [reqGetArg search_username_exact]"

	# Set default search parameters
	# Get desired rows +1 so we can know if there are more results
	set results_per_page [_nvl [reqGetArg results_per_page] $CFG(results_per_page)]
	set results_per_page [expr $results_per_page + 1]

	# Default search
	set search_for [_nvl [reqGetArg search_for] $CFG(search_for)]

	switch -- $search_for {
		"machine_list" {
			tpBindString Title "Machine List"
			set query_index machine_list
			set html_file   machine_id/list.html
		}
		"machine_account_summary" {
			tpBindString Title "Machine Account Summary"
			set query_index account_summary
			set html_file   machine_id/account_summary.html
		}
		"machine_login_history" {
			tpBindString Title "Machine Login History"
			set query_index login_history
			set html_file   machine_id/login_history.html
		}
		default {
			error "Invalid search_for ([reqGetArg search_for]) must be:\
			       machine_list, machine_login_history, machine_account_summary"
		}
	}

	set search_machine_code [reqGetArg search_machine_code]
	set search_username     [reqGetArg search_username]

	# Check whether to use exact matching
	if {![string length [reqGetArg search_machine_code_exact]]} {
		append search_machine_code "%"
	}

	if {![string length [reqGetArg search_username_exact]]} {
		append search_username "%"
	}

	set search_rs [_execute_search_query \
		$query_index \
		$results_per_page \
		$search_machine_code \
		$search_username]

	# Bind the results
	set      num_rows   [db_get_nrows $search_rs]
	tpSetVar NumRows    $num_rows
	_bind_rs $search_rs RESULTS results_idx _machine_db_transform [_get_search_order $query_index]

	db_close $search_rs

	return $html_file
}



proc ADMIN::MACHINE_ID::init args {

	variable QRY

	set QRY(get_machine_by_id) {
		select
			*
		from
			tMachine
		where
			machine_id = ?
	}

	set QRY(add_machine) {
		insert into tMachine (
			machine_code,
			description
		)
		values (
			?,
			?
		)
	}

	set QRY(update_machine) {
		update
			tMachine
		set
			machine_code = ?,
			description  = ?
		where
			machine_id   = ?
	}

	set QRY(upd_status) {
		update
			tMachine
		set
			status      = ?,
			description = ?
		where
			machine_id = ?
	}

	# Queries for searching ###########################################
	# Note that the variables will need to be set, and the subst will
	# be required at the point of evaluation
	#

	## Machine List ##
	set QRY(machine_list,id_colname)   [list machine_id]
	set QRY(machine_list,table_alias)  [list m]
	set QRY(machine_list,order)        desc


	set QRY(machine_list) {
		select first $results_per_page
			m.cr_date,
			m.machine_id,
			m.machine_code,
			m.status,
			(
				select
					count(*)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id
			) as logins,
			(
				select
					count(distinct cust_id)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id
			) as accounts
		from
			tMachine     m
		where
			m.status <> 'X'
		and m.machine_code  like ?
		[expr {$username != "%" ? "
			and exists (
					select
						1
					from
						tMachineCust mc,
						tCustomer c
					where
						mc.machine_id = m.machine_id
					and c.cust_id = mc.cust_id
					and c.username like ?
				)
		" : ""}]
		[expr {$where != "" ? "
			and $where
		": ""}]
		$order_by
	}

	set QRY(machine_list,count) {
		select
			count(distinct mc.machine_id) as count
		from
			tMachine     m,
			tMachineCust mc,
			tCustomer    c
		where
			m.machine_id    = mc.machine_id and
			mc.cust_id      = c.cust_id     and
			m.machine_code  like ?          and
			c.username      like ?          and
			m.status <> 'X'
	}

	## Account Summary ##
	set QRY(account_summary,id_colname)   [list machine_id cust_id]
	set QRY(account_summary,table_alias)  [list m c]
	set QRY(account_summary,order)        desc

	set QRY(account_summary) {
		select first $results_per_page distinct
			m.machine_id,
			(
				select
					count(*)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id and
					c.cust_id    = mc.cust_id
			) as logins,
			(
				select
					min(cr_date)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id and
					c.cust_id    = mc.cust_id
			) as first_login,
			(
				select
					max(cr_date)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id and
					c.cust_id    = mc.cust_id
			) as last_login,
			m.status,
			m.machine_code,
			c.cust_id,
			c.username
		from
			tMachine m,
			tMachineCust mc,
			tCustomer c
		where
			m.machine_id    = mc.machine_id and
			mc.cust_id      = c.cust_id     and
			m.machine_code  like ?          and
			c.username      like ?          and
			m.status       <> 'X'
			[expr {$where!=""?"and $where":""}]
		group by
			mc.cust_id,
			mc.machine_id,
			m.machine_id,
			m.status,
			m.machine_code,
			c.cust_id,
			c.username
		$order_by
	}

	# Counting account_summary total is not feasible because of the distinct
	# accross two columns

	## Login History ##
	set QRY(login_history,id_colname)   [list machine_cust_id]
	set QRY(login_history,table_alias)  [list mc]
	set QRY(login_history,order)        desc

	set QRY(login_history) {
		select first $results_per_page
			mc.machine_cust_id,
			mc.cr_date,
			(
				select
					count(*)
				from
					tMachineCust mc
				where
					m.machine_id = mc.machine_id and
					c.cust_id    = mc.cust_id
			) as logins,
			m.machine_id,
			m.machine_code,
			m.status,
			c.cust_id,
			c.username
		from
			tMachine     m,
			tMachineCust mc,
			tCustomer    c
		where
			m.machine_id    = mc.machine_id and
			mc.cust_id      = c.cust_id     and
			m.machine_code  like ?          and
			c.username      like ?          and
			m.status        <> 'X'
			[expr {$where!=""?"and $where":""}]
		$order_by
	}

	set QRY(login_history,count) {
		select
			count(*) as count
		from
			tMachine     m,
			tMachineCust mc,
			tCustomer    c
		where
			m.machine_id    = mc.machine_id and
			mc.cust_id      = c.cust_id     and
			m.machine_code  like ?          and
			c.username      like ?          and
			m.status        <> 'X'
	}


}

ADMIN::MACHINE_ID::init
