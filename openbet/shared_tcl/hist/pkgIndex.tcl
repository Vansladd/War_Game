# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
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

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

set hist_pkg [list \
    hist_hist   4.5 hist\
    hist_TX     4.5 TX\
    hist_PMT    4.5 PMT\
    hist_XGAME  4.5 XGAME\
    hist_BET    4.5 BET\
    hist_BALLS  4.5 BALLS\
    hist_NBALLS 4.5 NBALLS\
    hist_SNG    4.5 SNG\
    hist_IGF    4.5 IGF\
    hist_GAM    4.5 GAM\
    hist_PBET   4.5 POOLS]

foreach {pkg version file} $hist_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}

