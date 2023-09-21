# $Id: pkgIndex.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Utility tcl package index file.
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

#
#
# Package              | Description
# ---------------------------------------------------------------------------
# oxixpushserver       | Functions for dealing with failed messages
# ---------------------------------------------------------------------------
#
set OXi_Packages [list \
	oxipushserver            1.0 $dir [list \
	                                     oxipushserver/init.${xtn} \
	                                     oxipushserver/failed_msgs.${xtn} \
	                                     ] \
]

foreach {
	pkg_name 
	pkg_version 
	pkg_dir 
	pkg_files
} $OXi_Packages {
  
	if {[llength $pkg_files] == 1} {
		package ifneeded $pkg_name $pkg_version [list source [file join $pkg_dir $pkg_files]]
		continue
	}

	set full_path [list]
	foreach f $pkg_files {
		lappend full_path [file join $pkg_dir $f]
	}

	package ifneeded $pkg_name $pkg_version [list foreach f $full_path {source $f}]
}
