# $Id: qas.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $

package require net_socket
package require tdom
package require util_db
package require util_log

namespace eval qas {
	# How many items to return in admin QAS search
	variable THRESHOLD
	# Is QAS already initialized ?
	variable INIT 0
}

#
# Initialize QAS.
#
proc qas::init {} {
	variable THRESHOLD
	variable INIT

	if { $INIT == 0 } {
		# Set THRESHOLD value, defaulting to 50
		set THRESHOLD [OT_CfgGet QAS_ADDR_THRESHOLD 50]

		ob_log::write INFO {Initializing QAS module. Threshold is: $THRESHOLD}
	
		set INIT 1
	}

}



#------------------------------------------------------------------------------
# XML building procs
#------------------------------------------------------------------------------

#
# desc    : XML - build basic body.
# params  : n/a
# returns : XMLNode
#
# <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://www.qas.com/web-2005-10">
#     <soap:Body>
# 		...
#     </soap:Body>
# </soapenv:Envelope>
#
proc qas::_build_body {} {

	variable XML_DOM
	catch {$XML_DOM delete}

	# Create new XML document
	dom setResultEncoding "UTF-8"
	set XML_DOM [dom createDocument "soapenv:Envelope"]

	set E_Envelope [$XML_DOM documentElement]

	$E_Envelope setAttribute \
		"xmlns:soapenv" "http://schemas.xmlsoap.org/soap/envelope/" \
		"xmlns:web" "http://www.qas.com/web-2005-10"

	set E_Body [$XML_DOM createElement "soap:Body"]
	$E_Envelope appendChild $E_Body

	return $E_Body
}



#
# desc    : XML - build singleline search request.
# params  : address string separted by '|'
# returns : XML String
#
# <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
#     <soap:Body>
#         <QASearch xmlns="http://www.qas.com/web-2005-10">
#             <Country>GBR</Country>
#             <Engine Flatten="false" Th>Singleline</Engine>
#             <Layout>Strict Postal</Layout>
#             <Search>
# 			Chiswick High Rd|w45tf
#             </Search>
#         </QASearch>
#     </soap:Body>
# </soap:Envelope>
#
proc qas::_build_singleline_search {addr_str} {
	variable XML_DOM
	variable THRESHOLD

	set E_Body    [_build_body]

	set E_QASearch [$XML_DOM createElement "QASearch"]
	$E_Body setAttribute "xmlns" "http://www.qas.com/web-2005-10"
	$E_Body appendChild $E_QASearch

	set E_Country [$XML_DOM createElement "Country"]

	$E_Country appendChild [$XML_DOM createTextNode "GBR"]
	$E_QASearch appendChild $E_Country

	set E_Engine [$XML_DOM createElement "Engine"]
	$E_Engine appendChild [$XML_DOM createTextNode "Singleline"]
	$E_Engine setAttribute "Threshold" $THRESHOLD
	$E_QASearch appendChild $E_Engine

	set E_Layout [$XML_DOM createElement "Layout"]
	$E_Layout appendChild [$XML_DOM createTextNode "Strict Postal"]
	$E_QASearch appendChild $E_Layout

	# Add the node.
	set E_SearchTerm [$XML_DOM createElement "Search"]
	$E_SearchTerm appendChild [$XML_DOM createTextNode $addr_str]
	$E_QASearch   appendChild $E_SearchTerm

	return [$XML_DOM asXML]
}



#
# desc    : XML - build Experian search request.
# params  : address string separated by '|'
# returns : XML String
# <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://www.qas.com/web-2005-10">
# 	<soap:Body xmlns="http://www.qas.com/web-2005-10">
# 		<QASearch>
# 			<Country>GBR</Country>
# 			<Engine Threshold="50">Verification</Engine>
# 			<Layout>Experian</Layout>
# 			<Search>Flat 5 45 Something Road|Burton|Dorset|CHRISTCHURCH|BH23 7LT</Search>
# 		</QASearch>
# 	</soap:Body>
# </soapenv:Envelope
#				  
proc qas::_build_verification_search {addr_str} {
	variable XML_DOM
	variable THRESHOLD

	set E_Body    [_build_body]

	set E_QASearch [$XML_DOM createElement "QASearch"]
	$E_Body setAttribute "xmlns" "http://www.qas.com/web-2005-10"
	$E_Body appendChild $E_QASearch

	set E_Country [$XML_DOM createElement "Country"]

	$E_Country appendChild [$XML_DOM createTextNode "GBR"]
	$E_QASearch appendChild $E_Country

	set E_Engine [$XML_DOM createElement "Engine"]
	$E_Engine appendChild [$XML_DOM createTextNode "Verification"]
	$E_Engine setAttribute "Threshold" $THRESHOLD
	$E_QASearch appendChild $E_Engine

	set E_Layout [$XML_DOM createElement "Layout"]
	$E_Layout appendChild [$XML_DOM createTextNode "Experian"]
	$E_QASearch appendChild $E_Layout

	# Add the node.
	set E_SearchTerm [$XML_DOM createElement "Search"]
	$E_SearchTerm appendChild [$XML_DOM createTextNode $addr_str]
	$E_QASearch   appendChild $E_SearchTerm

	return [$XML_DOM asXML]
}



# <?xml version="1.0"?>
# <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
#     <soap:Body>
#         <QASearch xmlns="http://www.qas.com/web-2005-10">
#             <Country>GBR</Country>
#             <Engine>Authenticate</Engine>
#             <SearchSpec>
#                 <SearchTerm Key="CTRL_SEARCHCONSENT">Y</SearchTerm>
#                 <SearchTerm Key="NAME_DATEOFBIRTH">22/09/1974</SearchTerm>
#                 <SearchTerm Key="CTRL_CHANNEL">I</SearchTerm>-->
#                 <SearchTerm Key="ADDR_HOUSENUMBER">2</SearchTerm>
#                 <SearchTerm Key="ADDR_STREET">Petersfield Road</SearchTerm>
#                 <SearchTerm Key="ADDR_TOWN">London</SearchTerm>-->
#                 <SearchTerm Key="ADDR_POSTCODE">W3 8NY</SearchTerm>
#                 <SearchTerm Key="ADDR_COUNTY">London</SearchTerm>-->
#                 <SearchTerm Key="NAME_INITIALS">R</SearchTerm>-->
#                 <SearchTerm Key="NAME_TITLE">MR</SearchTerm>-->
#                 <SearchTerm Key="NAME_FORENAME">PAUL</SearchTerm>
#                 <SearchTerm Key="NAME_SURNAME">OLIVER</SearchTerm>
#                 <SearchTerm Key="NAME_SEX">M</SearchTerm>-->
#             </SearchSpec>
#         </QASearch>
#     </soap:Body>
# </soap:Envelope>
#
# params : array as list.
# return : xml string.
#
proc qas::_build_authenticate_search {auth_lst} {
	variable XML_DOM
	variable THRESHOLD

	set E_Body    [_build_body]

	set E_QASearch [$XML_DOM createElement "QASearch"]
	$E_Body setAttribute "xmlns" "http://www.qas.com/web-2005-10"
	$E_Body appendChild $E_QASearch

	set E_Country [$XML_DOM createElement "Country"]

	$E_Country appendChild [$XML_DOM createTextNode "GBR"]
	$E_QASearch appendChild $E_Country

	set E_Engine [$XML_DOM createElement "Engine"]
	$E_Engine appendChild [$XML_DOM createTextNode "Authenticate"]
	$E_QASearch appendChild $E_Engine

	set E_SearchSpec [$XML_DOM createElement "SearchSpec"]
	$E_QASearch appendChild $E_SearchSpec

	array set AUTH_ARR $auth_lst

	# Add all search term elements.
	foreach key_name [array names AUTH_ARR] {
		# Create element.
		if {
			[info exists AUTH_ARR($key_name)] &&
			[string length $AUTH_ARR($key_name)] > 0
		} {
			set E_SearchTerm [$XML_DOM createElement "SearchTerm"]
			$E_SearchTerm appendChild [$XML_DOM createTextNode $AUTH_ARR($key_name)]
			$E_SearchTerm setAttribute "Key" $key_name
			$E_SearchSpec appendChild $E_SearchTerm
		} else {
			ob_log::write DEV "Skipped: '$key_name' has no value."
		}

	}

	return [$XML_DOM asXML]
}



#
# desc    : XML - build refine request.
# params  : moniker - the id for qas to identify a point in the search process.
# returns : XML String
#
# <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://www.qas.com/web-2005-10">
#    <soapenv:Body>
#       <web:QARefine>
#          <web:Moniker>6OGBRFQPYBwMAAQABZAHSAAAAAAAAZAA-</web:Moniker>
#          <!--<web:Refinement></web:Refinement>-->
#       </web:QARefine>
#    </soapenv:Body>
# </soapenv:Envelope>
#
proc qas::_build_refine {moniker} {
	variable XML_DOM
	variable THRESHOLD

	set E_Body [_build_body]

	set E_QARefine [$XML_DOM createElement "QARefine"]
	$E_Body setAttribute "Threshold" $THRESHOLD
	#$E_Body setAttribute "xmlns" "http://www.qas.com/web-2005-10"
	$E_Body appendChild $E_QARefine

	set E_Moniker [$XML_DOM createElement "Moniker"]
	$E_Moniker appendChild [$XML_DOM createTextNode $moniker]
	$E_QARefine appendChild $E_Moniker

	set E_Refinement [$XML_DOM createElement "Refinement"]
	$E_Refinement appendChild [$XML_DOM createTextNode ""]
	$E_QARefine appendChild $E_Refinement

	return [$XML_DOM asXML]
}



#
# desc    : XML - build get address request (the final formatted request).
# params  : moniker - the id for qas to identify a point in the search process.
#           layout  - layout of the request ie "strict postal", this decides
#                     the format the xml will come back in.
# returns : XML String
#
#<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://www.qas.com/web-2005-10">
#   <soapenv:Header/>
#   <soapenv:Body>
#      <web:QAGetAddress>
#         <web:Layout>Strict Postal</web:Layout>
#         <web:Moniker>6OGBRFQPYBwMAAQABZAHSAAAAAAAAZAA-</web:Moniker>
#      </web:QAGetAddress>
#   </soapenv:Body>
#</soapenv:Envelope>
#
proc qas::_build_get_address {MONIKER layout} {
	variable XML_DOM

	set E_Body [_build_body]

	set E_QAGetAddress [$XML_DOM createElement "QAGetAddress"]
	$E_Body appendChild $E_QAGetAddress

	set E_Layout [$XML_DOM createElement "Layout"]

	$E_Layout appendChild [$XML_DOM createTextNode $layout]
	$E_QAGetAddress appendChild $E_Layout

	set E_Moniker [$XML_DOM createElement "Moniker"]
	$E_Moniker appendChild [$XML_DOM createTextNode $MONIKER]
	$E_QAGetAddress appendChild $E_Moniker

	return "[$XML_DOM asXML]"
}



#------------------------------------------------------------------------------
# Action procs
#------------------------------------------------------------------------------

#
# desc    : Do qas singleline serach (for address completion).
# params  : address string.
# returns : see [_parse_picklist]
#
proc qas::do_singleline_search {addr_str} {
	set req  [_build_singleline_search $addr_str]
	set resp [_send_req $req "DoSearch"]

	# Get results array from picklist.
	return [_parse_picklist $resp]
}



# desc    : Do qas search using Experian layout
# params  : address string.
# returns : see [_parse_address]
#
proc qas::do_verification_search {addr_str} {
	set req  [_build_verification_search $addr_str]
	set resp [_send_req $req "DoSearch"]

	# Check the VerifyLevel - if it's not Verified or InteractionRequired then we return an empty list
	variable XML_DOM

	# Get root element.
	set XML_DOM [dom parse $resp]
	set xml [$XML_DOM documentElement]

	# Get all the address elements
	set search_result [$xml getElementsByTagName "qas:QASearchResult"]
	
	if {$search_result != ""} {
		set verify_level  [$search_result getAttribute "VerifyLevel"]
	} else {
		set verify_level ""
	}

	if {$verify_level == "Verified" || $verify_level == "InteractionRequired"} {
		return [_parse_address $resp]
	} else {
		return [list]
	}
}



#
# desc    : Do qas singleline serach (for address completion).
# params  : address array
#         : field list to limit what array items get used.
# returns : see [list <<return item array>>]
#
proc qas::do_search_authenticate {addr_lst {field_list ""}} {
	# If field list is blank the include all array items.
	if {$field_list == ""} {
		array set TMP_ARR $addr_lst
		set field_list [array names TMP_ARR]
	}

	set req  [_build_authenticate_search $addr_lst]

	if {[catch { set resp [_send_req $req "DoSearch"] } msg]} {
		return [list OB_ERROR "$msg"]
	}

	return [list OB_OK [_parse_qaaddress $resp]]
}



#
# desc    : Refine search, picked from partial addresses return by initial search.
# params  : moniker - the id for qas to identify a point in the search process.
#           level   - only to be used when recursiing, other DON'T specify it!
# returns : see [_parse_picklist]
#
proc qas::do_refine {moniker {level 0}} {
	set req  [_build_refine $moniker]
	set resp [_send_req $req "DoRefine"]

	# Get results array from picklist.
	return [_parse_picklist $resp [incr level]]
}



#
# desc    : Get the final formatted address.
# params  : moniker - the id for qas to identify a point in the search process.
#           layout  - layout of the request ie "strict postal", this decides
#                     the format the xml will come back in.
# returns : see [_parse_picklist]
#
proc qas::do_get_address {moniker {layout "Strict Postal"}} {
	set req  [_build_get_address $moniker $layout]
	set resp [_send_req $req "DoGetAddress"]

	# Get results array from picklist.
	return  [_parse_address $resp]
}



#
# desc    : Send request to qas.
# params  :-
#     request : XML string.
#     action  : Name of the request.
# returns : XML response string.
#
# Pack up and send the reuest.
proc qas::_send_req {request action} {

	variable AUTH_PRO_HTTP_TOKEN
	variable AUTH_PRO_DATA

	ob_log::write INFO {QAS soap request: $request}
	ob_log::write INFO {QAS soap action:  $action}

	set url [OT_CfgGet QAS_SERVER_URL]

	# Figure out the connection settings for this API.
	if {[catch {
		foreach {api_scheme api_host api_port junk junk junk} \
		  [ob_socket::split_url $url] {break}
	} msg]} {
		# Cannot decode the URL.
		ob_log::write ERROR {qas::_send_req: Bad API URL, $msg}
		error "OVS_AUTH_PRO: Error splitting url"
	}

	# Construct the raw HTTP request.
	if {[catch {
		set req [ob_socket::format_http_req \
		           -host       $api_host \
		           -method     "POST" \
		           -post_data  $request \
		           -headers    [list \
		                         "Content-Type" "text/xml" \
		                         "charset"      "UTF-8" \
		                         "SOAPAction"   "\"http://www.qas.com/web-2005-10/$action\""] \
		           $url]
	} msg]} {
		ob_log::write ERROR {qas::_send_req: Bad request, $msg}
		error "OVS_AUTH_PRO: Error formatting verification request"
	}

	# Cater for the unlikely case that we're not using HTTPS.
	if {$api_scheme == "http"} {
		set tls -1
	} else {
		set tls {}
	}

	# Send the request to the QAS url.
	# XXX We're potentially doubling the timeout by using it as both
	# the connection and request timeout.
	if {[catch {
		foreach {req_id status complete} \
		  [::ob_socket::send_req \
		    -tls          $tls \
		    -is_http      1 \
		    -conn_timeout [OT_CfgGet QAS_SERVER_TIMEOUT 10000] \
		    -req_timeout  [OT_CfgGet QAS_SERVER_TIMEOUT 10000] \
		    $req \
		    $api_host \
		    $api_port] {break}
	} msg]} {
		# We can't be sure if anything reached the server or not.
		ob_log::write ERROR {qas::_send_req: send_req failed: $msg}
		error "OVS_AUTH_PRO: Error sending verification request"
	}

	if {$status != "OK"} {
		::ob_socket::clear_req $req_id
		error "OVS_AUTH_PRO: Error sending verification request: $status"
	} else {

		# Request successful - get and return the response data.
		set body [::ob_socket::req_info $req_id http_body]

		::ob_socket::clear_req $req_id
	}

	ob_log::write INFO {QAS soap response: $body}

	return $body
}



#------------------------------------------------------------------------------
# Parsing procs
#------------------------------------------------------------------------------

#
# desc    : Parse an xmldoc with a picklist.
# params  : XML string.
# returns : returns one of the following:-
#    [list FULL_ADDRESS [list $moniker $partial_address]]
#    [list MULTIPLE
#       [list $moniker $partial_address]
#       [list $moniker $partial_address]
#    ]
#    [list TOO_MANY]
#    [list ERROR]
#
proc qas::_parse_picklist {xml {level 0}} {
	variable THRESHOLD

	set XML_DOM {}
	set fn {QAS::_parse_picklist}

	ob_log::write INFO {${fn}: xml:$xml}

	# If this is hanging around for any reason, nuke it.
	catch {$XML_DOM delete}
	ob_log::write INFO "${fn}: unpacking XML"

	set XML_DOM [dom parse $xml]
	ob_log::write INFO "${fn}: parsed XML"

	set resp [$XML_DOM documentElement]
	ob_log::write INFO "${fn}: found root element"

	# Check for errors in the response
	set qas_fault_element [$resp getElementsByTagName qas:ErrorCode]
	
	# If this element is populated, then we have an error in QAS response
	if { $qas_fault_element != "" } {
		set qas_error_msg "Unknown Error"
		# Just in case the element is not present ...
		catch {
		  set qas_error_msg [[$resp getElementsByTagName qas:ErrorMessage] text]
		}
		ob_log::write ERROR \
		  "${fn}: QAS error response ([$qas_fault_element text]) $qas_error_msg"
		return [list ERROR]
	}

	# The number of picklist items returned.
	set total [[$resp getElementsByTagName qas:Total] text]

	# The threshold at which we say there are too many results and search
	# criteria is too vague.
	set over_threshold  {}
	set Picklist        [$resp getElementsByTagName qas:QAPicklist]

	catch { set over_threshold [$Picklist getAttribute OverThreshold]}
	if {$over_threshold == "true" && $total > $THRESHOLD} {
		return [list TOO_MANY]
	}

	# Get the picklist items.
	set PicklistEntries [$resp getElementsByTagName qas:PicklistEntry]

	set addresses {}
	foreach picklist $PicklistEntries {

		set full_address {}
		set can_step {}

		catch { set full_address [$picklist getAttribute FullAddress]}
		catch { set can_step [$picklist getAttribute CanStep]}

		if {$full_address == "true"} {
			# Get the moniker and address.
			set moniker         [[$picklist getElementsByTagName qas:Moniker] text]
			set partial_address [[$picklist getElementsByTagName qas:PartialAddress] text]

			# If we have one full address then this must be the final one! yay!

			if {$total == 1} {
				return [list FULL_ADDRESS [list $moniker $partial_address]]
			}

			lappend addresses [list $moniker $partial_address]

		} elseif {$can_step == "true"} {
			set moniker [[$picklist getElementsByTagName qas:Moniker] text]

			# If "CanStep" is true then there is a partial match found we need to do
			# refine the search to get a list of monikers and add each returned moniker to
			# the address list.
			foreach address [do_refine $moniker $level] {
				lappend addresses $address
			}
		} else {
			# Dodgey response!!
			ob_log::write ERROR "${fn}: Garbled Picklist Entry, problem with the following node."
			ob_log::write ERROR {[$picklist asXML]}
		}
	}

	# if we've hit the top of the stack then add address type 'label' => MULTIPLE.
	if {$level} {
		return $addresses
	} else {
		return [list MULTIPLE $addresses]
	}
}



#
# desc    : Parse the get_address response
# params  : XML string
# returns : Array of address lines
#
proc qas::_parse_address {xml} {
	set fn {QAS::_parse_address}

	variable XML_DOM

	# if this is hanging around for any reason, smite it
	catch {$XML_DOM delete}

	# Parse XML into dom tree.
	ob_log::write INFO {unpacking XML}
	set XML_DOM [dom parse $xml]
	ob_log::write INFO {parsed XML}

	# Get root element.
	set resp [$XML_DOM documentElement]
	ob_log::write INFO {${fn} - found root element}

	# Get all the address elements
	set addr_parts [$resp getElementsByTagName qas:AddressLine]

	array set ADDR [list]
	set addr_ln_no 0
	foreach item $addr_parts {
		set qas_label [[$item getElementsByTagName qas:Label] text]
		set qas_line  [[$item getElementsByTagName qas:Line] text]
		ob_log::write INFO "${fn}: Address Item:$qas_label, Address Value:$qas_line"

		set ADDR($addr_ln_no) $qas_line
		incr addr_ln_no
	}

	# Return address.
	return [array get ADDR]
}



#
# desc    : Parse a qaaddress response.
# params  : xml string.
# returns : <<ARRAY>> (name, value pairs).
#
# <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
#    <soap:Body>
#       <qas:QASearchResult VerifyLevel="None" xmlns:qas="http://www.qas.com/web-2005-10">
#          <qas:QAAddress>
#             <qas:AddressLine LineContent="None">
#                <qas:Label/>
#                <qas:Line>2</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Street (Current)</qas:Label>
#                <qas:Line>Petersfield Road</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Town (Current)</qas:Label>
#                <qas:Line/>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate District (Current)</qas:Label>
#                <qas:Line/>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate County (Current)</qas:Label>
#                <qas:Line/>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Postcode (Current)</qas:Label>
#                <qas:Line>W3 8NY</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label/>
#                <qas:Line>PAUL, OLIVER</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Decision text</qas:Label>
#                <qas:Line>Applicant is OK to bet - Money laundering minimal Risk</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Decision</qas:Label>
#                <qas:Line>AU01</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Authentication index explanation</qas:Label>
#                <qas:Line>A medium to high level of authentication has been found for the identity supplied. Depending on your exposure you may wish to seek further proofs of identity before dealing with this customer.</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate Authentication index</qas:Label>
#                <qas:Line>70</qas:Line>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate HR Policy rule</qas:Label>
#                <qas:Line/>
#             </qas:AddressLine>
#             <qas:AddressLine LineContent="None">
#                <qas:Label>Authenticate HR policy rule text</qas:Label>
#                <qas:Line/>
#             </qas:AddressLine>
#          </qas:QAAddress>
#       </qas:QASearchResult>
#    </soap:Body>
# </soap:Envelope>
#
proc qas::_parse_qaaddress {xml} {
	variable XML_DOM
	set fn {QAS::_parse_qaaddress}

	ob_log::write INFO "${fn}: xml:$xml"

	# If this is hanging around for any reason, nuke it.
	catch {$XML_DOM delete}
	ob_log::write INFO "${fn}: unpacking XML"

	set XML_DOM [dom parse $xml]
	ob_log::write INFO "${fn}: parsed XML"

	set resp [$XML_DOM documentElement]
	ob_log::write INFO "${fn}: found root element"

	# Get parts.
	set total [$resp getElementsByTagName qas:QASearchResult]
	set total [$resp getElementsByTagName qas:QAAddress]

	set AddressLines [$resp getElementsByTagName qas:AddressLine]

	foreach addr_line $AddressLines {
		# Get the name value pairs.
		set name  [[$addr_line getElementsByTagName qas:Label] text]
		set name [string tolower $name]

		# Remove all the stuff we don't want from the name
		regsub -all {\(.*\)} $name {} name
		regsub -all {^[ \t]+|[ \t]+$} $name {} name
		regsub -all { } $name {_} name
		regsub -all {authenticate_} $name {} name

		set value [[$addr_line getElementsByTagName qas:Line] text]

		# Get the lines and values.
		if {[string length $name]} {
			set QA_ADDRESS($name) $value
		} else {
			ob_log::write ERROR {qas::_parse_qaaddress: name has no value.}
		}
	}

	# Return the final address.
	return [array get QA_ADDRESS]
}

# Init QAS on package sourcing, if not already done
qas::init

