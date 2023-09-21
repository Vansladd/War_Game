# ==============================================================
# $Id: menu.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 2004 Orbis Technology Ltd. All rights reserved.
# ==============================================================

namespace eval ADMIN::MENU {
}

proc ADMIN::MENU::bind_menu {menus} {
	global MENU

	set CGI_URL [OT_CfgGet CGI_URL]

	#
	# Now work out all relevant menus and submenus
	#
	set num_menus 0
	set i 0
	foreach {menudata submenu} $menus {
		set cfg [lindex $menudata 2]
		if {$cfg != ""} {
			set default [lindex $menudata 3]
		}
		set op_test [lindex $menudata 4]
		if {$op_test == ""} {
			set op_test 1
		} else {
			set op_test [eval $op_test]
		}
		if {($cfg == "" || [OT_CfgGet $cfg $default]) && $op_test} {
			set MENU($num_menus,name) [subst [lindex $menudata 0]]
			set MENU($num_menus,id) [lindex $menudata 1]
			set num_sub [llength $submenu]
			set n 0
			for {set j 0} {$j < $num_sub} {incr j} {
				set submenu_data [lindex $submenu $j]
				set cfg [lindex $submenu_data 2]
				set default [lindex $submenu_data 3]
				set op_test [lindex $submenu_data 4]
				if {$op_test == ""} {
					set op_test 1
				} else {
					#ob::log::write DEV {op_test $op_test [eval $op_test]}
					set op_test [eval $op_test]
				}
				if {$cfg == "" || [OT_CfgGet $cfg $default] && $op_test} {
					set MENU($num_menus,$n,name) [subst [lindex $submenu_data 0]]
					set MENU($num_menus,$n,href) [subst [lindex $submenu_data 1]]
					incr n
				}
				set MENU($num_menus,num_subs) $n
			}
			incr num_menus
		}
		incr i
	}

	tpSetVar  menu_num $num_menus
	tpBindVar name    MENU name 1Idx
	tpBindVar id      MENU id   1Idx
	tpBindVar href    MENU href 1Idx 2Idx
	tpBindVar subname MENU name 1Idx 2Idx
}

proc ADMIN::MENU::show_logo {} {
	tpBufAddHdr "Content-Type" "image/gif"
	set f [open ../html/orbis_logo.gif r]
	fconfigure $f -translation binary
	tpBufWriteBin [read $f]
	close $f
}
