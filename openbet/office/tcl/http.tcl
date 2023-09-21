# $Id: http.tcl,v 1.1 2011/10/04 12:30:14 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office
# HTTP Request/Response Handler
#
# Configuration:
#
# Procedures:
#    http::req_init          request init
#    http::req_end           requent end
#    http::req_error         error handler
#    htpp::H_default         default action handler
#

# Namespace Variables
#
namespace eval http {

	variable MASK [list pwd password vfy_password c_pwd n_pwd v_pwd card_no\
	               cvv2]
}



#--------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------

# Request init
#
proc http::req_init args {

	variable MASK

	set action [reqGetArg action]

	ob_log::set_prefix [format "%03d:%04d" [asGetId] [reqGetId]]
	ob_log::write DEBUG {************************************}
	ob_log::write_req_args DEBUG $MASK

	# check login cookie
	# - if failed, play the login page
	if {![ob_office::login::req_init $action]} {
		ob_log::write WARNING {http: asSetAction ob_office::login::H_login}

		# construct a redirect url
		if {$action != ""} {
			set location "?action=$action"
			for {set i 0} {$i < [reqGetNumVals]} {incr i} {
				append location "&[reqGetNthName $i]=[reqGetNthVal $i]"
			}
			tpBindString location [urlencode $location]
		}

		asSetAction ob_office::login::H_login
	}
}



# Request end
#
proc http::req_end args {
	ob_db::req_end
	ob_gc::clean_up

	ob_log::set_prefix ""
}



# Handle an enexpected error condition
#
#    msg  - error message
#
proc http::req_error { msg } {

	global ARG

	ob_gc::add ::ARG

	set action [reqGetArg action]
	if {$action == ""} {
		set action "default"
	}

	tpBindString action $action
	tpBindString msg $msg

	set ARG(total) [reqGetNumVals]
	for {set i 0} {$i < $ARG(total)} {incr i} {
		set ARG($i,name)  [reqGetNthName $i]
		set ARG($i,value) [reqGetNthVal  $i]
	}

	tpBindVar name  ARG name  idx
	tpBindVar value ARG value idx

	ob_office::util::play error.html
}



#--------------------------------------------------------------------------
# Action handler
#--------------------------------------------------------------------------

# Default action handler
#
proc http::H_default args {

	ob_log::write DEBUG {http: H_default}

	ob_office::util::play index.html
}



#--------------------------------------------------------------------------
# Util
#--------------------------------------------------------------------------

# Redirect the action to one specified within the search element of a url, i.e.
# everything after '?'
# If the action cannot be found, then plays default page.
#
#   search - search element of a url
#
proc http::redirect { search } {

	# split the search arguments (1st is the action)
	set arg [split [urldecode $search] "&"]

	# get action
	# - if not found found, then play default action
	set action [lindex $arg 0]
	if {[string first "?action=" $action] == -1} {
		return [H_default]
	}
	set action [asGetAct [string range $action 8 end]]

	# does the action handler exist
	# - if not, then play default handler
	ob_log::write DEBUG {obcm_http: redirect action=$action}
	if {$action == ""} {
		return [H_default]
	}

	# set the arguments
	for {set i 1} {$i < [llength $arg]} {incr i} {
		foreach {name value} [split [lindex $arg $i] =] {}
		reqSetArg $name $value
	}

	# execute the action
	return [eval {$action}]
}
