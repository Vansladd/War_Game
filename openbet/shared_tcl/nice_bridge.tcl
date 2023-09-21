# $Id: nice_bridge.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2010 Orbis Technology Ltd. All rights reserved.
#
# provide an interface to call the third party NICE  API
#

package require net_socket
package require util_xml

namespace eval nice_bridge {
	variable INIT 0
}



#-------------------------------------------------------------------------------
# Initialisation
#-------------------------------------------------------------------------------

# initialisation
proc nice_bridge::init {} {

	variable INIT
	variable CFG

	# Check if already initialised
	if {$INIT} {
		return
	}

	ob_log::write INFO {nice_bridge::init - Initialising nice_bridge}

	# read configuration
	set CFG(api_url)           [OT_CfgGet NICE_API_URL]
	set CFG(api_port)          [OT_CfgGet NICE_API_PORT 80]
	set CFG(xmlns)             [OT_CfgGet NICE_XMLNS http://nice.uniform/CLSAP13]
	set CFG(conn_timeout)      [OT_CfgGet NICE_CONN_TIMEOUT 30000]
	set CFG(req_timeout)       [OT_CfgGet NICE_REQ_TIMEOUT 30000]
	set CFG(default_switch_id) [OT_CfgGet NICE_DEFAULT_SWITCH_ID]


	_prepare_queries

	ob_log::write INFO {nice_bridge::init INITIALISED}
	set INIT 1
}



# Prepare queries
#
proc nice_bridge::_prepare_queries {} {

	tb_db::store_qry nice_bridge::get_user_details {
		select
			agent_id,
			phone_switch
		from
			tAdminUser
		where
			user_id = ?
	}

}



#-------------------------------------------------------------------------------
# Public
#-------------------------------------------------------------------------------

# send a stop request to NICE API
#  user_id - id of the admin user to send request for
#
# return    - [1 "OK"] if sucessful
#             [0 err_msg] otherwise
#
proc nice_bridge::send_stop {user_id} {

	variable CFG

	ob_log::write DEBUG {nice_bridge::send_stop sending stop request: $user_id}

	foreach {status agent_id switch_id} [nice_bridge::_get_user_details $user_id] {}

	if {!$status} {
		return [list 0 "NICE_BRIDGE_INVALID_USER"]
	}

	set params [list \
		"Switch" $switch_id \
		"Agent"  $agent_id]

	set res [_send_request \
		"${CFG(api_url)}/REST/CallManager/ForceStop/Agent" \
		$params \
		$CFG(conn_timeout) \
		$CFG(req_timeout)]

	# let errors bubbling up to the calling proc
	return $res
}



# send a start request to NICE API
#  user_id - id of the admin user to send request for
#
# return    - [1 "OK"] if sucessfull
#             [0 err_msg] otherwise
#
proc nice_bridge::send_start {user_id} {

	variable CFG

	ob_log::write DEBUG {nice_bridge::send_start sending start request: $user_id}

	foreach {status agent_id switch_id} [nice_bridge::_get_user_details $user_id] {}

	if {!$status} {
		return [list 0 "NICE_BRIDGE_INVALID_USER"]
	}

	set params [list \
		"Switch" $switch_id \
		"Agent"  $agent_id \
		"Media"  "voice"]

	set res [_send_request \
		"${CFG(api_url)}/REST/CallManager/ROD/Start/Agent" \
		$params \
		$CFG(conn_timeout) \
		$CFG(req_timeout) ]

	# let errors bubbling up to the calling proc
	return $res
}



#-------------------------------------------------------------------------------
# Private
#-------------------------------------------------------------------------------

# send a request to NICE API
# url          - API url
# args         - request argument to send to NICE API (Agent,switch and Media)
# conn_timeout - timeout in ms for sending the request
# req_timeout  - timeout in ms for awaiting response
#
proc nice_bridge::_send_request {
	url
	args
	conn_timeout
 	req_timeout
} {

	variable CFG

	set fn "nice_bridge::_send_request"

	if {[catch {
		foreach {api_scheme api_host api_port api_urlpath junk junk} \
			[ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn: Bad API URL - $msg}
		return [list 0 "NICE_BRIDGE_ERR_REQ"]
	}

	# Construct the raw HTTP request.
 	if {[catch {
 		set req [ob_socket::format_http_req \
			-host       $api_host \
			-method     "GET" \
			-form_args  $args \
			$api_urlpath]
	} msg]} {
		ob_log::write ERROR {$fn: Unable to build stop request - $msg}
		return [list 0 "NICE_BRIDGE_ERR_REQ"]
	}

	# Send the request to the NICE bridge API url.
	if {[catch {
		foreach {req_id status complete} \
			[::ob_socket::send_req \
				-is_http      1 \
				-conn_timeout $conn_timeout \
				-req_timeout  $req_timeout \
				$req \
				$api_host \
				$api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		 ob_log::write ERROR {$fn: Unsure whether request reached NICE bridge, send_req failed - $msg}
		return [list 0 "NICE_BRIDGE_ERR_REQ"]
	}

	if {$status == "OK"} {

		# Request successful - get and return the response data.
		set res_body [string trim [::ob_socket::req_info $req_id http_body]]
		ob_log::write INFO {$fn: Request successful, response is $res_body}
		::ob_socket::clear_req $req_id

		# parse response
		if {[catch {
			set doc     [ob_xml::parse $res_body -novalidate]
			set root    [$doc documentElement]
			set node    [$root selectNodes -namespaces [list ans $CFG(xmlns)] //ans:ResultCodeEx/text()]
			set result  [$node data]
		} msg]} {
			ob_log::write ERROR {$fn: Unable to parse response $msg}
			return [list 0 "NICE_BRIDGE_ERR_REQ"]
		}

		if {$result == "CLS_SE_SUCCESS"} {
			return [list 1 "OK"]
		}

		ob_log::write ERROR {$fn Call to NICE failed. Status: $result}

		return [list 0 "NICE_BRIDGE_ERR_NICE_API"]

	} else {

		# Request failed - return failure.
		ob_log::write ERROR {$fn: Request NOT successful. Status: $status}

		# Is there a chance this request might actually have got to NICE bridge
		if {[::ob_socket::server_processed $req_id]} {
			ob_log::write ERROR {$fn: Unsure whether request reached NICE bridge, status was $status}
			set err_msg "NICE_BRIDGE_ERR_REQ"
		} else {
			ob_log::write ERROR {$fn: Unable to send request to NICE bridge, status was $status}
			set err_msg "NICE_BRIDGE_ERR_REQ"
		}
		::ob_socket::clear_req $req_id
		return [list 0 $err_msg]
	}
}



# get operator information , return an empty string if an error occurs
#
# cols - a list of values to get]
# returns a list
#     1 if successful, 0 if not
#     list of values (in same order as requested)
#
proc nice_bridge::_get_user_details {user_id} {

	variable CFG

	set fn "nice_bridge::_get_user_details"

	if {$user_id == "" || $user_id < 0} {
		ob_log::write ERROR {$fn:  User id invalid: $user_id}
		return [list 0 {} {}]
	}

	set rs [tb_db::exec_qry nice_bridge::get_user_details $user_id]

	if {![db_get_nrows $rs]} {
		ob_log::write ERROR {$fn:  User not found: $user_id}
		return [list 0 {} {}]
	}

	set agent_id  [db_get_col $rs 0 agent_id]
	set switch_id [db_get_col $rs 0 phone_switch]

	if {$switch_id == ""} {
		set switch_id $CFG(default_switch_id)
	}

	tb_db::rs_close $rs

	return [list 1 $agent_id $switch_id]

}
