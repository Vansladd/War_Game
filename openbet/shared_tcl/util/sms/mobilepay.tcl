# $Id: mobilepay.tcl,v 1.1 2011/10/04 12:27:28 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# Mobilepay namespace for sending SMS, pulls all it's setting from the array
# provided.
#
# No procedures in this namespace maybe called by procedures in any namespace
# with the exception of ob_sms.
#
# Synopsis:
#   package require util_sms_mobilepay ?4.5?
#
# Configuration:
#   SMS_MOBILEPAY_URL      - URL to post the request to.
#   SMS_MOBILEPAY_USER     - username.
#   SMS_MOBILEPAY_PASS     - password.
#   SMS_MOBILEPAY_AGENT    - agent (OpenBet).
#   SMS_MOBILEPAY_TIMEOUT  - timeout milliseconds (5000).
#   SMS_MOBILEPAY_TEST     - whether to test communications [0|1] (0).
#
# Procedures:
#   none
#
# See also:
#   www.npsl.co.uk
#   NPSL Mobile Toolkit v2 - Tier 1 Integration Document version 1.53
#

package provide util_sms_mobilepay 4.5



# Dependencies
#
package require http
package require tls
package require tdom
package require util_log
package require util_xml



# Variables
#
namespace eval ob_sms::_mobilepay {

	variable CFG
	variable INIT 0
}



# Initialise
#
proc ob_sms::_mobilepay::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	ob_log::init
	ob_xml::init

	http::register https 443 ::tls::socket

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		url "http://www.mobile-pay.co.uk:80/mobilepay/integration/tier1xml.asp"
		user      ""
		pass      ""
		useragent OpenBet
		timeout   5000
		test      0
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet SMS_MOBILEPAY_[string toupper $n] $v]
		}
	}

	if {$CFG(url) == ""} {
		error "Config item SMS_MOBILEPAY_URL must be specified"
	}

	if {$CFG(user) == ""} {
		error "Config item SMS_MOBILEPAY_USER must be specified"
	}

	if {$CFG(pass) == ""} {
		error "Config item SMS_MOBILEPAY_PASS must be specified"
	}

	if {$CFG(useragent) == ""} {
		error "Config item SMS_MOBILEPAY_USERAGENT must be specified"
	}

	if {![string is integer -strict $CFG(timeout)] || $CFG(timeout) < 0} {
		error "Config item SMS_MOBILEPAY_TIMEOUT is not an integer"
	}

	if {[lsearch {0 1} $CFG(test)] == -1} {
		error "Config item SMS_MOBILEPAY_TEST must be 0 or 1"
	}
}



# Sends a message using mobilepay. You can also specify a callback to be
# executed when the HTTP request is complete. If you do this you should take
# one or two things to mind. Firstly, you system may not support callbacks,
# in the case of an appserv, you probably don't want things happening cross
# request. Secondly, the callback may throw an error, to deal with this you
# must ensure that the procedure bgerror exists to deal with this. All in all,
# you may want to consider not using callback unless you have a good reason.
#
# Optional arguments are:
#   -command - a callback command to be excuted when the request is complete
#              this should be a procedure which takes a a least two arguments
#              which, when called, will contain the success of the message,
#              followed by any error message
#              To make the callback identifyable, add an argument with an
#              identifier in it (e.g. the mobile phone number)
#
# Example:
#
#   proc APP::test::sms_callback {mobile ok msg} {
#       if {$ok} {
#          ob_log::write INFO {sent message to $mobile ok}
#       } else {
#          ob_log::write ERROR {failed to send message to $mobile: $msg}
#       }
#   }
#
#   ob_sms::send -to 02012345678 -text "Test Message" -command \
#      [list APP::test::sms_callback 02012345678]
#
proc ob_sms::_mobilepay::_send {SMS_ARR} {

	variable CFG

	upvar 1 $SMS_ARR SMS

	set xml [_get_xml_request SMS]

	# must log all comms with third parties
	ob_log::write INFO {sms: xml=$xml}


	# this will be changed by other systems in the same app, we need to make
	# sure this is correct each time we get an url
	http::config -accept text/xml -useragent $CFG(useragent)


	# if we have a callback command specified we using the callback proc to
	# manage it
	if {[info exists SMS(command)]} {
		set token [http::geturl $CFG(url) -query $xml -type text/xml \
			-timeout $CFG(timeout) -headers [list X_OBUID [OT_UniqueId]] \
			-command [list ob_sms::mobilepay::_command $SMS(command)]]
		ob_log::write INFO {sms: mobilepay token $token is pending}
	} else {
		set token [http::geturl $CFG(url) -query $xml -type text/xml \
			-timeout $CFG(timeout)  -headers [list X_OBUID [OT_UniqueId]]]
		_complete $token
	}
}



# Deal with a callback.
#
#   token  - http token
#   throws - errors
#
proc ob_sms::_mobilepay::_complete {token} {

	# copy the contents of the state array
	set data   [http::data $token]
	set status [http::status $token]
	set ncode  [http::ncode $token]

	# clean up the request
	http::cleanup $token

	if {$status == "timeout"} {
		error "Message timed out (may have been delivered)"
	}

	# http transport failure
	if {$status != "ok" || $ncode != 200} {
		error "Failed to send SMS, status is not ok or ncode is not 200"
	}

	ob_log::write INFO {sms: data=$data}

	_parse_xml_response $data
}



# Manage a callback. This may request the procedure bgerror to specfied.
# You may not be able to do callbacks within an appserv.
#
#   command - command to callback
#   token   - HTTP token
#
proc ob_sms::_mobilepay::_command {command token} {

	ob_log::write INFO {sms: mobilepay callback for token $token occured}

	set caught [catch {
		_complete $token
	} msg]

	if {$caught} {
		ob_log::write ERROR {sms: failed to complete message: $msg}
	}

	if {[catch {
		# msg may, of course, be blank
		uplevel #0 $command [expr {!$caught}] $msg
	} msg]} {
		ob_log::write ERROR {sms: callback failed: $msg}
		error $msg $::errorInfo $::errorCode
	}
}



# Generate the XML request
#
#   SMS_ARR - name of array containing SMS request
#   returns - string of XML
#
proc ob_sms::_mobilepay::_get_xml_request {SMS_ARR} {

	variable CFG

	upvar 1 $SMS_ARR SMS

	# generate the xml request, we make an assuming that this may fail, but
	# this is not expected
	set declaration  {<?xml version="1.0"?>}

	set doc          [dom createDocument send]

	set send         [$doc documentElement]

	set authenticate [$doc createElement authenticate]

	$authenticate    setAttribute user $CFG(user) pass $CFG(pass)
	$send            appendChild $authenticate

	set sendtextmessage [$doc createElement sendtextmessage]
	$sendtextmessage setAttribute from $SMS(from)
	$send            appendChild $sendtextmessage

	set to           [$doc createElement to]
	$sendtextmessage appendChild $to

	set phone        [$doc createElement phone]
	# if the mode is test we prefix the number with the letter T
	$phone           setAttribute number \
		[expr {$CFG(test) ? {T} : {}}]$SMS(to)
	$to              appendChild $phone

	set messagetext  [$doc createElement messagetext]
	# we remove special chars from the text and replace them with
	# entitities
	set text         [string map {< &lt; > &gt;} $SMS(text)]
	$messagetext     appendChild [$doc createTextNode $text]
	$sendtextmessage appendChild $messagetext

	set xml    $declaration\n
	append xml [$doc asXML]

	$doc delete

	return $xml
}



# Parse the XML response
#
#   xml    - XML
#   throws - possible error
#
proc ob_sms::_mobilepay::_parse_xml_response {xml} {

	# parse the xml response to determine if any errors occured
	set doc    [ob_xml::parse $xml -novalidate]

	set caught [catch {

		set send   [$doc documentElement]

		# use xpath to get the status node, the xml repsonse
		# seems to differ in practice from the documentation
		set status [$send selectNodes sendtextmessage/status]

		set errors [$status getAttribute errors]

		if {$errors} {
			set statustext [$status getAttribute statustext]
		}
	} msg]

	$doc delete

	if {$caught} {
		error $msg $::errorInfo $::errorCode
	}

	if {$errors} {
		error $statustext
	}

	ob_log::write INFO {sms: No errors occured}
}

