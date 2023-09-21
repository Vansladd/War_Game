# ==============================================================
# $Id: customersort.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::CUSTSORT {

asSetAct ADMIN::CUSTSORT::GoCustSortList [namespace code go_cust_sort_list]
asSetAct ADMIN::CUSTSORT::GoCustSort     [namespace code go_cust_sort]
asSetAct ADMIN::CUSTSORT::DoCustSort     [namespace code do_cust_sort]

asSetAct ADMIN::CUSTSORT::GoCustCode     [namespace code go_cust_code]
asSetAct ADMIN::CUSTSORT::DoCustCode     [namespace code do_cust_code]

asSetAct ADMIN::CUSTSORT::GoLiabGroup    [namespace code go_liab_group]
asSetAct ADMIN::CUSTSORT::DoLiabGroup    [namespace code do_liab_group]

proc go_cust_sort_list {} {

	global DB CUSTOMERSORT CUSTOMERCODE
	global LIAB_GROUP_COLOUR COLOURMAP

	set sql {
		select
			sort,
			desc,
			commission_rate,
			tax_rate
		from
			tCustomerSort
		order by
			sort
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set CUSTOMERSORT($r,Sort)           [db_get_col $rs $r sort]
		set CUSTOMERSORT($r,Desc)           [db_get_col $rs $r desc]
		set CUSTOMERSORT($r,CommissionRate) [db_get_col $rs $r commission_rate]
		set CUSTOMERSORT($r,TaxRate)        [db_get_col $rs $r tax_rate]
	}

	tpSetVar NumSorts $nrows

	db_close $rs

	tpBindVar Sort           CUSTOMERSORT Sort           idx
	tpBindVar Desc           CUSTOMERSORT Desc           idx
	tpBindVar CommissionRate CUSTOMERSORT CommissionRate idx
	tpBindVar TaxRate        CUSTOMERSORT TaxRate        idx


	set sql {
		select
			cust_code,
			desc
		from
			tCustCode
		order by
			Cust_code
	}

	set stmt [inf_prep_sql $DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		set CUSTOMERCODE($r,Code)           [db_get_col $rs $r cust_code]
		set CUSTOMERCODE($r,Desc)           [db_get_col $rs $r desc]
	}

	tpSetVar NumCodes $nrows

	db_close $rs

	tpBindVar Code           CUSTOMERCODE Code           idx
	tpBindVar CodeDesc       CUSTOMERCODE Desc           idx

	#
	# Liability Groups
	#
	set sql {
		select
			liab_group_id,
			liab_desc,
			disp_order,
			intercept_value,
			colour
		from
			tLiabGroup
		order by
			disp_order
	}

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]

	inf_close_stmt $stmt

	set nrows [db_get_nrows $res]

	tpSetVar NumLiabGroups $nrows

	tpBindTcl LiabGroupId    sb_res_data $res liab_group_idx liab_group_id
	tpBindTcl DispOrder      sb_res_data $res liab_group_idx disp_order
	tpBindTcl LiabDesc       sb_res_data $res liab_group_idx liab_desc
	tpBindTcl InterceptValue sb_res_data $res liab_group_idx intercept_value
	tpBindTcl Colour_Rgb     sb_res_data $res liab_group_idx colour

	# Need to get a colour name for the rgb
	# This solution is slightly messy but better than the alternatives for now
	# Loop through the config apps until we find a matching name for our rgb hex

	if {![info exists LIAB_GROUP_COLOUR]} {
		init_liab_group_colours
	}

	for {set i 0} {$i < $nrows} {incr i} {

		set colour_rgb   [db_get_col $res $i colour]
		set match_found  0

		# Go through the list of liab_group_colours till we find a match
		for {set j 0} {$j < $LIAB_GROUP_COLOUR(total)} {incr j} {

			if {$LIAB_GROUP_COLOUR($j,rgb) == $colour_rgb} {
				set COLOURMAP($i,name) $LIAB_GROUP_COLOUR($j,name)
				set match_found        1
				break
			}

		}

		if {!$match_found} {
			# If we've gotten this far without a match it
			# is because it has not been set in the configs
			set COLOURMAP($i,name) "Colour"
		}
	}

	tpBindVar Colour_Name COLOURMAP name liab_group_idx

	asPlayFile -nocache customersort.html
}


proc go_cust_sort {} {

	global DB

	set sort [reqGetArg Sort]

	if {$sort == ""} {

		tpSetVar opAdd 1

	} else {

		set sql [subst {
			select
				sort,
				desc,
				commission_rate,
				tax_rate
			from
				tCustomerSort
			where
				sort = '$sort'
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpBindString Sort           [db_get_col $rs 0 sort]
		tpBindString Desc           [db_get_col $rs 0 desc]
		tpBindString CommissionRate [db_get_col $rs 0 commission_rate]
		tpBindString TaxRate        [db_get_col $rs 0 tax_rate]

		db_close $rs
	}

	asPlayFile -nocache cust_sort.html
}


proc do_cust_sort {} {

	switch -- [reqGetArg SubmitName] {
		SortDel {
			delete_cust_sort
		}
		SortMod {
			modify_cust_sort
		}
		SortAdd	{
			add_cust_sort
		}
		Back {
			go_cust_sort_list
			return
		}
	}
	go_cust_sort_list
}


proc delete_cust_sort {} {

	global DB

	set sql {
		delete from
			tCustomerSort
		where
			sort = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt [reqGetArg Sort]
	} msg]} {
		tpBindString Error "Cannot delete this customer sort"
	}

	inf_close_stmt $stmt
}


proc add_cust_sort {} {

	global DB

	set sql {
		insert into tCustomerSort(
			sort, desc, commission_rate, tax_rate
		)
		values (
			?, ?, ?, ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt\
			[reqGetArg Sort]\
			[reqGetArg Desc]\
			[reqGetArg CommissionRate]\
			[reqGetArg TaxRate]
	} msg]} {
		if {[regexp {.*Unique constraint (.*) violated.*} $msg]} {
			set msg "Sort [reqGetArg Sort] is already in use"
		}
		err_bind $msg
	}

	inf_close_stmt $stmt

}


proc modify_cust_sort {} {

	global DB

	set sql {
		update tCustomerSort set
			desc = ?,
			commission_rate = ?,
			tax_rate = ?
		where
			sort = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_exec_stmt $stmt\
		[reqGetArg Desc]\
		[reqGetArg CommissionRate]\
		[reqGetArg TaxRate]\
		[reqGetArg Sort]

	inf_close_stmt $stmt
}



proc go_cust_code {} {

	global DB

	set code [reqGetArg Code]

	if {$code == ""} {

		tpSetVar opAdd 1

	} else {

		set sql [subst {
			select
				cust_code,
				desc
			from
				tCustcode
			where
				cust_code = '$code'
		}]

		set stmt [inf_prep_sql $DB $sql]
		set rs [inf_exec_stmt $stmt]
		inf_close_stmt $stmt

		tpBindString Code           [db_get_col $rs 0 cust_code]
		tpBindString Desc           [db_get_col $rs 0 desc]

		db_close $rs
	}

	asPlayFile -nocache cust_code.html
}


proc do_cust_code {} {

	switch -- [reqGetArg SubmitName] {
		CodeDel {
			delete_cust_code
		}
		CodeMod {
			modify_cust_code
		}
		CodeAdd	{
			add_cust_code
		}
		Back {
			go_cust_sort_list
			return
		}
	}
	go_cust_sort_list
}


proc delete_cust_code {} {

	global DB

	set sql {
		execute procedure pDelCustCode(
			p_cust_code = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt [reqGetArg Code]
	} msg]} {
		tpBindString Error "Cannot delete this customer code: $msg"
	}

	inf_close_stmt $stmt
}

proc modify_cust_code {} {

	global DB

	set sql {
		update tCustcode set
			desc = ?
		where
			cust_code = ?
	}

	set stmt [inf_prep_sql $DB $sql]

	inf_exec_stmt $stmt\
		[reqGetArg Desc]\
		[reqGetArg Code]

	inf_close_stmt $stmt
}


proc add_cust_code {} {

	global DB

	set sql {
		execute procedure pInsCustCode(
			p_cust_code = ?,
			p_desc = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		inf_exec_stmt $stmt\
			[reqGetArg Code]\
			[reqGetArg Desc]
	} msg]} {
		if {[regexp {.*Unique constraint (.*) violated.*} $msg]} {
			set msg "Code [reqGetArg Code] is already in use"
		}
		err_bind $msg
	}

	inf_close_stmt $stmt

	# add cust sort permissions for debt management
	if {[OT_CfgGet FUNC_DEBT_MANAGEMENT 0] == 1} {
		set add_perm {
			insert into tAdminOp (type, action, desc)
			values ('CSV',  ? , ? );
		}
		set code [reqGetArg Code]
		set action "DebtManSort_$code"
		set desc   "Debt management permission for customer group $code"
		set stmt [inf_prep_sql $DB $add_perm]
		if {[catch {		
			inf_exec_stmt $stmt $action $desc
		} msg]} {
			if {[regexp {.*Unique constraint (.*) violated.*} $msg]} {
				set msg "Code $code is already in use"
			}
			err_bind $msg
		}
		inf_close_stmt $stmt
	}
}

proc go_liab_group {{add 0}} {

	global DB

	set liab_group_id [reqGetArg LiabGroupId]

	if {$liab_group_id == "" || $add} {

		tpSetVar opAdd 1

	} else {

		set sql {
			select
				liab_group_id,
				liab_desc,
				disp_order,
				intercept_value,
				colour
			from
				tLiabGroup
			where
				liab_group_id = ?
		}

		set stmt [inf_prep_sql $DB $sql]
		set res [inf_exec_stmt $stmt $liab_group_id]
		inf_close_stmt $stmt

		tpBindString LiabGroupId       [db_get_col $res 0 liab_group_id]
		tpBindString DispOrder         [db_get_col $res 0 disp_order]
		tpBindString LiabDesc          [db_get_col $res 0 liab_desc]
		tpBindString InterceptValue    [db_get_col $res 0 intercept_value]
		tpBindString Colour            [db_get_col $res 0 colour]

		db_close $res
	}

	bind_liab_group_colours

	asPlayFile -nocache liab_group.html
}


proc do_liab_group {} {

	switch -- [reqGetArg SubmitName] {
		GroupDel {
			delete_liab_group
		}
		GroupMod {
			modify_liab_group
		}
		GroupAdd	{
			add_liab_group
		}
		Back -
		default {
			go_cust_sort_list
		}
	}
}


proc delete_liab_group {} {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelLiabGroup(
			p_adminuser = ?,
			p_liab_group_id = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		inf_exec_stmt $stmt $USERNAME [reqGetArg LiabGroupId]
	} msg]} {
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt

	if {$bad} {
		go_liab_group
		return
	}

	go_cust_sort_list
}

proc modify_liab_group {} {

	global DB USERNAME

	set sql {
		execute procedure pUpdLiabGroup(
			p_adminuser = ?,
			p_liab_group_id = ?,
			p_liab_desc = ?,
			p_disp_order = ?,
			p_intercept_value = ?,
			p_colour = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		inf_exec_stmt $stmt $USERNAME \
			[reqGetArg LiabGroupId] \
			[reqGetArg LiabDesc]\
			[reqGetArg DispOrder]\
			[reqGetArg InterceptValue]\
			[reqGetArg Colour]
	} msg]} {
		set bad 1
		err_bind $msg
	}

	inf_close_stmt $stmt

	if {$bad} {
		go_liab_group
		return
	}
	go_cust_sort_list
}


proc add_liab_group {} {

	global DB USERNAME

	set sql {
		execute procedure pInsLiabGroup(
			p_adminuser = ?,
			p_liab_group_id = ?,
			p_liab_desc = ?,
			p_disp_order = ?,
			p_intercept_value = ?,
			p_colour = ?
		)
	}

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	set disporder [reqGetArg DispOrder]
	if {$disporder == ""} {
		set disporder 0
	}

	if {[catch {
		inf_exec_stmt $stmt $USERNAME \
				[reqGetArg LiabGroupId]\
				[reqGetArg LiabDesc] \
				$disporder \
				[reqGetArg InterceptValue]\
				[reqGetArg Colour]
	} msg]} {
		set bad 1
		if {[regexp {.*Unique constraint (.*) violated.*} $msg]} {
			set msg "Code [reqGetArg LiabGroupId] is already in use"
		}
		err_bind $msg
	}

	inf_close_stmt $stmt

	if {$bad} {
		rebind_request_data
		go_liab_group 1
		return
	}

	go_cust_sort_list
}

proc bind_liab_group_colours {} {

	global LIAB_GROUP_COLOUR

	if {![info exists LIAB_GROUP_COLOUR]} {
		init_liab_group_colours
	}

	tpSetVar   NumLiabGroupColours $LIAB_GROUP_COLOUR(total)

	tpBindVar Colour_Name LIAB_GROUP_COLOUR  name liab_group_colour_idx
	tpBindVar Colour_Rgb  LIAB_GROUP_COLOUR  rgb  liab_group_colour_idx


}

proc init_liab_group_colours {} {

	global LIAB_GROUP_COLOUR

	set LIAB_GROUP_COLOURS [OT_CfgGet LIAB_GROUP_COLOURS]

	set LIAB_GROUP_COLOUR(total) 0

	foreach colour $LIAB_GROUP_COLOURS {

		foreach {name rgb} $colour {
			set i $LIAB_GROUP_COLOUR(total)
			set LIAB_GROUP_COLOUR($i,name) $name
			set LIAB_GROUP_COLOUR($i,rgb)  $rgb
			incr LIAB_GROUP_COLOUR(total)
		}
	}
}

# Rebind data sent in the request.
#   For playback of original page.
proc rebind_request_data {} { 
        for {set i 0} {$i < [reqGetNumVals]} {incr i} { 
                reqSetArg [reqGetNthName $i] [reqGetNthVal $i]
        }

        # Rebind all the sent data.
        for {set n 0} {$n < [reqGetNumVals]} {incr n} { 
                tpBindString [reqGetNthName $n] [reqGetNthVal $n]
        }
}

}
