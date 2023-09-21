# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:27:05 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Utility tcl package index file.
# Sourced either when an application starts up or by a "package unknown"
# script.  It invokes the "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically in response to
# "package require" commands.  When this script is sourced, the variable
# $dir must contain the full path name of this file's directory.
#

global xtn admin_screens

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

# default to standalone or customer screens (not admin)
if {![info exists admin_screens]} {
	set admin_screens 0
}

set rng_pkg [list]

# Based on tcl version use suitable RNG
if {[info tclversion] >= 8.4} {
	lappend rng_pkg rng_client 4.5 rngclient32
} else {
	lappend rng_pkg rng_client 4.5 rngclient
}

foreach {pkg version file} $rng_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
