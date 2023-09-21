# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:26:34 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Admin tcl package index file.
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

set admin_pkg [list admin_login 4.5 login\
					admin_audit 4.5 audit\
					admin_user  4.5 user]

foreach {pkg version file} $admin_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
