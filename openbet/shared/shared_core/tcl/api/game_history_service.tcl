#
# © 2011 OpenBet Technology Ltd. All rights reserved.
#
# The following procedures are made available for invoking web services on
# the game history module. Results are returned as lists of name-value pairs.
#
#
# Error codes:
#   GHS_ERROR_MANDATORY_FIELD
#   GHS_ERROR_DB
#   GHS_ERROR_SEND_REQ
#   GHS_ERROR_XML_PARSING
#   GHS_ERROR_WRONG_CUSTOMER
#   GHS_ERROR_NO_DATA
#

set pkg_version 1.0
package provide core::game_history_service $pkg_version

package require core::socket       1.0
package require core::xml          1.0
package require core::db::schema   1.0
package require core::xl           1.0
package require tdom

core::args::register_ns \
	-namespace core::game_history_service \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args] \
	-docs      xml/api/game_history_service.xml

namespace eval core::game_history_service {
	variable CFG

	set CFG(init) 0
}


#
# Initialise game_history_service package
#
core::args::register \
	-proc_name core::game_history_service::init \
	-args [list \
		[list -arg -service_host          -mand 0 -check ASCII -default localhost -desc {Service host}] \
		[list -arg -service_port          -mand 0 -check UINT  -default 8084      -desc {Service port}] \
		[list -arg -summary_url           -mand 0 -check ANY   -default 1         -desc {Service URL for summary game history}] \
		[list -arg -detail_url            -mand 0 -check ANY   -default 1         -desc {Service URL for summary detailed history}] \
		[list -arg -conn_timeout          -mand 0 -check UINT  -default 10000     -desc {Connection timeout}] \
		[list -arg -req_timeout           -mand 0 -check UINT  -default 10000     -desc {Request timeout}] \
	] \
	-body {
		variable CFG

		if {$CFG(init)} { return }

		core::log::write INFO {Initialising core::game_history_service}

		set CFG(service_host) $ARGS(-service_host)
		set CFG(service_port) $ARGS(-service_port)
		set CFG(conn_timeout) $ARGS(-conn_timeout)
		set CFG(req_timeout)  $ARGS(-req_timeout)
		set CFG(summary_url)  $ARGS(-summary_url)
		set CFG(detail_url)   $ARGS(-detail_url)

		prep_qrys

		# Main Node - SubNode - Elements subnode contains - required in the response - dict key
		set CFG(detailed_response_format) [list \
			GameDetail        Gameplay     gameplay_elements     1 gameplay_info\
			ProgressiveDetail Progressive  progressive_elements  0 progressive_info \
			BonusInformation  Bonus        bonus_elements        0 bonus_info \
			WageringReqtInfo  WageringReqt wageringreqt_elements 0 wageringreqt_info \
			HeldFundsInfo     HeldFund     heldfund_elements     0 heldfund_info \
		]

		# This is a mapping to the response elements from ghs and the dict elements
		# from this package
		# Format for the below:
		# GHS Response Element - Response Dict Key - Needs translation
		set CFG(summary_elements) [list \
			GameSummaryID       id                   0\
			StartDate           cr_date              0\
			FinishDate          finished             0\
			GameName            game_name            0\
			DisplayName         name                 1\
			Class               class                0\
			Source              source               0\
			TotalStakes         stakes               0\
			TokenStakes         token_stakes         0\
			TotalWinnings       winnings             0\
			AccumulatorWinnings accumulator_winnings 0\
			Status              status               1\
		]

		set CFG(gameplay_elements) [list \
			GameSummaryID id           0\
			StartDate     cr_date      0\
			FinishDate    finished     0\
			Name          game_name    0\
			DisplayName   name         1\
			Class         class        0\
			Stakes        stakes       0\
			TokenStakes   token_stakes 0\
			Winnings      winnings     0\
			Status        status       1\
		]

		set CFG(progressive_elements) [list \
			ProgSummaryID     id                 0\
			AdvertisedJackpot advertised_jackpot 0\
			Jackpot           jackpot            0\
			ProgContribution  prog_contribution  0\
			Stakes            stakes             0\
			Winnings          winnings           0\
			BonusWinnings     bonus_winnings     0\
			DrawResult        draw_result        0\
		]

		set CFG(bonus_elements) [list \
			BonusName        name              0\
			BonusDescription description       0\
			CustomerTokenID  customer_token_id 0\
			RedeemedAmount   redeemed_amount   0\
		]

		set CFG(wageringreqt_elements) [list \
			BonusName        name              0\
			BonusDescription description       0\
			CustomerTokenID  customer_token_id 0\
			OpType           op_type           0\
			Amount           amount            0\
			Balance          balance           0\
		]

		set CFG(heldfund_elements) [list \
			BonusName        name              0\
			BonusDescription description       0\
			CustomerTokenID  customer_token_id 0\
			OpType           op_type           0\
			Amount           amount            0\
			Balance          balance           0\
		]

		set CFG(init) 1
	}

#
# This proc gets all the available request parameters and builds the request
# for summary game history
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
#core::args::register \
#	-proc_name core::gamehistoryservice::build_summary_request \
#	-args [list \
#		[list -arg -cust_id     -mand 0 -check UINT     -default -1 -desc {Customer's Id to get summary game history}] \
#		[list -arg -acct_id     -mand 0 -check UINT     -default -1 -desc {Customer's account Id to get summary game history}] \
#		[list -arg -min_date    -mand 1 -check DATETIME             -desc {Start time for game summary history}] \
#		[list -arg -max_date    -mand 1 -check DATETIME             -desc {End time for game summary history}] \
#		[list -arg -source      -mand 0 -check ASCII    -default {} -desc {Source / Channel}] \
#		[list -arg -cg_id       -mand 0 -check UINT     -default {} -desc {Category Id of the games in game summary}] \
#		[list -arg -page_size   -mand 0 -check UINT     -default {} -desc {Page size of the game summary}] \
#		[list -arg -page_no     -mand 0 -check UINT     -default {} -desc {Page number to be returned}] \
#		[list -arg -period_type -mand 0 -check {ENUM -args {startdate finishdate}} -default {startdate} -desc {Get game summary history based on startdate/finishdate}] \
#		[list -arg -status      -mand 0 -check {ENUM -args {O C X P J}}            -default {}          -desc {Status of the games in game summary}] \
#	] \
#	-body {
#		variable CFG
#
#		array set ARGS [core::args::check core::gamehistoryservice::build_summary_request {*}$args]
#
#		# We can get game summary with either cust_id or acct_id. If none of them
#		# is present we return
#		if {$ARGS(-cust_id) == -1 && $ARGS(-acct_id)} {
#			return [list 0 GHS_ERROR_MANDATORY_FIELD]
#		}
#
#		# Build request document
#		set doc [dom createDocument GameHistorySummaryRequest]
#		$doc encoding utf-8
#
#		set root              [$doc documentElement]
#		core::xml::add_element -node $root -name PeriodStart -value $ARGS(-min_date)
#		core::xml::add_element -node $root -name PeriodEnd   -value $ARGS(-max_date)
#		core::xml::add_element -node $root -name PeriodType  -value $ARGS(-period_type)
#
#		# Parameter   -   Request Element
#		set optional_parameters [list \
#			$ARGS(-source)    Source \
#			$ARGS(-cg_id)     CgId \
#			$ARGS(-page_size) PageSize \
#			$ARGS(-page_no)   PageNo \
#			$ARGS(-status)    Status \
#		]
#
#		set has_optional_parameters 0
#		foreach {value elem} $optional_parameters {
#			if {!$has_optional_parameters && $value != {}} {
#				set optional_node [core::xml::add_element -node $root -name xmlFilters]
#				core::xml::add_element -node $optional_node -name $elem -value $value
#				set has_optional_parameters 1
#			} elseif {$has_optional_parameters && $value != {}} {
#				core::xml::add_element -node $optional_node -name $elem -value $value
#			}
#		}
#
#		# Send the request parse the response return results
#	}



#
# Sends REST request and returns XML response or error message
#
# This request is a POST request to GHS.
# @return list in form of {0 ERROR_CODE} or {1 "xml_data"}
#core::args::register \
#	-proc_name core::gamehistoryservice::_do_summary_request \
#	-args [list \
#		[list -arg -doc -mand 1 -check ALNUM  -desc {XML document reference to send}] \
#		[list -arg -ref -mand 1 -check ASCII  -desc {Object reference name}] \
#	] \
#	-body {
#		variable CFG
#
#		array set ARGS [core::args::check core::gamehistoryservice::do_summary_request {*}$args]
#
#		set doc  $ARGS(-doc)
#		set ref  $ARGS(-ref)
#		set root [$doc documentElement]
#
#		set fn {core::gamehistoryservice::_do_summary_request}
#
#		set request_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n[$root asXML]"
#
#		$doc delete
#
#		foreach line [split $request_xml \n] {
#			core::log::write INFO {REQ $line}
#		}
#
#		if {![info exists CFG(summary_url)]} {
#			return [list 0 GHS_ERROR_SEND_REQ "Unknown reference $ref"]
#		}
#
#		if {[catch {
#			set req [core::socket::format_http_req \
#				-host       $CFG(service_host) \
#				-method     "POST" \
#				-headers    [list Content-Type application/xml] \
#				-post_data  $request_xml \
#				-url        $CFG(summary_url)]
#		} msg]} {
#			core::log::write ERROR {$fn Unable to build verification request: $msg}
#			return [list 0 GHS_ERROR_SEND_REQ]
#		}
#
#		set args [list -is_http 1]
#		lappend args -conn_timeout $CFG(conn_timeout)
#		lappend args -req_timeout  $CFG(req_timeout)
#
#		lappend args \
#			-req  $req \
#			-host $CFG(service_host) \
#			-port $CFG(service_port) \
#			-encoding utf-8
#
#		# Send the request to the verification module
#		if {[catch {
#			foreach {req_id status complete} \
#			[core::socket::send_req {*}$args] {break}
#		} msg]} {
#			core::log::write ERROR {$fn Unexpected error contacting Game History Service: $msg}
#			return [list 0 GHS_ERROR_SEND_REQ]
#		}
#
#		# get response
#		set response [string trim [core::socket::req_info \
#			-req_id $req_id \
#			-item http_body]]
#
#		core::socket::clear_req -req_id $req_id
#
#		if {$status != "OK"} {
#			set desc [_extract_http_error_desc $response]
#			core::log::write ERROR {$fn Server returned error: $status : $desc}
#			return [list 0 GHS_ERROR_SEND_REQ $desc]
#		}
#
#		set ret [core::xml::parse -xml $response -strict 0]
#		if {[lindex $ret 0] != {OK}} {
#			core::log::write ERROR {$fn xml parsing failed: $msg}
#			return [list 0 GHS_ERROR_XML_PARSING $msg]
#		}
#
#		set doc [lindex $ret 1]
#
#		core::log::write DEBUG {RESP $response}
#
#		return [list 1 $doc]
#	}


#
# This proc sends a request to game history service to retrieve detailed information
# about a game
#
# return: throws an error
#         or dict containing all the game detailed information {key value key1 value1...} {...}}
#
core::args::register \
	-proc_name core::game_history_service::get_details \
	-args [list \
		[list -arg -game_id -mand 1 -check UINT  -desc {Game Id}] \
		[list -arg -acct_id -mand 1 -check UINT  -desc {Customer's account id}] \
		[list -arg -lang    -mand 1 -check ASCII -desc {Language code for customer}] \
	] \
	-body {
		variable CFG

		set fn {core::game_history_service::get_details}

		set url "$CFG(detail_url)/$ARGS(-game_id)"

		# We will check if the this game belongs to the account id passed in
		if {[catch {set rs [core::db::exec_qry -name core::game_history_service::check_game \
			-args [list $ARGS(-game_id) $ARGS(-acct_id)]]} err]} {
			core::log::write ERROR {Unable to execute query: $err}
			error {Unable to execute query} $::errorInfo GHS_ERROR_DB
		}

		if {[db_get_nrows $rs] != 1} {
			core::log::write ERROR {$fn: Game does not belong to user}
			error {Game does not belong to user} {} GHS_ERROR_WRONG_CUSTOMER
		}


		if {[catch {set ret [core::game_history_service::_do_detail_request -url $url]} msg]} {
			core::log::write ERROR {$fn: Error sending request to Game History Service}
			error {Error sending request to Game History Service} $::errorInfo
		}

		set doc      $ret
		set root     [$doc documentElement]
		set response [$root selectNodes {/GameHistoryDetail}]

		# This happens if the response does not contain GameHistoryDetail node
		if {$response == {}} {
			core::log::write ERROR {$fn: Game history service returned empty data set}
			error {Game history service returned empty data set} {} GHS_ERROR_NO_DATA
		}

		# The results will be returned as a dict
		set results [dict create]

		set summary_node [$response getElementsByTagName {GameSummary}]

		if {$summary_node == {}} {
			core::log::write ERROR {$fn: Game history service returned response without summary information}
			error {Game history service returned response without summary information} {} GHS_ERROR_NO_DATA
		}

		foreach {el_name dict_key xl} $CFG(summary_elements) {
			set element [$summary_node getElementsByTagName $el_name]
			if {$element != {}} {
				if {$xl} {
					set value [core::xl::XL -str [$element asText] -lang -$ARGS(-lang)]
				} else {
					set value [$element asText]
				}
			} else {
				set value {}
			}
			dict set results $dict_key $value
		}


		# Gameplay, bonus, wageringreqt, progressive and heldfund information will
		# be represented as list of dicts since there might be multiple nodes in the
		# response.
		foreach {main_node sub_node elements required dict_key} $CFG(detailed_response_format) {
			set game_info [list]
			set cur_main_node [$response getElementsByTagName $main_node]

			if {$cur_main_node != {}} {
				foreach cur_sub_node [$cur_main_node getElementsByTagName $sub_node] {

					if {$cur_sub_node != {}} {
						set cur_dict [dict create]

						foreach {el_name key xl} $CFG($elements) {
							set cur_element [$cur_sub_node getElementsByTagName $el_name]
							if {$cur_element != {}} {
								if {$xl} {
									set value [core::xl::XL -str [$cur_element asText] -lang -$ARGS(-lang)]
								} else {
									set value [$cur_element asText]
								}
							} else {
								set value {}
							}
							dict set cur_dict $key $value
						}

						lappend game_info $cur_dict
					}

				}
			}

			if {$required && $game_info == {}} {
				core::log::write ERROR {$fn: Game History Service didn't return mandatory element}
				error {Game History Service didn't return mandatory element} {} GHS_ERROR_NO_DATA
			}
			dict set results $dict_key $game_info

		}

		return $results
	}

#
# Send REST request and get the response
#
# This request is a GET request to GHS.
# @return list in form of {0 ERROR_CODE} or {1 "xml_data"}
core::args::register \
	-proc_name core::game_history_service::_do_detail_request \
	-args [list \
		[list -arg -url -mand 1 -check ASCII  -desc {Object reference name}] \
	] \
	-body {
		variable CFG

		set fn {core::game_history_service::_do_detail_request}

		if {[catch {
			set req [core::socket::format_http_req \
				-host       $CFG(service_host) \
				-headers    [list Accept {application/xml;q=0.9,*/*;q=0.8}] \
				-method     "GET" \
				-url        $ARGS(-url)]
		} msg]} {
			core::log::write ERROR {$fn Unable to build game history detail request: $msg}
			error {Unable to build game history detail request} $::errorInfo GHS_ERROR_SEND_REQ
		}

		set args [list -is_http 1]
		lappend args -conn_timeout $CFG(conn_timeout)
		lappend args -req_timeout  $CFG(req_timeout)

		lappend args \
			-tls  -1 \
			-req  $req \
			-host $CFG(service_host) \
			-port $CFG(service_port) \
			-encoding utf-8

		# Send the request to the verification module
		if {[catch {
			foreach {req_id status complete} \
			[core::socket::send_req {*}$args] {break}
		} msg]} {
			core::log::write ERROR {$fn Unexpected error contacting Game History Service: $msg}
			error {Unexpected error contacting Game History Service} $::errorInfo GHS_ERROR_SEND_REQ
		}

		# get response
		set response [string trim [core::socket::req_info \
			-req_id $req_id \
			-item http_body]]

		core::socket::clear_req -req_id $req_id

		if {$status != "OK"} {
			set desc [_extract_http_error_desc $response]
			core::log::write ERROR {$fn Server returned error: $status : $desc}
			error $desc {} GHS_ERROR_SEND_REQ
		}

		set ret [core::xml::parse -xml $response -strict 0]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {$fn xml parsing failed: [lindex $ret 1]}
			error {Response xml parsing failed} {} GHS_ERROR_XML_PARSING
		}

		set doc [lindex $ret 1]

		core::log::write DEBUG {RESP $response}

		return $doc
	}

#
# Private proc to parse the error response and get the description of the error
#
proc core::game_history_service::_extract_http_error_desc {response} {


	set desc {}

	set ret [core::xml::parse -xml $response -strict 0]
	if {[lindex $ret 0] != {OK}} {
		return $desc
	}

	set root [[lindex $ret 1] documentElement]

	set message_node [$root selectNodes {/ServiceError/Message}]

	if {$message_node != {}} {
		set desc [$message_node asText]
	}

	return $desc
}

#
# Private proc to prepare any required queries.
#
proc core::game_history_service::prep_qrys {} {

	core::db::store_qry \
		-cache 0 \
		-name core::game_history_service::check_game \
		-qry {
			select
				cg_game_id
			from
				tCGGameSummary s
				inner join tCGAcct ga on (ga.cg_acct_id = s.cg_acct_id)
				inner join tAcct   a  on (a.acct_id     = ga.acct_id)
			where
				s.cg_game_id = ?
				and a.acct_id = ?
		}
}