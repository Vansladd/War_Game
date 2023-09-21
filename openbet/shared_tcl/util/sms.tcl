# $Id: sms.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C)2005 Orbis Technology Ltd. All rights reserved.

# Provides a system for sending SMS message using a third party gateway
# service.
#
# Configuration:
#   SMS_FROM     - The from address (OpenBet)
#   SMS_METHOD   - The gateway to use, essentially the third party. The
#                  gateways currently implemented are:
#
#                  * test
#                  * mobilepay
#
# Synopsis:
#   package require util_sms ?4.5?
#
# Procedures:
#   ob_sms::init - Initlialse
#   ob_sms::send - Send an SMS.
#
# Assumptions:
#   This implementation assume that SMS's are delivered by a third party.
#   That this third party uses http(s) and XML to comminuicate with openbet and
#   requires some kind of authentication details (e.g. username and password).
#   It also assumes that this communication is done using the http package, and
#   the XML is create and parsed using tdom. Specific implementations of SMS may
#   differ but there should be enough flexibility to manage this.
#

package provide util_sms 4.5



# Dependencies are loaded at init time.
#



# Variables
#
namespace eval ob_sms {

	variable CFG
	variable INIT 0
}



# Initilaise
#
proc ob_sms::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	set INIT 1

	ob_log::init

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} {
		gateway ""
		from   OpenBet
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet SMS_[string toupper $n] $v]
		}
	}

	if {$CFG(gateway) == ""} {
		error "Config item SMS_GATEWAY must be specified"
	}

	if {$CFG(from) == ""} {
		error "Config item SMS_FROM must be specified"
	}

	package require util_sms_$CFG(gateway)

	eval ob_sms::_$CFG(gateway)::init $args
}




# Send a single SMS text message.
# Other options maybe available for different gateways, and the documentation
# should be consulted regarding this.
#
# Example:
#
#   if {[catch {
#       ob_sms::send \
#          -to      07000123456                \
#          -text   "Congratulations, you have registered for SMS service." \
#    } msg]} {
#       ob_log::write ERROR {failed to send sms: $msg}
#    }
#
# Synopsis:
#   ob_sms::send ?-from string? -to string -text string
#
#   -from    - from number ($CFG(from))
#   -to      - to number
#   -text    - message to send via the SMS gateway
#
proc ob_sms::send args {

	variable CFG

	# if arguments are missing, then add them from the arguments
	# get the settings from the arguments
	foreach {n v} $args {
		set SMS([string trimleft $n -]) $v
	}

	if {![info exists SMS(from)]} {
		set SMS(from) $CFG(from)
	}

	# check that the required args are provided and not blank
	foreach required {from to text} {
		if {![info exists SMS($required)]} {
			error "$required is missing"
		}
		if {$SMS($required) == ""} {
			error "$required is blank"
		}
	}

	# delagate the call to a private namespace
	eval ob_sms::_$CFG(gateway)::_send SMS
}
