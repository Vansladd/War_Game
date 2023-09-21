# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Make it possible for packages to rely of legacy shared TCL.
#

global xtn

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

foreach {pkg version file} {
	camp_track       4.5   camp_track
	ezsmtp           1.0.0 ezsmtp
	ICS              1.0   cybersource
	util_prof        4.5   util/prof
	xsys             1.0   xsys
} {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
