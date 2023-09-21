#
# $Id: BossMedia_shared.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# Copyright (c) 2005 Orbis Technology Ltd. All rights reserved.
#

namespace eval BM_shared {

	namespace export encode_BM_action
	namespace export deccode_BM_action

}

#
# encode_BM_action
#
# Encode the action, login cookie and cust_id
#
# This is intended to be appended to the end of the go_bm_secure customer
# screen URL to enable seamless access to the customers account pages
# from the BossMedia executable
#
# cust_id - the user's cust_id
#
# action - is the original action that the BossMedia system wants to access
#          e.g. go_acct_pwd
#
# cookie - the login cookie which will be set at the browser before the
#          redirection to 'action' occurs
#
proc BM_shared::encode_BM_action {cust_id action cookie} {

	OT_LogWrite DEBUG "encode_BM_action $cust_id $action $cookie"
	#Concat the args together
	set str "${cust_id}|${action}|${cookie}"

	# Encrypt into binary and express in hexadecimal
	set TOKEN_ENC [OT_CfgGet TOKEN_ENC "bin"]
	set TOKEN_KEY [OT_CfgGet TOKEN_KEY "BillyTheFish"]
	if {[catch {set bstr [blowfish encrypt -$TOKEN_ENC $TOKEN_KEY -bin $str]} msg]} {
		OT_LogWrite DEBUG "Error blowfishing the BM_action"
		return ""
	}
	# We shorten using base64
	if {[catch {set estr [convertto b64 -hex $bstr]} msg]} {
		OT_LogWrite DEBUG "Error hexing the BM_action"
		return ""
	}

	set ustr [urlencode $estr]
	return $ustr
}

#
# deccode_BM_action
#
# Decode the passed encoding to the action, login cookie and cust_id
#
# This is intended to be appended to the end of the go_bm_secure customer
# screen URL to enable seamless access to the customers account pages
# from the BossMedia executable
#
# Decrypts to a list of cust_id action cookie
#
# cust_id - the user's cust_id
#
# action - is the original action that the BossMedia system wants to access
#          e.g. go_acct_pwd
#
# cookie - the login cookie which will be set at the browser before the
#          redirection to 'action' occurs
#
proc BM_shared::deccode_BM_action {enc} {

	# Decrypt the base64 and express in hexadecimal
	set TOKEN_ENC [OT_CfgGet TOKEN_ENC "bin"]
	set TOKEN_KEY [OT_CfgGet TOKEN_KEY "BillyTheFish"]
	if {[catch {set dec [blowfish decrypt -$TOKEN_ENC $TOKEN_KEY -b64 $enc]} msg]} {
		OT_LogWrite DEBUG "blowfish decrypt failed: $msg"
		return ""
	}
	if {[catch {set dec [hextobin $dec]} msg]} {
		OT_LogWrite DEBUG "hextobin failed: $msg"
		return ""
	}
	set parts [split $dec "|"]
	OT_LogWrite DEBUG "decode_BM_action parts are $parts"

	return $parts
}

