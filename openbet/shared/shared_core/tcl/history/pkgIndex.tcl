# Core History Package Index
variable TCL

set pkg_list [list \
    core::history                       1.0  history \
    core::history::bet                  1.0  bet \
    core::history::combination          1.0  combination \
    core::history::footballpoolbet      1.0  footballpoolbet \
    core::history::formatter            1.0  formatter \
    core::history::game                 1.0  game \
    core::history::lotterybet           1.0  lotterybet \
    core::history::poolbet              1.0  poolbet \
    core::history::payment              1.0  payment \
    core::history::transaction          1.0  transaction \
    core::history::fs_transaction       1.0  fs_transaction \
    core::history::transfer             1.0  transfer \
    core::history::manualadjustment     1.0  manualadjustment \
    core::history::fund                 1.0  fund \
    core::history::wagering_requirement 1.0  wagering_requirement \
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
