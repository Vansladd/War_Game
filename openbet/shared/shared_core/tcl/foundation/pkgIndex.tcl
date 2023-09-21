# Core Util Package Index
variable TCL

set pkg_list [list \
	core::args  1.3  args \
    core::check 1.0  check \
    core::log   1.0  log \
]

foreach {pkg version name} $pkg_list {

	set file [file join $dir $name]

	if {[file exists $file.tbc]} {
		set file  $file.tbc
	} elseif {[file exists $file.tcl]} {
		set file  $file.tcl
	} else {
		error "Can't load package $pkg version $version from file $file.{tbc,tcl}"
	}

	set TCL($pkg,filename) $file
	set TCL($pkg,dir)      $dir
	set TCL($pkg,version)  $version

	package ifneeded $pkg $version [list source $file]
}
