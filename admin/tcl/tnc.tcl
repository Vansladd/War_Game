# $Id: tnc.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C)2008 Orbis Technology Ltd. All rights reserved.
#
# Control of Terms and Conditions.
#
# Configuration:
#   FUNC_MENU_TNC = 0
#
# Permission:
#   TermsAndConditions


namespace eval ADMIN::TERMS_AND_CONDITIONS {
	asSetAct ADMIN::TERMS_AND_CONDITIONS::go_tnc_controls  [namespace code go_tnc_controls]
	asSetAct ADMIN::TERMS_AND_CONDITIONS::go_tnc           [namespace code go_tnc]
	asSetAct ADMIN::TERMS_AND_CONDITIONS::do_tnc           [namespace code do_tnc]
}


# Show a list of all the statments controls.
#
proc ADMIN::TERMS_AND_CONDITIONS::go_tnc_controls {} {
	
	global TERMS_AND_CONDITIONS
	
	array unset TERMS_AND_CONDITIONS

	if {![op_allowed TermsAndConditions]} {
		error "You do not have permission to do this"
	}
	
	set sql {
		select
			*
		from
			tTnC
		order by
			tnc_id
	}

	set stmt [inf_prep_sql $::DB $sql]
	set rs [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]
	set colnames [db_get_colnames $rs]

	for {set r 0} {$r < $nrows} {incr r} {
		foreach n $colnames {
			set TERMS_AND_CONDITIONS($r,$n) [db_get_col $rs $r $n]
		}
	}

	db_close $rs

	tpSetVar nrows $nrows

	foreach n $colnames {
		tpBindVar $n TERMS_AND_CONDITIONS $n idx
	}

	asPlayFile -nocache tnc_controls.html
}


# Show one of the statments controls.
#
proc ADMIN::TERMS_AND_CONDITIONS::go_tnc {} {

	if {![op_allowed TermsAndConditions]} {
		error "You do not have permission to do this"
	}
	
	set tnc_name [reqGetArg tnc_name]
	
	if {$tnc_name != ""} {
		set sql {select * from tTnC where tnc_name = ?}
		set stmt [inf_prep_sql $::DB $sql]
		set rs [inf_exec_stmt $stmt $tnc_name]
		inf_close_stmt $stmt
	
		set colnames [db_get_colnames $rs]
	
		foreach n $colnames {
			tpBindString $n [db_get_col $rs 0 $n]
		}
	
		db_close $rs	
	}
	
	asPlayFile -nocache tnc.html
}


# Update or insert a statment control.
#
proc ADMIN::TERMS_AND_CONDITIONS::do_tnc {} {
	
	if {![op_allowed TermsAndConditions]} {
		error "You do not have permission to do this"
	}


	set tnc_id         [reqGetArg tnc_id]
	set tnc_name       [reqGetArg tnc_name]
	set channels       [reqGetArg channels]
	set xsys_host_grp  [reqGetArg xsys_host_grp]
	set version        [reqGetArg version]
	set url            [reqGetArg url]
	set submit         [reqGetArg submit]

	# Check that the url is kinda valid
	if {[string first "http://" $url] == -1} {
		err_bind "url is invalid"
		reqSetArg tnc_name ""
		go_tnc
		return
	}

	# Make sure that the url does not have a space in it
	if {[string first " " $url] != -1} {
		err_bind "urls must not contain spaces"
		reqSetArg tnc_name ""
		go_tnc
		return
	}

	# Check that the version number is of the format n.n.n.n
	if {[string is integer [string map {. ""} $version]] == 0} {
		err_bind "version number is invalid"
		reqSetArg tnc_name ""
		go_tnc
		return
	}

	switch $submit {
		"Insert" {
			OT_LogWrite INFO "Inserting Terms and Conditions"

			set sql {insert into tTnC(cr_date, tnc_name, channels, xsys_host_grp, 
				version, url, updated) values (CURRENT,?,?,?,?,?,CURRENT)}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $tnc_name $channels $xsys_host_grp $version $url
			inf_close_stmt $stmt
			msg_bind "Terms and Conditions Inserted"
		}
		"Update" {
			OT_LogWrite INFO "Updating Terms and Conditions"

			# Check to see that the version number is not less than what was there previously
			set sql1 {select version from tTnC where tnc_id = ?}

			set stmt1 [inf_prep_sql $::DB $sql1]
			set res [inf_exec_stmt $stmt1 $tnc_id]
			set nrows [db_get_nrows $res]
			set old_version [db_get_col $res 0 version]

			set o_v [string map {. ""} $old_version]
			set v [string map {. ""} $version]

			if {$o_v > $v} {
				err_bind "version number must not be decreased"
				go_tnc
				return
			}

			# Clean Up
			db_close $res
			inf_close_stmt $stmt1

			set sql {update tTnC set tnc_name = ?, channels = ?, xsys_host_grp = ?, 
				version = ?, url = ?, updated = CURRENT where tnc_id = ?}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $tnc_name $channels $xsys_host_grp $version $url $tnc_id
			inf_close_stmt $stmt
			msg_bind "Terms and Conditions Updated"
	
		}
		"Delete" {
			OT_LogWrite INFO "Deleting Terms and Conditions"
			set sql {delete from tTnC where tnc_id = ?}
			set stmt [inf_prep_sql $::DB $sql]
			inf_exec_stmt $stmt $tnc_id
			inf_close_stmt $stmt
			msg_bind "Terms and Conditions Deleted"
		}
		default {
			error "Unknown submit"
		}
	}
	
	go_tnc_controls
}
