# $Id: mcs_api.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $

package require xml
#namespace import xml::*


namespace eval mcs_api {

namespace export get_mcs_balance

variable MCS_DATA


proc mcs_api_init {} {

	variable MCS_DATA


	#
	# Prep querys
	#
	prep_mcs_api_qrys


	#
	# Set up some static data needed later
	#
	set MCS_DATA(mcs_timeout_lo)         [OT_CfgGet MCS_TIMEOUT_LO 5000]
	set MCS_DATA(action_check_balance)   "/checkbal.asp?"

	# For use against Orbis test harness.
	if {[OT_CfgGetTrue MCS_TEST]} {
		set MCS_DATA(action_check_balance)  "?action=checkbal&"
	}
}

proc prep_mcs_api_qrys {} {

	global SHARED_SQL

	set SHARED_SQL(get_customer_flags) {
			select
				flag_value
			from
				tcustomerflag
			where
				cust_id = ? and
				flag_name = ?
		}
}

###############################################################################
# Procedure:    get_mcs_balance
# Description:  retrieves account balance
# Output:       MCS balance of $MODE account, or 'FAILED' if an error occurs.
###############################################################################
proc get_mcs_balance {cust_id username {mode "casino"} {aff ""}} {
	ob::log::write INFO {==>get_mcs_balance cust_id=$cust_id username=$username mode=$mode}

	variable MCS_DATA
	global XML_RESPONSE


	set mcs_URL  [get_mcs_url $cust_id $mode $aff]
	set username [urlencode $username]
	set url      [format "%s%sloginname=%s" $mcs_URL $MCS_DATA(action_check_balance) $username]

	ob::log::write DEV {calling mcs with url:$url}

	# grab the response (use timeout)
	if {[catch {set http_response [http::geturl $url -timeout $MCS_DATA(mcs_timeout_lo)]}]} {
		catch {http::cleanup $http_response}
		ob::log::write ERROR {failed to get mcs $mode balance (timeout)}
		return FAILED
	}

	# check ok
	set response [validateResponse $http_response]
	if {$response != "OK"} {
		catch {http::cleanup $http_response}
		ob::log::write ERROR {failed to get mcs $mode balance (response = $response)}
		return FAILED
	}

	# parse the data
	parseBody [http::data $http_response]

	# clean up the html
	http::cleanup $http_response

	# now check the response
	if {[info exists XML_RESPONSE(getbalance,result)]} {
		ob::log::write_array INFO XML_RESPONSE

		if {$XML_RESPONSE(getbalance,result) == "QRY_OK"} {

			ob::log::write_array INFO XML_RESPONSE
			ob::log::write INFO {mcs $mode balance retrieved ok}

			if {[info exists XML_RESPONSE(getbalance,balance)]} {
				# Remove commas etc from Microgaming return value.
				return [string map {"," ""} $XML_RESPONSE(getbalance,balance)]
			}
			ob::log::write ERROR {get_mcs_balance: Unexpected result from MCS}
			return FAILED

		} elseif {[info exists XML_RESPONSE(getbalance,errorcode)]} {

			ob::log::write_array DEV XML_RESPONSE
			if {($mode == "poker") && ($XML_RESPONSE(getbalance,errorcode) == "116")} {
				ob::log::write INFO {code 116 detected}
				return NOALIAS
			}
			ob::log::write ERROR {failed to get mcs balance (qry failed)}
			return FAILED
		} else {
			return FAILED
		}

	}
	ob::log::write ERROR {failed to get mcs $mode balance (unknown failure)}
	return FAILED
}


##
# get_mcs_url - Return a URL for contacting microgaming based on params
#
# SYNOPSIS
#
#    [get_mcs_url \[<mode>\]]
#
# SCOPE
#
#    private
#
# PARAMS
#
#    cust_id - customer's unique customer id (like tCustomer.cust_id)
#    [mode] - string:casino / poker, default = casino.
#    casinoaff - affiliate casino string
#                "" - reqGetArg the aff
#                "default" - effective no aff
#                "RIO" - Roi Bay Casino affiliate id.
#
# RETURN
#
#    URL for contacting microgaming.
#
# DESCRIPTION
#
# Will return a URL based on various variables, including
# mode, server_id flag in DB (for different countries) and
# casino_aff get argument.
#
##

proc get_mcs_url {cust_id {mode "casino"} {casinoaff ""}} {
	ob::log::write INFO {==>get_mcs_url cust_id=$cust_id mode=$mode casinoaff=$casinoaff}

	variable MCS_DATA

	if {$mode == "poker"} {
		return [OT_CfgGet MCS_POKER_BASE_URL]
	}


	if {$casinoaff == ""} {
		set aff [string toupper [reqGetArg casino_aff]]
	} elseif {$casinoaff == "default"} {
		set aff ""
	} else {
		set aff [string toupper $casinoaff]
	}
	ob::log::write DEV {get_mcs_url:: casino_aff = $aff}

	#
	# Retrieve serverid flag from tcustomerflag if it hasn't been done already.
	#
	if {![info exists MCS_DATA(serverid)]} {

		ob::log::write DEV {MCS: Retrieving user's server id from DB}

		if {[catch {
			set rs [tb_db::tb_exec_qry get_customer_flags $cust_id serverid]
		} msg]} {
			ob::log::write ERROR {MCS: $msg}
		}

		if {[db_get_nrows $rs] < 1} {
			set MCS_DATA(serverid) none
		} else {
			set MCS_DATA(serverid) [string toupper [db_get_col $rs 0 flag_value]]
			ob::log::write DEV {MCS_DATA(serverid):$MCS_DATA(serverid)}
		}
	}

	set cfg [expr {
		$aff == "" ?
		"MCS_BASE_URL" :
		"MCS_BASE_URL_$aff"
	}]

	return [expr {
		$MCS_DATA(serverid) == "none" ?
		[OT_CfgGet $cfg] :
		[OT_CfgGet ${cfg}_$MCS_DATA(serverid)]
	}]
}

#########################################################################################
#
#          MCS HTTP CODE (taken originally from mcs_http.tcl)
#
#########################################################################################

proc H_read_url {} {

	# reads the url information
	set http_response	[http::geturl [reqGetArg url]]

	if {[validateResponse $http_response]=="FAILED"} {
		http::cleanup $http_response
		play_file error.html
		return;
	}

	# parse the data
	parseBody [http::data $http_response]

	# clean up the html
	http::cleanup $http_response

	play_file read_url.html
}


# is the response valid?
#
proc validateResponse {http_response} {

	set http_error 		[http::error $http_response]
	set http_code 		[http::code $http_response]
	set http_wait 		[http::wait $http_response]

	if {$http_wait != "ok"} {
		return TIMEOUT
	}
	if {$http_error != ""} {
		return HTTP_ERROR
	}
	if {$http_code != "HTTP/1.1 200 OK"} {
		return HTTP_WRONG_CODE
	}
	return OK
}



# set up an event parser, this reads nodes and text values associated
# with the nodes into the XML_REPONSE array
#
# NB it won't do attributes and it doesn't check the validity or wellformedness
proc parseBody {xml_body} {

	global XML_RESPONSE

	if {[info exists XML_RESPONSE]} {
		unset XML_RESPONSE
	}

	set parser [xml::parser]
	$parser configure -elementstartcommand handleStart
	$parser configure -characterdatacommand handleText
	$parser configure -elementendcommand handleEnd
	$parser parse $xml_body

}


# handlers for the XML parser
#
# fills the XML_RESPONSE array with nodes and node names
proc handleStart {name attlist} {

	global XML_NAME
	lappend XML_NAME $name
}

proc handleText {data} {

	global XML_NAME
	global XML_RESPONSE

	set trimmed [string trim $data]

	if {$trimmed != ""} {
		set array_key [join $XML_NAME ,]
		set XML_RESPONSE($array_key) $trimmed

		ob::log::write DEV {handleText: $array_key=$trimmed}
	}
}

proc handleEnd {name} {

	global XML_NAME
	set XML_NAME [lrange $XML_NAME 0 end-1]
}


#
# Close namespace and init it!
#
mcs_api_init

}
