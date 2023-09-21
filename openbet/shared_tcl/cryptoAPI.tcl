#
# $Header: /cvsroot-openbet/training/openbet/shared_tcl/cryptoAPI.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

# Handle http requests
package provide cryptoAPI 1.0
package require net_socket
package require tls
package require tdom
package require http
package require util_gc

# Available requests
#    encrypt        - Encrypt data
#    decrypt        - Decrypt data
#    reEncrypt      - Re-encrypt data on the latest key
#    dataKeys       - retrieve all key versions on the keyring
#    dataKeyLatest  - retrieve the latest key version
#    dataKeyCreate  - create a new key
#    dataKeyExpire  - expire a key

namespace eval ::cryptoAPI {
	variable CFG
	variable REQUEST
	variable RESPONSE
	variable SOCKET
	variable DECRYPT
	variable USER_AUTH

	set CFG(crypto,sslEnabled) [OT_CfgGet CRYPTO_SSL_ENABLED    1]
	set CFG(crypto,sslServers) [OT_CfgGet CRYPTO_SSL_SERVERS    {}]
	set CFG(crypto,sslPorts)   [OT_CfgGet CRYPTO_SSL_PORTS      1]
	set CFG(crypto,sslRetry)   [OT_CfgGet CRYPTO_SSL_RETRY      5]
	set CFG(http,timeout)      [OT_CfgGet CRYPTO_TIMEOUT        10000]
	set CFG(cacheDecReq)       [OT_CfgGet CRYPTO_CACHE_DECRYPT  0]
	set CFG(conn,timeout)      [OT_CfgGet SOCKET.CONN_TIMEOUT   2000]
	set CFG(send,timeout)      [OT_CfgGet SOCKET.SEND_TIMEOUT   2000]
	set CFG(appName)           [OT_CfgGet APP_TAG               {unknown}]

	set CFG(initialised)       0

	set USER_AUTH {}

	set REQUEST(contentType)   "text/xml"
	set REQUEST(userAgent)     {cryptoAPI}
	set REQUEST(timeout)       10000
	set REQUEST(postData)      {}
	set REQUEST(headers)       {}
}

# Wrapper for OT_LogWrite adds in namespace context
proc ::cryptoAPI::log {level msg} {

	set prefix {}
	if {[uplevel [list info level]] > 0} {
		set fullName [uplevel [list namespace which -command [lindex [info level -1] 0]]]
		set prefix   "[string trimleft $fullName {::}]: "
	}

	uplevel OT_LogWrite [list $level "${prefix}${msg}"]
}

# Initialise the API
proc ::cryptoAPI::init {} {

	variable CFG
	variable REQUEST

	# Generate a SSL ID
	set CFG(sslId)         [genSSLId]

	set REQUEST(userAgent) {cryptoAPI}
	set REQUEST(timeout)   $CFG(http,timeout)
	set REQUEST(key)       {}

	incr CFG(initialised)

	return [list OK]
}

# Generate a random hex id for the SSL key
proc ::cryptoAPI::genSSLId {} {

	variable CFG

	set id [format "%02X" [asGetId]]
	for {set i 0} {$i < 4} {incr i} {
		append id [format "%02X" [expr int(rand()*256)]]
	}

	return $id
}

# Connect to the Crypto server via a secure socket and
# request a secure key to encyrpt all data over HTTP
proc ::cryptoAPI::newKey {} {

	variable CFG
	variable SOCKET
	variable REQUEST

	# If there is a valid key we can return
	set ret [validateKey]
	if {[lindex $ret 0] == {OK}} {
		return $ret
	}

	set ret [list socket.cluster "Unable to connect to cluster"]

	set portRange [list]
	for {set i 0} {$i < $CFG(crypto,sslPorts)} {incr i} {
		lappend portRange $i
	}

	log INFO "Requesting SSL Encryption Key"

	# Build a new transport request
	createTransport

	# Add the key request
	addKeyRequest

	# Serialise the data to be sent down the socket
	set reqData  [serialise]
	set attempts 0

	# Loop through the number of available ports per server
	foreach offset [randomiseList $portRange] {
		foreach server [randomiseList $CFG(crypto,sslServers)] {

			set host [lindex $server 0]
			set port [expr {[lindex $server 1] + $offset}]
			set url  [lindex $server 2]
			set ret  [socketSend $host $port $reqData]
			if {[lindex $ret 0] == {OK}} {
				# Configure the http url based on the connected socket
				set CFG(crypto,httpURL) $url
				break
			}

			# Only try server combinations a fixed number of times before aborting
			incr attempts
			if {$attempts >= $CFG(crypto,sslRetry)} {
				log ERROR "ABORT Connection ($attempts attempts)"
				return $ret
			}

			log INFO "RETRY Connection ($attempts attempts)"
		}

		# If we have successfully connected we should break
		if {[lindex $ret 0] == {OK}} {break}
	}

	set response [lindex $ret 1]

	# Parse the request
	set ret [parse $response]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR [lindex $ret 1]"
		return $ret
	}

	set root         [lindex $ret 1]
	set reqNode      [$root selectNode "/cryptoTransport/response"]
	set REQUEST(key) [$reqNode getAttribute "key" {}]

	# Check that the key returned is valid
	set ret [validateKey]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR: [lindex $ret 1]"
		return $ret
	}

	log INFO "New Key Generated"

	return [list OK]
}

# Check that the key is valid
proc ::cryptoAPI::validateKey {} {

	variable REQUEST

	if {$REQUEST(key) == {}} {
		log ERROR "Missing Key"
		return [list sslKey.missing "Missing Key"]
	}

	set expiry [string range $REQUEST(key) 32 end]

	# Check that the expiry is a valid integer
	if {![string is integer $expiry]} {
		log ERROR "Key Expiry NOT integer"
		return [list sslKey.corrupt "Key Expiry NOT integer"]
	}

	log INFO "Key Expiry [clock format $expiry]"

	if {$expiry <= [clock seconds]} {
		log ERROR "Key Expired"
		return [list sslKey.expired "Key Expired [clock format $expiry]"]
	}

	return [list OK]
}

# Make a non-blocking request to the crypto server
proc ::cryptoAPI::socketSend {host port reqData} {

	variable CFG
	variable SOCKET

	if {[catch {
		foreach {reqId status complete} [::ob_socket::send_req \
			-tls          {} \
			-is_http      0 \
			-conn_timeout $CFG(conn,timeout) \
			-req_timeout  $CFG(conn,timeout) \
			$reqData \
			$host \
			$port] {break}
	} err]} {
		log ERROR $err
		return [list socket.error $err]
	}

	# Retrieve the response
	set response [::ob_socket::req_info $reqId response]

	# Clear up the socket
	::ob_socket::clear_req $reqId

	switch -- $status {
		OK             {return [list OK             $response]}
		CONN_TIMEOUT   {return [list socket.timeout $status]}
		CONN_FAIL      {return [list socket.open    $status]}
		HANDSHAKE_FAIL {return [list socket.ssl     $status]}
		SEND_FAIL      {return [list socket.send    $status]}
		default {
			return [list socket.error $status]
		}
	}
}

# Initialise a request.
# Ensure we have a valid key and build the transport request
proc ::cryptoAPI::initRequest {} {

	variable CFG
	variable REQUEST
	variable RESPONSE

	if {!$CFG(initialised)} {
		return [list api.initialise "API Not Initialised"]
	}

	log INFO "Initialising Request"

	# Get the encryption key
	set ret [newKey]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR [lindex $ret 1]"
		return $ret
	}

	array set RESPONSE [array unset RESPONSE]

	# Build a new transport request
	createTransport

	return [list OK]
}

# Create a Transport request
proc ::cryptoAPI::createTransport {} {

	variable CFG
	variable REQUEST
	variable USER_AUTH

	set REQUEST(transport,root) [[dom createDocument "cryptoTransport"] documentElement]

	$REQUEST(transport,root) setAttribute date    [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	if {$USER_AUTH == {}} {
		$REQUEST(transport,root) setAttribute appName $CFG(appName)
	} else {
		$REQUEST(transport,root) setAttribute appName $CFG(appName):$USER_AUTH
	}
	$REQUEST(transport,root) setAttribute boxName [info hostname]
	$REQUEST(transport,root) setAttribute sslId   $CFG(sslId)

	return
}

# Build a Crypto Data request
proc ::cryptoAPI::createDataRequest args {

	set request [lindex $args 0]

	set doc     [dom createDocument "cryptoRequest"]
	set root    [$doc documentElement]
	set reqNode [addElement $root "request"]

	$root    setAttribute date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
	$reqNode setAttribute name $request

	# Setup the parameters based on the flags passed in
	foreach {flag value} [lrange $args 1 end] {
		if {[regexp {^-(.+)$} $flag all flag]} {
			set ARG($flag) $value
		}
	}

	# Depending on the request add attributes to the request
	switch -- $request {
		encrypt        {
			# Create a request to encrypt data
			$reqNode setAttribute "data" $ARG(data)
		}
		decrypt -
		reEncrypt {
			$reqNode setAttribute "data"       $ARG(data)
			$reqNode setAttribute "ivec"       $ARG(ivec)
			$reqNode setAttribute "keyVersion" $ARG(keyVersion)
		}
		dataKeys {
			# Create a request for all key versions on the key ring
		}
		dataKeyLatest {
			# Create a request for the current version data key
		}
		dataKeyCreate  {
			# Create a request to create a new data key
		}
		dataKeyExpire  {
			# Create a request to expire a data key
			$reqNode setAttribute "keyVersion" $ARG(keyVersion)
		}
	}

	return $root
}

# Add a key request to the transport request
proc ::cryptoAPI::addKeyRequest {} {

	variable REQUEST

	set reqNode [addElement $REQUEST(transport,root) "request"]

	$reqNode setAttribute requestId 0
	$reqNode setAttribute type      "key"

	return [list OK]
}

# Encrypt a request and add it to the transport request
proc ::cryptoAPI::addDataRequest {requestId request} {

	variable REQUEST
	variable CFG

	# Encrypt the request
	set ret [encryptRequest $request]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR [lindex $ret 1]"
		return $ret
	}

	set encRequest [lindex $ret 1]

	set reqNode [addElement $REQUEST(transport,root) "request" $encRequest]

	$reqNode setAttribute requestId  $requestId
	$reqNode setAttribute type       "data"

	return [list OK]
}

# Handle a request when in Server mode
proc ::cryptoAPI::makeRequest {} {

	variable REQUEST
	variable CFG

	# Configure the OXi::HTTP package
	set REQUEST(postData) [serialise]
	set REQUEST(ssl)      0

	log INFO "Initiating Request $CFG(crypto,httpURL)"

	# Send the request to the Crypto server encrypted
	# and return the xml response to the calling application
	set ret [sendDataRequest $CFG(crypto,httpURL)]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR [lindex $ret 1]"
		return $ret
	}

	set transportResponse [lindex $ret 1]

	# Parse the request
	set ret [parse $transportResponse]
	if {[lindex $ret 0] != {OK}} {
		log ERROR "ERROR [lindex $ret 1] $transportResponse"
		return $ret
	}

	set root       [lindex $ret 1]
	set doc        [$root ownerDocument]
	set requestIds [list]

	foreach transportNode [$root selectNode "/cryptoTransport/response"] {

		set requestId  [$transportNode getAttribute requestId]
		set statusCode [$transportNode getAttribute statusCode]
		set statusType [$transportNode getAttribute statusType]
		set statusDesc [$transportNode getAttribute statusDesc]

		lappend requestIds $requestId

		# Check the status of the transport response
		if {$statusCode != {001}} {
			log ERROR "ERROR Transport Failure: $statusCode $statusType $statusDesc"

			# if its caused by a missing key, remove the key so that we get a
			# new one next time (otherwise we can get stuck with an invalid
			# key just because crypto has restarted)
			if {$statusCode == 403} {
				log ERROR "ERROR Key missing. Removing old key"
				set REQUEST(key) {}
			}

			return [list $statusType $statusCode $statusDesc]
		}

		# Decrypt the response from the Crypto server
		set ret [decryptResponse [$transportNode text]]
		if {[lindex $ret 0] != {OK}} {
			log ERROR "ERROR [lindex $ret 1]"
			return $ret
		}

		set binResponse [lindex $ret 1]

		# Parse the Crypto request
		set ret [parse $binResponse]
		if {[lindex $ret 0] != {OK}} {
			log ERROR "ERROR [lindex $ret 1]"
			return $ret
		}

		set requestRoot [lindex $ret 1]
		set requestDoc  [$requestRoot ownerDocument]
		set requestNode [$requestRoot selectNode "/cryptoRequest/response"]
		set statusCode  [$requestNode getAttribute statusCode]
		set statusType  [$requestNode getAttribute statusType]
		set statusDesc  [$requestNode getAttribute statusDesc]

		# Check the status of the Crypto response
		if {$statusCode != {001}} {
			log ERROR "ERROR: $statusCode $statusType $statusDesc"
			return [list $statusType $statusCode $statusDesc]
		}
		handleResponse $requestNode $requestId

		# Delete the dom structure
		catch {$requestDoc delete}
	}

	# Delete the dom structure
	catch {$doc delete}

	log INFO "Successfully Handled Request ([llength $requestIds] Batched Request(s))"
	return [list OK $requestIds]
}

# Do we already have the decrypted value available from earlier in the request
proc ::cryptoAPI::decryptGet {data ivec keyVersion} {

	variable CFG
	variable DECRYPT

	if {[info exists DECRYPT($data,$ivec,$keyVersion)]} {
		return [list 1 $DECRYPT($data,$ivec,$keyVersion)]
	} else {
		return [list 0 {}]
	}

}

# Do we already have the decrypted value available from earlier in the request
proc ::cryptoAPI::decryptSet {data ivec keyVersion decrypt} {

	variable CFG
	variable DECRYPT

	if {!$CFG(cacheDecReq)} {
		return
	}

	# make sure we tidy up at end
	ob_gc::add ::cryptoAPI::decryptSet

	set DECRYPT($data,$ivec,$keyVersion) $decrypt

}

# Encrypt a request to send to the Crypto server
proc ::cryptoAPI::encryptRequest {request} {

	variable REQUEST

	set request [$request asXML]

	# Encrypt the request
	if {[catch {set encRequest [blowfish encrypt -hex $REQUEST(key) -bin $request]} err]} {
		log ERROR "ERROR $err"
		return [list transport.encrypt $err]
	}

	return [list OK $encRequest]
}

# Decrypt the response from the Crypto server
proc ::cryptoAPI::decryptResponse {encResponse} {

	variable REQUEST

	# Decrypt the response
	if {[catch {
		set hexResponse [blowfish decrypt -hex $REQUEST(key) -hex $encResponse]
		set binResponse [hextobin $hexResponse]
	} err]} {
		log ERROR "ERROR $err"
		return [list transport.decrypt $err]
	}

	return [list OK $binResponse]
}

# Handle a Crypto response and populate the response array
proc ::cryptoAPI::handleResponse {node id} {

	variable RESPONSE

	set RESPONSE($id,name) [$node getAttribute name]

	switch -- $RESPONSE($id,name) {
		encrypt -
		reEncrypt {
			set RESPONSE($id,data)       [$node getAttribute data]
			set RESPONSE($id,ivec)       [$node getAttribute ivec]
			set RESPONSE($id,keyVersion) [$node getAttribute keyVersion]
		}
		decrypt {
			set RESPONSE($id,data)       [$node getAttribute data]
		}
		dataKeys {
			set RESPONSE($id,keyVersions) [list]
			foreach keyNode [$node selectNodes "keys/key"] {
				lappend RESPONSE($id,keyVersions) [$keyNode getAttribute version {}]
			}
		}
		dataKeyLatest -
		dataKeyCreate  {
			set RESPONSE($id,keyVersion) [$node getAttribute keyVersion]
		}
		dataKeyExpire  {}
	}

	return
}

# Given the request name and id, return a list of data values
proc ::cryptoAPI::getResponseData {id object} {

	variable RESPONSE

	if {![info exists RESPONSE($id,$object)]} {
		return {}
	}

	return $RESPONSE($id,$object)
}

# Create a element with text node
proc ::cryptoAPI::addElement {root name {value {}}} {

	set doc  [$root ownerDocument]
	set elem [$doc createElement $name]

	if {$value != {}} {
		set tn [$doc createTextNode $value]
		$elem appendChild $tn
	}

	$root appendChild $elem
	return $elem
}

# Serialise a message for sending via secure socket
proc ::cryptoAPI::serialise {} {

	variable REQUEST

	set xml  [$REQUEST(transport,root) asXML]
	regsub -line -all {^\s+} $xml {} xml
	regsub       -all {\n}   $xml "" xml

	# The server is line buffering so we should re-add the newline
	append xml \n

	# Delete the dom structure
	catch {$REQUEST(transport,root) delete}

	return $xml
}

# Simply parse an xml message
proc ::cryptoAPI::parse {xml} {

	if {[catch {set doc [dom parse -simple $xml]} err]} {
		catch {$doc delete}
		return [list transport.parse $err]
	}

	return [list OK [$doc documentElement]]
}

# Send Encrypted data to the Crypto server
proc ::cryptoAPI::sendDataRequest {url} {

	variable REQUEST
	variable RESPONSE

	::http::config \
		-useragent $REQUEST(userAgent)

	set startTime [OT_MicroTime -micro]

	if {[catch {
		set token [http::geturl \
			$url \
			-query   $REQUEST(postData) \
			-type    $REQUEST(contentType) \
			-timeout $REQUEST(timeout) \
			-headers $REQUEST(headers)]
	} err]} {
		# Cleanup the http state information
		catch {http::cleanup $token}
		return [list http.error $err]
	}

	upvar #0 $token state

	set code   [lindex $state(http) 1]
	set body   $state(body)
	set status $state(status)

	# Cleanup the http state information
	http::cleanup $token

	# Log the request time
	set totalTime [format "%.2f" [expr {[OT_MicroTime -micro] - $startTime}]]

	log INFO "TIME $totalTime sec (http $code)"

	if {$status == {timeout}} {
		return [list http.timeout "Timeout $REQUEST(timeout) $url"]
	}

	# Handle failed request
	if {$code != 200} {
		return [list http.code $code]
	}

	return [list OK $body]
}

# Randomise a list of sub-lists
proc ::cryptoAPI::randomiseList {list} {
    set n     1
    set slist {}
    foreach item $list {
        set index [expr {int(rand()*$n)}]
        set slist [linsert $slist $index $item]
        incr n
    }
    return $slist
 }

proc ::cryptoAPI::setAdminUser {username} {
	variable USER_AUTH
	set USER_AUTH $username
}

