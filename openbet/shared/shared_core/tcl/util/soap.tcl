#
# Copyright OpenBet Technology Ltd 2013
#
# Provides a simple and consistent method of constructing,
# calling and retrieving data from SOAP endpoints.
#
# --- Public procedures ---
#
# core::soap::store_envelope          - Store a SOAP envelope
# core::soap::create_envelope         - Create a SOAP envelope
# core::soap::add_soap_header         - Add a Header to the SOAP envelope
# core::soap::add_soap_body           - Add a Body to the SOAP envelope
# core::soap::add_element             - Add an element to a parent
# core::soap::send                    - Send a SOAP request
# core::soap::get_doc                 - Get the tdom reference for a request/response
# core::soap::set_namespaces          - Sets namespaces in lieu of subsequent xpath
#                                      calls made in get_element/get_attributes
# core::soap::get_element             - Get the value of an element using xpath
# core::soap::get_attribute           - Get the value of an attribute using xpath
# core::soap::set_masked_elements     - Determine which elements to mask
# core::soap::print_soap              - Print a SOAP request/response
# core::soap::cleanup                 - Clean up tdom
#
# --- Private procedures ---
#
# core::soap::_parse                  - Parse raw SOAP to dom
# core::soap::_validate_new_name      - Ensure the name is unqiue
# core::soap::_validate_existing_name - Ensure the name is not already in use
# core::soap::_validate_parent        - Ensure the parent exists
# core::soap::_validate_label         - Ensure the label is not already in use
#

set pkg_version 1.0
package provide core::soap $pkg_version

# Dependencies
package require core::log      1.0
package require core::socket   1.0
package require core::xml      1.0
package require tdom

core::args::register_ns \
	-namespace core::soap \
	-version   $pkg_version \
	-dependent [list core::log core::socket core::args] \
	-docs      util/soap.xml

namespace eval core::soap {
	variable CFG
	variable SOAP

	set CFG(init) 0
}

core::args::register \
	-proc_name core::soap::init \
	-body {
		variable CFG

		# Already initialised.
		if {$CFG(init)} {
			return
		}

		core::log::write DEBUG {core::soap:init: initialised}
	}

core::args::register \
	-proc_name core::soap::_auto_reset \
	-is_public 0 \
	-body {
		variable SOAP

		if {[llength [info commands reqGetId]] == 0} {
			# hmm, do we need to protect ourselves here???
			return
		}

		set id [reqGetId]

		if {([info exists SOAP(req_id)] && $id != $SOAP(req_id))
			|| ![info exists SOAP(req_id)]
		} {
			array set SOAP [array unset SOAP]
			set SOAP(req_id) $id
		}
	}

##############################################
# Store SOAP outside of the create/send flow #
##############################################

#
# Stores and parses a SOAP envelope.
#
# name         - The name envelope to store.
# raw_envelope - Unparsed SOAP envelope.
# encoding     - The encoding of the envelope.
# type         - If this is a envelope to send or one we have received.
#
# E.g: core::soap::store_envelope -name soap1 -raw_envelope {<Request>REQUEST</Request>}    -type request
#      core::soap::store_envelope -name soap1 -raw_envelope {<Response>RESPONSE</Response>} -type received
#

core::args::register \
	-proc_name core::soap::store_envelope \
	-args [list \
		[list -arg -name         -mand 0 -check ASCII -desc {The name of the envelope}     -default "default"] \
		[list -arg -raw_envelope -mand 0 -check ANY -desc {Unparsed SOAP envelope}       -default ""] \
		[list -arg -encoding     -mand 0 -check ASCII -desc {The encoding of the envelope} -default "utf-8"] \
		[list -arg -type         -mand 0 -check {ENUM -args {received request}} \
			-desc {If this is an envelope to send or one we have received}                 -default "request"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Ensure the same is not in use already.
		core::soap::_validate_new_name $ARGS(-name) $ARGS(-type)

		set SOAP($ARGS(-name),$ARGS(-type),raw) $ARGS(-raw_envelope)

		core::soap::_parse $ARGS(-name) $ARGS(-type)
	}

#################################
# Building up a request to send #
#################################

#
# Creates a new SOAP envelope.
#
# name            - The name of the envelope.
# namespaces      - The namespaces of the envelope.
# elem            - The name of the envelope that will appear in the SOAP message
# attributes      - Any attribute name/value pairs required for the Envelope.
# encoding        - The encoding of the envelope.
# masked_elements - Elements that should be masked when logging xml
#
core::args::register \
	-proc_name core::soap::create_envelope \
	-args [list \
		[list -arg -name            -mand 0 -check ASCII -desc {The name of the envelope} -default "default"] \
		[list -arg -namespaces      -mand 0 -check ASCII -desc {The namespaces of the envelope} \
			-default [list \
				"xsi"     "http://www.w3.org/2001/XMLSchema-instance" \
				"xsd"     "http://www.w3.org/2001/XMLSchema" \
				"soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
				"soapenc" "http://schemas.xmlsoap.org/soap/encoding/"]] \
		[list -arg -elem            -mand 0 -check ASCII -desc {The name of the Envelop element} -default "soapenv:Envelope"] \
		[list -arg -attributes      -mand 0 -check ASCII -desc {Any attribute name/value pairs required for the envelope} -default [list]] \
		[list -arg -encoding        -mand 0 -check ASCII -desc {The encoding on the envelope} -default "utf-8"] \
		[list -arg -masked_elements -mand 0 -check ASCII -desc {Sensitive elements to mask when making a request} -default [list]] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Ensure the same is not in use already.
		core::soap::_validate_new_name $ARGS(-name) "request"

		# Lets default some stuff.
		set SOAP($ARGS(-name),labels) [list]
		core::soap::set_masked_elements -name $ARGS(-name) -elements $ARGS(-masked_elements)

		# Creating this way means when SOAP($name,request,doc) is freed so is the doc.
		dom createDocumentNode SOAP($ARGS(-name),request,doc)
		dom setResultEncoding $ARGS(-encoding)

		set SOAP($ARGS(-name),request,$ARGS(-elem)) [core::xml::add_element \
			-node $SOAP($ARGS(-name),request,doc) \
			-name $ARGS(-elem)]

		foreach {ns uri} $ARGS(-namespaces) {
			core::xml::add_attribute \
				-node  $SOAP($ARGS(-name),request,$ARGS(-elem)) \
				-name  "xmlns:$ns" \
				-value $uri
		}

		foreach {attr_name attr_value} $ARGS(-attributes) {
			core::xml::add_attribute \
				-node  $SOAP($ARGS(-name),request,$ARGS(-elem)) \
				-name  $attr_name \
				-value $attr_value
		}
	}

#
# Add a SOAP header to an envelope.
#
# name       - The name of the envelope.
# attributes - Any attribute name/value pairs required for the Header.
# parent     - The envelope name that will include the Header
# elem       - The name of the Header that will appear in the SOAP message
# label      - An internal label to reference the Header.
#              This defaults to soapenv:Header if not set.
#
core::args::register \
	-proc_name core::soap::add_soap_header \
	-args [list \
		[list -arg -name        -mand 0 -check ASCII -desc {Envelope name} -default "default"] \
		[list -arg -attributes  -mand 0 -check ASCII -desc {Attribute name/value pairs required for the header} -default [list]] \
		[list -arg -parent      -mand 0 -check ASCII -desc {The label of the element's parent} -default "soapenv:Envelope"] \
		[list -arg -elem        -mand 0 -check ASCII -desc {The name of the Envelop element} -default "soapenv:Header"] \
		[list -arg -label       -mand 0 -check ASCII -desc {Internal label to reference the header} -default "soapenv:Header"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Ensure the label has not already been used.
		core::soap::_validate_existing_name $ARGS(-name) "request"
		core::soap::_validate_parent        $ARGS(-name) $ARGS(-parent)
		core::soap::_validate_label         $ARGS(-name) $ARGS(-label)

		set SOAP($ARGS(-name),request,$ARGS(-label)) [core::xml::add_element \
			-node $SOAP($ARGS(-name),request,$ARGS(-parent)) \
			-name $ARGS(-elem)]

		foreach {attr_name attr_value} $ARGS(-attributes) {
			core::xml::add_attribute \
				-node  $SOAP($ARGS(-name),request,$ARGS(-label)) \
				-name  $attr_name \
				-value $attr_value
		}
	}

#
# Add a Body element to a SOAP envelope.
#
# name       - The name of the envelope.
# attributes - Any attribute name/value pairs required for the Body.
# parent     - The envelope name that will include the Body
# elem       - The name of the Body that will appear in the SOAP message
# label      - An internal label to reference the Body.
#              This defaults to soapenv:Body if not set.
#
core::args::register \
	-proc_name core::soap::add_soap_body \
	-args [list \
		[list -arg -name -mand 0 -check ASCII -desc {The name of the envelope} -default "default"] \
		[list -arg -attributes  -mand 0 -check ASCII -desc {Attribute name/value pairs required for the header} -default [list]] \
		[list -arg -parent      -mand 0 -check ASCII -desc {The label of the element's parent} -default "soapenv:Envelope"] \
		[list -arg -elem        -mand 0 -check ASCII -desc {The name of the Envelop element} -default "soapenv:Body"] \
		[list -arg -label       -mand 0 -check ASCII -desc {Internal label to reference the header} -default "soapEnv:Body"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Ensure the label has not already been used.
		core::soap::_validate_existing_name $ARGS(-name) "request"
		core::soap::_validate_parent        $ARGS(-name) $ARGS(-parent)
		core::soap::_validate_label         $ARGS(-name) $ARGS(-label)

		set SOAP($ARGS(-name),request,$ARGS(-label)) [core::xml::add_element \
			-node $SOAP($ARGS(-name),request,$ARGS(-parent)) \
			-name $ARGS(-elem)]

		foreach {attr_name attr_value} $ARGS(-attributes) {
			core::xml::add_attribute \
				-node  $SOAP($ARGS(-name),request,$ARGS(-label)) \
				-name  $attr_name \
				-value $attr_value
		}
	}

#
# Add a new element to the parent.
#
# -name       - The name of the envelope.
# -parent     - The label of the elements parent.
# -elem       - The name of the element.
# -value      - The value of the element.
# -attributes - Any attribute name/value pairs required for the element.
# -label      - An internal label to reference the element.
#               This defaults to $elem if not set.
#
core::args::register \
	-proc_name core::soap::add_element \
	-args [list \
		[list -arg -name       -mand 0 -check ASCII  -desc {The name of the envelope} -default "default"] \
		[list -arg -parent     -mand 0 -check ASCII  -desc {The label of the element's parent} -default ""] \
		[list -arg -elem       -mand 0 -check ASCII  -desc {The name of the element} -default ""] \
		[list -arg -value      -mand 0 -check STRING -desc {The value of the element} -default ""] \
		[list -arg -attributes -mand 0 -check ASCII  -desc {Attribute name/value pairs required for the element} -default [list]] \
		[list -arg -label      -mand 0 -check ASCII  -desc {Internal label to reference the element, default to the value of -element if not set} -default ""] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		if {$ARGS(-label) == ""} {
			set label $ARGS(-elem)
		} else {
			set label $ARGS(-label)
		}

		# Ensure the label has not already been used.
		core::soap::_validate_existing_name $ARGS(-name) "request"
		core::soap::_validate_parent        $ARGS(-name) $ARGS(-parent)
		core::soap::_validate_label         $ARGS(-name) $label

		# Create the new element.
		set SOAP($ARGS(-name),request,$label) [core::xml::add_element \
			-node $SOAP($ARGS(-name),request,$ARGS(-parent)) \
			-name $ARGS(-elem) \
			-value $ARGS(-value)]

		# Add the attributes.
		foreach {attr_name attr_value} $ARGS(-attributes) {
			core::xml::add_attribute \
				-node $SOAP($ARGS(-name),request,$label) \
				-name $attr_name \
				-value $attr_value
		}

	}

##############################
# Sending and receiving SOAP #
##############################

#
# Send a soap request.
#
# endpoint     - The location to send the SOAP envelope to.
# name         - The name of the SOAP envelope.
# conn_timeout - How long until the connection will timeout.
# req_timeout  - How long until the request will timeout.
# encoding     - The encoding to send the request in.
# charset      - The character set to send the request in.
#
# E.g: core::soap::send http://www.ladbrokes.com/endpoint \
#       -name         soap1 \
#       -conn_timeout 5000 \
#       -req_timeout  3000 \
#
# Returns - A list whose first element is 'OK' if the request was successful
#           and 'NOT_OK' otherwise.
#
#           If the request was not successful then the list will contain the
#           following extra elements:
#
#           The second element will be a code indicating the failure reason
#
#           If the request was sent to the destination server then there will
#           be a third element containing the socket status at the end of the
#           send.
#
core::args::register \
	-proc_name core::soap::send \
	-args [list \
		[list -arg -endpoint         -mand 1 -check ASCII                    -desc {The location to send the soap request to}] \
		[list -arg -name             -mand 0 -check ASCII -default "default" -desc {The name of the SOAP envelope} ] \
		[list -arg -conn_timeout     -mand 0 -check UINT  -default 10000     -desc {How long until the connection will timeout} ] \
		[list -arg -req_timeout      -mand 0 -check UINT  -default 10000     -desc {How long until the request will timeout} ] \
		[list -arg -encoding         -mand 0 -check ASCII -default "utf-8"   -desc {The encoding to send the request in}] \
		[list -arg -charset          -mand 0 -check ASCII -default "utf-8"   -desc {The character set to send the request in} ] \
		[list -arg -headers          -mand 0 -check ASCII -desc {Headers to send with the request} \
			-default [list "Content-Type" "text/xml; charset=utf-8" "SOAPAction" ""]] \
		[list -arg -declaration      -mand 0 -check ASCII -default {<?xml version="1.0"?>} -desc {XML declaration}] \
		[list -arg -tls_validate_cert    -mand 0 -check BOOL   -default 0               -desc {Check the certificate provided by the server is valid}] \
		[list -arg -tls_client_cert_file -mand 0 -check STRING -default {}              -desc {File containing client certificate to be provided to server}] \
		[list -arg -tls_client_key_file  -mand 0 -check STRING -default {}              -desc {File containing the private key to use for this connection}] \
		[list -arg -tls_ca_dir           -mand 0 -check STRING -default {/etc/pki/tls/} -desc {Directory to search for CA certificates}] \
		[list -arg -tls_validate_subject -mand 0 -check BOOL   -default 0               -desc {Check the CN strings in the servers certificate match the host we are contacting}] \
		[list -arg -tls_host_to_match    -mand 0 -check STRING -default {}              -desc {Hostname to match against the server certificates subject}] \
		[list -arg -tls_protocols        -mand 0 -check LIST   \
			-default $core::socket::DEFAULT_TLS_PROTOCOLS -default_cfg NET_SOCKET_TLS_PROTOCOLS       -desc {The protocol versions and boolean values to support for this request}]
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset
		set fn "core::soap::send"

		core::soap::_validate_existing_name $ARGS(-name) "request"

		append post_data \
			$ARGS(-declaration) \
			[$SOAP($ARGS(-name),request,doc) asXML]

		core::log::write DEBUG {$fn: request: [core::soap::print_soap -name $ARGS(-name) -type "request"]}

		if {[catch {
			lassign [core::socket::send_http_req \
				-url                   $ARGS(-endpoint) \
				-conn_timeout          $ARGS(-conn_timeout) \
				-req_timeout           $ARGS(-req_timeout) \
				-headers               $ARGS(-headers) \
				-post_data             $post_data \
				-encoding              $ARGS(-encoding) \
				-tls_validate_cert     $ARGS(-tls_validate_cert) \
				-tls_client_cert_file  $ARGS(-tls_client_cert_file) \
				-tls_client_key_file   $ARGS(-tls_client_key_file) \
				-tls_ca_dir            $ARGS(-tls_ca_dir) \
				-tls_validate_subject  $ARGS(-tls_validate_subject) \
				-tls_host_to_match     $ARGS(-tls_host_to_match) \
				-tls_protocols         $ARGS(-tls_protocols) \
			] req_id status complete
		} msg]} {
			core::log::write ERROR {$fn: error sending request - $msg}
			return [list NOT_OK ERR_OBSOAP_UNKNOWN]
		}

		core::log::write INFO {status: $status complete: $complete}

		set body [core::socket::req_info -req_id $req_id -item http_body]

		set return_value [list OK]

		if {$status != "OK"} {
			if {[core::socket::server_processed -req_id $req_id] == 0} {
				core::log::write INFO {$fn: bad response, request not processed, status $status}
				set reason ERR_OBSOAP_NOCONTACT
			} else {
				core::log::write INFO {$fn: bad response, request potentially processed, status $status}
				set reason ERR_OBSOAP_UNKNOWN
			}

			set response [core::socket::req_info -req_id $req_id -item response]
			core::log::write INFO {$fn: error body is $body}
			core::log::write INFO {$fn: error response is $response}

			set return_value [list NOT_OK $reason $status]
		}

		core::socket::clear_req -req_id $req_id

		# soap faults come up as HTTP_SERVER_ERRORs
		set SOAP($ARGS(-name),received,raw) $body

		return $return_value
	}

########################
# Parsing the response #
########################

#
# Return the dom document for if you want to do your own parsing.
#
# name - The name of the envelope to get the dom document for.
# type - If this is a envelope to send or one we received.
#
# E.g: core::soap::get_doc -name my_soap -type received
#
core::args::register \
	-proc_name core::soap::get_doc \
	-args [list \
		[list -arg -name -mand 0 -check ASCII \
			-desc {The name of the envelope to get the DOM document for}   -default "default"] \
		[list -arg -type -mand 0 -check {ENUM -args {received request}} \
			-desc {If this is an envelope to send or one we have received} -default "received"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),$ARGS(-type),doc)]} {
			core::soap::_parse $ARGS(-name) $ARGS(-type)
		}

		return $SOAP($ARGS(-name),$ARGS(-type),doc)
	}

#
# Sets the namespaces for the received document - these will be used when selectNodes
# calls are made on the document (i.e. using the get_element procedure).
# Namespaces set here will be overridden if the -namespaces option is used with
# get_element
#
# namespace_list - key value list of desired prefixes and their associated URIs
#
# E.g.:
#
# core::soap::set_namespaces [list \
#   "MY_soap" "http://schemas.xmlsoap.org/soap/envelope/" \
#   "MY_ns1"  "http://www.i-neda.com/namespace/xsd/betplus_webservice" \
#   "MY_ns2"  "http://www.i-neda.com/namespace/xsd/betplus_webservice"]
#
# Where your xpath in subsequent calls to get_element or get_attribute will
# use your custom prefix, e.g. your xpath may be "/MY_soap:Envelope/my_ns1:bookstore/my_ns2:books"
#
core::args::register \
	-proc_name core::soap::set_namespaces \
	-args [list \
		[list -arg -name        -mand 0 -check ASCII -desc {The name of the received envelope}   -default "default"] \
		[list -arg -namespaces  -mand 0 -check ASCII -desc {The namespaces to give the envelope} -default [list]] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),received,doc)]} {
			core::soap::_parse $ARGS(-name) "received"
		}

		$SOAP($ARGS(-name),received,doc) selectNodesNamespaces $ARGS(-namespaces)
	}

#
# Return the value of an xpath for an element.
#
# name       - The name of the envelope.
# namespaces - Any namespace aliases required.
# xpath      - The xpath of the element to select.
#
# E.g: core::soap::get_element -name my_soap -xpath "/Request/Username"
#
core::args::register \
	-proc_name core::soap::get_element \
	-args [list \
		[list -arg -name        -mand 0 -check ASCII -desc {The name of the envelope}           -default "default"] \
		[list -arg -namespaces  -mand 0 -check ASCII -desc {Any namespace aliases required}     -default [list]] \
		[list -arg -xpath       -mand 0 -check ASCII -desc {The xpath of the element to select} -default ""] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),received,doc)]} {
			core::soap::_parse $ARGS(-name) "received"
		}

		if {[catch {
			# if namespaces list variable empty, don't set it using -namespaces, as
			# this will explicitly override namespaces set with core::soap::set_namespaces
			if {[llength $ARGS(-namespaces)] == 0} {
				set elements [$SOAP($ARGS(-name),received,doc) selectNodes $ARGS(-xpath)]
			} else {
				set elements [$SOAP($ARGS(-name),received,doc) selectNodes -namespaces $ARGS(-namespaces) $ARGS(-xpath)]
			}
		} msg]} {
			set elements [list]
		}

		set values [list]
		foreach element $elements {
			lappend values [$element text]
		}

		return $values
	}

#
# Return the value(s) one or more attributes given the xpath.
#
# name       - The name of the envelope.
# namespaces - Any namespace aliases required.
# xpath      - The xpath of the attribute to select.
#
# E.g: core::soap::get_attributes -name my_soap -xpath "/Response/@attr-foo"
#      returns: [list attr-foo single_value]
#
# E.g: core::soap::get_attributes -name my_soap -xpath "/Response/@attr-foo|/Response/@attr-bar"
#      returns: [list attr-foo [list [list val_1 val_2 .. val_n]] attr_bar [list [list val_1 val_2 .. val_n]]]
#
core::args::register \
	-proc_name core::soap::get_attributes \
	-args [list \
		[list -arg -name        -mand 0 -check ASCII -desc {The name of the envelope}             -default "default"] \
		[list -arg -namespaces  -mand 0 -check ASCII -desc {Any namespace aliases required}       -default [list]] \
		[list -arg -xpath       -mand 0 -check ASCII -desc {The xpath of the attribute to select} -default ""] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),received,doc)]} {
			core::soap::_parse $ARGS(-name) "received"
		}

		if {[catch {
			# if namespaces list variable empty, don't set it using -namespaces, as
			# this will explicitly override namespaces set with core::soap::set_namespaces
			if {[llength $ARGS(-namespaces)] == 0} {
				set attributes [$SOAP($ARGS(-name),received,doc) selectNodes $ARGS(-xpath)]
			} else {
				set attributes [$SOAP($ARGS(-name),received,doc) selectNodes -namespaces $ARGS(-namespaces) $ARGS(-xpath)]
			}
		} msg]} {
			return [list]
		}

		foreach attribute $attributes {
			set attribute_name  [lindex $attribute 0]
			set attribute_value [lindex $attribute 1]

			if {[info exists RET($attribute_name)]} {
				lappend RET($attribute_name) $attribute_value
			} else {
				set RET($attribute_name) [list $attribute_value]
			}
		}

		return [array get RET]
	}

#
# Return number element given the xpath.
#
# name       - The name of the envelope.
# namespaces - Any namespace aliases required.
# xpath      - The xpath of the attribute to count.
#
# E.g: core::soap::count_element -name my_soap -xpath "/Response/elem"
#      returns: 2
#
core::args::register \
	-proc_name core::soap::count_element \
	-args [list \
		[list -arg -name        -mand 0 -check ASCII -desc {The name of the envelope}             -default "default"] \
		[list -arg -namespaces  -mand 0 -check ASCII -desc {Any namespace aliases required}       -default [list]] \
		[list -arg -xpath       -mand 0 -check ASCII -desc {The xpath of the attribute to select} -default ""] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),received,doc)]} {
			core::soap::_parse $ARGS(-name) "received"
		}

		set xpath "count($ARGS(-xpath))"

		if {[catch {
			# if namespaces list variable empty, don't set it using -namespaces, as
			# this will explicitly override namespaces set with core::soap::set_namespaces
			if {[llength $ARGS(-namespaces)] == 0} {
				set num_elements [$SOAP($ARGS(-name),received,doc) selectNodes $xpath]
			} else {
				set num_elements [$SOAP($ARGS(-name),received,doc) selectNodes -namespaces $ARGS(-namespaces) $xpath]
			}
		} msg]} {
			return 0
		}

		return $num_elements

	}

###################
# Displaying SOAP #
###################

#
# Set 'sensitive' elements to mask when printing a request or response.
#
# name     - The name of the envelope to apply to mask to.
# elements - A list of elements to mask.
#
# E.g: core::soap::set_masked_elements -name soap1 -elements [list Username Password]
#
core::args::register \
	-proc_name core::soap::set_masked_elements \
	-args [list \
		[list -arg -name     -mand 0 -check ASCII -desc {The name of the envelope to apply the mask to} -default "default"] \
		[list -arg -elements -mand 0 -check ASCII -desc {A list of elements to mask}                    -default "default"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		set SOAP($ARGS(-name),maskedElements) $ARGS(-elements)
	}

#
# Return masked SOAP to be logged.
#
# name - The name of the envelope to log.
# type - The type of SOAP to log (request or received).
#
# E.g: core::soap::print_soap -name my_soap -type received
#
core::args::register \
	-proc_name core::soap::print_soap \
	-args [list \
		[list -arg -name  -mand 0 -check ASCII -desc {The name of the envelope to log} -default "default"] \
		[list -arg -type  -mand 0 -check {ENUM -args {received request}} \
			-desc {If this is an envelope to send or one we have received} -default "request"] \
	] \
	-body {
		variable SOAP
		core::soap::_auto_reset

		# Parse the raw soap if not already done.
		if {![info exists SOAP($ARGS(-name),$ARGS(-type),doc)]} {
			core::soap::_parse $ARGS(-name) $ARGS(-type)
		}

		set xml [$SOAP($ARGS(-name),$ARGS(-type),doc) asXML]

		# We need to mask any masked elements.
		if {![info exists SOAP($ARGS(-name),maskedElements)]} {
			set SOAP($ARGS(-name),maskedElements) [list]
		}

		foreach elem $SOAP($ARGS(-name),maskedElements) {
			regsub -all -- [subst {(<${elem}(?:\\s\[^>\]*?\[^/\])??>).*?(</${elem}>)}] $xml {\1******\2} xml
		}

		return $xml
	}

###############
# Cleaning up #
###############

#
# Clean up a request when done with it to prevent memory leaks.
#
# name - The name of the envelope to clean up.
#
# E.g: core::soap::cleanup -name soap1
#
core::args::register \
	-proc_name core::soap::cleanup \
	-args [list \
		[list -arg -name -mand 0 -check ASCII -desc {The name of the envelope to clean up} -default "default"] \
	] \
	-body {
		variable SOAP

		array unset SOAP "$ARGS(-name),*"
	}

######################
# Private Procedures #
######################

#
# Parse the received xml.
#
proc core::soap::_parse {name type} {

	variable SOAP
	set fn "core::soap::_parse"

	if {![info exists SOAP($name,$type,raw)]} {
		error "$fn: nothing to parse"
	}

	if {[catch {
		dom parse -simple $SOAP($name,$type,raw) SOAP($name,$type,doc)
	} msg]} {
		core::log::write DEBUG {$msg}
		core::log::write DEBUG {Failed to parse: $SOAP($name,$type,raw)}
		error "$fn: failed to parse $name"
	}
}

#
# Ensure the name is not already in use.
#
proc core::soap::_validate_new_name {name type} {

	variable SOAP
	set fn "core::soap::_validate_new_name"

	if {[info exists SOAP($name,$type,doc)]} {
		error "$fn: name $name already in use for $type"
	}
}

#
# Ensure the name already exists
#
proc core::soap::_validate_existing_name {name type} {

	variable SOAP
	set fn "core::soap::_validate_existing_name"

	if {![info exists SOAP($name,$type,doc)]} {
		error "$fn: name $name not is use for $type"
	}
}

#
# Ensure a parent element exists,
#
proc core::soap::_validate_parent {name parent} {

	variable SOAP
	set fn "core::soap::_validate_parent"

	if {![info exists SOAP($name,request,$parent)]} {
		error "$fn: parent $parent does not exist"
	}
}

#
# Ensure that a label is not already in use.
#
proc core::soap::_validate_label {name label} {

	variable SOAP
	set fn "core::soap::_validate_label"

	if {[lsearch $SOAP($name,labels) $label] != -1} {
		error "$fn: invalid label: $label"
	}

	# We have validated the label so add it to the list
	# of used labels.
	lappend SOAP($name,labels) $label
}

#
# Extract all the xpath element in the Map from a soap message to a dictionary
# map  - Map of element to extract
# envelope_name     - The encoding of the envelope.
#
# Map signature:
# [list {element_name xpath is_attribute default_value nested_element nested_sub_element} {..}] \
# - element_name: it is the name of variable extracted from the soap message in the output dictionary
# - xpath: it is the xpath needed to extract the element from the soap message, in the case is a sub element of a nested element, it is just the path FROM the nested element.
# - is_attribute: it is a flag that is used only in not nested element, set to 1 if the element to extract is an attribute, set to 0 if it a node and we need the text value.
# - default_value: it is the default value in the case xpath is not retrieving any value from the soap message.
# - nested_element: it is a flag to say if the current node is or not a nested element, if so we need to specify the nested_sub_element
# - nested_sub_element: it is a list that has the same structure of map entry signature, but the xpath is defined FROM the parent nested element.
#
# Return value:
# Return a dict with the same structure of the map in input, each element is a entry in the dictionary, each nested element is a list where each sub-element are another dictionary and so on in case there are other nested elements.
core::args::register \
	-proc_name core::soap::map_to_dict \
	-desc {Extract all the xpath elements in the Map from a soap message to a dictionary} \
	-args [list \
		[list -arg -map            -mand 1 -check LIST  -desc {Map of element to extract} ] \
		[list -arg -envelope_name  -mand 1 -check ASCII -desc {Envelope name of the message to read}] \
	] \
	-body {
		return [_map_to_dict $ARGS(-map) $ARGS(-envelope_name)]
	}

# PRIVATE procedure, do not use directly, use core::soap::map_to_dict, is private because called recursively
proc core::soap::_map_to_dict {map envelope_name {root_path ""}} {

	foreach {param xpath is_attribute default_value is_nested nested_elements} $map {

		# for recursive case need to add the xpath to the nested elements.
		set xpath "$root_path$xpath"
		# no nested normal element extract directly
		if {!$is_nested} {
			if {$is_attribute} {
				set value [lindex [core::soap::get_attributes \
					-name $envelope_name \
					-xpath $xpath] 1]
			} else {
				set value [lindex [core::soap::get_element \
					-name $envelope_name \
					-xpath $xpath] 0]
			}

			if {$value == {}} {
				set value $default_value
			}
			dict set result $param $value

		} else {
			# number nested elements unknown.
			set num_nodes [core::soap::count_element -name $envelope_name -xpath $xpath]

			set items [list]
			for {set node_index 1} {$node_index <= $num_nodes} {incr node_index} {
				set xpath_element [subst -nocommand {$xpath[$node_index]}]

				lappend items [_map_to_dict $nested_elements $envelope_name $xpath_element]
			}
			# append to the result the imtes got from the recursive call
			dict set result $param $items
		}
	}
	return $result
}
