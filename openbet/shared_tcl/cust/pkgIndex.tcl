# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:51 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Customer tcl package index file.
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

set cust_pkg [list \
		cust_flag         4.5 flag\
		cust_group        4.5 group\
		cust_login        4.5 login\
		cust_login_compat 4.5 login-compat\
		cust_pref         4.5 pref\
		cust_reg          4.5 register\
		reg_utils         0.1 reg_utils\
		cust_session      4.5 session\
		cust_status_flag  4.5 status_flag\
		cust_util         4.5 util\
		cust_srp          4.5 srp\
		cust_kyc          4.5 kyc\
]

foreach {pkg version file} $cust_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
