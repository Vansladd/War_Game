# ==============================================================
# $Id: acct-dcash.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
#
# ==============================================================

namespace eval datacash {

namespace export dcash_init
namespace export make_dcash_call

global TT

	#####################
	# Datacash Messages #
	# wp: for WAP       #
	#####################
	set TT(DCASH_7,en)	"Sorry, the payment request was declined. Please contact your bank."
	set TT(DCASH_7,wp)	"Sorry, the payment request was declined. Please contact your bank."
	set TT(DCASH_7,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#35201;&#27714;&#30340;&#27454;&#38917;&#25976;&#30446;&#34987;&#37504;&#34892;&#25298;&#32085;. &#35531;&#33287;&#20320;&#30340;&#37504;&#34892;&#32879;&#32097;."
	set TT(DCASH_7,es)	"Lo sentimos, pero la solicitud de pago ha sido denegada. Consulte a su banco."
	set TT(DCASH_7,it)	"La richiesta di pagamento non &egrave; stata accettata. Contattate la vostra banca."

	set TT(DCASH_8,en)	"Sorry, your bank's server is not responding to our request for authorisation."
	set TT(DCASH_8,wp)	"Sorry, your bank's server is not responding to our request for authorisation."
	set TT(DCASH_8,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#37504;&#34892;&#30340;&#32178;&#32097;&#24037;&#20316;&#31449;&#23565;&#25152;&#35201;&#27714;&#26680;&#20934;&#27794;&#26377;&#22238;&#25033;."
	set TT(DCASH_8,es)	"Los sentimos, su banco no respondé a nuestra petici&oacute;n de autorizaci&oacute;n."
	set TT(DCASH_8,it)	"Il server della vostra banca non risponde alla nostra richiesta di autorizzazione.."

	set TT(DCASH_21,en)	"Sorry, your card type is invalid."
	set TT(DCASH_21,wp)	"Sorry, your card type is invalid."
	set TT(DCASH_21,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#31278;&#39006;&#24050;&#20572;&#27490;&#20351;&#29992;"
	set TT(DCASH_21,es)	"Los sentimos, su tarjeta no es v&aacute;lido."
	set TT(DCASH_21,it)	"Questo tipo di carta non &egrave; valido."

	set TT(DCASH_24,en)	"Sorry, your card has expired."
	set TT(DCASH_24,wp)	"Sorry, your card has expired."
	set TT(DCASH_24,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#24050;&#36942;&#26399;"
	set TT(DCASH_24,es)	"Los sentimos, su tarjeta ha caducado."
	set TT(DCASH_24,it)	"La carta &egrave; scaduta."

	set TT(DCASH_25,en)	"Sorry, your card number is invalid."
	set TT(DCASH_25,wp)	"Sorry, your card number is invalid."
	set TT(DCASH_25,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#34399;&#30908;&#19981;&#27491;&#30906;"
	set TT(DCASH_25,es)	"Los sentimos, su tarjeta no es v&aacute;lido."
	set TT(DCASH_25,it)	"Il numero della carta non &egrave; valido."

	set TT(DCASH_26,en)	"Sorry, your card number is the wrong length."
	set TT(DCASH_26,wp)	"Sorry, your card number is the wrong length."
	set TT(DCASH_26,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#34399;&#30908;&#25976;&#23383;&#22826;&#38263;"
	set TT(DCASH_26,es)	"Los sentimos, el n&uacute;umero de su tarjeta ha tiene una longitud err&ograve;nea."
	set TT(DCASH_26,it)	"La lunghezza del numero della carta &egrave; errata."

	# error only has english & wap translations
	set TT(DCASH_27,en) "Invalid or missing issue number."
	set TT(DCASH_27,wp) "Invalid or missing issue number."

	# error only has english & wap translations
	set TT(DCASH_28,en) "Invalid or missing start/issue date."
	set TT(DCASH_28,wp) "Invalid or missing start/issue date."

	set TT(DCASH_29,en)	"Sorry, your card is not yet valid."
	set TT(DCASH_29,wp)	"Sorry, your card is not yet valid."
	set TT(DCASH_29,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#36996;&#26410;&#33021;&#27491;&#24335;&#20351;&#29992;"
	set TT(DCASH_29,es)	"Los sentimos, su tarjeta aun no es operatina."
	set TT(DCASH_29,it)	"La carta non &egrave; ancora valida."

	set TT(DCASH_36,en)	"Sorry, your card has been used within the last 2 minutes. Please wait a short time before trying again."
	set TT(DCASH_36,wp)	"Sorry, your card has been used within the last 2 minutes. Please wait a short time before trying again."
	set TT(DCASH_36,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#26366;&#22312;&#36889;&#20841;&#20998;&#37912;&#20839;&#29992;&#36942;. &#35531;&#31245;&#24460;&#20877;&#35430;."
	set TT(DCASH_36,es)	"Los sentimos, su tarjeta ha sido usada en los ultomos 2 minutes. Por favor espere un poco antes de volver a intentarlo."
	set TT(DCASH_36,it)	"Los sentimos, su tarjeta ha sido usada en los ultomos 2 minutes. Por favor espere un poco antes de volver a intentarlo."

	set TT(DCASH_56,en)	"Sorry, your card has been used within the last 2 minutes. Please wait a short time before trying again."
	set TT(DCASH_56,wp)	"Sorry, your card has been used within the last 2 minutes. Please wait a short time before trying again."
	set TT(DCASH_56,cn)	"&#23565;&#19981;&#36215;, &#38307;&#19979;&#30340;&#21345;&#26366;&#22312;&#36889;&#20841;&#20998;&#37912;&#20839;&#29992;&#36942;. &#35531;&#31245;&#24460;&#20877;&#35430;."
	set TT(DCASH_56,es)	"Los sentimos, su tarjeta ha sido usada en los ultomos 2 minutes. Por favor espere un poco antes de volver a intentarlo."
	set TT(DCASH_56,it)	"La carta &egrave; stata utilizzata negli ultimi 2 minuti. Attendere qualche istante prima di riprovare."

	set TT(DCASH_DFLT,en)	"Sorry, we can not authorise your payment details at this time."
	set TT(DCASH_DFLT,wp)	"Sorry, we can not authorise your payment details at this time."
	set TT(DCASH_DFLT,cn)	"&#23565;&#19981;&#36215;, &#25105;&#20497;&#30446;&#21069;&#19981;&#33021;&#25209;&#20934;&#38307;&#19979;&#25152;&#35201;&#27714;&#30340;&#27454;&#38917;&#36039;&#26009;"
	set TT(DCASH_DFLT,es)	"Lo sentimos, pero no podemos autorizar sus datos de pago en estos momentos."
	set TT(DCASH_DFLT,it)	"In questo momento il pagamento non pu&ograve; essere autorizzato."



set DCASH_ENCRYPT  1

set DCASH_ISSUES_INFO [list\
	490302-09 1\
	490335-40 1\
	490525-29 2\
	491100-02 1\
	491174-82 1\
	493600-99 1\
	564182 2\
	633110 1\
	633301 1\
	633461 1\
	633473 1\
	633476 1\
	633478 1\
	633481 1\
	633490-93 1\
	633494 1\
	633495-97 2\
	633498 1\
	633499 1\
	675901 1\
	675905 1\
	675918 1\
	675938-40 1\
	675950-62 1\
	675998 1\
	676701 1\
	676703 1\
	676705 1\
	676706-07 2\
	676718 1\
	676740 1\
	676750-62 1\
	676770 1\
	676774 1\
	676779 1\
	676782 1\
	676795 1\
	676798 1]

#
# Put each card number start nto an associative array for speedy lookups
#
foreach {r i} $DCASH_ISSUES_INFO {

	set sl [split $r -]

	if {[llength $sl] == 1} {
		set DCASH_ISSUE($r) $i
	} else {
		set r0 [lindex $sl 0]
		set r1 [string range $r0 0 3][lindex $sl 1]
		for {set r $r0} {$r <= $r1} {incr r} {
			set DCASH_ISSUE($r) $i
		}
	}
}

set DCASH_STARTS_INFO [list\
	633300\
	633302-49\
	633350-99\
	633450-60\
	633462-72\
	633474-75\
	633477\
	633479-80\
	633482-89\
	675900\
	675902-04\
	675906-17\
	675919-37\
	675941-49\
	675963-97\
	675999\
	676700\
	676702\
	676704\
	676708-17\
	676719-39\
	676741-49\
	676763-69\
	676771-73\
	676775-78\
	676780-81\
	676783-94\
	676796-97\
	676799]

foreach r $DCASH_STARTS_INFO {

	set sl [split $r -]

	if {[llength $sl] == 1} {
		set DCASH_START($r) 1
	} else {
		set r0 [lindex $sl 0]
		set r1 [string range $r0 0 3][lindex $sl 1]
		for {set r $r0} {$r <= $r1} {incr r} {
			set DCASH_START($r) 1
		}
	}
}

# map datacash return codes to generic Payment return codes
variable  DCASH_CODE_TX
array set DCASH_CODE_TX {
	1  OK
	3  PMT_RESP
	6  PMT_RESP
	7  PMT_DECL
	8  PMT_RESP
	21 PMT_TYPE
	22 PMT_REF
	24 PMT_EXPR
	25 PMT_CRNO
	26 PMT_CLEN
	27 PMT_ISSUE
	28 PMT_STRT
	29 PMT_STRT
	36 PMT_SPEED
	56 PMT_SPEED
}



# ----------------------------------------------------------------------
# Attempts to open a socket to datacash, send a message using the
# parameters supplied, read the returned message and close the socket.
#
# The data in the message returned by datacash is stored in the array
# supplied.
#
# The value returned will be 'OK' for success, or one of the
# PMT_ERR_CODES defined in payment_gateway.
# ----------------------------------------------------------------------
proc make_dcash_call {ARRAY} {

	upvar $ARRAY PMT

	variable DCASH_CODE_TX
	variable cfg

	upvar $ARRAY PMT


	switch -- $PMT(pay_sort) {
		"D" {
				set DCASH_DATA(OP) pre
		}
		"W" {
			# Datacash 2.7 now supports auth/settle on withdrawals
			# make this the default in the future but for now it
			# is a config file option
			if {[OT_CfgGet DCASH_WTD_DO_AUTH N] == "N"} {
				  set DCASH_DATA(OP) refund
			} else {
				  set DCASH_DATA(OP) erp
			}
		}
		default {
			ob::log::write WARNING {DCASH: Bad payment sort $PMT(pay_sort)}
			return PMT_TYPE
		}
	}


	set DCASH_DATA(REF_NO)       $PMT(apacs_ref)
	set DCASH_DATA(AMOUNT)       $PMT(amount)
	set DCASH_DATA(CARD)         $PMT(card_no)
	set DCASH_DATA(START)        $PMT(start)
	set DCASH_DATA(EXPIRY)       $PMT(expiry)
	set DCASH_DATA(ISSUE_NO)     $PMT(issue_no)
	set DCASH_DATA(CCY)          $PMT(ccy_code)
	set DCASH_DATA(AUTH_CODE)	 $PMT(gw_auth_code)

	# payment gateway values
	set DCASH_DATA(HOST)         $PMT(host)
	set DCASH_DATA(PORT)         $PMT(port)
	set DCASH_DATA(RESP_TIMEOUT) [OT_CfgGet DCASH_TIMEOUT         $PMT(resp_timeout)]
	set DCASH_DATA(CONN_TIMEOUT) [OT_CfgGet DCASH_SOCKET_TIMEOUT  $PMT(conn_timeout)]
	set DCASH_DATA(CLIENT)       $PMT(client)
	set DCASH_DATA(PASSWORD)     $PMT(password)
	set DCASH_DATA(KEY)          $PMT(key)
	set DCASH_DATA(SOURCE)       $PMT(cp_flag)

	# make the dcash call
	if [catch {set sock [payment_gateway::socket_timeout \
							 $DCASH_DATA(HOST) \
							 $DCASH_DATA(PORT) \
							 $DCASH_DATA(CONN_TIMEOUT)]} msg] {
		ob::log::write CRITICAL {DCASH: Caught dcash socket exception: $msg}
		return PMT_NO_SOCKET
	}

	if [catch {set dcash_result [dcash_send_msg $sock DCASH_DATA]} msg ] {
		ob::log::write CRITICAL {DCASH: Caught dcash exception: $msg}
		return PMT_RESP
	}

	catch {close $sock}

	set PMT(gw_auth_code)       [lindex $dcash_result 1]
	set PMT(gw_ret_code)        [lindex $dcash_result 0]
	set PMT(gw_uid)             [lindex $dcash_result 3]
	set PMT(card_type)          [lindex $dcash_result 4]
	set PMT(gw_ret_msg)         [join $dcash_result :]

	# we translate the datacash return code into a
	# generic PMT return code and ... return it

	ob::log::write INFO {DCASH: response code was $PMT(gw_ret_code)}

	set gw_ret_code PMT_ERR

	if {[info exists DCASH_CODE_TX($PMT(gw_ret_code))]} {
		set gw_ret_code $DCASH_CODE_TX($PMT(gw_ret_code))
	}

	#
	# Payment declined is unfortunately mixed in with
	# payment referred... and to complicate things, different
	# card issuers phrase referrals differently in the response.
	# The pattern appears to be that for referrals, the auth code
	# will be CALL AUTH CENTRE or will begin with REFER
	#
	if {$gw_ret_code=="PMT_DECL"} {
		set test_str [string toupper $PMT(gw_auth_code)]
		if {$test_str=="CALL AUTH CENTRE" \
		||  [string range $test_str 0 4] == "REFER"} {
			set gw_ret_code PMT_REFER
		}
	}

	return $gw_ret_code
}

#--------------------------------------------------------
# Initialises anything which is specific to datacash
# messaging
#--------------------------------------------------------
proc dcash_init {} {

	ob::log::write DEV {DCASH ==> dcash_init}
}

# ----------------------------------------------------------------------
# Send the message to datacash with the supplied socket and read the
# response
# ----------------------------------------------------------------------
proc dcash_send_msg {sock ARRAY} {

	variable DCASH_ENCRYPT
	variable DCASH_START
	variable DCASH_ISSUE

	upvar $ARRAY DCASH_DATA

	global read_expired read_ended

	set client    $DCASH_DATA(CLIENT)
	set password  $DCASH_DATA(PASSWORD)
	set key       $DCASH_DATA(KEY)
	set source    $DCASH_DATA(SOURCE)
	set op        $DCASH_DATA(OP)
	set ref_no    $DCASH_DATA(REF_NO)
	set amount    [format {%0.2f} $DCASH_DATA(AMOUNT)]
	set card      $DCASH_DATA(CARD)
	set start     $DCASH_DATA(START)
	set expiry    $DCASH_DATA(EXPIRY)
	set issue_no  $DCASH_DATA(ISSUE_NO)

	if {![info exists DCASH_DATA(CCY)]} {
		error "No currency passed"
	}

	if {[info exists DCASH_DATA(AUTH_CODE)]} {
		set auth_code $DCASH_DATA(AUTH_CODE)
	} else {
		set auth_code ""
	}

	set num_start [string range $card 0 5]

	if {$DCASH_ENCRYPT == 1} {
		set enc_card [OT_DCashEnc $card $key]
		ob::log::write INFO {DCASH: encrypted card number => $enc_card}
		set card $enc_card
	}

	ob::log::write INFO {DCASH: client    => $client}
	ob::log::write INFO {DCASH: op        => $op}
	ob::log::write INFO {DCASH: ref no    => $ref_no}
	ob::log::write INFO {DCASH: amount    => $amount}
	ob::log::write INFO {DCASH: card      => $card}
	ob::log::write INFO {DCASH: start     => $start}
	ob::log::write INFO {DCASH: expiry    => $expiry}
	ob::log::write INFO {DCASH: issue     => $issue_no}
	ob::log::write INFO {DCASH: source    => $source}
	ob::log::write INFO {DCASH: auth_code => $auth_code}

	if [info exists DCASH_START($num_start)] {
		# card digits indicate a start date should be sent, put it into
		# the issue number field

		ob::log::write INFO {DCASH: Card start ($num_start) ==> send start date}
		set issue_no $start
	}

	if [catch {

		puts $sock "CLIENT $client"
		puts $sock "PASS $password"
		puts $sock "TYPE $op"
		puts $sock "REF $ref_no"
		puts $sock "SUM $amount"
		puts $sock "NUM $card"
		puts $sock "EXP $expiry"

		if {[string trim $issue_no] != ""} {
			puts $sock "ISSUE $issue_no"
		}
		if {[info exists DCASH_DATA(CCY)]} {
			puts $sock "CURRENCY $DCASH_DATA(CCY)"
		}
		if {$source != ""} {
			puts $sock "SOURCE $source"
		}
		if {$auth_code != ""} {
			puts $sock "AUTH $auth_code"
		}

		puts $sock "."

	} msg] {
		ob::log::write ERROR {DCASH: failed to send request : $msg}
		catch {close $sock}
		error "failed to send request"
	}

	ob::log::write INFO {DCASH: awaiting response...}

	set read_expired ""
	fileevent $sock readable {set read_expired "OK"}
	set id [after $DCASH_DATA(RESP_TIMEOUT) {set read_expired "TIMED_OUT"}]

	vwait read_expired
	# cancel the fileevent now that we've waited for it
	fileevent $sock readable {}

	if {$read_expired == "TIMED_OUT"} {
		ob::log::write ERROR {DCASH: Timed out. Failed to read response.}
		catch {close $sock}
		error "Timed out after $DCASH_DATA(RESP_TIMEOUT) while waiting for response"
	}

	after cancel $id

	set more 1

	ob::log::write INFO {DCASH: reading response...}

	set read_ended ""
	set id [after $DCASH_DATA(RESP_TIMEOUT) {set read_ended "TIMED_OUT"}]

	while {$more==1} {
		if [catch {gets $sock resp} msg] {
			ob::log::write ERROR {DCASH: failed to read dcash response : $msg}
			catch {close $sock}
			after cancel $id
			error "failed to read datacash response"
		}
		if {$resp != "" || [fblocked $sock]!=1} {
			set more 0
		} elseif {$read_ended == "TIMED_OUT"} {
			ob::log::write ERROR {DCASH: Timed out. Failed to finish reading dcash response}
			catch {close $sock}
			after cancel $id
			error "Timed out after $DCASH_DATA(RESP_TIMEOUT) while reading response"
		}
		after 50
	}
	after cancel $id

	ob::log::write INFO {DCASH: response read: $resp}

	return [split [string trim $resp] :]
}

#############################
proc dcash_err_filter {err} {
#############################
#
# Argument is a datacash return code other than 1
# (this function is for ERROR codes not success messages!!!)
# Returns a message suitable for displaying to customers.
#
#
# Does not yet deal with all codes, will return a catch all message for missing ones.
# extra codes can easily be added (very dull : can only do a few at a time before becoming exceedingly bored...)
# If anybody adds some - please do in numerical order.
#
	global TT LANG

	if {$err==7} {
		# Not authorised Transaction declined.
		# The argument is the bank's reason for declining it (e.g. REFERRAL, CALL AUTH CENTRE, PICK UP CARD etc.)
		# Version 2.4 will return additional arguments, as for code 1.
		return $TT(DCASH_7,$LANG)
		# additional info will be stored in tacctpayment

	} elseif {$err==8} {
		# APACS-30 timeout The Bank's server did not respond
		return $TT(DCASH_8,$LANG)

	} elseif {$err==21} {
		# Invalid card type.
		# This terminal does not accept transactions for this type of card
		# (e.g. VISA UK Electron, which is a cardholder present card which we cannot accept).
		return $TT(DCASH_21,$LANG)

	}  elseif {$err==24} {
		# Card has already expired The supplied expiry date is in the past.
		return $TT(DCASH_24,$LANG)
		# (shouldn't really happen as javascript / tcl validation should sort it out, may happen if customer tries to fiddle stuf though ?)

	}  elseif {$err==25} {
		#Card number invalid The card number does not pass the standard Luhn checksum test.
		return $TT(DCASH_25,$LANG)

	}  elseif {$err==26} {
		# Card number wrong length The card number does not have the expected number of digits.
		return $TT(DCASH_26,$LANG)

	} elseif {$err == 27} {
		# Invalid or missing issue number.
		if {$LANG == "en" || $LANG == "wp"} { return $TT(DCASH_27,$LANG)
		} else { return $TT(DCASH_DFLT,$LANG) }

	} elseif {$err == 28} {

		# Invalid or missing issue number.
		if {$LANG == "en" || $LANG == "wp"} { return $TT(DCASH_28,$LANG)
		} else { return $TT(DCASH_DFLT,$LANG) }

	}  elseif {$err==29} {
		# Card is not valid yet The supplied start date is in the future
		return $TT(DCASH_29,$LANG)
		# (shouldn't really happen as javascript / tcl validation should sort it out, may happen if customer tries to fiddle stuf though ?)

	}  elseif {$err==36} {
		# Card used recently This credit card was used within the last 2 minutes.
		return $TT(DCASH_36,$LANG)

	}  elseif {$err==56} {
		# Card used recently This credit card was used within the last 2 minutes.
		return $TT(DCASH_56,$LANG)

	} else {
		# catch all
		return $TT(DCASH_DFLT,$LANG)
	}
}

# close namespace
}


proc dcash_init {} {

	ob::log::write DEV {DCASH: ==> dcash_init: PLEASE REMOVE this call, use payment_gateway::pmt_gtwy_init instead}

}


