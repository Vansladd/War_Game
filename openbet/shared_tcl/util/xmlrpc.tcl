# $Id: xmlrpc.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
#
# This package deals with the creation and parsing of
# standard XMLRPC calls/responses respectively.
#
# For convenience, there is also a format_and_send_request
# proc as this is a standard process for XMLRPC requests.
#

package provide util_xmlrpc 4.5

# Dependencies
package require util_log 4.5
package require net_socket 4.5
package require tdom
package require util_xml 4.5



namespace eval ob_xmlrpc {
	variable INIT 0
	variable CFG
	variable REQ
	variable RESP
}

#
# Initialize
#
proc ob_xmlrpc::init args {
	variable INIT
	variable CFG

	if {$INIT} {
		return
	}

	ob_log::init

	foreach {cfg dflt} { \
		dom_encoding "utf-8"
	} {
		set CFG($cfg) [OT_CfgGet XMLRPC_[string toupper $cfg] $dflt]
	}

	dom setResultEncoding $CFG(dom_encoding)

	set INIT 1
}


# ob_xmlrpc::build_req
#
# Args:
#    method_name: the methodName node of the request
#    params     : a {k} {v} list of params and their values
#
# Returns
#    A list with the following elements
#    lindex      0           1
#             NOT_OK    ERROR message
#               OK      XMLRPC request body
#
proc ob_xmlrpc::build_req {
	method_name \
	req_params \
} {

	variable CFG
	variable REQ
	array unset -nocomplain REQ

	ob_log::write DEV {ob_xmlrpc::build_req \
		-method_name $method_name \
		-req_params $req_params \
	}

	# build the body
	set REQ(doc) [dom createDocument "methodCall"]
	set root     [$REQ(doc) documentElement]

	# methodName child
	set methodName [$REQ(doc) createElement "methodName"]
	$root appendChild $methodName
	$methodName appendChild [$REQ(doc) createTextNode $method_name]


	# params child for each parameter
	if {[llength $req_params]} {
		set params [$REQ(doc) createElement "params"]
		$root appendChild $params

		foreach req_param $req_params {
			_add_param_node $req_param
		}
	}


	# Add the XML declaration to the top
	set xml  [subst {<?xml version="1.0" encoding="$CFG(dom_encoding)" ?>\n}]
	append xml [$REQ(doc) asXML -doctypeDeclaration 0]
	return $xml
}



# ob_xmlrcp::format_and_send_req
#
# This is a wrapper proc around some of the util_socket functions.
# It is provided here for convenience as sending an XMLRPC request will usually
# involve the same standard steps.
#
# Args
#    api_url     - The server to send the request to. The format is:
#                  http(s)://username:password@services.myurl.co.uk:80/my_api.php
#    method_name - The methodName node of the request
#    params      - k v list of the remaining xmlrpc params
#
# Returns
#    A list with the following elements
#    lindex      0           1
#             NOT_OK    ERROR message
#               OK         response
#
proc ob_xmlrpc::format_and_send_req args {

	variable CFG

	set fn "ob_xmlrcp::format_and_send_req"

	# All the required and optional fields are passed on blindly
	# to the ob_socket package to be validated there.

	# Required fields
	set api_url      [lindex $args end]
	set request_body [lindex $args end-1]

	# Optional fields
	set opt_args [lrange $args 0 end-2]


	# Build the header
	set header [list "Content-Type" "text/xml"]

	if {[catch {
		foreach {api_scheme api_host api_port api_uri api_username api_password} \
		  [ob_socket::split_url $api_url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn: Bad URL: $msg}
		return [list NOT_OK ERR_OBXMLRPC_URL_MALFORMED]
	}

	ob_log::write DEBUG {$fn: API details: \
		-api_scheme $api_scheme \
		-api_host $api_host \
		-api_port $api_port \
		-api_uri $api_uri \
		-api_username $api_username \
		-api_password $api_password \
	}

	# Any server authentication?
	if {$api_username != ""} {
		lappend header "Authorization" "Basic [bintob64 ${api_username}:${api_password}]"
	}


	if {[catch {
		# XMLRPC is always POST
		set req [ob_socket::format_http_req \
			-method     "POST" \
			-host       $api_host \
			-headers    $header \
			-post_data  $request_body \
			$api_uri \
		]
	} msg]} {
		ob_log::write ERROR {$fn: Unable to build request: $msg}
		return [list NOT_OK ERR_OBXMLRPC_NO_REQ_BUILD]
	}


	# Log the request. Mask the authorization details
	set req_log [regsub -nocase -line {^(Authori[z|s]ation: Basic )(.)+$} $req "\\1****"]
	ob_log::write INFO {$fn - Request: \n$req_log}


	# Cater for the unlikely case that we're not using HTTPS.
	set tls [expr {$api_scheme == "http" ? -1 : ""}]

	# Build up the call to ob_socket::format_and_send_req
	set send_req [list "ob_socket::send_req"]
	foreach arg_component $opt_args {lappend send_req $arg_component}
	lappend send_req "-tls" $tls "-is_http" 1 $req $api_host $api_port

	# Send the request.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
			[eval $send_req] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob_log::write ERROR {$fn: Unsure whether request reached $api_host:\
			proc blew up with $msg \
		}
		return [list NOT_OK ERR_OBXMLRPC_UNKNOWN]
	}

	if {$status != "OK"} {
		# Is there a chance this request might actually have got to the host?
		if {[::ob_socket::server_processed $req_id]} {
			ob_log::write ERROR \
			  {$fn: Unsure whether request reached $api_url: status was $status}
			::ob_socket::clear_req $req_id
			return [list NOT_OK ERR_OBXMLRPC_UNKNOWN]
		} else {
			ob_log::write ERROR \
			  {$fn: Unable to send request to $api_url: status was $status}
			::ob_socket::clear_req $req_id
			return [list NOT_OK ERR_OBXMLRPC_NOCONTACT]
		}
	}

	set response_body [string trim [::ob_socket::req_info $req_id http_body]]
	::ob_socket::clear_req $req_id
	ob_log::write DEBUG {$fn: Response body:\n $response_body}


	return [list OK $response_body]

}


# ob_xmlrpc::parse_response
#
# 1. Parse to a dom element.
# 2. Check for a valid methodResponse tag.
# 3. Check for a fault response.
# 4. Return the parsed dom element. Let the caller decide what to do with the contents.
#
# Args:
#   resp                - The whole response.
#   check_generic_fault - Do a generic fault check. There is a prescribed generic spec for
#                         fault responses that the API serving the response should (but
#                         doesn't necessarily have to) adhere to.
#
# Returns:
#   One of the following lists:
#   lindex:   0                    1
#             OK    A dom element containing the response contents
#          NOT_OK   Error code
#           FAULT   A list of {fault_code fault_string}
#
proc ob_xmlrpc::parse_response {resp {check_generic_fault 1}} {

	variable RESP
	array unset -nocomplain RESP

	set fn "ob_xmlrpc::parse_response"

	# Actually parsing the XML
	if {[catch {
		set RESP(doc) [ob_xml::parse $resp -novalidate]
	} msg]} {
		ob_log::write ERROR {$fn: NOT_OK: $msg}
		return [list NOT_OK XML_PARSE_ERROR]
	}

	# The root has to be a methodResponse tag
	set RESP(root)  [$RESP(doc) documentElement]
	if {[$RESP(root) nodeName] != "methodResponse"} {
		ob_log::write ERROR {$fn: NOT_OK: Unrecognized root element: $RESP(root)}
		return [list NOT_OK XML_MALFORMED]
	}

	# Is this an error response?
	if {$check_generic_fault} {
		set fault [$RESP(root) selectNodes {fault}]
		if {$fault != {}} {

			# Get the fault info list
			set fault_members [$fault selectNodes {value/struct/member}]

			set fault_code ""
			set fault_string ""

			foreach member $fault_members {

				set name  [[$member selectNodes {name/text()}] nodeValue]
				set value [$member selectNodes {value}]

				switch -exact -- $name {
					"faultCode" {
						set fault_code [[$value selectNode {int/text()}] nodeValue]
					}
					"faultString" {
						set fault_string [[$value selectNode {string/text()}] nodeValue]
					}
					default {
						ob_log::write ERROR {$fn: ERROR. Unrecognized member_name: $name}
						return [list NOT_OK XML_MALFORMED]
					}
				}

			}

			ob_log::write DEBUG {$fn: Received FAULT message ($fault_code): $fault_string}
			return [list FAULT [list $fault_code $fault_string]]

		}
	}

	return [list OK $RESP(root)]
}


# ob_xmlrpc::_add_param_node
#
# Adds an xmlrpc standard "param" node to the REQ(doc) dom element based on what has been passed in
#
# NOTE: So far support for param types has only been added for those currently in use.
#       There are more in existence that this proc does not support. These should be added as needed.
#
# Args:
#    req_param: A list in one of the following formats:
#       * {param name} {param value} {param type (int/string/etc)}
#       * {param value} {param type (int/string/etc)}
#
# Returns:
#    Nothing
#
proc ob_xmlrpc::_add_param_node req_param {

	variable REQ
	set fn "ob_xmlrpc::_add_param_node"

	# Get the parts out of the param. If it's three elements long,
	# we expect name,val,type. If it's two, we expect val,type.
	set par_name ""
	switch -- [llength $req_param] {
		"3" {foreach {par_name par_val par_type} $req_param {break}}
		"2" {foreach {par_val par_type} $req_param {break}}
		default {error "$fn: \"Malformed param: $req_param\""}
	}

	# Add the nodes to the request
	set params [$REQ(doc) selectNodes {/methodCall/params}]
	set param [$REQ(doc) createElement "param"]
	$params appendChild $param

	# Are we sending param names in the request?
	if {$par_name != ""} {
		set name [$REQ(doc) createElement "name"]

		$name  appendChild [$REQ(doc) createTextNode $par_name]
		$param appendChild $name
	}

	set value [$REQ(doc) createElement "value"]
	$param appendChild $value

	# Add the <type> node to the value
	switch -- $par_type {
		"int" -
		"i4" -
		"boolean" -
		"string" -
		"double" -
		"dateTime.iso8601" -
		"base64" {
			set $par_type [$REQ(doc) createElement $par_type]
			[subst "$$par_type"] appendChild [$REQ(doc) createTextNode $par_val]
			$value appendChild [subst "$$par_type"]
		}
		default {error "$fn: \"Unknown type: $par_type\""}
	}
}
