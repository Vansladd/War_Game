# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Security tcl package index file.
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

set security_pkg [list \
	security_cntrychk   4.5 country_check\
	security_fraudchk   4.5 fraud_check\
	security_geopoint   4.5 geopoint\
	security_iesnare    4.5 iesnare]

foreach {pkg version file} $security_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}

