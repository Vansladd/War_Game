#==============================================================
# $Id: autosettler.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# Everything Autosettler related is now handled by the Autosettler Appserv
# The Admin Screens simply send Autosettler a message to see if it is active
# - If so, we play pages served by Autosettler, otherwise we do nothing!
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#==============================================================

namespace eval ::ADMIN::AUTO_SETTLE {
#####################################


	# AutoSettler
	#--------------
	asSetAct ADMIN::AUTO_SETTLE::DoAutoSettlerAction ::ADMIN::AUTO_SETTLE::do_autosettle_action
	asSetAct ADMIN::AUTO_SETTLE::GoAutoSettler       ::ADMIN::AUTO_SETTLE::go_autosettle
	asSetAct ADMIN::AUTO_SETTLE::GoAutoSettlerBlocks ::ADMIN::AUTO_SETTLE::go_autosettle_blocks
	asSetAct ADMIN::AUTO_SETTLE::GoAutoSettlerDelays ::ADMIN::AUTO_SETTLE::go_autosettle_delays

	asSetAct ADMIN::AUTO_SETTLE::AutoSettlerStyle    ::ADMIN::AUTO_SETTLE::play_css

}



########################################
proc ::ADMIN::AUTO_SETTLE::play_css {} {
########################################
	asPlayFile -cache "autosettler/autosettler.css"
}

#
#
#
proc ::ADMIN::AUTO_SETTLE::do_autosettle_action {} {

	set action [reqGetArg task]

	if {[op_allowed ActivateAutoSettler]} {
		switch -exact $action {
			activate {
				set status [perform_action turn_on]
			}
			suspend {
				set status [perform_action turn_off]
			}
			reset {
				set status [perform_action reset]
			}
		}
	}

	go_autosettle
}



#############################################
proc ::ADMIN::AUTO_SETTLE::go_autosettle {} {
#############################################
#
# Play the main autosettler page - show current markets awaiting settlement
#

	if {![op_allowed ViewAutoSettler]} {
		return
	}

	set autosettler_state [perform_action get_status]

	tpBindString AS_STATUS $autosettler_state
	tpBindString AUTOSETTLER_URL [OT_CfgGet AUTOSETTLER_URL "/autosettler"]

	switch -exact $autosettler_state {
		OFF {
			asPlayFile -nocache "autosettler/main_off.html"
		}
		ACTIVE -
		SUSPENDED {
			asPlayFile -nocache "autosettler/main_on.html"
		}
		UNKNOWN -
		default  {
			asPlayFile -nocache "autosettler/main_off.html"
		}
	}
}



####################################################
proc ::ADMIN::AUTO_SETTLE::go_autosettle_blocks {} {
####################################################
#
# Play the autosettler blocks
#

	if {![op_allowed ViewAutoSettler]} {
		return
	}

	set autosettler_state [perform_action get_status]

	tpBindString AS_STATUS $autosettler_state
	tpBindString AUTOSETTLER_URL [OT_CfgGet AUTOSETTLER_URL "/autosettler"]

	switch -exact $autosettler_state {
		OFF {
			asPlayFile -nocache "autosettler/blocks_off.html"
		}
		ACTIVE -
		SUSPENDED {
			asPlayFile -nocache "autosettler/blocks_on.html"
		}
		UNKNOWN -
		default  {
			asPlayFile -nocache "autosettler/blocks_off.html"
		}
	}
}



####################################################
proc ::ADMIN::AUTO_SETTLE::go_autosettle_delays {} {
####################################################
#
# Play the autosettler delays
#

	if {![op_allowed ViewAutoSettler]} {
		return
	}

	set autosettler_state [perform_action get_status]

	tpBindString AS_STATUS $autosettler_state

	switch $autosettler_state {
		OFF {
			asPlayFile -nocache "autosettler/delays_off.html"
		}
		ACTIVE -
		SUSPENDED {
			asPlayFile -nocache "autosettler/delays_on.html"
		}
		UNKNOWN -
		default  {
			asPlayFile -nocache "autosettler/delays_off.html"
		}
	}

}



######################################################
proc ::ADMIN::AUTO_SETTLE::perform_action {action_name} {
######################################################
#
# Perform autosettler application requests
#

	switch $action_name {
		get_status {
			set state [OB_auto_settle::get_status]
			ob_log::write INFO {==> ADMIN::AUTO_SETTLE - Autosettler state is $state}
			return $state
		}
		turn_on {
			set state [OB_auto_settle::turn_on]
			ob_log::write INFO {==> ADMIN::AUTO_SETTLE - Autosettler state is $state}
			return $state

		}
		turn_off {
			set state [OB_auto_settle::turn_off]
			ob_log::write INFO {==> ADMIN::AUTO_SETTLE - Autosettler state is $state}
			return $state

		}
		reset {
			set state [OB_auto_settle::reset]
			ob_log::write INFO {==> ADMIN::AUTO_SETTLE - Autosettler state is $state}
			return $state
			
		}
		default {
			ob_log::write INFO {==> ADMIN::AUTO_SETTLE - Something strange..? Who ya gonna call? GHOSTBUSTERS}
			return 0
		}
	}

	# failsafe
	return 0
}
