# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# CC payment harness
#
set pkg_version 1.0
package provide core::harness::payment::CC $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0
package require core::stub     1.0

core::args::register_ns \
	-namespace core::harness::payment::CC \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check \
		core::stub]

namespace eval core::harness::payment::CC  {
	variable CFG
	variable CORE_DEF
	variable HARNESS_DATA

	set CORE_DEF(request) [list -arg -request -mand 1 -check ASCII -desc {Request data}]

	# We need different response and request handling based on
	# which payment gateway is being used. The responses also need
	# to be different depending on the cvv2 supplied. Store all
	# the responses in a dictionary and use templates to store the xml
	dict set HARNESS_DATA DCASHXML template {
		<Response>
			<status>##TP_status##</status>
			<reason>##TP_reason##</reason>
			<information>##TP_information##</information>
			<merchantreference>##TP_merchantreference##</merchantreference>
			<datacash_reference>##TP_datacash_reference##</datacash_reference>
			<time>##TP_time##</time>
			<mode>##TP_mode##</mode>
			<CardTxn>
				<Cv2Avs>
					<policy>##TP_policy##</policy>
					<cv2avs_status>##TP_cv2avs_status##</cv2avs_status>
				</Cv2Avs>
				##TP_IF {[tpGetVar use_3D_secure 0]}##
				<ThreeDSecure>
					<pareq_message>##TP_pareq_message##</pareq_message>
					<acs_url>##TP_acs_url##</acs_url>
				</ThreeDSecure>
				##TP_ENDIF##
			</CardTxn>
		</Response>
	}
	# Below are the response data definitions keyed by cvv2 and 3d secure
	# e.g.
	# dict set HARNESS_DATA $pg_type data $cvv2 $use_3D_secure {response values}
	dict set HARNESS_DATA DCASHXML data 100 0 {status 1   reason {Payment ok}}
	dict set HARNESS_DATA DCASHXML data 101 0 {status 3   reason {Unable to authorise funds}}
	dict set HARNESS_DATA DCASHXML data 102 0 {status 7   reason {Payment declined}}
	dict set HARNESS_DATA DCASHXML data 103 0 {status 21  reason {Invalid payment type}}
	dict set HARNESS_DATA DCASHXML data 104 0 {status 22  reason {Invalid reference number}}
	dict set HARNESS_DATA DCASHXML data 105 0 {status 24  reason {Invalid Expiry date}}
	dict set HARNESS_DATA DCASHXML data 106 0 {status 25  reason {Invalid Card Number}}
	dict set HARNESS_DATA DCASHXML data 107 0 {status 26  reason {Invalid Card number length}}
	dict set HARNESS_DATA DCASHXML data 108 0 {status 27  reason {Invalid issue number}}
	dict set HARNESS_DATA DCASHXML data 109 0 {status 28  reason {Invalid Start date}}
	dict set HARNESS_DATA DCASHXML data 110 0 {status 36  reason {Speed limit hit}}
	dict set HARNESS_DATA DCASHXML data 111 0 {status 161 reason {Payment referred}}

	dict set HARNESS_DATA DCASHXML data 100 1 {status 150 reason {3DS verificarion redirect required}}
	dict set HARNESS_DATA DCASHXML data 101 1 {status 158 reason {Transaction cannot perform 3DS}}
	dict set HARNESS_DATA DCASHXML data 102 1 {status 162 reason {transaction will benefit from 3DS without redirect}}
	dict set HARNESS_DATA DCASHXML data 103 1 {status 21  reason {Invalid payment type}}
	dict set HARNESS_DATA DCASHXML data 104 1 {status 22  reason {Invalid reference number}}
	dict set HARNESS_DATA DCASHXML data 105 1 {status 24  reason {Invalid Expiry date}}
	dict set HARNESS_DATA DCASHXML data 106 1 {status 25  reason {Invalid Card Number}}
	dict set HARNESS_DATA DCASHXML data 107 1 {status 26  reason {Invalid Card number length}}
	dict set HARNESS_DATA DCASHXML data 108 1 {status 27  reason {Invalid issue number}}
	dict set HARNESS_DATA DCASHXML data 109 1 {status 28  reason {Invalid Start date}}
	dict set HARNESS_DATA DCASHXML data 110 1 {status 36  reason {Speed limit hit}}
	dict set HARNESS_DATA DCASHXML data 111 1 {status 179 reason {3DS verification failed}}
	dict set HARNESS_DATA DCASHXML data 112 1 {status 183 reason {3DS bypassed for this transaction}}

	dict set HARNESS_DATA BANWIRE  data 100 0 {status 1 code {} reason {}}
	dict set HARNESS_DATA BANWIRE  data 101 0 {status 0 code 400 reason {Variables de configuration faltantes}}
	dict set HARNESS_DATA BANWIRE  data 102 0 {status 0 code 401 reason {ID de cuenta invalido}}
	dict set HARNESS_DATA BANWIRE  data 103 0 {status 0 code 402 reason {Cuenta bloqueada}}
	dict set HARNESS_DATA BANWIRE  data 104 0 {status 0 code 403 reason {Numero de tarjeta invalida para la terminal de visa/mastercard/amex}}
	dict set HARNESS_DATA BANWIRE  data 105 0 {status 0 code 404 reason {El codigo ccv2 es invalido}}
	dict set HARNESS_DATA BANWIRE  data 106 0 {status 0 code 405 reason {direccion y codigo postal requeridos para pagos con AMEX}}
	dict set HARNESS_DATA BANWIRE  data 107 0 {status 0 code 406 reason {Lo sentimos, esta tarjeta no peude ser procesada por seguridad, si crees que esto es un error por favor envia un correo a contacto@banwire.com o comunicate al tel. 15.79.91.55}}
	dict set HARNESS_DATA BANWIRE  data 108 0 {status 0 code 407 reason {Divisa desconocida}}
	dict set HARNESS_DATA BANWIRE  data 109 0 {status 0 code 408 reason {El total excede el monto maximo}}
	dict set HARNESS_DATA BANWIRE  data 110 0 {status 0 code 409 reason {El usario no tiene permisos para usar la API PAGO-PRO para duda o aclaraciones contactanos a contacto@banwire.com}}
	dict set HARNESS_DATA BANWIRE  data 111 0 {status 0 code 410 reason {Error de segiridad, con los parametros enviados son incorrectos.}}
	dict set HARNESS_DATA BANWIRE  data 111 0 {status 0 code 700 reason {Pago Denegado}}
	dict set HARNESS_DATA BANWIRE  data 111 0 {status 0 code 100 reason {Error de AVS}}
}

core::args::register \
	-proc_name core::harness::payment::CC::expose_magic \
	-body {
		variable HARNESS_DATA
		set i 0

		set MAGIC(0,header) {CVV2 Value}
		set MAGIC(1,header) {3D Secure Enabled}
		set MAGIC(2,header) {Response Data}

		foreach request_type [dict keys $HARNESS_DATA] {

			set MAGIC($i,request_type) "$request_type Payment Gateway"
			set j 0

			foreach key [dict keys [dict get $HARNESS_DATA $request_type data]] {
				if {[dict exists $HARNESS_DATA $request_type data $key 0]} {
					set data [dict get $HARNESS_DATA $request_type data $key 0]
					set MAGIC($i,$j,0,column) $key
					set MAGIC($i,$j,1,column) 0
					set MAGIC($i,$j,2,column) $data
					core::log::write DEV {$request_type - $key - 0 - $data}
					incr j
				}
			}
			foreach key [dict keys [dict get $HARNESS_DATA $request_type data]] {
                if {[dict exists $HARNESS_DATA $request_type data $key 1]} {
                    set data [dict get $HARNESS_DATA $request_type data $key 1]
                    set MAGIC($i,$j,0,column) $key
                    set MAGIC($i,$j,1,column) 1
                    set MAGIC($i,$j,2,column) $data
                    core::log::write DEV {$request_type - $key - 1 - $data}
					incr j
                }
            }
			set MAGIC($i,num_rows) $j
			incr i
		}
		set MAGIC(num_requests) $i
		set MAGIC(num_columns) 3

		return [array get MAGIC]
	}


# 
# init
#
# Register CC harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::payment::CC::init \
	-args      [list \
		[list -arg -enabled      -mand 0 -check BOOL   -default_cfg CC_HARNESS_ENABLED      -default 0 -desc {Enable the Credit Card harness}] \
		[list -arg -redirect_url -mand 0 -check STRING -default_cfg CC_HARNESS_REDIRECT_URL -default 0 -desc {Url for redirection}] \
	] \
	-body {
		if {!$ARGS(-enabled)} {
			core::log::xwrite -msg {Credit Card Harness available though disabled} -colour yellow
			return
		}
		variable CFG

		set CFG(redirect_url) $ARGS(-redirect_url)

		core::stub::init

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				ob_socket   send_req \
				ob_socket   req_info \
				ob_socket   clear_req \
			] \

		core::stub::set_override \
			-proc_name       {ob_socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_deposit} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_process_request \
					-request [lindex $args end-2] \
					-host    [lindex $args end-1]]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_withdrawal} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_process_request \
					-request [lindex $args end-2] \
                    -host    [lindex $args end-1]]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::3d_secure_auth} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_process_request \
					-request [lindex $args end-2] \
					-host    [lindex $args end-1]]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::send_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::send_micro_transaction} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_process_request \
					-request [lindex $args end-2] \
					-host    [lindex $args end-1]]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::req_info} \
			-arg_list        [list 1 http_body] \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_deposit} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_get_response]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::req_info} \
			-arg_list        [list 1 http_body] \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_withdrawal} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_get_response]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::req_info} \
			-arg_list        [list 1 http_body] \
			-scope           proc \
			-scope_key       {::core::payment::CC::3d_secure_auth} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_get_response]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::req_info} \
			-arg_list        [list 1 http_body] \
			-scope           proc \
			-scope_key       {::core::payment::CC::send_micro_transaction} \
			-use_body_return 1 \
			-body {
				return [core::harness::payment::CC::_get_response]
			}

		core::stub::set_override \
			-proc_name       {ob_socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_deposit} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {ob_socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::make_withdrawal} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {ob_socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::3d_secure_auth} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {ob_socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::payment::CC::send_micro_transaction} \
			-return_data     {}

		_prepare_queries

		core::log::xwrite -msg {Credit Card Harness available and enabled} -colour yellow

	}


#
# _process_request
#
# Simply matches the request host against tpmtgtwyhost to get the payment
# gatweay type. This s used to decide which _prepare_response_xxx proc to
# call to process the request and prepare the response
#
core::args::register \
	-proc_name {core::harness::payment::CC::_process_request} \
	-desc      {Main request processing proc to decide which response to send back} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
		[list -arg -host    -mand 1 -check ASCII -desc {The host the request was sent to}] \
	] \
	-body {
		variable HARNESS_DATA

		set request $ARGS(-request)
		set host    "%$ARGS(-host)%"

		# Get the payment gateway type from the databse
		if {[catch {
			set rs [core::db::exec_qry \
				-name core::harness::payment::CC::get_pg_type \
				-args [list $host]]
		} msg]} {
			core::log::xwrite \
				-msg    {Could not get payment gateway type from the database} \
				-colour red
			return [list -1 HARNESS_FAILED 1]
		}

		if {[db_get_nrows $rs] != 1} {
			core::log::xwrite \
				-msg    {Unable to match to a single payment gateway} \
				-colour red
			return [list -1 HARNESS_FAILED 1]
		}

		set pg_type [db_get_col $rs 0 pg_type]

		return [_prepare_response_${pg_type} -request $request]
	}

#
# _prepare_response_DCASHXML
#
# Analyses the DCASHXML format received request data and prepares a response
# to be returned from a subsequent req_info call
#
core::args::register \
	-proc_name {core::harness::payment::CC::_prepare_response_DCASHXML} \
	-desc      {Process a Data Cash XML specific request and prepare the result} \
	-args      [list \
		$::core::harness::payment::CC::CORE_DEF(request) \
	] \
	-body {
		variable HARNESS_DATA
		variable CFG
		
		set request $ARGS(-request)

		set body_start [string first "\n\r" $request]

		if {$body_start == -1} {
			# No body found
			core::log::xwrite \
				-msg    {Request Body not found in request : $request} \
				-colour red
			return [list -1 HTTP_INVALID 1]
		}

		set xml [string range $request [expr {$body_start + 2}] end]

		foreach {status doc} [core::xml::parse -strict 0 -xml $xml] {}

		if {$status != {OK}} {
			core::log::xwrite \
				-msg    {Unable to parse xml: $req} \
				-colour red
		}

		# Get cvv2 value
		if {[catch {
			set cvv2 [[[$doc getElementsByTagName cv2] firstChild] nodeValue]
		} msg]} {
			set cvv2 "100"
		}

		foreach {param xpath} {
			merchantreference /Request/Transaction/TxnDetails/merchantreference
			verify_3DS        /Request/Transaction/TxnDetails/ThreeDSecure/verify
			cvv2_policy       /Request/Transaction/CardTxn/Card/Cv2Avs/policy
			cvv2              /Request/Transaction/CardTxn/Card/Cv2Avs/cv2
		} {
			if {[catch {
				set $param [core::xml::extract_data \
					-node $doc \
					-xpath $xpath \
					-return_list 1]
			} msg]} {
				set $param {}
			}
		}

		set use_3D_secure [expr {$verify_3DS == {yes} ? 1 : 0}]
		set cvv2          [expr {$cvv2 == {} ? 100 : $cvv2}]

		if {[dict exists $HARNESS_DATA DCASHXML data $cvv2 $use_3D_secure]} {
			set response_codes [dict get $HARNESS_DATA DCASHXML data $cvv2 $use_3D_secure]
		} else {
			set response_codes [dict get $HARNESS_DATA DCASHXML data 100 $use_3D_secure]
		}

		set status [lindex $response_codes 1]
		set reason [lindex $response_codes 3]

		set information        {Response provided by Test Harness}
		set datacash_reference $merchantreference
		set time               [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
		set mode               {TEST}
		set cv2avs_status      1

		tpBindString status             $status
		tpBindString reason             $reason
		tpBindString information        $information
		tpBindString merchantreference  $merchantreference
		tpBindString datacash_reference $datacash_reference
		tpBindString time               $time
		tpBindString mode               $mode
		tpBindString policy             $cvv2_policy
		tpBindString cv2avs_status      $cv2avs_status

		# We may want to store these as part of the dictionary although maybe
		# this would be better done another way as this would be needed if a
		# customer team wanted to set up a fake redirect
		tpSetVar     use_3D_secure      $use_3D_secure
		tpBindString pareq_message      1234567890abcdef
		tpBindString acs_url            $CFG(redirect_url)

		dict set HARNESS_DATA response \
			[tpStringPlay -tostring [dict get $HARNESS_DATA DCASHXML template]]

		return [list 1 OK 1]
	}

#
# _prepare_response_BANWIRE
#
# Analyses the BANWIRE request data and prepares a response
# to be returned from a subsequent req_info call
#
core::args::register \
	-proc_name {core::harness::payment::CC::_prepare_response_BANWIRE} \
	-desc      {Process a Banwire specific request and prepare the result} \
	-args      [list \
		$::core::harness::payment::CC::CORE_DEF(request) \
	] \
	-body {
		variable HARNESS_DATA

		set request $ARGS(-request)

		set body_start [string first "\n\r" $request]

		if {$body_start == -1} {
			# No body found
			core::log::xwrite \
				-msg    {Request Body not found in request : $request} \
				-colour red
			return [list -1 HTTP_INVALID 1]
		}

		set content [string range $request [expr {$body_start + 2}] end]

		set response_list [split $content "&"]

		foreach nv_pair $response_list {
			foreach {name value} [split $nv_pair "="] {break}

			set ${name}_arg $value
		}

		set response_user      $user_arg
		set response_id        12345
		set response_reference $reference_arg
		set response_date      [urlencode [clock format [clock seconds] -format "%d-%m-%Y %H:%M:%S"]]
		set response_card      [string range $card_num_arg end-3 end]
		set response_amount    $ammount_arg
		set response_client    $card_name_arg

		# Build up the post data response
		set post_data_str {}
		append post_data_str user=${response_user}&
		append post_data_str id=${response_id}&
		append post_data_str referencia=${response_reference}&
		append post_data_str date=${response_date}&
		append post_data_str card=${response_card}&

		# Get response specific data
		if {[dict exists $HARNESS_DATA BANWIRE data $card_ccv2_arg 0]} {
			set data [dict get $HARNESS_DATA BANWIRE data $card_ccv2_arg 0]
		} else {
			set data [dict get $HARNESS_DATA BANWIRE data 100 0]
		}

		set status [lindex $data 1]
		set code   [lindex $data 3]
		set reason [lindex $data 5]

		if {$status} {
			append post_data_str response=ok&
			append post_data_str code_auth=12345&
			append post_data_str monto=$response_amount&
			append post_data_str client=$response_client
		} else {
			append post_data_str response=ko&
			append post_data_str code=$code&
			append post_data_str message=$reason
		}

		dict set HARNESS_DATA response $post_data_str

		return [list 1 OK 1]
	}

#
# _get_response
#
# Simply returns the prepared response. After calling any prepared
# response in the dictionary will be cleared
#
core::args::register \
	-proc_name {core::harness::payment::CC::_get_response} \
	-desc      {Gets the response prepared by _process_request} \
	-body {
		variable HARNESS_DATA

		set response [dict get $HARNESS_DATA response]

		dict unset HARNESS_DATA response

		return $response
	}


core::args::register \
	-proc_name {core::harness::payment::CC::_prepare_queries} \
	-desc      {Prepare database queries needed by the harness} \
	-body {

		core::db::store_qry \
			-name {core::harness::payment::CC::get_pg_type} \
			-qry {
				select
					pgh.pg_type
				from
					tPmtGateHost pgh
				where
					pgh.pg_ip like ?
			}
	}
