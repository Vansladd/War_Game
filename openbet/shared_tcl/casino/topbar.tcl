# $Id: topbar.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# Some useful casino-related procs
#
# Configuration:
#
# Synopsis:
#     package require casino_topbar ?4.5?
#
# Procedures:
#    ob_casino::topbar::init   					one time initialisation
#	 ob_casino::topbar::bind_topbar_xml			bind topbar vars
#	 ob_casino::topbar::bind_time 			 	bind vars
#	 ob_casino::topbar::bind_scrollbar			bind messages scrollbar
#

package provide casino_topbar 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5
package require tdom

# Variables
#
namespace eval ob_casino::topbar {

	variable INIT
	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::topbar::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CASINO TOPBAR: init}

	# get configuration
	array set OPT [list \
		msg_repetition 2 \
		time_mode      server \
		real_play_msg  0 \
	]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet "TOPBAR_[string toupper $c]" $OPT($c)]
	}

	_prepare_qrys

	set INIT 1
}

proc ob_casino::topbar::bind_topbar_xml {type arr msg_arr {lang en}} {

	ob_log::write DEBUG {ob_casino::topbar H_bind_topbar_xml}

	upvar 1 $arr CFG
	upvar 1 $msg_arr messages

	## get messages for scrollbar..
	set errs [ob_casino::topbar::bind_scrollbar messages $lang]

	## get and bind server time
	ob_casino::topbar::bind_time

	if {$type eq "full"} {
		set game [reqGetArg game]
		
		if { $game ne "" } {

			set location $CFG(games,$game,location)
			set url      $CFG(games,$game,url)
			set help     $CFG(games,$game,help)
			set title    [ob_xl::sprintf $lang $CFG(games,$game,title)]

			tpBindString casino_game_name      $game
			tpBindString casino_game_location  $location
			tpBindString casino_game_url       $url
			tpBindString casino_game_help      $help
			tpBindString casino_game_title     $title

			## bind up the dynamic components for the topbar
			tpSetVar casino_game_movieclips  $CFG(games,$game,movieclips)
			tpSetVar casino_game_fonts       $CFG(games,$game,fonts)
			tpSetVar casino_game_optionmenus $CFG(games,$game,optionmenus)
			tpSetVar casino_game_dialogs     $CFG(games,$game,dialogs)

			## Check whether demo/real play dialog should show
			set embedded_demo_real [OT_CfgGet EMBEDDED_DEMO_REAL]
			if {[lsearch $embedded_demo_real $game] >= 0} {
				tpSetVar demo_real hide
			} else {
				tpSetVar demo_real show
			}

			## Check whether to show clock or not
			set no_clock_list [OT_CfgGetTrue HIDE_DATE_TIME]
			if {[lsearch $no_clock_list $game] >= 0} {
				tpSetVar hide_clock yes
			} else {
				tpSetVar hide_clock no
			}

			## Check whether to show bonus bar or not
			set no_bonusbar_list [OT_CfgGetTrue HIDE_BONUSBAR]
			if {[lsearch $no_bonusbar_list $game] >= 0} {
				tpSetVar hide_bonusbar yes
				ob_log::write INFO {BBAR disabled}
			} else {
				# Check that we actually have an active bonus bar
				if {[catch {
						set rs [ob_db::exec_qry ::ob_casino::topbar::check_bbar\
								"%[OT_CfgGet CHANNEL "I"]%"]
				} msg]} {
					ob_log::write ERROR {Failed to exec qry ::ob_casino::topbar::check_bbar $msg}
				} else {
					if {[db_get_nrows $rs]} {
						ob_log::write INFO {BBAR enabled}
					} else {
						tpSetVar hide_bonusbar yes
						ob_log::write INFO {BBAR disabled}
					}
					db_close $rs
				}
			}

		}

		if {[lsearch [list cn cs] $lang] >= 0} {
			tpSetVar casino_game_global_font international
		} else {
			tpSetVar casino_game_global_font standard
		}
	} 
	return $errs
}

proc ob_casino::topbar::bind_time {} {

	variable CFG

	## want to be able to say whether we
	## are to display client or server
	## time.
	set now [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

	## just make sure it's either client or server
	set time_mode [string tolower $CFG(time_mode)]
	if {$time_mode ne "server"} {
		set time_mode "client"
	}
	tpBindString server_time $now
	tpBindString time_mode $time_mode
}

proc ob_casino::topbar::bind_scrollbar {msg_arr lang} {

	variable CFG

	upvar 1 $msg_arr messages

	## need to get any customer messages..
	set cust_id [ob_login::get cust_id]

	## make note of errors to pass back
	set errs ""

	set num_msgs 0

	if { [catch {
	    set rs [ob_db::exec_qry ::ob_casino::topbar::get_messages $cust_id]
	} err] } {
		ob::log::write ERROR "Error exec_qry ::ob_casino::topbar::get_messages $cust_id: $err"
		set errs "$errs CASINO_ACCT_DATABASE_ERROR ERROR"
	} else {
	    set nrows [db_get_nrows $rs]

	    for { set i 0 } { $i < $nrows } { incr i } {
			if { [db_get_col $rs $i ntc_type] eq "B" } {
			    set messages($num_msgs,msg) [ob_xl::sprintf $lang \
										[db_get_col $rs $i xl_code]]
			    set messages($num_msgs,repetition) $CFG(msg_repetition)
			} else {
			    set messages($num_msgs,msg) [db_get_col $rs $i msg]
			    set messages($num_msgs,repetition) $CFG(msg_repetition)

			    ## set empty string as at present theres
			    ## no url associated with customer notices
			    set messages($num_msgs,function) ""
			}

			incr num_msgs
	    }
		db_close $rs
	}

	## need to pull out any news highlights also
	##
	set channel "%[OT_CfgGet CHANNEL "I"]%"
	if {[catch {
		set rs [ob_db::exec_qry ::ob_casino::topbar::get_super_blurb $channel]
	} err] } {
			ob::log::write ERROR "Error exec_qry ::ob_casino::topbar::get_super_blurb $channel: $err"
			set errs "$errs CASINO_ACCT_DATABASE_ERROR ERROR"
	} else {
		set nrows [db_get_nrows $rs]

		for {set i 0} {$i < $nrows} {incr i} {

			set messages($num_msgs,msg) [db_get_col $rs $i msg]

			## want to constantly run super blurbs....
			## Zero for infinite
			set messages($num_msgs,repetition) 0
			set messages($num_msgs,function) [db_get_col $rs $i info_url]

			incr num_msgs
		}
		db_close $rs
	}

	set real_play [reqGetArg real_play]

	## real_play may not exist
	if {![info exists real_play] || $real_play == ""} {
		set real_play 0
	}

	## we need to add the real-play to the messages
	## if we're in demo_play mode
	##
	if {!$real_play && $CFG(real_play_msg)} {

		set messages($num_msgs,msg) [ob_xl::sprintf $lang TOPBAR_PLAY_FOR_REAL]
		set messages($num_msgs,repetition) 0
		set messages($num_msgs,function) "controller.realPlayClicked()"

		incr num_msgs
	}

	## ok, bind up
	tpSetVar num_msgs $num_msgs
	tpBindVar msg        messages msg i
	tpBindVar repetition messages repetition i
	tpBindVar function   messages function i

	return $errs
}


# Private procedure to prepare the package queries
#
proc ob_casino::topbar::_prepare_qrys args {

	ob_db::store_qry ::ob_casino::topbar::get_messages {
		select
			b.body as msg,
			n.xl_code,
			n.ntc_type
		from
			tCustNotice n,
			outer tCustNtcBody b
		where
			n.cust_id = ?
			and n.read = 'N'
			and n.deleted = 'N'
			and n.body_id = b.body_id
			and n.from_date <= current
			and (n.to_date is null or n.to_date > current);
	}
	
	ob_db::store_qry ::ob_casino::topbar::get_super_blurb {
		select
			ns.news as msg,
			ns.info_url
		from
			tNews ns,
			tNewsType nt
		where
			ns.type = nt.code
			and ns.type = "SB"
			and ns.displayed = "Y"
			and nt.status = "A"
			and from_date <= current
			and to_date > current
			and ns.channels like ?
		order by ns.disporder
	}
	
	# Check that the bonus bar is active
	#
	ob_db::store_qry ::ob_casino::topbar::check_bbar {
		select
			1
		from
			tPromotion
		where
			type = 'BBAR'
			and status = 'A'
			and channels like ?
	}
}

#-------------------------------------------------------------------------------
# vim:noet:ts=4:sts=4:sw=4:tw=80:ft=tcl:ff=unix:
#-------------------------------------------------------------------------------
