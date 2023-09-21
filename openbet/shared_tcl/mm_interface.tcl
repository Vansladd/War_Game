# ==============================================================
# $Id: mm_interface.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2005 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval OB_MM_interface {
	namespace export init
	namespace export funds_held_check

    # has this module been initialised?
    variable INITIALISED
    set INITIALISED 0
}

# ======================================================================
# Mahjong XML Interface, one time initialisation functions
# init_MM_interface should be called before any other function
# in this file
# ----------------------------------------------------------------------

proc OB_MM_interface::prep_qrys {} {
	global SHARED_SQL

	set SHARED_SQL(MM_getCustomerCharset) {
		select
			l.charset
		from
			tCustomer c,
			tLang l
		where
			c.username = ? and
			c.lang = l.lang
	}
}

##
# OB_MM_interface::init - Initialise this module
#
# SYNOPSIS
#
#       [OB_MM_interface::init]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#       Initialises this module.
#       It will load in its config parameters and required packages.
#
##

proc OB_MM_interface::init {} {
	variable INITIALISED

	if {$INITIALISED} {
		return
	}

	prep_qrys

	package require tdom
	package require http

	set INITIALISED 1
}

##
# OB_MM_interface::funds_held_check -
#
# SYNOPSIS
#
#       [OB_MM_interface::funds_held_check]
#
# SCOPE
#
#       public
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::funds_held_check {username} {
	global MM_DETAILS

	#
	# Clear global before use.
	catch {unset MM_DETAILS}

	#
	# First, we need to customer's charset as we're putting into utf-8.

	if {[catch {set rs [tb_db::tb_exec_qry "MM_getCustomerCharset" $username]} msg]} {
		ob::log::write INFO {OB_MM_interface::funds_held_check - Can't get customer's charset: $msg}
		return
	}

	set nrows [db_get_nrows $rs]
	if {$nrows != 1} {
		ob::log::write INFO {OB_MM_interface::funds_held_check - Can't get customer's charset: More than one row.}
	}

	set charset [db_get_col $rs 0 charset]
	db_close $rs

	#
	# Build the request xml message.
	set xml_msg [build_funds_held_check_request_xml $username $charset]

	ob::log::write INFO {OB_MM_interface::funds_held_check - xml_msg: $xml_msg}

	#
	# Convert XML to utf-8.
	set xml_msg [encoding convertto "utf-8" $xml_msg]

	return [OB_MM_interface::parse_funds_held_check_response_xml\
		[OB_MM_interface::send_xml_message $xml_msg [OT_CfgGet MM_TIMEOUT 10000]]]
}

##
# OB_MM_interface::send_xml_message -
#
# SYNOPSIS
#
#       [OB_MM_interface::send_xml_message]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::send_xml_message {xml_msg timeout} {
	global MM_DETAILS

	ob::log::write DEV {OB_MM_interface::send_xml_message: Using timeout: $timeout}

	if {$xml_msg == ""} {
		return ""
	}

	set auth [bintob64 [OT_CfgGet MM_CRED_AUTH_USER ""]:[OT_CfgGet MM_CRED_AUTH_PASS ""]]

	set MM_start_time [OT_MicroTime]

	if {[catch {set http_response\
		[http::geturl "[OT_CfgGet MM_FUNDS_CHECK_URL "/"]"\
			 -headers [list Authorization "Basic $auth"]\
			 -timeout $timeout\
			 -query [http::formatQuery xmlStr $xml_msg]]} msg]} {
		catch {http::cleanup $http_response}
		ob::log::write WARNING {OB_MM_interface::send_xml_message: Failed to contact [OT_CfgGet MM_FUNDS_CHECK_URL "/"] - xml=${xml_msg} - msg: $msg}
		return ""
	}

	# check ok
	set response [OB_MCS_utils::validateResponse $http_response]

	set MM_time [format "%.2f" [expr {[OT_MicroTime] - $MM_start_time}]]
	ob::log::write INFO "OB_MM_interface::send_xml_message: Request to MM took $MM_time"

	if {$response != "OK"} {
		catch {http::cleanup $http_response}
		ob::log::write WARNING {OB_MM_interface::send_xml_message: Problem with HTTP response code from [OT_CfgGet MM_FUNDS_CHECK_URL "/"] - xml=${xml_msg} - response: $response}

		# We now need to retain the http response code. This response may determine the processing that follows in later stages.
		set MM_DETAILS(http_error_response_code) $response

		return ""
	}

	# parse the data
	set xml_resp [http::data $http_response]

	# clean up the html
	http::cleanup $http_response

	ob::log::write INFO {OB_MM_interface::send_xml_message: XML Response: $xml_resp}

	return $xml_resp
}

##
# OB_MM_interface::build_funds_held_check_request_xml
#
# SYNOPSIS
#
#       [OB_MM_interface::build_funds_held_check_request_xml]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::build_funds_held_check_request_xml {username charset} {
	dom setResultEncoding "UTF-8"

	set dom_msg [OB_MM_interface::build_request_template_xml]
	set root_node [$dom_msg documentElement]

	set partner_id_node\
		[$root_node appendChild [$dom_msg createElement "partnerID"]]
	set username_node\
        [$root_node appendChild [$dom_msg createElement "partnerPlayerID"]]

	set partner_id_text_node  [$dom_msg createTextNode [OT_CfgGet MM_UOI -1]]
	set username_text_node    [$dom_msg createTextNode [encoding convertfrom $charset $username]]

	$partner_id_node appendChild $partner_id_text_node
	$username_node appendChild $username_text_node

	set xml_msg [$dom_msg asXML]
	$dom_msg delete

	return $xml_msg
}

##
# OB_MM_interface::parse_funds_held_check_response_xml
#
# SYNOPSIS
#
#       [OB_MM_interface::parse_funds_held_check_response_xml]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::parse_funds_held_check_response_xml {xml_msg} {
	global MM_DETAILS

	#
	# First, the response comes url encoded for some reason.

	set xml_msg [urldecode $xml_msg]

	ob::log::write WARNING {OB_MM_interface::parse_register_response_xml: Raw XML response: $xml_msg}

	# Produce a DOM tree first. The following means for parsing means that
	# memory is freed when dom goes out of scope.

	if {[catch {dom parse -simple $xml_msg doc} msg]} {
		ob::log::write WARNING {OB_MM_interface::parse_register_response_xml: Error parsing MM response XML: $msg}

		return [list 0 "General Error" MM_ERROR]
	}

	# Do a generic check on the message to see if it looks OK.

	if {![lindex [OB_MM_interface::general_response_xml_check $doc] 0]} {
	ob::log::write WARNING {OB_MM_interface::parse_register_response_xml: General response fail.}
		return [list 0 "General Error" MM_ERROR]
	}

	# Next, see if there's any <error/> nodes in the response XML.

	set failure_nodes [[$doc documentElement] selectNodes {//*/error}]

	if {[llength $failure_nodes] == 1} {
		# Get the error code and pass this back via error handling code.

		set MM_DETAILS(failure_reason)\
			[string trim [[[lindex $failure_nodes 0] selectNode "text()"] nodeValue]]

		return [list 0 "$MM_DETAILS(failure_reason)"]
	}

	# No failure has occurred if we get here, so try and get the XML node containing the
	# indication of held funds.

	if {[catch {
		foreach item {
			fundsHeld
		} {
			set MM_DETAILS($item)\
				[[[[$doc documentElement] getElementsByTagName $item]\
					  firstChild] nodeValue]

			ob::log::write WARNING {OB_MM_interface::parse_funds_held_check_response_xml - MM_DETAILS($item): $MM_DETAILS($item)}
		}
	} msg]} {
		# These elements are compulsory, so if they fail
		# the entire message is pretty useless!

		ob::log::write WARNING {OB_MM_interface::parse_funds_held_check_response_xml - Bad XML format.  Message is \n [[$doc documentElement] asXML]}

		return [list 0 "General Error" MM_ERROR]
	}

	return [list 1]
}

##
# OB_MM_interface::build_request_template_xml
#
# SYNOPSIS
#
#       [OB_MM_interface::build_request_template_xml]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::build_request_template_xml {} {
	dom setResultEncoding "UTF-8"

	set dom_msg   [dom createDocument "reqAccountFundsHeld"]
	set root_node [$dom_msg documentElement]

	return $dom_msg
}

##
# OB_MM_interface::general_response_xml_check
#
# SYNOPSIS
#
#       [OB_MM_interface::general_response_xml_check]
#
# SCOPE
#
#       private
#
# PARAMS
#
#       none
#
# RETURN
#
#       none
#
# DESCRIPTION
#
#
##

proc OB_MM_interface::general_response_xml_check {doc} {

	if {[[$doc documentElement] nodeName] != "respAccountFundsHeld"} {
		return [list 0 "Inavlid XML Response" MM_ERROR]
	}

	# The XML response looks good.

	return [list 1]
}

##############################################################################
#
# MM Enabled functions.
#
##############################################################################
proc OB_MM_interface::check_mm_enabled {} {
	return [OT_CfgGet MM_ENABLED 0]
}

# initialise Mahjong XML Interface when file is sourced.
OB_MM_interface::init
