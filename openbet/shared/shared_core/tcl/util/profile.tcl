##
# Copyright (c) 2007 Orbis Technology Limited. All Rights Reserved.
# core::profile - a simple Tcl profiler to help find CPU hotspots.
#
# Synopsis:
#   package require util_prof
#
# Configuration: (if using core::profile::req_init and core::profile::req_end)
#
#  OB_PROF_FOR_CUST_ID  = <cust_id>
#    Enable profiling only for requests where [ob_login::get cust_id]
#    matches the given <cust_id>. NB- this will only work if
#    you call the ob_login package before the core::profile package.
#
# Procedures:
#
#   core::profile::init     - One-time initialisation.
#   core::profile::enable   - Start gathering statistics.
#   core::profile::disable  - Stop gathering statistics.
#   core::profile::reset    - Reset all statistics.
#   core::profile::write    - Dump statistics to a channel.
#   core::profile::analyse  - Analyse saved dumped statistics.
#   core::profile::req_init - Call from your req_init.
#   core::profile::req_end  - Call from your req_end.
#
# Bugs:
#   May not cope with:
#     - really weird auto-generated / auto-loading stuff
#     - procedures brought into existence in unusual ways
#
##
set pkg_version 1.0
package provide core::profile $pkg_version

package require core::check 1.0
package require core::args  1.0
package require core::log   1.0

core::args::register_ns \
	-namespace core::profile \
	-version   $pkg_version \
	-dependent [list core::check core::args] \
	-docs      util/profile.xml

namespace eval ::core::profile {

	variable CFG
	variable ENABLED
	variable TIMING_BODY
	variable BUFFER
	variable TOTALS
	variable FLOW
	variable GLOB_PROTECT
	variable SCARY_PROCS
	variable SCARY_NAMESPACES

	set ENABLED 0
	set GLOB_PROTECT [list * \\* ? \\? \[ \\\[ \] \\\]]
	set SCARY_PROCS [list \
	  ::auto_load_index ::unknown ::auto_import ::auto_execok \
	  ::auto_qualify ::auto_load ::history ::tclLog \
	  ::bgError ::clock ::asGetTime \
	]
	set SCARY_NAMESPACES [list \
	  ::tcl ::core::profile msgcat\
	]
}


# One-time initialisation.
core::args::register \
	-proc_name core::profile::init \
	-desc      {Initialise proc profiling} \
	-args [list \
		[list -arg -profile_cust_id  -mand 0 -check UINT  -default_cfg  OB_PROF_FOR_CUST_ID -default -999        -desc {Cust id profiling}] \
		[list -arg -profile_dir      -mand 0 -check ASCII                                   -default {profiler}  -desc {Directory to drop the profile files}] \
		[list -arg -enable_colours   -mand 0 -check BOOL                                    -default 0           -desc {Enable coloring}] \
		[list -arg -colours          -mand 0 -check ASCII -default_cfg  OB_PROF_COLOURS     -default {}          -desc {Colour scheme}] \
	] \
	-body {
		variable CFG

		::core::profile::reset

		set CFG(profile_cust_id) $ARGS(-profile_cust_id)
		set CFG(profile_dir)     $ARGS(-profile_dir)
		set CFG(enable_colours)  $ARGS(-enable_colours)
		set CFG(colours)         $ARGS(-colours)

		if {$CFG(enable_colours) && $CFG(colours) == {}} {
			set CFG(colours) {
				core::db         green
				core::request    blue
				core::controller cyan
				core::check      yellow
				core::           white
			}
		}

		if { ![llength [info commands ::asGetTime]] } {
			proc ::asGetTime args { return 0.0 }
		}

		return
	}

# Reset all profiler statistics.
core::args::register \
	-proc_name core::profile::reset \
	-desc      {Reset all profiler statistics.} \
	-body {
		variable BUFFER
		variable TOTALS
		variable FLOW

		catch {unset BUFFER}
		set BUFFER [list]

		catch {unset TOTALS}
		set TOTALS(<Tcl>,count)         1
		set TOTALS(<Tcl>,callees,clk)   0.0
		set TOTALS(<Tcl>,callees,usr)   0.0
		set TOTALS(<Tcl>,callees,sys)   0.0

		catch {unset FLOW} ; array set FLOW [list]

		return
	}

#
# Turn on profiling.
# Statistics will start to be gathered about every procedure call.
# NB - this call may be fairly expensive since it needs to instrument
# every procedure.
#
core::args::register \
	-proc_name core::profile::enable \
	-args [list \
		[list -arg -reset -mand 0 -check UINT -default 0 -desc {Reset profile statistics}] \
	] \
	-desc {Turn on profiling} \
	-body {
		variable ENABLED
		variable TIMING_BODY

		# No-op.
		if {$ENABLED} {
			return
		}

		if {$ARGS(-reset)} {
			reset
		}

		# For every procedure that is currently defined ...
		set all_procs [_find_procs]
		foreach pname $all_procs {

			# If this procedure already has an accompanying xxx_profile_orig
			# procedure, then profiling must already be enabled for it.
			if { [llength [info procs [_glob_protect ${pname}_profile_orig]]] } {
				continue
			}

			# Create a timing procedure xxx_profile_timer for this proc if it doesn't
			# already have one.
			if { ![llength [info procs [_glob_protect ${pname}_profile_timer]]] } {
				proc ${pname}_profile_timer args $TIMING_BODY
			}

			# Rename the procedure to xxx_profile_orig, and rename the timing
			# procedure xxx_profile_timer to be the procedure itself.
			rename $pname                 ${pname}_profile_orig
			rename ${pname}_profile_timer $pname

		}

		# Replace the original Tcl "proc" and "rename" commands with our own
		# so that we can instrument any procedures created or renamed after
		# this call.
		_replace_tcl_cmds

		set ENABLED 1
	}

#
# Turn off profiling.
# Statistics will cease to be gathered until core::profile::enable is called.
# NB - this call may be fairly expensive since it de-instruments
# every procedure.
#
core::args::register \
	-proc_name core::profile::disable \
	-desc      {Turn off profiling} \
	-body {
		variable ENABLED

		# No-op.
		if {!$ENABLED} {
			return
		}

		# Restore the original Tcl "proc" and "rename" commands.
		_restore_tcl_cmds

		# For every procedure that is currently defined ...
		set all_procs [_find_procs]
		foreach pname $all_procs {

			# If this procedure doesn't have an accompanying xxx_profile_orig
			# procedure, then profiling must not have been enabled for it.
			if { ![llength [info procs [_glob_protect ${pname}_profile_orig]]] } {
				continue
			}

			# At the moment, the procedure is in fact the timing one.
			# Delete it, and rename the original procedure, xxx_profile_orig,
			# to be the procedure itself.
			rename $pname                ""
			rename ${pname}_profile_orig $pname
		}

		set ENABLED 0
	}

core::args::register \
	-proc_name core::profile::write \
	-desc      {Write the profiling information to file} \
	-args [list \
		[list -arg -disable -mand 0 -check BOOL -default 1 -desc {Disable the profiling}] \
	] \
	-body {
		variable ENABLED
		variable BUFFER
		variable TOTALS
		variable FLOW
		variable CFG

		if {!$ENABLED} {
			return
		}

		# Ensure buffer has been processed.
		_flush

		# Create the directort if it doesn't exist
		if {![file isdirectory $CFG(profile_dir)]} {
			core::log::write INFO {Creating $CFG(profile_dir)}
			file mkdir $CFG(profile_dir)
		}

		set filename [file join $CFG(profile_dir) [format "profile.%s.%s" [OT_MicroTime] [asGetId]]]

		# Write out a dump file.
		if {[catch {
			set fd [core::util::open_file -file $filename -access w]

			# Write out Tcl commands to recreate the TOTALS and FLOW arrays.
			set names [array names TOTALS]
			foreach name $names {
				puts $fd "set TOTALS([list $name]) [list $TOTALS($name)]"
			}

			set names [array names FLOW]
			foreach name $names {
				puts $fd "set FLOW([list $name]) [list $FLOW($name)]"
			}

			close $fd
		} msg]} {
			catch {close $fd}
			core::log::write ERROR {error in req_end: $msg}
		}

		if {$ARGS(-disable)} {
			disable
		}

		return $filename
	}

#
# Call from your req_init.
#
core::args::register \
	-proc_name core::profile::req_init \
	-desc      {Call from your req_init.} \
	-body {
		variable CFG

		global LOGIN_DETAILS

		# Check if we should enable profiling for this request.

		if {[ob_login::is_guest]} {
			set cust_id "unknown"
		} else {
			set cust_id [ob_login::get cust_id]
		}

		if {$cust_id == $CFG(profile_cust_id)} {
			core::log::write INFO {enabling profiling (cust_id is $cust_id)}
			reset
			enable
		} else {
			core::log::write DEBUG {Not enabling profiling (cust_id is $cust_id)}
		}

		return
	}


# Call from your req_end.
core::args::register \
	-proc_name core::profile::req_end \
	-desc      {Call from your req_end} \
	-body {
		write
	}

#
# Analyse the profiler statistics from the saved output of core::profile::dump.
#
# Syntax:
#   core::profile::analyse ?-top <N>? ?-by <stat1,..statN>? ?-flow 0|1?
# where:
#   -top <N>    = show top <N> procedures
#   -by <stats> = order by statistics <stats> (a comma separated subset
#                 of the names below)
#   -flow 0|1   = also show the call flow information
#
# Statistics available are:
#   Name   = Name of procedure (fully-qualified)
#   Calls  = Total number of calls
#   TotClk = Total wallclock time
#   TotUsr = Total CPU time (user space)
#   TotSys = Total CPU time (kernel space)
#   ExtClk = Total wallclock time spent in calls to other procs.
#   ExtUsr = Total CPU time (user space) spent in calls to other procs.
#   ExtSys = Total CPU time (kernel space) spent in calls to other procs.
#   IntClk = Total wallclock time excluding calls to other procs.
#   IntUsr = Total CPU time (user space) excluding calls to other procs.
#   IntSys = Total CPU time (kernel space) excluding calls to other procs.
#
# Returns a human readable string.
#
# FIXME: -flow 1 option not implemented.
#
core::args::register \
	-proc_name core::profile::analyse \
	-args [list \
		[list -arg -filename      -mand 0 -check STRING -default {}                   -desc {Filename to analyse}] \
		[list -arg -topN          -mand 0 -check UINT   -default 0                    -desc {show top <N> procedures}] \
		[list -arg -order_by      -mand 0 -check ANY    -default "TotClk,ExtClk,Name" -desc {Order by statistics <stats> See documentation}] \
		[list -arg -show_flow     -mand 0 -check BOOL   -default 0                    -desc {Show the call flow information}] \
		[list -arg -log           -mand 0 -check BOOL   -default 0                    -desc {Log the data}] \
		[list -arg -disable_write -mand 0 -check BOOL   -default 0                    -desc {Write the file and disable}] \
	] \
	-desc {Turn on profiling} \
	-body {
		variable CFG

		set filename  $ARGS(-filename)
		set topN      $ARGS(-topN)
		set order_by  [split $ARGS(-order_by) ","]
		set show_flow $ARGS(-show_flow)

		array set TOTALS [list]
		array set FLOW   [list]

		# Disable and write out the test. Makes it simpler from the calling code
		if {$ARGS(-disable_write)} {
			set filename [write]
		} elseif {$filename == {}} {
			error "Expecting filename" {} MISSING_ARG
		}

		# The dumped script should re-create the arrays.
		source $filename

		if { ![info exists TOTALS(<Tcl>,callees,clk)] } {
			error "File \"$filename\" does not appear to contain an core::profile::dump"
		}

		# These are the statistics we display for each procedure.
		set stat_names [list Name Calls \
			TotClk TotUsr TotSys \
			ExtClk ExtUsr ExtSys \
			IntClk IntUsr IntSys]

		# We make the total figure for the "root" procedure the same as the time
		# spent in the top-level procs. XXX Is there anything better we can do?

		set TOTALS(<Tcl>,total,clk) $TOTALS(<Tcl>,callees,clk)
		set TOTALS(<Tcl>,total,usr) $TOTALS(<Tcl>,callees,usr)
		set TOTALS(<Tcl>,total,sys) $TOTALS(<Tcl>,callees,sys)

		# For each proc in TOTALS, append its timing data to a big list of lists.

		set timing_data    [list]
		set max_arg_length 0
		set proc_key_names [lsort -dictionary [array names TOTALS "*,total,clk"]]

		foreach proc_key_name $proc_key_names {

			regsub {^(.*),total,clk$} $proc_key_name \\1 pname

			# The stats are in the same order as in stat_names above.
			lappend timing_data [list \
				$pname \
				$TOTALS($pname,count) \
				$TOTALS($pname,total,clk) \
				$TOTALS($pname,total,usr) \
				$TOTALS($pname,total,sys) \
				$TOTALS($pname,callees,clk) \
				$TOTALS($pname,callees,usr) \
				$TOTALS($pname,callees,sys) \
				[expr { $TOTALS($pname,total,clk) - $TOTALS($pname,callees,clk) }] \
				[expr { $TOTALS($pname,total,usr) - $TOTALS($pname,callees,usr) }] \
				[expr { $TOTALS($pname,total,sys) - $TOTALS($pname,callees,sys) }] ]

			if {[string length $pname] > $max_arg_length} {
				set max_arg_length [string length $pname]
			}
		}

		# Sort the timing data by the keys requested.

		for {set i [expr { [llength $order_by] - 1 }]} {$i >= 0} {incr i -1} {
			set stat_name [lindex $order_by $i]
			set stat_idx  [lsearch $stat_names $stat_name]

			if {[lsearch $stat_names $stat_name] < 0 } {
				error "Unknown -order_by option \"$stat_name\""
			}

			if {$stat_name == "Name"} {
				set timing_data [lsort -dictionary -index $stat_idx $timing_data]
			} else {
				set timing_data [lsort -real -index $stat_idx $timing_data]
			}
		}

		# Restrict to the top N if requested.

		if {$topN != ""} {
			set timing_data [lrange $timing_data end-[expr { $topN - 1 }] end]
		}

		# Describe the output.
		set desc ""

		if {$topN == ""} {
			append desc "All procedures"
		} else {
			append desc "Top $topN procedures"
		}

		append desc " by " [join $order_by ", "] ":\n"

		# Build up a big string containing the formatted data.

		set s ""

		append s $desc

		set fmt "%${max_arg_length}s%8s%8s%8s%8s%8s%8s%8s%8s%8s%8s\n"
		append s [eval [list format $fmt] $stat_names]

		set fmt "%${max_arg_length}s%8u%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f\n"
		foreach timing_datum $timing_data {
			append s [eval [list format $fmt] $timing_datum]
		}

		# Now add the flow data (if requested)
		if {$show_flow} {
			# XXX TODO
		}

		if {$ARGS(-log)} {
			foreach line [split $s \n] {
				set match 0
				foreach {re colour} $CFG(colours) {
					if {[regexp $re $line all]} {
						core::log::xwrite -msg {$line} -ns_prefix 0 -colour $colour
						incr match
						break
					}
				}

				if {$match} {
					continue
				}

				core::log::xwrite -msg {$line} -ns_prefix 0
			}
		}

		return $s

	}

##
# Internal - this is the procedure body we use to time procedure calls.
# It should be independent of the procedure being timed, and as fast
# as possible.
##
set ::core::profile::TIMING_BODY {

	# Get the fully-qualified name of this proc and our caller's proc.
	# For top-level procedures, we pretend we were called by "<Tcl>".

	set level [::info level]
	if {$level > 2} {
		set _profile_name [::uplevel 1 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _profile_caller [::uplevel 2 [::list namespace origin [::lindex [::info level 1] 0]]]
	} elseif {$level == 2} {
		set _profile_name [::uplevel 1 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _profile_caller [::uplevel #0 [::list namespace origin [::lindex [::info level 1] 0]]]
	} else {
		set _profile_name [::uplevel #0 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _profile_caller "<Tcl>"
	}

	# Note the time before the real procedure was executed.

	set _profile_clk0 [::clock clicks -millis]
	set _profile_usr0 [::asGetTime -user]
	set _profile_sys0 [::asGetTime -system]

	# Execute the real procedure, which we assume is called xxx_profile_orig,
	# capturing the return value and code.

	::set ret_code [::catch {
		::uplevel 1 [::list ${_profile_name}_profile_orig] $args
	} ret_val]

	# Note the time after the procedure executed.

	::set _profile_clk1 [::clock clicks -millis]
	::set _profile_usr1 [::asGetTime -user]
	::set _profile_sys1 [::asGetTime -system]

	# Append the details to the buffer for later analysis.

	::lappend ::core::profile::BUFFER $_profile_name $_profile_caller
	::lappend ::core::profile::BUFFER $_profile_clk0 $_profile_usr0 $_profile_sys0
	::lappend ::core::profile::BUFFER $_profile_clk1 $_profile_usr1 $_profile_sys1

	# Return whatever the real procedure returned.

	::return -code $ret_code $ret_val
}

#
# Internal - add the data in the buffer to the totals, then clear the buffer.
#
proc ::core::profile::_flush {} {

	variable BUFFER
	variable TOTALS
	variable FLOW

	# For each procedure call recorded in the buffer ...
	foreach [list name caller clk0 usr0 sys0 clk1 usr1 sys1] $BUFFER {

		# Take into account the renaming of procedures.
		regsub {(.*)_profile_orig$} $caller \\1 caller

		# Record who called who.
		if { ![info exists FLOW($caller,$name,count)] } {
			set FLOW($caller,$name,count) 1
			lappend FLOW($caller,callees) $name
			lappend FLOW($name,callers) $caller
		} else {
			incr FLOW($caller,$name,count)
		}

		# Do the math to get the time taken
		set clk [expr { ($clk1 - $clk0) * 0.001 }]
		set usr [expr { $usr1 - $usr0 }]
		set sys [expr { $sys1 - $sys0 }]

		# Create some blank totals for this procedure name if needed.
		# Note that the callees figures could already be there.
		if { ![info exists TOTALS($name,count)] } {
			set TOTALS($name,count)     0
			set TOTALS($name,total,clk) 0.0
			set TOTALS($name,total,usr) 0.0
			set TOTALS($name,total,sys) 0.0
		}

		if { ![info exists TOTALS($name,callees,clk)] } {
			set TOTALS($name,callees,clk) 0.0
			set TOTALS($name,callees,usr) 0.0
			set TOTALS($name,callees,sys) 0.0
		}

		# Increase the totals for this procedure name.
		incr TOTALS($name,count)
		set TOTALS($name,total,clk) [expr { $TOTALS($name,total,clk) + $clk }]
		set TOTALS($name,total,usr) [expr { $TOTALS($name,total,usr) + $usr }]
		set TOTALS($name,total,sys) [expr { $TOTALS($name,total,sys) + $sys }]

		# Increase the caller's callees totals.
		if { ![info exists TOTALS($caller,callees,clk)] } {
			set TOTALS($caller,callees,clk) 0.0
			set TOTALS($caller,callees,usr) 0.0
			set TOTALS($caller,callees,sys) 0.0
		}

		set TOTALS($caller,callees,clk) \
			[expr { $TOTALS($caller,callees,clk) + $clk }]
		set TOTALS($caller,callees,usr) \
			[expr { $TOTALS($caller,callees,usr) + $usr }]
		set TOTALS($caller,callees,sys) \
			[expr { $TOTALS($caller,callees,sys) + $sys }]
	}

	set BUFFER [list]

	return
}


#
# Internal - find the names of all procedures that are currently defined.
# We exclude those ending in "_profile_orig" or "_profile_timer", as well
# as some internal ones.
# The names returned will be fully qualified with their namespace.
#
proc ::core::profile::_find_procs { {ns ""} } {

	variable SCARY_PROCS
	variable SCARY_NAMESPACES

	# Find the procedures in this namespace.

	set procs [info procs "${ns}::*"]
	set keep_procs [list]
	foreach pname $procs {
		if { [string match "*_profile_orig" $pname] || \
			[string match "*_profile_timer" $pname] || \
			[lsearch -exact $SCARY_PROCS $pname] != -1 } {
				continue
		}
		lappend keep_procs $pname
	}

	set procs $keep_procs

	# Find the namespaces below this namespace, and recurse over them,
	# adding their procedures to our list.

	if {$ns == ""} {
		set child_namepaces [namespace children "::"]
	} else {
		set child_namepaces [namespace children $ns]
	}

	foreach cns $child_namepaces {
		if {[lsearch -exact $SCARY_NAMESPACES $cns] != -1} {
			continue
		}
		# XXX Could we speed this up by using upvar?
		eval [list lappend procs] [_find_procs $cns]
	}

	return $procs
}


#
# Internal - replace the built-in "rename" and "proc" commands with our own.
#
proc ::core::profile::_replace_tcl_cmds {} {

	# Replace the rename command with our own.

	rename ::rename ::_core::profile_tcl_rename
	proc ::rename { oldName newName } {

		if {$newName == ""} {

			# Ensure we delete the original procedure too, if there is one.

			catch {
				uplevel 1 \
					[list ::_core::profile_tcl_rename ${oldName}_profile_orig  ""]
			}

		} else {

			# Ensure we rename the original procedure too, if there is one.
			# This relies on the timing body being universal.

			catch {
				uplevel 1 \
					[list ::_core::profile_tcl_rename \
						${oldName}_profile_orig ${newName}_profile_orig]
			}

		}

		# Now rename the procedure we were actually asked to rename.
		return [uplevel 1 [list ::_core::profile_tcl_rename $oldName $newName]]
	}

	# Replace the proc command with our own.

	rename ::proc ::_core::profile_tcl_proc
	::_core::profile_tcl_proc ::proc { name args body } {

		# check the target name isn't a scarily important proc

		set is_scary 0
		if {[string match "::*" $name]} {
			set fqn $name
		} else {
			set ccns [uplevel 1 [list ::namespace current]]
			if {$ccns == "::"} {
				set fqn "::${name}"
			} else {
				set fqn "${ccns}::${name}"
			}
		}
		if {[lsearch -exact $::core::profile::SCARY_PROCS $fqn]} {
			set is_scary 1
		} else {
			foreach scary_ns $::core::profile::SCARY_NAMESPACES {
				puts "${scary_ns}::* vs $fqn"
				if {[string match "${scary_ns}::*" $fqn]} {
					set is_scary 1
					break
				}
			}
		}

		if {$is_scary} {
			return [uplevel 1 [list ::_core::profile_tcl_proc $name $args $body]]
		}

		# Create the procedure under the name xxx_profile_orig, then create a
		# timing procedure under the name requested.

		uplevel 1 [list ::_core::profile_tcl_proc ${name}_profile_orig $args $body]
		uplevel 1 [list ::_core::profile_tcl_proc $name args $::core::profile::TIMING_BODY]

		return
	}

	return
}


#
# Internal - restore the original  "rename" and "proc" commands.
#
proc ::core::profile::_restore_tcl_cmds {} {

	# Restore the original replace command if there's a saved one.
	if { [llength [info commands ::_core::profile_tcl_rename]] } {

		::_core::profile_tcl_rename ::rename ""
		# XXX Tcl seems happy enough with this - bit scary though!
		::_core::profile_tcl_rename ::_core::profile_tcl_rename ::rename
	}

	# Restore the original proc command if there's a saved one.
	if { [llength [info commands ::_core::profile_tcl_proc]] } {
		rename ::proc ""
		rename ::_core::profile_tcl_proc ::proc
	}

	return
}

proc ::core::profile::_glob_protect {s} {
	variable GLOB_PROTECT
	return [string map $GLOB_PROTECT $s]
}
