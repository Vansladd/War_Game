# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# DMBC payment harness.
#
# Limitation: This is hard-coded to only support single transactions at once
# although examples provided indicate that the listener should accept
# notifications related to multiple payments (i.e. multiple OPERACION
# elements).
#
set pkg_version 1.0
package provide core::harness::payment::DMBC $pkg_version

# Dependencies
package require core::payment  1.0
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0
package require core::stub     1.0
package require core::xml      1.0
package require core::soap     1.0

core::args::register_ns \
	-namespace core::harness::payment::DMBC \
	-version   $pkg_version \
	-dependent [list \
		core::payment \
		core::log \
		core::args \
		core::check \
		core::socket \
		core::stub]

namespace eval core::harness::payment::DMBC  {
	variable CFG
	variable CORE_DEF
	variable MAGIC_DATA

	set CORE_DEF(request) [list -arg -request -mand 1 -check ASCII -desc {Request data}]

	# ------------------------------------------------
	#  make_deposit example request.
	# ------------------------------------------------
	# Example request: make_deposit (made from portal, admin).
	#
	#  <?xml version="1.0" encoding="utf-8"?>
	#  <SOAP-ENV:Envelope SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
	#      xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"
	#      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	#      xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	#      xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">
	#  <SOAP-ENV:Body>
	#      <DoPaymentWithReference xmlns="https://api.dineromail.com/">
	#          <Credential>
	#             <APIUserName>$PMT(client)</APIUserName>
	#             <APIPassword>$PMT(password)</APIPassword>
	#          </Credential>
	#          <Crypt>$PMT(crypt)</Crypt>
	#          <MerchantTransactionId>$PMT(pmt_id)</MerchantTransactionId>
	#          <Items>
	#              <Item>
	#                  <Amount>$PMT(amount)</Amount>
	#                  <Currency>$PMT(ccy_code)</Currency>
	#                  <Name>$PMT(item_name)</Name>
	#                  <Quantity>$PMT(quantity)</Quantity>
	#              </Item>
	#          </Items>
	#          <Buyer>
	#              <Name>$PMT(fname)</Name>
	#              <LastName>$PMT(lname)</LastName>
	#              <Email>$PMT(email)</Email>
	#          </Buyer>
	#          <Provider>$PMT(provider)</Provider>
	#          <UniqueMessageId>$PMT(uniqueid)</UniqueMessageId>
	#          <Hash>$PMT(hash)</Hash>
	#      </DoPaymentWithReference>
	#  </SOAP-ENV:Body>
	#  </SOAP-ENV:Envelope>

	# Response template for the make_deposit.
	dict set MAGIC_DATA templates make_deposit {
		<response>
			<TransactionId>##TP_transactionId##</TransactionId>
			<VoucherUrl>##TP_voucherUrl##://example.com/voucher</VoucherUrl>
			<BarcodeImageUrl>##TP_barcodeImageUrl##</BarcodeImageUrl>
			<BarcodeDigits>##TP_barcodeDigits##</BarcodeDigits>
			<MerchantTransactionId>##TP_merchantTransactionId##</MerchantTransactionId>
			<Message>##TP_message##</Message>
			<UniqueMessageId>##TP_uniqueMessageId##</UniqueMessageId>
			<Status>##TP_status##</Status>
		</response>
	}

	# --------------------------------------------------------
	#  make_ipn_request example request.
	# --------------------------------------------------------
	#  Example request: make_ipn_request (made by the Dineromail listener).
	#
	#  DATA=<REPORTE>
	#     <NROCTA>111111</NROCTA>
	#     <DETALLE>
	#          <CONSULTA>
	#              <CLAVE>MIPASSWORD001</CLAVE>
	#              <TIPO>1</TIPO>
	#              <OPERACIONES>
	#                  <ID>31548</ID>
	#                  <ID>XA5547</ID>
	#              </OPERACIONES>
	#          </CONSULTA>
	#     </DETALLE>
	#  </REPORTE>

	# Response template for the make_ipn_request.
	dict set MAGIC_DATA templates make_ipn_request {
		<REPORTE>
			<ESTADOREPORTE>##TP_estadoreporte##</ESTADOREPORTE>
			<DETALLE>
				<OPERACIONES>
					<OPERACION>
						<ID>##TP_id##</ID>
						<FECHA>##TP_fecha##</FECHA>
						<ESTADO>##TP_estado##</ESTADO>
						<NUMTRANSACCION>##TP_numtransaccion##</NUMTRANSACCION>
						<COMPRADOR>
							<EMAIL>##TP_email##</EMAIL>
							<DIRECCION>##TP_direccion##</DIRECCION>
							<COMENTARIO>##TP_comentario##</COMENTARIO>
							<NOMBRE>##TP_nombre##</NOMBRE>
							<TELEFONO>##TP_telefono##</TELEFONO>
							<TIPODOC>##TP_tipodoc##</TIPODOC>
							<NUMERODOC>##TP_numerodoc##</NUMERODOC>
						</COMPRADOR>
						<MONTO>##TP_monto##</MONTO>
						<MONTONETO>##TP_montoneto##</MONTONETO>
						<METODOPAGO>##TP_metodopago##</METODOPAGO>
						<MEDIOPAGO>##TP_mediopago##</MEDIOPAGO>
						<CUOTAS>##TP_cuotas##</CUOTAS>
						<ITEMS>
							<ITEM>
								<DESCRIPCION>##TP_descripcion##</DESCRIPCION>
								<MONEDA>##TP_moneda##</MONEDA>
								<PRECIOUNITARIO>##TP_preciounitario##</PRECIOUNITARIO>
								<CANTIDAD>##TP_cantidad##</CANTIDAD>
							</ITEM>
						</ITEMS>
						<VENDEDOR>
							<TIPODOC>##TP_tipodoc##</TIPODOC>
							<NUMERODOC>##TP_numerodoc##</NUMERODOC>
						</VENDEDOR>
					</OPERACION>
				</OPERACIONES>
			</DETALLE>
		</REPORTE>
	}

	# Magic data.
	# These values may be used to force a certain response.

	# Provider determines the response to make_deposit and make_ipn_request.
	#
	# Note that the qualified values given here (DM_OK, PENDING) are translated
	# to their numeric values in the actual response according to the mapping
	# provided by dineromail.tcl. The descriptive value is given here for clarity.
	#
	# These test providers can be set with the config item DINEROMAIL_PROVIDERS.
	#
	# See https://wiki.openbet/display/codere/Using+the+dineromail+test+harness
	# for more details.

	dict set MAGIC_DATA provider default                                              {status COMPLETED   estadoreporte DM_OK                        estado COMPLETED}

	# make_deposit is COMPLETED
	dict set MAGIC_DATA provider test-COMPLETED-DM_OK-PENDING                         {status COMPLETED   estadoreporte DM_OK                        estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_OK-COMPLETED                       {status COMPLETED   estadoreporte DM_OK                        estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_OK-DENIED                          {status COMPLETED   estadoreporte DM_OK                        estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_WRONG_XML_FORMAT-PENDING       {status COMPLETED   estadoreporte DM_ERR_WRONG_XML_FORMAT      estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_WRONG_XML_FORMAT-COMPLETED     {status COMPLETED   estadoreporte DM_ERR_WRONG_XML_FORMAT      estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_WRONG_XML_FORMAT-DENIED        {status COMPLETED   estadoreporte DM_ERR_WRONG_XML_FORMAT      estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_ACCT-PENDING           {status COMPLETED   estadoreporte DM_ERR_INVALID_ACCT          estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_ACCT-COMPLETED         {status COMPLETED   estadoreporte DM_ERR_INVALID_ACCT          estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_ACCT-DENIED            {status COMPLETED   estadoreporte DM_ERR_INVALID_ACCT          estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_PWD-PENDING            {status COMPLETED   estadoreporte DM_ERR_INVALID_PWD           estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_PWD-COMPLETED          {status COMPLETED   estadoreporte DM_ERR_INVALID_PWD           estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_PWD-DENIED             {status COMPLETED   estadoreporte DM_ERR_INVALID_PWD           estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_REQ_TYPE-PENDING       {status COMPLETED   estadoreporte DM_ERR_INVALID_REQ_TYPE      estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_REQ_TYPE-COMPLETED     {status COMPLETED   estadoreporte DM_ERR_INVALID_REQ_TYPE      estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_REQ_TYPE-DENIED        {status COMPLETED   estadoreporte DM_ERR_INVALID_REQ_TYPE      estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_OP_ID-PENDING          {status COMPLETED   estadoreporte DM_ERR_INVALID_OP_ID         estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_OP_ID-COMPLETED        {status COMPLETED   estadoreporte DM_ERR_INVALID_OP_ID         estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_INVALID_OP_ID-DENIED           {status COMPLETED   estadoreporte DM_ERR_INVALID_OP_ID         estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_ACCT_OR_INVALID_PWD-PENDING    {status COMPLETED   estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_ACCT_OR_INVALID_PWD-COMPLETED  {status COMPLETED   estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_ACCT_OR_INVALID_PWD-DENIED     {status COMPLETED   estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado DENIED}

	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_NO_OP_FOUND-PENDING            {status COMPLETED   estadoreporte DM_ERR_NO_OP_FOUND           estado PENDING}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_NO_OP_FOUND-COMPLETED          {status COMPLETED   estadoreporte DM_ERR_NO_OP_FOUND           estado COMPLETED}
	dict set MAGIC_DATA provider test-COMPLETED-DM_ERR_NO_OP_FOUND-DENIED             {status COMPLETED   estadoreporte DM_ERR_NO_OP_FOUND           estado DENIED}

	# make_despot is PENDING
	dict set MAGIC_DATA provider test-PENDING-DM_OK-PENDING                           {status PENDING     estadoreporte DM_OK                        estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_OK-COMPLETED                         {status PENDING     estadoreporte DM_OK                        estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_OK-DENIED                            {status PENDING     estadoreporte DM_OK                        estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_WRONG_XML_FORMAT-PENDING         {status PENDING     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_WRONG_XML_FORMAT-COMPLETED       {status PENDING     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_WRONG_XML_FORMAT-DENIED          {status PENDING     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_ACCT-PENDING             {status PENDING     estadoreporte DM_ERR_INVALID_ACCT          estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_ACCT-COMPLETED           {status PENDING     estadoreporte DM_ERR_INVALID_ACCT          estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_ACCT-DENIED              {status PENDING     estadoreporte DM_ERR_INVALID_ACCT          estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_PWD-PENDING              {status PENDING     estadoreporte DM_ERR_INVALID_PWD           estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_PWD-COMPLETED            {status PENDING     estadoreporte DM_ERR_INVALID_PWD           estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_PWD-DENIED               {status PENDING     estadoreporte DM_ERR_INVALID_PWD           estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_REQ_TYPE-PENDING         {status PENDING     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_REQ_TYPE-COMPLETED       {status PENDING     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_REQ_TYPE-DENIED          {status PENDING     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_OP_ID-PENDING            {status PENDING     estadoreporte DM_ERR_INVALID_OP_ID         estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_OP_ID-COMPLETED          {status PENDING     estadoreporte DM_ERR_INVALID_OP_ID         estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_INVALID_OP_ID-DENIED             {status PENDING     estadoreporte DM_ERR_INVALID_OP_ID         estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_ACCT_OR_INVALID_PWD-PENDING      {status PENDING     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_ACCT_OR_INVALID_PWD-COMPLETED    {status PENDING     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_ACCT_OR_INVALID_PWD-DENIED       {status PENDING     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado DENIED}

	dict set MAGIC_DATA provider test-PENDING-DM_ERR_NO_OP_FOUND-PENDING              {status PENDING     estadoreporte DM_ERR_NO_OP_FOUND           estado PENDING}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_NO_OP_FOUND-COMPLETED            {status PENDING     estadoreporte DM_ERR_NO_OP_FOUND           estado COMPLETED}
	dict set MAGIC_DATA provider test-PENDING-DM_ERR_NO_OP_FOUND-DENIED               {status PENDING     estadoreporte DM_ERR_NO_OP_FOUND           estado DENIED}

	# make_deposit is DENIED
	dict set MAGIC_DATA provider test-DENIED-DM_OK-PENDING                            {status DENIED     estadoreporte DM_OK                        estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_OK-COMPLETED                          {status DENIED     estadoreporte DM_OK                        estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_OK-DENIED                             {status DENIED     estadoreporte DM_OK                        estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_WRONG_XML_FORMAT-PENDING          {status DENIED     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_WRONG_XML_FORMAT-COMPLETED        {status DENIED     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_WRONG_XML_FORMAT-DENIED           {status DENIED     estadoreporte DM_ERR_WRONG_XML_FORMAT      estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_ACCT-PENDING              {status DENIED     estadoreporte DM_ERR_INVALID_ACCT          estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_ACCT-COMPLETED            {status DENIED     estadoreporte DM_ERR_INVALID_ACCT          estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_ACCT-DENIED               {status DENIED     estadoreporte DM_ERR_INVALID_ACCT          estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_PWD-PENDING               {status DENIED     estadoreporte DM_ERR_INVALID_PWD           estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_PWD-COMPLETED             {status DENIED     estadoreporte DM_ERR_INVALID_PWD           estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_PWD-DENIED                {status DENIED     estadoreporte DM_ERR_INVALID_PWD           estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_REQ_TYPE-PENDING          {status DENIED     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_REQ_TYPE-COMPLETED        {status DENIED     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_REQ_TYPE-DENIED           {status DENIED     estadoreporte DM_ERR_INVALID_REQ_TYPE      estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_OP_ID-PENDING             {status DENIED     estadoreporte DM_ERR_INVALID_OP_ID         estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_OP_ID-COMPLETED           {status DENIED     estadoreporte DM_ERR_INVALID_OP_ID         estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_INVALID_OP_ID-DENIED              {status DENIED     estadoreporte DM_ERR_INVALID_OP_ID         estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_ACCT_OR_INVALID_PWD-PENDING       {status DENIED     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_ACCT_OR_INVALID_PWD-COMPLETED     {status DENIED     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_ACCT_OR_INVALID_PWD-DENIED        {status DENIED     estadoreporte DM_ERR_ACCT_OR_INVALID_PWD   estado DENIED}

	dict set MAGIC_DATA provider test-DENIED-DM_ERR_NO_OP_FOUND-PENDING               {status DENIED     estadoreporte DM_ERR_NO_OP_FOUND           estado PENDING}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_NO_OP_FOUND-COMPLETED             {status DENIED     estadoreporte DM_ERR_NO_OP_FOUND           estado COMPLETED}
	dict set MAGIC_DATA provider test-DENIED-DM_ERR_NO_OP_FOUND-DENIED                {status DENIED     estadoreporte DM_ERR_NO_OP_FOUND           estado DENIED}
}

core::args::register \
	-proc_name core::harness::payment::DMBC::expose_magic \
	-desc {Provide magic data details to the documentation generator} \
	-body {
		core::log::write INFO {core::harness::payment::DMBC::expose_magic START}
		variable MAGIC_DATA

		# Row dividers.
		#
		# Treat make_deposit and make_ipn_request as one, since they cannot be
		# controlled independently anyway.
		set MAGIC(num_requests) 1

		# Headers.
		set MAGIC(num_columns)  2
		set MAGIC(0,header) {Provider}
		set MAGIC(1,header) {Response Data}

		# Rows for request 0.
		set MAGIC(0,request_type) "make_deposit request"
		set MAGIC(0,num_rows)     [dict size [dict get $MAGIC_DATA provider]]


		set row_i 0
		dict for {provider response_data} [dict get $MAGIC_DATA provider] {
			set MAGIC(0,$row_i,0,column) $provider

			set response_string ""
			dict for {key val} $response_data {
				append response_string " $key=$val "
			}

			set MAGIC(0,$row_i,1,column) $response_string
			incr row_i
		}

		set MAGIC_as_list [array get MAGIC]
		core::log::write DEBUG {returning $MAGIC_as_list}
		return [array get MAGIC]
	}


#
# init
#
# Register DMBC harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::payment::DMBC::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg DMBC_HARNESS_ENABLED -default 0 -desc {Enable the Dineromail harness}] \
		[list -arg -dmbc_harness_listener_url -mand 0 -check ASCII -default_cfg DMBC_HARNESS_LISTENER_URL -default "" -desc {URL for the Dineromail listener}] \
	] \
	-body {
		variable CFG

		if {!$ARGS(-enabled)} {
			core::log::xwrite -msg {Dineromail Harness available though disabled} -colour yellow
			return
		}

		set CFG(dmbc_harness_listener_url) $ARGS(-dmbc_harness_listener_url)
		if {$CFG(dmbc_harness_listener_url) == ""} {
			error {When Dineromail Harness is enabled using config DMBC_HARNESS_ENABLED the listener URL must be set using config DMBC_HARNESS_LISTENER_URL.}
		}

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				core::socket        send_req \
				core::socket        req_info \
				core::socket        clear_req \
				core::payment::DMBC update_pmt \
			]

		# Override the send_req call in core::payment::DMBC::make_deposit.
		core::stub::set_override \
			-proc_name       core::socket::send_req \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_deposit \
			-arg_list        [list -req ".*DoPaymentWithReference.*"] \
			-body {
				core::log::write INFO {core::socket::send_req: Using make_deposit stub from core::harness::payment::DMBC}
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				# Prepare the make_deposit response.
				return [core::harness::payment::DMBC::_prepare_response_make_deposit -request $ARGS(-req)]
			} \
			-use_body_return 1

		# Override the req_info call for make_deposit.
		core::stub::set_override \
			-proc_name       core::socket::req_info \
			-scope           proc \
			-arg_list        [list -item http_body -req_id make_deposit] \
			-scope_key       ::core::payment::DMBC::make_deposit \
			-body {
				core::log::write INFO {core::socket::req_info: Using make_deposit stub from core::harness::payment::DMBC}
				return [core::harness::payment::DMBC::get_response_data]
			} \
			-use_body_return 1

		# Override the update_pmt call to update the payment using the original
		# proc, and then make a call to the listener.
		core::stub::set_override \
			-proc_name       core::payment::DMBC::update_pmt \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_deposit \
			-body {
				set mapped_proc [core::stub::get_mapped_proc \
					-ns_name      core::payment::DMBC \
					-proc_name    update_pmt \
					-scope_key    global]

				core::log::xwrite \
					-msg {core::payment::DMBC::update_pmt: Overridden proc calling mapped proc: $mapped_proc} \
					-colour yellow

				set return_val [$mapped_proc {*}$args]

				# Make the request to the listener.
				core::harness::payment::DMBC::send_listener_notification_request

				return $return_val

			} \
			-use_body_return 1

		# Clear req should just not error.
		core::stub::set_override \
			-proc_name       core::socket::clear_req \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_deposit \
			-body {
				core::log::write INFO {core::socket::clear_req: Using make_deposit stub from core::harness::payment::DMBC::make_deposit}
				return 1
			} \
			-use_body_return 1

		# Override the send_req call in core::payment::DMBC::make_ipn_request.
		core::stub::set_override \
			-proc_name       core::socket::send_req \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_ipn_request \
			-body {
				core::log::xwrite \
					-msg {core::socket::send_req: Using make_ipn_request stub from core::harness::payment::DMBC} \
					-colour yellow

				array set ARGS [core::args::check core::socket::send_req {*}$args]
				return [core::harness::payment::DMBC::_prepare_response_make_ipn_request -request $ARGS(-req)]
			} \
			-use_body_return 1

		# Override the req_info call for make_ipn_request.
		core::stub::set_override \
			-proc_name       core::socket::req_info \
			-arg_list        [list -item http_body -req_id make_ipn_request] \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_ipn_request \
			-body {
				core::log::write INFO {core::socket::req_info: Using make_ipn_request stub from core::harness::payment::DMBC}
				return [core::harness::payment::DMBC::get_response_data]
			} \
			-use_body_return 1

		# Clear req should just not error.
		core::stub::set_override \
			-proc_name       core::socket::clear_req \
			-scope           proc \
			-scope_key       ::core::payment::DMBC::make_ipn_request \
			-body {
				core::log::write INFO {core::socket::clear_req: Using make_deposit stub from core::harness::payment::DMBC::make_ipn_request}
				return 1
			} \
			-use_body_return 1

		core::log::xwrite -msg {Dineromail Harness available and enabled} -colour yellow
	}

#
# _prepare_response_make_deposit
#
# Processes a make_deposit request (made by portal or admin) and
# prepares the response.
#
core::args::register \
	-proc_name {core::harness::payment::DMBC::_prepare_response_make_deposit} \
	-desc      {Process an IPN Report request and prepare the response} \
	-args      [list \
		$::core::harness::payment::DMBC::CORE_DEF(request) \
	] \
	-body {
		variable RESPONSE
		variable MAGIC_DATA

		core::soap::store_envelope \
			-name make_deposit \
			-type received \
			-raw_envelope $ARGS(-request)

		core::log::xwrite \
			-msg     "core::harness::payment::DMBC::_prepare_response_make_deposit: Processing request:" \
			-colour  yellow

		core::log::xwrite \
			-msg     [core::soap::print_soap -name make_deposit -type received] \
			-colour  yellow

		set make_deposit_doc [core::soap::get_doc \
			-name make_deposit \
			-type received]

		# Get Provider magic key to determine the make_deposit response.
		if {[catch {
			set provider_elements [$make_deposit_doc getElementsByTagName Provider]
			set provider          [[lindex $provider_elements 0] text]
		} msg]} {
			set err "Processing request failed: unable to get Provider element from request: $msg"
			core::log::xwrite \
				-msg     $err \
				-colour red

			error $err
		}

		# Get pmt_id (MerchantTransactionId element), which forms part of the response.
		if {[catch {
			set pmt_id_elements [$make_deposit_doc getElementsByTagName MerchantTransactionId]
			set pmt_id          [[lindex $pmt_id_elements 0] text]
		} msg]} {
			set err "Processing request failed: unable to get MerchantTransactionId element from request: $msg"
			core::log::xwrite \
				-msg     $err \
				-colour red

			error $err
		}

		core::log::xwrite -msg {Extracted provider=$provider} -colour yellow
		core::log::xwrite -msg {Extracted pmt_id=$pmt_id} -colour yellow

		if {[dict exists $MAGIC_DATA provider $provider]} {
			# Use the magic response.
			set status   [dict get $MAGIC_DATA provider $provider status]
		} else {
			# Use the default.
			core::log::write INFO {Unable to match Provider=$provider to a magic value, using defaults.}
			set status   [dict get $MAGIC_DATA provider default status]
		}

		# PLACEHOLDER is used in lieu of having accurate test data.
		tpBindString transactionId            PLACEHOLDER
		tpBindString voucherUrl               PLACEHOLDER
		tpBindString barcodeImageUrl          PLACEHOLDER
		tpBindString barcodeDigits            PLACEHOLDER
		tpBindString merchantTransactionId    $pmt_id
		tpBindString message                  PLACEHOLDER
		tpBindString uniqueMessageId          PLACEHOLDER
		tpBindString status                   $status

		set response [tpStringPlay -tostring [dict get $MAGIC_DATA templates make_deposit]]
		core::log::xwrite \
			-msg {Responding with: $response} \
			-colour yellow

		# Store response for the core::socket::req_info call and the request to the listener.
		dict set RESPONSE body          $response
		dict set RESPONSE pmt_id        $pmt_id

		# Return the faked core::socket::send_req result.
		set req_id "make_deposit"
		set status "OK"
		set complete 1

		return [list $req_id $status $complete]
	}

#
# _prepare_response_make_ipn_request
#
# Processes an IPN Report request (made by the Dineromail listener) and
# prepares a Report response.
#
# The response magic depends on the previous make_deposit request and not on
# the request sent in the arguments here.
#
core::args::register \
	-proc_name {core::harness::payment::DMBC::_prepare_response_make_ipn_request} \
	-desc      {Process an IPN Report request and prepare the response} \
	-args      [list \
		$::core::harness::payment::DMBC::CORE_DEF(request) \
	] \
	-body {
		variable MAGIC_DATA
		variable RESPONSE

		core::log::xwrite \
			-msg     "core::harness::payment::DMBC::_prepare_response_make_ipn_request: Processing request: $ARGS(-request)" \
			-colour  yellow

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		# Get ID of payment.
		if {[catch {
			set id [core::xml::extract_data \
				-node $doc \
				-xpath "//ID"]
		} msg]} {
			set err "Processing request failed: unable to get ID element from request: $msg"
			core::log::xwrite \
				-msg     $err \
				-colour red

			error $err
		}

		core::log::xwrite -msg {Extracted ID=$id} -colour yellow

		# Get the payment details.
		set get_pmt_details_result [core::payment::DMBC::get_pmt_details -pmt_id $id]
		lassign $get_pmt_details_result status payment

		core::log::xwrite -msg {payment: $payment} -colour yellow

		set payment_amount [dict get $payment amount]

		if {[dict exists $MAGIC_DATA amount $payment_amount]} {
			# Use the magic response.
			set estadoreporte [dict get $MAGIC_DATA amount $payment_amount estadoreporte]
			set estado        [dict get $MAGIC_DATA amount $payment_amount estado]
		} else {
			# Use the default response.
			core::log::xwrite -msg {Unable to match Amount=$payment_amount to a magic value, using defaults.} -colour yellow
			set estadoreporte [dict get $MAGIC_DATA amount default estadoreporte]
			set estado        [dict get $MAGIC_DATA amount default estado]
		}


		# Now we need to look up the codes.
		set estadoreporte_code [core::payment::DMBC::response_code \
			-type   ESTADOREPORTE \
			-value  $estadoreporte \
			-dflt   "-1"]

		set estado_code [core::payment::DMBC::response_code \
			-type   ESTADO \
			-value  $estado \
			-dflt   "-1"]

		# PLACEHOLDER is used in lieu of having accurate test data.
		tpBindString estadoreporte      $estadoreporte_code
		tpBindString id                 $id
		tpBindString fecha              PLACEHOLDER
		tpBindString estado             $estado_code
		tpBindString numtransaccion     PLACEHOLDER
		tpBindString email              PLACEHOLDER
		tpBindString direccion          PLACEHOLDER
		tpBindString comentario         PLACEHOLDER
		tpBindString nombre             PLACEHOLDER
		tpBindString telefono           PLACEHOLDER
		tpBindString tipodoc            PLACEHOLDER
		tpBindString numerodoc          PLACEHOLDER
		tpBindString monto              PLACEHOLDER
		tpBindString montoneto          PLACEHOLDER
		tpBindString metodopago         PLACEHOLDER
		tpBindString mediopago          PLACEHOLDER
		tpBindString cuotas             PLACEHOLDER
		tpBindString descripcion        PLACEHOLDER
		tpBindString moneda             PLACEHOLDER
		tpBindString preciounitario     PLACEHOLDER
		tpBindString cantidad           PLACEHOLDER
		tpBindString tipodoc            PLACEHOLDER
		tpBindString numerodoc          PLACEHOLDER

		set response [tpStringPlay -tostring [dict get $MAGIC_DATA templates make_ipn_request]]
		core::log::xwrite \
			-msg {Responding with: $response} \
			-colour yellow

		# Store response settings for the core::socket::req_info call.
		dict set RESPONSE body $response

		# Return the faked core::socket::send_req result.
		set req_id "make_ipn_request"
		set status "OK"
		set complete 1

		return [list $req_id $status $complete]
	}

#
# get_response_data
#
# Simply returns a property of the prepared response.
# -key body : Returns the full response body.
# -key pmt_id : Returns just the payment ID associated with the response.
#
core::args::register \
	-proc_name {core::harness::payment::DMBC::get_response_data} \
	-args [list \
		[list -arg -key -mand 0 -check {ENUM -args {body pmt_id}} -default body -desc {The request key}] \
	] \
	-desc {Gets a property of the prepared response} \
	-body {
		variable RESPONSE
		return [dict get $RESPONSE $ARGS(-key)]
	}

core::args::register \
	-proc_name {core::harness::payment::DMBC::send_listener_notification_request} \
	-desc      {Sends a notification request to the dineromail listener, mimicking what dineromail would send to OpenBet.} \
	-body {
		variable CFG

		set fn "core::harness::payment::DMBC::send_listener_notification_request"
		core::log::xwrite -msg {$fn: Making request to the dineromail listener} -colour yellow

		# Retrieve the ID from the last processed response.
		set pmt_id [core::harness::payment::DMBC::get_response_data -key pmt_id]

		# Figure out where we need to connect to for this URL.
		if {[catch {
			set split_url [core::socket::split_url -url $CFG(dmbc_harness_listener_url)]
		} msg]} {
			# Cannot decode the URL.
			error "$fn: Badly formatted url: $msg"
		}

		lassign $split_url \
			api_scheme \
			api_host \
			api_port \
			url_path

		set form_args [list Notificacion [subst {
			<notificacion>
				<tiponotificacion>1</tiponotificacion>
				<operaciones>
					<operacion>
						<tipo>1</tipo>
						<id>$pmt_id</id>
					</operacion>
				</operaciones>
			</notificacion>
		}]]

		# Construct the raw HTTP request.
		set format_http_req_args [list \
			-url       $CFG(dmbc_harness_listener_url) \
			-method    POST \
			-host      $api_host \
			-form_args $form_args]

		if {[catch {
			set http_req [core::socket::format_http_req {*}$format_http_req_args]
		} msg]} {
			error "$fn: Unable to build request: $msg"
		}

		# Send the request to listener.
		core::log::xwrite \
			-msg "Sending to the dineromail listener: $form_args" \
			-colour yellow

		if {[catch {
			set send_req_result [core::socket::send_req \
				-req            $http_req \
				-host           $api_host \
				-port           $api_port \
				-tls            1 \
				-is_http        1 \
				-conn_timeout   1000 \
				-req_timeout    1000]
		} msg]} {
			# We can't be sure if anything reached the server or not.
			error "$fn: Request to listener failed: $msg"
		}

		lassign $send_req_result req_id status complete
		core::log::xwrite \
			-msg {Sending to the listener returned, req_id=$req_id status=$status complete=$complete} \
			-colour yellow

		return 1
	}

