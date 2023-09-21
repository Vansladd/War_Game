##
# $Id: prof.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# Copyright (c) 2007 Orbis Technology Limited. All Rights Reserved.
# ob_prof - a simple Tcl profiler to help find CPU hotspots.
#
# Synopsis:
#   package require util_prof
#
# Configuration: (if using ob_prof::req_init and ob_prof::req_end)
#
#  OB_PROF_FOR_CUST_ID  = <cust_id>
#    Enable profiling only for requests where [ob_login::get cust_id]
#    matches the given <cust_id>. NB- this will only work if
#    you call the ob_login package before the ob_prof package.
#
# Procedures:
#
#   ob_prof::init     - One-time initialisation.
#   ob_prof::enable   - Start gathering statistics.
#   ob_prof::disable  - Stop gathering statistics.
#   ob_prof::reset    - Reset all statistics.
#   ob_prof::dump     - Dump statistics to a channel.
#   ob_prof::analyse  - Analyse saved dumped statistics.
#   ob_prof::req_init - Call from your req_init.
#   ob_prof::req_end  - Call from your req_end.
#
# Bugs:
#   May not cope with:
#     - really weird auto-generated / auto-loading stuff
#     - procedures brought into existence in unusual ways
#
##

package provide util_prof 4.5

namespace eval ::ob_prof {

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
	  ::tcl ::ob_prof msgcat\
	]

	if { [llength [info commands OT_CfgGet]] } {
		set CFG(OB_PROF_FOR_CUST_ID)  [OT_CfgGet OB_PROF_FOR_CUST_ID  -999]
	}
}


##
# One-time initialisation.
##
proc ::ob_prof::init {} {

	# Initialises at package require time.

	return
}


##
# Reset all profiler statistics.
##
proc ::ob_prof::reset {} {

	variable BUFFER
	variable TOTALS
	variable FLOW

	catch {unset BUFFER}
	set BUFFER [list]

	catch {unset TOTALS}
	set TOTALS(<Tcl>,count) 1
	set TOTALS(<Tcl>,callees,clk)   0.0
	set TOTALS(<Tcl>,callees,usr)   0.0
	set TOTALS(<Tcl>,callees,sys)   0.0

	catch {unset FLOW} ; array set FLOW [list]

	return
}


##
# Turn on profiling.
# Statistics will start to be gathered about every procedure call.
# NB - this call may be fairly expensive since it needs to instrument
# every procedure.
##
proc ::ob_prof::enable {} {

	variable ENABLED
	variable TIMING_BODY

	# No-op.

	if {$ENABLED} {
		return
	}

	# For every procedure that is currently defined ...

	set all_procs [_find_procs]
	foreach pname $all_procs {

		# If this procedure already has an accompanying xxx_prof_orig
		# procedure, then profiling must already be enabled for it.

		if { [llength [info procs [_glob_protect ${pname}_prof_orig]]] } {
			continue
		}

		# Create a timing procedure xxx_prof_timer for this proc if it doesn't
		# already have one.

		if { ![llength [info procs [_glob_protect ${pname}_prof_timer]]] } {
			proc ${pname}_prof_timer args $TIMING_BODY
		}

		# Rename the procedure to xxx_prof_orig, and rename the timing
		# procedure xxx_prof_timer to be the procedure itself.

		rename $pname ${pname}_prof_orig
		rename ${pname}_prof_timer $pname

	}

	# Replace the original Tcl "proc" and "rename" commands with our own
	# so that we can instrument any procedures created or renamed after
	# this call.

	_replace_tcl_cmds

	set ENABLED 1
}


##
# Turn off profiling.
# Statistics will cease to be gathered until ob_prof::enable is called.
# NB - this call may be fairly expensive since it de-instruments
# every procedure.
##
proc ::ob_prof::disable {} {

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

		# If this procedure doesn't have an accompanying xxx_prof_orig
		# procedure, then profiling must not have been enabled for it.

		if { ![llength [info procs [_glob_protect ${pname}_prof_orig]]] } {
			continue
		}

		# At the moment, the procedure is in fact the timing one.
		# Delete it, and rename the original procedure, xxx_prof_orig,
		# to be the procedure itself.

		rename $pname ""
		rename ${pname}_prof_orig $pname

	}

	set ENABLED 0
}


##
# Call from your req_init.
##
proc ::ob_prof::req_init {} {

	variable CFG

	global LOGIN_DETAILS

	# Check if we should enable profiling for this request.

	if {[ob_login::is_guest]} {
		set cust_id "unknown"
	} else {
		set cust_id [ob_login::get cust_id]
	}

	if {$cust_id == $CFG(OB_PROF_FOR_CUST_ID)} {
		ob_log::write INFO {OB_PROF enabling profiling (cust_id is $cust_id)}
		reset
		enable
	} else {
		ob_log::write DEBUG {OB_PROF not enabling profiling (cust_id is $cust_id)}
	}

	return
}


##
# Call from your req_end.
##
proc ob_prof::req_end {} {

	variable ENABLED

	if {$ENABLED} {

		# Write out a dump file.

		if {[catch {
			# XXX Should make location configurable
			set filename "/tmp/ob_prof.[OT_MicroTime].[asGetId]"
			ob_log::write INFO {OB_PROF writing dump to $filename}
			set f [open $filename "w"]
			dump $f
			close $f
		} msg]} {
			catch {close $f}
			ob_log::write ERROR {OB_PROF error in req_end: $msg}
		}

		# Disable profiling again.

		ob_log::write INFO {OB_PROF disabling profiling}

		disable

	}

	return
}


##
# Dump the profiler statistics gathered to a channel.
##
proc ::ob_prof::dump { {chan stderr} } {

	variable BUFFER
	variable TOTALS
	variable FLOW

	# Ensure buffer has been processed.

	_flush

	# Write out Tcl commands to recreate the TOTALS and FLOW arrays.

	set names [array names TOTALS]
	foreach name $names {
		puts $chan "set TOTALS([list $name]) [list $TOTALS($name)]"
	}

	set names [array names FLOW]
	foreach name $names {
		puts $chan "set FLOW([list $name]) [list $FLOW($name)]"
	}

	return
}


##
# Analyse the profiler statistics from the saved output of ob_prof::dump.
#
# Syntax:
#   ob_prof::analyse ?-top <N>? ?-by <stat1,..statN>? ?-flow 0|1?
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
##
proc ::ob_prof::analyse { filename args } {

	# These are our own local arrays, not the namespace ones.

	array set TOTALS [list]
	array set FLOW   [list]

	# The dumped script should re-create the arrays.

	source $filename

	if { ![info exists TOTALS(<Tcl>,callees,clk)] } {
		error "File \"$filename\" does not appear to contain an ob_prof::dump"
	}

	# These are the statistics we display for each procedure.

	set stat_names \
	  [list Name Calls \
	        TotClk TotUsr TotSys \
	        ExtClk ExtUsr ExtSys \
	        IntClk IntUsr IntSys]

	# Interpret the options. We supply sensible defaults.

	set topN      ""
	set order_by  [list TotClk ExtClk Name]
	set flow      1

	foreach [list opt_name opt_val] $args {
		switch -exact -- $opt_name {
			"-top" {
				set topN $opt_val
			}
			"-by" {
				set order_by [split $opt_val ","]
				foreach stat_name $order_by {
					if { [lsearch $stat_names $stat_name] < 0 } {
						error "Unknown -by option \"$stat_name\""
					}
				}
			}
			"-flow" {
				set flow $opt_val
			}
		}
	}

	# We make the total figure for the "root" procedure the same as the time
	# spent in the top-level procs. XXX Is there anything better we can do?

	set TOTALS(<Tcl>,total,clk) $TOTALS(<Tcl>,callees,clk)
	set TOTALS(<Tcl>,total,usr) $TOTALS(<Tcl>,callees,usr)
	set TOTALS(<Tcl>,total,sys) $TOTALS(<Tcl>,callees,sys)

	# For each proc in TOTALS, append its timing data to a big list of lists.

	set timing_data [list]
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

	}

	# Sort the timing data by the keys requested.

	for {set i [expr { [llength $order_by] - 1 }]} {$i >= 0} {incr i -1} {
		set stat_name [lindex $order_by $i]
		set stat_idx  [lsearch $stat_names $stat_name]
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

	set fmt "%32s%8s%8s%8s%8s%8s%8s%8s%8s%8s%8s\n"
	append s [eval [list format $fmt] $stat_names]

	set fmt "%32s%8u%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f%8.3f\n"
	foreach timing_datum $timing_data {
		append s [eval [list format $fmt] $timing_datum]
	}

	# Now add the flow data (if requested)

	if {$flow} {
		# XXX TODO
	}

	return $s
}


##
# Internal - this is the procedure body we use to time procedure calls.
# It should be independent of the procedure being timed, and as fast
# as possible.
##
set ::ob_prof::TIMING_BODY {

	# Get the fully-qualified name of this proc and our caller's proc.
	# For top-level procedures, we pretend we were called by "<Tcl>".

	set level [::info level]
	if {$level > 2} {
		set _prof_name [::uplevel 1 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _prof_caller [::uplevel 2 [::list namespace origin [::lindex [::info level 1] 0]]]
	} elseif {$level == 2} {
		set _prof_name [::uplevel 1 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _prof_caller [::uplevel #0 [::list namespace origin [::lindex [::info level 1] 0]]]
	} else {
		set _prof_name [::uplevel #0 [::list namespace origin [::lindex [::info level 0] 0]]]
		set _prof_caller "<Tcl>"
	}

	# Note the time before the real procedure was executed.

	set _prof_clk0 [::clock clicks -millis]
	set _prof_usr0 [::asGetTime -user]
	set _prof_sys0 [::asGetTime -system]

	# Execute the real procedure, which we assume is called xxx_prof_orig,
	# capturing the return value and code.

	::set ret_code [::catch {
		::uplevel 1 [::list ${_prof_name}_prof_orig] $args
	} ret_val]

	# Note the time after the procedure executed.

	::set _prof_clk1 [::clock clicks -millis]
	::set _prof_usr1 [::asGetTime -user]
	::set _prof_sys1 [::asGetTime -system]

	# Append the details to the buffer for later analysis.

	::lappend ::ob_prof::BUFFER $_prof_name $_prof_caller
	::lappend ::ob_prof::BUFFER $_prof_clk0 $_prof_usr0 $_prof_sys0
	::lappend ::ob_prof::BUFFER $_prof_clk1 $_prof_usr1 $_prof_sys1

	# Return whatever the real procedure returned.

	::return -code $ret_code $ret_val
}


##
# Internal - add the data in the buffer to the totals, then clear the buffer.
##
proc ::ob_prof::_flush {} {

	variable BUFFER
	variable TOTALS
	variable FLOW

	# For each procedure call recorded in the buffer ...

	foreach [list name caller clk0 usr0 sys0 clk1 usr1 sys1] $BUFFER {

		# Take into account the renaming of procedures.

		regsub {(.*)_prof_orig$} $caller \\1 caller

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


##
# Internal - find the names of all procedures that are currently defined.
# We exclude those ending in "_prof_orig" or "_prof_timer", as well
# as some internal ones.
# The names returned will be fully qualified with their namespace.
##
proc ::ob_prof::_find_procs { {ns ""} } {

	variable SCARY_PROCS
	variable SCARY_NAMESPACES

	# Find the procedures in this namespace.

	set procs [info procs "${ns}::*"]
	set keep_procs [list]
	foreach pname $procs {
		if { [string match "*_prof_orig" $pname] || \
		     [string match "*_prof_timer" $pname] || \
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


##
# Internal - replace the built-in "rename" and "proc" commands with our own.
##
proc ::ob_prof::_replace_tcl_cmds {} {

	# Replace the rename command with our own.

	rename ::rename ::_ob_prof_tcl_rename
	proc ::rename { oldName newName } {

		if {$newName == ""} {

			# Ensure we delete the original procedure too, if there is one.

			catch {
				uplevel 1 \
				  [list ::_ob_prof_tcl_rename ${oldName}_prof_orig  ""]
			}

		} else {

			# Ensure we rename the original procedure too, if there is one.
			# This relies on the timing body being universal.

			catch {
				uplevel 1 \
				  [list ::_ob_prof_tcl_rename \
				     ${oldName}_prof_orig ${newName}_prof_orig]
			}

		}

		# Now rename the procedure we were actually asked to rename.

		return [uplevel 1 [list ::_ob_prof_tcl_rename $oldName $newName]]
	}


	# Replace the proc command with our own.

	rename ::proc ::_ob_prof_tcl_proc
	::_ob_prof_tcl_proc ::proc { name args body } {

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
		if {[lsearch -exact $::ob_prof::SCARY_PROCS $fqn]} {
			set is_scary 1
		} else {
			foreach scary_ns $::ob_prof::SCARY_NAMESPACES {
				puts "${scary_ns}::* vs $fqn"
				if {[string match "${scary_ns}::*" $fqn]} {
					set is_scary 1
					break
				}
			}
		}

		if {$is_scary} {
			return [uplevel 1 [list ::_ob_prof_tcl_proc $name $args $body]]
		}

		# Create the procedure under the name xxx_prof_orig, then create a
		# timing procedure under the name requested.

		uplevel 1 [list ::_ob_prof_tcl_proc ${name}_prof_orig $args $body]
		uplevel 1 [list ::_ob_prof_tcl_proc $name args $::ob_prof::TIMING_BODY]

		return
	}

	return
}


##
# Internal - restore the original  "rename" and "proc" commands.
##
proc ::ob_prof::_restore_tcl_cmds {} {

	# Restore the original replace command if there's a saved one.

	if { [llength [info commands ::_ob_prof_tcl_rename]] } {

		::_ob_prof_tcl_rename ::rename ""
		# XXX Tcl seems happy enough with this - bit scary though!
		::_ob_prof_tcl_rename ::_ob_prof_tcl_rename ::rename

	}

	# Restore the original proc command if there's a saved one.

	if { [llength [info commands ::_ob_prof_tcl_proc]] } {

		rename ::proc ""
		rename ::_ob_prof_tcl_proc ::proc

	}

	return
}

proc ::ob_prof::_glob_protect {s} {
	variable GLOB_PROTECT
	return [string map $GLOB_PROTECT $s]
}

# Reset statistics initally.

::ob_prof::reset

#
# Supply a dummy asGetTime if we are running outside an appserver.
#

if { ![llength [info commands asGetTime]] } {
	proc asGetTime args { return 0.0 }
}

#
# Quick Test Case.
#

if {0} {
	namespace eval ob_prof_test {
		proc foo { n } {
			for {set i 0} {$i < $n} {incr i} {
				bar $i
			}
			if {[child::deep? 1] != 2} {
				error "return values broken"
			}
			if {![catch {::ob_prof_test::child::deep*} v] || $v != "foo"} {
				error "error return broken ($v)"
			}
		}
		proc recursive { n } {
			if {$n < 1} {
				return
			} else {
				return [recursive [expr {$n - 1}]]
			}
		}
		namespace eval child {
			proc deep* {} {
				error "foo"
			}
			proc deep? {x} {
				return [expr {$x + 1}]
			}
		}
	}
	proc ob_prof_test::bar {x} {
		set junk [clock scan "today + $x days"]
	}
	puts "profiling on"
	ob_prof::enable
	puts "creating _baz"
	proc _baz {} {
		ob_prof_test::foo 100
		ob_prof_test::recursive 5
	}
	puts "renaming _baz to _wibble"
	rename _baz _wibble
	puts "executing _wibble"
	_wibble
	puts "dump (1):"
	ob_prof::dump
	puts "resetting"
	ob_prof::reset
	puts "profiling off"
	ob_prof::disable
	puts "executing _wibble"
	_wibble
	puts "dump (2):"
	ob_prof::dump
	puts "profiling on again"
	ob_prof::enable
	puts "executing _wibble many times"
	for {set i 0} {$i < 100} {incr i} {
		_wibble
	}
	puts "analysing dump (3) via file:"
	set filename "/tmp/ob_prof_test.dump"
	set f [open $filename w]
	ob_prof::dump $f
	close $f
	puts stderr [ob_prof::analyse $filename -by "Calls,TotClk" -top 10]
}
