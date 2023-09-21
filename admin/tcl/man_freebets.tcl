# $Id: man_freebets.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# Manual Freebets.tcl
#
# Allows the customer to upload a file containing the account numbers of customers, and perform manual adjustments to these customer's accounts
#


namespace eval ADMIN::MAN_FREEBETS {


	asSetAct ADMIN::MAN_FREEBETS::go_manual_freebets [namespace code go_manual_freebets]
	asSetAct ADMIN::MAN_FREEBETS::delete_file        [namespace code delete_file]
	asSetAct ADMIN::MAN_FREEBETS::show_options       [namespace code display_man_freebets_options]
	asSetAct ADMIN::MAN_FREEBETS::do_man_freebets    [namespace code do_man_freebets]

	proc go_manual_freebets {} {

		global FILE

		if {![op_allowed DoManualFreeBets]} {
			err_bind "You don't have permission to do manual free bets"
		}

		set UPLOAD_DIR [OT_CfgGet MAN_FB_UPLOAD_DIR]
		set UPLOAD_URL [OT_CfgGet MAN_FB_UPLOAD_URL]

		tpBindString UPLOAD_URL $UPLOAD_URL
		set action [reqGetArg SubmitName]
		if {$action=="uploaded"} {
			tpSetVar UPLOADED 1
		} else {
			tpSetVar UPLOADED 0
		}

		set months [list "" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

		set mrx {([12][09][0-9][0-9])-([01][0-9])-([0-3][0-9])}
		set trx {([012][0-9]):([0-5][0-9]):([0-5][0-9])}

		set drx ${mrx}_${trx}\$


		set n_files 0


		set files [glob -nocomplain $UPLOAD_DIR/*]


		foreach f $files {
			set ftail [file tail $f]
			if [regexp $drx $ftail time y m d hh mm ss] {

				if [regsub _$drx $ftail "" ftrunc] {

					set m [lindex $months [string trimleft $m 0]]

					set FILE($n_files,date)     "$y-$m-$d $hh:$mm:$ss"
					set FILE($n_files,fullname)     [urlencode $ftail]
					set FILE($n_files,trunc)    [html_encode $ftrunc]
					OT_LogWrite 1 "$FILE($n_files,trunc)"
					set FILE($n_files,time)     $time

					incr n_files
				}
			}

		}

		tpBindVar FileTime FILE date     file_idx
		tpBindVar FileName FILE trunc    file_idx
		tpBindVar FileKey  FILE fullname file_idx

		tpSetVar NumFiles $n_files

		OT_LogWrite 20 "Play File man_freebets.html"

		asPlayFile -nocache man_freebets.html
		catch {unset FILE}

	}

	proc delete_file args {


		if {![op_allowed DoManualFreeBets]} {
			err_bind "You don't have permission to do manual free bets"
			asPlayFile -nocache man_freebets.html
			return
		}

		set UPLOAD_DIR [OT_CfgGet MAN_FB_UPLOAD_DIR]

		set name [reqGetArg FileName]

		if {[catch {
			file delete $UPLOAD_DIR/$name
		} msg]} {
			error "failed to delete $UPLOAD_DIR/$name"
		}

		go_manual_freebets
	}

	proc display_man_freebets_options {} {

		if {![op_allowed DoManualFreeBets]} {
			err_bind "You don't have permission to do manual free bets"
			asPlayFile -nocache man_freebets.html
			return
		}


		tpBindString FILENAME [reqGetArg FileName]

		asPlayFile -nocache man_freebets_options.html

	}


	proc do_man_freebets {} {

		global DB USERNAME

		if {![op_allowed DoManualFreeBets]} {
			err_bind "You don't have permission to do manual free bets"
			asPlayFile -nocache man_freebets.html
			return
		}


		set file [OT_CfgGet MAN_FB_UPLOAD_DIR]/[reqGetArg filename]

		set sql1 [subst {
			execute procedure pCustFundsXfer(
			 p_adminuser    = ?,
			 p_type         = '[OT_CfgGet MANUAL_FREEBET_MANADJ_TYPE  FBET]',
			 p_desc         = ?,
			 p_ccy_code     = ?,
			 p_bm_acct_type = 'MAN',
			 p_cust_id      = ?,
			 p_amount       = ?,
			 p_withdrawable = 'N',
			 p_status       = 'R'
			 )
		}]


		set sql2 {
			select
			c.cust_id,
			ccy_code
			from
			tcustomer c,
			tacct a
			where
			c.acct_no = ? and
			c.cust_id = a.cust_id
		}

		set sql3 {
			select exch_rate
			from   tCCY
			where  ccy_code = ?
		}

		set stmt1 [inf_prep_sql $DB $sql1]
		set stmt2 [inf_prep_sql $DB $sql2]
		set stmt3 [inf_prep_sql $DB $sql3]

		set f [open $file r]
		set desc   [reqGetArg Description]
		set amount [reqGetArg Amount]

		OT_LogWrite 3 "Desc: $desc, amount: $amount"

		set successful 0

		while {[gets $f line]>=0} {

			set acct_no [lindex [split $line ,] 0]
			if {![regexp {[0-9]+} $acct_no]} {
				OT_LogWrite 3 "Invalid account number : $acct_no"
				continue
			}

			if [catch {set rs [inf_exec_stmt $stmt2 $acct_no]} msg] {
				OT_LogWrite 3 "Error retrieving cust_details for $acct_no : $msg"
			} else {
				if {[db_get_nrows $rs]!=1} {
					OT_LogWrite 3 "Error retrieving cust_details for acct_no $acct_no: wrong no. of cols"
				} else {
					set cust_id  [db_get_col $rs 0 cust_id]
					set ccy_code [db_get_col $rs 0 ccy_code]
					if [catch {set rs [inf_exec_stmt $stmt3 $ccy_code]} msg ] {
						OT_LogWrite 3 "Error retrieving exchange rate for ccy_code : $ccy_code :: $msg"
					} else {
						set exch_rate [db_get_col $rs 0 exch_rate]
						set converted_amount [format %0.2f [expr $amount * $exch_rate]]
					  }

					if [catch {inf_exec_stmt $stmt1 $USERNAME  $desc $ccy_code $cust_id $converted_amount} msg] {
						OT_LogWrite 3 "Error adding free bet for cust_id: $cust_id, acct_id: $acct_id  - $msg"
					} else {
						OT_LogWrite 15 "Adding Free bet to cust_id: $cust_id"
						incr successful
					}
				}
				db_close $rs
			}
		}

		inf_close_stmt $stmt1
		inf_close_stmt $stmt2
		inf_close_stmt $stmt3

		#puts $f "Processed By $USERNAME on [exec date]"
		close $f

		OT_LogWrite 7 "Number of Bets Given = $successful"

		tpBindString NUM_SUCCESS $successful
		asPlayFile -nocache man_freebets_done.html
	}

}
