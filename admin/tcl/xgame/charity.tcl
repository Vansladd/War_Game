# ==============================================================
# $Id: charity.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================


#
# This file contains the procedures used to
# maintaine the tXGameCharity table.
#
namespace eval ADMIN::XGAME::CHARITY {


variable FIELDS {charity_id aff_id sort name}
variable LABELS {Id Affiliate "Game type" Name}
if {[OT_CfgGet OPENBET_CUST ""] != "BlueSQ"} {
	append FIELDS email_msg
	append LABELS "Email Message"
}

proc go_list_charities {} {

	set sql [subst {
		select
			c.charity_id as charity_id,
			c.name as charity_name,
			c.sort,
			a.aff_name as aff_name,
			c.cr_date
		from
			tXGameCharity c,
			outer tAffiliate a
		where
			c.aff_id = a.aff_id
		order by c.name asc
	}]

	if [catch {set rs [xg_exec_qry $sql]} msg] {
		return [handle_err "unable to get charities" "error: $msg"]
	}
	
	tpSetVar num_charities [db_get_nrows $rs]

	tpBindTcl charity_id     sb_res_data $rs charity_idx charity_id
	tpBindTcl charity_name   sb_res_data $rs charity_idx charity_name
	tpBindTcl sort           sb_res_data $rs charity_idx sort
	tpBindTcl aff_name       sb_res_data $rs charity_idx aff_name
	tpBindTcl cr_date        sb_res_data $rs charity_idx cr_date

	asPlayFile -nocache "xgame/charity_list.html"

	db_close $rs
}

proc go_display_charity {{charity_id ""} {mode MOD}} {
	global CHARITY_AFFS

	if {($mode == "MOD") && ($charity_id == "")} {
		set charity_id [reqGetArg charity_id]
	}
	tpSetVar charity_id $charity_id

	if {$charity_id != ""} {
		populate_charity charity $charity_id

		tpBindString charity_id         $charity(charity_id)
		tpBindString charity_name       $charity(name)
		tpBindString sort               $charity(sort)
		tpBindString charity_cr_date    $charity(cr_date)
		if {[OT_CfgGet OPENBET_CUST ""] != "BlueSQ"} {
			tpBindString charity_email_msg  $charity(email_msg)	
		}
		tpSetVar charity_aff_id  $charity(aff_id)	
		tpSetVar sort            $charity(sort)
	}

	catch {unset CHARITY_AFFS}
	populate_affiliates CHARITY_AFFS
	tpBindVar chr_aff_id CHARITY_AFFS id aff_idx
	tpBindVar chr_aff_name CHARITY_AFFS name aff_idx

	asPlayFile -nocache "xgame/charity.html"
}


proc go_add_charity {}  {
	variable FIELDS
	variable LABELS

	set err_msg ""

	set bad_fields {}
	foreach f $FIELDS l $LABELS {
		set $f [reqGetArg $f]
		OT_LogWrite 10 "$f=[set $f]"

		if {[set $f] == "" && $f != "aff_id" && $f != "sort"} {
			lappend bad_fields $l
		}
	}
	if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
		set email_msg "-"
	} 
	if {[llength $bad_fields] > 0} {
		set err_msg "No values given for: [join $bad_fields ,]"
	} else {
		set sql [subst {
			insert into tXGameCharity (
				charity_id, aff_id, sort, name, email_msg
			) values (?, ?,?, ?, ?)
		}]

		if [catch {set rs [xg_exec_qry $sql \
				$charity_id \
				$aff_id \
				$sort \
				$name \
				$email_msg \
		]} msg] {
			set err_msg $msg
		}
	}

	if {$err_msg != ""} {
		err_bind $err_msg

		# rebind the template variables
		tpBindString new_charity_id     $charity_id
		tpBindString charity_name       $name
		if {[OT_CfgGet OPENBET_CUST ""] != "BlueSQ"} {
			tpBindString charity_email_msg  $email_msg
		}
		tpSetVar charity_aff_id $aff_id
		tpSetVar sort $sort

		set charity_id ""
	} else {
		if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
			send_charity_notification_emails $sort
		}
	 }
	
	go_display_charity $charity_id ADD 

}

proc send_charity_notification_emails {sort} {

	# Find all customers with outstanding Prizebuster subs for 
	# game type sort
	# They must be sent an email telling them that the proceeds 
	# from their outstanding subs will go to the new charity

	global EMAIL_TYPES xgaQry

	if {$sort == "PBUST3"} {
		set cust_mail_type "XCH3"
	} else {
		set cust_mail_type "XCH4"
	  }

	set sub_id_list [list]
	
	if [catch {set users [xg_exec_qry $xgaQry(get_users_with_outstanding_pbust_subs) $sort]} msg] {
		return [handle_err "get_users_with_outstanding_pbust_subs" "error: $msg"]
	}

	set num_users [db_get_nrows $users]

	for {set u 0} {$u < $num_users} {incr u} {
		if [catch {set sub_ids [xg_exec_qry $xgaQry(get_outstanding_pbust_subs_for_user) [db_get_col $users $u acct_id] $sort]} msg] {
			return [handle_err "get_users_with_outstanding_pbust_subs" "error: $msg"]
		}
		set num_subs [db_get_nrows $sub_ids]
		for {set s 0} {$s < $num_subs} {incr s} {
			lappend sub_id_list [db_get_col $sub_ids $s xgame_sub_id]			
		}
		set ref_id [join $sub_id_list "|"]
		
                if [catch {set rs [xg_exec_qry $xgaQry(get_cust_id_for_user) [db_get_col $users $u acct_id]]} msg] {
                        return [handle_err "get_cust_id_for_user"\
                                        "error: $msg"]
                }
                set cust_id [db_get_col $rs 0 cust_id]

		ins_cust_mail $cust_mail_type $cust_id $ref_id
	}	
}

proc go_modify_charity {} {
	variable FIELDS
	variable LABELS

	set bad_fields {}
	foreach f $FIELDS l $LABELS {
		set $f [reqGetArg $f]
		if {[set $f] == "" && $f != "aff_id" && $f != "sort"} {
			lappend bad_fields $l
		}
	}
	if {[OT_CfgGet OPENBET_CUST ""] == "BlueSQ"} {
		set email_msg "-"
	} 

	if {[llength $bad_fields] > 0} {
		err_bind "No values given for: [join $bad_fields ',']"

	} else {
		set sql [subst {
			update
				tXGameCharity 
			set
				aff_id = ?,
				name = ?,
				email_msg = ?
			where
				charity_id = ?
		}]

		if [catch {set rs [xg_exec_qry $sql \
				$aff_id \
				$name \
				$email_msg \
				$charity_id \
		]} msg] {
			err_bind $msg
		}
	}

	go_display_charity $charity_id 
}

proc go_delete_charity {} {

	set charity_id [reqGetArg charity_id]
	if {$charity_id == ""} {
		err_bind "No charity given"
	} else {
		set sql "delete from tXGameCharity where charity_id = ?"
		if [catch {set rs [xg_exec_qry $sql $charity_id]} msg] {
			err_bind $msg
		}
	}

	go_list_charities
}

proc populate_affiliates {affs_ref} {
	upvar $affs_ref affs_res

	set affs_res(num_rows) 0

	set sql [subst {
		select
			aff_id,
			aff_name
		from 
			tAffiliate
		order by aff_name
	}]

	if [catch {set rs [xg_exec_qry $sql]} msg] {
		error "failed to get affiliates: $msg"
	}

	set num_rows [db_get_nrows $rs]
	if {$num_rows < 0} {
		error "failed to get affiliates: num_rows=$num_rows"
	}

	set affs_res(num_rows) $num_rows 
	for {set r 0} {$r < $num_rows} {incr r} {
		set affs_res($r,id)   [db_get_col $rs $r aff_id]
		set affs_res($r,name) [db_get_col $rs $r aff_name]
	}
		
	# Add in 'none'
	incr affs_res(num_rows)
	set affs_res($r,id) ""
	set affs_res($r,name) "--No affiliate--"

	db_close $rs
}

proc populate_charity {charity_ref charity_id} {
	upvar $charity_ref charity

	set sql [subst {
		select
			cr_date,
			charity_id,
			name,
			sort,
			email_msg,
			aff_id
		from
			tXGameCharity
		where
			charity_id = ? 
	}]
	
	if [catch {set rs [xg_exec_qry $sql $charity_id]} msg] {
		error "failed to get charity: $msg"
	}

	set num_rows [db_get_nrows $rs]
	if {$num_rows != 1} {
		error "No charity with id = $charity_id"
		OT_LogWrite 2 "XGAME CHARITY ERROR: no charity with id=$charity_id, num_rows=$num_rows"
	}

	set charity(cr_date)     [db_get_col $rs 0 cr_date]
	# now using fixed length field in database, so trim excess spaces from message:
	set charity(email_msg)   [string trimright [db_get_col $rs 0 email_msg] " "]
	set charity(charity_id)  [db_get_col $rs 0 charity_id]
	set charity(sort)        [db_get_col $rs 0 sort]
	set charity(name)        [db_get_col $rs 0 name]
	set charity(aff_id)      [db_get_col $rs 0 aff_id]

	db_close $rs
}


}
