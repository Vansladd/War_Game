# ==============================================================
# $Id: cust_flag_desc.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2008 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUSTFLAG {

	asSetAct ADMIN::CUSTFLAG::GoAdminCustFlagsDescList  [namespace code go_admin_cust_flags_desc_list]
	asSetAct ADMIN::CUSTFLAG::DoAdminCustFlag           [namespace code do_admin_cust_flag ]
	asSetAct ADMIN::CUSTFLAG::GoAdminCustFlag           [namespace code go_admin_cust_flag ]
	asSetAct ADMIN::CUSTFLAG::GoAdminCustFlagVal        [namespace code go_admin_cust_flag_val]
	asSetAct ADMIN::CUSTFLAG::DoAdminCustFlagVal        [namespace code do_admin_cust_flag_val]


#Binds all non-system flags from tCustFlagDesc
proc go_admin_cust_flags_desc_list args {

	global CUST_FLAGS DB

	if {![op_allowed ManageCustFlags]} {
		err_bind "You are not allowed to manage customer flags"
		asPlayFile "main_area.html"
		return
	}

	catch {unset CUST_FLAGS}

	set stmt [inf_prep_sql $DB {
		select
		flag_name,
		description,
		note,
		status
	from
		tcustflagdesc
	where
		type = 'U'
	}]

	set res [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set num_flags [db_get_nrows $res]

	tpSetVar NumFlag $num_flags

	for {set i 0 } { $i < $num_flags } { incr i } {

		foreach a [list "flag_name" "description" "note" "status" ] {
			set CUST_FLAGS($i,$a) [db_get_col $res $i $a]
		}
	}

	db_close $res

	tpBindVar Name   CUST_FLAGS   flag_name     flag_idx
	tpBindVar Desc   CUST_FLAGS   description   flag_idx
	tpBindVar Note   CUST_FLAGS   note          flag_idx
	tpBindVar Status CUST_FLAGS   status        flag_idx

	
	asPlayFile -nocache flags.html

}

#Bind data for a particular entry in tCustFlagDesc
proc go_admin_cust_flag args {

	global DB
	global FLAG_VAL

	catch {unset FLAG_VAL}

	set flag_name [reqGetArg flag_name]

	if {$flag_name == "" } {

		if {![op_allowed ManageCustFlags]} {
			err_bind "You are not allowed to manage customer flags"
			go_admin_cust_flags_desc_list
			return
		}

		tpSetVar add_flag 1

	} else {

		set stmt [inf_prep_sql $DB {
			select
				d.flag_name,
				d.description,
				d.note,
				d.status
			from
				tcustflagdesc d
			where
				d.flag_name = ?
		}]

		set res [inf_exec_stmt $stmt $flag_name]
		inf_close_stmt $stmt

		if {[db_get_nrows $res ] < 1 } {
			err_bind "Could not retrieve entry for this flag desc"
			go_admin_cust_flags_desc_list
			db_close $res
			return

		} else {

			tpBindString Name [db_get_col $res 0 flag_name ]
			tpBindString Desc [db_get_col $res 0 description]
			tpBindString Note [db_get_col $res 0 note]
			tpBindString Status [db_get_col $res 0 status ]

			db_close $res


			set stmt [inf_prep_sql $DB {
				select
					1 as editable,
					flag_value,
					description
				from
					tCustFlagVal
				where
					flag_name = ?
				union
				select unique
					0 as editable,
					flag_value,
					'(already associated with cust)' as description
				from
					tCustomerFlag
				where
					flag_name = ? and
					flag_value not in (
						select
							flag_value
						from
							tCustFlagVal
						where
							flag_name = ?
					)

			}]

			set res [inf_exec_stmt $stmt $flag_name $flag_name $flag_name]
			inf_close_stmt $stmt

			set nrows [db_get_nrows $res]
			tpSetVar nbVal $nrows


			for {set i 0 } { $i < $nrows } { incr i } {
				set FLAG_VAL($i,flag_value) [ db_get_col $res $i flag_value ]
				set FLAG_VAL($i,description) [ db_get_col $res $i description ]
				set FLAG_VAL($i,editable) [ db_get_col $res $i editable ]
			}

			tpBindVar Value        FLAG_VAL  flag_value  val_idx
			tpBindVar Description  FLAG_VAL  description val_idx
			tpBindVar Editable     FLAG_VAL  editable    val_idx

		}

		tpSetVar add_flag 0
	}

	asPlayFile flag.html


}

#Affect action to use when submitting
#a request.
proc do_admin_cust_flag args {

	if {![op_allowed ManageCustFlags]} {
		err_bind "You are not allowed to manage customer flags"
		go_admin_cust_flags_desc_list
		return
	}

	set action [reqGetArg SubmitName]

	switch -- $action {
		"Back" {
			go_admin_cust_flags_desc_list
		}
		"AddFlag" {
			do_insert_admin_cust_flag
		}
		"UpdFlag" {
			do_update_admin_cust_flag
		}
		"AddValue" {
			go_admin_cust_flag_val
		}
		default {
			go_admin_cust_flags_desc_list
		}
	}
}

#Update tCustomerFlagDesc
proc do_update_admin_cust_flag args {

	global DB

	set sql [subst {
		update
			tCustFlagDesc
		set
			description = ?,
			note = ?,
			status = ?,
			type = 'U'
		where
			flag_name = ?
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg description]\
			[reqGetArg note]\
			[reqGetArg status]\
			[reqGetArg flag_name] ]} msg]} {
		err_bind $msg
		OT_LogWrite ERROR "ADMIN::CUST unable to update flag $msg"
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_admin_cust_flag
		return
	}

	go_admin_cust_flags_desc_list
}

#Inserts flag in TCustFlagDesc
proc do_insert_admin_cust_flag args {

	global DB

	set sql [subst {
		insert into
			tCustFlagDesc(flag_name,description,note,status,type)
		values
			(?,?,?,?,'U')
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			[reqGetArg flag_name]\
			[reqGetArg description]\
			[reqGetArg note]\
			[reqGetArg status ] ]} msg]} {
		err_bind $msg
		OT_LogWrite ERROR "ADMIN::CUST unable to insert flag : $msg"
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_admin_cust_flag
		return
	}

	go_admin_cust_flags_desc_list

}

proc go_admin_cust_flag_val args {

	if {![op_allowed ManageCustFlags]} {
		err_bind "You are not allowed to manage customer flags"
		go_admin_cust_flags_desc_list
		return
	}

	set flag_name    [reqGetArg flag_name]
	set flag_value   [reqGetArg flag_value]
	set description  [reqGetArg description]

	if { $flag_name != "" } {

		tpBindString Name $flag_name

		if { $flag_value != "" } {
			tpSetVar add_value 0

			tpBindString Value $flag_value
			tpBindString Desc $description

		} else {

			tpSetVar add_value 1
		}

	} else {
		err_bind "Couldn't retrieve flag value"
		go_admin_cust_flags_desc_list
		return
	}

	asPlayFile flag_val.html

}

proc do_admin_cust_flag_val args {

	global DB

	if {![op_allowed ManageCustFlags]} {
		err_bind "You are not allowed to manage customer flags"
		go_admin_cust_flags_desc_list
		return
	}


	set action [reqGetArg SubmitName]
	switch -- $action {
		"Back" {
			go_admin_cust_flag
		}
		"AddVal" {
			set sql [subst {

				insert into tCustFlagVal(flag_name,flag_value,description) values (?,?,?)
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					[reqGetArg flag_name]\
					[reqGetArg flag_value]\
					[reqGetArg description] ]} msg]} {
				err_bind $msg
				OT_LogWrite ERROR "ADMIN::CUST unable to add flag value :$msg"
				go_admin_cust_flag
				return
			}

			go_admin_cust_flags_desc_list
		}
		"UpdVal" {
			set sql [subst {

				update tCustFlagVal set description = ? where flag_name= ? and flag_value = ?
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					[reqGetArg description]\
					[reqGetArg flag_name]\
					[reqGetArg flag_value] ]} msg]} {
				err_bind $msg
				OT_LogWrite ERROR "ADMIN::CUST unable to update flag value : $msg"
				go_admin_cust_flag
				return
			}

			go_admin_cust_flags_desc_list
		}
		"DelVal" {

			set sql [subst {

				delete from tCustFlagVal where flag_name= ? and flag_value = ?
			}]

			set stmt [inf_prep_sql $DB $sql]

			if {[catch {
				set res [inf_exec_stmt $stmt\
					[reqGetArg flag_name]\
					[reqGetArg flag_value] ]} msg]} {
				err_bind $msg
				OT_LogWrite ERROR "ADMIN::CUST unable to delete flag value : $msg"
				go_admin_cust_flag
				return
			}

			go_admin_cust_flags_desc_list
		}
		default {
			go_admin_cust_flag_desc_list
		}
	}

}



#close namespace
}