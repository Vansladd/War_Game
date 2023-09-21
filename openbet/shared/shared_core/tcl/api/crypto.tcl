#
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

# Handle http requests
set pkg_version 1.0
package provide core::api::crypto $pkg_version

package require core::socket        1.0
package require core::log           1.0
package require core::control       1.0
package require core::util          1.0
package require core::check         1.0
package require core::args          1.0
package require core::gc            1.0
package require core::xml           1.0
package require core::security::aes 1.0
package require tls
package require tdom
package require http

core::args::register_ns \
	-namespace core::api::crypto \
	-version   $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::socket \
		core::xml \
		core::util] \
	-docs xml/api/crypto.xml

# Available requests
#    encrypt        - Encrypt data
#    decrypt        - Decrypt data
#    reEncrypt      - Re-encrypt data on the latest key
#    dataKeys       - retrieve all key versions on the keyring
#    dataKeyLatest  - retrieve the latest key version
#    dataKeyCreate  - create a new key
#    dataKeyExpire  - expire a key

namespace eval ::core::api::crypto {
	variable CFG
	variable REQUEST
	variable RESPONSE
	variable ERRCODE
	variable SOCKET
	variable DECRYPT
	
	set CFG(initialised) 0
}

# Initialise the API
core::args::register \
	-proc_name core::api::crypto::init \
	-args [list \
		[list -arg -available            -mand 0 -check BOOL  -default_cfg CRYPTO_AVAILABLE       -default 1       -desc {Is crypto available}] \
		[list -arg -ssl_enabled          -mand 0 -check BOOL  -default_cfg CRYPTO_SSL_ENABLED     -default 1       -desc {Enable SSL}] \
		[list -arg -ssl_servers          -mand 0 -check ASCII -default_cfg CRYPTO_SSL_SERVERS     -default {}      -desc {List of server in the form host:port}] \
		[list -arg -ssl_ports            -mand 0 -check UINT  -default_cfg CRYPTO_SSL_PORTS       -default 1       -desc {Number of SSL ports to open}] \
		[list -arg -ssl_retry            -mand 0 -check UINT  -default_cfg CRYPTO_SSL_RETRY       -default 5       -desc {Number of times to retry the connection before aborting}] \
		[list -arg -enc_type             -mand 0 -check ASCII -default_cfg CRYPTO_ENCRYPTION_TYPE -default BF128   -desc {Encryption type}] \
		[list -arg -aes_pad              -mand 0 -check BOOL  -default_cfg CRYPTO_PAD_AES_IN_TCL  -default 0       -desc {Add padding to aes encrypted data}] \
		[list -arg -http_timeout         -mand 0 -check UINT  -default_cfg CRYPTO_TIMEOUT         -default 10000   -desc {Timeout for HTTP communication}] \
		[list -arg -cache_decrypted_data -mand 0 -check BOOL  -default_cfg CRYPTO_CACHE_DECRYPT   -default 0       -desc {Cache the decrypted data}] \
		[list -arg -socket_conn_timeout  -mand 0 -check BOOL  -default_cfg SOCKET.CONN_TIMEOUT    -default 2000    -desc {Socket connection timeout}] \
		[list -arg -socket_send_timeout  -mand 0 -check BOOL  -default_cfg SOCKET.SEND_TIMEOUT    -default 2000    -desc {Socket send timeout}] \
		[list -arg -app_tag              -mand 0 -check ASCII -default_cfg APP_TAG                -default unknown -desc {Client application name (tAppCode.app_tag)}] \
	] \
	-body {
		variable CFG
		variable REQUEST
		variable RESPONSE
		variable ERRCODE
		variable SOCKET
		variable DECRYPT
	
		set CFG(available)            $ARGS(-available)
		set CFG(ssl_enabled)          $ARGS(-ssl_enabled)
		set CFG(ssl_servers)          $ARGS(-ssl_servers)
		set CFG(ssl_ports)            $ARGS(-ssl_ports)
		set CFG(ssl_retry)            $ARGS(-ssl_retry)
		set CFG(enc_type)             $ARGS(-enc_type)
		set CFG(aes_pad)              $ARGS(-aes_pad)
		set CFG(http_timeout)         $ARGS(-http_timeout)
		set CFG(conn_timeout)         $ARGS(-socket_conn_timeout)
		set CFG(send_timeout)         $ARGS(-socket_send_timeout)
		set CFG(cache_decrypted_data) $ARGS(-cache_decrypted_data)
		set CFG(app_tag)              $ARGS(-app_tag)
		
		set REQUEST(ssl_id)       [gen_ssl_id]
		set REQUEST(content_Type) "text/xml"
		set REQUEST(user_agent)   {cryptoAPI}
		set REQUEST(timeout)      $CFG(http_timeout)
		set REQUEST(post_data)    {}
		set REQUEST(headers)      {}
		set REQUEST(key)          {}
		set REQUEST(key)          {}
		set REQUEST(adminuser)    {}
		
		core::xml::init
		
		# lookup for error codes for potential errors that, because the transport
		# failed, do not result in a code being returned by the crypto server
		array set ERRCODE {
			unknown           100
			http.error        110
			http.timeout      111
			http.code         112
			transport.parse   120
			transport.decrypt 122
		}
		
		# Use core::control if it has been initialised
		if {[core::control::is_initialised]} {
			set CFG(conn_timeout)  [core::control::get -name HTTP_CON_TIMEOUT_CRYPTO_SERVER]
			set CFG(send_timeout)  [core::control::get -name HTTP_REQ_TIMEOUT_CRYPTO_SERVER]
		}
		
		core::security::aes::init \
			-pad_data 1
		
		incr CFG(initialised)
		
		return [list OK]
	}
	
# Set a request configuration value
core::args::register \
	-proc_name core::api::crypto::set_request_cfg \
	-args [list \
		[list -arg -name  -mand 1 -check ASCII -desc {Request config name}] \
		[list -arg -value -mand 1 -check ANY   -desc {Request config value}] \
	] \
	-body {
		variable REQUEST
		
		set name  $ARGS(-name)
		set value $ARGS(-value)
		
		if {![info exists REQUEST($name)]} {
			error "Unknown request configuration item $name"
		}
	
		set REQUEST($name) $value
	}
	

# Generate a random hex id for the SSL key
#
# TODO use core::random
core::args::register \
	-proc_name core::api::crypto::gen_ssl_id \
	-body {
		set id [format "%02X" [asGetId]]
		for {set i 0} {$i < 4} {incr i} {
			append id [format "%02X" [expr int(rand()*256)]]
		}

		return $id
	}
	
# Map and error code to a number
core::args::register \
	-proc_name core::api::crypto::map_error \
	-args [list \
		[list -arg -code  -mand 1 -check ASCII -desc {Error Code}] \
	] \
	-body {
		variable ERRCODE
		
		set code $ARGS(-code)
		
		if {[info exist ERRCODE($code)]} {
			return $ERRCODE($code)
		} else {
			return $ERRCODE(unknown)
		}
	}
	
# Connect to the Crypto server via a secure socket and
# request a secure key to encrypt all data over HTTP
core::args::register \
	-proc_name core::api::crypto::new_key \
	-body {
		variable CFG
		variable SOCKET
		variable REQUEST

		# If there is a valid key we can return
		set ret [validate_key]
		if {[lindex $ret 0] == {OK}} {
			return $ret
		}

		set ret [list socket.cluster "Unable to connect to cluster"]

		set port_range [list]
		for {set i 0} {$i < $CFG(ssl_ports)} {incr i} {
			lappend port_range $i
		}

		core::log::write INFO {Requesting SSL Encryption Key}

		# Build a new transport request
		create_transport

		# Add the key request
		add_key_request

		set attempts 0

		# Loop through the number of available ports per server
		foreach offset [core::util::lrandomise -list $port_range] {
			foreach server [core::util::lrandomise -list $CFG(ssl_servers)] {
			
				set host [lindex $server 0]
				set port [expr {[lindex $server 1] + $offset}]
				set url  [lindex $server 2]
				
				# Serialise the data to be sent down the socket
				set ret  [_socket_send \
					-host     $host \
					-port     $port \
					-req_data [core::xml::serialise -node $REQUEST(transport,root)]]

				if {[lindex $ret 0] == {OK}} {
					# Configure the http url based on the connected socket
					set CFG(crypto,httpURL) $url
					break
				}

				# Only try server combinations a fixed number of times before aborting
				incr attempts
				if {$attempts >= $CFG(ssl_retry)} {
					core::log::write ERROR {ABORT Connection ($attempts attempts)}
					return $ret
				}

				core::log::write INFO {RETRY Connection ($attempts attempts)}
			}

			# If we have successfully connected we should break
			if {[lindex $ret 0] == {OK}} {break}
		}

		set response [lindex $ret 1]
		
		# Parse the request
		set ret [core::xml::parse -strict 0 -xml $response]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {ERROR [lindex $ret 1]}
			return $ret
		}

		set doc          [lindex $ret 1]
		set root         [$doc documentElement]
		set node         [$root selectNode "/cryptoTransport/response"]
		set REQUEST(key) [$node getAttribute "key" {}]

		# Check that the key returned is valid
		set ret [validate_key]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {ERROR: [lindex $ret 1]}
			return $ret
		}
		
		# TODO Destroy DOM Object??

		core::log::write INFO {New Key Generated}

		return [list OK]
	}
	
# If a decrypt / encrypt request fails due to connectivity then also drop the key so that we
# don't keep on trying the same server over and over again. Essentially forces a re-negotiation
# of the SSL key. 
core::args::register \
	-proc_name core::api::crypto::drop_key \
	-body {
		variable REQUEST

		set REQUEST(key) {}

		core::log::write INFO {Dropping SSL Encryption Key}
	}
	
# Check that the key is valid
core::args::register \
	-proc_name core::api::crypto::validate_key \
	-body {
		variable CFG
		variable REQUEST

		if {$REQUEST(key) == {}} {
			core::log::write ERROR {Missing Key}
			return [list sslKey.missing "Missing Key"]
		}

		switch -- $CFG(enc_type) {
			AES256 {
				set expiry [string range $REQUEST(key) 64 end]
			}
			BF128 -
			default  {
				set expiry [string range $REQUEST(key) 32 end]
			}
		}
		
		# Check that the expiry is a valid integer
		if {![string is integer -strict $expiry]} {
			core::log::write ERROR {Key Expiry NOT integer}
			return [list sslKey.corrupt "Key Expiry NOT integer"]
		}

		core::log::write INFO {Key Expiry [clock format $expiry]}

		if {$expiry <= [clock seconds]} {
			core::log::write ERROR {Key Expired}
			return [list sslKey.expired "Key Expired [clock format $expiry]"]
		}

		return [list OK]
	}

# Initialise a request.
# Ensure we have a valid key and build the transport request
core::args::register \
	-proc_name core::api::crypto::init_request \
	-body {
		variable CFG
		variable REQUEST
		variable RESPONSE

		# Return error if crypto server is unavailable
		if {!$CFG(available)} {
			core::log::write ERROR {Crypto server is unavailable}
			return [list 0 "Crypto server is unavailable"]
		}

		if {!$CFG(initialised)} {
			return [list api.initialise "API Not Initialised"]
		}

		core::log::write INFO {Initialising Request}

		# Get the encryption key
		set ret [new_key]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {ERROR [lindex $ret 1]}
			return $ret
		}

		array set RESPONSE [array unset RESPONSE]

		# Build a new transport request
		create_transport

		return [list OK]
	}
	

# Create a Transport request
core::args::register \
	-proc_name core::api::crypto::create_transport \
	-body {
		variable CFG
		variable REQUEST
		
		set root [[dom createDocument "cryptoTransport"] documentElement]

		set REQUEST(transport,root) $root

		$root setAttribute date \
			[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]

		if {$REQUEST(adminuser) == {}} {
			$root setAttribute appName $CFG(app_tag)
		} else {
			$root setAttribute appName $CFG(app_tag):$REQUEST(adminuser)
		}

		$root setAttribute boxName [info hostname]
		$root setAttribute sslId   $REQUEST(ssl_id)

		return
	}
	

# Build a Crypto Data request
core::args::register \
	-proc_name core::api::crypto::create_data_request \
	-args [list \
		[list -arg -request     -mand 1 -check ASCII             -desc {Name of request}] \
		[list -arg -data        -mand 0 -check ANY   -default {} -desc {Data}] \
		[list -arg -ivec        -mand 0 -check ANY   -default {} -desc {Initialisation vector}] \
		[list -arg -key_version -mand 0 -check UINT  -default {} -desc {Version of the key}] \
	] \
	-body {
		set doc     [dom createDocument cryptoRequest]
		set root    [$doc documentElement]
		set reqNode [core::xml::add_element -node $root -name request]
		
		set request $ARGS(-request)

		$root    setAttribute date [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
		$reqNode setAttribute name $request

		# Depending on the request add attributes to the request
		switch -- $request {
			encrypt        {
				# Create a request to encrypt data
				$reqNode setAttribute data $ARGS(-data)
			}
			decrypt -
			reEncrypt {
				$reqNode setAttribute data       $ARGS(-data)
				$reqNode setAttribute ivec       $ARGS(-ivec)
				$reqNode setAttribute keyVersion $ARGS(-key_version)
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
				$reqNode setAttribute keyVersion $ARGS(-key_version)
			}
		}

		return $root
	}
	

# Add a key request to the transport request
core::args::register \
	-proc_name core::api::crypto::add_key_request \
	-body {
		variable REQUEST

		set node [core::xml::add_element \
			-node $REQUEST(transport,root) \
			-name request]

		$node setAttribute requestId 0
		$node setAttribute type      key

		return [list OK]
	}

# Encrypt a request and add it to the transport request
core::args::register \
	-proc_name core::api::crypto::add_data_request \
	-args [list \
		[list -arg -request_id -mand 1 -check UINT  -desc {Numerical ID for the request}] \
		[list -arg -request    -mand 1 -check ANY   -desc {Body of request}] \
	] \
	-body {
		variable REQUEST
		variable CFG
		
		set request_id $ARGS(-request_id)
		set request    $ARGS(-request)

		# Encrypt the request
		set ret [encrypt_request -request $request]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {ERROR [lindex $ret 1]}
			return $ret
		}

		set enc_request [lindex $ret 1]

		set node [core::xml::add_element \
			-node  $REQUEST(transport,root) \
			-name  request \
			-value $enc_request]

		$node setAttribute requestId  $request_id
		$node setAttribute type       data

		return [list OK]
	}


# Handle a request when in Server mode
#
# @return
#   OK {request IDs}
# or
#   {error type} {error code} {error description}
#
core::args::register \
	-proc_name core::api::crypto::make_request \
	-body {
		variable REQUEST
		variable CFG
		variable ERRCODE

		set REQUEST(post_data) [core::xml::serialise -node $REQUEST(transport,root)]
		set REQUEST(ssl)      0

		core::log::write INFO {Initiating Request $CFG(crypto,httpURL)}

		# Send the request to the Crypto server encrypted
		# and return the xml response to the calling application
		set ret  [send_data_request -url $CFG(crypto,httpURL)]
		set code [lindex $ret 0]
		if {$code != {OK}} {
			core::log::write ERROR {ERROR [lindex $ret 1]}
			return [list \
				[lindex $ret 0] \
				[map_error -code [lindex $ret 0]] \
				[lindex $ret 1]]
		}

		set transport_response [lindex $ret 1]
		
		# Parse the request
		set ret [core::xml::parse -strict 0 -xml $transport_response]
		if {[lindex $ret 0] != {OK}} {
			core::log::write ERROR {ERROR [lindex $ret 1] $transport_response}
			return [list \
				[lindex $ret 0] \
				[map_error -code [lindex $ret 0]] \
				[lindex $ret 1]]
		}

		set doc         [lindex $ret 1]
		set root        [$doc documentElement]
		set request_ids [list]

		foreach transport_node [$root selectNode "/cryptoTransport/response"] {

			set request_id  [$transport_node getAttribute requestId]
			set status_code [$transport_node getAttribute statusCode]
			set status_type [$transport_node getAttribute statusType]
			set status_desc [$transport_node getAttribute statusDesc]

			lappend request_ids $request_id

			# Check the status of the transport response
			if {$status_code != {001}} {
				core::log::write ERROR {ERROR Transport Failure: $status_code $status_type $status_desc}

				# if its caused by a missing key, remove the key so that we get a
				# new one next time (otherwise we can get stuck with an invalid
				# key just because crypto has restarted)
				if {$status_code == 403} {
					core::log::write ERROR {ERROR Key missing. Removing old key}
					set REQUEST(key) {}
				}

				return [list $status_type $status_code $status_desc]
			}

			# Decrypt the response from the Crypto server
			set ret [decrypt_response -enc_response [$transport_node text]]
			if {[lindex $ret 0] != {OK}} {
				core::log::write ERROR {ERROR [lindex $ret 1]}
				core::xml::destroy -doc $doc
				
				return [list \
					[lindex $ret 0] \
					[map_error -code [lindex $ret 0]] \
					[lindex $ret 1]]
			}

			set bin_response [lindex $ret 1]

			# Parse the Crypto request
			set ret [core::xml::parse -strict 0 -xml $bin_response]
			if {[lindex $ret 0] != {OK}} {
				core::log::write ERROR {ERROR [lindex $ret 1]}
				core::xml::destroy -doc $doc

				return [list \
					[lindex $ret 0] \
					[map_error -code [lindex $ret 0]] \
					[lindex $ret 1]]
			}

			set request_doc   [lindex $ret 1]
			set request_root  [$request_doc documentElement]
			set request_node  [$request_root selectNode "/cryptoRequest/response"]
			set status_code   [$request_node getAttribute statusCode]
			set status_type   [$request_node getAttribute statusType]
			set status_desc   [$request_node getAttribute statusDesc]

			# Check the status of the Crypto response
			if {$status_code != {001}} {
				core::log::write ERROR {ERROR: $status_code $status_type $status_desc}
				return [list $status_type $status_code $status_desc]
			}
			
			handle_response \
				-node       $request_node \
				-request_id $request_id

			# Delete the dom structure
			core::xml::destroy -doc $request_doc
		}

		# Delete the dom structure
		core::xml::destroy -doc $doc

		core::log::write INFO {Successfully Handled Request ([llength $request_ids] Batched Request(s))}
		return [list OK $request_ids]
	}

# Do we already have the decrypted value available from earlier in the request
core::args::register \
	-proc_name core::api::crypto::decrypt_get \
	-args [list \
		[list -arg -enc_data    -mand 1 -check ANY -desc {Encrypted data}] \
		[list -arg -ivec        -mand 1 -check HEX -desc {Initialisation vector}] \
		[list -arg -key_version -mand 1 -check ANY -desc {Key version}] \
	] \
	-body {
		variable CFG
		variable DECRYPT
		
		if {!$CFG(cache_decrypted_data)} {
			return [list 0 {}]
		}
		
		set enc_data    $ARGS(-enc_data)
		set ivec        $ARGS(-ivec)
		set key_version $ARGS(-key_version)

		if {[info exists DECRYPT($enc_data,$ivec,$key_version)]} {
			return [list 1 $DECRYPT($enc_data,$ivec,$key_version)]
		} else {
			return [list 0 {}]
		}
	}

# Do we already have the decrypted value available from earlier in the request
core::args::register \
	-proc_name core::api::crypto::decrypt_set \
	-args [list \
		[list -arg -enc_data    -mand 1 -check ANY -desc {Encrypted data}] \
		[list -arg -raw_data    -mand 1 -check ANY -desc {Raw data}] \
		[list -arg -ivec        -mand 1 -check HEX -desc {Initialisation vector}] \
		[list -arg -key_version -mand 1 -check ANY -desc {Key version}] \
	] \
	-body {
		variable CFG
		variable DECRYPT

		if {!$CFG(cache_decrypted_data)} {
			return
		}
		
		set enc_data    $ARGS(-enc_data)
		set raw_data    $ARGS(-raw_data)
		set ivec        $ARGS(-ivec)
		set key_version $ARGS(-key_version)

		# make sure we tidy up at end
		core::gc::add core::api::crypto::decryptSet

		set DECRYPT($enc_data,$ivec,$key_version) $raw_data
	}

# Encrypt a request to send to the Crypto server
core::args::register \
	-proc_name core::api::crypto::encrypt_request \
	-args [list \
		[list -arg -request -mand 1 -check ANY -desc {Request to encrypt}] \
	] \
	-body {
		variable CFG
		variable REQUEST
		
		set request $ARGS(-request)
		
		# Encrypt the request
		if {[catch {
			switch -- $CFG(enc_type) {
				"AES256" {
					set enc_request \
						[core::security::aes::encrypt \
							-hex_key [string range $REQUEST(key) 0 63] \
							-content $request]
				}
				"BF128" -
				default  {
					set enc_request [blowfish encrypt -hex $REQUEST(key) -bin $request]
				}
			}
		} err]} {
			core::log::write ERROR {ERROR $err}
			return [list transport.encrypt $err]
		}

		return [list OK $enc_request]
	}

# Decrypt the response from the Crypto server
core::args::register \
	-proc_name core::api::crypto::decrypt_response \
	-args [list \
		[list -arg -enc_response -mand 1 -check ANY -desc {Encrypted response}] \
	] \
	-body {
		variable CFG
		variable REQUEST
		
		set enc_response $ARGS(-enc_response)

		# Decrypt the response
		if {[catch {
			switch -- $CFG(enc_type) {
				"AES256" {
					set response \
						[core::security::aes::decrypt \
							-hex_key [string range $REQUEST(key) 0 63] \
							-hex_data $enc_response]
				}
				"BF128" -
				default  {
					set hex_response [blowfish decrypt \
						-hex $REQUEST(key) \
						-hex $enc_response]
						
					set response [hextobin $hex_response]
				}
			}
		} err]} {
			core::log::write ERROR {ERROR $err}
			return [list transport.decrypt $err]
		}

		return [list OK $response]
	}

# Handle a Crypto response and populate the response array
core::args::register \
	-proc_name core::api::crypto::handle_response \
	-args [list \
		[list -arg -node        -mand 1 -check ASCII -desc {Response node}] \
		[list -arg -request_id  -mand 1 -check UINT  -desc {Request ID}] \
	] \
	-body {
		variable RESPONSE
		
		set node $ARGS(-node)
		set id   $ARGS(-request_id)

		set RESPONSE($id,name) [$node getAttribute name]

		switch -- $RESPONSE($id,name) {
			"encrypt" -
			"reEncrypt" {
				set RESPONSE($id,data)       [$node getAttribute data]
				set RESPONSE($id,ivec)       [$node getAttribute ivec]
				set RESPONSE($id,keyVersion) [$node getAttribute keyVersion]
			}
			"decrypt" {
				set RESPONSE($id,data)       [$node getAttribute data]
			}
			"dataKeys" {
				set RESPONSE($id,keyVersions) [list]
				foreach key_node [$node selectNodes "keys/key"] {
					lappend RESPONSE($id,keyVersions) [$key_node getAttribute version {}]
				}
			}
			"dataKeyLatest" -
			"dataKeyCreate"  {
				set RESPONSE($id,keyVersion) [$node getAttribute keyVersion]
			}
			"dataKeyExpire"  {}
		}

		return
	}

# Retrieve a response object given the name and request_id
core::args::register \
	-proc_name core::api::crypto::get_response_data \
	-args [list \
		[list -arg -request_id  -mand 1 -check UINT  -desc {Request Identifier}] \
		[list -arg -object      -mand 1 -check ASCII -desc {Object reference}] \
	] \
	-body {
		variable RESPONSE
		
		set id     $ARGS(-request_id)
		set object $ARGS(-object)

		if {![info exists RESPONSE($id,$object)]} {
			return {}
		}

		return $RESPONSE($id,$object)
	}

# Send Encrypted data to the Crypto server
core::args::register \
	-proc_name core::api::crypto::send_data_request \
	-args [list \
		[list -arg -url -mand 1 -check ASCII -desc {URL of the Crypto server to send the request to}] \
	] \
	-body {
		variable REQUEST
		variable RESPONSE
		
		set url $ARGS(-url)

		::http::config \
			-useragent $REQUEST(user_agent)

		set start_time [OT_MicroTime -micro]

		if {[catch {
			set token [http::geturl \
				$url \
				-query   $REQUEST(post_data) \
				-type    $REQUEST(content_Type) \
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

		# core::log::write the request time
		set total_time [format "%.2f" [expr {[OT_MicroTime -micro] - $start_time}]]

		core::log::write INFO {TIME $total_time sec (http $code)}

		if {$status == {timeout}} {
			return [list http.timeout "Timeout $REQUEST(timeout) $url"]
		}

		# Handle failed request
		if {$code != 200} {
			return [list http.code $code]
		}

		return [list OK $body]
	}
	
# Make a non-blocking request to the crypto server
core::args::register \
	-proc_name core::api::crypto::_socket_send \
	-args [list \
		[list -arg -host     -mand 1 -check ASCII -desc {Crypto server host name}] \
		[list -arg -port     -mand 1 -check UINT  -desc {Crypto server port number}] \
		[list -arg -req_data -mand 1 -check ANY   -desc {Request data}] \
	] \
	-body {
		variable CFG
		variable SOCKET
		
		set host     $ARGS(-host)
		set port     $ARGS(-port)
		set req_data $ARGS(-req_data)

		if {[catch {
			foreach {req_id status complete} [core::socket::send_req \
				-tls          {} \
				-is_http      0 \
				-conn_timeout $CFG(conn_timeout) \
				-req_timeout  $CFG(send_timeout) \
				-client_data  $req_data \
				-host         $host \
				-port         $port] {break}
		} err]} {
			core::log::write ERROR {$err}
			return [list socket.error $err]
		}

		# Retrieve the response
		set response [core::socket::req_info -req_id $req_id -item response]

		# Clear up the socket
		core::socket::clear_req -req_id $req_id

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