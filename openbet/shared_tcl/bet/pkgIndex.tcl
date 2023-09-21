################################################################################
# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Bet placement pkgIndex file.
#
# Utility tcl package index file.
# Sourced either when an application starts up or by a "package unknown"
# script.  It invokes the "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically in response to
# "package require" commands.  When this script is sourced, the variable
# $dir must contain the full path name of this file's directory.
#
################################################################################

global xtn

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

set general_files [list\
					   bet.$xtn\
					   cust.$xtn\
					   place.$xtn\
					   selection.$xtn\
					   util.$xtn\
					   override.$xtn\
					   limits.$xtn\
					   liability.$xtn\
					   freebets.$xtn\
					   combi.$xtn\
					   async.$xtn\
					   manual.$xtn\
					   bet_delay.$xtn]

set bet_packages [list\
	bet_bet         4.5 [eval list bet6.$xtn $general_files]\
	bet_45          4.5 [eval list bet45.$xtn $general_files]\
	bet_interactive 4.5 [eval list bet_interactive.$xtn $general_files]]

foreach {
	pkg_name
	pkg_version
	pkg_files
} $bet_packages {

	set full_path [list]
	foreach f $pkg_files {
		lappend full_path [file join $dir $f]
	}

	package ifneeded $pkg_name $pkg_version\
		[list foreach f $full_path {source $f}]
}
