#!/usr/bin/tclsh8.5
#
# $Header$
#

# Build a test file for stubbing 

variable CFG

load libOT_Tcl.so

# Add the core tcl path
set ::xtn tcl

# Sort out the auto_path for core packages
regsub "[pwd]/" [file dirname [file normalize $argv0]] {} path
lappend ::auto_path {*}[file normalize [file join $path "../../tcl"]]

package require core::standalone 1.0

set CFG(fname)        [file rootname [file tail [info script]]]
set CFG(trace_file)   [clock format [clock seconds] -format "coverage.%Y%m%d.xml"]
set CFG(dependencies) [list \
	core::unit          1.0 \
	core::util          1.0 \
	core::xml           1.0 \
	core::stub          1.0 \
	core::stub::appserv 1.0 \
]

# Initialise standalone features
core::standalone::init \
	-init_log  1 \
	-init_unit 1 \
	-options [subst {
		-d log_dir      DIR  {.}               "Directory to log"
		-l log_file     FILE {<<stdout>>}      "Log file"
		-t trace_file   FILE $CFG(trace_file)  "Code coverage output file"
		-o output_dir   DIR  {.}               "Directory to write the unit test"
		-u output_file  FILE {}                "Name of the unit test file"
		-n ns_stubs     LIST {}                "List of namespace stubs to pass to core::stub"
		-p package      PKG  {}                "Core package to build unit test against"
		-x dependencies LIST {}                "List of core dependencies {pkg version}"
		-h help         {}                     "Display usage"
	}]


if {[core::standalone::get_config -name output_file] == {}} {
	set CFG(output_file) [format "test-%s.tcl" \
	[string map {:: _} [core::standalone::get_config -name package]]]
}

set CFG(package) [core::standalone::get_config -name package]

if {$CFG(package) == {}} {
	core::log::xwrite -msg {Missing package} -colour red
	puts [core::standalone::usage]
	exit
}

set CFG(ns_stubs)    [core::standalone::get_config -name ns_stubs]
set CFG(version)     [core::util::load_package -package $CFG(package)]

core::log::write INFO {Loaded $CFG(package) v$CFG(version)}

set CFG(dependencies) [concat $CFG(dependencies) \
	[core::standalone::get_config -name dependencies]]

# Setup the header
set header_def [subst {
	variable CFG
	
	load libOT_Tcl.so
	set ::xtn tcl
	
	# Sort out the auto_path for core packages
	regsub "\[pwd\]/" \[file dirname \[file normalize \$argv0\]\] {} path
	lappend ::auto_path {*}\[file normalize \[file join \$path "../../../tcl"\]\]
	
	set CFG(fname)      \[file rootname \[file tail \[info script\]\]\]
	set CFG(trace_file) \[clock format \[clock seconds\] -format "coverage.%Y%m%d.xml"\]
	set CFG(output_file) unit-test-\${CFG(fname)}.xml
	
	package require core::standalone 1.0

	# Initialise standalone features
	core::standalone::init \\
		-init_log  1 \\
		-init_unit 1 \\
		-options \[subst {
			-a auto_path    PATH {}                "Paths to add to the auto_path"
			-d log_dir      DIR  {.}                "Directory to log"
			-l log_file     FILE {<<stdout>>}       "Log file"
			-t trace_file   FILE \$CFG(trace_file)  "Code coverage output file"
			-o output_dir   DIR  {.}                "Directory to write the unit test"
			-u output_file  FILE \$CFG(output_file) "Name of the unit test file"
			-h help         {}                      "Display usage"
		}\] \\
		-packages \[list $CFG(dependencies)\]
		
	set CFG(versions) \[core::util::load_package -package $CFG(package)\]
}]

set stub_def {}
if {[llength $CFG(ns_stubs)]} {
	set stub_def [subst {

		# Initialise stub handling
		core::stub::init
		
		core::stub::define_procs -proc_definition $CFG(ns_stubs)
	}]
}

set ns_def   {}
set proc_def {}
foreach proc [lindex [core::args::dump_ns "$CFG(package),procs_short"] 1] {
	
	# Build arg list
	set proc_ns "${CFG(package)}::${proc}"
	set arg_list [list]
	foreach arg [lindex [core::args::dump "$CFG(package),${proc_ns},args"] 1] {
		set check [lindex [core::args::dump "$CFG(package),${proc_ns},$arg,check"] 1]
		lappend arg_list "[format "%-20s" $arg]  __${check}-PLACEHOLDER__ \\"
	}
	
	set test_name "$proc_ns"
	lappend proc_def [subst {
		core::unit::test \\
			-name      \{$test_name\} \\
			-classname \{$proc_ns\} \\
			-body \{
				set ret \[$proc_ns \\
					[join $arg_list \n\t\t\t\t\t]
				\]
				
				error "Unit test $test_name not implemented"
			\}
	}]
}
	
lappend ns_def [join $proc_def \n\n]

set file_def [subst {
	#
	# \$Header$
	#
	
	# Unit test framework for $CFG(package)
	$header_def
	
	$stub_def
	
	[join $ns_def \n]
	
	core::unit::write
}]

if {$CFG(output_file) == "stdout"} {
	set f stdout
} else {
	set f [open [file join \
		[core::standalone::get_config -name output_dir] \
		$CFG(output_file)]\
		w]
}

puts $f $file_def

close $f
