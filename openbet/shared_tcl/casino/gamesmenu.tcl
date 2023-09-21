# $Id: gamesmenu.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2006 Orbis Technology Ltd. All rights reserved.
#
# Some useful casino-related procs
#
# Configuration:
#
# Synopsis:
#     package require casino_gamesmenu ?4.5?
#
# Procedures:
#    ob_casino::gamesmenu::init    one time initialisation
#

package provide casino_gamesmenu 4.5


# Dependencies
#
package require util_log 4.5
package require util_db  4.5

package require tdom


# Variables
#
namespace eval ob_casino::gamesmenu {

	variable INIT

	set INIT 0
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::gamesmenu::init args {

	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CASINO GAMESMENU: init}

	_prepare_qrys

	set INIT 1
}

# Get the games array
#
# returns - array of games
#
proc ob_casino::gamesmenu::get {arr {category_type CASINO} {lang ""}} {

	upvar 1 $arr games_arr

	_load_game_data $category_type games $lang

	array set games_arr [array get games]
	
}


proc ob_casino::gamesmenu::get_games_drilldown {arr {category_type CASINO} {lang en}} {
	
	upvar 1 $arr drilldown

	# populate array of available games
	_load_game_data $category_type games $lang

	set num_types [llength $games(types)]

	# set the bindings we want
	for {set i 0} {$i < $num_types} {incr i} {
		set type [lindex $games(types) $i]

		set drilldown($i,type) [ob_xl::XL $lang $games(types,$type,title)]

		set drilldown($i,num_games) [llength $games(types,$type,games)]

		for {set j 0} {$j < $drilldown($i,num_games)} {incr j} {

			set game [lindex $games(types,$type,games) $j]

			set drilldown($i,$j,name) $game
			set drilldown($i,$j,title) [ob_xl::XL $lang $games(games,$game,title)]
			set drilldown($i,$j,id)   $games(games,$game,cgr_id)
		}
	}

	tpSetVar casino_num_types [llength $games(types)]

	tpBindVar casino_type_name   drilldown type      i
	tpBindVar casino_num_games   drilldown num_games i
	tpBindVar casino_game_name   drilldown name      i j
	tpBindVar casino_game_title  drilldown title     i j
	tpBindVar casino_game_id     drilldown id        i j
}

#
# Private procedure to load the game data
#
proc ob_casino::gamesmenu::_load_game_data {category_type arr {lang ""}} {

	upvar 1  $arr games

	ob::log::write DEBUG "CASINO -> in _load_game_data"

	# get the channel
	set channel "%[OT_CfgGet CHANNEL I]%"

	set lang "%${lang}%"

	set CGI_URL [OT_CfgGet CGI_URL]
	set SWF_URL [OT_CfgGet SWF_URL]

	# load the game categories
	if {[catch {
		set rs [ob_db::exec_qry ob_casino::gamesmenu::get_games_categories \
						$category_type \
						$channel]
	} err]} {
		ob::log::write ERROR "Error loading casino game categories: $err"
	} else {
		set num_categories [db_get_nrows $rs]

		set games(types) ""
		set games(games) ""

		# loop through categories
		for {set cat_count 0} {$cat_count < $num_categories} {incr cat_count} {
			set category_id    [db_get_col $rs $cat_count cg_category_id]
			set type           [db_get_col $rs $cat_count title]
			set image          [db_get_col $rs $cat_count image]

			# Get all the games to be displayed for the current category
			if {[catch {set rs2 [ob_db::exec_qry ob_casino::gamesmenu::get_games_menu \
						$category_id \
						$category_type \
						$channel \
						$channel \
						$lang]} err] } {
				ob_log::write ERROR {Error loading casino games menu: $err}
			} else {
				set num_games [db_get_nrows $rs2]

				# Only worry about adding the category type if there are
				# actually some games to display
				if {$num_games > 0} {
					lappend games(types) $type

					# put bars round the title so that it can be translated
					set games(types,$type,title) "|${type}|"
					set games(types,$type,image) $image

					set games(types,$type,games) ""
					set topbar_swf ${SWF_URL}[OT_CfgGet TOPBAR_SWF TopBar.swf]
					set preload_swf ${SWF_URL}[OT_CfgGet PRELOAD_SWF preload.swf]
				}

				# Loop through the games for the current category
				for {set game_count 0} {$game_count < $num_games} {incr game_count} {
					set game [db_get_col $rs2 $game_count name]

					foreach {key default} {
						cgr_id      ""
						cgf_id      ""
						name        $game
						image       $game
						external    N
						location    $game
						lang        ""
						swf         $game.swf
						url         $SWF_URL/$game
						help        $game.html
						movieclips  [list]
						fonts       [list]
						optionmenus [list]
						dialogs     [list]
						xl_font     _sans
						topbar_swf  $topbar_swf
					} {
						set games(games,$game,$key) [db_get_col $rs2 $game_count $key]

						if {$games(games,$game,$key) == ""} {
							set games(games,$game,$key) [subst $default]
						}
					}

					set games(games,$game,title) \
								CASINO_GAME_TITLE_[string toupper $game]
					set games(games,$game,preload_url) $preload_swf
					set name $games(games,$game,name)
					lappend games(types,$type,games) $name
					lappend games(games) $name

					# If overriding the language for this game, add the language
					# as a GET parameter to the topbar and translation URLs.
					if {$games(games,$game,lang) ne ""} {
						set game_lang &lang=$games(games,$game,lang)
					} else {
						set game_lang ""
					}

					foreach {url action} {
						topbar_url  get_topbar_xml
						update_url  update_topbar_xml
						trans_url   get_translations
					} {
						set games(games,$game,$url) $CGI_URL?action=$action&game=$name${game_lang}
					}
				}
				ob_db::rs_close $rs2
			}
		}
		ob_db::rs_close $rs
	}
}

# Private procedure to prepare the package queries
#
proc ob_casino::gamesmenu::_prepare_qrys args {

	ob_db::store_qry ob_casino::gamesmenu::get_games_categories {
		select
			cg_category_id,
			title,
			image
		from
			tCGGamesCategory
		where
			displayed = 'Y'
		and category_type = ?
		and channels like ?
		order by disporder
	} 600

	ob_db::store_qry ob_casino::gamesmenu::get_games_menu {
		select
			cgr.cg_id as cgr_id,
			cgf.cg_id as cgf_id,
			cgr.name,
			gm.image,
			gm.external,
			gm.location,
			gm.lang,
			gm.swf,
			gm.url,
			gm.help,
			gm.movieclips,
			gm.fonts,
			gm.optionmenus,
			gm.dialogs,
			gm.xl_font,
			gm.topbar_swf
		from
			tCGGamesCategory gc,
			tCGGamesMenuLink l,
			tCGGamesMenu gm,
			tCGGame cgr,
			tCGGame cgf
		where
			gc.cg_category_id = ?
		and gc.category_type = ?
		and gc.cg_category_id = l.cg_category_id
		and gm.cgs_id = l.cg_gamesmenu_id
		and gm.cgr_id = cgr.cg_id
		and gm.cgf_id = cgf.cg_id
		and "AA" = cgr.status || cgf.status
		and "YY" = cgr.displayed || cgf.displayed
		and "NY" = cgr.free_play || cgf.free_play
		and cgr.channels like ?
		and cgf.channels like ?
		and (gm.languages is null or gm.languages like ?)
		order by l.disporder, gm.title
	} 600
}
