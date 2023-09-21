# $Id: test.tcl,v 1.1 2011/10/04 12:27:28 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.
#
# Provide a generic test namespace which doesn't do any communications
# and either returns success or failure on a round robin rotation.
#
# This a test namespace and can also be used as a template for new ones.
#
# No procedures in this namespace maybe called by procedures in any namespace
# with the exception of ob_sms.
#
# Synopsis:
#   package require util_sms_test ?4.5?
#
# Configuration:
#   none
#
# Procedures:
#   none
#

package provide util_sms_test 4.5



# Dependencies
#



# Variables
#
namespace eval ob_sms::_test {

	variable result 1
}



# Initilaise
#
proc ob_sms::_test::init args {
}



# Send a text message
#
#   SMS_ARR -  array of SMS details
#
proc ob_sms::_test::_send {SMS_ARR} {

	variable result

	set result [expr {!$result}]

	if {!$result} {
		error "Failed to send test message"
	}
}
