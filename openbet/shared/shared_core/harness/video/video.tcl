# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
#  Harness for core::video
#
set pkg_version 1.0
package provide core::harness::video $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::check    1.0
package require core::stub    1.0

core::args::register_ns \
	-namespace core::harness::video \
	-version   $pkg_version \
	-dependent [list \
		core::log \
		core::args \
		core::check \
		core::stub]

namespace eval core::harness::video {
	variable CFG


}

core::args::register \
	-proc_name core::harness::video::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg VIDEO_HARNESS_ENABLED -default 0 -desc {Enable the harness for videostream functionality}] \
	] \
	-body {
		if {!$ARGS(-enabled)} {
			core::log::write ERROR {core::harness::video::init : ERROR : Trying to load Harness for core::video, event if VIDEO_HARNESS_ENABLED is set to 0.}
			return
		}
		core::log::write INFO {Loading Harness for core::video}

		core::stub::init

		core::log::xwrite -msg {Harness available and enabled} -colour yellow
		core::stub::define_procs -proc_definition \
			[list \
				video::cobain makeSOAPRequest \
				video::perform _sendPerformVerification
			]

		core::stub::set_override \
			-proc_name video::cobain::makeSOAPRequest \
			-return_data [list 1 {<?xml version="1.0" encoding="utf-8"?>
						 <soap:Envelope
						 		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
								xmlns:xsd="http://www.w3.org/2001/XMLSchema"
								xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
						   <soap:Body>
							 <GetSARaceProgram xmlns="http://cobainltd.com/services/">
								<RTMPLink>RTMPLink</RTMPLink>
								<StreamName>StreamName</StreamName>
								<ErrorCode></ErrorCode>
								<ErrorMessage></ErrorMessage>
								<PlayerURL>PlayerURL</PlayerURL>
								<Token>Token</Token>
							 </GetSARaceProgram>
						   </soap:Body>
						 </soap:Envelope>}]

		core::stub::set_override \
			-proc_name video::perform::_sendPerformVerification \
			-return_data [list 1 success]

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				http geturl \
				http ncode \
				http data \
				http cleanup \
			]

		core::stub::set_override \
			-proc_name {http::geturl} \
			-scope     proc \
			-scope_key {video::perform::doStreamRequest} \
			-return_data {DUMMY_TOKEN}

		core::stub::set_override \
			-proc_name {http::ncode} \
			-scope     proc \
			-scope_key {video::perform::doStreamRequest} \
			-return_data {200}

		core::stub::set_override \
			-proc_name {http::cleanup} \
			-scope     proc \
			-scope_key {video::perform::doStreamRequest} \
			-use_body_return 1 \
			-body {
				return
			}

		core::stub::set_override \
			-proc_name {http::data} \
			-scope     proc \
			-scope_key {video::perform::doStreamRequest} \
			-return_data {
						<?xml version="1.0" ?>
						<events>
							<event id="443060" contentTypeId="3" startDateTime="2013-11-01T15:00:00+0000" endDateTime="2013-11-01T16:00:00+0000" description="Alinghi vs BMW Oracle" chargeable="false" location="" blockedCountryCodes="">
								<identifiers/>
								<localisedDescriptions/>
							</event>
							<event id="443160" contentTypeId="17" startDateTime="2013-11-01T09:20:00+0000" endDateTime="2013-11-01T09:35:00+0000" description="VOLLEYBALL: Allianz Volley Stattgart v VfB SuhlNot available in Germany and USA" chargeable="false" location="" blockedCountryCodes="DE VI US UM">
								<identifiers>
									<identifier type="override" id="12345" />
								</identifiers>
								<localisedDescriptions>
									<localisedDescription locale="en_GB" description="VOLLEYBALL: Allianz Stuttgart v VfB SuhlNot available in Germany and USA" />
									<localisedDescription locale="fr_FR" description="VOLLEYBALL: Décharge Stuttgart v VfB SuhlNot d'Allianz disponible en Allemagne et aux Etats-Unis" />
								</localisedDescriptions>
							</event>
						</events>
			}
	}
