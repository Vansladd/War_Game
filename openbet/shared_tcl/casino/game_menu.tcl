#-------------------------------------------------------------------------------
# Copyright © 2006-2008 Orbis Technology Ltd.
#-------------------------------------------------------------------------------
# $Id: game_menu.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
#-------------------------------------------------------------------------------
#
# Some useful casino-related procs
#
# Configuration:
#
# Synopsis:
#     package require casino_game_menu ?4.5?
#
# Procedures:
#    ob_casino::game_menu::init    one time initialisation
#
#-------------------------------------------------------------------------------

package provide casino_game_menu 4.5

#-------------------------------------------------------------------------------
# Dependencies
#
package require Tcl      8.4

package require util_log 4.5
package require util_db  4.5

# Variables
#
namespace eval ob_casino::game_menu {

	set INIT 0

}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_casino::game_menu::init args {

	variable INIT
	variable CFG

	# already initialised
	if {$INIT} {
		return
	}

	ob_log::write DEBUG {ob_casino::game_menu::init}

	# initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {CASINO GAMESMENU: init}

	set CFG(channel)        [OT_CfgGet CHANNEL                              I]
	set CFG(menu)           [OT_CfgGet CASINO_GAME_MENU_NAME           CASINO]
	set CFG(summary_period) [OT_CfgGet CASINO_GAME_MENU_SUMMARY_PERIOD     24]
	set CFG(qry_cache_time) [OT_CfgGet CASINO_GAME_MENU_QRY_CACHE_TIME    600]

	_prep_sql

	set INIT 1

}


#
# Private procedure to prepare the package queries
#
proc ob_casino::game_menu::_prep_sql {} {

	variable CFG

	ob_db::store_qry ob_casino::game_menu::get_menus {

		select
			m.menu_id as id,
			m.title,
			x.code    as xl_code
		from
			tCGGameMenu m,
			outer tXlateCode x
		where
			m.displayed     = 'Y'
		    and m.xlate_code_id = x.code_id

	} $CFG(qry_cache_time)

	ob_db::store_qry ob_casino::game_menu::get_menu_cat_links {

		select
			menu_id,
			category_id  as cat_id
		from tCGGameMenuCLink
		where menu_id in (?, ?, ?)
		order by
			disporder,
			menu_id

	} $CFG(qry_cache_time)

	ob_db::store_qry ob_casino::game_menu::get_menu_categories {

		select
			c.cg_category_id as id,
			c.title,
			c.image,
			c.displayed,
			x.code           as xl_code
		from
			tCGGamesCategory c,
			outer tXlateCode x
		where
			c.category_type = ?
		and c.channels      like ?
		and c.xlate_code_id = x.code_id
		and c.cg_category_id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
		                         ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		order by c.disporder


	} $CFG(qry_cache_time)

	ob_db::store_qry ob_casino::game_menu::get_menu_item_links {

		select
			cg_category_id  as cat_id,
			cg_gamesmenu_id as item_id,
			locations
		from tCGGamesMenuLink
		where cg_category_id in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		order by
			disporder,
			cg_category_id

	} $CFG(qry_cache_time)

	ob_db::store_qry ob_casino::game_menu::get_menu_items {

		select
			m.cgs_id,
			m.cgr_id,
			m.cgf_id,
			r.name,
			r.display_name,
			m.title as menu_title,
			m.image,
			m.external,
			m.languages,
			m.vip,
			m.rating as override_rating,
			t.code as title_code,
			b.code as blurb_code,
			trunc (g.avg_rating + 0.5) as voted_rating
		from
			tCGGamesMenu        m,
			tCGGame             r,
			tCGGame             f,
			outer tXlateCode    t,
			outer tXlateCode    b,
			outer tCGGameRating g
		where
			m.cgr_id     = r.cg_id
		and m.cgf_id         = f.cg_id
		and r.status         = 'A'
		and f.status         = 'A'
		and r.displayed      = 'Y'
		and f.displayed      = 'Y'
		and r.free_play      = 'N'
		and f.free_play      = 'Y'
		and r.channels       like ?
		and f.channels       like ?
		and m.cgs_id         in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
								 ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		and m.xlate_code_id  = t.code_id
		and m.blurb_code_id  = b.code_id
		and m.cgs_id = g.cgs_id
		order by m.cgs_id;

	} $CFG(qry_cache_time)

	ob_db::store_qry ob_casino::game_menu::get_num_games {

		select {+ORDERED}
			s.cg_id,
			count (*)
		from
			tCGGSFinished  f,
			tCGGameSummary s
		where
			f.finished   > current year to second - ? units hour
		and f.cg_game_id = s.cg_game_id
		group by 1;

	} $CFG(qry_cache_time)

}

#
# Set the current menu.  If no argument is passed, reset to the default.
#
proc ob_casino::game_menu::set_menu { { menu CASINO } } {

	ob_log::write DEBUG {ob_casino::game_menu::set_menu $menu}

	variable CFG

	set CFG(menu) $menu

}

#
# Retrieve the current menu.
#
proc ob_casino::game_menu::get_menu {} {

	ob_log::write DEBUG {ob_casino::game_menu::get_menu}

	variable CFG

	return $CFG(menu)

}

#
# Load the menu
#
proc ob_casino::game_menu::load_menu { var { lang {} } } {

	ob_log::write DEBUG {ob_casino::game_menu::load_menu $var $lang}

	variable CFG

	variable menus
	variable categories
	variable items

	upvar 1 $var data

	_load_menu_data

	set data(menus)         [list]
	set data(categories)    [list]
	set data(all_games)     [list]
	set data(games,id_map)  [list]
	set data(non_vip_games) [list]

	#
	# First load and store the toplevel menu data
	#
	set num_menus [llength $menus(ids)]

	for { set i 0 } { $i < $num_menus } { incr i } {
		set menu_id $menus($i,id)

		set data(menus,$menus($i,title)) $menu_id
		lappend data(menus)              $menu_id

		set data(menus,$menu_id,title)   $menus($i,title)
		set data(menus,$menu_id,xl_code) $menus($i,xl_code)

		set data(menus,$menu_id,categories) [list]
		foreach j $menus($i,categories) {
			lappend data(menus,$menu_id,categories) $categories($j,id)
		}
	}

	set num_categories [llength $categories(ids)]

	for { set i 0 } { $i < $num_categories } { incr i } {

		set category_id $categories($i,id)
		set type        $categories($i,title)
		set image       $categories($i,image)
		set xl_code     $categories($i,xl_code)
		set displayed   $categories($i,displayed)

		set data(categories,$category_id,locs) $categories($i,loc,locs)
		
		foreach loc $categories($i,loc,locs) {
			if {[info exists categories($i,loc,$loc,items)]} {		
				foreach item $categories($i,loc,$loc,items) {
					lappend data(categories,$category_id,locs,$loc) $items($item,name)
				}
			}
		}

		foreach j $categories($i,items) {

			set game $items($j,name)

			set data(games,$game,name) $game

			foreach key { cgs_id
					cgr_id
					cgf_id
					display_name
					minigame
					image
					external
					vip
					title_code
					blurb_code
					num_plays
					languages
					rating
			} {
				set data(games,$game,$key) $items($j,$key)
			}

			# Add it to the general list of vip_games as long as it is not a minigame
			if { $items($j,minigame) eq "N" } { lappend data(all_games) $game }

			lappend data(games,id_map) $items($j,cgr_id)    $game
			lappend data(categories,$category_id,all_games) $game

			lappend data(games,$game,cat_ids) $category_id

			set data(games,$game,title) $data(games,$game,title_code)

			lappend type_games $game

			# VIP check now combined with a check for whether this is a minigame
			if { $data(games,$game,vip) eq "N"} {
				# Add it to the general list of non_vip_games as long as it is not a minigame
				if { $items($j,minigame) eq "N" } { lappend data(non_vip_games) $game }
				lappend data(categories,$category_id,non_vip_games) $game
			}
		}

		#
		# Ignore category if there are no games.
		#
		if { [info exists data(categories,$category_id,all_games)] } {

			lappend data(categories) $category_id

			set data(categories,$category_id,title)   $type
			set data(categories,$category_id,image)   $image
			set data(categories,$category_id,xl_code) $xl_code
			set data(categories,$category_id,displayed) $displayed			

		}

	}

	set data(all_games)     [lsort -unique $data(all_games)]
	set data(non_vip_games) [lsort -unique $data(non_vip_games)]

	set data(categories,all,all_games)     $data(all_games)
	set data(categories,all,non_vip_games) $data(non_vip_games)

	ob_log::write_array DEV data

}


proc ob_casino::game_menu::bind_menu { menu_name lang { game {} } { var {} } { vip N } } {

	ob_log::write DEBUG {ob_casino::game_menu::bind_menu $menu_name $lang $var}

	if { $var ne "" } {
		upvar 1 $var menu
	} else {
		variable menu
		set var [namespace current]::menu
	}

	array unset menu

	variable menus
	variable categories
	variable items

	#
	# populate array of available games
	#
	_load_menu_data

	# loop through each menu to find the one we need...
	# not the nicest way of doing this
	set num_menus [llength $menus(ids)]
	set cat_ids [list]

	for { set m 0 } { $m < $num_menus } { incr m } {
		if { $menus($m,title) eq $menu_name } {
			set cat_ids $menus($m,categories)
			break
		}
	}

	set t 0

	foreach i $cat_ids {
		set g 0

		if {$categories($i,displayed) eq "N"} {
			continue
		}

		foreach j $categories($i,items) {

			if { $vip eq "N" && $items($j,vip) eq "Y" }  { continue }
			set menu($t,$g,id)    $items($j,cgr_id)
			set menu($t,$g,name)  $items($j,name)
			set menu($t,$g,title) \
				[ob_xl::XL $lang |$items($j,title_code)|]

			if { $game eq $items($j,name) } {
				tpBindString topbar_game_name [string toupper $menu($t,$g,title)]
				tpBindString topbar_game      $game
			}

			incr g
		}

		#
		# Ignore category if there are no games.
		#
		if { $g } {

			set menu($t,type) [ob_xl::XL $lang |$categories($i,xl_code)|]
			set menu($t,num_games) $g

			incr t

		}

	}

	tpSetVar casino_menu_num_types $t

	tpBindVar casino_menu_type_name   $var type      i
	tpBindVar casino_menu_num_games   $var num_games i
	tpBindVar casino_menu_game_name   $var name      i j
	tpBindVar casino_menu_game_title  $var title     i j
	tpBindVar casino_menu_game_id     $var id        i j

	ob_log::write_array DEV menu

}

proc ob_casino::game_menu::_load_menu_data {} {

	#
	# Large and unwieldy proc to pull out all the menu data and store it in one of three arrays:
	# 			menus, categories, items
	#

	variable CFG

	ob_log::write DEBUG {ob_casino::game_menu::_load_menu_data}

	#
	# First grab all the menus
	#
	if { [catch {
		set rs [ob_db::exec_qry ob_casino::game_menu::get_menus]
	} err] } {
		ob_log::write ERROR {Error loading menus: $err}
		return
	}

	variable    menus
	array unset menus
	array set   menus [list ids [list]]

	set num_menus [db_get_nrows $rs]

	# This will store the categories that this menu links to
	array set cat_links [list]

	# Place all menu details within an array
	for { set i 0 } { $i < $num_menus } { incr i } {
		set menus($i,id)         [db_get_col $rs $i id]
		set menus($i,title)      [db_get_col $rs $i title]
		set menus($i,categories) [list]

		set xl_code [db_get_col $rs $i xl_code]
		if { $xl_code ne "" } {
			set menus($i,xl_code) $xl_code
		} else {
			set menus($i,xl_code) CASINO_TYPE_TITLE_[string toupper $menus($i,title)]
		}

		lappend menus(ids) $menus($i,id)

		set cat_links($menus($i,id)) [list]
	}

	ob_db::rs_close $rs

	# Now grab all the category links for the menus as above
	set cat_ids [list]

	for { set s 0; set e 2 } { $s < $num_menus } { incr s 3; incr e 3 } {

		if { [catch {
			set rs [eval ob_db::exec_qry ob_casino::game_menu::get_menu_cat_links \
										[lrange $menus(ids) $s $e]]
		} err] } {
			ob_log::write ERROR {Error loading menu_cat links: $err}
			return
		}

		set num_links [db_get_nrows $rs]

		#
		# Store the category links as a link specific to this menu
		#  i.e. cat_links(2) 151 152 153 etc
		# and also in a list of all categories loaded so we only load
		# items for relevant categories
		#
		for { set i 0 } { $i < $num_links } { incr i } {
			set menu_id [db_get_col $rs $i menu_id]
			set cat_id  [db_get_col $rs $i cat_id]

			lappend cat_links($menu_id) $cat_id
			lappend cat_ids             $cat_id
		}

		ob_db::rs_close $rs

	}

	# Remove duplicate categories from the list of all categories to avoid duplicate loading of items
	set cat_ids  [lsort -unique -integer $cat_ids]
	set num_cats [llength $cat_ids]

	#
	# Now get all the displayed categories for these menus as defined by cat_ids
	#
	variable    categories
	array unset categories
	array set   categories [list ids [list]]

	set i 0

	# This will hold links between a category and an item/game
	array set item_links [list]

	for { set s 0; set e 19 } { $s < $num_cats } { incr s 20; incr e 20 } {

		if { [catch {
			set rs [eval ob_db::exec_qry ob_casino::game_menu::get_menu_categories \
									$CFG(menu) \
									%$CFG(channel)% \
									[lrange $cat_ids $s $e]]
			} err] } {
				ob_log::write ERROR {Error loading menu categories: $err}
				return
			}

		set n [db_get_nrows $rs]

		# As with menu data above, store all the category data
		for { set r 0 } { $r < $n } { incr r; incr i } {
			set categories($i,id)    [db_get_col $rs $r id]
			set categories($i,title) [db_get_col $rs $r title]
			set categories($i,image) [db_get_col $rs $r image]
			set categories($i,displayed) [db_get_col $rs $r displayed]
			set categories($i,items) [list]

			set xl_code [db_get_col $rs $r xl_code]
			if { $xl_code ne "" } {
				set categories($i,xl_code) $xl_code
			} else {
				set categories($i,xl_code) \
					CASINO_TYPE_TITLE_[string toupper $categories($i,title)]
			}

			# Construct a list of all category ids
			lappend categories(ids) $categories($i,id)

			set item_links($categories($i,id)) [list]
		}

		ob_db::rs_close $rs

	}

	#
	# Now grab all the links for those categories
	#
	set item_ids [list]

	for { set s 0; set e 35 } { $s < $num_cats } { incr s 36; incr e 36 } {

		if { [catch {
			set rs [eval ob_db::exec_qry ob_casino::game_menu::get_menu_item_links \
										 [lrange $categories(ids) $s $e]]
		} err] } {
			ob_log::write ERROR {Error loading menu_item links: $err}
			return
		}

		set num_links [db_get_nrows $rs]

		for { set i 0 } { $i < $num_links } { incr i } {

			set cat_id  [db_get_col $rs $i cat_id]
			set item_id [db_get_col $rs $i item_id]

			lappend item_links($cat_id) $item_id
			lappend item_ids            $item_id

			set locations [split [db_get_col $rs $i locations] ,]
			foreach loc $locations {
				if { ![info exists item_links($cat_id,locs)] || \
					 [lsearch $item_links($cat_id,locs) $loc] == -1 } {
					lappend item_links($cat_id,locs) $loc
				}
				lappend item_links($cat_id,locs,$loc) $item_id
			}
		}

		ob_db::rs_close $rs

	}

	ob_log::write_array DEV item_links

	set item_ids [lsort -unique -integer $item_ids]
	set num_items [llength $item_ids]

	array set num_plays [list]

	if { [catch {
		set rs [ob_db::exec_qry ob_casino::game_menu::get_num_games \
								$CFG(summary_period)]
	} err] } {
		ob_log::write WARNING {Error loading casino games menu: $err}
	} else {

		for { set i 0; set n [db_get_nrows $rs] } { $i < $n } { incr i } {
			set num_plays([db_get_coln $rs $i 0]) [db_get_coln $rs $i 1]
		}

		ob_db::rs_close $rs

	}

	#
	# Then grab all the active games which appear in those links as per cat_links
	#
	variable items

	array unset items
	array set   items [list ids [list]]

	for { set i 0
		  set s 0; set e 71 } { $s < $num_items } { incr s 72; incr e 72 } {

		if { [catch {
			set rs [eval ob_db::exec_qry ob_casino::game_menu::get_menu_items \
										 %$CFG(channel)% \
										 %$CFG(channel)% \
										 [lrange $item_ids $s $e]]
		} err] } {
			ob_log::write ERROR {Error loading casino games menu: $err}
			return
		}

		set n [db_get_nrows $rs]

		for { set r 0 } { $r < $n } { incr r; incr i } {

			set items($i,cgs_id)       [db_get_col $rs $r cgs_id]
			set items($i,cgr_id)       [db_get_col $rs $r cgr_id]
			set items($i,cgf_id)       [db_get_col $rs $r cgf_id]
			set items($i,name)         [db_get_col $rs $r menu_title]

			# THIS IS BAD!!! Assume that if it has Mini in the game name, it is
			# a minigame. This should be replaced with a column specifically
			# to indicate mini-game
			if {[string match -nocase "*Mini*" $items($i,name)]} {
				set items($i,minigame) "Y"
			} else {
				set items($i,minigame) "N"
			}

			set items($i,languages)    [split [db_get_col $rs $r languages] ,]
			if { [info exists num_plays($items($i,cgr_id))] } {
				set items($i,num_plays) $num_plays($items($i,cgr_id))
			} else {
				set items($i,num_plays) 0
			}

			set rating [db_get_col $rs $r override_rating]
			# Check override rating has been set and that it is in correct range
			if { $rating eq "" || $rating < 1 || $rating > 5 } {
				set rating [db_get_col $rs $r voted_rating]
				if { $rating eq "" } {
					set rating 3
				}
			}
			set items($i,rating) $rating

			foreach {
				key           default
			} [subst {
				display_name $items($i,name)
				image        $items($i,name)
				external     N
				vip          N
				title_code   CASINO_GAME_TITLE_[string toupper $items($i,name)]
				blurb_code   CASINO_GAME_BLURB_[string toupper $items($i,name)]
			}] {

				set val [db_get_col $rs $r $key]

				if { $val ne "" } {
					set items($i,$key) $val
				} else {
					set items($i,$key) $default
				}

			}

			lappend items(ids) $items($i,cgs_id)

		}

		ob_db::rs_close $rs

	}

	#
	# Finally map the menus to categories and the categories to items
	#
	for { set i 0 } { $i < $num_menus } { incr i } {
		foreach cat_id $cat_links($menus($i,id)) {
			set idx [lsearch $categories(ids) $cat_id]
			if { $idx != -1 } {
				lappend menus($i,categories) $idx
			}
		}
	}

	for { set i 0 } { $i < $num_cats } { incr i } {
		foreach item_id $item_links($categories($i,id)) {
			set idx [lsearch $items(ids) $item_id]
			if { $idx != -1 } {
				lappend categories($i,items) $idx
			}
		}
		if { [info exists item_links($categories($i,id),locs)] } {
			foreach loc $item_links($categories($i,id),locs) {
				lappend categories($i,loc,locs) $loc
				foreach item_id $item_links($categories($i,id),locs,$loc) {
					set idx [lsearch $items(ids) $item_id]
					if { $idx != -1 } {
						lappend categories($i,loc,$loc,items) $idx
					}
				}
			}
		} else {
			set categories($i,loc,locs) [list]
		}
	}

	ob_log::write_array DEV menus
	ob_log::write_array DEV categories
	ob_log::write_array DEV items

}
