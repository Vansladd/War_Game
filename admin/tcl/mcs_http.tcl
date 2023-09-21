# $Id: mcs_http.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $


#package require dom
#namespace import dom::*

package require xml
namespace import xml::*


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

###############################################################################
# is the response valid?
#
proc validateResponse {http_response} {

	set http_error 		[http::error $http_response]
	set http_code 		[http::code $http_response]
	set http_wait 		[http::wait $http_response]

	if {$http_wait != "ok"} {
		err_bind "failed to contact mcs: code=$http_wait"
		return TIMEOUT
	}
	if {$http_error != ""} {
		err_bind "failed to contact mcs: code=$http_error"
		return HTTP_ERROR
	}
	if {$http_code != "HTTP/1.1 200 OK"} {
		err_bind "failed to contact mcs: code=$http_code"
		return HTTP_WRONG_CODE
	}
	return OK
}


###############################################################################
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

###############################################################################
# handlers for the XML parser
#
# fills the XML_RESPONSE array with nodes and node names
proc handleStart {name attlist} {

	global XML_NAME
	lappend XML_NAME $name
}

proc handleText {data} {

	global XML_NAME XML_RESPONSE

	set trimmed [string trim $data]

	if {$trimmed != ""} {
		set array_key [join $XML_NAME ,]
		set XML_RESPONSE($array_key) $trimmed

		OT_LogWrite 7 "$array_key=$trimmed"
	}
}

proc handleEnd {name} {

	global XML_NAME
	set XML_NAME [lrange $XML_NAME 0 end-1]
}

