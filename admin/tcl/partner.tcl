# ==============================================================
# $Id: partner.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#
# ----------------------------------------------------------------------------
# Procedures called from here do their own transaction management
# ----------------------------------------------------------------------------
#
namespace eval ADMIN::PARTNER {

asSetAct ADMIN::PARTNER::GoPartnerList [namespace code go_partner_list]
asSetAct ADMIN::PARTNER::GoPartner     [namespace code go_partner]
asSetAct ADMIN::PARTNER::DoPartner     [namespace code do_partner]

#
# ----------------------------------------------------------------------------
# Go to partner list
# ----------------------------------------------------------------------------
#
proc go_partner_list args {

	global DB

	set sql [subst {
		select
			ptnr_code,
			desc,
			channels,
			disporder
		from
			tPartner
		order by
			disporder asc, ptnr_code asc
	}]

	set stmt [inf_prep_sql $DB $sql]
	set res  [inf_exec_stmt $stmt]
	inf_close_stmt $stmt

	tpSetVar NumPartner [db_get_nrows $res]

	tpBindTcl PartnerCode               sb_res_data $res partner_idx ptnr_code
	tpBindTcl PartnerDescription        sb_res_data $res partner_idx desc
	tpBindTcl PartnerChannels           sb_res_data $res partner_idx channels
	tpBindTcl PartnerDisporder          sb_res_data $res partner_idx disporder

	asPlayFile -nocache partner_list.html

	db_close $res
}


#
# ----------------------------------------------------------------------------
# Go to single partner add/update
# ----------------------------------------------------------------------------
#
proc go_partner args {

	global DB

	set ptnr_code [reqGetArg PartnerCode]

	foreach {n v} $args {
		set $n $v
	}

	tpBindString PartnerCode $ptnr_code

	if {$ptnr_code == ""} {

		tpSetVar opAdd 1
		make_channel_binds  "" - 1
		tpBindString PartnerDisporder 0

	} else {

		tpSetVar opAdd 0

		#
		# Get partner information
		#
		set sql [subst {
			select
				ptnr_code,
				desc,
				channels,
				disporder
			from
				tPartner
			where
				ptnr_code = ?
		}]

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt $ptnr_code]
		inf_close_stmt $stmt

		tpBindString PartnerCode             [db_get_col $res 0 ptnr_code]
		tpBindString PartnerDescription      [db_get_col $res 0 desc]
		tpBindString PartnerDisporder        [db_get_col $res 0 disporder]

		make_channel_binds [db_get_col $res 0 channels] -

		db_close $res
	}

	asPlayFile -nocache partner.html
}


#
# ----------------------------------------------------------------------------
# Do partner insert/update/delete
# ----------------------------------------------------------------------------
#
proc do_partner args {

	set act [reqGetArg SubmitName]

	if {$act == "Back"} {
		go_partner_list
		return
	}

	if {$act == "PartnerAdd"} {
		do_partner_add
	} elseif {$act == "PartnerMod"} {
		do_partner_upd
	} elseif {$act == "PartnerDel"} {
		do_partner_del
	} else {
		error "unexpected SubmitName: $act"
	}
}

proc do_partner_add args {

	global DB USERNAME

	set sql [subst {
		execute procedure pInsPartner(
			p_adminuser = ?,
			p_ptnr_code = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg PartnerCode]\
			[reqGetArg PartnerDescription]\
			[make_channel_str]\
			[reqGetArg PartnerDisporder]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
	}
	go_partner
}

proc do_partner_upd args {

	global DB USERNAME

	set sql [subst {
		execute procedure pUpdPartner(
			p_adminuser = ?,
			p_ptnr_code = ?,
			p_desc = ?,
			p_channels = ?,
			p_disporder = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg PartnerCode]\
			[reqGetArg PartnerDescription]\
			[make_channel_str]\
			[reqGetArg PartnerDisporder]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_partner
		return
	}
	go_partner_list
}

proc do_partner_del args {

	global DB USERNAME

	set sql [subst {
		execute procedure pDelPartner(
			p_adminuser = ?,
			p_ptnr_code = ?
		)
	}]

	set stmt [inf_prep_sql $DB $sql]

	set bad 0

	if {[catch {
		set res [inf_exec_stmt $stmt\
			$USERNAME\
			[reqGetArg PartnerCode]]} msg]} {
		err_bind $msg
		set bad 1
	}

	catch {db_close $res}
	inf_close_stmt $stmt

	if {$bad} {
		for {set a 0} {$a < [reqGetNumVals]} {incr a} {
			tpBindString [reqGetNthName $a] [reqGetNthVal $a]
		}
		go_partner
		return
	}

	go_partner_list
}

}
