# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# Office API package index file.
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

set files [list init.$xtn action.$xtn util.$xtn login.$xtn err.$xtn]

set full_path [list]
foreach f $files {
	lappend full_path [file join $dir $f]
}

package ifneeded office 1.0 [list foreach f $full_path {source $f}]

