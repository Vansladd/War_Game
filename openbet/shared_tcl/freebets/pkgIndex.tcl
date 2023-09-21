# $Id: pkgIndex.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#

global xtn

# default to tbc file extensions, compiled tcl
# - if using un-compiled tcl, set xtn tcl before requiring the packages
if {![info exists xtn]} {
	set xtn tbc
}

foreach {pkg version file} {freebets_retro 4.5 retro} {
	package ifneeded $pkg $version [list source [file join $dir $file.$xtn]]
}

set general_files [list\
	check.$xtn \
	cache.$xtn \
	fulfill.$xtn \
]

set fbet_packages [list\
    fbets_fbets     4.5 [eval list freebets.$xtn $general_files]\
]

foreach {
	pkg_name
	pkg_version
	pkg_files
} $fbet_packages {

	set full_path [list]
	foreach f $pkg_files {
		lappend full_path [file join $dir $f]
	}

	package ifneeded $pkg_name $pkg_version\
		[list foreach f $full_path {source $f}]
}