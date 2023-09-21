# $Id: monitor.tcl,v 1.1 2011/10/04 12:25:12 xbourgui Exp $
# 2005 Orbis Technology Ltd. All rights reserved.
#
# Monitor Utilities
#
# Configuration:
#    MONITOR_SERVERS    - name/value pair list of monitor servers
#                            host <hostname>
#                            port <portnumber>
#                            <msg_code>,host <hostname>
#                            <msg_code>,port <portnumber>
#                         e.g. bet,host venus bet,port 1234 host venus port 4321
#    MONITOR_ENABLED    - enable the monitor              - Y
#    MONITOR_MSG_STYLE  - message style (tabs|xml)        - tabs
#    MONITOR_TIMEOUT    - monitor connection timeout (ms) - 2000
#
# Synopsis:
#    package require monitor_monitor ?4.5?
#
# Procedures:
#    ::ob_monitor::init            one time initialisation
#    ::ob_monitor::get_server      get monitor server hostname and port number
#    ::ob_monitor::is_enabled      is the monitor enabled
#

package provide monitor_monitor 4.5



# Dependencies
#
package require util_db        4.5
package require util_log       4.5
package require net_sockclient 4.5



# Variables
#
namespace eval ::ob_monitor {

	variable CFG
	variable INIT
	variable SERVER
	variable MESSAGE
	variable PREFILTER

	# prefilter codes
	set PREFILTER(codes) [list]

	# init flag
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
#
# Can specify any of the configuration items as a name value pair (overwrites
# file configuration), names are
#
#	-servers
#	-enabled
#	-msg_style
#
proc ::ob_monitor::init args {

	variable CFG
	variable INIT
	variable SERVER

	# Already initialised
	if {$INIT} {
		return
	}

	# Initialise dependencies
	ob_log::init
	ob_db::init

	ob_log::write DEBUG {MONITOR: init}

	# Load the config items via args
	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	# Load config with defaults
	array set OPT [list\
		servers   ""\
		enabled   Y \
		msg_style tabs \
		timeout   2000]
		

	foreach c [array names OPT] {
		if {![info exists CFG($c)]} {
			set CFG($c) [OT_CfgGet MONITOR_[string toupper $c] $OPT($c)]
		}
	}

	if {[string tolower $CFG(enabled)] == "y"} {
		set CFG(enabled) 1
	} elseif {[string tolower $CFG(enabled)] == "n"} {
		set CFG(enabled) 0
	}

	# If not enabled, then exit
	if {!$CFG(enabled)} {
		set INIT 1
		ob_log::write WARNING {MONITOR: disabled}
		return
	}

	# Validate message style
	if {$CFG(msg_style) != "tabs" && $CFG(msg_style) != "xml"} {
		error "MONITOR: illegal message style"
	}

	# Get monitor server array
	if {$CFG(servers) == ""
		|| [catch {
			array set SERVER $CFG(servers)
		}]
	} {
		error "MONITOR: illegal server list"
	}
	ob_log::write_array DEBUG ::ob_monitor::SERVER

	# Prepare queries
	::ob_monitor::_prepare_qrys

	# Denote we have already initialised
	set INIT 1
}



# Private procedure to prepare package queries
#
proc ::ob_monitor::_prepare_qrys args {

	# Use pre-filter
	ob_db::store_qry ob_monitor::use_prefilter {
		select
		    m.use_prefilter
		from
		    tMonMessage m
		where
		    m.code = ?
	}

	# Get pre-filter rules
	ob_db::store_qry ob_monitor::get_prefilter_rules {
		select
		    f.name  as field,
		    p.value,
		    p.operand,
		    p.s_order
		from
		    tMonMessage      m,
		    tMonPreFilter    p,
		    tMonMessageField mf,
		    tMonField        f
		where
		    m.message_id = p.message_id
		and p.message_field_id = mf.message_field_id
		and mf.field_id = f.field_id
		and m.code = ?
		order by
		    p.s_order
	}

	# Get exchange rate - cached for 10 minutes
	ob_db::store_qry ob_monitor::get_exch_rate {
		select
		    exch_rate
		from
		    tCCY
		where
		    ccy_code = ?
	} 600
}



#--------------------------------------------------------------------------
# Accessors
#--------------------------------------------------------------------------

# Get the monitor server hostname and port number for a message code/type from
# the cfg MONITOR_SERVER.
# If the message code/type is not specified, then host and/or port name/value
# pair is used.
#
#    msg_code - message code/type e.g. bet
#    returns  - tcl list {status hostname portnumber}
#
proc ::ob_monitor::get_server { msg_code } {

	variable SERVER

	if {[info exists SERVER($msg_code,host)]} {
		set host $SERVER($msg_code,host)
	} elseif {![info exists SERVER(host)]} {
		return [list OB_ERR_MONITOR_HOST "" ""]
	} else {
		set host $SERVER(host)
	}

	if {[info exists SERVER($msg_code,port)]} {
		set port $SERVER($msg_code,port)
	} elseif {![info exists SERVER(port)]} {
		return [list OB_ERR_MONITOR_PORT "" ""]
	} else {
		set port $SERVER(port)
	}

	return [list OB_OK $host $port]
}



# Is the monitor enabled.
#
#	returns 1 if enabled, 0 if not (or not initialised)
#
proc ::ob_monitor::is_enabled args {

	variable INIT
	variable CFG

	if {!$INIT || !$CFG(enabled) || ! [OT_CfgGet MONITOR 0] } {
		return 0
	} else {
		return 1
	}
}



#--------------------------------------------------------------------------
# Communication
#--------------------------------------------------------------------------

# Private procedure to send a message to a monitor.
#
#    msg_code - message code
#    returns  - monitor status, OB_OK denotes success
#
proc ::ob_monitor::_send { msg_code } {

	variable CFG
	variable MESSAGE

	# Evaluate pre-filters against the message
	foreach [list status result] [::ob_monitor::_prefilter $msg_code] {
		break
	}
	if {$status != "OB_OK" || !$result} {
		return $status
	}

	# append the originating IP address
	if {[info commands reqGetEnv] != ""} {
		set MESSAGE [linsert $MESSAGE 0 ip_addr [reqGetEnv REMOTE_ADDR]]
	}

	# get the server
	foreach [list status host port] [::ob_monitor::get_server $msg_code] {
		break
	}

	if {$status != "OB_OK"} {
		return $status
	}

	# connect
	if {[catch {
		set sock [ob_sockclt::connect $host $port $CFG(timeout)]} msg]
	} {
		ob_log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_CONNECT
	}

	# send the packaged message
	set status OB_OK
	if {[catch {
		ob_sockclt::write $sock [_pack $msg_code]
	} msg]} {
		ob_log::write ERROR {MONITOR: $msg}
		set status OB_ERR_MONITOR_WRITE
	}

	close $sock
	return $status
}



#--------------------------------------------------------------------------
# Pre-Filter
#--------------------------------------------------------------------------

# Private procedure to evaluate pre-filters against the message data
#
#	msg_code  - message code
#	returns   - list {status result} where result:
#		1 if the msg can be sent
#		0 if the msg cannot be sent, e.g. failed a pre-filter eval'
#
proc ::ob_monitor::_prefilter { msg_code } {

	variable MESSAGE
	variable PREFILTER

	array set DATA $MESSAGE

	# Always send the message?
	if {[info exists DATA(cust_is_notifiable)] &&\
	        $DATA(cust_is_notifiable) == "Y"} {
		return [list OB_OK 1]
	}

	# Do we have a pre-filter for the supplied code? (One-time only)
	if {[lsearch $PREFILTER(codes) $msg_code] == -1} {
		set status [::ob_monitor::_load_prefilter_rules $msg_code]
		if {$status != "OB_OK"} {
			return [list $status 0]
		}
		lappend PREFILTER(codes) $msg_code
	}

	# Apply the pre-filter?
	if {$PREFILTER($msg_code,use) == "N"} {
		return [list OB_OK 1]
	}

	# Apply filters
	set result 1
	for {set i 0} {$result && $i < $PREFILTER($msg_code,num_rows)} {incr i} {

		foreach c {operand value field} {
			set $c $PREFILTER($msg_code,$i,$c)
		}

		# get the filter operand
		switch -- $operand {
			"EQ"    {
				set eval_op "=="
			}
			"NEQ"   {
				set eval_op "!="
			}
			"GT"    {
				set eval_op ">"
			}
			"GTE"   {
				set eval_op ">="
			}
			"LT"    {
				set eval_op "<"
			}
			"LTE"   {
				set eval_op "<="
			}
			default {
				set eval_op ""
			}
		}

		if {$eval_op == ""} {
			ob_log::write ERROR\
			    {MONITOR: unable to apply filter on $msg_code $field $operand}
			continue
		}

		# evaluate the data against the filter
		# - if data does not match the filter, then denote that the message
		#	should not be sent
		set eval_str [list $DATA($field) $eval_op $value]
		if {[catch {
			if {![expr $eval_str]} {
				ob_log::write WARNING\
				    {MONITOR: filtering on $msg_code $field - $eval_str}
				set result 0
			}
		} msg]} {
			ob_log::write WARBING {MONITOR: $msg}
		}
	}

	return [list OB_OK $result]
}



# Private procedure to one-time load the pre-filter rules for a monitor code.
# Stores the rules within the namespace.
#
#	msg_code - message code
#
proc ::ob_monitor::_load_prefilter_rules { msg_code } {

	variable PREFILTER

	ob_log::write DEBUG {MONITOR: _load_prefilter_rules $msg_code}

	set PREFILTER($msg_code,use)      N
	set PREFILTER($msg_code,num_rows) 0

	# Use a prefilter?
	if {[catch {
		set rs [ob_db::exec_qry ob_monitor::use_prefilter $msg_code]
	} msg]} {
		ob_log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_USE_PREFILTER
	}

	if {[db_get_nrows $rs] == 1} {
		set PREFILTER($msg_code,use) [db_get_col $rs 0 use_prefilter]
	} else {
		set PREFILTER($msg_code,use) N
	}
	ob_db::rs_close $rs

	# Not using a pre-filter
	if {$PREFILTER($msg_code,use) == "N"} {
		return OB_OK
	}

	# Get prefilter rules
	if {[catch {
		set rs [ob_db::exec_qry ob_monitor::get_prefilter_rules $msg_code]
	} msg]} {
		ob_log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_GET_PREFILTER_RULES
	}

	set colnames [db_get_colnames $rs]
	set PREFILTER($msg_code,num_rows) [db_get_nrows $rs]

	for {set i 0} {$i < $PREFILTER($msg_code,num_rows)} {incr i} {
		foreach c $colnames {
			set PREFILTER($msg_code,$i,$c) [db_get_col $rs $i $c]
		}
	}
	ob_db::rs_close $rs

	return OB_OK
}



#--------------------------------------------------------------------------
# Util
#--------------------------------------------------------------------------

# Private procedure to package the monitor message in either tab or xml format
# (depending on the cfg MONITOR_MSG_STYLE.
#
#	msg_code - message code
#	returns  - packaged message
#
proc ::ob_monitor::_pack { msg_code} {

	variable CFG
	variable MESSAGE

	set data ""
	if {$CFG(msg_style) == "tabs"} {
		append data "msg-type\t"
		append data "$msg_code\t"
		foreach {n v} $MESSAGE {
			set v [string map {"\t" " "} $v]
			append data "$n\t$v\t"
		}

	} else {
		append data {<?xml version="1.0" standalone="yes"?>}
		append data [subst {<message code="$msg_code">}]
		foreach {n v} $MESSAGE {
			append data [subst {<field name="[::ob_monitor::_xml_encode $n]" }]
			append data [subst {value="[::ob_monitor::_xml_encode $v]"\>}]
		}
		append data {</message>}
	}

	return $data
}



# XML encode a string
#
#	value   - value to encode
#	returns - encoded XML
#
proc ::ob_monitor::_xml_encode { value } {

	regsub -all {&} $value {\&amp;} value
	regsub -all {"} $value {\&quot;} value
	regsub -all {'} $value {\&apos;} value
	regsub -all {<} $value {\&lt;} value
	regsub -all {>} $value {\&gt;} value
	return $value
}

# Return the current datetime as a formatted string
#
#	returns - a timestamp in the format YYYY-MM-DD hh:mm:ss
#
proc ::ob_monitor::datetime_now {} {
	return [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]
}
