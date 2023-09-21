#-------------------------------------------------------------------------------
# Copyright © 2006-2008 Orbis Technology Ltd.
#-------------------------------------------------------------------------------
# $Id: game_xml.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
#-------------------------------------------------------------------------------
#
# Some useful IGF-related procs
#
# Configuration:
#
# Synopsis:
#     package require casino_game_xml ?4.5?
#
# Procedures:
#    ob_casino::game_xml::init               one time initialisation
#    ob_casino::game_xml::bind_launcher      bind launch page.
#    ob_casino::game_xml::bind_preloader_xml bind preloader XML
#    ob_casino::game_xml::bind_topbar_xml    bind topbar XML
#    ob_casino::game_xml::bind_update_xml    bind update XML
#
#-------------------------------------------------------------------------------

package provide casino_game_xml 4.5

#-------------------------------------------------------------------------------
# Dependencies
#
package require Tcl      8.4

package require http     2.5
package require tdom     0.8.0

package require util_log  4.5
package require util_db   4.5
package require util_util 4.5

# Variables
#
namespace eval ob_casino::game_xml {

	set INIT 0
	set ISO_LANG_MAP [list en eng cn chi]
	set TOPBAR_QUALITY_LABELS [list LOW MEDIUM HIGH BEST]

}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::game_xml::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	ob_log::write DEBUG {ob_casino::game_xml::init}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CASINO TOPBAR: init}

	#
	# Get configuration
	#
	variable CFG

	foreach key { promotions_enabled
				  freebets_enabled
				  update_on_close } {
		set CFG($key) [expr {
			[OT_CfgGetTrue [string toupper $key]] ? "true" : "false"
		}]
	}

	foreach key [list fog_url] {
		set CFG($key) [OT_CfgGet [string toupper $key]]
	}

	foreach {
		key                default
	} {
		topbar_swf         /TopBar.swf
		mini_topbar_swf    /TopBar/miniBarF8.swf
		preloader_swf      /Preloader.swf
		mini_preloader_swf /Preloader/preloaderMiniF8.swf
	} {
		set CFG($key) [OT_CfgGet [string toupper $key] $default]
	}

	foreach {
		key                   default
	} {
		channel               I
		mini_channel          M
		topbar                ""
		site_name             "OpenBet Casino"
		flash_version         8
		number_of_auto_spins  1
		thirdparty_chaingames ""
	} {
		set CFG($key) [OT_CfgGet [string toupper $key] $default]
	}

	foreach {
			key                default
	} [list embedded_demo_real [list] \
			hide_mode_dialogue [list] \
			hide_date_time     [list] \
			hide_bonusbar      [list] \
			msg_repetition     2 \
			real_play_msg      0 \
			session_close_func "javascript:void (0);" \
			session_continue_func "javascript:void (0);" \
			session_ack_tm_out -1 \
			update_xml_rate    30000 \
			time_mode          server \
			time_source        app \
			games_menu         1 \
			games_menu_dd      CASINO \
			games_menu_ddvip   "" \
			default_fr         30 \
			show_turbo_option	1 \
			turbo_override	   [list] \
			show_about_box		1 \
			refresh_game_windows 0\
	] {
		set CFG($key) [OT_CfgGet TOPBAR_[string toupper $key] $default]
	}

	set CFG(real_play_msg) [OT_CfgGetTrue TOPBAR_REAL_PLAY_MSG]
	set CFG(bonus_bar)     [OT_CfgGetTrue BONUS_BAR]


	if { [lsearch { server client } $CFG(time_mode)] == -1 } {
		ob_log::write WARNING {Unrecognized time-mode $CFG(time_mode):\
							   using "server".}
		set CFG(time_mode) server
	}

	variable TOPBARS

	set TOPBARS(topbars) [OT_CfgGet TOPBARS [list]]

	foreach tb $TOPBARS(topbars) {

		set TOPBARS($tb,swf)           [OT_CfgGet TOPBARS.$tb.SWF           ""]
		set TOPBARS($tb,preloader)     [OT_CfgGet TOPBARS.$tb.PRELOADER     ""]
		set TOPBARS($tb,xml)           [OT_CfgGet TOPBARS.$tb.XML           ""]
		set TOPBARS($tb,update_xml)    [OT_CfgGet TOPBARS.$tb.UPDATE_XML    ""]
		set TOPBARS($tb,assets_xml)    [OT_CfgGet TOPBARS.$tb.ASSETS_XML    ""]
		set TOPBARS($tb,fragment_xml)  [OT_CfgGet TOPBARS.$tb.FRAGMENT_XML ""]
		set TOPBARS($tb,game_x_offset) [OT_CfgGet TOPBARS.$tb.GAME_X_OFFSET ""]
		set TOPBARS($tb,game_y_offset) [OT_CfgGet TOPBARS.$tb.GAME_Y_OFFSET ""]

	}

	#
	# Prep the SQL
	#
	_init_sql

	#
	# Pull down the XML game properties.
	#
	_init_xml_properties

	set INIT 1

}

#
# Private procedure to prepare the package queries
#
proc ob_casino::game_xml::_init_sql {} {

	ob_db::store_qry ::ob_casino::game_xml::get_messages {

		select
			b.body as msg,
			n.xl_code,
			n.ntc_type
		from
			tCustNotice n,
			outer tCustNtcBody b
		where n.cust_id = ?
		  and n.read    = 'N'
		  and n.deleted = 'N'
		  and n.body_id = b.body_id
		  and current   between n.from_date and nvl (n.to_date, current)

	}

	ob_db::store_qry ::ob_casino::game_xml::get_news {

		select
			n.news_id,
			n.news,
			n.info_url
		from
			tNewsType t,
			tNews     n
		where t.code      = n.type
		  and t.status    = 'A'
		  and t.code      =  ?
		  and n.displayed = 'Y'
		  and current     between n.from_date and n.to_date
		  and n.channels  like ?
		order by n.disporder

	}

	# Check that the bonus bar is active for this game
	#
	ob_db::store_qry ::ob_casino::game_xml::check_bbar {

		select
			1
		from
			tPromotion p,
			tPromoGameGrp pg,
			tGPGameGrpLk ggl,
			tGPGame gg,
			tCGGame g
		where p.type = 'BBAR'
		  and p.status = 'A'
		  and p.channels like ?
		  and pg.promotion_id = p.promotion_id
		  and ggl.gp_game_grp_id = pg.gp_game_grp_id
		  and gg.gp_game_id = ggl.gp_game_id
		  and g.cg_id = gg.cg_id
		  and g.name = ?

	}

	ob_db::store_qry ::ob_casino::game_xml::get_properties {

		select
			n.prop_name  as name,
			v.prop_value as value
		from
			tCGGamePropName  n,
		outer (
			tCGGamePropValue v,
			tCGGame          g
		)
		where n.prop_id = v.prop_id
		  and v.cg_id   = g.cg_id
		  and g.name    = ?

	} 600

	ob_db::store_qry ::ob_casino::game_xml::get_translations {

		select
			c.group,
			c.code,
			v.xlation_1,
			v.xlation_2,
			v.xlation_3,
			v.xlation_4
		from
			tXlateCode c,
			tXlateVal  v
		where (
				c.code    like ?
			and c.group   = ?
			 or c.group   in ('Portal.Splash',
							  'Portal.GamePreloader')
		  )
		  and c.code_id = v.code_id
		  and v.lang    = ?;

	}

	ob_db::store_qry ::ob_casino::game_xml::get_preloader_xl {

		select
			c.group,
			c.code,
			v.xlation_1,
			v.xlation_2,
			v.xlation_3,
			v.xlation_4
		from
			tXlateCode c,
			tXlateVal  v
		  and c.code_id = v.code_id
		  and v.lang    = ?;

	}

	ob_db::store_qry ::ob_casino::game_xml::db_time {
		select
			CURRENT year to second as now
		from
			tControl
	}

}

proc ::ob_casino::game_xml::_init_xml_properties {} {

	variable  CFG
	variable  XML_PROPERTIES
	array set XML_PROPERTIES [list games [list]]

	if { ![OT_CfgExists GAME_PROPS_URL] } {
		ob_log::write WARNING {GAME_PROPS_URL not defined.}
		return
	}

	set url [OT_CfgGet GAME_PROPS_URL]

	if { [catch {
		set token [http::geturl $url]
	} err] } {
		ob_log::write ERROR {could not retrieve $url: $err.}
		return
	}

	switch [http::status $token] {

		eof {
			ob_log::write ERROR {could not retrieve $url: got EOF.}
		}
		error {
			ob_log::write ERROR \
				{could not retrieve $url: got [http::error $token].}
		}
		default {

			if { [http::ncode $token] != 200 } {
				ob_log::write ERROR \
					{could not retrieve $url: got [http::code $token].}
			} else {
				upvar #0 $token state
				set xml $state(body)
			}

		}

	}

	http::cleanup $token

	if { ![info exists xml] } return

	set ok 1
	set doc [dom parse $xml]

	if { [catch {
		set root [$doc firstChild]
	} err] } {
		ob_log::write ERROR {XML has not root.}
	} elseif { [$root nodeName] ne "games" } {
		ob_log::write ERROR {Unexpected node: [$root nodeName].}
	} else {

		foreach game_node [$root childNodes] {

			if { [$game_node nodeName] ne "game" } {
				ob_log::write ERROR {Unexpected node: [$game_node nodeName].}
				continue
			}

			if { ![$game_node hasAttribute name] } {
				ob_log::write ERROR {Game has no name.}
				continue
			}

			set name [$game_node getAttribute name]

			lappend XML_PROPERTIES(games) $name

			foreach n [$game_node attributes] {
				set XML_PROPERTIES($name,$n) [$game_node getAttribute $n]
			}

			set XML_PROPERTIES($name,chain_games) [list]

			foreach chain_node [$game_node childNodes] {

				if { [$chain_node nodeName] ne "chain_game" } {
					ob_log::write ERROR \
						{Unexpected node: [$chain_node nodeName].}
					continue
				}

				set chain_name [$chain_node getAttribute name]

				lappend XML_PROPERTIES($name,chain_games) $chain_name

				foreach n [$chain_node attributes] {
					set XML_PROPERTIES($name,chain_games,$chain_name,$n) \
						[$chain_node getAttribute $n]
				}

				set XML_PROPERTIES($chain_name,parent) $name

			}

		}

	}

	for {set i 0} {$i < [llength $CFG(thirdparty_chaingames)]} {incr i} {
		set sel [lindex $CFG(thirdparty_chaingames) $i]
		set XML_PROPERTIES([lindex $sel 0],parent) [lindex $sel 1]
	}

	$doc delete

}


# Bind up launch variables
#
# game     - game to launch
# lang     - are we passing through a specific language
# skip     - is skip enabled
# mode     - which mode for skip
# menu_arr - allows a pre-existing menu array to be passed in
#            to avoid having to query the database
#
proc ob_casino::game_xml::bind_launcher {
	  game
	  lang
	  skip
	  mode
	  menu_arr
	  url_protocol
	  url_host
	{ mini_game "" }
} {

	ob_log::write INFO {ob_casino::game_xml::bind_launcher\
						 $game $lang $skip $mode $mini_game}

	# check if existing menu array has been passed in
	if {$menu_arr ne "_NONE_"} {
		upvar 1 $menu_arr menu
	} else {
		ob_casino::game_menu::load_menu menu
	}
	
	if {[lsearch $menu(all_games) $game] == -1 || [lsearch $menu(games,$game,languages) $lang] == -1 } {
		set lang "en"
		set title [ob_xl::sprintf $lang $game]
	} else {
		set title [ob_xl::sprintf $lang $menu(games,$game,title)]
	}

	array set properties [get_properties $game $lang $mini_game]

	if { ![info exists properties] } {
		return 0
	}

	set url                 [_subst_url $properties(url) \
										$url_protocol \
										$url_host]
	set preloader_xml_url   [_subst_url $properties(preloader_xml_url) \
										$url_protocol \
										$url_host]

	set preloader_swf       $properties(preloader_swf)
	set mini_preloader_swf  $properties(mini_preloader_swf)
	#
	# These can be used to skip the game straight to free- or real-play.
	#
	if { $skip ne "" } {
		append preloader_xml_url [urlencode &skip=$skip]
	}
	if { $mode ne "" } {
		append preloader_xml_url [urlencode &mode=$mode]
	}

	tpBindString casino_flash_version       $properties(flash_version)
	tpBindString casino_game_name           $game
	tpBindString casino_game_title          $title
	tpBindString casino_game_help           $properties(help)
	tpBindString casino_game_lang           $lang
	tpBindString casino_game_url            $url
	if {[lsearch $menu(all_games) $game] != -1} {	
		tpBindString casino_game_real_id        $menu(games,$game,cgr_id)
		tpBindString casino_game_demo_id        $menu(games,$game,cgf_id)
		tpBindString casino_game_menu_id        $menu(games,$game,cgs_id)
	}
	tpBindString casino_preloader_swf       $preloader_swf
	tpBindString casino_mini_preloader_swf  $mini_preloader_swf
	tpBindString casino_preloader_xml_url   $preloader_xml_url

	return 1

}

proc ob_casino::game_xml::bind_preloader_xml {
	  game
	  lang
	  skip
	  mode
	  url_protocol
	  url_host
	{ mini_game "" }
} {

	ob_log::write DEBUG {info level 0}

	set fn [lindex [info level 0] 0]

	variable CFG
	variable TOPBARS

	array set properties [get_properties $game $lang $mini_game]

	if { ![info exists properties] } {
		ob_log::write ERROR {${fn}: failed to find $game properties}
		return
	}

	if { $CFG(topbar) ne "" && $TOPBARS($CFG(topbar),preloader) ne "" } {
		set preloader_xml_url $TOPBARS($CFG(topbar),preloader)
	} else {
		set preloader_xml_url $properties(preloader_xml_url)
	}

	if { [lsearch $TOPBARS(topbars) $CFG(topbar)] != -1 } {

		tpBindString topbar_x_offset       $TOPBARS($CFG(topbar),game_x_offset)
		tpBindString topbar_y_offset       $TOPBARS($CFG(topbar),game_y_offset)
		tpBindString topbar_assets_xml_url $TOPBARS($CFG(topbar),assets_xml)
		tpBindString fragment_xml          $TOPBARS($CFG(topbar),fragment_xml)

	}

	if { $mini_game ne "" } {
		tpBindString channel $CFG(mini_channel)
	} else {
		tpBindString channel $CFG(channel)
	}

	tpBindString update_xml_rate $CFG(update_xml_rate)

	tpBindString skip      $skip
	tpBindString mode      $mode
	
	# Quick fix changes for minigames session timeout
	set login_status [ob_login::get login_status]
		
	if { $mini_game ne "" && $login_status eq "OB_ERR_CUST_SESS_START"} {
		tpBindString logged_in "true"
	} else {	
		tpBindString logged_in [expr {
			![ob_login::is_guest] ? "true" : "false"
		}]
	}

	tpBindString supplier            $properties(supplier)
	if { $mini_game ne "" } {
		tpBindString topbar_swf_url  [_subst_url $properties(mini_topbar_swf) \
												 $url_protocol \
												 $url_host]
	} else {
		tpBindString topbar_swf_url  [_subst_url $properties(topbar_swf) \
												 $url_protocol \
												 $url_host]
	}
	tpBindString fog_url             [_subst_url $properties(fog_url) \
												 $url_protocol \
												 $url_host]
	tpBindString topbar_xml_url      [_subst_url $properties(topbar_xml_url) \
												 $url_protocol \
												 $url_host]
	tpBindString update_xml_url      [_subst_url $properties(update_xml_url) \
												 $url_protocol \
												 $url_host]
	tpBindString preloader_xl_url    [_subst_url $properties(preloader_xl_url) \
												 $url_protocol \
												 $url_host]
	tpBindString territory           [expr {
		$properties(territory) eq "Y" ? "true" : "false"
	}]

	tpBindString show_win_boxes       $properties(show_win_boxes)
	tpBindString use_plus_minus_stake $properties(use_plus_minus_stake)
	tpBindString number_of_auto_spins $properties(number_of_auto_spins)

	variable games
	array unset games

	set games(num_games) 1

	set games(0,is_master)   true
	set games(0,name)        $game
	set games(0,assets_xml)  $properties(assets_xml)
	set games(0,url)         [_subst_url $properties(url) \
										 $url_protocol \
										 $url_host]
	set games(0,config_url)  [_subst_url $properties(config_url) \
										 $url_protocol \
										 $url_host]
	set games(0,game_xl_url) [_subst_url $properties(game_xl_url) \
										 $url_protocol \
										 $url_host]

	# Look for this game in the xml properties file
	variable XML_PROPERTIES

	if { [lsearch $XML_PROPERTIES(games) $game] != -1 } {

		# If this game exists in the xml properties, then
		# override certain db settings and check for chain games
		_set_xml_props "games" $game 0 $game

		tpBindString game_class $XML_PROPERTIES($game,class)
		tpBindString server_game_name $XML_PROPERTIES($game,server_game_name)

		set num_slave_games [llength $XML_PROPERTIES($game,chain_games)]

		for { set i 0
				set j 1
				set n $num_slave_games } { $i < $n } { incr i } {

			set slave_game [lindex $XML_PROPERTIES($game,chain_games) $i]

			array unset properties

			array set properties [get_properties $slave_game $lang]

			if {[info exists properties]} {

				set games($j,is_master)   false
				set games($j,name)        $slave_game
				set games($j,assets_xml)  $properties(assets_xml)
				set games($j,url)         [_subst_url $properties(url) \
													  $url_protocol \
													  $url_host]
				set games($j,config_url)  [_subst_url $properties(config_url) \
													  $url_protocol \
													  $url_host]
				set games($j,game_xl_url) [_subst_url $properties(game_xl_url) \
													  $url_protocol \
													  $url_host]

				_set_xml_props \
					games $game,chain_games,$slave_game $j $slave_game

				incr j

			} else {
				incr num_slave_games -1
			}

		}

		incr games(num_games) $num_slave_games
	}

	set ns [namespace current]

	tpSetVar num_games $games(num_games)

	tpBindVar game_name       ${ns}::games name          g
	tpBindVar game_is_master  ${ns}::games is_master     g
	tpBindVar game_xl_url     ${ns}::games game_xl_url   g
	tpBindVar game_url        ${ns}::games url           g
	tpBindVar game_config_url ${ns}::games config_url    g
	tpBindVar game_assets_xml ${ns}::games assets_xml    g
	tpBindVar game_x_offset   ${ns}::games game_x_offset g
	tpBindVar game_y_offset   ${ns}::games game_y_offset g

	if { $CFG(topbar) ne ""
			&& [lsearch $TOPBARS(topbars) $CFG(topbar)] != -1 } {
		return $TOPBARS($CFG(topbar),xml)
	} else {
		return ""
	}

}


proc ob_casino::game_xml::_subst_url { url protocol host } {

	return [regsub -all %{HTTP_PROTO} \
		   [regsub -all %{HTTP_HOST}  $url $host] \
										   $protocol]

}

# Set specific xml properties if they exist in the game properties file
#
proc ob_casino::game_xml::_set_xml_props { arr key idx game } {

	variable CFG
	variable XML_PROPERTIES

	upvar 1 $arr games

	set xml_props {
		game_x_offset ""
		game_y_offset ""
		game_class    ""
		server_game_name ""
	}

	foreach {p dflt} $xml_props {
		set games($idx,$p) $dflt
		if { [info exists XML_PROPERTIES($key,$p)] } {
			set games($idx,$p) $XML_PROPERTIES($key,$p)
		}
	}

	# Set up urls
	if { $XML_PROPERTIES($key,has_assets_xml) eq "Yes" } {
		set games($idx,assets_xml) "/$game/${game}-Assets.xml"
	}

	if { $XML_PROPERTIES($key,has_config_xml) eq "Yes" && \
		 $XML_PROPERTIES($key,uses_casino_config_xml) eq "Yes" } {
		set games($idx,config_url) "/SharedLibraries/casinoSLconfig.xml"

	} elseif { $XML_PROPERTIES($key,has_config_xml) eq "Yes" } {
		set games($idx,config_url) "/$game/${game}-Config.xml"
	}
}


#
# Set the current top-bar.  If no argument is passed, reset to the default.
#
proc ob_casino::game_xml::set_topbar { { topbar {} } } {

	ob_log::write DEBUG {ob_casino::game_xml::set_topbar $topbar}

	variable CFG

	set CFG(topbar) $topbar

}

#
# Retrieve the current top-bar.
#
proc ob_casino::game_xml::get_topbar {} {

	ob_log::write DEBUG {ob_casino::game_xml::get_topbar}

	variable CFG

	return $CFG(topbar)

}

proc ob_casino::game_xml::bind_topbar_xml { game lang } {

	ob_log::write DEBUG {ob_casino::game_xml::bind_topbar_xml $game $lang}

	variable CFG

	array set properties [get_properties $game $lang]
	
	if {$lang == "en" || $lang == "ie"} {
		tpSetVar topbar_lang_en 1
	} else {
		tpSetVar topbar_lang_en 0
	}

	#
	# Bind up the dynamic components for the topbar
	#
	tpBindString topbar_movie_clips  [split $properties(movie_clips)  ,]
	tpBindString topbar_fonts        [split $properties(fonts)        ,]
	tpBindString topbar_option_menus [split $properties(option_menus) ,]
	tpBindString topbar_dialogues    [split $properties(dialogues)    ,]

	#
	# Check whether to hide mode dialogue:
	#
	tpSetVar topbar_hide_mode_dialogue [expr {
		[lsearch $CFG(hide_mode_dialogue) $game] != -1
	}]

	#
	# Check whether to show clock or not
	#
	tpSetVar topbar_hide_clock [expr {
		[lsearch $CFG(hide_date_time) $game] != -1
	}]

	#
	# Check whether to show the about box or not
	#
 	tpSetVar topbar_show_about_box $CFG(show_about_box)


	#
	#Check whether to show turbo option or not
	#

	set hide_turbo $CFG(show_turbo_option)

	foreach {gameName setting} $CFG(turbo_override) {

		if {$gameName eq $game} {
			set hide_turbo $setting
		}

	}

	tpSetVar topbar_hide_turbo $hide_turbo


	#
	# Check whether to show bonus bar or not
	#
	set hide_bonusbar [expr {
		!$CFG(bonus_bar) || [lsearch $CFG(hide_bonusbar) $game] != -1
	}]

	#
	# Check that we actually have an active bonus bar
	#
	if { !$hide_bonusbar } {

		if { [catch {
			set rs [ob_db::exec_qry ::ob_casino::game_xml::check_bbar \
									%$CFG(channel)% \
									$game ]
		} msg] } {

			ob_log::write ERROR {Failed to exec qry\
				ob_casino::game_props::check_bbar $msg}

			set hide_bonusbar 1

		} else {

			if { ![db_get_nrows $rs] } {
				set hide_bonusbar 1
			}

			ob_db::rs_close $rs

		}

		if { $hide_bonusbar } {
			ob_log::write INFO {bonus-bar disabled}
		}

	}

	tpSetVar topbar_hide_bonusbar $hide_bonusbar

	#
	# Bind the drill-down
	#
	if {$CFG(games_menu_ddvip) ne ""
		&& ![ob_login::is_guest]
		&& [ob_cgroup::get [ob_login::get cust_id] CASINO] eq "VIP"} {

		ob_casino::game_menu::bind_menu $CFG(games_menu_ddvip) $lang $game {} Y
	} else {
		ob_casino::game_menu::bind_menu $CFG(games_menu_dd) $lang $game
	}

	#
	# Bind the welcome message.
	#
	if { [ob_login::is_guest] } {
		set code TOPBAR_DEFAULT_MESSAGE
		set arg $CFG(site_name)
	} else {
		set code TOPBAR_DEFAULT_MESSAGE_LOGGEDIN
		set arg [ob_login::get first_name [ob_login::get username " "]]
	}

	tpBindString topbar_scr_init_message [ob_xl::sprintf $lang $code $arg]

	#
	# Bind the quality labels.
	#
	variable TOPBAR_QUALITY_LABELS

	foreach label $TOPBAR_QUALITY_LABELS {
		lappend xl_labels \
			"$label:[ob_xl::XL $lang |TOPBAR_QUALITY_${label}_SHORT|]"
	}
	tpBindString topbar_quality_labels [join $xl_labels ,]

	#
	# Decide which global font to use
	#
	tpSetVar topbar_use_std_global_font [expr {
		[lsearch [list cn cs] $lang] == -1
	}]

}

proc ob_casino::game_xml::bind_update_xml { extend_session real_play lang } {

	ob_log::write DEBUG {ob_casino::game_xml::bind_update_xml\
						 $extend_session $real_play $lang}

	variable CFG
	variable TOPBARS

	_bind_time
	_bind_session $extend_session $real_play

	_bind_scr_messages $lang $real_play
	_bind_sys_messages $lang

	if { $CFG(topbar) ne ""
			&& [lsearch $TOPBARS(topbars) $CFG(topbar)] != -1 } {
		return $TOPBARS($CFG(topbar),update_xml)
	} else {
		return ""
	}

}


#
# Bind the server-time.
#
proc ob_casino::game_xml::_bind_time {} {

	variable CFG

	set fn {ob_casino::game_xml::_bind_time:}

	# Get server time from db or app server
	if {$CFG(time_source) eq "db"} {
		if {[catch {
			set rs  [ob_db::exec_qry ::ob_casino::game_xml::db_time]
			set now [clock scan [db_get_col $rs 0 now]]
		} msg]} {
			catch {ob_db::rs_close $rs}
			ob_log::write ERROR \
				{$fn failed to get db time ($msg), using clock time}
			set now [clock seconds]
		}
	} else {
		set now [clock seconds]
	}

	#
	# Want to be able to say whether we are to display client or server time.
	#
	tpBindString time_mode $CFG(time_mode)
	tpBindString server_time [clock format $now -format "%Y-%m-%d %H:%M:%S %Z"]

}

#
# Bind the session info.
#
proc ob_casino::game_xml::_bind_session { extend_session real_play } {

	variable CFG

	set fn {ob_casino::game_xml::_bind_session:}

	set session_id [ob_session::get session_id]
	set now [clock scan [tpBindGet server_time]]

	if { $session_id ne "" } {

		switch -- $extend_session {

			yes {

				ob_log::write INFO {$fn acknowledging session $session_id}

				if { [catch {
					set status [ob_session::ack $session_id]
				} err] } {
					ob_log::write ERROR \
						{$fn failed to acknowledge session: $err}
				} elseif { $status ne "OB_OK"} {
					ob_log::write ERROR \
						{$fn failed to acknowledge session: $status}
				} else {
						# clear the session so we can reload
						ob_session::clear
						set ob_session::SESSION(session_id) $session_id
						if { $CFG(refresh_game_windows) == 1} {
							tpSetVar session_continue_selected 1
							tpBindString session_continue_func $CFG(session_continue_func)
						}
				}

			}

			no {

				if { [clock scan [ob_session::get session_ack_due]] > $now } {
					ob_log::write INFO \
						{$fn session already acknowledged $session_id}
				} else {

					ob_log::write INFO \
						{$fn terminating session $session_id}
					if { [catch {
						set status [ob_session::end $session_id P]
					} err] } {
						ob_log::write ERROR \
							{$fn failed to end session: $err}
					} elseif { $status ne "OB_OK"} {
						ob_log::write ERROR \
							{$fn failed to end session: $status}
					}

					ob_session::clear

					set session_id ""
				}

			}

		}

	}

	#
	# Session logic only applies if logged in.
	#
	set login_status [ob_login::get login_status]
	ob_log::write INFO {$fn login_status=$login_status}

	if { $login_status ne "OB_OK"
	  && $login_status ne "OB_ERR_SESSION_CHK"
	  && $login_status ne "OB_ERR_CUST_SESS_START" } {
		return
	}

	#
	# If we don't have a session, then we force a close
	# on the assumption it has just been ended, and a new one
	# has not been allowed to start
	#
	# We do this indiscriminately for real play and free play.
	#
	if { $session_id eq "" } {
		tpSetVar session_force_close 1
		tpBindString session_close_func $CFG(session_close_func)
	#
	# Otherwise show session play info if relevant
	#
	} else {

		set first_bet [ob_session::get first_bet]
		if { $first_bet ne "" } {
			tpBindString session_duration [expr {
				$now - [clock scan $first_bet]
			}]
		} else {
			tpBindString session_duration 0
		}

		set ack_due [ob_session::get session_ack_due]
		if { $ack_due ne "" && [clock scan $ack_due] < $now } {

			tpSetVar session_ack_due 1

			set ccy_code          [ob_login::get ccy_code "GBP"]
			set session_stakes    [ob_session::get stakes]
			set session_winnings  [ob_session::get winnings]
			set session_turn_over [expr { $session_winnings - $session_stakes }]
			set session_ccy_turn_over  [ob_util::get_flash_ccy_amount $session_turn_over $ccy_code]

			tpBindString session_stakes    $session_stakes
			tpBindString session_winnings  $session_winnings
			tpBindString session_turn_over $session_turn_over
			tpBindString session_time_out  $CFG(session_ack_tm_out)
			tpBindString session_ccy_turn_over $session_ccy_turn_over

		}

	}

}

#
# Bind the messages for the scroller
#
proc ob_casino::game_xml::_bind_scr_messages { lang real_play } {

	variable CFG

	variable scr_messages

	array unset scr_messages

	#
	# Message index
	#
	set m 0

	#
	# Need to get customer notices ...
	#
	set cust_id [ob_login::get cust_id]

	if { [catch {
		set rs [ob_db::exec_qry ::ob_casino::game_xml::get_messages $cust_id]
	} err] } {
		ob_log::write ERROR \
			{Error exec_qry ::ob_casino::game_xml::get_messages $cust_id: $err}
	} else {

		for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {

			if { [db_get_col $rs $i ntc_type] eq "B" } {
				set scr_messages($m,msg) \
					[ob_xl::sprintf $lang [db_get_col $rs $i xl_code]]
			} else {
				set scr_messages($m,msg) [db_get_col $rs $i msg]
			}
			#
			# No URL's associated with customer messages.
			#
			set scr_messages($m,function) ""
			set scr_messages($m,repetition) $CFG(msg_repetition)

			incr m

		}

		ob_db::rs_close $rs

	}

	#
	# ... and need to pull out any news highlights ...
	#
	if {[catch {
		set rs [ob_db::exec_qry ::ob_casino::game_xml::get_news SB \
															  %$CFG(channel)%]
	} err] } {
		ob_log::write ERROR {Error exec_qry\
			::ob_casino::game_xml::get_news SB, $CFG(channel): $err}
	} else {

		for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {

			set scr_messages($m,msg)      [db_get_col $rs $i news]
			set scr_messages($m,function) [db_get_col $rs $i info_url]
			#
			# High-lights should be run indefinitely:
			#
			set scr_messages($m,repetition) 0

			incr m

		}

		ob_db::rs_close $rs

	}

	#
	# ... and add the "play for real" if required.
	#
	if { ($real_play eq "" || !$real_play) && $CFG(real_play_msg) } {

		set scr_messages($m,msg) [ob_xl::sprintf $lang TOPBAR_PLAY_FOR_REAL]
		set scr_messages($m,function) "controller.realPlayClicked()"
		set scr_messages($m,repetition) 0

		incr m

	}

	#
	# Now bind them up.
	#
	tpSetVar num_scr_messages $m

	set ns [namespace current]

	tpBindVar msg        ${ns}::scr_messages msg        i
	tpBindVar repetition ${ns}::scr_messages repetition i
	tpBindVar function   ${ns}::scr_messages function   i

}

#
# Bind the system messages.
#
proc ob_casino::game_xml::_bind_sys_messages lang {

	variable CFG
	variable sys_messages

	array unset sys_messages

	if {[catch {
		set rs [ob_db::exec_qry ::ob_casino::game_xml::get_news SM \
															  %$CFG(channel)%]
	} err] } {
		ob_log::write ERROR {Error exec_qry\
			::ob_casino::game_xml::get_news SM, $CFG(channel): $err}
	} else {

		for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {
			set sys_messages($i,type)     SM
			set sys_messages($i,title)    [ob_xl::sprintf \
												$lang TOPBAR_MESSAGE_TYPE_SM]
			set sys_messages($i,id)       [db_get_col $rs $i news_id]
			set sys_messages($i,msg)      [db_get_col $rs $i news]
			set sys_messages($i,function) [db_get_col $rs $i info_url]
		}

		ob_db::rs_close $rs

		tpSetVar num_sys_messages $n

		set ns [namespace current]

		tpBindVar msg_id       ${ns}::sys_messages id       i
		tpBindVar msg_text     ${ns}::sys_messages msg      i
		tpBindVar msg_type     ${ns}::sys_messages type     i
		tpBindVar msg_title    ${ns}::sys_messages title    i
		tpBindVar msg_function ${ns}::sys_messages function i

	}

}

proc ::ob_casino::game_xml::bind_translations { game lang } {

	variable trans

	array unset trans

	if { [catch {
		set rs [ob_db::exec_qry ::ob_casino::game_xml::get_translations \
								$game% \
								Games.$game \
								$lang]
	} err] } {
		ob::casino::err::add CASINO_ACCT_DATABASE_ERROR ERROR
		ob_log::write ERROR {could not exec query: $err}
		return 0
	}

	for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {

		set group [db_get_col $rs $i group]
		set code  [db_get_col $rs $i code]

		if { $group eq "Games.$game" } {
			set code [join [lrange [split $code .] 1 e] .]
		}

		set    xl [db_get_col $rs $i xlation_1]
		append xl [db_get_col $rs $i xlation_2]
		append xl [db_get_col $rs $i xlation_3]
		append xl [db_get_col $rs $i xlation_4]

		# Appserv strips out trailing white space so this allows the use of {ws} within
		# a translation to indicate whitespace. This regsub will replace all instances
		# of {ws} with a single space
		regsub -all {\{ws\}} $xl { } xl

		set trans($i,code) $code
		set trans($i,xl)   $xl

	}

	variable ISO_LANG_MAP

	tpBindString isolang [string map $ISO_LANG_MAP $lang]

	set ns [namespace current]

	tpSetVar num_trans $n

	tpBindVar code ${ns}::trans code i
	tpBindVar xl   ${ns}::trans xl   i

	#
	# Now just need to bind up the translation font:
	#
	array set properties [get_properties $game $lang]

	if { [info exists properties] } {
		tpBindString font $properties(xl_font)
	}

	return 1

}

proc ob_casino::game_xml::get_properties { game lang {mini_game ""} } {

	ob_log::write DEBUG {ob_casino::game_xml::get_properties $game $lang $mini_game}

	variable CFG

	variable XML_PROPERTIES

	if {[catch {
		set rs [ob_db::exec_qry ::ob_casino::game_xml::get_properties $game]
	} err] } {
		ob_log::write ERROR {Error loading casino games menu: $err}
		return
	}

	set num_props [db_get_nrows $rs]

	if { $mini_game ne "" } { set game $mini_game }

	array set defaults {
		location               $game
		swf                    $game.swf
		url                    /$game/
		help                   $game.html
		xl_font                _sans
		fog_url                $CFG(fog_url)
		topbar_swf             $CFG(topbar_swf)
		mini_topbar_swf        $CFG(mini_topbar_swf)
		preloader_swf          $CFG(preloader_swf)
		mini_preloader_swf     $CFG(mini_preloader_swf)
		supplier               Orbis
		show_win_boxes         true
		number_of_auto_spins   $CFG(number_of_auto_spins)
		use_plus_minus_stake   true
	}

	if {![catch {
		set preloader_fr $XML_PROPERTIES($game,preloader_frame_rate)
	} msg]} {
		if {$preloader_fr ne $CFG(default_fr)} {
			set defaults(preloader_swf) \
				[OT_CfgGet PRELOADER_SWF_${preloader_fr} \
						   $CFG(preloader_swf)]
		}
	}

	for { set p 0 } { $p < $num_props } { incr p } {

		set n [db_get_col $rs $p name]
		set v [db_get_col $rs $p value]

		if { $v ne "" || ![info exists defaults($n)] } {
			set properties($n) $v
		} else {
			set properties($n) [subst $defaults($n)]
		}

	}


	# Use the language passed in
	# !!! TO DO need to check what games can be played in this language !!!
	set properties(lang) $lang

	ob_db::rs_close $rs

	set properties(flash_version) $CFG(flash_version)

	set properties(preloader_xml_url) [urlencode \
		?action=get_preloader_xml&game=$game&lang=$properties(lang)&mini_game=$mini_game]

	foreach {
		url              action
	} {
		game_xl_url      get_translation_xml
		preloader_xl_url get_translation_xml
		update_xml_url   get_update_xml
	} {
		set    properties($url) "?action=$action&game=$game"
		append properties($url) "&lang=$properties(lang)"
	}

	if { $mini_game ne "" } {
		set properties(topbar_xml_url) "?action=get_mini_topbar_xml"
	} else {
		set properties(topbar_xml_url) "?action=get_topbar_xml"
	}
	append properties(topbar_xml_url) "&game=$game&lang=$properties(lang)"

	return [array get properties]

}

# Accessor
#
proc ob_casino::game_xml::get {arg} {

	variable XML_PROPERTIES

	if {[info exists XML_PROPERTIES($arg)]} {
		return $XML_PROPERTIES($arg)
	} else {
		ob_log::write WARNING {ob_casino::game_xml::get: $arg not found}
		return ""
	}
}

#-------------------------------------------------------------------------------
# vim:noet:ts=4:sts=4:sw=4:tw=80:ft=tcl:ff=unix:
#-------------------------------------------------------------------------------
