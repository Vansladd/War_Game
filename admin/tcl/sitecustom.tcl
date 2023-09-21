# ==============================================================
# $Id: sitecustom.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::SITECUSTOM {

asSetAct ADMIN::SITECUSTOM::GoSiteCustom [namespace code go_sitecustom]
asSetAct ADMIN::SITECUSTOM::DoSiteCustom [namespace code do_sitecustom]

#
# ----------------------------------------------------------------------------
# Got to the site customisation settings page
# ----------------------------------------------------------------------------
#
proc go_sitecustom args {

	global SCDATA
	global DB

	if {[info exists SCDATA]} {
		unset SCDATA
	}

	set sql [subst  {
		SELECT
			sd.setting_name,
			sd.description,
			sd.note,
			s.setting_value as curr_value,
			sv.setting_value as poss_value,
			(select count (*)
			 from tSiteCustomVal xsv
			 where xsv.setting_name = sd.setting_name
			) as num_vals
		FROM
			tSiteCustomDesc sd,
			tSiteCustom s,
			outer tSiteCustomVal sv
		WHERE
			sd.setting_name = sv.setting_name and
			sd.setting_name = s.setting_name
		ORDER BY
			sd.setting_name
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt]} msg]} {
		set bad 1
		err_bind $msg
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	# loop through each setting / value pair
	for {set r 0} {$r < $nrows} {incr r} {

		foreach col {
			setting_name
			description
			note
			curr_value
			poss_value
			num_vals
		} {
			set SCDATA($r,$col) [db_get_col $rs $r $col]
		}

	}

	set SCDATA(num) $nrows

	tpBindVar Name    SCDATA setting_name   sc_idx
	tpBindVar Desc    SCDATA description    sc_idx
	tpBindVar Note    SCDATA note		    sc_idx
	tpBindVar PosVal  SCDATA poss_value     sc_idx
	tpBindVar CurVal  SCDATA curr_value     sc_idx
	tpBindVar NumVals SCDATA num_vals       sc_idx

	asPlayFile -nocache sitecustom.html

}


#
# ----------------------------------------------------------------------------
# Update site customisation information
# ----------------------------------------------------------------------------
#
proc do_sitecustom args {

	global DB

	set sql [subst  {
		SELECT
			s.setting_name,
			s.setting_value
		FROM
			tSiteCustom s
	}]

	set bad 0

	set stmt [inf_prep_sql $DB $sql]

	if {[catch {
		set rs [inf_exec_stmt $stmt]} msg]} {
		set bad 1
		err_bind $msg
	}

	inf_close_stmt $stmt

	set nrows [db_get_nrows $rs]

	# loop through each setting name
	for {set r 0} {$r < $nrows} {incr r} {
		set setting_name [db_get_col $rs $r setting_name]
		set new_setting_value [reqGetArg $setting_name]

		# no change - no update
		if { $new_setting_value == [db_get_col $rs $r setting_value]} {
			continue
		}


		set sql [subst {
			update tSiteCustom
				set setting_value = ?
			where setting_name = ?
		}]

		set bad 0

		set stmt [inf_prep_sql $DB $sql]

		if {[catch {
			set res [inf_exec_stmt 	$stmt\
								 	$new_setting_value\
									$setting_name] } msg]} {
			set bad 1
			err_bind $msg
		}

		inf_close_stmt $stmt

		if {$bad} {
			#
			# Something went wrong
			#
			for {set a 0} {$a < [reqGetNumVals]} {incr a} {
				tpBindString [reqGetNthName $a] [reqGetNthVal $a]
			}
			tpSetVar UpdateFailed 1
			go_sitecustom
			return
		}

	}

	go_sitecustom

}



}
