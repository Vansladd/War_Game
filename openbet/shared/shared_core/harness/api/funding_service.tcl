# $Header$
# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# funding service harness
#
set pkg_version 1.0
package provide core::harness::api::funding_service $pkg_version

# Dependencies
package require core::api::funding_service 1.0
package require core::log                  1.0
package require core::args                 1.0
package require core::check                1.0
package require core::stub                 1.0
package require core::xml                  1.0
package require core::date                 1.0

load libOT_Tcl.so
load libOT_Template.so

core::args::register_ns \
	-namespace core::harness::api::funding_service \
	-version   $pkg_version \
	-dependent [list \
		core::api:funding_service \
		core::log \
		core::args \
		core::check \
		core::stub \
		core::xml \
	]

namespace eval core::harness::api::funding_service  {
	variable CFG
	variable CORE_DEF
	variable HARNESS_DATA

	set CORE_DEF(request) [list -arg -request -mand 1 -check ASCII -desc {Request data}]

	dict set HARNESS_DATA GETBALANCE template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<getBalanceResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<funds>
						<ns2:fund>
							<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
							<ns2:externalRestrictionRef id="##TP_fund.restriction.id_1##" provider="##TP_fund.restriction.provider_1##"/>
							<ns2:type>##TP_fund.type_1##</ns2:type>
							<ns2:status>##TP_fund.status_1##</ns2:status>
							<ns2:createDate>##TP_fund.createDate_1##</ns2:createDate>
							<ns2:startDate>##TP_fund.startDate_1##</ns2:startDate>
							<ns2:expiryDate>##TP_fund.expiryDate_1##</ns2:expiryDate>
							<ns2:activationStatus>##TP_fund.activation_status_1##</ns2:activationStatus>
							<ns2:fundItems>
								<ns2:fundItem>
									<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
									<ns2:balance>##TP_fund_1.item_1.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_1.item_1.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
								<ns2:fundItem>
									<ns2:type>##TP_fund_1.item_2.type##</ns2:type>
									<ns2:balance>##TP_fund_1.item_2.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_1.item_2.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
								<ns2:fundItem>
									<ns2:type>##TP_fund_1.item_3.type##</ns2:type>
									<ns2:balance>##TP_fund_1.item_3.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_1.item_3.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
							</ns2:fundItems>
						</ns2:fund>
						<ns2:fund>
							<ns2:externalFundRef id="##TP_fund.id_2##" provider="##TP_fund.provider_2##"/>
							<ns2:externalRestrictionRef id="##TP_fund.restriction.id_2##" provider="##TP_fund.restriction.provider_2##"/>
							<ns2:type>##TP_fund.type_2##</ns2:type>
							<ns2:status>##TP_fund.status_2##</ns2:status>
							<ns2:createDate>##TP_fund.createDate_1##</ns2:createDate>
							<ns2:startDate>##TP_fund.startDate_2##</ns2:startDate>
							<ns2:expiryDate>##TP_fund.expiryDate_2##</ns2:expiryDate>
							<ns2:activationStatus>##TP_fund.activation_status_2##</ns2:activationStatus>
							<ns2:fundItems>
								<ns2:fundItem>
									<ns2:type>##TP_fund_2.item_1.type##</ns2:type>
									<ns2:balance>##TP_fund_2.item_1.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_2.item_1.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
								<ns2:fundItem>
									<ns2:type>##TP_fund_2.item_2.type##</ns2:type>
									<ns2:balance>##TP_fund_2.item_2.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_2.item_2.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
								<ns2:fundItem>
									<ns2:type>##TP_fund_2.item_3.type##</ns2:type>
									<ns2:balance>##TP_fund_2.item_3.balance##</ns2:balance>
									<ns2:initialBalance>##TP_fund_2.item_3.initial_balance##</ns2:initialBalance>
								</ns2:fundItem>
							</ns2:fundItems>
						</ns2:fund>
					</funds>
				</getBalanceResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETBALANCE template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<getBalanceResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</getBalanceResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CREATEFUND template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<createFundResponse xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
						xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</createFundResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CREATEFUND template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<createFundResponse xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
						xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<status code="##TP_status.code##" />
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fund>
						<ns2:externalFundRef id="##TP_fund.id##" provider="##TP_fund.provider##"/>
						<ns2:externalRestrictionRef id="##TP_fund.restriction.id##" provider="##TP_fund.restriction.provider##"/>
						<ns2:type>##TP_fund.type##</ns2:type>
						<ns2:status>##TP_fund.status##</ns2:status>
						<ns2:createDate>##TP_fund.createDate##</ns2:createDate>
						<ns2:startDate>##TP_fund.startDate##</ns2:startDate>
						<ns2:expiryDate>##TP_fund.expiryDate##</ns2:expiryDate>
						<ns2:fundItems>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_1.type##</ns2:type>
								<ns2:balance>##TP_fund.item_1.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_1.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_2.type##</ns2:type>
								<ns2:balance>##TP_fund.item_2.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_2.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
							<ns2:fundItem>
								<ns2:type>HELD</ns2:type>
								<ns2:balance>0.00</ns2:balance>
								<ns2:initialBalance>0.00</ns2:initialBalance>
							</ns2:fundItem>
						</ns2:fundItems>
					</fund>
				</createFundResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CREATERESTRICTION template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<createRestrictionResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<restriction>
						<ns2:externalRestrictionRef id="##TP_restriction.id##" provider="##TP_restriction.provider##"/>
						<ns2:status>##TP_restriction.status##</ns2:status>
					</restriction>
				</createRestrictionResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CREATERESTRICTION template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<createRestrictionResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</createRestrictionResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CONFIRMFUNDING template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<confirmFundingResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status_1##">
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</confirmFundingResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CONFIRMFUNDING template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
					<ns2:serviceError>
						<ns2:code>##TP_service_error.code##</ns2:code>
						<ns2:message>##TP_service_error.message##</ns2:message>
					</ns2:serviceError>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<confirmFundingResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</confirmFundingResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<reserveMultipleFundingResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status##">
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_2.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_2.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_3.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_3.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</reserveMultipleFundingResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING template success_multi {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<reserveMultipleFundingResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status##">
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_2.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_2.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_3.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_3.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
					<fundingTransaction id="##TP_fundTrans.id_2##" amount="##TP_fundTrans.amount_2##" requestedAmount="##TP_fundTrans.reqAmount_2##" status="##TP_fundTrans.status##">
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_2##" provider="##TP_fund.provider_2##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_2.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_2.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_2.item_2.type##</ns2:type>
										<ns2:amount>##TP_fund_2.item_2.amount##</ns2:amount>
									</ns2:transactionFundItem>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_2.item_3.type##</ns2:type>
										<ns2:amount>##TP_fund_2.item_3.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</reserveMultipleFundingResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETFUNDHISTORY template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<getFundHistoryResponse 
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns3="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<fund>
						<ns3:externalFundRef id="##TP_fund.id##" provider="##TP_fund.provider##"/>
					</fund>
					<transactions>
						<ns3:transaction id="##TP_fundTrans_1.id##" amount="##TP_fundTrans_1.amount##" requestedAmount="##TP_fundTrans_1.reqAmount_1##" status="##TP_fundTrans_1.status##">
							<ns3:transactionFunds>
								<ns3:transactionFund>
									<ns3:externalFundRef id="##TP_fundTrans_1.fund_1.id##" provider="##TP_fundTrans_1.fund_1.provider##"/>
									<ns3:transactionFundItems>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_1.item_1.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_1.item_1.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_1.item_2.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_1.item_2.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_1.item_3.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_1.item_3.amount##</ns3:amount>
										</ns3:transactionFundItem>
									</ns3:transactionFundItems>
								</ns3:transactionFund>
								<ns3:transactionFund>
									<ns3:externalFundRef id="##TP_fundTrans_1.fund_2.id##" provider="##TP_fundTrans_1.fund_2.provider##"/>
									<ns3:transactionFundItems>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_2.item_1.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_2.item_1.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_2.item_2.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_2.item_2.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_1.fund_2.item_3.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_1.fund_2.item_3.amount##</ns3:amount>
										</ns3:transactionFundItem>
									</ns3:transactionFundItems>
								</ns3:transactionFund>
							</ns3:transactionFunds>
							<ns3:transactionDate>##TP_fundTrans_1.date##</ns3:transactionDate>
							<ns3:fundingActivity>
								<ns3:externalActivityRef id="##TP_fundTrans_1.activity.id##" provider="##TP_fundTrans_1.activity.provider##" />
								<ns3:type>##TP_fundTrans_1.activity.type##</ns3:type>
								<ns3:fundingOperations>
									<ns3:fundingOperation>
										<ns3:externalOperationRef id="##TP_fundTrans_1.activity.op_1.id##" provider="##TP_fundTrans_1.activity.op_1.provider##" />
										<ns3:externalOperationRef id="##TP_fundTrans_1.activity.op_2.id##" provider="##TP_fundTrans_1.activity.op_2.provider##" />
									</ns3:fundingOperation>
								</ns3:fundingOperations>
							</ns3:fundingActivity>
						</ns3:transaction>
						<ns3:transaction id="##TP_fundTrans_2.id##" amount="##TP_fundTrans_2.amount##" requestedAmount="##TP_fundTrans_2.reqAmount_1##" status="##TP_fundTrans_2.status##">
							<ns3:transactionFunds>
								<ns3:transactionFund>
									<ns3:externalFundRef id="##TP_fundTrans_2.fund_1.id##" provider="##TP_fundTrans_2.fund_1.provider##"/>
									<ns3:transactionFundItems>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_1.item_1.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_1.item_1.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_1.item_2.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_1.item_2.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_1.item_3.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_1.item_3.amount##</ns3:amount>
										</ns3:transactionFundItem>
									</ns3:transactionFundItems>
								</ns3:transactionFund>
								<ns3:transactionFund>
									<ns3:externalFundRef id="##TP_fundTrans_2.fund_2.id##" provider="##TP_fundTrans_2.fund_2.provider##"/>
									<ns3:transactionFundItems>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_2.item_1.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_2.item_1.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_2.item_2.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_2.item_2.amount##</ns3:amount>
										</ns3:transactionFundItem>
										<ns3:transactionFundItem>
											<ns3:type>##TP_fundTrans_2.fund_2.item_3.type##</ns3:type>
											<ns3:amount>##TP_fundTrans_2.fund_2.item_3.amount##</ns3:amount>
										</ns3:transactionFundItem>
									</ns3:transactionFundItems>
								</ns3:transactionFund>
							</ns3:transactionFunds>
							<ns3:transactionDate>##TP_fundTrans_2.date##</ns3:transactionDate>
							<ns3:fundingActivity>
								<ns3:externalActivityRef id="##TP_fundTrans_2.activity.id##" provider="##TP_fundTrans_2.activity.provider##" />
								<ns3:type>##TP_fundTrans_2.activity.type##</ns3:type>
								<ns3:fundingOperations>
									<ns3:fundingOperation>
										<ns3:externalOperationRef id="##TP_fundTrans_2.activity.op_1.id##" provider="##TP_fundTrans_2.activity.op_1.provider##" />
										<ns3:externalOperationRef id="##TP_fundTrans_2.activity.op_2.id##" provider="##TP_fundTrans_2.activity.op_2.provider##" />
									</ns3:fundingOperation>
								</ns3:fundingOperations>
							</ns3:fundingActivity>
						</ns3:transaction>
					</transactions>
				</getFundHistoryResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CANCELFUNDING template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<cancelFundingResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
						xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status_1##">
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</cancelFundingResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CANCELRESTRICTION template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<cancelRestrictionResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
						xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<fundingTransactions>
						<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status_1##">
							<ns2:transactionFunds>
								<ns2:transactionFund>
									<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
									<ns2:transactionFundItems>
										<ns2:transactionFundItem>
											<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
											<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
										</ns2:transactionFundItem>
										<ns2:transactionFundItem>
											<ns2:type>##TP_fund_1.item_2.type##</ns2:type>
											<ns2:amount>##TP_fund_1.item_2.amount##</ns2:amount>
										</ns2:transactionFundItem>
									</ns2:transactionFundItems>
								</ns2:transactionFund>
							</ns2:transactionFunds>
						</fundingTransaction>
					</fundingTransactions>
				</cancelRestrictionResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA CANCELMULTIPLERESTRICTION template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<cancelMultipleRestrictionResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
						xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<restrictions>
						<ns2:restriction>
							<ns2:externalRestrictionRef id="##TP_restriction_1.id##" provider="##TP_restriction_1.provider##" />
							<ns2:status>##TP_restriction_1.status##</ns2:status>
						</ns2:restriction>
						<ns2:restriction>
							<ns2:externalRestrictionRef id="##TP_restriction_2.id##" provider="##TP_restriction_2.provider##" />
							<ns2:status>##TP_restriction_2.status##</ns2:status>
						</ns2:restriction>
					</restrictions>
				</cancelMultipleRestrictionResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}
	

	dict set HARNESS_DATA CANCELACTIVITY template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<cancelActivityResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
						xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status_1##">
  						<ns2:externalActivityRef id="##TP_activityRef##" provider="G" />
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem>
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</cancelActivityResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETFUNDACCOUNTHISTORY template success {
		<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
			<soap:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soap:Header>
			<soap:Body>
				<getFundAccountHistoryResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/fundingTypes" xmlns:ns2="http://schema.products.sportsbook.openbet.com/promoCommonTypes" xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<transactions>
						<ns3:transaction id="##TP_transaction_1.id##" amount="##TP_transaction_1.amount##" requestedAmount="##TP_transaction_1.requested_amount##" status="##TP_transaction_1.status##">
							<ns3:wallets>
								<ns3:wallet>
									<ns3:walletType>##TP_walletType_1##</ns3:walletType>
									<ns3:totalBalance>##TP_balance_1##</ns3:totalBalance>
								</ns3:wallet>
								<ns3:wallet>
									<ns3:walletType>##TP_walletType_2##</ns3:walletType>
									<ns3:totalBalance>##TP_balance_2##</ns3:totalBalance>
								</ns3:wallet>
								<ns3:wallet>
									<ns3:walletType>##TP_walletType_3##</ns3:walletType>
									<ns3:totalBalance>##TP_balance_3##</ns3:totalBalance>
								</ns3:wallet>
								<ns3:wallet>
									<ns3:walletType>##TP_walletType_4##</ns3:walletType>
									<ns3:totalBalance>##TP_balance_4##</ns3:totalBalance>
								</ns3:wallet>
								<ns3:wallet>
									<ns3:walletType>##TP_walletType_5##</ns3:walletType>
									<ns3:totalBalance>##TP_balance_5##</ns3:totalBalance>
								</ns3:wallet>
							</ns3:wallets>
							<ns3:transactionFunds>
								<ns3:transactionFund>
									<ns3:externalFundRef id="##TP_fund_1.id##" provider="##TP_fund_1.provider##"/>
									<ns3:transactionFundItems>
										<ns3:transactionFundItem forfeited="false">
											<ns3:type>##TP_fund_1.item_1.type##</ns3:type>
											<ns3:amount>##TP_fund_1.item_1.amount##</ns3:amount>
										</ns3:transactionFundItem>
									</ns3:transactionFundItems>
								</ns3:transactionFund>
							</ns3:transactionFunds>
							<ns3:transactionType>##TP_transaction_1.type##</ns3:transactionType>
							<ns3:creationDate>##TP_transaction_1.date##</ns3:creationDate>
							<ns3:transactionDate>##TP_transaction_1.date##</ns3:transactionDate>
							<ns3:fundingActivity>
								<ns3:externalActivityRef id="##TP_activity_1.id##" provider="##TP_provider##"/>
								<ns3:type>##TP_activity_1.type##</ns3:type>
								<ns3:fundingOperations>
									<ns3:externalOperationRef id="##TP_activity_1.operation_id##" provider="##TP_activity_1.operation_provider##" />
	                                <ns3:operationType>##TP_activity_1.operation_type##</ns3:operationType>
	                                <ns3:status>##TP_activity_1.operation_status##</ns3:status>
								</ns3:fundingOperations>
							</ns3:fundingActivity>
							<ns3:description>##TP_description##</ns3:description>
						</ns3:transaction>
					</transactions>
				</getFundAccountHistoryResponse>
			</soap:Body>
		</soap:Envelope>
	}

	dict set HARNESS_DATA GETFUNDACCOUNTSUMMARY template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_service_error.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<getFundAccountSummaryResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</getFundAccountSummaryResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA GETFUNDACCOUNTSUMMARY template success {
		<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
			<soap:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soap:Header>
			<soap:Body>
				<getFundAccountSummaryResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/fundingTypes" xmlns:ns2="http://schema.products.sportsbook.openbet.com/promoCommonTypes" xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<summaries>
						<ns3:summary>
							<ns3:transactionType>##TP_summary_1.transaction_type##</ns3:transactionType>
							<ns3:operationType>##TP_summary_1.operation_type##</ns3:operationType>
							<ns3:amount>##TP_summary_1.amount##</ns3:amount>
							<ns3:transactionCount>##TP_summary_1.count##</ns3:transactionCount>
							<ns3:fromDate>##TP_summary_1.from_date##</ns3:fromDate>
							<ns3:toDate>##TP_summary_1.to_date##</ns3:toDate>
							<ns3:fromTime>##TP_summary_1.from_time##</ns3:fromTime>
							<ns3:toTime>##TP_summary_1.to_time##</ns3:toTime>
						</ns3:summary>
						<ns3:summary>
							<ns3:transactionType>##TP_summary_2.transaction_type##</ns3:transactionType>
							<ns3:operationType>##TP_summary_2.operation_type##</ns3:operationType>
							<ns3:amount>##TP_summary_2.amount##</ns3:amount>
							<ns3:transactionCount>##TP_summary_2.count##</ns3:transactionCount>
							<ns3:fromDate>##TP_summary_2.from_date##</ns3:fromDate>
							<ns3:toDate>##TP_summary_2.to_date##</ns3:toDate>
							<ns3:fromTime>##TP_summary_2.from_time##</ns3:fromTime>
							<ns3:toTime>##TP_summary_2.to_time##</ns3:toTime>
						</ns3:summary>
					</summaries>
				</getFundAccountSummaryResponse>
			</soap:Body>
		</soap:Envelope>
	}


	dict set HARNESS_DATA MAKEFUNDPAYMENT template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<makeFundPaymentResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
									xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
									xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##"/>
					<wallets>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_1##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_1##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_1##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_1##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_1##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_2##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_2##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_2##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_2##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_2##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_3##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_3##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_3##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_3##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_3##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_4##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_4##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_4##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_4##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_4##</ns2:closedItemsCount>
						</ns2:wallet>
						<ns2:wallet>
							<ns2:walletType>##TP_walletType_5##</ns2:walletType>
							<ns2:totalBalance>##TP_balance_5##</ns2:totalBalance>
							<ns2:openItemsCount>##TP_open_fund_5##</ns2:openItemsCount>
							<ns2:totalRedeemed>##TP_redeemed_5##</ns2:totalRedeemed>
							<ns2:closedItemsCount>##TP_close_fund_5##</ns2:closedItemsCount>
						</ns2:wallet>
					</wallets>
					<fundingTransaction id="##TP_fundTrans.id_1##" amount="##TP_fundTrans.amount_1##" requestedAmount="##TP_fundTrans.reqAmount_1##" status="##TP_fundTrans.status##">
						<ns2:externalActivityRef id="##TP_activity.id_1##" provider="##TP_activity.provider_1##"/>
						<ns2:transactionFunds>
							<ns2:transactionFund>
								<ns2:externalFundRef id="##TP_fund.id_1##" provider="##TP_fund.provider_1##"/>
								<ns2:transactionFundItems>
									<ns2:transactionFundItem forfeited="##TP_fund.forfeited_1##">
										<ns2:type>##TP_fund_1.item_1.type##</ns2:type>
										<ns2:amount>##TP_fund_1.item_1.amount##</ns2:amount>
									</ns2:transactionFundItem>
								</ns2:transactionFundItems>
							</ns2:transactionFund>
						</ns2:transactionFunds>
					</fundingTransaction>
				</makeFundPaymentResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA ACTIVATEFUND template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<activateFundResponse xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
						xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<status code="##TP_status.code##" />
					<fund>
						<ns2:externalFundRef id="##TP_fund.id##" provider="##TP_fund.provider##"/>
						<ns2:externalRestrictionRef id="##TP_fund.restriction.id##" provider="##TP_fund.restriction.provider##"/>
						<ns2:type>##TP_fund.type##</ns2:type>
						<ns2:status>##TP_fund.status##</ns2:status>
						<ns2:createDate>##TP_fund.createDate##</ns2:createDate>
						<ns2:startDate>##TP_fund.startDate##</ns2:startDate>
						<ns2:expiryDate>##TP_fund.expiryDate##</ns2:expiryDate>
						<ns2:activationStatus>ACTIVE</ns2:activationStatus>
						<ns2:fundItems>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_1.type##</ns2:type>
								<ns2:balance>##TP_fund.item_1.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_1.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_2.type##</ns2:type>
								<ns2:balance>##TP_fund.item_2.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_2.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
						</ns2:fundItems>
					</fund>
				</activateFundResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}


	dict set HARNESS_DATA UPDATEFUND template success {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader" xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader">
					<ns2:status>##TP_status.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<updateFundResponse xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
						xmlns="http://schema.products.sportsbook.openbet.com/fundingService"
						xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes">
					<status code="##TP_status.code##" />
					<fund id="##TP_fund.id##">
						<ns2:externalFundRef id="##TP_fund.reference.id##" provider="##TP_fund.provider##"/>
						<ns2:externalRestrictionRef id="##TP_fund.restriction.id##" provider="##TP_fund.restriction.provider##"/>
						<ns2:type>##TP_fund.type##</ns2:type>
						<ns2:status>##TP_fund.status##</ns2:status>
						<ns2:createDate>##TP_fund.createDate##</ns2:createDate>
						<ns2:startDate>##TP_fund.startDate##</ns2:startDate>
						<ns2:expiryDate>##TP_fund.expiryDate##</ns2:expiryDate>
						<ns2:activationStatus>ACTIVE</ns2:activationStatus>
						<ns2:fundItems>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_1.type##</ns2:type>
								<ns2:balance>##TP_fund.item_1.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_1.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
							<ns2:fundItem>
								<ns2:type>##TP_fund.item_2.type##</ns2:type>
								<ns2:balance>##TP_fund.item_2.balance##</ns2:balance>
								<ns2:initialBalance>##TP_fund.item_2.initial_balance##</ns2:initialBalance>
							</ns2:fundItem>
						</ns2:fundItems>
					</fund>
				</updateFundResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}

	dict set HARNESS_DATA UPDATEFUND template failed {
		<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
			<soapenv:Header>
				<ns2:responseHeader xmlns="http://schema.core.sportsbook.openbet.com/requestHeader"
					xmlns:ns2="http://schema.core.sportsbook.openbet.com/responseHeader" >
					<ns2:status>##TP_service_error.code##</ns2:status>
				</ns2:responseHeader>
			</soapenv:Header>
			<soapenv:Body>
				<updateFundResponse xmlns:ns3="http://schema.products.sportsbook.openbet.com/promoCommonTypes"
					xmlns:ns2="http://schema.products.sportsbook.openbet.com/fundingTypes"
					xmlns="http://schema.products.sportsbook.openbet.com/fundingService">
					<status code="##TP_status.code##" subcode="##TP_status.subcode##" >
						<ns3:specification>##TP_status.specification##</ns3:specification>
					</status>
				</updateFundResponse>
			</soapenv:Body>
		</soapenv:Envelope>
	}


	# Below are the response data definitions keyed by the currency code
	# e.g.
	# dict set HARNESS_DATA request data wallettype template {response values}

	dict set HARNESS_DATA GETBALANCE data USD failed  {status.code REQUEST_VALIDATION  service_error.code {REQUEST_VALIDATION}  service_error.message {Internal Error}  status.subcode REQUEST_VALIDATION status.specification {Violations (1): Account not valid.}}

	dict set HARNESS_DATA GETBALANCE data EUR success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {154.00} open_fund_1 2 redeemed_1 {10.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {15.00} open_fund_2 4 redeemed_2 {2.00} close_fund_2 2 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fund.id_1 {123123} fund.provider_1 {G} fund.restriction.id_1 {666} fund.restriction.provider_1 {G} fund.type_1 {WR} \
		fund.status_1 {OPEN} fund.activation_status_1 {ACTIVE} fund.createDate_1 {2014-01-22T12:33:11} fund.startDate_1 {2014-01-22T12:33:11} fund.expiryDate_1 {2014-12-22T12:33:11} \
		fund_1.item_1.type {BONUS} fund_1.item_1.balance {11.00} fund_1.item_1.initial_balance {20.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.balance {0.00} fund_1.item_2.initial_balance {13.00} \
		fund_1.item_3.type {HELD} fund_1.item_3.balance {13.00} fund_1.item_3.initial_balance {13.00} \
		fund.id_2 {321321} fund.provider_2 {G} fund.restriction.id_2 {999} fund.restriction.provider_2 {G} fund.type_2 {WR}\
		fund.status_2 {OPEN} fund.activation_status_2 {ACTIVE} fund.createDate_2 {2014-01-22T12:33:11} fund.startDate_2 {2014-01-22T12:33:11} fund.expiryDate_2 {2014-06-22T12:33:11} \
		fund_2.item_1.type {BONUS} fund_2.item_1.balance {0.00} fund_2.item_1.initial_balance {12.00} \
		fund_2.item_2.type {LOCKEDIN} fund_2.item_2.balance {3.00} fund_2.item_2.initial_balance {11.00} \
		fund_2.item_3.type {HELD} fund_2.item_3.balance {67.00} fund_2.item_3.initial_balance {110.00} \
	]

	dict set HARNESS_DATA GETBALANCE data GBP success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {60.00} open_fund_1 2 redeemed_1 {55.00} close_fund_1 42 \
		walletType_2 {STANDARD} balance_2 {35.00} open_fund_2 4 redeemed_2 {16.00} close_fund_2 21 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fund.id_1 {123123} fund.provider_1 {G} fund.restriction.id_1 {666} fund.restriction.provider_1 {G} fund.type_1 {WR} \
		fund.status_1 {OPEN} fund.activation_status_1 {ACTIVE} fund.createDate_1 {2014-01-22T12:33:11} fund.startDate_1 {2014-01-22T12:33:11} fund.expiryDate_1 {2014-12-22T12:33:11} \
		fund_1.item_1.type {BONUS} fund_1.item_1.balance {10.00} fund_1.item_1.initial_balance {100.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.balance {20.00} fund_1.item_2.initial_balance {10.00} \
		fund_1.item_3.type {HELD} fund_1.item_3.balance {0.00} fund_1.item_3.initial_balance {0.00} \
		fund.id_2 {321321} fund.provider_2 {G} fund.restriction.id_2 {999} fund.restriction.provider_2 {G} fund.type_2 {WR} \
		fund.status_2 {CLOSED} fund.activation_status_2 {ACTIVE} fund.createDate_2 {2014-01-22T12:33:11} fund.startDate_2 {2014-01-22T12:33:11} fund.expiryDate_2 {2014-06-22T12:33:11} \
		fund_2.item_1.type {BONUS} fund_2.item_1.balance {50.00} fund_2.item_1.initial_balance {50.00} \
		fund_2.item_2.type {LOCKEDIN} fund_2.item_2.balance {5.00} fund_2.item_2.initial_balance {10.00} \
		fund_2.item_3.type {HELD} fund_2.item_3.balance {10.00} fund_2.item_3.initial_balance {0.00} \
	]

	dict set HARNESS_DATA CREATEFUND data USD failed  {status.code INTERNAL_ERROR service_error.code {INTERNAL_ERROR}  service_error.message {Internal Error} status.subcode {INTERNAL_ERROR} status.specification {An internal error occured. Please try again.}}
	dict set HARNESS_DATA CREATEFUND data GBP success [list \
		status.code OK \
		walletType_1 {PROMO} balance_1 {154.00} open_fund_1 2 redeemed_1 {10.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {15.00} open_fund_2 4 redeemed_2 {2.00} close_fund_2 2 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fund.status OPEN \
	]
	
	dict set HARNESS_DATA CREATEFUND data EUR success [list \
		status.code OK \
		walletType_1 {PROMO} balance_1 {60.00} open_fund_1 2 redeemed_1 {55.00} close_fund_1 42 \
		walletType_2 {STANDARD} balance_2 {35.00} open_fund_2 4 redeemed_2 {16.00} close_fund_2 21 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
	]

	dict set HARNESS_DATA CREATERESTRICTION data USD failed  {status.code INVALID_REFERENCE  service_error.code {INVALID_REFERENCE}  service_error.message {Internal Error}  status.subcode INVALID_RESTRICTION status.specification {Restriction with same reference already exists.}}
	dict set HARNESS_DATA CREATERESTRICTION data EUR success [list status.code {OK} restriction.status {SUSPENDED}]
	dict set HARNESS_DATA CREATERESTRICTION data GBP success [list status.code {OK} restriction.status {ACTIVE}]

	dict set HARNESS_DATA CONFIRMFUNDING data success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {50.00} open_fund_1 1 redeemed_1 {0.00} close_fund_1 0 \
		walletType_2 {STANDARD} balance_2 {50.00} open_fund_2 2 redeemed_2 {0.00} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.amount_1 {50.00} fundTrans.reqAmount_1 {50.00} fundTrans.status_1 {COMPLETE} \
		fund.id_1 {1} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {50.00} \
	]

	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data USD false failed {status.code INTERNAL_ERROR service_error.code {INTERNAL_ERROR}  service_error.message {Internal Error}  status.subcode {INTERNAL_ERROR} status.specification {An internal error occured. Please try again.}}
	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data EUR false success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.status {COMPLETE} \
		fund.id_1 {3} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {-15.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.amount {-22.11} \
		fund_1.item_3.type {BONUS} fund_1.item_3.amount {75.00} \
	]
	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data GBP false success_multi [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.status {COMPLETE} \
		fund.id_1 {3} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {-15.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.amount {-22.11} \
		fund_1.item_3.type {BONUS} fund_1.item_3.amount {75.00} \
		fund.id_2 {4} fund.provider_2 {G} \
		fund_2.item_1.type {HELD} fund_2.item_1.amount {60.00} \
		fund_2.item_2.type {LOCKEDIN} fund_2.item_2.amount {-30.00} \
		fund_2.item_3.type {BONUS} fund_2.item_3.amount {-10.00} \
	]

	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data USD true failed {status.code INTERNAL_ERROR service_error.code {INTERNAL_ERROR}  service_error.message {Internal Error}  status.subcode {INTERNAL_ERROR} status.specification {An internal error occured. Please try again.}}
	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data EUR true success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {-50.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 1 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.status {COMPLETE} \
		fund.id_1 {3} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {-15.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.amount {-22.11} \
		fund_1.item_3.type {BONUS} fund_1.item_3.amount {75.00} \
	]
	dict set HARNESS_DATA RESERVEMULTIPLEFUNDING data GBP true success_multi  [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {-50.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 1 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.status {COMPLETE} \
		fund.id_1 {3} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {-15.00} \
		fund_1.item_2.type {LOCKEDIN} fund_1.item_2.amount {-22.11} \
		fund_1.item_3.type {BONUS} fund_1.item_3.amount {75.00} \
		fund.id_2 {4} fund.provider_2 {G} \
		fund_2.item_1.type {HELD} fund_2.item_1.amount {60.00} \
		fund_2.item_2.type {LOCKEDIN} fund_2.item_2.amount {-30.00} \
		fund_2.item_3.type {BONUS} fund_2.item_3.amount {-10.00} \
	]

	dict set HARNESS_DATA GETFUNDHISTORY data success [list \
		status.code {OK} \
		fundTrans_1.id {1} fundTrans_1.amount {100.00} fundTrans_1.reqAmount_1 {100.00} fundTrans_1.status {COMPLETE} fundTrans_1.date {2014-05-06T14:15:59} \
		fundTrans_1.fund_1.id {14042801} fundTrans_1.fund_1.provider {G} \
		fundTrans_1.fund_1.item_1.type {BONUS} fundTrans_1.fund_1.item_1.amount {50.00} \
		fundTrans_1.fund_1.item_2.type {LOCKEDIN} fundTrans_1.fund_1.item_2.amount {10.00} \
		fundTrans_1.fund_1.item_3.type {HELD} fundTrans_1.fund_1.item_3.amount {50.00} \
		fundTrans_1.fund_2.id {4861254} fundTrans_1.fund_2.provider {G} \
		fundTrans_1.fund_2.item_1.type {BONUS} fundTrans_1.fund_2.item_1.amount {15.00} \
		fundTrans_1.fund_2.item_2.type {LOCKEDIN} fundTrans_1.fund_2.item_2.amount {25.00} \
		fundTrans_1.fund_2.item_3.type {HELD} fundTrans_1.fund_2.item_3.amount {30.00} \
		fundTrans_1.activity.id {15848} fundTrans_1.activity.provider {G} fundTrans_1.activity.type {CREATEFUND} \
		fundTrans_1.activity.op_1.id {1542} fundTrans_1.activity.op_1.provider {G} \
		fundTrans_1.activity.op_2.id {1543} fundTrans_1.activity.op_2.provider {G} \
		fundTrans_2.id {2} fundTrans_2.amount {15.00} fundTrans_2.reqAmount_1 {30.00} fundTrans_2.status {COMPLETE} fundTrans_2.date {2014-05-06T15:15:59} \
		fundTrans_2.fund_1.id {14042802} fundTrans_2.fund_1.provider {G} \
		fundTrans_2.fund_1.item_1.type {BONUS} fundTrans_2.fund_1.item_1.amount {30.00} \
		fundTrans_2.fund_1.item_2.type {LOCKEDIN} fundTrans_2.fund_1.item_2.amount {1.00} \
		fundTrans_2.fund_1.item_3.type {HELD} fundTrans_2.fund_1.item_3.amount {49.00} \
		fundTrans_2.fund_2.id {4861255} fundTrans_2.fund_2.provider {G} \
		fundTrans_2.fund_2.item_1.type {BONUS} fundTrans_2.fund_2.item_1.amount {54.00} \
		fundTrans_2.fund_2.item_2.type {LOCKEDIN} fundTrans_2.fund_2.item_2.amount {15.00} \
		fundTrans_2.fund_2.item_3.type {HELD} fundTrans_2.fund_2.item_3.amount {4.00} \
		fundTrans_2.activity.id {15849} fundTrans_2.activity.provider {G} fundTrans_2.activity.type {STAKE} \
		fundTrans_2.activity.op_1.id {1544} fundTrans_2.activity.op_1.provider {G} \
		fundTrans_2.activity.op_2.id {1545} fundTrans_2.activity.op_2.provider {G} \
	]

	dict set HARNESS_DATA GETFUNDACCOUNTSUMMARY data USD failed  {status.code INVALID_STATUS service_error.code {FAILED} status.subcode {INVALID_FUNDING_TRANSACTION} status.specification {The fromDate should be firstDayOFWeek and toDate should be lastDayOfWeek.}}
	dict set HARNESS_DATA GETFUNDACCOUNTSUMMARY data GBP success [list \
		status.code {OK} \
		summary_1.transaction_type {BSTK} summary_1.operation_type {OPL} summary_1.amount {17.00} \
		summary_1.count {3} summary_1.from_date {2016-01-25} summary_1.to_date {2016-01-31} \
		summary_1.from_time {15:00:00} summary_1.to_time {15:00:00} \
		summary_2.transaction_type {BSTK} summary_2.operation_type {OPX} summary_2.amount {11.00} \
		summary_2.count {2} summary_2.from_date {2016-01-11} summary_2.to_date {2016-01-17} \
		summary_2.from_time {15:00:00} summary_2.to_time {15:00:00} \
	]

	dict set HARNESS_DATA CANCELFUNDING data success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {50.00} open_fund_1 1 redeemed_1 {0.00} close_fund_1 0 \
		walletType_2 {STANDARD} balance_2 {50.00} open_fund_2 2 redeemed_2 {0.00} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {0.00} open_fund_3 0 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		fundTrans.amount_1 {50.00} fundTrans.reqAmount_1 {50.00} fundTrans.status_1 {CANCELLED} \
		fund.id_1 {1} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {50.00} \
	]

	dict set HARNESS_DATA CANCELRESTRICTION data success [list \
		status.code {OK} \
		fundTrans.amount_1 {-100.00} fundTrans.reqAmount_1 {-100.00} fundTrans.status_1 {COMPLETE} \
		fundTrans.id_1 {1} fund.provider_1 {G} \
		fund_1.item_1.type {HELD} fund_1.item_1.amount {-50.00} \
		fund_1.item_2.type {BONUS} fund_1.item_2.amount {-50.00} \
	]

	dict set HARNESS_DATA CANCELMULTIPLERESTRICTION data success [list \
		status.code {OK} \
		restriction_1.id {1} restriction_1.provider {G} restriction_1.status {CANCELLED} \
		restriction_2.id {2} restriction_2.provider {G} restriction_2.status {CANCELLED} \
	]

	dict set HARNESS_DATA CANCELACTIVITY data GBP success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {154.00} open_fund_1 2 redeemed_1 {10.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {15.00} open_fund_2 4 redeemed_2 {2.00} close_fund_2 2 \
		walletType_3 {STANDARD} balance_3 {15.00} open_fund_3 4 redeemed_3 {2.00} close_fund_3 2 \
		walletType_4 {STANDARD} balance_4 {15.00} open_fund_4 4 redeemed_4 {2.00} close_fund_4 2 \
		walletType_5 {STANDARD} balance_5 {15.00} open_fund_5 4 redeemed_5 {2.00} close_fund_5 2 \
		fundTrans_2.activity.id {15849} fundTrans_2.activity.provider {G} fundTrans_2.activity.type {STAKE} \
		fund.id_1 {123123} fund.provider_1 {G} fund.restriction.id_1 {666} fund.restriction.provider_1 {G} fund.type_1 {WR} \
		fund_1.item_1.type {BONUS} fund_1.item_1.balance {10.00} fund_1.item_1.initial_balance {100.00} \
	]

	dict set HARNESS_DATA MAKEFUNDPAYMENT data USD failed  {status.code INTERNAL_ERROR service_error.code {INTERNAL_ERROR}  service_error.message {Internal Error}  status.subcode {INTERNAL_ERROR} status.specification {An internal error occured. Please try again.}}
	dict set HARNESS_DATA MAKEFUNDPAYMENT data GBP success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {100.00} open_fund_3 1 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		activity.id_1 {8102015} activity.provider_1 {G} \
		fundTrans.amount_1 {50.00} fundTrans.reqAmount_1 {50.00} fundTrans.status {COMPLETE} \
		fund.id_1 {123123} fund.provider_1 {G} fund.forfeited_1 {false} \
		fund_1.item_1.type {CASH} fund_1.item_1.amount {50.00} \
	]

	dict set HARNESS_DATA MAKEFUNDPAYMENT data EUR success [list \
		status.code {OK} \
		walletType_1 {PROMO} balance_1 {45.20} open_fund_1 3 redeemed_1 {5.00} close_fund_1 1 \
		walletType_2 {STANDARD} balance_2 {34.62} open_fund_2 6 redeemed_2 {31.10} close_fund_2 0 \
		walletType_3 {CASH} balance_3 {100.00} open_fund_3 1 redeemed_3 {0.00} close_fund_3 0 \
		walletType_4 {CREDIT} balance_4 {0.00} open_fund_4 0 redeemed_4 {0.00} close_fund_4 0 \
		walletType_5 {FREESPINS} balance_5 {0.00} open_fund_5 0 redeemed_5 {0.00} close_fund_5 0 \
		activity.id_1 {8102015} activity.provider_1 {G} \
		fundTrans.amount_1 {-50.00} fundTrans.reqAmount_1 {50.00} fundTrans.status {COMPLETE} \
		fund.id_1 {123123} fund.provider_1 {G} fund.forfeited_1 {false} \
		fund_1.item_1.type {CASH} fund_1.item_1.amount {-50.00} \
	]

	dict set HARNESS_DATA GETFUNDACCOUNTHISTORY data EUR success [list \
		status.code {OK} \
		transaction_1.id {123456} transaction_1.amount {50.00} transaction_1.requested_amount {50.00} transaction_1.status {COMPLETE} \
		walletType_1 {PROMO} balance_1 {45.20}  \
		walletType_2 {STANDARD} balance_2 {34.62} \
		walletType_3 {CASH} balance_3 {100.00}  \
		walletType_4 {CREDIT} balance_4 {0.00}  \
		walletType_5 {FREESPINS} balance_5 {0.00}  \
		fund_1.id {123123} fund_1.provider {G} \
		fund_1.item_1.type {CASH} fund_1.item_1.amount {-50.00} \
		transaction_1.type {GPMT} transaction_1.date {2016-02-02T10:28:59} \
		activity_1.id {8102015} provider {G} activity_1.type {DEP} activity_1.operation_id {123} activity_1.operation_provider {G} activity_1.operation_type {DEP} activity_1.operation_status \
		description {DEPOSIT} \
	]

	dict set HARNESS_DATA GETFUNDACCOUNTHISTORY data GBP success [list \
		status.code {OK} \
		transaction_1.id {123456} transaction_1.amount {50.00} transaction_1.requested_amount {50.00} transaction_1.status {COMPLETE} \
		walletType_1 {PROMO} balance_1 {45.20}  \
		walletType_2 {STANDARD} balance_2 {34.62} \
		walletType_3 {CASH} balance_3 {100.00}  \
		walletType_4 {CREDIT} balance_4 {0.00}  \
		walletType_5 {FREESPINS} balance_5 {0.00}  \
		fund_1.id {123123} fund_1.provider {G} \
		fund_1.item_1.type {CASH} fund_1.item_1.amount {-50.00} \
		transaction_1.type {MADJ} transaction_1.date {2016-02-02T10:28:59} \
		activity_1.id {8102015} provider {G} activity_1.type {MAN} activity_1.operation_id {123} activity_1.operation_provider {G} activity_1.operation_type {MAN} activity_1.operation_status \
		description {Manual Adjustment} \
	]

	dict set HARNESS_DATA ACTIVATEFUND data 123123 success [list \
		status.code {OK} \
		fund.id {123123} fund.provider {G} \
		fund.restriction.id {654321} fund.restriction.provider {G} \
		fund.type {WR} \
		fund.status {OPEN} \
		fund.createDate {2016-01-01T00:00:01}\
		fung.startDate {2016-01-01T00:00:01}\
		fund.expiryDate {2016-01-01T00:00:01}\
		fund.item_1.type {CASH} fund.item_1.balance {20.00} fund.item_1.initial_balance {0.00} \
		fund.item_2.type {BONUS} fund.item_2.balance {20.00} fund.item_2.initial_balance {50.00} 
	]

	dict set HARNESS_DATA ACTIVATEFUND data 123124 success [list \
		status.code {OK} \
		fund.id {123124} fund.provider {G} \
		fund.restriction.id {654321} fund.restriction.provider {G} \
		fund.type {BONUS} \
		fund.status {CLOSED} \
		fund.createDate {2016-01-01T00:00:01}\
		fung.startDate {2016-01-01T00:00:01}\
		fund.expiryDate {2016-01-01T00:00:01}\
		fund.item_1.type {HELD} fund.item_1.balance {20.00} fund.item_1.initial_balance {0.00} \
		fund.item_2.type {BONUS} fund.item_2.balance {20.00} fund.item_2.initial_balance {50.00} 
	]
	
	dict set HARNESS_DATA UPDATEFUND data GBP success [list \
		status.code {OK} \
		fund.id {123123} \
		fund.reference.id {123123} fund.provider {G} \
		fund.restriction.id {654321} fund.restriction.provider {G} \
		fund.type {WR} \
		fund.status {OPEN} \
		fund.createDate {2016-01-01T00:00:01}\
		fung.startDate {2016-01-01T00:00:01}\
		fund.expiryDate {2016-01-01T00:00:01}\
		fund.item_1.type {CASH} fund.item_1.balance {20.00} fund.item_1.initial_balance {0.00} \
		fund.item_2.type {BONUS} fund.item_2.balance {20.00} fund.item_2.initial_balance {50.00} 
	]

	dict set HARNESS_DATA UPDATEFUND data EUR success [list \
		status.code {OK} \
		fund.id {123123} \
		fund.reference.id {123123} fund.provider {G} \
		fund.restriction.id {654321} fund.restriction.provider {G} \
		fund.type {BONUS} \
		fund.status {CLOSED} \
		fund.createDate {2016-01-01T00:00:01}\
		fung.startDate {2016-01-01T00:00:01}\
		fund.expiryDate {2016-01-01T00:00:01}\
		fund.item_1.type {HELD} fund.item_1.balance {20.00} fund.item_1.initial_balance {0.00} \
		fund.item_2.type {BONUS} fund.item_2.balance {20.00} fund.item_2.initial_balance {50.00} 
	]
}

core::args::register \
	-proc_name core::harness::api::funding_service::expose_magic \
	-body {
		variable HARNESS_DATA
		set i 0

		set MAGIC(0,header) {Currency type}
		set MAGIC(1,header) {Template scenario}
		set MAGIC(2,header) {Response Data}

		foreach request_type [dict keys $HARNESS_DATA] {
			set MAGIC($i,request_type) "$request_type funding service"
			set j 0

			foreach key [dict keys [dict get $HARNESS_DATA $request_type data]] {

				foreach template [dict keys [dict get $HARNESS_DATA $request_type data $key]] {
					set response_data [dict get $HARNESS_DATA $request_type data $key $template]
				}

				set MAGIC($i,$j,0,column) $key
				set MAGIC($i,$j,1,column) $template
				set MAGIC($i,$j,2,column) $response_data
				core::log::write DEV {$request_type - $key - $template - $response_data}
				incr j
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
# Register funding service harness stubs and overrides
#
core::args::register \
	-proc_name core::harness::api::funding_service::init \
	-args      [list \
		[list -arg -enabled -mand 0 -check BOOL -default_cfg FUNDING_SERVICE_HARNESS_ENABLED -default 0 -desc {Enable the funding service harness}] \
	] \
	-body {
		if {!$ARGS(-enabled)} {
			core::log::xwrite -msg {Funding service Harness - available though disabled} -colour yellow
			return
		}
		variable CFG

		core::stub::init

		core::stub::define_procs \
			-scope           proc \
			-pass_through    1 \
			-proc_definition [list \
				core::socket   send_req \
				core::socket   req_info \
				core::socket   clear_req \
			]

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_balance} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {getBalance} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_fund} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {createFund} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_balance} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_balance} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_fund} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_fund} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_restriction} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {createRestriction} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_restriction} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::create_restriction} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::confirm_funding} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {confirmFunding} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::confirm_funding} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::confirm_funding} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_history} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {getFundHistory} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_history} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_history} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_summary} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {getFundAccountSummary} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_summary} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_summary} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_funding} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {cancelFunding} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_funding} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_funding} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_restriction} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {cancelRestriction} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_restriction} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_restriction} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_multiple_restriction} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {cancelMultipleRestriction} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_multiple_restriction} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_multiple_restriction} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::reserve_multiple_funding} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {reserveMultipleFunding} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::reserve_multiple_funding} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::reserve_multiple_funding} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_activity} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {cancelActivity} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_activity} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::cancel_activity} \
			-return_data     {}
		
		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::make_fund_payment} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {makeFundPayment} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::make_fund_payment} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::make_fund_payment} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_history} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {getFundAccountHistory} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_history} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::get_fund_account_history} \
			-return_data     {}		


		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::activate_fund} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {activateFund} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::activate_fund} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::activate_fund} \
			-return_data     {}

		core::stub::set_override \
			-proc_name       {core::socket::send_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::update_fund} \
			-use_body_return 1 \
			-body {
				array set ARGS [core::args::check core::socket::send_req {*}$args]

				return [core::harness::api::funding_service::_process_request \
					-requestName {updateFund} \
					-request $ARGS(-req)]
			}

		core::stub::set_override \
			-proc_name       {core::socket::req_info} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::update_fund} \
			-use_body_return 1 \
			-body {
				return [core::harness::api::funding_service::_get_response]
			}

		core::stub::set_override \
			-proc_name       {core::socket::clear_req} \
			-scope           proc \
			-scope_key       {::core::api::funding_service::update_fund} \
			-return_data     {}				

		core::log::xwrite -msg {Funding service Harness - available and enabled} -colour yellow
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_process_request} \
	-desc      {Main request processing proc to decide which response to send back} \
	-args      [list \
		[list -arg -requestName -mand 1 -check ASCII -desc {The requestName to be processed}] \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		set requestName $ARGS(-requestName)
		set request     $ARGS(-request)

		return [_prepare_response_$requestName -request $request]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_getBalance} \
	-desc      {prepare the result for getBalance} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA GETBALANCE data $currency]]
		set response_data [dict get $HARNESS_DATA GETBALANCE data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		set response_get_balance [tpStringPlay -tostring [dict get $HARNESS_DATA GETBALANCE template $template]]
		dict set HARNESS_DATA response $response_get_balance

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_createFund} \
	-desc      {prepare the result for createFund} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		foreach {param xpath} {
			fund_type            {//*[local-name()='fund']/@type}
			fund_id              {//*[local-name()='externalFundRef']/@id}
			fund_provider        {//*[local-name()='externalFundRef']/@provider}
			restriction_id       {//*[local-name()='externalRestrictionRef']/@id}
			restriction_provider {//*[local-name()='externalRestrictionRef']/@provider}
			startDate            {//*[local-name()='startDate']}
			expiryDate           {//*[local-name()='expiryDate']}
			funds_bonus_balance  {//*[local-name()='fundItem'][@type='BONUS']/@amount}
			funds_fs_balance     {//*[local-name()='fundItem'][@type='FREESPINS']/@amount}
			funds_locked_balance {//*[local-name()='fundItem'][@type='LOCKEDIN']/@amount}
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

		set template [dict keys [dict get $HARNESS_DATA CREATEFUND data $currency]]
		set response_data [dict get $HARNESS_DATA CREATEFUND data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

                if {$funds_bonus_balance == "" } {
                        set funds_bonus_balance {0.00}
                }

                if {$funds_fs_balance == "" } {
                        set funds_fs_balance {0.00}
                }

		if {$funds_locked_balance == "" } {
			set funds_locked_balance {0.00}
		}
		tpBindString {fund.id} $fund_id
		tpBindString {fund.provider} $fund_provider
		tpBindString {fund.type} $fund_type
		tpBindString {fund.restriction.id} $restriction_id
		tpBindString {fund.restriction.provider} $restriction_provider
		tpBindString {fund.createDate} [core::date::datetime_to_xml_date -datetime [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]
		if { $startDate == {}} {
			# if there is the start date in the request (is optional) use it, otherwise use the current time
			set startDate [core::date::datetime_to_xml_date -datetime [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]
		}
		tpBindString {fund.startDate} $startDate
		tpBindString {fund.expiryDate} $expiryDate
		if { $fund_type == {STANDARD} || $fund_type == {WR} } {
			tpBindString {fund.item_1.type} "BONUS"
			tpBindString {fund.item_1.balance} $funds_bonus_balance
			tpBindString {fund.item_1.initial_balance} $funds_bonus_balance
		} else {
			tpBindString {fund.item_1.type} "FREESPINS"
			tpBindString {fund.item_1.balance} $funds_fs_balance
			tpBindString {fund.item_1.initial_balance} $funds_fs_balance
		}
		tpBindString {fund.item_2.type} "LOCKEDIN"
		tpBindString {fund.item_2.balance} $funds_locked_balance
		tpBindString {fund.item_2.initial_balance} $funds_locked_balance

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CREATEFUND template $template]]
		dict set HARNESS_DATA response $response
		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_createRestriction} \
	-desc      {prepare the result for createRestriction} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set id [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalRestrictionRef']/@id} \
			-return_list 1]
		
		set provider [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalRestrictionRef']/@provider} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA CREATERESTRICTION data $currency]]
		set response_data [dict get $HARNESS_DATA CREATERESTRICTION data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString {restriction.id} $id
		tpBindString {restriction.provider} $provider

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CREATERESTRICTION template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_confirmFunding} \
	-desc      {prepare the result for confirmFunding. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set fundingTransactionRef [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingTransactionRef']/@id} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA CONFIRMFUNDING data ]]
		set response_data [dict get $HARNESS_DATA CONFIRMFUNDING data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}
		tpBindString fundTrans.id_1 $fundingTransactionRef

		set response_confirm_transaction [tpStringPlay -tostring [dict get $HARNESS_DATA CONFIRMFUNDING template $template]]
		dict set HARNESS_DATA response $response_confirm_transaction

		return [list 1 OK 1]
	}
	
core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_getFundHistory} \
	-desc      {prepare the result for getFundHistory. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set fund_id [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalFundRef']/@id} \
			-return_list 1]
		set fund_provider [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalFundRef']/@provider} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA GETFUNDHISTORY data]]
		set response_data [dict get $HARNESS_DATA GETFUNDHISTORY data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString fund.id $fund_id
		tpBindString fund.provider $fund_provider

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA GETFUNDHISTORY template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_getFundAccountSummary} \
	-desc      {prepare the result for getFundAccountSummary. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA GETFUNDACCOUNTSUMMARY data $currency]]
		set response_data [dict get $HARNESS_DATA GETFUNDACCOUNTSUMMARY data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		set transaction_types [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='transactionType']} \
			-return_list 1]

		# If request has transaction types use them instead from harness data
		foreach type $transaction_types {
			incr type_idx	
			tpBindString summary_$type_idx.transaction_type $type
		}

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA GETFUNDACCOUNTSUMMARY template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_cancelFunding} \
	-desc      {prepare the result for cancelFunding. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set fundingTransactionRef [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingTransactionRef']/@id} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA CANCELFUNDING data ]]
		set response_data [dict get $HARNESS_DATA CANCELFUNDING data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}
		tpBindString fundTrans.id_1 $fundingTransactionRef

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CANCELFUNDING template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_cancelRestriction} \
	-desc      {prepare the result for cancelRestriction. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set restrictionId [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalRestrictionRef']/@id} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA CANCELRESTRICTION data]]
		set response_data [dict get $HARNESS_DATA CANCELRESTRICTION data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}
		tpBindString fund.id_1 $restrictionId

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CANCELRESTRICTION template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_cancelMultipleRestriction} \
	-desc      {prepare the result for cancelRestriction. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set template [dict keys [dict get $HARNESS_DATA CANCELMULTIPLERESTRICTION data]]
		set response_data [dict get $HARNESS_DATA CANCELMULTIPLERESTRICTION data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CANCELMULTIPLERESTRICTION template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_reserveMultipleFunding} \
	-desc      {prepare the result for reserveMultipleFunding} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set num_activities [llength [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']} \
			-return_list 1]]

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set fundingTransactionRef1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalActivityRef']/@id} \
			-return_list 1] 0]

		set amount1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']/*[local-name()='amount']} \
			-return_list 1] 0]

		set negative [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='negativeBalanceOverride']} \
			-return_list 1] 0]

		if {$negative == {}} {
			set negative false
		}

		if {$num_activities > 1} {
			set fundingTransactionRef2 [lindex [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalActivityRef']/@id} \
				-return_list 1] 1]

			set amount2 [lindex [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='fundingActivity']/*[local-name()='amount']} \
				-return_list 1] 1]

			tpBindString fundTrans.id_2        $fundingTransactionRef2
			tpBindString fundTrans.amount_2    $amount2
			tpBindString fundTrans.reqAmount_2 $amount2
		}

		set template [dict keys [dict get $HARNESS_DATA RESERVEMULTIPLEFUNDING data $currency $negative]]
		set response_data [dict get $HARNESS_DATA RESERVEMULTIPLEFUNDING data $currency $negative $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString fundTrans.id_1 $fundingTransactionRef1
		tpBindString fundTrans.amount_1 $amount1
		tpBindString fundTrans.reqAmount_1 $amount1 

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA RESERVEMULTIPLEFUNDING template $template]]
		
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}


	core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_makeFundPayment} \
	-desc      {prepare the result for makeFundPayment} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set num_activities [llength [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']} \
			-return_list 1]]

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

		set fundingTransactionRef1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalActivityRef']/@id} \
			-return_list 1] 0]

		set amount1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']/*[local-name()='fund']/*[local-name()='fundItems']/*[local-name()='fundItem']/@amount} \
			-return_list 1] 0]

		set template [dict keys [dict get $HARNESS_DATA MAKEFUNDPAYMENT data $currency]]
		set response_data [dict get $HARNESS_DATA MAKEFUNDPAYMENT data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		tpBindString fundTrans.id_1 $fundingTransactionRef1
		tpBindString fundTrans.amount_1 $amount1

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA MAKEFUNDPAYMENT template $template]]

		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_cancelActivity} \
	-desc      {prepare the result for cancelActivity. This will always return a successful result.} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set fundingTransactionRef1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalActivityRef']/@id} \
			-return_list 1] 0]

		set template [dict keys [dict get $HARNESS_DATA CANCELACTIVITY data ]]
		set response_data [dict get $HARNESS_DATA CANCELACTIVITY data $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}
		tpBindString activityRef $fundingTransactionRef

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA CANCELACTIVITY template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

	core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_getFundAccountHistory} \
	-desc      {prepare the result for getFundAccountHistory} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

#		set num_activities [llength [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']} \
			-return_list 1]]

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {USD} \
			-return_list 1]

#		set fundingTransactionRef1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalActivityRef']/@id} \
			-return_list 1] 0]

#		set amount1 [lindex [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='fundingActivity']/*[local-name()='amount']} \
			-return_list 1] 0]

		#if {$num_activities > 1} {
		#	set fundingTransactionRef2 [lindex [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='externalActivityRef']/@id} \
				-return_list 1] 1]

		#	set amount2 [lindex [core::xml::extract_data \
				-node    $doc \
				-xpath   {//*[local-name()='fundingActivity']/*[local-name()='amount']} \
				-return_list 1] 1]

		#	tpBindString fundTrans.id_2        $fundingTransactionRef2
		#	tpBindString fundTrans.amount_2    $amount2
		#	tpBindString fundTrans.reqAmount_2 $amount2
		#}

		set template [dict keys [dict get $HARNESS_DATA GETFUNDACCOUNTHISTORY data $currency]]
		set response_data [dict get $HARNESS_DATA GETFUNDACCOUNTHISTORY data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		#tpBindString fundTrans.id_1 $fundingTransactionRef1
		#tpBindString fundTrans.amount_1 $amount1
		#tpBindString fundTrans.reqAmount_1 $amount1 

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA GETFUNDACCOUNTHISTORY template $template]]
		
		dict set HARNESS_DATA response $response
		

		return [list 1 OK 1]
	}


	core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_activateFund} \
	-desc      {prepare the result for activateFund} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set fund_id [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='externalFundRef']/@id} \
			-default {GBP} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA ACTIVATEFUND data $fund_id]]
		set response_data [dict get $HARNESS_DATA ACTIVATEFUND data $fund_id $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA ACTIVATEFUND template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

	core::args::register \
	-proc_name {core::harness::api::funding_service::_prepare_response_updateFund} \
	-desc      {prepare the result for updateFund} \
	-args      [list \
		[list -arg -request -mand 1 -check ASCII -desc {The request to be processed}] \
	] \
	-body {
		variable HARNESS_DATA

		lassign [core::xml::parse -strict 0 -xml $ARGS(-request)] status doc

		set currency [core::xml::extract_data \
			-node    $doc \
			-xpath   {//*[local-name()='currencyRef']/@id} \
			-default {GBP} \
			-return_list 1]

		set template [dict keys [dict get $HARNESS_DATA UPDATEFUND data GBP]]
		set response_data [dict get $HARNESS_DATA UPDATEFUND data $currency $template]

		foreach {key value} $response_data {
			tpBindString $key $value
		}

		set response [tpStringPlay -tostring [dict get $HARNESS_DATA UPDATEFUND template $template]]
		dict set HARNESS_DATA response $response

		return [list 1 OK 1]
	}

#
#
# _get_response
#
# Simply returns the prepared response. After calling any prepared
# response in the dictionary will be cleared
#
core::args::register \
	-proc_name {core::harness::api::funding_service::_get_response} \
	-desc      {Gets the response prepared by _process_request} \
	-body {
		variable HARNESS_DATA

		set response [dict get $HARNESS_DATA response]

		dict unset HARNESS_DATA response

		return $response
	}
