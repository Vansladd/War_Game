# ==============================================================
# $Id: thirdparty.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# File for handling admin pages for Third Parties
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::THIRDPARTY {
	
asSetAct ADMIN::THIRDPARTY::GoThirdParties  [namespace code go_third_party_list]
asSetAct ADMIN::THIRDPARTY::GoThirdPartyMod [namespace code go_third_party_mod]
asSetAct ADMIN::THIRDPARTY::DoThirdParty    [namespace code do_third_party]

# Show the list of Third Parties
proc go_third_party_list args {
	global DB THIRD_PARTIES

	tpSetVar NumThirdParties [bind_third_parties THIRD_PARTIES]

	asPlayFile -nocache third_party_list.html

	catch {unset THIRD_PARTIES}
}

# Show screen for modifying a third party
proc go_third_party_mod args {
	global DB

	set third_party_flag [reqGetArg ThirdPartyFlag]
	
	set select_sql {
		select
			replace(flag_name, "3RDPARTY_", "") as flag_name,
			description
		from
			tAdminUserFlagDesc
		where
			flag_name = ?
	}

	ob_log::write INFO "third_party_flag=$third_party_flag"

	set st [inf_prep_sql $DB $select_sql]
	set rs [inf_exec_stmt $st "$third_party_flag"]
	inf_close_stmt $st

	tpBindString ThirdPartyAbbv [db_get_col $rs 0 flag_name]
	tpBindString ThirdPartyName [db_get_col $rs 0 description]

	asPlayFile -nocache third_party_mod.html
}

# Perform actions for Third Parties, switching on SubmitName in request
proc do_third_party args {
	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_country_list
		return
	}

	if {$act == "ThirdPartyAdd"} {
		do_tp_add
	} elseif {$act == "ThirdPartyMod"} {
		do_tp_mod
	} else {
		error "unexpected SubmitName: $act"
	}

}

# Change the description of a third party flag
proc do_tp_mod args {
	global DB

	set tp_name [reqGetArg ThirdPartyName]
	set tp_abbv [reqGetArg ThirdPartyAbbv]

	if {$tp_name == ""} {
		ob_log::write ERROR "Trying to update Third Party name but value is blank"
		err_bind "Name cannot be blank"
		return [go_third_party_mod]
	}

	set sql {
		update
			tAdminUserFlagDesc
		set
			description = ?
		where
			flag_name =  ?
	}

	if {[_tp_name_exists $tp_name $tp_abbv]} {
		ob_log::write ERROR "Add third party: flag description is not unique"
		err_bind "That third party name has already been used"
		reqSetArg ThirdPartyFlag "3RDPARTY_$tp_abbv"
		return [go_third_party_mod]
	}

	set st [inf_prep_sql $DB $sql]
	inf_exec_stmt $st $tp_name "3RDPARTY_$tp_abbv"
	inf_close_stmt $st

	go_third_party_list
}


# Add a new Third Party
proc do_tp_add args {	
	global DB USERNAME

	set sql {
		insert into
			tAdminUserFlagDesc(
				flag_name,
				description
			)
		values(?, ?)
	}

	set tp_abbv [reqGetArg ThirdPartyAbbv]
	if {$tp_abbv == ""} {
		ob_log::write ERROR "Trying to add third party but abbreviation is blank"
		err_bind "Third Party Abbreviation cannot be blank"
		return [go_third_party_list]
	}

	set tp_abbv "3RDPARTY_[string toupper $tp_abbv]"

	set tp_name [reqGetArg ThirdPartyName]
	if {$tp_name == ""} {
		ob_log::write ERROR "Trying to add third party but name is blank"
		err_bind "Third Party Name cannot be blank"
		return [go_third_party_list]
	}

	if {[_tp_name_exists $tp_name]} {
		ob_log::write ERROR "Add third party: flag description is not unique"
		err_bind "That third party name has already been used"
		return [go_third_party_list]
	}

	set stmt [inf_prep_sql $DB $sql]
	if {[catch {
		inf_exec_stmt $stmt\
			$tp_abbv\
			$tp_name\
		} msg]} {
		if {[regexp "cadmusrflagdesc_pk" $msg]} {
			err_bind "That third party abbreviation has already been used"
		} else {
			err_bind $msg
		}
		ob_log::write ERROR "Trying to add third party. DB Error: $msg"
	}

	inf_close_stmt $stmt

	msg_bind "Third Party '$tp_name' added successfully."

	go_third_party_list
}

# Bind 3RDPARTY flags into a given array
#
#   arr_name - Name of the array to populate with third parties
#
proc bind_third_parties {arr_name {sortby flag_name} } {
	global DB

	upvar $arr_name THIRD_PARTIES

	set sql [subst {
		select
			flag_name,
			description,
			upper($sortby) as sortc
		from
			tAdminUserFlagDesc
		where
			flag_name like "3RDPARTY_%"
		order by
			sortc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set rs   [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set n_flags [db_get_nrows $rs]

	for {set r 0} {$r < $n_flags} {incr r} {
		set THIRD_PARTIES($r,flag_name) [db_get_col $rs $r flag_name]
		set THIRD_PARTIES($r,abbv)      [string map {"3RDPARTY_" ""} [db_get_col $rs $r flag_name]]
		set THIRD_PARTIES($r,desc)      [db_get_col $rs $r description]
	}


	tpBindVar ThirdPartyFlag $arr_name flag_name tp_idx
	tpBindVar ThirdPartyAbbv $arr_name abbv      tp_idx
	tpBindVar ThirdPartyName $arr_name desc      tp_idx

	db_close $rs
	return $n_flags
}

# Check if a third party name has been used
proc _tp_name_exists {tp_name {tp_abbv ""}} {
	global DB

	set check_sql {
		select
			flag_name
		from
			tAdminUserFlagDesc
		where
			description = ?
			and flag_name != ?
	}

	set tp_abbv "3RDPARTY_$tp_abbv"

	# Check description is unique
	set stmt [inf_prep_sql $DB $check_sql]
	set rs   [inf_exec_stmt $stmt $tp_name $tp_abbv]
	set nrows [db_get_nrows $rs]
	db_close $rs
	inf_close_stmt $stmt

	if {$nrows != 0} {
		return 1
	} else {
		return 0
	}
}

}
