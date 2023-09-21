# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:27:27 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Payment tcl package index file.
# Sourced either when an application starts up or by a "package unknown"
# script.  It invokes the "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically in response to
# "package require" commands.  When this script is sourced, the variable
# $dir must contain the full path name of this file's directory.
#

global xtn

# Default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

set pmt_pkg [list \
		pmt_validate      4.5 validate\
]

foreach {pkg version file} $pmt_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
