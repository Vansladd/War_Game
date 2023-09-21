# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
# (C) 2011 OpenBet. All rights reserved.
#
# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

global xtn

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
        set xtn tbc
}

set files     [list \
				monitor.${xtn}\
				alert.${xtn}\
				bet.${xtn}\
				bg.${xtn}\
				arbitrage.${xtn}\
				bet_rum.${xtn}\
				betx.${xtn} \
				bf_order.${xtn} \
				cust_max_stake.${xtn} \
				first_transfer.${xtn} \
				fraud.${xtn} \
				man_bet.${xtn} \
				manual_adjustment.${xtn} \
				non_runner.${xtn} \
				override.${xtn} \
				parked_bet.${xtn} \
				payment.${xtn} \
				payment_denied.${xtn} \
				pmt_method_registered.${xtn} \
				pmt_non_card.${xtn} \
				poker.${xtn} \
				red.${xtn} \
				send_seln_rum.${xtn} \
				suspended.${xtn} \
				async_bet.${xtn} \
				urn_match.${xtn} ]
	
set full_path [list]

foreach f $files {
	lappend full_path [file join $dir $f]
}

set full_path_compat [lappend full_path [file join $dir monitor-compat.${xtn}]]

package ifneeded monitor_compat 1.0 [list foreach f $full_path_compat {source $f}]

package ifneeded MONITOR 1.0 [list foreach f $full_path_compat {source $f}]

package ifneeded monitor_monitor 4.5 [list foreach f $full_path {source $f}]

