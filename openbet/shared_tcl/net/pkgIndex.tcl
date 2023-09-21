# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:13 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# NET tcl package index file.
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

set cust_pkg [list\
        net_sockserver 4.5 sock_server\
        net_sockclient 4.5 sock_client\
        net_socket     4.5 socket\
        net_util       4.5 util]

foreach {pkg version file} $cust_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}

