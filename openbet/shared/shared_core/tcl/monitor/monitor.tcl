# $Id$
# 2014 Openbet Technology Ltd. All rights reserved.
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
#    package require core::monitor ?1.0?
#
# Procedures:
#    ::core::monitor::init            One time initialisation
#    ::core::monitor::get_server      Get monitor server hostname and port number
#    ::core::monitor::is_enabled      Is the monitor enabled
#    ::core::monitor::send            Send message to router
#

set pkgVersion 1.0

package provide core::monitor $pkgVersion

package require core::db
package require core::log
package require core::args
package require core::socket::client
package require core::request

namespace eval core::monitor {
	variable CFG
	variable INIT

	set INIT 0
}

core::args::register_ns \
	-namespace core::monitor \
	-version   $pkgVersion \
	-dependent [list]


core::args::register\
	-proc_name core::monitor::init\
	-desc      {}\
	-args      [list\
		[list -arg -servers         -mand 0 -check STRING -default_cfg MONITOR_SERVERS      -default {}]\
		[list -arg -enabled         -mand 0 -check STRING -default_cfg MONITOR_ENABLED      -default Y]\
		[list -arg -timeout         -mand 0 -check UINT   -default_cfg MONITOR_TIMEOUT      -default 2000]\
		[list -arg -default_ip      -mand 0 -check STRING -default_cfg MONITOR_DEFAULT_IP   -default "127.0.0.1"]\
		[list -arg -msg_style       -mand 0 -check {ENUM -args {tabs xml}} -default_cfg MONITOR_MSG_STYLE -default tabs]\
		[list -arg -tracker_enabled -mand 0 -check BOOL   -default_cfg TRACKER_ENABLED      -default 0]\
		[list -arg -receiver_url    -mand 0 -check STRING -default_cfg TRACKER_RECEIVER_URL -default "127.0.0.1/tracker/receiver"]\
	]\
	-body {
		variable CFG
		variable INIT
		variable SERVER

		# Already initialised
		if {$INIT} {
			return
		}

		set CFG(servers)         $ARGS(-servers)
		set CFG(enabled)         $ARGS(-enabled)
		set CFG(msg_style)       $ARGS(-msg_style)
		set CFG(timeout)         $ARGS(-timeout)
		set CFG(default_ip)      $ARGS(-default_ip)
		set CFG(tracker_enabled) $ARGS(-tracker_enabled)
		set CFG(receiver_url)    $ARGS(-receiver_url)

		# Backwards compatibility with the multitudes of configs to turn on and off
		if {[string tolower $CFG(enabled)] == "y"} {
			set CFG(enabled) 1
		} elseif {[string tolower $CFG(enabled)] == "n"} {
			set CFG(enabled) 0
		}

		set CFG(enabled) [expr {$CFG(enabled) && [OT_CfgGet MONITOR 0]}]

		# If not enabled, then exit
		if {!$CFG(enabled)} {
			set INIT 1
			core::log::write WARNING {MONITOR: disabled}
			return
		}

		if {$CFG(servers) == ""
		    || [catch {
				array set SERVER $CFG(servers)
			}]
		} {
			error "MONITOR: illegal server list"
		}

		_prep_queries

		# Get configured messages and fields
		set CFG(msg_codes) [list]

		if {[catch {
			set rs [core::db::exec_qry -name core::monitor::get_format]
		} msg]} {
			core::log::write CRITICAL {CORE MONITOR: Failed to initialise monitors $msg}
			error "CORE MONITOR: Failed to initialise"
		}

		for {set i 0; set nrows [db_get_nrows $rs]} {$i < $nrows} {incr i} {
			set code      [db_get_col $rs $i code]
			set name      [db_get_col $rs $i name]
			set data_type [db_get_col $rs $i data_type]
			if {[lsearch $CFG(msg_codes) $code] == -1} {
				lappend CFG(msg_codes) $code
				set CFG($code,fields) [list]
			}

			lappend CFG($code,fields) $name
			set CFG($code,field,$name,data_type) $data_type
		}

		# Register procedures
		foreach code $CFG(msg_codes) {
			_load_prefilter_rules $code
		}

		if {$CFG(tracker_enabled)} {
			package require tracker::api
			tracker::api::init -receiver_url $CFG(receiver_url)
		}

		# Denote we have already initialised
		set INIT 1
	}

#--------------------------------------------------------------------------
# Accessors
#--------------------------------------------------------------------------

core::args::register\
	-proc_name core::monitor::datetime_now\
	-desc      {Current datetime as a formatted string suite for monitor messages}\
	-args      [list\
	]\
	-body {
		return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	}


core::args::register\
	-proc_name core::monitor::get_server\
	-desc      {Get router details for a given message type}\
	-args      [list\
		[list -arg -code -mand 1 -check STRING -desc {Message code}]\
	]\
	-body {
		variable SERVER

		set msg_code $ARGS(-code)

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


core::args::register\
	-proc_name core::monitor::is_enabled\
	-desc      {Is the monitor functionality enabled}\
	-args      [list]\
	-body {
		variable INIT
		variable CFG

		if {!$INIT || !$CFG(enabled)} {
			return 0
		} else {
			return 1
		}
	}



#--------------------------------------------------------------------------
# Message formatting and sending
#--------------------------------------------------------------------------

core::args::register\
	-proc_name core::monitor::send\
	-desc      {}\
	-args      [list\
		[list -arg -code     -mand 1 -check STRING -desc {Message code}]\
		[list -arg -msg_dict -mand 1 -check NONE   -desc {A dict containing the monitor message data}]\
	]\
	-body {

		variable CFG

		if {![is_enabled]} {
			core::log::write WARNING {CORE MONITOR - NOT SENDING (disabled)}
			return
		}

		set code $ARGS(-code)
		set dict [dict get $ARGS(-msg_dict)]

		set msg  [list]

		# Backwards compat: always make sure there's an IP addr field (go figure)
		if {[lsearch $CFG($code,fields) "ip_addr"] == -1} {

			if {![dict exists $dict "ip_addr"]} {
				set ip_addr $CFG(default_ip)
				if {[catch {
					set ip_addr [core::request::get_client_ip]
				} err]} {
					core::log::write WARNING {CORE MONITOR: Failed to get IP add $err}
				}
			} else {
				set ip_addr [dict get $dict ip_addr]
			}
			lappend msg ip_addr $ip_addr
		}

		foreach field $CFG($code,fields) {

			if {[dict exists $dict $field]} {
				set value  [dict get $dict $field]
			} else {
				set value  {}
			}

			foreach v $value {
				lappend msg $field $v
			}
		}

		# Validate
		set status [_send $code $msg]
		return $status
	}


# Private procedure to package the monitor message in either tab or xml format
# (depending on the cfg).
#
#   msg_code - message code
#   msg      - Message body
#	returns  - packaged message
#
proc core::monitor::_pack {msg_code msg} {

	variable CFG

	set data ""
	if {$CFG(msg_style) == "tabs"} {
		append data "msg-type\t"
		append data "$msg_code\t"
		foreach {n v} $msg {
			set v [string map {"\t" " "} $v]
			append data "$n\t$v\t"
		}

	} else {
		append data {<?xml version="1.0" standalone="yes"?>}
		append data [subst {<message code="$msg_code">}]
		foreach {n v} $msg {
			append data [subst {<field name="[core::view::escape_html_tcl $n]" }]
			append data [subst {value="[core::view::escape_html_tcl $v]"\>}]
		}
		append data {</message>}
	}

	return $data
}


# Send message to router
#
proc core::monitor::_send {msg_code data} {

	variable CFG

	# Evaluate pre-filters against the message
	foreach [list status result] [_prefilter $msg_code $data] {
		break
	}

	if {$status == "OB_OK" && !$result} {
		core::log::write WARNING {CORE MONITOR Message prefiltered - NOT SENDING}
		return OB_ERR_MONITOR_MSG_PREFILTERED
	}

	core::log::write INFO {CORE MONITOR Sending message $msg_code : $data}

	if {$CFG(tracker_enabled)} {

		if {[catch {
			tracker::api::send -type $msg_code -data $data -flush 1
		} msg]} {
			core::log::write ERROR {TRACKER: $msg}
			return OB_ERR_TRACKER_CONNECT
		}
		return OB_OK

	}

	# Get router details
	lassign [core::monitor::get_server -code $msg_code] status host port
	if {$status != "OB_OK"} {
		return $status
	}

	# connect
	if {[catch {
		set sock [core::socket::client::connect\
			-host    $host\
			-port    $port\
			-timeout $CFG(timeout)]
	} msg]} {
		core::log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_CONNECT
	}

	# send the packaged message
	if {[catch {
		core::socket::client::write -sock $sock -msg [_pack $msg_code $data]
	} msg]} {
		core::log::write ERROR {MONITOR: $msg}
		return OB_ERR_MONITOR_WRITE
	}

	close $sock
	return OB_OK
}


#--------------------------------------------------------------------------
# Pre-Filter
#--------------------------------------------------------------------------

# Private procedure to evaluate pre-filters against the message data
# @params
#    msg_code  - message code
# @returns
#    list {status result} where result:
#       1 if the msg can be sent
#       0 if the msg cannot be sent, e.g. failed a pre-filter eval'
#
proc ::core::monitor::_prefilter { msg_code data } {

	variable PREFILTER

	array set DATA $data

	# Always send the message?
	if {[info exists DATA(cust_is_notifiable)] && $DATA(cust_is_notifiable) == "Y"} {
		return [list OB_OK 1]
	}

	# Do we have a pre-filter for the supplied code? (One-time only)
	if {[lsearch $PREFILTER(codes) $msg_code] == -1} {
		if {[catch {
			_load_prefilter_rules $msg_code
		} msg]} {
			core::log::write WARNING {Failed to load pre-filter for $msg_code: $msg}
			return [list OB_OK 1]
		}
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
			core::log::write ERROR {CORE MONITOR: unable to apply filter on $msg_code $field $operand}
			continue
		}

		# evaluate the data against the filter
		# - if data does not match the filter, then denote that the message
		#	should not be sent
		set eval_str [list $DATA($field) $eval_op $value]
		if {[catch {
			if {![expr $eval_str]} {
				core::log::write WARNING {CORE MONITOR: filtering on $msg_code $field - $eval_str}
				set result 0
			}
		} msg]} {
			core::log::write WARNING {CORE MONITOR: $msg}
		}
	}

	return [list OB_OK $result]
}


# Private procedure to one-time load the pre-filter rules for a monitor code.
# Stores the rules within the namespace.
# @params:
#    msg_code - message code
#
proc ::core::monitor::_load_prefilter_rules { msg_code } {

	variable PREFILTER

	if {![info exists PREFILTER(codes)]} {
		set PREFILTER(codes) [list]
	}

	# Only load once per child
	if {[lsearch $PREFILTER(codes) $msg_code] != -1} {
		return
	}

	lappend PREFILTER(codes) $msg_code

	set PREFILTER($msg_code,use)      N
	set PREFILTER($msg_code,num_rows) 0

	# Get prefilter rules
	if {[catch {
		set rs [core::db::exec_qry\
			-name core::monitor::get_prefilter_rules\
			-args [list $msg_code]]
	} msg]} {
		core::log::write ERROR {CORE MONITOR: $msg}
		error "OB_ERR_MONITOR_GET_PREFILTER_RULES"
	}

	set colnames [db_get_colnames $rs]
	set PREFILTER($msg_code,num_rows) [db_get_nrows $rs]

	for {set i 0} {$i < $PREFILTER($msg_code,num_rows)} {incr i} {
		foreach c $colnames {
			set PREFILTER($msg_code,$i,$c) [db_get_col $rs $i $c]
		}
	}

	if {$PREFILTER($msg_code,num_rows) > 0} {
		set PREFILTER($msg_code,use) Y
	}

	core::db::rs_close -rs $rs
}


# Prepare statements
#
proc core::monitor::_prep_queries {} {

	# Get message columns. Executed on init - no cache needed
	core::db::store_qry\
		-name core::monitor::get_format\
		-qry {
			select
				m.code,
				f.name,
				f.data_type
			from
				tMonMessageField fm,
				tMonField f,
				tMonMessage m
			where
				fm.field_id   = f.field_id
			and fm.message_id = m.message_id
		}

	# Get pre-filter rules. Executed on init - no cache needed
	core::db::store_qry\
		-name core::monitor::get_prefilter_rules\
		-qry {
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
			and m.use_prefilter = 'Y'
			and m.code = ?
			order by
				p.s_order
		}
}

