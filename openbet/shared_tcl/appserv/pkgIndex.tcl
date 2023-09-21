# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#

global xtn

# default to tcl file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tcl
}

set appserv_pkg [list \
	appserv_queues       4.5 queues       \
	appserv_messageboard 4.5 messageboard \
	appserv_nohttp       4.5 nohttp       \
	appserv_page_cache   4.5 page_cache   \
]

foreach {pkg version file} $appserv_pkg {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}
