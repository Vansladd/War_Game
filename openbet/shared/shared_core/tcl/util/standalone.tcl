# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Standalone utilities for core scripts
#
set pkgVersion 1.0
package provide core::standalone $pkgVersion

package require core::check 1.0
package require core::args  1.0
package require core::unit  1.0
package require core::stub  1.0

core::args::register_ns \
	-namespace core::standalone \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args] \
	-docs      util/standalone.xml

namespace eval core::standalone {
	variable CFG

	set CFG(log_dir)  {.}
	set CFG(log_file) {<<stdout>>}
	set CFG(packages) {
		core::unit          1.0
		core::util          1.0
		core::xml           1.0
		core::stub          1.0
		core::stub::appserv 1.0
		core::stub::db      1.0
		core::assert        1.0
		core::db            1.0
		core::gc            1.0
		core::log           1.0
	}
}

# Helper proc that setups standard functionality for scripts
core::args::register \
	-proc_name core::standalone::init \
	-args      [list \
		[list -arg -options         -mand 0 -check ANY    -default {}      -desc {List of getopts info {-a auto_path LIST {} "TCL autopath"}}] \
		[list -arg -simple_options  -mand 0 -check ANY    -default {}      -desc {Simplified option list {--option {} "Description"}}] \
		[list -arg -packages        -mand 0 -check ANY    -default {}      -desc {List of packages to load {core::log 1.0}}] \
		[list -arg -init_log        -mand 0 -check BOOL   -default 0       -desc {Initialise logging}] \
		[list -arg -log_sym_level   -mand 0 -check ASCII  -default INFO    -desc {Log level}] \
		[list -arg -init_unit       -mand 0 -check BOOL   -default 0       -desc {Initialise unit testing}] \
		[list -arg -unit_enabled    -mand 0 -check BOOL   -default 1       -desc {Test package enabled}] \
		[list -arg -unit_package    -mand 0 -check ASCII  -default {}      -desc {Test package name}] \
		[list -arg -unit_setup      -mand 0 -check ASCII  -default {}      -desc {Test package setup proc}] \
		[list -arg -unit_cleanup    -mand 0 -check ASCII  -default {}      -desc {Test package cleanup proc}] \
		[list -arg -suite_name      -mand 0 -check ASCII  -default {}      -desc {Initial test suite name}] \
		[list -arg -prefix_args     -mand 0 -check ASCII  -default {}      -desc {List of arguments that prefix the n/v pairs}] \
		[list -arg -relative_home   -mand 0 -check ASCII  -default {../}   -desc {Relative project home from the tcl directory}] \
		[list -arg -src_dir         -mand 0 -check ASCII  -default {tcl/}  -desc {Source directory}] \
		[list -arg -test_src_dir    -mand 0 -check ASCII  -default {test/} -desc {Test source directory}] \
		[list -arg -strict_stubbing -mand 0 -check BOOL   -default 0       -desc {Enforce strict syntax when using core::stub}] \
		[list -arg -stub_appserv    -mand 0 -check BOOL   -default 1       -desc {Stub out the appserver functionality}] \
	] \
	-body {
		variable CFG

		upvar 1 ::argv argv

		set CFG(packages)        [concat $CFG(packages) $ARGS(-packages)]
		set CFG(script)          [uplevel 1 {info script}]
		set CFG(fname)           [uplevel 1 {file rootname [file tail [info script]]}]
		set CFG(usage)           [subst {Usage: tclsh8.5 $CFG(script) $ARGS(-prefix_args) \[OPTIONS\]\n\t}]
		set CFG(trace_file)      {}
		set CFG(output_dir)      {}
		set CFG(config)          {}
		set CFG(output_file)     {<<stdout>>}
		set CFG(relative_home)   $ARGS(-relative_home)
		set CFG(src_dir)         $ARGS(-src_dir)
		set CFG(test_src_dir)    $ARGS(-test_src_dir)
		set CFG(init_log)        $ARGS(-init_log)
		set CFG(strict_stubbing) $ARGS(-strict_stubbing)
		set CFG(abort_limit)     0
		set arg_offset           [llength $ARGS(-prefix_args)]
		set options              {}

		if {$ARGS(-suite_name) != {}} {
			set CFG(suite_name) $ARGS(-suite_name)
		} else {
			set CFG(suite_name) [format "core::%s" $CFG(fname)]
		}

		array set MAP {}

		# Handle the old slightly longwinded options handling
		foreach {short_form arg type default desc} $ARGS(-options) {

			# Set default
			set CFG($arg) $default

			if {$short_form != {}} {
				set MAP($short_form) $arg
			}

			set MAP(--$arg) $arg

			if {$type != {}} {
				set name [format "--%s (%s)" $arg $type]
			} else {
				set name [format "--%s" $arg]
			}

			lappend options [format "%s, %-20s - %-30s (%s)" \
				$short_form \
				$name \
				$desc \
				$default]
		}

		# Handle simplified getopts option handling
		foreach {flag default desc} $ARGS(-simple_options) {
			set arg [string trimleft $flag --]

			# Set default
			set CFG($arg)  $default
			set MAP($flag) $arg

			lappend options [format "%-20s - %-30s (%s)" \
				$flag \
				$desc \
				$default]
		}

		append CFG(usage) [join $options "\n\t"]

		# Parse input
		foreach {flag value} [lrange $argv $arg_offset end] {
			if {![info exists MAP($flag)]} {
				puts stderr "Ignoring $flag - Unknown Parameter"
				continue
			}

			set name $MAP($flag)

			switch -- $name {
				auto_path {
					lappend ::auto_path {*}$value
				}
				help {
					puts [core::standalone::usage]
					exit
				}
			}

			set CFG($name) $value
		}

		# Initialise logging
		if {$ARGS(-init_log)} {
			core::log::init \
				-log_dir    $CFG(log_dir) \
				-log_file   $CFG(log_file) \
				-symlevel   $ARGS(-log_sym_level) \
				-strict     0 \
				-standalone 1

			core::log::xwrite -msg {Initialising standalone} -colour green
		} else {
			puts "Initialising standalone"
		}

		_log_input

		# Read the config file defined by --config BEFORE we load the packages
		if {$CFG(config) != {}} {
			if {[catch {
				core::log::write INFO {Reading configuration $CFG(config)}
				OT_CfgRead $CFG(config)
			} err]} {
				core::log::write ERROR {ERROR $err}
			}
		}

		foreach {pkg version} $CFG(packages) {
			set version [core::util::load_package -package $pkg -version $version]

			if {$ARGS(-init_log)} {
				core::log::write INFO {[format " Loaded %-20s %s" $pkg $version]}
			} else {
				puts [format " Loaded %-20s %s" $pkg $version]
			}
		}

		if {![regexp {<<(stdout|stderr)>>} $CFG(output_file) all CFG(output)]} {
			set CFG(output) [file join $CFG(output_dir) $CFG(output_file)]
		}

		# Initialise the unit testing package
		if {$ARGS(-init_unit)} {
			set unit_package $ARGS(-unit_package)

			set pkg_relative {}
			set test_script  [file normalize $CFG(script)]

			# Maven will define sourceDirectory and testSourceDirectory
			# so the test_script and pkg_file should be relative to that
			if {[info exists ::TCL($unit_package,filename)]} {

				set pkg_filename [file normalize $::TCL($unit_package,filename)]

				if {[info exists ::env(SRC_PATH)] && [info exists ::env(TEST_PATH)] \
					&& $::env(SRC_PATH) != {} && $::env(TEST_PATH) != {}} {

					set src_dir      [format "%s/" $::env(SRC_PATH)]
					set test_dir     [format "%s/" $::env(TEST_PATH)]

					regsub $src_dir  $pkg_filename {} pkg_relative
					regsub $test_dir $test_script  {} test_script

				} else {
					set home         [file normalize [file join $::TCL($unit_package,dir) $CFG(relative_home)]]

					regsub [format "%s/%s" $home $CFG(test_src_dir)] $test_script  {} test_script
					regsub [format "%s/%s" $home $CFG(src_dir)]      $pkg_filename {} pkg_relative
				}
			}

			core::unit::init \
				-trace_file   $CFG(trace_file) \
				-output       $CFG(output) \
				-enabled      $ARGS(-unit_enabled) \
				-abort_limit  $CFG(abort_limit) \
				-package      $unit_package \
				-properties   [list \
					pkg_name    $unit_package \
					pkg_file    $pkg_relative \
					dir         [exec pwd] \
					test_script $test_script] \
				-test_include [expr {[info exists ::env(TEST_INCLUDE)] ? $::env(TEST_INCLUDE) : {ALL}}]

			core::unit::testsuite \
				-name       $CFG(suite_name) \
				-setup      $ARGS(-unit_setup) \
				-cleanup    $ARGS(-unit_cleanup)

			# Initialize stubbing
			if { $CFG(strict_stubbing) } {
				core::stub::init -strict 1
			} else {
				core::stub::init
			}

			# Stub out the appserver
			if {$ARGS(-stub_appserv)} {
				core::util::load_package -package core::stub::appserv -version 1.0
				core::stub::appserv::init
			}
		}

		return
	}

# Log the script input
proc core::standalone::_log_input {} {

	variable CFG

	foreach name [lsort [array names CFG]] {
		if {$name == {usage}}  {continue}

		if {$CFG(init_log)} {
			core::log::write DEBUG {[format "%-15s %s" $name $CFG($name)]}
		} else {
			puts [format "%-15s %s" $name $CFG($name)]
		}
	}
}

# Retrieve standalone config information
# @param -name    config name
# @param -default Default value if named config doesn't exist
core::args::register \
	-proc_name core::standalone::get_config \
	-args      [list \
		[list -arg -name    -mand 1 -check ASCII             -desc {Config name}] \
		[list -arg -default -mand 0 -check ANY   -default {} -desc {Default value if named config doesn't exist}] \
	] \
	-body {
		variable CFG

		set name $ARGS(-name)

		if {[info exists CFG($name)]} {
			return $CFG($name)
		}

		return $ARGS(-default)
	}

# @return configured usage
core::args::register \
	-proc_name core::standalone::usage \
	-body {
		variable CFG
		return $CFG(usage)
	}
