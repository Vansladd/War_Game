# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utility tcl package index file.
# Sourced either when an application starts up or by a "package unknown"
# script.  It invokes the "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically in response to
# "package require" commands.  When this script is sourced, the variable
# $dir must contain the full path name of this file's directory.
#

global xtn

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

foreach {
	pkg               ver file
} [list \
	casino_game_menu  4.5 game_menu \
	casino_game_xml   4.5 game_xml  \
	casino_jackpot    4.5 jackpot   \
	casino_winners    4.5 winners   \
] {
	package ifneeded $pkg $ver [list source [file join $dir $file.$xtn]]
}
