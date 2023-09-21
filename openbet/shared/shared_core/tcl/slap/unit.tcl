#
#

#
# Example usage...
#
# core::unit::testsuite -name testsuite1
# core::unit::test -name test1.1 -setup {set 1 2} -body {expr 1/0} -cleanup {set 5 6}
# core::unit::test -name test1.2 -setup {set 2 3} -body {set 2 3} -return {3} -cleanup {set 4 5}
#
# core::unit::write
#
# https://svn.jenkins-ci.org/trunk/hudson/dtkit/dtkit-format/dtkit-junit-model/src/main/resources/com/thalesgroup/dtkit/junit/model/xsd/junit-4.xsd

set pkg_version 1.0
package provide core::unit $pkg_version
package require core::check 1.0
package require core::args  1.0
package require core::xml   1.0
package require core::stub  1.0
package require core::log   1.0
package require core::util  1.0
package require tdom

core::args::register_ns \
	-namespace core::unit \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::stub core::log core::xml] \
	-docs      slap/unit.xml

namespace eval core::unit {

	variable LOG
	variable XML
	variable CFG
	variable COVERAGE

	set LOG(testsuites)        {}
	set LOG(current_suite)     {}
	set LOG(current_suite_key) {}
	set LOG(current_test)      {}
	set CFG(name)              {}
	set CFG(trace_file)        {}
	set CFG(trace_auto)        1
	set CFG(output)            stdout
	set CFG(test_filter)       {}

	namespace export testsuite
	namespace export test
	namespace export write
}

# Quick setup for a standard unit test
core::args::register \
	-proc_name core::unit::standalone_setup \
	-args      [list \
		[list -arg -package         -mand 1 -check ASCII                                              -desc {Test package name}] \
		[list -arg -version         -mand 1 -check DECIMAL                           -default {}      -desc {Test package version}] \
		[list -arg -log_sym_level   -mand 0 -check ASCII   -default_cfg LOG_SYMLEVEL -default INFO    -desc {Log level}] \
		[list -arg -relative_home   -mand 0 -check ASCII                             -default {../}   -desc {Relative project home from the tcl directory}] \
		[list -arg -src_dir         -mand 0 -check ASCII                             -default {tcl/}  -desc {Source directory}] \
		[list -arg -test_src_dir    -mand 0 -check ASCII                             -default {test/} -desc {Test source directory}] \
		[list -arg -load_package    -mand 0 -check BOOL                              -default 1       -desc {Load the package as the first test}] \
		[list -arg -unit_setup      -mand 0 -check ASCII                             -default {}      -desc {Test package setup proc}] \
		[list -arg -unit_cleanup    -mand 0 -check ASCII                             -default {}      -desc {Test package cleanup proc}] \
		[list -arg -ignore_packages -mand 0 -check ASCII                             -default {}      -desc {Ignore certain packages when loading the main package}] \
		[list -arg -abort_limit     -mand 0 -check UINT                              -default 0       -desc {Abort test run when num errors reaches the limit. 0 means run to completion.}] \
		[list -arg -stub_appserv    -mand 0 -check BOOL                              -default 1       -desc {Stub out the appserver functionality}] \
	] \
	-body {
		set fname       [file rootname [file tail [info script]]]
		set output_file "unit-test-${fname}.xml"
		set trace_file  [clock format [clock seconds] -format "coverage.%Y%m%d.xml"]
		set ignore_list $ARGS(-ignore_packages)

		core::util::load_package -package core::standalone -version 1.0

		# Initialise standalone features
		core::standalone::init \
			-init_log       1 \
			-init_unit      1 \
			-unit_package   $ARGS(-package) \
			-unit_setup     $ARGS(-unit_setup) \
			-unit_cleanup   $ARGS(-unit_cleanup) \
			-suite_name     $ARGS(-package) \
			-log_sym_level  $ARGS(-log_sym_level) \
			-relative_home  $ARGS(-relative_home) \
			-src_dir        $ARGS(-src_dir) \
			-test_src_dir   $ARGS(-test_src_dir) \
			-stub_appserv   $ARGS(-stub_appserv) \
			-simple_options [list \
				--auto_path    {}                "Paths to add to the auto_path"     \
				--log_dir      {.}               "Directory to log"                  \
				--log_file     {<<stdout>>}      "Log file"                          \
				--trace_file   $trace_file       "Code coverage output file"         \
				--output_dir   {.}               "Directory to write the unit test"  \
				--output_file  $output_file      "Name of the unit test file"        \
				--help         {}                "Display usage"                     \
				--abort_limit  0                 "Abort after these num of errors. 0 means run to end" \
			]

		# Load the package using package require
		# Do this as a test to confirm whether the
		# package has been created properly
		if {$ARGS(-load_package)} {
			core::util::load_package \
				-package     $ARGS(-package) \
				-version     $ARGS(-version) \
				-ignore_list $ignore_list
		}
	}

# Initialise the unit testing framework
core::args::register \
	-proc_name core::unit::init \
	-args [list \
		[list -arg -name         -mand 0 -check STRING                               -default {}       -desc {Name of the test run}] \
		[list -arg -package      -mand 0 -check STRING                               -default {}       -desc {Name of the package being tested. Used for display purposes with xUnit plugin}] \
		[list -arg -trace_file   -mand 0 -check STRING                               -default {}       -desc {Trace implicit proc calls for coverage analysis}] \
		[list -arg -trace_auto   -mand 0 -check BOOL                                 -default 1        -desc {Output trace file when writing junit XML}] \
		[list -arg -properties   -mand 0 -check NVPAIRS                              -default {}       -desc {List of suuite wide properties (name/value) pairs}] \
		[list -arg -output       -mand 0 -check STRING                               -default {stdout} -desc {XML output file}] \
		[list -arg -test_include -mand 0 -check STRING  -default_cfg TEST_INCLUDE    -default {ALL}    -desc {Include specific tests based on regexp}] \
		[list -arg -enabled      -mand 0 -check BOOL                                 -default 1        -desc {Enable all tests}] \
		[list -arg -abort_limit  -mand 0  -check UINT                                -default 0      -desc {Limit on number of errors before bailing out - 0 means run test to completion}] \
		[list -arg -log_prefix   -mand 0 -check BOOL    -default_cfg UNIT_LOG_PREFIX -default 1        -desc {Enable log prefixing}] \
	] \
	-body {
		variable CFG
		variable COVERAGE

		# Create unit testing coverage dictionary
		set COVERAGE [dict create]

		set CFG(name)           $ARGS(-name)
		set CFG(package)        $ARGS(-package)
		set CFG(trace_file)     $ARGS(-trace_file)
		set CFG(trace_auto)     $ARGS(-trace_auto)
		set CFG(output)         $ARGS(-output)
		set CFG(properties)     $ARGS(-properties)
		set CFG(test_include)   $ARGS(-test_include)
		set CFG(enabled)        $ARGS(-enabled)
		set CFG(log_prefix)     $ARGS(-log_prefix)
		set CFG(abort_limit)    $ARGS(-abort_limit)
		set CFG(dependency_dir) "target/dependency"

		# If the name isn't explicitly set assume we are a script
		if {$CFG(name) == {}} {
			set CFG(name) [format "script-%s" [file rootname [file tail [info script]]]]
		}

		# Pull the dependency dir from the shell script
		# This approach is semi-hacky though would require changes to all tests otherwise
		if {[info exists ::env(DEPENDENCY_DIR)]} {
			set CFG(dependency_dir) $::env(DEPENDENCY_DIR)
		}

		# Add proc tracing for all procs registered via core::args
		# TODO - Adding handling for all procs?
		if {$CFG(trace_file) != {}} {
			foreach ns [core::args::get_ns] {
				foreach proc [lindex [core::args::dump_ns "$ns,procs_all"] 1] {
					trace add execution $proc {enter} core::unit::tracer
				}
			}
		}

		core::log::xwrite -msg {------------- Unit testing framework configuration ------------- } -colour green
		foreach name [lsort [array name CFG]] {
			core::log::xwrite -msg {[format "%-15s" $name] $CFG($name)}
		}
		core::log::xwrite -msg {------------- Unit testing framework configuration ------------- } -colour green
	}

# Set a property
core::args::register \
	-proc_name core::unit::get_cfg \
	-desc {Get unit testing configuration} \
	-args [list \
		[list -arg -name    -mand 1 -check ASCII             -desc {env name}] \
		[list -arg -default -mand 0 -check ANY   -default {} -desc {env default}] \
	] \
	-body {
		variable CFG

		set name $ARGS(-name)

		if {[info exists CFG($name)]} {
			return $CFG($name)
		}

		return $ARGS(-default)
	}

# Set a property
core::args::register \
	-proc_name core::unit::set_property \
	-desc {Set a unit test property} \
	-args [list \
		[list -arg -name   -mand 1 -check ASCII -desc {Property name}] \
		[list -arg -value  -mand 1 -check ANY   -desc {Property value}] \
	] \
	-body {
		variable CFG

		dict set CFG(properties) $ARGS(-name) $ARGS(-value)

		core::log::write INFO {Adding property $ARGS(-name) ($ARGS(-value))}
	}

core::args::register \
	-proc_name core::unit::log_test \
	-args [list \
		[list -arg -type   -mand 0 -check {ENUM -args {BEGIN END}}     -default END    -desc {Beginning or end of test}] \
		[list -arg -status -mand 0 -check {ENUM -args {PASSED FAILED}} -default {}     -desc {Status of test}] \
		[list -arg -error  -mand 0 -check ANY                          -default {}     -desc {Error information}] \
	] \
	-body {
		variable LOG
		variable CFG

		set suite     $LOG(current_suite)
		set name      $LOG(current_test)
		set classname $LOG(current_classname)
		set test_no   $LOG($suite,test,$name,test_no)

		set test_info [format "Suite %s : Test %s (%s)" \
			$suite \
			$name \
			$classname]

		if {$ARGS(-type) == {BEGIN}} {

			if {$CFG(log_prefix)} {
				core::log::set_prefix "UNIT-$suite-$test_no"
			}

			core::log::xwrite \
				-msg       {UNIT BEGIN ($test_no) $test_info} \
				-ns_prefix 0 \
				-colour    white
		}

		if {$ARGS(-status) == {PASSED}} {
			set colour      green
			set error_level INFO
			set flag        $ARGS(-status)
		} elseif {$ARGS(-status) == {FAILED}} {
			set colour      red
			set error_level ERROR
			set flag        [format "%s %s" $ARGS(-status) $ARGS(-error)]
			incr LOG($suite,failures)
		}

		if {$ARGS(-type) == {END}} {
			core::log::xwrite \
				-sym_level  $error_level \
				-msg        {UNIT END ($test_no)\t$flag}  \
				-ns_prefix  0 \
				-colour     $colour

			core::log::xwrite \
				-sym_level  $error_level \
				-msg        {UNIT END ($test_no) $test_info} \
				-ns_prefix  0 \
				-colour     $colour

			if {$CFG(log_prefix)} {
				core::log::set_prefix "UNIT-$suite"
			}
		}
	}

# Add trace information to dictionary
proc core::unit::tracer args {
	variable COVERAGE

	set command_list [lindex $args 0]

	# Establish the fully qualified namespace
	set proc [namespace which [lindex $command_list 0]]

	if {$proc == {}} {
		set proc [format "%s::%s" [uplevel [list namespace current]] [lindex $command_list 0]]
	}

	# Strip leading namespace qualifier
	regexp {^::(.+)$} $proc all proc

	if {![dict exists $COVERAGE $proc implicit_count]} {
		dict set COVERAGE $proc implicit_count 1
	} else {
		dict set COVERAGE $proc implicit_count \
			[expr {[dict get $COVERAGE $proc implicit_count] + 1}]
	}
}

# Get a unique key for the suite or test scope
core::args::register \
	-proc_name core::unit::get_key \
	-args [list \
		[list -arg -scope -mand 0 -check ASCII -default {} -desc {Key scope (suite | test)}] \
	] \
	-body {
		variable LOG
		switch -- $ARGS(-scope) {
			global {
				return global
			}
			suite {
				set suite $LOG(current_suite)

				if {$suite != {}} {
					return $LOG($suite,key)
				}
			}
			test {
				set suite $LOG(current_suite)
				set test  $LOG(current_test)
				if {$suite != {} && $test != {}} {
					return $LOG($suite,test,$test,key)
				}
			}
		}

		return {}
	}

# Initialises a test suite.
#
# @param -name the name of this test suite (mandatory)
# @param -setup Execute setup code per test
# @param -cleanup Execute cleanup code per test
# @param -properties N/V pair list
# @param -unset_override Unset all stub overrides for the current suite scope
#
core::args::register \
	-proc_name core::unit::testsuite \
	-args [list \
		[list -arg -name           -mand 1 -check ASCII                  -desc {Name of the test suite}] \
		[list -arg -package        -mand 0 -check STRING     -default {} -desc {Name of the package being tested. Used for display purposes with xUnit plugin}] \
		[list -arg -setup          -mand 0 -check ANY        -default {} -desc {Suite setup callback to be applied across all tests}] \
		[list -arg -cleanup        -mand 0 -check ANY        -default {} -desc {Suite cleanup callback}] \
		[list -arg -properties     -mand 0 -check NVPAIRS    -default {} -desc {List of properties (name/value) pairs}] \
		[list -arg -output         -mand 0 -check DEPRECATED -default {} -desc {Deprecated: Set on initialisation}] \
		[list -arg -unset_override -mand 0 -check BOOL       -default 1  -desc {Unset stubbed proc overrides set at the suite scope level}] \
	] \
	-body {
		variable LOG
		variable CFG

		set name    $ARGS(-name)
		set setup   $ARGS(-setup)
		set package $ARGS(-package)

		if {!$CFG(enabled)} {
			core::log::xwrite -msg {$CFG(name) DISABLED} -colour red
			return
		}

		# In case we ever let there be more than one test suite at once...
		if {[lsearch -exact $LOG(testsuites) $name] > -1} {
			error "Test suite '$name' already exists"
		}

		if {$CFG(log_prefix)} {
			core::log::set_prefix "UNIT-$name"
		}

		set properties [concat $CFG(properties) $ARGS(-properties)]

		# Unset previous suite level overrides
		if {$ARGS(-unset_override)} {
			core::stub::unset_scope -scope_key $LOG(current_suite_key)
		}

		# Fall back to the package registered on initialisation
		if {$package == {}} {
			set package $CFG(package)
		}

		lappend LOG(testsuites) $name

		set LOG($name,test_no)    0
		set LOG($name,time)       0
		set LOG($name,tests)      [list]
		set LOG($name,errors)     0
		set LOG($name,failures)   0
		set LOG($name,setup)      $setup
		set LOG($name,package)    $package
		set LOG($name,cleanup)    $ARGS(-cleanup)
		set LOG($name,properties) $properties
		set LOG($name,key)        [format "suite%d" [llength $LOG(testsuites)]]

		set LOG(current_suite)     $name
		set LOG(current_suite_key) $LOG($name,key)

		core::xml::init
	}

# Runs a test and records the output to be written out later.
#
# @param -suite Name of the current suite
# @param -name the name of the test to be run
# @classname - Proc being tested
# @param -setup a script/command to be run to initialise this test
# @param -body a script/command which runs this test
# @param -cleanup a script/command to be run to clean up after this test
# @param -unset_override Unset all stub overrides for the current test scope
# @param -publish Capture the result of the test in the junit output
# @param -return
core::args::register \
	-proc_name core::unit::test \
	-args [list \
		[list -arg -enabled        -mand 0 -check BOOL    -default 1   -desc {Should the test be run (useful for disabling)}] \
		[list -arg -suite          -mand 0 -check STRING  -default {}  -desc {Name of the test suite}] \
		[list -arg -name           -mand 1 -check STRING               -desc {Name of the test}] \
		[list -arg -classname      -mand 0 -check STRING  -default {}  -desc {TCL procedure name}] \
		[list -arg -package        -mand 0 -check STRING  -default {}  -desc {Name of the package being tested. Used for display purposes with xUnit plugin}] \
		[list -arg -body           -mand 0 -check ANY                  -desc {TCL to execute}] \
		[list -arg -setup          -mand 0 -check ANY                  -desc {Test setup callback}] \
		[list -arg -cleanup        -mand 0 -check ANY                  -desc {Test cleanup callback}] \
		[list -arg -unset_override -mand 0 -check BOOL    -default 1   -desc {Unset stubbed proc overrides set at the test scope level}] \
		[list -arg -publish        -mand 0 -check BOOL    -default 1   -desc {Capture the result of the test in the junit output}] \
		[list -arg -args           -mand 0 -check ASCII   -default {}  -desc {name value pair variables to set in the test scope}] \
	] \
	-body {
		variable LOG
		variable CFG

		set suite     $LOG(current_suite)
		set classname {}

		set suite     $ARGS(-suite)
		set name      $ARGS(-name)
		set classname $ARGS(-classname)
		set test_args $ARGS(-args)
		set publish   $ARGS(-publish)
		set package   $ARGS(-package)

		if {!$CFG(enabled)} {
			core::log::xwrite -msg {$CFG(name) DISABLED} -colour red
			return
		}

		if {!$ARGS(-enabled)} {
			core::log::xwrite -msg {$suite - $name DISABLED} -colour red
			return
		}

		if {$CFG(test_include) != {ALL} && ![regexp $CFG(test_include) \"$name\"]} {
			core::log::xwrite -msg {$suite - $name SKIPPING (include $CFG(test_include))} -colour red
			return
		}

		if {$suite == {}} {
			set suite $LOG(current_suite)
		}

		if {[lsearch -exact $LOG(testsuites) $suite] == -1} {
			error "Test suite $suite does not exist"
		}

		if {[lsearch -exact $LOG($suite,tests) $name] != -1} {
			error "Test $name already exists"
		}

		# Fall back to the package registered at the suite level
		if {$package == {}} {
			set package $LOG($suite,package)
		}

		set suite_key $LOG($suite,key)

		lappend LOG($suite,tests) $name

		set suite_key $LOG($suite,key)
		set test_no   $LOG($suite,test_no)
		incr          LOG($suite,test_no)
		set test_key  [format "%s-test%d" \
			$suite_key \
			[llength $LOG($suite,tests)]]

		set LOG(current_suite)               $suite
		set LOG(current_test)                $name
		set LOG(current_classname)           $classname
		set LOG($suite,test,$name,errors)    [list]
		set LOG($suite,test,$name,key)       $test_key
		set LOG($suite,test,$name,classname) $classname
		set LOG($suite,test,$name,package)   $package
		set LOG($suite,test,$name,publish)   $publish
		set LOG($suite,test,$name,test_no)   $test_no

		set t0 [clock clicks]

		log_test -type BEGIN

		set suite_setup_def   {}
		set suite_cleanup_def {}
		set test_setup_def    {}
		set test_cleanup_def  {}

		if {$LOG($suite,setup) != {}} {
			set suite_setup_def [subst -nocommands {
				if {[catch {$LOG($suite,setup)} err]} {
					log_test -status FAILED -error "Suite setup ERROR \n\$::errorInfo"

					error "Suite setup failed \$err" \$::errorInfo setup
				}
			}]
		}

		if {$ARGS(-setup) != {}} {
			set test_setup_def [subst -nocommands {
				if {[catch {$ARGS(-setup)} err]} {
					# Ensure we unset the test before we error
					if {$ARGS(-unset_override)} {
						core::stub::unset_scope -scope_key $test_key
					}

					log_test -status FAILED -error "Test setup ERROR \n\$::errorInfo"

					error "Test setup failed \$err" \$::errorInfo setup
				}
			}]
		}

		if {$ARGS(-cleanup) != {}} {
			set test_cleanup_def [subst -nocommands {
				if {[catch {$ARGS(-cleanup)} err]} {
					# Ensure we unset the test before we error
					if {$ARGS(-unset_override)} {
						core::stub::unset_scope -scope_key $test_key
					}

					log_test -status FAILED -error "Test cleanup ERROR \n\$::errorInfo"

					error "Test cleanup failed \$err" \$::errorInfo cleanup
				}
			}]
		}

		if {$LOG($suite,cleanup) != {}} {
			set suite_cleanup_def [subst -nocommands {
				if {[catch {$LOG($suite,cleanup)} err]} {
					# Ensure we unset the test before we error
					if {$ARGS(-unset_override)} {
						core::stub::unset_scope -scope_key $test_key
					}

					log_test -status FAILED -error "Suite cleanup ERROR \n\$::errorInfo"

					error "Suite cleanup failed \$err" \$::errorInfo cleanup
				}
			}]
		}

		# Setup the proc args
		set arg_def [list]
		foreach {n v} $test_args {
			lappend arg_def "set $n [list $v]"
		}

		set arg_def [join $arg_def \n]

		# Define sandboxed test proc
		set body [subst -nocommands {
			$arg_def

			# Run the suite setup
			$suite_setup_def

			# Execute the test setup
			$test_setup_def

			# Execute the body of the test
			if {[set c [catch {$ARGS(-body)} err]]} {
				switch -exact -- \$c {
					1 {
						# Ensure we unset the test before we error
						if {$ARGS(-unset_override)} {
							core::stub::unset_scope -scope_key $test_key
						}

						set test_err   \$err
						set test_stack \$::errorInfo

						log_test \
							-status FAILED -error "Test ERROR \$test_err\n\$test_stack"

						# Execute the test cleanup
						$test_cleanup_def

						# Execute the suite cleanup
						$suite_cleanup_def

						error "Test ERROR \$test_err" \$test_stack body
					}
				}
			}

			# Execute the test cleanup
			$test_cleanup_def

			# Unset test level overrides
			if {$ARGS(-unset_override)} {
				core::stub::unset_scope -scope_key $test_key
			}

			# Execute the suite cleanup
			$suite_cleanup_def
		}]

		proc ::core::unit::_run_test args $body

		# Run the test
		if {[catch {_run_test} err]} {

			lappend LOG($suite,test,$name,errors) \
				$::errorCode \
				$err \
				$::errorInfo

			# Only record the failure if we are publishingZ
			if {$publish} {
				incr LOG($suite,errors)
			}
		}

		set t1 [clock clicks]
		set total_time [expr {($t1 - $t0) / 1000000.0}]

		set LOG($suite,test,$name,time) [format "%f" $total_time]
		set LOG($suite,time)            [expr {$LOG($suite,time) + $total_time}]

		if {$LOG($suite,test,$name,errors) == {}} {
			log_test -status PASSED
		} elseif {$CFG(abort_limit) > 0 && $LOG($suite,errors) >= $CFG(abort_limit)} {
			_log_fail_details $suite

			core::log::xwrite -sym_level CRITICAL -colour red -msg {**********************************************************************************************************}
			core::log::xwrite -sym_level CRITICAL -colour red -msg {**  Aborting as the number of errors has reached the -abort_limit setting of $CFG(abort_limit)}
			core::log::xwrite -sym_level CRITICAL -colour red -msg {**********************************************************************************************************}
			exit 1
		}
	}

# Write junit XML to the given file.
#
# @param -output the output file to write to
#
core::args::register \
	-proc_name core::unit::write \
	-args [list \
		[list -arg -output -mand 0 -check STRING  -default {}  -desc {Output file name}] \
	] \
	-body {
		variable CFG
		variable LOG

		set suite  $LOG(current_suite)
		set output $ARGS(-output)

		if {!$CFG(enabled)} {
			core::log::xwrite -msg {$CFG(name) DISABLED} -colour red
			return
		}

		if {$output == {}} {
			set output $CFG(output)
		}

		set doc  [dom createDocument testsuites]
		set root [$doc documentElement]

		foreach suite $LOG(testsuites) {

			set xml_suite [core::xml::add_element -node $root -name testsuite]

			core::xml::add_attribute -node $xml_suite -name name      -value $suite
			core::xml::add_attribute -node $xml_suite -name tests     -value [llength $LOG($suite,tests)]
			core::xml::add_attribute -node $xml_suite -name errors    -value $LOG($suite,errors)
			core::xml::add_attribute -node $xml_suite -name failures  -value $LOG($suite,failures)
			core::xml::add_attribute -node $xml_suite -name timestamp -value [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
			core::xml::add_attribute -node $xml_suite -name hostname  -value [info hostname]

			set properties [core::xml::add_element -node $xml_suite -name properties]
			foreach {name value} $LOG($suite,properties) {
				set property [core::xml::add_element -node $properties -name property]
				core::xml::add_attribute -node $property -name name  -value $name
				core::xml::add_attribute -node $property -name value -value $value
			}

			foreach name $LOG($suite,tests) {

				if {!$LOG($suite,test,$name,publish)} {
					core::log::write DEBUG {Not capturing test $name}
					continue
				}

				set xml_case  [core::xml::add_element -node $xml_suite -name testcase]
				set classname $LOG($suite,test,$name,classname)
				set package   $LOG($suite,test,$name,package)

				# Prepend the package to the classname if its set
				if {$package != {}} {
					set classname [format "%s.%s" $package $classname]
				}

				core::xml::add_attribute -node $xml_case -name name      -value $name
				core::xml::add_attribute -node $xml_case -name classname -value $classname
				core::xml::add_attribute -node $xml_case -name time      -value $LOG($suite,test,$name,time)

				foreach {type message details} $LOG($suite,test,$name,errors) {

					set xml_error [core::xml::add_element -node $xml_case -name error -value $details]

					core::xml::add_attribute -node $xml_error -name type    -value $type
					core::xml::add_attribute -node $xml_error -name message -value $message
				}
			}

			_log_summary $suite
		}

		dump_xml -filename $output -xml [$doc asXML]

		# Write the trace file
		if {$CFG(trace_auto)} {
			write_trace -name $CFG(name)
		}

		core::xml::destroy -doc $doc
	}

# Dump the xml file
core::args::register \
	-proc_name core::unit::dump_xml \
	-args [list \
			[list -arg -filename -mand 1 -check STRING -desc {Output file name}] \
			[list -arg -xml      -mand 1 -check ANY    -desc {Output xml}] \
		] \
	-body {
		variable CFG
		set filename $ARGS(-filename)

		if {![regexp {(?:<<)?(stdout|stderr)(?:>>)?} $filename all filename]} {
			set fd [open $filename w]
		} else {
			set fd $filename
		}

		fconfigure $fd -translation auto
		fconfigure $fd -encoding    utf-8

		core::log::write INFO {Writing utf-8 $filename}

		set str    {<?xml version="1.0" encoding="UTF-8"?>}
		append str $ARGS(-xml)

		puts $fd $str
		close $fd
	}

# Write trace information in XML files
core::args::register \
	-proc_name core::unit::write_trace \
	-args [list \
			[list -arg -name -mand 1 -check ASCII -desc {Test name}] \
		] \
	-body {
		variable CFG
		variable LOG
		variable COVERAGE

		if {$CFG(trace_file) == {}} {
			return
		}

		set name $ARGS(-name)

		# Try and open existing coverage XML
		set ret [core::xml::parse \
			-filename $CFG(trace_file) \
			-strict   0]

		if {[lindex $ret 0] != {OK}} {
			set doc [dom createDocument coverage]
		} else {
			set doc [lindex $ret 1]
		}

		set root [$doc documentElement]

		# Delete any existing suites that share this name
		foreach node [$root selectNodes "//test\[@name='$name'\]"] {
			core::log::write INFO {deleting [$node getAttribute name] [$node getAttribute datetime]}
			$node delete
		}

		set node [core::xml::add_element -node $root -name test]

		$node setAttribute name     $name
		$node setAttribute datetime [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		dict for {name keys} $COVERAGE {
			dict with keys {
				switch -- [lindex $keys 0] {
					implicit_count {
						set xml_proc [core::xml::add_element -node $node -name proc]
						$xml_proc setAttribute name  $name
						$xml_proc setAttribute count $implicit_count
					}
				}
			}
		}

		# Write out the file
		dump_xml -filename $CFG(trace_file) -xml [$doc asXML]

		core::xml::destroy -doc $doc
	}

# Trawl the junit directory, parse the XML files and establish the coverage
core::args::register \
	-proc_name core::unit::get_coverage \
	-args [list \
		[list -arg -unit_dir  -mand 0 -check STRING -default {./}  -desc {Unit XML directory}] \
		[list -arg -ref_count -mand 0 -check BOOL   -default 1     -desc {Retrieve reference count (may take a while)}] \
	] \
	-body {
		variable CFG
		variable LOG
		variable COVERAGE

		set dir $ARGS(-unit_dir)

		# Check the directory exists
		if {![file isdirectory $dir]} {
			error "Directory $dir doesn't exist"
		}

		# Examine all XML junit files under this directory
		foreach path [core::util::find_files -dir $dir -pattern ".*unit-test.*.xml$"] {

			# Parse each unit test and build up an array of coverage information
			set ret [core::xml::parse -filename $path -strict   0]

			if {[lindex $ret 0] != {OK}} {
				core::log::write INFO {Skipping $path [lindex $ret 1]}
				continue
			}

			set doc [lindex $ret 1]
			set root [$doc documentElement]

			foreach testcase [$root selectNodes {//testsuite/testcase}] {
				set name      [$testcase getAttribute name      {}]
				set classname [$testcase getAttribute classname {}]

				# Check we don't have blank classname
				if {$classname == {}} {
					core::log::write ERROR {Found blank classname [$testcase asXML]}
					continue
				}

				# Remove the prepended package name from the classname
				regexp {^([[:alnum:]_:]+)\.(.*)$} $classname all package classname

				if {![dict exists $COVERAGE $classname explicit_count]} {
					dict set COVERAGE $classname explicit_count 1
				} else {
					dict set COVERAGE $classname explicit_count \
						[expr {[dict get $COVERAGE $classname explicit_count] + 1}]
				}
			}

			# Cleanup the junit XML doc
			core::xml::destroy -doc $doc
		}

		# Handle colour coding of procs
		#
		# Colours Red -> Green FF0000 -> 00FF00 multiple of 17 (0 - 255)
		# Establish a percentage using explicit, implicit and referenced and complexity
		# Rank from 0% to 100% and apply css .coverage-percent-<percentage>
		# https://jira.openbet.com/browse/OBCORE-83

		foreach ns [core::args::get_ns] {
			set complexity [list]
			set proc_list  [lindex [core::args::dump_ns $ns,procs_pub] 1]
			foreach proc $proc_list {
				lappend complexity [concat $proc [proc_complexity -namespace $ns -proc $proc]]
			}

			foreach l [lsort -decreasing -integer -index 3 $complexity] {
				set proc [lindex $l 0]

				dict set COVERAGE $proc arg_count   [lindex $l 1]
				dict set COVERAGE $proc body_length [lindex $l 2]
				dict set COVERAGE $proc complexity  [lindex $l 3]
			}

			dict set COVERAGE $ns procs_ordered \
				[lsort -decreasing -command _complexity_sort $proc_list]

			if {$ARGS(-ref_count)} {
				# Work out the number of references per proc
				foreach proc $proc_list {
					dict set COVERAGE $proc ref_count [core::unit::proc_references \
						-namespaces [core::args::get_ns] \
						-proc       $proc]
				}
			}
		}

		# If we have implicit proc call tracing enabled we should retrieve
		# the trace information from XML file
		set ret [core::xml::parse \
			-filename $CFG(trace_file) \
			-strict   0]

		if {[lindex $ret 0] != {OK}} {
			return $COVERAGE
		}

		set doc  [lindex $ret 1]
		set root [$doc documentElement]
		foreach proc_node [$root selectNodes {//coverage/test/proc}] {
			set classname [$proc_node getAttribute name]
			set count     [$proc_node getAttribute count]

			# Strip leading namespace qualifier
			regexp {^::(.+)$} $classname all classname

			if {![dict exists $COVERAGE $classname implicit_count]} {
				dict set COVERAGE $classname implicit_count $count
			} else {
				dict set COVERAGE $classname implicit_count \
					[expr {[dict get $COVERAGE $classname implicit_count] + $count}]
			}
		}

		# Cleanup the implicit trace XML doc
		core::xml::destroy -doc $doc

		return $COVERAGE
	}

# Establish the complexity of a proc based on the
# length of the proc and the number of arguments
core::args::register \
	-proc_name core::unit::proc_complexity \
	-args [list \
		[list -arg -namespace -mand 1 -check STRING -desc {Proc namespace}] \
		[list -arg -proc      -mand 1 -check STRING -desc {Proc name}] \
	] \
	-body {
		set ns        $ARGS(-namespace)
		set proc      $ARGS(-proc)

		# Get the argument list for the proc
		set arg_list  [lindex [core::args::dump "$ns,$proc,args"] 1]

		set body [_proc_body $proc]

		# Work out the number of lines
		set complexity  0
		set body_length [llength [split $body \n]]
		set arg_length  [llength $arg_list]

		if {$arg_length == 0} {
			set arg_length 1
		}

		if {$body_length} {
			set complexity [expr {$arg_length * $body_length}]
		}

		return [list $arg_length $body_length $complexity]
	}

# Establish the number of references within a list of namespaces
core::args::register \
	-proc_name core::unit::proc_references \
	-args [list \
		[list -arg -namespaces -mand 1 -check STRING -desc {List of namespaces to check}] \
		[list -arg -proc       -mand 1 -check STRING -desc {Fully qualified proc name}] \
	] \
	-body {
		set check_proc  $ARGS(-proc)
		set total_count 0

		# Build the regsub, note we are only
		# using this to establish the count
		set local_name [namespace tail $check_proc]
		set origin     [namespace origin $check_proc]

		# Build a regular expression that handles
		# 1. Fully qualified proc with and without square brackets
		# 2. Local proc call with and without square brackets
		# 3. Evaluated proc call with and without square brackets

		# Create a different regexp if we aren't looking at a procs own namespace
		# Also ignore certain duplicates handled by core::args and logging
		set loose_re [format {(?:\[)?.*(?:%s)?(?:::)?(%s).*(?:\])?} $check_proc $local_name]
		set tight_re [format {(?:\[)?.*(%s).*(?:\])?} $check_proc]

		# Loop over all procs in the namespace and search the body
		foreach ns $ARGS(-namespaces) {

			if {$ns == $origin} {
				set re $loose_re
			} else {
				set re $tight_re
			}

			foreach proc [info commands ::${ns}::*] {

				set body  [_proc_body $proc]
				set count [regsub -all -line -- $re $body {} {}]

				if {$count != {}} {
					incr total_count $count
				}

				core::log::write DEV {$ns $proc checking $ns $count references ($re)}
			}
		}

		core::log::write DEBUG {$check_proc total count $total_count}

		return $total_count
	}

# Return the body of a proc minus comments and blank lines
proc core::unit::_proc_body {proc} {

	# Get the proc body
	if {[catch {
		set body [info body $proc]
	} msg]} {
		core::log::write DEV {Unable to introspect $proc}
		return {}
	}

	# Strip the log line if we aren't in the log proc
	if {$proc != {core::log::write}} {
		regsub -all -line -- {(.*core::log::write.*)} $body "" body
	}

	# Strip white space
	regsub -all {\n+} $body "\n" body
	regsub {\n$}      $body {} body

	# Strip comments
	regsub -all {#.*?\n} $body "" body

	return $body
}

# Proc complexity dictionary sort command
proc core::unit::_complexity_sort {a b} {
	variable COVERAGE

	set a_complexity [dict get $COVERAGE $a complexity]
	set b_complexity [dict get $COVERAGE $b complexity]
	if {$a_complexity < $b_complexity} {
		return -1
	} elseif {$a_complexity > $b_complexity} {
		return 1
	}

	return 0
}

proc core::unit::_log_fail_details {suite} {
	variable LOG

	core::log::xwrite -ns_prefix  0 -colour red  -sym_level WARNING -msg {*******************************************************************}
	core::log::xwrite -ns_prefix  0 -colour red  -sym_level WARNING -msg {**  Errors for suite: $suite}
	core::log::xwrite -ns_prefix  0 -colour red  -sym_level WARNING -msg {**}

	foreach name $LOG($suite,tests) {

			if {!$LOG($suite,test,$name,publish)} {
				core::log::write DEBUG {Not capturing test $name}
				continue
			}

			set classname $LOG($suite,test,$name,classname)
			set package   $LOG($suite,test,$name,package)
			set test_no   $LOG($suite,test,$name,test_no)
			# Prepend the package to the classname if its set
			if {$package != {}} {
				set classname [format "%s.%s" $package $classname]
			}


			foreach {type message details} $LOG($suite,test,$name,errors) {
				core::log::xwrite -ns_prefix  0 -sym_level ERROR -colour red -msg {**  ${suite}-${test_no} FAILED: $classname: $name}
				core::log::xwrite -ns_prefix  0 -sym_level ERROR -colour red -msg {**  ${suite}-${test_no}     ==> $message}
			}
		}
	core::log::xwrite -ns_prefix  0 -colour red  -sym_level WARNING -msg {**}
	core::log::xwrite -ns_prefix  0 -colour red  -sym_level WARNING -msg {*******************************************************************}
}

# This procs writes overview of passed/failed tests. It makes dev easier as
# one can immediately see if any tests failed when running the tests with
# log output to stdout.
proc core::unit::_log_summary {suite} {
	variable LOG

	set number_of_tests  [llength $LOG($suite,tests)]
	set column_width     [expr {58 - [string length $suite]}]
	set whitespace_column [string repeat " " $column_width]

	if {$LOG($suite,errors) == 0 && $LOG($suite,failures) == 0} {
		core::log::xwrite \
			-sym_level  {INFO} \
			-msg        {Suite: $suite: $whitespace_column passed $number_of_tests tests}  \
			-ns_prefix  0 \
			-colour     white
	} else {
		core::log::xwrite \
			-sym_level  {WARNING} \
			-msg        {Suite: $suite: $whitespace_column\
							errors: $LOG($suite,errors),\
							fails: $LOG($suite,failures)}  \
			-ns_prefix  0 \
			-colour     red

		_log_fail_details $suite

	}
}
