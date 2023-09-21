#
# $Id: racing_focus.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Racing Focus is used to switch the Sportsbook horse racing homepage from
# being focussed on Live events (during the day) to Virtual races (during the
# evening), so that once all the live races are done the customer can push
# their Virtual Racing page.  This is language specific, as events finish in
# different locales at different times.  The config item for this is
# FUNC_RACING_FOCUS in global_func.cfg
#

namespace eval ADMIN::RACING_FOCUS {

asSetAct ADMIN::RACING_FOCUS::GoRacingFocus [namespace code go_racing_focus]
asSetAct ADMIN::RACING_FOCUS::DoRacingFocus [namespace code do_racing_focus]



#
# Bind and play the Racing Focus page
#
proc go_racing_focus {} {

	global DB
	global RACING_FOCUS

	catch {[unset RACING_FOCUS]}

	ob_log::write INFO {ADMIN::RACING_FOCUS::go_racing_focus: Navigating\
													to Racing Focus page}

	if {[catch {
		set sql {
			select
				lang,
				hr_setting
			from
				tHRLangSetting
		}

		set stmt [inf_prep_sql $DB $sql]
		set res  [inf_exec_stmt $stmt]

		set bad 0

	} msg]} {
		ob_log::write ERROR {ADMIN::RACING_FOCUS::go_racing_focus: Failed to\
										retrieve HR language settings: $msg}
		err_bind $msg
		set bad 1
	}

	inf_close_stmt $stmt
	set nlang 0

	if {!$bad} {
		set nlang [db_get_nrows $res]
		# Bind up the lang and hr_settings
		for {set i 0} {$i < $nlang} {incr i} {
			set hr_setting [db_get_col $res $i hr_setting]

			# Select which of the radio buttons will be checked
			switch -- $hr_setting {
				"V" {
					set RACING_FOCUS($i,live_check)    ""
					set RACING_FOCUS($i,virtual_check) "checked"
				}
				"L" {
					set RACING_FOCUS($i,live_check)    "checked"
					set RACING_FOCUS($i,virtual_check) ""
				}
				default {
					set RACING_FOCUS($i,live_check)    ""
					set RACING_FOCUS($i,virtual_check) ""
				}
			}

			set RACING_FOCUS($i,lang)       [db_get_col $res $i lang]
		}
	}

	tpBindVar Lang         RACING_FOCUS  lang          rf_idx
	tpBindVar LiveCheck    RACING_FOCUS  live_check    rf_idx
	tpBindVar VirtualCheck RACING_FOCUS  virtual_check rf_idx

	tpSetVar nlang $nlang

	asPlayFile -nocache racing_focus.html

}



#
# Proc for redirecting from form submit
#
proc do_racing_focus {} {

	global DB

	set action [reqGetArg SubmitName]

	if {$action == "Add"} {
		add_racing_focus
	} elseif {$action == "Upd"} {
		upd_racing_focus
	} else {
		err_bind "Unknown submit action: $action"
		go_racing_focus
	}
}



#
# Add a new row into tHRLangSetting
#
proc add_racing_focus {} {

	global DB

	set lang       [reqGetArg NewLang]
	set hr_setting [string range [reqGetArg NewHRSetting] 0 0]

	if {[catch {

		# Check if we've already got the language so we can send a useful
		# error message
		set sql {
			select
				l.lang,
				hr.lang
			from
				tLang l,
				outer tHRLangSetting hr
			where
				l.lang = hr.lang and
				l.lang = ?
		}

		set stmt      [inf_prep_sql $DB $sql]
		set res_check [inf_exec_stmt $stmt $lang]
		inf_close_stmt $stmt

		if {[db_get_nrows $res_check] > 0} {

			set hrlang_lang [db_get_coln $res_check 0 1]

			if {$hrlang_lang == ""} {

				# Don't need to do any more validation on lang as this has been
				# done in the javascript
				set sql {
					insert into tHRLangSetting (
						lang,
						hr_setting
					)
					values (
						?,
						?
					)
				}

				set stmt [inf_prep_sql $DB $sql]
				inf_exec_stmt $stmt $lang $hr_setting
				inf_close_stmt $stmt

				ob_log::write INFO {ADMIN::RACING_FOCUS::add_racing_focus:\
											Successfully added language $lang\
											with racing focus $hr_setting}

				msg_bind "Successfully added racing focus for $lang"

			} else {
				ob_log::write INFO {ADMIN::RACING_FOCUS::add_racing_focus:\
												Language $lang already exists}
				err_bind "Racing focus for $lang already exists"
			}
		} else {
			ob_log::write INFO {ADMIN::RACING_FOCUS::add_racing_focus: Language\
														$lang does not exist}
			err_bind "Language $lang does not exist"
		}

		db_close $res_check

	} msg]} {
		ob_log::write ERROR {ADMIN::RACING_FOCUS::add_racing_focus: Failed to\
													add new racing focus: $msg}
		err_bind "Failed to add new language: $msg"
	}

	go_racing_focus
}



#
# Update all the racing focus settings
#
proc upd_racing_focus {} {

	global DB

	set sql {
		update tHRLangSetting
		set
			hr_setting = ?
		where
			lang = ?
	}

	set stmt [inf_prep_sql $DB $sql]
	set bad 0

	for {set n 0} {$n < [reqGetNumVals]} {incr n} {

		# If the argument is one of the radio buttons groups, we want to store it
		if {[regexp "HRSetting_(.*)" [reqGetNthName $n] full lang]} {

			set hr_setting [string range [reqGetNthVal $n] 0 0]
			if {[catch {
				ob_log::write INFO {ADMIN::RACING_FOCUS::upd_racing_focus:\
												setting $lang to $hr_setting}
				inf_exec_stmt $stmt $hr_setting $lang

			} msg]} {
				ob_log::write ERROR {ADMIN::RACING_FOCUS::upd_racing_focus:\
								Failed to update $lang to $hr_setting: $msg}
				err_bind "Failed to set $lang to $hr_setting: $msg"
				set bad 1
			}
		}
	}

	if {!$bad} {
		msg_bind "Updated successfully"
	}

	inf_close_stmt $stmt

	go_racing_focus
}

}