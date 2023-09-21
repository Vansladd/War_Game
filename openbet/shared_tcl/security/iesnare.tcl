# $Id: iesnare.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Synopsis:
#   package provide security_iesnare 4.5
#
# Procedures:
#   init                        one time initialisation
#   _prepare_qrys               Prepare the package queries
#   _auto_reset                 Determine if the package cache should be reloaded
#   CheckLogin                  Deprecated
#   CheckTransaction            subtitute of checkLogin. Adding functionality of velocity check
#   get                         Get a value from the package cache
#   get_all                     Get all previously set data from the package cache
#   set_value                   Set a value in the the package cache
#   set_value_transaction       Set value for transaction prior sending to Iovation
#   get_err                     Get the list of errors
#   add_err                     Add an error code to the error list
#   clear_err                   Clear the error list
#   _set_customer_flag          Set customer status flag
#   _pack_ioBegin               Build CheckLogin SOAP request message
#   _unpack_ioBegin             Parse CheckLoginResponse SOAP message data
#   _response_status            Record in logs the response status
#   _send_msg                   Sends a SOAP request to the IESNARE Device Reputation Authority
#   _suspend_customer           Suspend customers account
#   _pack_ioBegin_transaction   Build CheckTransaction SOAP request message
#   _unpack_ioBegin_transaction Parse CheckTransactionResponse SOAP message data
#   ieSnareCheck                Check against the device for suspicious customer
#   _get_evidence_details       (not currently used in Implementation stage 1)
#   bind_iesnare_links          Bind template strings (deprecated)
#   AddAccountEvidence          (not currently used in Implementation stage 1)
#   _get_config                 Get global and system level settings
#   _get_acct_config            Get account level settings
#   _check_settings_logic       Check config settings logic in required sequence
#   _get_cust_trig_count        Get count for customer trigger action count
#   _do_cust_stats              Increment trigger action count
#   _store_response             Store Iovation response
#   upd_response_with_ref       Update Iovation response table with reference

package provide security_iesnare 4.5


# Dependencies
#
package require tls
package require http 2.3
package require tdom
package require util_xml
package require util_log  4.5
package require util_db   4.5
package require util_crypt 4.5
package require net_util 4.5

# Variables
#
namespace eval ob_iesnare {

	variable CFG
	variable CFG_ACCT
	variable CFG_REQ

	#CHECKLOGIN: DATA, DATA_NAME and CHECK_FIELDS to remove if satisfied with checkTransaction
	variable DATA
	variable DATA_NAME

	#Parameters for the iovation request
	variable DATA_TRANSACTION
	variable DATA_TRANSACTION_NAME
	variable TRANSACTION_RESPONSE
	variable TRANSACTION_RESPONSE_NAME

	variable GET_ACTIVE_EVIDENCE_PARAM_NAMES

	variable INIT

	variable CHECK_FIELDS
	variable CHECK_FIELDS_TRANSACTION

	set CFG_REQ(req_id)  ""

	# init flag
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_iesnare::init args {

	variable CFG
	variable CFG_REQ

	#CHECKLOGIN: DATA, DATA_NAME and CHECK_FIELDS to remove if satisfied with checkTransaction
	variable DATA
	variable DATA_NAME

	variable DATA_TRANSACTION
	variable DATA_TRANSACTION_NAME
	variable TRANSACTION_RESPONSE
	variable TRANSACTION_RESPONSE_NAME

	variable INIT
	variable CHECK_FIELDS
	variable CHECK_FIELDS_TRANSACTION

	if {$INIT} {
		return
	}

	# init dependencies
	ob_log::init
	ob_db::init
	ob_crypt::init

	ob_log::write INFO {ob_iesnare: Initialising Iovation}

	set CFG(cache_time)  [OT_CfgGet IOVATION_CFG_CACHE 600]
	set CFG(channels)    [OT_CfgGet IOVATION_CFG_CHANNELS I]
	set CFG(api_timeout) [OT_CfgGet IOVATION_CFG_API_TIMEOUT 5000]

	if {[lsearch $CFG(channels) [OT_CfgGet CHANNEL I]] == -1} {
		ob_log::write INFO {ob_iesnare::init: channel [OT_CfgGet CHANNEL I] not supported}
		set CFG(chan_ok) 0
		return 0
	}
	set CFG(chan_ok) 1

	# prepare SQL queries
	_prepare_qrys

	# Get config items
	if {![_get_config]} {
		ob_log::write ERROR {failed to get iovation global config}
		return 0
	}

	#CHECKLOGIN: DATA, DATA_NAME and CHECK_FIELDS to remove if satisfied with checkTransaction

	set DATA_NAME [list \
		messageversion \
		sequence \
		usercode \
		enduserip \
		blackbox \
		subscriberid \
		adminusercode \
		status \
		rejectlogin \
		devicealias \
		trackingnumber \
	]


	set DATA_TRANSACTION_NAME [list \
		subscriberid \
		subscriberaccount \
		subscriberpasscode \
		enduserip \
		accountcode \
		beginblackbox \
		type \
	]


	set TRANSACTION_RESPONSE_NAME [list \
		result \
		reason \
		devicealias \
		trackingnumber \
		endblackbox \
		faultstring \
	]


	set CHECK_FIELDS [list \
		messageversion \
		sequence \
		usercode \
		enduserip \
		blackbox \
	]


	set CHECK_FIELDS_TRANSACTION [list \
		enduserip \
		accountcode \
		beginblackbox \
		type \
	]

	set INIT 1
}

rename reqGetEnv _reqGetEnv
proc reqGetEnv { v args } {
	switch -exact -- $v {
		"REMOTE_ADDR" {
			return [ob_net_util::get_best_guess_ip\
				[_reqGetEnv REMOTE_ADDR]\
				[_reqGetEnv HTTP_X_FORWARDED_FOR]\
				[OT_CfgGet CHECK_LOCAL_ADDR 1]\
			]
		}
		default {
			return [_reqGetEnv $v]
		}
	}
}

# Private procedure to prepare the package queries
#
proc ob_iesnare::_prepare_qrys {} {

	variable CFG

	ob_db::store_qry ob_iesnare::get_config {
		select first 1 *
		from
			tIovationCtrl
	} $CFG(cache_time)

	ob_db::store_qry ob_iesnare::get_trig_config {
		select
			trigger_type,
			enabled,
			freq_str,
			max_count
		from
			tIovTrigCtrl
	} $CFG(cache_time)

	ob_db::store_qry ob_iesnare::get_acct_config {
		select first 1
			enabled,
			freq_str,
			max_count
		from
			tCustIovTrigCtrl
		where
			cust_id      = ? and
			trigger_type = ?
	} $CFG(cache_time)

	ob_db::store_qry ob_iesnare::get_username {
		select username
		from tCustomer
		where cust_id = ?
	}

	ob_db::store_qry ob_iesnare::iesnare_suspend_customer {
		execute procedure pUpdCustStatus (
			p_cust_id         = ?,
			p_status          = 'S',
			p_status_reason   = ?
		)
	}

	ob_db::store_qry ob_iesnare::iesnare_set_status_flag {
		execute procedure pInsCustStatusFlag (
			p_cust_id = ?,
			p_status_flag_tag = ?,
			p_reason          = ?,
			p_transactional   = 'N'
		)
	}

	ob_db::store_qry ob_iesnare::iesnare_check_test_account_flag {
		select first 1
			cust_id
		from
			tcustomerflag
		where
			cust_id    = ?
		and flag_name='TEST_ACCOUNT'
		and flag_value='Y'
	}

	ob_db::store_qry ob_iesnare::get_acct_no {
		select first 1
			acct_no
		from
			tCustomer
		where
			cust_id = ?
	}

	ob_db::store_qry ob_iesnare::get_acct_id {
		select first 1
			acct_id
		from
			tAcct
		where
			cust_id = ?
	}

	ob_db::store_qry ob_iesnare::get_cust_trig_count {
		select
			nvl(cs.count,0) count
		from
			tAcct            a,
			tCustStats       cs,
			tCustStatsAction csa
		where
			a.cust_id       = ?            and
			cs.acct_id      = a.acct_id    and
			cs.source       = ?            and
			csa.action_id   = cs.action_id and
			csa.action_name = ?
	}

	ob_db::store_qry ob_iesnare::do_cust_stats {
		execute procedure pDoCustStats (
			p_acct_id     = ?,
			p_action_name = ?,
			p_ref_id      = ?,
			p_source      = ?
		)
	}

	ob_db::store_qry ob_iesnare::ins_iov_response {
		execute procedure pInsIovResponse (
			p_cust_id         = ?,
			p_device_alias    = ?,
			p_tracking_number = ?,
			p_response        = ?,
			p_trigger_type    = ?,
			p_ref_key         = ?,
			p_ref_id          = ?
		)
	}

	ob_db::store_qry ob_iesnare::upd_iov_response {
		execute procedure pUpdIovResponse (
			p_resp_id = ?,
			p_ref_key = ?,
			p_ref_id  = ?
		)
	}
}


#--------------------------------------------------------------------------
# Request Initialisation
#--------------------------------------------------------------------------

# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_iesnare::_auto_reset args {

	variable CFG_REQ
	#CHECKLOGIN: DATA, DATA_NAME and CHECK_FIELDS to remove if satisfied with checkTransaction
	variable DATA
	variable DATA_NAME

	variable DATA_TRANSACTION
	variable DATA_TRANSACTION_NAME
	variable TRANSACTION_RESPONSE
	variable TRANSACTION_RESPONSE_NAME


	set id [reqGetId]

	if {$CFG_REQ(req_id) != $id} {
		array unset CFG_REQ
		set CFG_REQ(req_id) $id
		set CFG_REQ(errors) [list]

		#CHECKLOGIN: DATA, DATA_NAME and CHECK_FIELDS to remove if satisfied with checkTransaction
		if {[info exists DATA]} {
			array unset DATA
			foreach n $DATA_NAME {
				set DATA($n) ""
			}
		}

		if {[info exists DATA_TRANSACTION]} {
			array unset DATA_TRANSACTION
			foreach n $DATA_TRANSACTION_NAME {
				set DATA_TRANSACTION($n) ""
			}
		}

		if {[info exists TRANSACTION_RESPONSE]} {
			array unset TRANSACTION_RESPONSE
			foreach n $TRANSACTION_RESPONSE_NAME {
				set TRANSACTION_RESPONSE($n) ""
			}
		}

		ob_log::write DEBUG {*** ob_iesnare::_auto_reset cache, req_id=$id}
		return 1
	}

	# already loaded
	return 0
}

#-------------------------------------------------------------------------
#  Build the CheckLogin SOAP message to send to the Device
#  Reputation Authority. Parse the CheckLoginResponse to tcl
#  and decide whether to register customer Active or Suspended
#  It is going to be substituted by CheckTransaction
#-------------------------------------------------------------------------
proc ob_iesnare::CheckLogin args {

	variable CFG
	variable CFG_REQ
	variable DATA

	ob_log::write DEBUG {*** iesnare::CheckLogin ***}

	# reset data?
	_auto_reset

	# Build the CheckLogin XML message from DeviceID client data
	set request [_pack_ioBegin]

	# Send the message to ieSnare Server for
	# verification and collect the response
	set response [_send_msg $request $CFG(check_url)]
	ob_log::write DEV {*** iesnare : CheckLogin SOAP response=$response ***}

	if { $response != "" && [lindex $response 0] != "IOV_ERR"} {
		set DATA(status)      0
		set DATA(rejectlogin) 0
		_unpack_ioBegin $response

		# If the return code of the iesnare check indicated
		# an error of some form, log the error and leave the
		# customer registered as they were.
		if {$DATA(status) > 0} {
			_response_status
		} elseif {$DATA(rejectlogin) > 0} {
			_suspend_account
			return 1
		}
	}
	return 0
}




#-------------------------------------------------------------------------
#  Build the CheckLogin SOAP message to send to the Device
#  Reputation Authority. Parse the CheckLoginResponse to tcl
#  and decide whether to register customer Active or Suspended
#  Returns a list:
#    OK ACCEPT   - on ACCEPT response from Iovation
#    OK REVIEW   - on REVIEW response from Iovation
#    OK DENY     - on DENY response from Iovation
#    ERR err_msg - on error
#-------------------------------------------------------------------------
proc ob_iesnare::CheckTransaction args {

	variable CFG
	variable CFG_REQ
	variable CFG_ACCT
	variable TRANSACTION_RESPONSE
	variable DATA_TRANSACTION

	ob_log::write DEV {*** iesnare::CheckTransaction ***}

	catch {unset TRANSACTION_RESPONSE}

	# reset data cache?
	_auto_reset

	# to indicate the error if blackbox value was invalid
	set TRANSACTION_RESPONSE(invalid_bb) 0

	# Build the CheckTransaction XML message from DeviceID client data
	set request [_pack_ioBegin_transaction]

	# Send the message to ieSnare Server for
	# verification and collect the response
	set response [_send_msg $request $CFG(check_url)]
	ob_log::write DEV {*** iesnare : CheckTransaction SOAP response= $response ***}

	if { $response != "" } {

		if {[lindex $response 0] == "IOV_ERR"} {
			if {[lindex $response 1] == "CONN_TIMEOUT"} {
				ob_log::write ERROR {IESNARE: Iovation API connection timed out}
				return [list ERR CONN_TIMEOUT]
			} elseif {[lindex $response 1] == "REQ_TIMEOUT"} {
				ob_log::write ERROR {IESNARE: Iovation API request timed out}
				return [list ERR REQ_TIMEOUT]
			} else {
				ob_log::write ERROR {IESNARE: Iovation send message error}
				return [list ERR IOV_ERR]
			}
		}

		_unpack_ioBegin_transaction $response

		ob_log::write INFO {IESNARE: result of the iovation check: \
			$TRANSACTION_RESPONSE(result)}

		set cust_id $CFG_ACCT(cust_id)

		# customer status flag reasons
		set set_flag_reason_empty   "Incomplete Iovation check returned"
		set set_flag_reason_invalid "Corrupt/Invalid Iovation check returned"
		set set_flag_reason_review  "Iovation Review response returned"
		set set_flag_reason_deny    "Iovation Deny response returned"

		set bb_empty 0
		set _override_result [OT_CfgGet IOVATION_CFG_EMPTY_BB_RESULT "R"]

		# we have sent an empty blackbox and received an 'A'ccept response
		if {$DATA_TRANSACTION(beginblackbox) == "" &&
			$TRANSACTION_RESPONSE(result) == "A"
		} {
			ob_log::write INFO {IESNARE: TRANSACTION RESPONSE IS **ACCEPT**, \
				empty blackbox has been sent}

			if {$_override_result != "A"} {
				ob_log::write INFO {IESNARE: override with '$_override_result'}

				# set flag to store specific reason
				set bb_empty 1

				# override with configured result
				set TRANSACTION_RESPONSE(result) $_override_result

			} else {
				ob_log::write INFO {IESNARE: do not override result}
			}
		}

		# If the return code of the iesnare check indicated
		# an error of some form, log the error and leave the
		# customer registered as they were.
		if {$TRANSACTION_RESPONSE(result) == "A"} {
			# Allow - customer passed check
			ob_log::write DEV {IESNARE: TRANSACTION RESPONSE IS **ACCEPT**}
			return [list OK ACCEPT]
		} elseif {$TRANSACTION_RESPONSE(result) == "R"} {
			# Review - set customer status flag of
			# "Review Fraud Check" along with reason code.
			ob_log::write DEV {IESNARE: TRANSACTION RESPONSE IS **REVIEW**}

			if {$bb_empty} {
				_set_customer_flag $cust_id "FRAUD_CHK" $set_flag_reason_empty
			} else {
				_set_customer_flag $cust_id "FRAUD_CHK" $set_flag_reason_review
			}

			return [list OK REVIEW]
		} elseif {$TRANSACTION_RESPONSE(result) == "D"} {
			# Deny - suspend account, and set customer status flag of
			# "Fraud Check Failed" along with reason code.
			ob_log::write DEV {IESNARE: TRANSACTION RESPONSE IS **DENY**}

			if {$bb_empty} {
				_set_customer_flag $cust_id "FRAUD" $set_flag_reason_empty
				_suspend_customer  $cust_id         $set_flag_reason_empty
			} else {
				_set_customer_flag $cust_id "FRAUD" $set_flag_reason_deny
				_suspend_customer  $cust_id         $set_flag_reason_deny
			}

			return [list OK DENY]
		} else {

			if {$TRANSACTION_RESPONSE(result) != ""} {
				ob_log::write ERROR {IESNARE: Unknown Iovation result \
					"$TRANSACTION_RESPONSE(result)" received}
			}

			if {$TRANSACTION_RESPONSE(faultstring) != ""} {

				# log an error received from Iovation
				ob_log::write ERROR {IESNARE: Error received from Iovation: \
					$TRANSACTION_RESPONSE(faultstring)}

				# check if this is the "invalid blackbox" error message

				# error string in the message
				set err_str "Invalid parameter beginblackbox"

				set _err_str     [string toupper $err_str]
				set _faultstring [string toupper \
											$TRANSACTION_RESPONSE(faultstring)]

				if {[string first $_err_str $_faultstring] != -1} {
					# it is

					ob_log::write INFO {IESNARE: \
						Error - Invalid parameter beginblackbox}

					set TRANSACTION_RESPONSE(invalid_bb) 1

					_set_customer_flag $cust_id "FRAUD_CHK" \
						$set_flag_reason_invalid

					# WH requirement: return REVIEW response in this case
					return [list OK REVIEW]
				}
			}

			return [list ERR "Error occured after parsing Iovation response"]
		}
	}

	ob_log::write ERROR {IESNARE: Iovation response is empty}
	return [list ERR IOV_ERR]
}

#--------------------------------------------------------------------------
# Data Procs
#--------------------------------------------------------------------------

# Get a value from the package cache
#
proc ob_iesnare::get {name} {

	variable DATA_NAME
	variable DATA

	# reset data?
	_auto_reset

	if {[lsearch -exact $DATA_NAME $name] != -1} {
		return $DATA($name)
	}

	return ""
}

# Get all previously set data from the package cache
#
proc ob_iesnare::get_all args {

	variable DATA_NAME
	variable DATA

	# reset data?
	_auto_reset

	set D(names) ""
	foreach n $DATA_NAME {
		if {$DATA($n) != ""} {
			lappend D(names) $n
			set D($n) $DATA($n)
		}
	}

	return [array get D]
}

# Set a value in the the package cache
#
proc ob_iesnare::set_value {name value} {

	variable DATA_NAME
	variable DATA

	# reset data?
	_auto_reset

	# removing leading and trailing space
	set value [string trim $value]

	if {[lsearch -exact $DATA_NAME $name] != -1} {

		ob_log::write DEV {*** ob_iesnare::set_value name=$name value=$value ***}
		# Add the field
		set DATA($name) $value
	}
}


# Set a value in the the package cache from Iovation response
#
proc ob_iesnare::set_value_transaction {name value} {
	variable DATA_TRANSACTION
	variable DATA_TRANSACTION_NAME

	# reset data?
	_auto_reset

	# removing leading and trailing space
	set value [string trim $value]

	if {[lsearch -exact $DATA_TRANSACTION_NAME $name] != -1} {

		ob_log::write DEV {*** ob_iesnare::set_value transaction name=$name value=$value ***}
		# Add the field
		set DATA_TRANSACTION($name) $value
	}
}


#---------------------------------------------------------------------------
#   Error handling routines
#---------------------------------------------------------------------------
#

# Get the list of error[s].
#
#   returns - list of errors, or an empty list if no errors
#             format {{error-code args} {error-code args} ...}
#
proc ob_iesnare::get_err args {

	variable CFG_REQ

	# reset data?
	_auto_reset

	return $CFG_REQ(errors)
}

# Add an error code to the error list.
#
#   code    - error code
#   field   - the field where the error occurred
#   returns - error code
#
proc ob_iesnare::add_err { code } {

	variable CFG_REQ

	# reset data?
	_auto_reset

	ob_log::write ERROR {*** iesnare : ERROR code=$code ***}

	set found 0

	# Need to guarantee duplicate code/field combinations
	# do not exist within the error list. Only add the
	# combination if it is not already present in the list.
	foreach e $CFG_REQ(errors) {
		if {$e == $code} {
			set found 1
			break
		}
	}

	if {!$found} {
		lappend CFG_REQ(errors) $code
	}

	return $code
}


# Clear the error list
#
proc ob_iesnare::clear_err args {

	variable CFG_REQ

	# reset data?
	_auto_reset

	set CFG_REQ(errors) [list]
}


#-------------------------------------------------------------
#  Private procs
#-------------------------------------------------------------


proc ob_iesnare::_set_customer_flag { cust_id flag_name reason } {

	if {[catch {ob_db::exec_qry ob_iesnare::iesnare_set_status_flag $cust_id $flag_name $reason} msg]} {
		ob_log::write INFO {*** ERROR ob_iesnare::_set_customer_flag : cust_id=$cust_id, flag_name=$flag_name,  : $msg ***}
	}

}

# Build CheckLogin SOAP message
#
#
# --Envelope
#      |
#      --Body
#          |
#          --CheckLogin
#                  |
#                  --messageversion
#                  |
#                  --sequence
#                  |
#                  --enduserip
#                  |
#                  --blackbox
#                  |
#                  --subscriberid
#                  |
#                  --adminusercode
#
proc ob_iesnare::_pack_ioBegin args {

	variable DATA_NAME
	variable DATA
	variable CHECK_FIELDS
	variable CFG

	ob_log::write DEBUG {*** ob_iesnare::_pack_ioBegin                 \
							messageversion=$DATA(messageversion)       \
							sequence=$DATA(sequence)                   \
							usercode=$DATA(usercode)                   \
							enduserip=$DATA(enduserip)                 \
							blackbox=$DATA(blackbox)                   \
							subscriberid=$CFG(subscriberid)            \
							adminusercode=$CFG(adminusercode)          \
							iesnare_url=$CFG(check_url) ***}

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set CHECK_LOGIN_XML_DOM [dom createDocument "soapenv:Envelope"]

	# Request
	set envelope [$CHECK_LOGIN_XML_DOM documentElement]

	#Different xml namespace for log and check messages
	$envelope setAttribute \
		"xmlns:xsi"     "http://www.w3.org/2001/XMLSchema-instance"  \
		"xmlns:xsd"     "http://www.w3.org/2001/XMLSchema"           \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/"  \
		"xmlns:soap"    "$CFG(check_url)/Snare/Handler/Soap"

	set body [$CHECK_LOGIN_XML_DOM createElement "soapenv:Body"]
	$envelope appendChild $body

	set checklogin [$CHECK_LOGIN_XML_DOM createElement "soap:CheckLogin"]
	$checklogin setAttribute "soapenv:encodingStyle" "http://schemas.xmlsoap.org/soap/encoding/"

	$body appendChild $checklogin

	foreach e $CHECK_FIELDS {
		set subnode [$CHECK_LOGIN_XML_DOM createElement $e]
		$subnode setAttribute "xsi:type" "xsd:string"
		$subnode appendChild [$CHECK_LOGIN_XML_DOM createTextNode $DATA($e)]
		$checklogin appendChild $subnode
	}

	foreach c {adminusercode subscriberid} {
		set subnode [$CHECK_LOGIN_XML_DOM createElement $c]
		$subnode setAttribute "xsi:type" "xsd:string"
		$subnode appendChild [$CHECK_LOGIN_XML_DOM createTextNode $CFG($c)]
		$checklogin appendChild $subnode
	}

	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$CHECK_LOGIN_XML_DOM asXML]"

	ob_log::write DEV {*** ob_iesnare::_pack_ioBegin request xml_msg=$xml_msg ***}

	catch {$CHECK_LOGIN_XML_DOM delete}

	return $xml_msg
}

# Parse CheckLoginResponse SOAP message data
#
#
# --Envelope
#      |
#      --Body
#          |
#          --CheckLoginResponse
#                  |
#                  --status
#                  |
#                  --messageversion
#                  |
#                  --sequence
#                  |
#                  --rejectlogin
#
proc ob_iesnare::_unpack_ioBegin {{xml ""}} {

	variable DATA_NAME
	variable DATA

	ob_log::write DEBUG {*** ob_iesnare::_unpack_ioBegin xml=$xml ***}

	if {[catch {set CHECK_LOGIN_RSP_XML_DOM [dom parse $xml]} msg]} {
		ob_log::write ERROR {*** ob_iesnare : unable to parse xml ($msg): $xml ***}
		return
	}

	set Response [$CHECK_LOGIN_RSP_XML_DOM documentElement]

	ob_log::write DEV {*** ob_iesnare : Found document root Response=$Response ***}

	# Response/SOAP-ENV:Envelope/soap:Bodynamesp4:CheckLoginResponse/
	set Body [$Response selectNodes /SOAP-ENV:Envelope/SOAP-ENV:Body]
	set Inner_Body [$Body firstChild]

	# Parse the data from the XML response elements
	foreach elem_node [$Inner_Body childNodes] {
		set node_name [$elem_node nodeName]
		set node_data [$elem_node selectNodes text()]
		set node_text [$node_data nodeValue]
		ob_log::write DEBUG {*** ob_iesnare::_unpack_ioBegin *~*~ Response Children node_name=$node_name node_data=$node_text ***}

		foreach d $DATA_NAME {
			if {[string last $d $node_name] != -1} {
				set DATA($d) $node_text
				ob_log::write DEBUG {*** Saving response data to array DATA($d)=$DATA($d) ***}
				break
			}
		}
	}

	# binding template strings/variables is deprecated
	#tpBindString IESNARE_blackbox        $DATA(blackbox)
	#tpBindString IESNARE_blackbox_urlenc [urlencode $DATA(blackbox)]

	catch {$CHECK_LOGIN_RSP_XML_DOM delete}
}

# An erroneous status was returned from
# ieSnare Device Reputation Authority.
# Determine the error and log it for
# support purposes
#
proc ob_iesnare::_response_status args {

	variable DATA

	switch -exact -- $DATA(status) {
		"1" {
			ob_log::write ERROR {IESNARE: The subscriberid provided is invalid.}
		}
		"2" {
			ob_log::write ERROR {IESNARE: The message version was either\
				missing or not a supported version number.}
		}
		"3" {
			ob_log::write ERROR {IESNARE: adminusercode was missing}
		}
		"4" {
			ob_log::write ERROR {IESNARE: The Blackbox was corrupted due to\
				transmission failure, buffer truncation, or some other cause.}
		}
		"5" {
			ob_log::write ERROR {IESNARE: The subscriberid could not be found.}
		}
		"7" {
			ob_log::write ERROR {IESNARE: The combination of subscriberid and\
				adminusercode is not valid.}
		}
		"8" {
			ob_log::write ERROR {IESNARE: General Server error. An error\
				occurred while processing the request.}
		}
		"9" {
			ob_log::write ERROR {IESNARE: No usercode or devicealias provided.\
				No information was provided to generate a response.}
		}
		"10" {
			ob_log::write ERROR {IESNARE: The subscriberid usercode combination\
				could not be found.}
		}
		"11" {
			ob_log::write ERROR {IESNARE: Device alias could not be found.}
		}
		"99" {
			ob_log::write ERROR {IESNARE: The Device Reputation Authority\
				Server is offline due to scheduled maintenance.}
		}
		default {
			ob_log::write ERROR {IESNARE: An undefined error has occurred\
				during the iesnare checking process}
		}
	}
}

# Sends a SOAP request to the IESNARE Device Reputation Authority
# NOTE: All errors from this procedure should be caught and the HTTP token deleted
#
#   request     - XML request to be sent
#   returns:
#               if successful - response message body
#               if failed     - IOV_ERR
#
proc ob_iesnare::_send_msg {request url} {

	variable CFG
	variable CFG_REQ
	variable DATA

	set fn "ob_iesnare::_send_msg"

	set req_log [ob_xml::mask_nodes $request [list adminpassword subscriberpasscode]]
	ob_log::write INFO {*** ob_iesnare::_send_msg request=$req_log url=$url***}

	set time_started [OT_MicroTime]

	if {[catch {
		foreach {api_scheme api_host api_port action junk junk} \
		  [ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {$fn: bad URL: $msg}
		return "IOV_ERR"
	}

	set headerList [list\
		"Content-Type" "text/xml; charset=utf-8"\
	]

	if {[catch {
		set req [ob_socket::format_http_req \
			-host       $api_host \
			-method     "POST" \
			-post_data  $request \
			-headers    $headerList \
			-encoding   "utf-8" \
			$action]
	} msg]} {
		ob_log::write ERROR {$fn: Unable to build request: $msg}
		return "IOV_ERR"
	}

	if {[catch {
		foreach {req_id status complete} \
		  [ob_socket::send_req \
		    -tls          1 \
		    -is_http      1 \
		    -conn_timeout $CFG(api_timeout) \
		    -req_timeout  $CFG(api_timeout) \
		    $req \
			$api_host \
			$api_port \
		] {break}
	} msg]} {
		ob_log::write ERROR {$fn: Unsure whether request reached Iovation: $msg}
		return "IOV_ERR"
	}

	if {$status != "OK"} {

		# Is there a chance this request might actually have got to Iovation?
		if {[ob_socket::server_processed $req_id]} {

			set response [ob_socket::req_info $req_id http_body]
			set response [string trim $response]

			ob_log::write ERROR {$fn:\
				Unsure whether request reached Iovation,\
				status: $status, response body:\n$response}

			ob_socket::clear_req $req_id
			return "IOV_ERR"

		} else {

			ob_log::write ERROR {$fn:\
				Unable to send request to Iovation, status: $status}

			ob_socket::clear_req $req_id
			return [list IOV_ERR $status]
		}
	}

	# Request successful - get the response data.
	ob_log::write INFO {$fn: Request successful}

	set response [ob_socket::req_info $req_id http_body]
	set response [string trim $response]

	ob_socket::clear_req $req_id

	return $response
}

# This account should be suspended upon
# iesnare's recomendation.
#
proc ob_iesnare::_suspend_customer {cust_id reason} {

	variable CFG_REQ
	variable DATA
	variable DATA_TRANSACTION

	if {[catch {
		ob_db::exec_qry ob_iesnare::iesnare_suspend_customer $cust_id $reason
	} msg]} {
		ob_log::write ERROR {*** ERROR ob_iesnare : iesnare_suspend_customer\
			query failed cust_id=$cust_id reason=$reason: $msg ***}
	}

	if {$CFG_REQ(errors) != ""} {
		ob_log::write ERROR {*** iesnare : ERROR [get_err]}
	}
}


#-------------------------------------------------------------
#  Private procs for checkTransaction
#-------------------------------------------------------------


# Build CheckTransaction SOAP message
#
# --Envelope
#      |
#      --Body
#          |
#          --CheckTransaction
#                  |
#                  --subscriberid
#                  |
#                  --subscriberaccount
#                  |
#                  --subscriberpasscode
#                  |
#                  --enduserip
#                  |
#                  --accountcode
#                  |
#                  --beginblackbox
#                  |
#                  --type (Optional)
#
proc ob_iesnare::_pack_ioBegin_transaction args {

	variable DATA_TRANSACTION
	variable DATA_TRANSACTION_NAME
	variable CHECK_FIELDS_TRANSACTION
	variable CFG

	ob_log::write DEBUG {*** ob_iesnare::_pack_ioBegin_transaction \
							subscriberid=$CFG(subscriberid)       \
							subscriberaccount=$CFG(subscriberaccount) \
							enduserip=$DATA_TRANSACTION(enduserip) \
							accountcode=$DATA_TRANSACTION(accountcode) \
							beginblackbox=$DATA_TRANSACTION(beginblackbox) \
							iesnare_url=$CFG(check_url) ***}

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set CHECK_TRANSACTION_XML_DOM [dom createDocument "soapenv:Envelope"]

	# Request
	set envelope [$CHECK_TRANSACTION_XML_DOM documentElement]

	#Different xml namespace for log and check messages
	$envelope setAttribute \
		"xmlns:xsi"     "http://www.w3.org/2001/XMLSchema-instance"  \
		"xmlns:xsd"     "http://www.w3.org/2001/XMLSchema"           \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/"  \
		"xmlns:soap"    "$CFG(check_url)/Snare/Handler/Soap"

	set body [$CHECK_TRANSACTION_XML_DOM createElement "soapenv:Body"]
	$envelope appendChild $body

	set checkTransaction [$CHECK_TRANSACTION_XML_DOM createElement "soap:CheckTransaction"]
	$checkTransaction setAttribute "soapenv:encodingStyle" "http://schemas.xmlsoap.org/soap/encoding/"

	$body appendChild $checkTransaction

	foreach c {subscriberid subscriberaccount subscriberpasscode} {
		set subnode [$CHECK_TRANSACTION_XML_DOM createElement $c]
		$subnode setAttribute "xsi:type" "xsd:string"
		$subnode appendChild [$CHECK_TRANSACTION_XML_DOM createTextNode $CFG($c)]
		$checkTransaction appendChild $subnode
	}


	foreach e $CHECK_FIELDS_TRANSACTION {
		set subnode [$CHECK_TRANSACTION_XML_DOM createElement $e]
		$subnode setAttribute "xsi:type" "xsd:string"

		if {[info exists DATA_TRANSACTION($e)]} {
			$subnode appendChild [$CHECK_TRANSACTION_XML_DOM createTextNode $DATA_TRANSACTION($e)]
		} else {
			$subnode appendChild [$CHECK_TRANSACTION_XML_DOM createTextNode ""]
		}
		$checkTransaction appendChild $subnode
	}


	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$CHECK_TRANSACTION_XML_DOM asXML]"

	catch {$CHECK_TRANSACTION_XML_DOM delete}

	ob_log::write DEV {ob_iesnare::_pack_ioBegin_transaction: xml_msg =\n$xml_msg}
	return $xml_msg
}




# Parse Iovation response
#
proc ob_iesnare::_unpack_ioBegin_transaction {{xml ""}} {

	variable TRANSACTION_RESPONSE
	variable TRANSACTION_RESPONSE_NAME

	set fn "ob_iesnare::_unpack_ioBegin_transaction"

	# initialise response array with empty strings
	foreach d $TRANSACTION_RESPONSE_NAME {
		set TRANSACTION_RESPONSE($d) ""
	}

	ob_log::write DEBUG {$fn: xml =\n$xml}

	if {[catch {set CHECK_TRANSACTION_RSP_XML_DOM [dom parse $xml]} msg]} {
		ob_log::write ERROR {$fn: unable to parse xml ($msg): $xml}
		return
	}

	set Response [$CHECK_TRANSACTION_RSP_XML_DOM documentElement]

	ob_log::write DEV {$fn: Found document root Response =\n$Response}

	# Response/SOAP-ENV:Envelope/soap:Bodynamesp4:CheckTransactionResponse/
	set Body [$Response selectNodes /SOAP-ENV:Envelope/SOAP-ENV:Body]
	set Inner_Body [$Body firstChild]

	# Parse the data from the XML response elements
	foreach elem_node [$Inner_Body childNodes] {
		set node_name [$elem_node nodeName]
		set node_data [$elem_node selectNodes text()]
		if {$node_data != ""} {
			set node_text [$node_data nodeValue]
		} else {
			set node_text ""
		}
		#ob_log::write DEBUG {*** ob_iesnare::_unpack_ioBegin *~*~ Response Children node_name=$node_name node_data=$node_text ***}

		foreach d $TRANSACTION_RESPONSE_NAME {
			if {[string last $d $node_name] != -1} {
				set TRANSACTION_RESPONSE($d) $node_text
				ob_log::write DEBUG {$fn: Saving response data to array TRANSACTION_RESPONSE($d) = $TRANSACTION_RESPONSE($d)}
			}
		}
	}

	# binding template strings/variables is deprecated
	#tpBindString IESNARE_blackbox        $TRANSACTION_RESPONSE(endblackbox)
	#tpBindString IESNARE_blackbox_urlenc [urlencode $TRANSACTION_RESPONSE(endblackbox)]

	catch {$CHECK_TRANSACTION_RSP_XML_DOM delete}
}


#
# Bind and Transaction
#

#
# Iovation - Check against the Device for potentially suspicious/fraudulent customer registration
#
# Returns a list:
#    OK  STOP            - on stop
#    OK  ACCEPT  resp_id - on ACCEPT response from Iovation
#    OK  REVIEW  resp_id - on REVIEW response from Iovation
#    OK  DENY    resp_id - on DENY response from Iovation
#    ERR err_msg         - on error
proc ::ob_iesnare::ieSnareCheck {
	cust_id
	blackbox
	trigger_type
	{ref_key ""}
	{ref_id ""}
} {

	variable CFG
	variable CFG_ACCT
	variable TRANSACTION_RESPONSE

	# Check if channel is supported
	if {!$CFG(chan_ok)} {
		ob_log::write INFO {ob_iesnare::ieSnareCheck: channel [OT_CfgGet CHANNEL I] not supported}
		return [list OK STOP]
	}

	# refresh config
	if {![_get_config]} {
		ob_log::write ERROR {ob_iesnare::ieSnareCheck: failed to get iovation global config}
		return [list ERR IOV_ERR]
	}

	# check Iovation settings logic
	foreach {result code} [_check_settings_logic $cust_id $trigger_type] {}
	if {$result != 1} {
		ob_log::write ERROR {ob_iesnare::ieSnareCheck: failed to check iovation settings logic: [lindex $result 1]}
		return [list ERR IOV_ERR]
	} elseif {$code == 0} {

		# increase trigger action count now
		set _res [_do_cust_stats $cust_id $trigger_type]

		ob_log::write INFO {ob_iesnare::_check_settings_logic: STOP action received}
		return [list OK STOP]
	}

	# Check if cust_id is a test account, and if so do not perform the Iovation check
	if {[catch {set rs [ob_db::exec_qry ob_iesnare::iesnare_check_test_account_flag $cust_id]} msg]} {
		ob_log::write ERROR {ob_iesnare::ieSnareCheck: Error executing ob_iesnare::iesnare_check_test_account_flag : $msg}
		return [list ERR IOV_ERR]
	} elseif { [db_get_nrows $rs] } {
		# Account is flagged as test - return
		ob_log::write DEBUG {ob_iesnare::ieSnareCheck: Account looks like a test account with at least 1 flag, setting Iovation to passed and returning... }

		# increase trigger action count now
		set _res [_do_cust_stats $cust_id $trigger_type]

		return [list OK STOP]
	}

	ob_log::write DEBUG {*** ob_iesnare::ieSnareCheck ***}

	# Not using remote address as it will just return a proxy
	set end_user_ip [ob_net_util::get_best_guess_ip [_reqGetEnv REMOTE_ADDR] [_reqGetEnv HTTP_X_FORWARDED_FOR] [OT_CfgGet CHECK_LOCAL_ADDR 1]]

	# replace spaces with +
	set blackbox [string map {{ } {+}} $blackbox]

	# get acct_no
	set rs [ob_db::exec_qry ob_iesnare::get_acct_no $cust_id]
	set acct_no [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	ob_iesnare::set_value messageversion "3.0"
	ob_iesnare::set_value sequence      $acct_no
	ob_iesnare::set_value usercode      $acct_no ;# Possibly deprecated - only used with CheckLogin
	ob_iesnare::set_value enduserip     $end_user_ip
	ob_iesnare::set_value blackbox      $blackbox

	ob_iesnare::set_value_transaction   enduserip     $end_user_ip
	ob_iesnare::set_value_transaction   beginblackbox $blackbox
	ob_iesnare::set_value_transaction   accountcode   $acct_no

	if {![info exists CFG(map,$trigger_type)]} {
		ob_log::write DEBUG {*** ERROR ob_iesnare::ieSnareCheck - unexpected rule type: $trigger_type ***}
		ob_log::write ERROR {ob_iesnare::ieSnareCheck - unexpected rule type: $trigger_type}
		return [list ERR IOV_ERR]
	}
	ob_iesnare::set_value_transaction   type          $CFG(map,$trigger_type)

	foreach {check_status code} [ob_iesnare::CheckTransaction] {}
	ob_log::write DEV {*** ob_iesnare::ieSnareCheck: CheckTransaction returned: check_status = $check_status code = $code ***}

	if {$code == "CONN_TIMEOUT" || $code == "REQ_TIMEOUT"} {
		# requirement: A timeout must be treated as an accept
		ob_log::write INFO {ob_iesnare::ieSnareCheck: on API timeout return\
			response as ACCEPT}
		return [list OK ACCEPT ""]
	}

	if {$TRANSACTION_RESPONSE(invalid_bb)} {
		return [list OK $code ""]
	}

	# increase trigger action count now
	set _res [_do_cust_stats $cust_id $trigger_type]

	if {$check_status == "OK"} {

		# store Iovation response
		foreach {store_status store_result} [_store_response $cust_id $trigger_type $ref_key $ref_id] {}

		set resp_id ""
		if {$store_status == 1} {
			set resp_id $store_result
		}

		return [list OK $code $resp_id]
	}

	return [list ERR IOV_ERR]
}


# Get evidence details
#
proc ::ob_iesnare::_get_evidence_details { username device_alias } {

	variable CFG

	ob_log::write DEBUG {*** ob_iesnare::_get_evidence_details ***}

	array set GET_EVIDENCE_DETAILS_PARAM_NAMES [list \
		subscriberid                    $CFG(subscriberid)\
		subscriberaccount          $CFG(subscriberaccount)\
		subscriberpasscode        $CFG(subscriberpasscode)\
		accountcode                              $username\
		devicealias                          $device_alias\
	]

	set GET_EVIDENCE_DETAILS_RESPONSE_NAMES [list \
		evidence_detail                           \
		evidence                                  \
		type                                      \
		source                                    \
	]

	ob_log::write DEBUG { Building XML... }
	## Build XML

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set CHECK_TRANSACTION_XML_DOM [dom createDocument "soapenv:Envelope"]

	# Request
	set envelope [$CHECK_TRANSACTION_XML_DOM documentElement]

	#Different xml namespace for log and check messages
	$envelope setAttribute \
		"xmlns:xsi"     "http://www.w3.org/2001/XMLSchema-instance"  \
		"xmlns:xsd"     "http://www.w3.org/2001/XMLSchema"           \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/"  \
		"xmlns:soap"    "$CFG(get_evidence_url)/Snare/Handler/Soap"

	set body [$CHECK_TRANSACTION_XML_DOM createElement "soapenv:Body"]
	$envelope appendChild $body

	set checkTransaction [$CHECK_TRANSACTION_XML_DOM createElement "soap:GetEvidenceDetails"]
	$checkTransaction setAttribute "soapenv:encodingStyle" "http://schemas.xmlsoap.org/soap/encoding/"

	$body appendChild $checkTransaction

	foreach c [array names GET_EVIDENCE_DETAILS_PARAM_NAMES] {
		ob_log::write DEBUG { ob_iesnare: Retrieving cfg item $c = $GET_EVIDENCE_DETAILS_PARAM_NAMES($c)}

		set subnode [$CHECK_TRANSACTION_XML_DOM createElement $c]
		$subnode setAttribute "xsi:type" "xsd:string"
		$subnode appendChild [$CHECK_TRANSACTION_XML_DOM createTextNode $GET_EVIDENCE_DETAILS_PARAM_NAMES($c)]
		$checkTransaction appendChild $subnode
	}

	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$CHECK_TRANSACTION_XML_DOM asXML]"

	catch {$CHECK_TRANSACTION_XML_DOM delete}

	## END BUILD XML
	ob_log::write DEBUG { Built XML. Sending to Iovation and getting response...}

	set response [_send_msg $xml_msg $CFG(get_evidence_url)]

	ob_log::write DEV {*** Get Evidence Details SOAP response= $response ***}

	ob_log::write DEBUG { Unpacking response from XML...}
	## UNPACK RESPONSE

	# Send the message to ieSnare Server for
	# verification and collect the response

	set evidence_codes [list]

	if { $response != "" && [lindex $response 0] != "IOV_ERR"} {
		set UNPACKED_RESPONSE(result) ""

		ob_log::write DEBUG {*** ob_iesnare::unpacking xml=$response ***}

		if {[catch {set CHECK_TRANSACTION_RSP_XML_DOM [dom parse $response]} msg]} {
			ob_log::write ERROR {*** ob_iesnare : unable to parse xml ($msg): $response ***}
			return
		}

		set Response [$CHECK_TRANSACTION_RSP_XML_DOM documentElement]

		ob_log::write DEV {*** ob_iesnare : Found document root Response=$Response ***}


		set evidence_codes [list]

		# Response/SOAP-ENV:Envelope/soap:Bodynamesp4:CheckLoginResponse/
		set Body [$Response selectNodes /SOAP-ENV:Envelope/SOAP-ENV:Body]

		set response_wrapper [$Body firstChild]

		# evidence_details
		set Inner_Body [$response_wrapper firstChild]

		# Parse the data from the XML response elements
		# evidence
		foreach elem_node [$Inner_Body childNodes] {
			set type_node [$elem_node firstChild]
			set node_data [$type_node selectNodes text()]
			set node_text [$node_data nodeValue]
			lappend evidence_codes $node_text

			ob_log::write DEBUG {*** ob_iesnare::iesnare_get_evidence_details data=$node_text ***}
		}

		catch {$CHECK_TRANSACTION_RSP_XML_DOM delete}
		## END UNPACK RESPONSE

		ob_log::write DEBUG {*** Unpacked response. Returning $evidence_codes ***}
	}

	return $evidence_codes
}

#
# Iovation - Bind ieSnare URL's
#
# substitute the config items and dynamic cust_id into the javascript
# add cust_id as it is dynamic and not set in the config
# takes the submit element id (usually a button) and the form id to which the submit element is tied
proc ::ob_iesnare::bind_iesnare_links {} {

	ob_log::write DEBUG {*** ob_iesnare::bind_iesnare_links ***}
	variable CFG

	set links [list]

	foreach opt {jscript_url gif_url subscriberid max_wait} {
		lappend links IESNARE_[string toupper $opt] $CFG($opt)
	}

	return $links
}


#
# Iovation - AddAccountEvidence
#
# builds & sends evidence to message iovation, for when a customer is suspected of
# fraud but is not flagged as such by iovation
#
# AddAccountEvidence SOAP message:
#
# --Envelope
#      |
#      --Body
#          |
#          --CheckTransaction
#                  |
#                  --subscriberid
#                  |
#                  --adminaccountname
#                  |
#                  --adminpassword
#                  |
#                  --accountcode
#                  |
#                  --evidencetype
#                  |
#                  --comment

proc ::ob_iesnare::AddAccountEvidence {cust_id evidence_type comment} {

	variable CFG
	variable CFG_REQ
	variable TRANSACTION_RESPONSE
	variable DATA_TRANSACTION

	# refresh config
	_get_config

	ob_log::write DEV {*** ob_iesnare::add_account_evidence ***}

	# reset data cache?
	_auto_reset

	set rs [ob_db::exec_qry ob_iesnare::get_username $cust_id]
	set username [db_get_coln $rs 0 0]
	ob_db::rs_close $rs

	array set ADD_ACCOUNT_EVIDENCE_PARAM_NAMES [list \
		subscriberid                    $CFG(subscriberid)\
		adminaccountname                $CFG(adminaccount)\
		adminpassword                   $CFG(adminpasscode)\
		accountcode                     $username\
		evidencetype                    $evidence_type\
		comment                         $comment\
	]

	ob_log::write DEBUG { Building XML... }

	dom setResultEncoding "UTF-8"

	# Create new XML document
	set ADD_ACCOUNT_EVIDENCE_XML_DOM [dom createDocument "soapenv:Envelope"]

	# Request
	set envelope [$ADD_ACCOUNT_EVIDENCE_XML_DOM documentElement]

	#Different xml namespace for log and check messages
	$envelope setAttribute \
		"xmlns:xsi"     "http://www.w3.org/2001/XMLSchema-instance"  \
		"xmlns:xsd"     "http://www.w3.org/2001/XMLSchema"           \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/"  \
		"xmlns:soap"    "$CFG(check_url)/Snare/Handler/Soap"

	set body [$ADD_ACCOUNT_EVIDENCE_XML_DOM createElement "soapenv:Body"]
	$envelope appendChild $body

	set addAccountEvidence [$ADD_ACCOUNT_EVIDENCE_XML_DOM createElement "soap:AddAccountEvidence"]
	$addAccountEvidence setAttribute "soapenv:encodingStyle" "http://schemas.xmlsoap.org/soap/encoding/"

	$body appendChild $addAccountEvidence

	foreach c [array names ADD_ACCOUNT_EVIDENCE_PARAM_NAMES] {
		ob_log::write DEBUG { ob_iesnare: Retrieving cfg item $c = $ADD_ACCOUNT_EVIDENCE_PARAM_NAMES($c)}

		set subnode [$ADD_ACCOUNT_EVIDENCE_XML_DOM createElement $c]
		$subnode setAttribute "xsi:type" "xsd:string"
		$subnode appendChild [$ADD_ACCOUNT_EVIDENCE_XML_DOM createTextNode $ADD_ACCOUNT_EVIDENCE_PARAM_NAMES($c)]
		$addAccountEvidence appendChild $subnode
	}

	set xml_msg "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n[$ADD_ACCOUNT_EVIDENCE_XML_DOM asXML]"

	ob_log::write DEV {*** ob_iesnare::add_account_evidence request xml_msg=$xml_msg ***}

	catch {$ADD_ACCOUNT_EVIDENCE_XML_DOM delete}

	## END BUILD XML
	ob_log::write DEBUG { Built XML. Sending to Iovation and getting response...}

	set response [_send_msg $xml_msg $CFG(add_evidence_url)]

	ob_log::write DEBUG {*** AddAccountEvidence SOAP response= $response ***}

	ob_log::write DEBUG { Unpacking response from XML...}

	set msg ""
	set status 1

	if { $response != "" && [lindex $response 0] != "IOV_ERR"} {

		if {[catch {set ADD_ACCOUNT_EVIDENCE_RSP_XML_DOM [dom parse $response]} msg]} {
			ob_log::write ERROR {*** ob_iesnare : unable to parse xml ($msg): $response ***}
			return
		}

		set Response [$ADD_ACCOUNT_EVIDENCE_RSP_XML_DOM documentElement]

		set Body [$Response selectNodes /SOAP-ENV:Envelope/SOAP-ENV:Body]

		set response_wrapper [$Body firstChild]
		set response_type    [$response_wrapper nodeName]
		ob_log::write DEBUG {*** ob_iesnare: response_type=$response_type ***}

		# 2 types of response
		# success looks like -
		#    Response/SOAP-ENV:Envelope/SOAP-ENV:Body/namesp1:AddAccountEvidenceResponse/namesp1:success
		# fault looks like -
		#    Response/SOAP-ENV:Envelope/SOAP-ENV:Body/SOAP-ENV:Fault

		if {$response_type == "namesp1:AddAccountEvidenceResponse"} {
			ob_log::write DEBUG {*** response : success! calling msg_bind... ***}
			set msg "Evidence code $evidence_type against customer $cust_id has successfully been sent to Iovation."
		} elseif {$response_type == "SOAP-ENV:Fault"} {
			set faultstring_text [$response_wrapper selectNodes faultstring/text()]
			set faultstring_value [$faultstring_text nodeValue]
			set msg "The evidence could not be forwarded to Iovation because: $faultstring_value"
			set status 0
		} else {
			set msg "The evidence could not be forwarded to Iovation."
			set status 0
		}

		catch {$ADD_ACCOUNT_EVIDENCE_RSP_XML_DOM delete}

	} else {
		set msg "The evidence could not be forwarded to Iovation."
		set status 0
	}

	return [list $status $msg]
}


# Pull config data from the db
#
proc ::ob_iesnare::_get_config args {

	variable CFG

	# global settings
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::get_config]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::get_config : $msg}
		return 0
	}

	if {[db_get_nrows $rs]} {

		set CFG(max_wait)           [db_get_col $rs 0 max_wait]
		set CFG(jscript_url)        [db_get_col $rs 0 jscript_url]
		set CFG(gif_url)            [db_get_col $rs 0 gif_url]
		set CFG(check_url)          [db_get_col $rs 0 check_url]
		set CFG(get_evidence_url)   [db_get_col $rs 0 get_evidence_url]
		set CFG(add_evidence_url)   [db_get_col $rs 0 add_evidence_url]
		set CFG(subscriberid)       [ob_crypt::decrypt_by_bf [db_get_col $rs 0 subscriberid]]
		set CFG(subscriberaccount)  [ob_crypt::decrypt_by_bf [db_get_col $rs 0 subscriberaccount]]
		set CFG(subscriberpasscode) [ob_crypt::decrypt_by_bf [db_get_col $rs 0 subscriberpasscode]]
		set CFG(adminaccount)       [ob_crypt::decrypt_by_bf [db_get_col $rs 0 adminaccount]]
		set CFG(adminpasscode)      [ob_crypt::decrypt_by_bf [db_get_col $rs 0 adminpasscode]]
		set CFG(enabled)            [db_get_col $rs 0 enabled]

	}

	db_close $rs

	# mapping triggers with business rules
	#
	foreach {trigger rule} [OT_CfgGet IOVATION_MAP_TRIGS_RULES ""] {
		set CFG(map,$trigger) $rule
	}

	# system level settings
	#
	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::get_trig_config]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::get_trig_config : $msg}
		return 0
	}

	set nrows [db_get_nrows $rs]

	for {set i 0} {$i < $nrows} {incr i} {

		set trig_type [db_get_col $rs $i trigger_type]

		set CFG(trig,$trig_type) $i

		set CFG(trig,$i,trigger_type) $trig_type
		set CFG(trig,$i,enabled)      [db_get_col $rs $i enabled]
		set CFG(trig,$i,freq_str)     [db_get_col $rs $i freq_str]
		set CFG(trig,$i,max_count)    [db_get_col $rs $i max_count]

		# if business rule is not defined then give it triggers name
		if {![info exists CFG(map,$trig_type)] || $CFG(map,$trig_type) == ""} {
			set CFG(map,$trig_type) $trig_type
		}

	}

	set CFG(trig,count) $nrows

	db_close $rs

	ob_log::write_array DEV CFG

	return 1
}


# Check if Iovation is globally enabled in DB
#
proc ::ob_iesnare::enabled args {

	variable CFG

	# refresh config
	if {![_get_config]} {
		ob_log::write ERROR {ob_iesnare::enabled: failed to refresh config}
		return 0
	}

	# Check if global level Iovation is enabled
	if {$CFG(enabled) != "Y"} {
		ob_log::write INFO {ob_iesnare: global level Iovation disabled}
		return 0
	}

	return 1
}


# Pull account level config data from the db
#
proc ::ob_iesnare::_get_acct_config {cust_id trigger_type} {

	variable CFG_ACCT

	set CFG_ACCT(cust_id) $cust_id

	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::get_acct_config\
			$cust_id $trigger_type]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::_get_acct_config: $msg}
		return 0
	}

	set CFG_ACCT(trigger_type) $trigger_type

	if {[db_get_nrows $rs]} {
		set CFG_ACCT(enabled)   [db_get_col $rs 0 enabled]
		set CFG_ACCT(freq_str)  [db_get_col $rs 0 freq_str]
		set CFG_ACCT(max_count) [db_get_col $rs 0 max_count]
	} else {
		# account level trigger settings are optional
		set CFG_ACCT(enabled)   ""
		set CFG_ACCT(freq_str)  ""
		set CFG_ACCT(max_count) ""
	}

	db_close $rs

	ob_log::write_array DEV CFG_ACCT

	return 1
}


# Run Iovation settings logic
#
# Returns a list:
#    1 0       - stop
#    1 1       - continue
#    0 err_msg - on error
#
proc ob_iesnare::_check_settings_logic {cust_id trigger_type} {

	variable CFG
	variable CFG_ACCT

	set fn "_check_settings_logic"

	# Check if global level Iovation is enabled
	if {$CFG(enabled) != "Y"} {
		ob_log::write INFO {$fn: global level Iovation disabled}
		return [list 1 0]
	}

	# Check if trigger/business rule exists
	if {![info exists CFG(trig,$trigger_type)]} {
		ob_log::write ERROR {$fn: unexpected trigger type: $trigger_type}
		return [list 0 "unexpected trigger type"]
	}

	set _trig_id $CFG(trig,$trigger_type)

	# get account level config
	if {![_get_acct_config $cust_id $trigger_type]} {
		ob_log::write ERROR {$fn: failed to get account level Iovation config:\
			$cust_id $trigger_type}
		return [list 0 "failed to get account level Iovation config"]
	}

	# Check if account level Iovation trigger is enabled
	if {$CFG_ACCT(enabled) != ""} {
		if {$CFG_ACCT(enabled) == "N"} {
			ob_log::write INFO {$fn: account level Iovation trigger disabled:\
				$cust_id $trigger_type}
			return [list 1 0]
		}
	} else {
		# Check if system level Iovation trigger is enabled
		if {$CFG(trig,$_trig_id,enabled) != "Y"} {
			ob_log::write INFO {$fn: system level Iovation trigger disabled:\
				$trigger_type}
			return [list 1 0]
		}
	}

	# Check trigger count against trigger max_count
	set _count [expr {[_get_cust_trig_count $cust_id $trigger_type] + 1}]

	if {$CFG_ACCT(max_count) != ""} {
		if {$_count > $CFG_ACCT(max_count)} {
			ob_log::write INFO {$fn: account trigger count less than account\
				level max_count: $cust_id $trigger_type $_count\
				$CFG_ACCT(max_count)}
			return [list 1 0]
		}
	} elseif {$CFG(trig,$_trig_id,max_count) != ""} {
		if {$_count > $CFG(trig,$_trig_id,max_count)} {
			ob_log::write INFO {$fn: account trigger count less than system\
				level max_count: $cust_id $trigger_type $_count\
					$CFG(trig,$_trig_id,max_count)}
			return [list 1 0]
		}
	}

	# Check if trigger count is present in freq_str
	if {$CFG_ACCT(freq_str) != ""} {
		set _freq [split $CFG_ACCT(freq_str) ","]
		if {$_freq != "*" && [lsearch -exact $_freq $_count] == -1} {
			ob_log::write INFO {$fn: account trigger count is not present in\
				account level freq_str: $cust_id $trigger_type $_count '$_freq'}
			return [list 1 0]
		}
	} elseif {$CFG(trig,$_trig_id,freq_str) != ""} {
		set _freq [split $CFG(trig,$_trig_id,freq_str) ","]
		if {$_freq != "*" && [lsearch -exact $_freq $_count] == -1} {
			ob_log::write INFO {$fn: account trigger count is not present in system\
				level freq_str: $cust_id $trigger_type $_count '$_freq'}
			return [list 1 0]
		}
	}

	return [list 1 1]
}


# Get account level Iovation trigger settings
#
proc ob_iesnare::_get_cust_trig_count {cust_id trigger_type {source "I"}} {

	variable CFG

	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::get_cust_trig_count\
					$cust_id $source "IOV_${trigger_type}"]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::_get_cust_trig_count:\
			$msg: $cust_id $source $trigger_type}
		return 0
	}

	set cust_trig_count 0

	if {[db_get_nrows $rs]} {
		set cust_trig_count [db_get_col $rs 0 count]
	}

	db_close $rs

	return $cust_trig_count
}


# Increase count for customer Iovation trigger
#
proc ob_iesnare::_do_cust_stats {
	cust_id
	trigger_type
	{ref_id ""}
	{source "I"}
} {

	# get acct_id

	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::get_acct_id $cust_id]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::get_acct_id:\
			$msg: $cust_id}
		return 0
	}

	if {[db_get_nrows $rs]} {
		set acct_id [db_get_coln $rs 0 0]
	} else {
		ob_log::write ERROR {acct_id not found: $cust_id}
		ob_db::rs_close $rs
		return 0
	}
	ob_db::rs_close $rs

	# increase customer's trigger count

	if {[catch {
		ob_db::exec_qry ob_iesnare::do_cust_stats\
					$acct_id "IOV_${trigger_type}" $ref_id $source
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::_do_cust_status:\
			$msg: $cust_id $source $trigger_type}
		return 0
	}

	return 1
}


# Store Iovation response
#
proc ob_iesnare::_store_response {
	cust_id
	trigger_type
	{ref_key ""}
	{ref_id ""}
} {

	ob_log::write DEBUG {ob_iesnare::_store_response: cust_id = $cust_id\
		trigger_typev = $trigger_type ref_key = $ref_key ref_id = $ref_id}

	variable TRANSACTION_RESPONSE

	set _resp_fields [list\
		devicealias\
		trackingnumber\
		result\
	]

 	foreach n $_resp_fields {
		if {[info exists TRANSACTION_RESPONSE($n)]} {
			set $n $TRANSACTION_RESPONSE($n)
		} else {
			set $n ""
		}
	}

	if {[catch {
		set rs [ob_db::exec_qry ob_iesnare::ins_iov_response\
			$cust_id\
			$devicealias\
			$trackingnumber\
			$result\
			$trigger_type\
			$ref_key\
			$ref_id\
		]
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::_store_response:\
			$msg: $cust_id $trigger_type}
		return [list 0 "Failed to insert Iovation response"]
	}

	set resp_id [db_get_coln $rs 0 0]

	ob_db::rs_close $rs

	return [list 1 $resp_id]
}


# Update Iovation response with reference
#
# resp_id - tIovResponse.resp_id
# ref_key - "PMT" for tPmt
#           "CPM" for tCustPayMthd
# ref_id  - serial for referenced table
#
proc ob_iesnare::upd_response_with_ref {
	resp_id
	{ref_key ""}
	{ref_id ""}
} {

	ob_log::write DEBUG {ob_iesnare::upd_response_with_ref: resp_id = $resp_id\
		ref_key = $ref_key ref_id = $ref_id}

	if {$resp_id == "" || $ref_id == ""} {
		# probably error when storing response
		# more checks are done in DB table constraints
		ob_log::write INFO {ob_iesnare::upd_response_with_ref: resp_id or\
			ref_id is empty, not updating}
		return 1
	}

	if {[catch {
		ob_db::exec_qry ob_iesnare::upd_iov_response\
			$resp_id\
			$ref_key\
			$ref_id
	} msg]} {
		ob_log::write ERROR {Error executing ob_iesnare::upd_response_with_ref:\
			$msg: $resp_id}
		return "Failed to update Iovation response"
	}

	return 1
}
