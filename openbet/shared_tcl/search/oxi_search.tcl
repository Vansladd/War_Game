###
# $Id: oxi_search.tcl,v 1.1 2011/10/04 12:27:42 xbourgui Exp $
#  Orbis Technology Ltd.  All rights reserved.
##

# Provides an interface to the OXi pub server search api.

# Information in array
# RESULTS(msg)          - error msg from http request or xml parsing
# RESULTS(nrows)        - number of result rows returned in the RESULTS array
# RESULTS(total_rows)   - total number of search results in the xml (up to the num_results limit)
# RESULTS(event_rows)   - number of events in the search results
# RESULTS(market_rows)  - number of markets in the search results
# RESULTS(class_rows)   - number of classes in the search results
# RESULTS(seln_rows)    - number of outcomes in the search results
# RESULTS($i,level)     - name of the type of result, e.g. "MARKET" or "OUTCOME"
# RESULTS($i,rank)      - rank of result, between 0 and 1
# RESULTS($i,id)        - database id of the result
# RESULTS($i,result)    - the matching string
# RESULTS($i,highlight) - an html fragment to highlight in the search results
# RESULTS($i,status)    - the status of the result item

package provide oxi_search

package require tdom

namespace eval oxi_search {
	variable INIT
	variable OXISERVER
	variable OXISEARCH
	variable OXISEARCH_PORT
	variable OXISEARCH_REQ_TIMEOUT
	variable OXISEARCH_CONN_TIMEOUT
	set INIT 0
}

proc oxi_search::init {} {

	variable INIT
	variable OXISERVER
	variable OXISEARCH
	variable OXISEARCH_PORT
	variable OXISEARCH_REQ_TIMEOUT
	variable OXISEARCH_CONN_TIMEOUT

	if {$INIT} {
		return
	}

	set OXISERVER              [OT_CfgGet OXI_SEARCH_SERVER ""]
	set OXISEARCH              [OT_CfgGet OXI_SEARCH_CGI ""]
	set OXISEARCH_PORT         [OT_CfgGet OXI_SEARCH_PORT 80]
	set OXISEARCH_REQ_TIMEOUT  [OT_CfgGet OXI_SEARCH_REQ_TIMEOUT 10000]
	set OXISEARCH_CONN_TIMEOUT [OT_CfgGet OXI_SEARCH_CONN_TIMEOUT 10000]

	set INIT 1

}

# Procedure oxi_search::search
# Arguments are:
# RESULTS_ARRAY      - the name of the array into which results are placed
# search_string      - the string to search for
# channels           - filter the results by bettable channels, the argument is a list of channels
#                      identified by their letters, e.g. "I".
# lang               - the language of the results
# outcome 0|1        - If outcome = 1, only return outcomes in the search results
# rank 0|1           - If rank = 1, order the results by rank
# start_result       - Ignore the results returned by the search server up to this result. This
#                      functionality is useful for searching through multiple pages of results.
# num_results        - The number of results to fetch from the search server
# status 0|1         - If status = 1, only return results with an active status
# partial 0|1        - Allow partial matching if supported
# start_tag          - opening tag for highlight
# end_tag            - closing tag for highlight
# partial_min_length - Minimum length of string to partial match
# category           - Only return results for the given category
# max_results        - Maximum number of results to return
# filter_class_ids   - Class Ids to exclude from search results
# dateFrom           - Date filter (either 'YYYY-MM-DD HH:MM:SS' or human readable)
# dateTo             - Date filter (either 'YYYY-MM-DD HH:MM:SS' or human readable)
# allow_is_off       - Return events marke as off
# headline           - Return the search headline
# retrospecive 0|1   - Perform a retrospective search
# class              - Only return results for the given class


proc oxi_search::search {
	RESULTS_ARRAY
	search_string
	channels
	{lang "en"}
	{level ""}
	{rank 1}
	{start_result 0}
	{num_results 0}
	{status 0}
	{partial 1}
	{start_tag ""}
	{end_tag ""}
	{partial_min_len 1}
	{category ""}
	{max_results 0}
	{filter_class_ids ""}
	{date_from ""}
	{date_to ""}
	{allow_is_off 0}
	{headline 1}
	{retrospecive 0}
	{class ""}} {

	upvar 1 $RESULTS_ARRAY RESULTS

	set req [oxi_search::_make_request $search_string $channels $rank $level \
		$lang $status $partial $start_tag $end_tag $partial_min_len $category \
		$max_results $filter_class_ids $date_from $date_to $allow_is_off \
		$headline $retrospecive $class]

	if {![lindex $req 0]} {
		ob_log::write ERROR {oxi_search::search http request failed [lindex $req 1]}
		set RESULTS(nrows) 0
		set RESULTS(msg) "http request failed: [lindex $req 1]"
		return 0
	}

	set xml [lindex $req 1]

	set parse [oxi_search::_parse_xml_response $xml RESULTS $level $start_result $num_results]

	if {![lindex $parse 0]} {
		set debug [lindex $parse 3]
		set code  [lindex $parse 2]
		ob_log::write ERROR {oxi_search::search xml parse failed [lindex $parse 1]}
		set RESULTS(nrows) 0
		if {$code == 111} {
			set RESULTS(msg) "Search failed: $debug"
		} else {
			set RESULTS(msg) "xml parsing failed: [lindex $parse 1]"
		}
		return 0
	}

	set RESULTS(msg) "success"

	return 1
}

proc oxi_search::_make_request {
		search_string
		channels
		rank
		level
		lang status
		partial
		start_tag
		end_tag
		partial_min_len
		category
		max_results
		filter_class_ids
		date_from
		date_to
		allow_is_off
		headline
		retrospecive
		class} {

	variable OXISERVER
	variable OXISEARCH
	variable OXISEARCH_PORT
	variable OXISEARCH_REQ_TIMEOUT
	variable OXISEARCH_CONN_TIMEOUT
	
	set search_string [urlencode $search_string]

	set channels [urlencode [join $channels ""]]

	set params [list \
		template        search\
		query           $search_string\
		output          xml\
		lang            $lang\
		rank            $rank\
		channels        $channels\
		level           $level\
		status          $status\
		partial         $partial\
		hlStartTag      $start_tag\
		hlEndTag        $end_tag\
		partialMinLen   $partial_min_len\
		category        $category\
		maxResults      $max_results\
		filterClassIds  $filter_class_ids\
		allowIsOff      $allow_is_off\
		headline        $headline\
		class           $class\
		dateFrom        $date_from\
		dateTo          $date_to\
		retrospective   $retrospecive]

	if {[catch {
		ob_log::write INFO {oxi_search::_make_request: making request for http://$OXISERVER$OXISEARCH?$params}

		set req [::ob_socket::format_http_req -host $OXISERVER \
			-method "POST" \
			-form_args $params\
			-urlencode_unsafe 0\
			"$OXISEARCH"]

		foreach {req_id status complete} [::ob_socket::send_req -conn_timeout $OXISEARCH_CONN_TIMEOUT -req_timeout $OXISEARCH_REQ_TIMEOUT -is_http 1 $req $OXISERVER $OXISEARCH_PORT] {break}
		if {$status == "OK"} {
			set xml [::ob_socket::req_info $req_id http_body]
			ob_log::write DEBUG {$xml}
		} else {
			error $status
		}
		::ob_socket::clear_req $req_id} msg]} {
		return [list 0 $msg]
	}

	return [list 1 $xml]

}

proc oxi_search::_parse_xml_response {xml RESULTS_ARRAY {hier_level ""} {start_result 0} {num_results 0}} {

	upvar 1 $RESULTS_ARRAY RESULTS

	if {[catch {set doc [dom parse $xml]} msg]} {
		ob_log::write ERROR {oxi_search::_parse_xml_response xml parsing failed: $msg}
		return [list 0 $msg]
	}

	set root   [$doc documentElement]

	set response [$root selectNodes /oxip/response]

	set request  [$response getAttribute request  ""]
	set code     [$response getAttribute code     ""]
	set message  [$response getAttribute message  ""]
	set debug    [$response getAttribute debug    ""]
	set provider [$response getAttribute provider ""]

	if {$debug != ""} {
		ob_log::write DEBUG {$debug}
	}

	if {$code != "001"} {
		return [list 0 $message $code $debug]
	}

	set type_rows     0
	set event_rows    0
	set market_rows   0
	set outcome_rows  0
	set class_rows    0
	set i             0
	set skipped       0
	set total_results 0

	foreach result [$response childNodes] {
		
		if {[$result nodeName] != "result"} {
			continue
		}

		set level         [$result getAttribute level   ""]
		set id            [$result getAttribute id      ""]
		set rank          [$result getAttribute rank    ""]
		set attrresult    [$result getAttribute result  ""]
		set classId       [$result getAttribute classId ""]
		set typeId        [$result getAttribute typeId  ""]
		set eventId       [$result getAttribute eventId ""]
		set status        [$result getAttribute status  ""]
		set highlight     [string trim [$result asText]]

		# Encode this to unicode. This was causing an issue for utf-8 langs
		# like chinese.
		set highlight     [encoding convertfrom utf-8 $highlight]

		if {$num_results != 0 && $i >= $num_results} {
			break
		}

		if {$level != ""} {
			switch [string tolower $level] {
				"type"      { incr type_rows }
				"event"     { incr event_rows }
				"market"    { incr market_rows }
				"outcome"   { incr outcome_rows }
				"class"     { incr class_rows }
				"default"   { ob_log::write ERROR {oxi_search::_parse_xml_response: Unrecognised hierarchy level $level in the xml result set}
						continue}
			}
			incr total_results
		}

		if {$skipped < $start_result} {
			incr skipped
			continue
		}

		if {$level != "" && $id != ""} {

			set RESULTS($i,level)     $level
			set RESULTS($i,id)        $id
			set RESULTS($i,rank)      $rank
			set RESULTS($i,result)    $attrresult
			set RESULTS($i,highlight) $highlight
			set RESULTS($i,status)    $status

			if {$hier_level == "OUTCOME"} {
				set RESULTS($i,classId) $classId
				set RESULTS($i,typeId)  $typeId
				set RESULTS($i,eventId) $eventId
			}

			incr i
		}
	}

	set RESULTS(nrows)        $i
	set RESULTS(total_rows)   $total_results
	set RESULTS(type_rows)    $type_rows
	set RESULTS(event_rows)   $event_rows
	set RESULTS(market_rows)  $market_rows
	set RESULTS(outcome_rows) $outcome_rows
	set RESULTS(class_rows)   $class_rows

	return [list 1 ""]
}
