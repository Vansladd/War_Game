# Core funding interface package interface
variable TCL

# Package version filename
set pkg_list [list \
    core::funding  1.0  funding \
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
