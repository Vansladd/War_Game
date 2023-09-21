#
#
# © 2011 OpenBet Technology Ltd. All rights reserved.
#
# The following procedures are made available for invoking web services on
# the verification module. Results are returned as lists of name-value pairs.
#
#
# Error codes:
#   VG_ERROR_MANDATORY_FIELD
#   VG_ERROR_DB
#   VG_ERROR_SEND_REQ
#   VG_ERROR_XML_PARSING
#   VG_ERROR_NO_CUSTOMER
#   VG_ERROR_NO_DATA
#   VG_ERROR_ADDRESS_NOT_FOUND
#

set pkg_version 1.0
package provide core::verification $pkg_version

package require core::socket       1.0
package require core::xml          1.0
package require core::db::schema   1.0
package require core::log          1.0
package require tdom

core::args::register_ns \
	-namespace core::verification \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args] \
	-docs      xml/api/verification.xml

namespace eval core::verification {
	variable CFG
	variable XML_ATTR_MAPPINGS

	set CFG(init) 0

	variable CUSTDATA
	variable BANKDATA
}

core::args::register \
	-proc_name core::verification::init \
	-args [list \
		[list -arg -service_host           -mand 0 -check ASCII -default_cfg {VG_HOST}                        -default localhost -desc {Service host}] \
		[list -arg -service_port           -mand 0 -check UINT  -default_cfg {VG_PORT}                        -default 8084      -desc {Service port}] \
		[list -arg -service_urls           -mand 0 -check LIST  -default_cfg {VG_REQUEST}                     -default [list]    -desc {Service URL list name value pairs}] \
		[list -arg -conn_timeout           -mand 0 -check UINT  -default_cfg {VG_CONN_TIMEOUT}                -default 3000      -desc {Connection timeout}] \
		[list -arg -req_timeout            -mand 0 -check UINT  -default_cfg {VG_REQ_TIMEOUT}                 -default 10000     -desc {Request timeout}] \
		[list -arg -use_ssl                -mand 0 -check BOOL  -default_cfg {VG_USE_SSL}                     -default 1         -desc {Enable secure communication over SSL}] \
		[list -arg -enable_cc_data         -mand 0 -check BOOL  -default_cfg {VG_ENABLE_CC_DATA}              -default 0         -desc {Enable credit card data}] \
		[list -arg -enable_ba_data         -mand 0 -check BOOL  -default_cfg {VG_ENABLE_BA_DATA}              -default 0         -desc {Enable bank data}] \
		[list -arg -verify_gender_enabled  -mand 0 -check BOOL                                                -default 1         -desc {Gender enabled}] \
		[list -arg -verify_title_enabled   -mand 0 -check BOOL                                                -default 1         -desc {Title enabled}] \
		[list -arg -verify_email_enabled   -mand 0 -check BOOL  -default_cfg {CORE_VG_VERIFY_EMAIL_ENABLED}   -default 1         -desc {Email enabled}] \
		[list -arg -provider_list_enabled  -mand 0 -check BOOL  -default_cfg {CORE_VG_PROVIDER_LIST_ENABLED}  -default 1         -desc {When enabled, provider ids and alias must be provided as a list and not separate proc arguments. This should be enabled if vefification gateway > 2.1.0 is being used.}] \
		[list -arg -status_list_enabled    -mand 0 -check BOOL  -default_cfg {CORE_VG_STATUS_LIST_ENABLED}    -default 1         -desc {When enabled, responce will build verification status element as a list of statuses. This should be enabled if vefification gateway > 2.1.0 is being used.}] \
	]

# Initializes the module
#
proc core::verification::init args {
	variable CFG
	variable XML_ATTR_MAPPINGS


	if {$CFG(init)} { return }

	core::log::write INFO {Initialising core::verification}

	array set ARGS [core::args::check core::verification::init {*}$args]

	set CFG(service_host)    $ARGS(-service_host)
	set CFG(service_port)    $ARGS(-service_port)
	set CFG(use_ssl)         $ARGS(-use_ssl)
	set CFG(enable_cc_data)  $ARGS(-enable_cc_data)
	set CFG(enable_ba_data)  $ARGS(-enable_ba_data)
	set CFG(conn_timeout)    $ARGS(-conn_timeout)
	set CFG(req_timeout)     $ARGS(-req_timeout)

	set CFG(verify.gender.enabled)  $ARGS(-verify_gender_enabled)
	set CFG(verify.title.enabled)   $ARGS(-verify_title_enabled)
	set CFG(verify.email.enabled)   $ARGS(-verify_email_enabled)
	set CFG(provider.list.enabled)  $ARGS(-provider_list_enabled)
	set CFG(status.list.enabled)    $ARGS(-status_list_enabled)

	foreach {req url} $ARGS(-service_urls) {
		set CFG(url,$req) $url
	}

	# Defining the mappings from proc arg names to corresponsing XML names
	array set XML_ATTR_MAPPINGS [list \
		custId    id \
	]

	core::db::schema::init

	prep_qrys

	set CFG(init) 1
}



#
# This procedure creates prepared statements:
# core::verification::customer_data_stmt
# core::verification::cc_data_stmt
#
proc core::verification::prep_qrys args {

	variable CFG

	# Temporary introspection check until full mechanism in place for core
	if {[core::db::schema::table_column_exists -table tcustomerreg -column addr_county]} {
		set CFG(column.exists.tcustomerreg.county) 1
	} else {
		set CFG(column.exists.tcustomerreg.county) 0
	}

	set CFG(fields) [list \
		cust_id        r 1 \
		title          r $CFG(verify.title.enabled) \
		fname          r 1 \
		lname          r 1 \
		gender         r $CFG(verify.gender.enabled) \
		dob            r 1 \
		contact_ok     r 1 \
		addr_street_1  r 1 \
		addr_street_2  r 1 \
		addr_street_3  r 1 \
		addr_street_4  r 1 \
		addr_postcode  r 1 \
		addr_city      r 1 \
		addr_county    r $CFG(column.exists.tcustomerreg.county) \
		addr_country   r 1 \
		telephone      r 1 \
		email          r $CFG(verify.email.enabled) \
		country_code   o 1 \
	]

	set selectFields [list]
	foreach {field prefix enableFlag} $CFG(fields) {
		if {$enableFlag} {
			lappend selectFields $prefix.$field
		}
	}

	core::db::store_qry \
		-name core::verification::customer_data_stmt \
		-qry  [subst {
			select
				[join $selectFields ", "]
			from
				tAcct        a,
				tCustomerReg r,
				tCustomer    c,
				outer tCountry o
			where
				c.cust_id = ?
			and r.cust_id = c.cust_id
			and c.cust_id = a.cust_id
			and c.type    = 'C'
			and r.addr_country = o.country_name
		}]

	core::db::store_qry \
		-name core::verification::bank_acc_data_stmt \
		-qry {
			select
				bank_acct_no,
				bank_sort_code
			from
				tCPMBank     b,
				tCustPayMthd cpm
			where
				b.cpm_id   = cpm.cpm_id
			and cpm.status = 'A'
			and b.cust_id  = ?
		}
}


core::args::register \
	-proc_name core::verification::build_verify_customer_req \
	-args [list \
		[list -arg -custId               -mand 1 -check ALNUM               -desc {The customer Id to verify}] \
		[list -arg -obAlias              -mand 1 -check ASCII               -desc {The verification profile to be used}] \
		[list -arg -username             -mand 0 -check STRING -default {}  -desc {Username of the customer}] \
		[list -arg -channel              -mand 0 -check ALNUM  -default {}  -desc {The channel the verification request is comming from}] \
		[list -arg -ipAddress            -mand 0 -check STRING -default {}  -desc {Current IP address of the customer}] \
		[list -arg -device               -mand 0 -check ASCII  -default {}  -desc {Data identifying or specific to customer's device, e.g. blackbox for iOvation checks}] \
		[list -arg -deviceType           -mand 0 -check ASCII  -default {}  -desc {Type of device, e.g. iPad}] \
		[list -arg -deviceAlias          -mand 0 -check ASCII  -default {}  -desc {Provider's identifier for the device}] \
		[list -arg -cvv2                 -mand 0 -check INT    -default {}  -desc {Customers cvv2}] \
		[list -arg -ccCardNo             -mand 0 -check UINT   -default {}  -desc {Customers credit card number}] \
		[list -arg -ccStart              -mand 0 -check STRING   -default {}  -desc {Customers credit card start date}] \
		[list -arg -ccExpiry             -mand 0 -check STRING   -default {}  -desc {Customers credit card expiry date}] \
		[list -arg -ccIssueNo            -mand 0 -check UINT   -default {}  -desc {Customers credit card issue_no}] \
		[list -arg -ccScheme             -mand 0 -check ASCII  -default {}  -desc {Customers credit card scheme}] \
		[list -arg -ssn                  -mand 0 -check ASCII  -default {}  -desc {Customers SSN (for international verification)}] \
		[list -arg -customerAddress      -mand 0 -check ANY    -default {}  -desc {Dict containing customer's current address}] \
		[list -arg -previousAddress      -mand 0 -check ANY    -default {}  -desc {Dict containing customer's previous address}] \
		[list -arg -billingAddress       -mand 0 -check ANY    -default {}  -desc {Dict containing customer's billing address}] \
		[list -arg -addressCallback      -mand 0 -check ASCII  -default {core::verification::resolve_address} -desc {Callback function that parses address fields}] \
		[list -arg -personalDataCallback -mand 0 -check ASCII  -default {}   -desc {Callback function that customizes handling of personal data fields}] \
		[list -arg -externalUser         -mand 0 -check ASCII  -default {}   -desc {External username}] \
		[list -arg -externalSysId        -mand 0 -check INT    -default {}   -desc {External system id}] \
		[list -arg -clientOrigin         -mand 0 -check STRING -default {}   -desc {Description of calling logic for request}] \
	]
#
# This method extracts relevant customer data and performs call to verification
# service, that routes request to the correct service provider.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#ALNUM
proc core::verification::build_verify_customer_req args {

	variable CFG
	variable BANKDATA
	variable CUSTDATA

	array set ARGS [core::args::check core::verification::build_verify_customer_req {*}$args]

	set fn {core::verification::build_verify_customer_req}

	# Get customer data for verification request
	if {[catch {
		set rs [core::db::exec_qry \
			-name core::verification::customer_data_stmt \
			-args [list $ARGS(-custId)]]
	} msg]} {
		core::log::write ERROR {$fn Error executing $msg}
		return [list 0 VG_ERROR_DB "retrieving customer data"]
	}

	set nrows [db_get_nrows $rs]
	if {$nrows < 1} {
		catch {core::db::rs_close -rs $rs}
		core::log::write ERROR {$fn no such customer has been found}
		return [list 0 VG_ERROR_NO_CUSTOMER \
			"No such customer has been found in the database"]
	}

	if {$nrows > 1} {
		core::log::write WARNING {$fn Query returned more than one row}
	}
	if {[db_get_col $rs 0 contact_ok] != "Y"} {
		core::log::write ERROR {$fn customer contact data not OK}
	}
	if {[db_get_col $rs 0 country_code] == ""} {
		core::log::write ERROR {$fn no country code found}
		return [list 0 VG_ERROR_NO_CNTRY_CODE]
	}

	foreach {field prefix enableFlag} $CFG(fields) {
		if {$enableFlag} {
			set CUSTDATA($field) [db_get_col $rs 0 $field]
		} else {
			set CUSTDATA($field) {}
		}
	}

	catch {core::db::rs_close -rs $rs}

	if {$ARGS(-customerAddress) != {}} {
		set laddress $ARGS(-customerAddress)
	} else {
		set laddress [$ARGS(-addressCallback) \
			-address1 $CUSTDATA(addr_street_1) \
			-address2 $CUSTDATA(addr_street_2) \
			-address3 $CUSTDATA(addr_street_3) \
			-address4 $CUSTDATA(addr_street_4) \
			-postcode $CUSTDATA(addr_postcode) \
			-city     $CUSTDATA(addr_city) \
			-county   $CUSTDATA(addr_county) \
			-country  $CUSTDATA(country_code) \
		]
	}

	dict for {addressField value} $laddress {
		set CUSTDATA($addressField) $value
	}

	if {$ARGS(-previousAddress) != {}} {
		set CUSTDATA(previousAddress) 1
		dict for {addressField value} $ARGS(-previousAddress) {
			set CUSTDATA(previousAddress,$addressField) $value
		}
	}

	if {$ARGS(-billingAddress) != {}} {
		set CUSTDATA(billingAddress) 1
		dict for {addressField value} $ARGS(-billingAddress) {
			set CUSTDATA(billingAddress,$addressField) $value
		}
	}

	if {$ARGS(-personalDataCallback) != {}} {
		set NEWDATA [$ARGS(-personalDataCallback) [array get CUSTDATA]]
		array unset CUSTDATA
		array set CUSTDATA $NEWDATA
	}

	# Normalize telephone number
	if {$CUSTDATA(telephone) != {}} {
		# experian works only with UK number, so make senso to normalize the number in the request.
		regsub -all {^(0044|\+44)?\s*([0-9]+)} $CUSTDATA(telephone) {\2} norm_telephone
		regsub -all {[^0-9]+} $norm_telephone {} norm_telephone
		# add 0 if not start with
		if {[string first {0} $norm_telephone ] != 0} {
			set norm_telephone "0${norm_telephone}"
		}

		set CUSTDATA(telephone) $norm_telephone
	}

	# Build request document
	set doc [dom createDocument verifyCustomer]
	$doc encoding utf-8

	set root        [$doc documentElement]
	set config_node [core::xml::add_element -node $root -name verificationConfiguration]

	$config_node setAttribute obAlias $ARGS(-obAlias)

	# Optional arguments
	if {$ARGS(-channel) != {}} {
		$config_node setAttribute channel $ARGS(-channel)
	}

	# externalClient node

	if {$ARGS(-externalUser) != {} && $ARGS(-externalSysId) != {}} {
		set external_node [core::xml::add_element -node $root -name externalClient]
		$external_node setAttribute externalUser $ARGS(-externalUser)
		$external_node setAttribute externalSysId $ARGS(-externalSysId)
	}

	set cust_node [core::xml::add_element -node $root -name customer]

	$cust_node setAttribute id                   $ARGS(-custId)
	$cust_node setAttribute firstName            $CUSTDATA(fname)
	$cust_node setAttribute middleName           {}
	$cust_node setAttribute lastName             $CUSTDATA(lname)
	$cust_node setAttribute suffix               {}
	$cust_node setAttribute title                $CUSTDATA(title)
	$cust_node setAttribute dob                  $CUSTDATA(dob)
	$cust_node setAttribute gender               $CUSTDATA(gender)
	$cust_node setAttribute telephone            $CUSTDATA(telephone)
	if {$CFG(verify.email.enabled)} {
		# Verfication server < 2.1.0 does not support email attribute.
		$cust_node setAttribute emailAddress $CUSTDATA(email)
	}
	$cust_node setAttribute passportNumber       {}
	$cust_node setAttribute drivingLicenceNumber {}
	$cust_node setAttribute ipAddress            $ARGS(-ipAddress)

	if {$ARGS(-username) != {}} {
		$cust_node setAttribute username         $ARGS(-username)
	}

	if {$ARGS(-ssn) != {}} {
		$cust_node setAttribute ssn              $ARGS(-ssn)
	}

	set address_node [core::xml::add_element -node $root -name customerAddress]
	if {[info exists CUSTDATA(full_address)] && $CUSTDATA(full_address) != {} } {
		$address_node setAttribute fullAddress  $CUSTDATA(full_address)
	} else {
		$address_node setAttribute flatNumber  $CUSTDATA(flat_number)
		$address_node setAttribute houseName   $CUSTDATA(house_name)
		$address_node setAttribute houseNumber $CUSTDATA(house_number)
		$address_node setAttribute street      $CUSTDATA(street)
		$address_node setAttribute district    $CUSTDATA(district)
		$address_node setAttribute zip         $CUSTDATA(zip)
		$address_node setAttribute city        $CUSTDATA(city)
		$address_node setAttribute state       $CUSTDATA(state)
		$address_node setAttribute country     $CUSTDATA(country)

		if {[info exists CUSTDATA(ireland_county_name)] && $CUSTDATA(ireland_county_name) != {} } {
			$address_node setAttribute irelandCountyName  $CUSTDATA(ireland_county_name)
		}
		if {[info exists CUSTDATA(ireland_county_code)] && $CUSTDATA(ireland_county_code) != {} } {
			$address_node setAttribute irelandCountyCode  $CUSTDATA(ireland_county_code)
		}
	}

	if {[info exists CUSTDATA(previousAddress)]} {
		set prev_address_node [core::xml::add_element -node $root -name previousCustomerAddress]
		if {[info exists CUSTDATA(previousAddress,full_address)] && $CUSTDATA(previousAddress,full_address) != {} } {
			$prev_address_node setAttribute fullAddress  $CUSTDATA(previousAddress,full_address)
		} else {
			$prev_address_node setAttribute flatNumber  $CUSTDATA(previousAddress,flat_number)
			$prev_address_node setAttribute houseName   $CUSTDATA(previousAddress,house_name)
			$prev_address_node setAttribute houseNumber $CUSTDATA(previousAddress,house_number)
			$prev_address_node setAttribute street      $CUSTDATA(previousAddress,street)
			$prev_address_node setAttribute district    $CUSTDATA(previousAddress,district)
			$prev_address_node setAttribute zip         $CUSTDATA(previousAddress,zip)
			$prev_address_node setAttribute city        $CUSTDATA(previousAddress,city)
			$prev_address_node setAttribute state       $CUSTDATA(previousAddress,state)
			$prev_address_node setAttribute country     $CUSTDATA(previousAddress,country)

		if {[info exists CUSTDATA(previousAddress,ireland_county_name)] && $CUSTDATA(previousAddress,ireland_county_name) != {} } {
			$prev_address_node setAttribute irelandCountyName  $CUSTDATA(previousAddress,ireland_county_name)
		}
		if {[info exists CUSTDATA(previousAddress,ireland_county_code)] && $CUSTDATA(previousAddress,ireland_county_code) != {} } {
			$prev_address_node setAttribute irelandCountyCode  $CUSTDATA(previousAddress,ireland_county_code)
		}

		}
	}

	if {[info exists CUSTDATA(billingAddress)]} {
		set billing_address_node [core::xml::add_element -node $root -name billingCustomerAddress]
		if {[info exists CUSTDATA(billingAddress,full_address)] && $CUSTDATA(billingAddress,full_address) != {} } {
			$billing_address_node setAttribute fullAddress  $CUSTDATA(billingAddress,full_address)
		} else {
			$billing_address_node setAttribute flatNumber  $CUSTDATA(billingAddress,flat_number)
			$billing_address_node setAttribute houseName   $CUSTDATA(billingAddress,house_name)
			$billing_address_node setAttribute houseNumber $CUSTDATA(billingAddress,house_number)
			$billing_address_node setAttribute street      $CUSTDATA(billingAddress,street)
			$billing_address_node setAttribute district    $CUSTDATA(billingAddress,district)
			$billing_address_node setAttribute zip         $CUSTDATA(billingAddress,zip)
			$billing_address_node setAttribute city        $CUSTDATA(billingAddress,city)
			$billing_address_node setAttribute state       $CUSTDATA(billingAddress,state)
			$billing_address_node setAttribute country     $CUSTDATA(billingAddress,country)

		if {[info exists CUSTDATA(billingAddress,ireland_county_name)] && $CUSTDATA(billingAddress,ireland_county_name) != {} } {
			$billing_address_node setAttribute irelandCountyName  $CUSTDATA(billingAddress,ireland_county_name)
		}
		if {[info exists CUSTDATA(billingAddress,ireland_county_code)] && $CUSTDATA(billingAddress,ireland_county_name) != {} } {
			$billing_address_node setAttribute irelandCountyCode  $CUSTDATA(billingAddress,ireland_county_code)
		}

		}
	}

	if {[_get_bank_acc_data $ARGS(-custId)]} {
		set bank_node [core::xml::add_element -node $root -name bankAccount]
		$bank_node setAttribute bankAccountNumber $BANKDATA(bank_acct_no)
		$bank_node setAttribute sortCode          $BANKDATA(bank_sort_code)
	}

	# Get credit card data if available
	if {$CFG(enable_cc_data) && $ARGS(-ccCardNo) != {}} {
		set cc_node [core::xml::add_element -node $root -name creditCard]
		$cc_node setAttribute cardNumber   $ARGS(-ccCardNo)
		$cc_node setAttribute cvv2         $ARGS(-cvv2)
		$cc_node setAttribute expiryDate   $ARGS(-ccExpiry)

		# only include if populated
		if {$ARGS(-ccStart) != ""} {
			$cc_node setAttribute startDate $ARGS(-ccStart)
		}
		# only inlcude if populated
		if {$ARGS(-ccIssueNo) != ""} {
			$cc_node setAttribute issueNumber $ARGS(-ccIssueNo)
		}

		$cc_node setAttribute cardScheme $ARGS(-ccScheme)
	} else {
		core::log::write DEBUG {$fn No card available for customer $ARGS(-custId)}
	}

	set device_node [core::xml::add_element -node $root -name device]
	if {$ARGS(-device) != {}} {
		core::xml::add_element \
			-node  $device_node \
			-name  encryptedInformation \
			-value $ARGS(-device)
	}

	if {$ARGS(-deviceAlias) != {} } {
		$device_node setAttribute deviceAlias $ARGS(-deviceAlias)
	}
	if {$ARGS(-deviceType) != {} } {
		$device_node setAttribute deviceType $ARGS(-deviceType)
	}

	if {$ARGS(-clientOrigin) != {}} {
		core::xml::add_element \
			-node  $root \
			-name  clientOrigin \
			-value $ARGS(-clientOrigin)
	}

	set ret [core::verification::send_request -doc $doc -ref verifyCustomer]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /verifyCustomerResp/verificationResult]

	if {$response == ""} {
		return [list 0 VG_ERROR_NO_DATA {Verification Gateway returned empty data set}]
	}

	set result [list]

	set verification_status ""
	if {$CFG(status.list.enabled)} {
		set verification_status [dict create]
	}

	set verificationFlags [list]

	# Ensure that we set all list key-value entries
	foreach el_name {
		cust \
		device \
		verificationStatus \
		verificationDateTime \
		verificationReference \
		verificationText \
		verificationFlag \
		verificationId \
		verificationChannel
	} {
		set element [$response getElementsByTagName $el_name]

		switch $el_name {
			cust    {
				# FIXME: This is a quick hack, should be properly reverse mapped
				lappend result custId [$element getAttribute id {}]
			}
			device {
				# Probably needs the same solution as cust
				if {$element != ""} {
					lappend result deviceAlias [$element getAttribute deviceAlias {}]
				}
			}
			verificationStatus {
				if {$CFG(status.list.enabled)} {
					# Verification gateway >= 2.1.0.

					# There can be multiple of these, so we build a dict using the check names as keys
					for {set i 0} {$i < [llength $element]} {incr i} {
						set status_elem [lindex $element $i]
						if {$status_elem != ""} {
							dict set verification_status [$status_elem getAttribute check {}] [$status_elem asText]
						}
					}
				} else {
					# Verification gateway < 2.1.0.
					if {$element != ""} {
						set verification_status [$element asText]
					}
				}
			}
			verificationFlag {
				for {set i 0} {$i < [llength $element]} {incr i} {
					set flag_elem [lindex $element $i]
					if {$flag_elem != ""} {
						set verification_flag [dict create]
						dict set verification_flag code [$flag_elem getAttribute code {}]
						dict set verification_flag desc [$flag_elem getAttribute desc {}]
						lappend verificationFlags $verification_flag
					}
				}
			}
			default {
				if {$element != ""} {
					lappend result $el_name [$element asText]
				} else {
					lappend result $el_name ""
				}
			}
		}
	}

	lappend result "verificationFlags"  $verificationFlags
	lappend result "verificationStatus" $verification_status

	return [list 1 $result]
}


core::args::register \
	-proc_name core::verification::build_check_verification_required \
	-args [list \
		[list -arg -obAlias -mand 1 -check ASCII             -desc {The verification profile to check}] \
		[list -arg -custId  -mand 0 -check ALNUM -default {} -desc {The customer Id to perform customer verify}] \
		[list -arg -channel -mand 0 -check ALNUM -default {} -desc {The channel the verification request is comming from}] \
	]

# This method performs a check of a particular configuration with verification service.
# Response indicates whether the verification check should be performed or not.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
# Example return: {1 {isRequired 0}}
#
proc core::verification::build_check_verification_required args {

	variable CFG

	array set ARGS [core::args::check core::verification::build_check_verification_required {*}$args]

	set fn {core::verification::build_check_verification_required}

	# Build request document
	set doc [dom createDocument checkVerificationRequired]
	$doc encoding utf-8

	set root        [$doc documentElement]
	set config_node [core::xml::add_element -node $root -name verificationConfiguration]

	$config_node setAttribute obAlias $ARGS(-obAlias)

	if {$ARGS(-channel) != {}} {
		$config_node setAttribute channel $ARGS(-channel)
	}

	if {$ARGS(-custId) != {}} {
		set cust_node [core::xml::add_element -node $root -name customer]
		$cust_node setAttribute id $ARGS(-custId)
	}

	set ret [core::verification::send_request -doc $doc -ref checkVerificationRequired]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /checkVerificationRequiredResp]
	set element  [$response getElementsByTagName "isRequired"]

	if {[llength $element] == 0} {
		return [list 0 VG_ERROR_NO_DATA {Verification Gateway returned empty data set}]
	}

	set result [list]

	# Required attributes
	lappend result "result" [$element getAttribute "result" {}]

	# Optional attributes
	if {[$element hasAttribute "reason"]} {
		lappend result "reason" [$element getAttribute "reason" {}]
	}

	if {[$element hasAttribute "lastVerificationId"]} {
		lappend result "lastVerificationId" [$element getAttribute "lastVerificationId" {}]
	}

	return [list 1 $result]
}

core::args::register \
	-proc_name core::verification::build_update_provider_req \
	-args [list \
		[list -arg -providerName -mand 1 -check ASCII              -desc {Name of verification provider}] \
		[list -arg -clientUser   -mand 1 -check ASCII              -desc {Admin user performing the change}] \
		[list -arg -authPort     -mand 0 -check ALNUM -default {}  -desc {New port number to used for authenticatication with the provider}] \
		[list -arg -authUrl      -mand 0 -check ASCII -default {}  -desc {New URL to be used for authenticatication with the provider}] \
		[list -arg -disporder    -mand 1 -check ALNUM              -desc {New display order for the provider}] \
		[list -arg -servicePort  -mand 0 -check UINT  -default {}  -desc {New port number to be used for verification checks}] \
		[list -arg -serviceUrl   -mand 0 -check ASCII -default {}  -desc {New URL to be used for verification checks}] \
		[list -arg -status       -mand 0 -check ALNUM -default {}  -desc {Updated status of the provider}] \
		[list -arg -referenceId  -mand 0 -check ASCII -default {}  -desc {Reference ID}] \
		[list -arg -apiTimeout   -mand 0 -check UINT  -default {}  -desc {API timeout}] \
		[list -arg -passCode     -mand 0 -check ASCII -default {}  -desc {Passcode}] \
	]
#
# This method updates existing provider settings. Only specify
# items, which you intend to change.
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
# Example return: {1 {updateProviderResult Failure}}
#
proc core::verification::build_update_provider_req args {

	variable CFG

	set fn {core::verification::build_update_provider_req}

	array set ARGS [core::args::check core::verification::build_update_provider_req {*}$args]

	# Build request document
	set doc [dom createDocument updateProvider]
	$doc encoding utf-8

	set root [$doc documentElement]

	set verf_provider_node [core::xml::add_element -node $root -name verificationProvider]
	$verf_provider_node setAttribute providerName $ARGS(-providerName)
	$verf_provider_node setAttribute clientUser   $ARGS(-clientUser)
	$verf_provider_node setAttribute disporder    $ARGS(-disporder)

	_set_optional_data \
		$verf_provider_node \
		Attribute \
		[list \
			authPort    $ARGS(-authPort) \
			authUrl     $ARGS(-authUrl) \
			servicePort $ARGS(-servicePort) \
			serviceUrl  $ARGS(-serviceUrl) \
			status      $ARGS(-status) \
			referenceId $ARGS(-referenceId) \
			apiTimeout  $ARGS(-apiTimeout) \
			passCode    $ARGS(-passCode)]

	set ret [core::verification::send_request -doc $doc -ref updateProvider]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc  [lindex $ret 1]
	set root [$doc documentElement]
	set result \
		[$root selectNodes /updateProviderResp/@updateProviderResult]

	return [list 1 $result]
}


core::args::register \
	-proc_name core::verification::build_get_configurations_req \
	-args [list \
		[list -arg -providerName -mand 1 -check ALNUM -desc {Name of verification provider}] \
	]
#
# This method makes a call to the service provider module to request a list of
# the available profiles.
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_get_configurations_req args {

	variable CFG

	array set ARGS [core::args::check core::verification::build_get_configurations_req {*}$args]

	set fn {core::verification::build_get_configurations_req}

	# Build request document
	set doc [dom createDocument getConfigurations]
	$doc encoding utf-8

	set root          [$doc documentElement]
	set provider_node [core::xml::add_element -node $root -name verificationProvider]
	$provider_node setAttribute providerName $ARGS(-providerName)

	set ret [core::verification::send_request -doc $doc -ref getConfigurations]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /getConfigurationsResp]

	set result [list]
	if {$CFG(provider.list.enabled)} {
		# Verification gateway >= 2.1.0.
		foreach check [$response childNodes] {
			lappend result [dict create \
				"providerCheckId"   [$check getAttribute "providerCheckId"   {}] \
				"providerCheckDesc" [$check getAttribute "providerCheckDesc" {}] \
			]
		}
	} else {
		# Verification gateway < 2.1.0
		foreach configuration [$response childNodes] {
			set configuration_data [list]
			lappend configuration_data providerAlias [$configuration getAttribute providerAlias {}]
			lappend configuration_data providerId    [$configuration getAttribute providerId    {}]

			lappend result $configuration_data
		}
	}

	return [list 1 $result]
}


core::args::register \
	-proc_name core::verification::build_list_providers_req \
	-args [list \
		[list -arg -status -mand 0 -check ASCII -default {A} -desc {Status verification provider}] \
	]

#
# The getProviders method returns a list of providers that can perform
# verification.
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_list_providers_req args {

	variable CFG

	set fn {core::verification::build_list_providers_req}

	array set ARGS [core::args::check core::verification::build_list_providers_req {*}$args]

	# Build request document
	set doc [dom createDocument getProviders]
	$doc encoding utf-8

	set root [$doc documentElement]
	$root setAttribute status $ARGS(-status)

	set ret [core::verification::send_request -doc $doc -ref getProviders]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /getProvidersResp]

	set result [list]
	foreach provider [$response childNodes] {
		set configuration_data [list]

		# Ensure that we set all list key-value entries
		foreach el_name {
			providerName \
			clientUser \
			referenceId \
			serviceUrl \
			servicePort \
			authUrl \
			authPort \
			status \
			disporder \
			apiTimeout \
		} {
			lappend configuration_data $el_name [$provider getAttribute $el_name {}]
		}

		lappend result $configuration_data
	}

	return [list 1 $result]
}

core::args::register \
	-proc_name core::verification::build_get_configuration_mappings_req \
	-args [list \
		[list -arg -providerName -mand 1 -check ASCII -desc {Name of verification provider}] \
	]

#
# This method returns the OpenBet alias and the provider configuration name
# for each configuration supported by a given provider.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_get_configuration_mappings_req {args} {

	variable CFG

	set fn {core::verification::build_get_configuration_mappings_req}

	array set ARGS [core::args::check core::verification::build_get_configuration_mappings_req {*}$args]

	# Build request document
	set doc [dom createDocument getConfigurationMappings]
	$doc encoding utf-8

	set root         [$doc documentElement]
	set provider_node [core::xml::add_element -node $root -name verificationProvider]
	$provider_node setAttribute providerName $ARGS(-providerName)

	set ret [core::verification::send_request -doc $doc -ref getConfigurationMappings]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /getConfigurationMappingsResp]

	set result [list]
	foreach configuration [$response childNodes] {
		set configuration_data [list]
		foreach el_name {
			obAlias \
			status \
			disporder \
			channels \
			frequencyType \
			frequencyVal \
			lastUpdated \
		} {
			lappend configuration_data \
				$el_name \
				[$configuration getAttribute $el_name {}]
		}

        	# External client details
        	set ext_client_list [list]
        	foreach conf [$configuration selectNodes externalClient] {
            		set ext_client [dict create]
            		dict set ext_client "systemId" [$conf getAttribute systemId {}]
            		dict set ext_client "userName" [$conf getAttribute userName {}]
            		lappend ext_client_list $ext_client
        	}

        	if {[llength $ext_client_list] > 0} {
            		lappend configuration_data "externalClients"
            		lappend configuration_data $ext_client_list
        	}

		# Provider check aliases
		set check_list [list]
		if {$CFG(provider.list.enabled)} {
			# Verification gateway >= 2.1.0
			foreach conf [$configuration selectNodes providerCheck] {
				set provider_check [dict create]
				dict set provider_check "providerCheckId" [$conf getAttribute providerCheckId {}]
				dict set provider_check "providerCheckDesc" [$conf getAttribute providerCheckDesc {}]
				lappend check_list $provider_check
			}

			if {[llength $check_list] > 0} {
				lappend configuration_data "providerChecks"
				lappend configuration_data $check_list
			}
		} else {
			# Verification gateway < 2.1.0
			lappend check_list providerAlias [$configuration getAttribute providerAlias {}]
			lappend check_list providerId    [$configuration getAttribute providerId    {}]

			# Verification gateway admin expects providerAlias
			# and providerId elements to be single list elements
			# and not to be eclosed in one.
			lappend configuration_data {*}$check_list
		}

		lappend result $configuration_data
	}

	return [list 1 $result]
}

core::args::register \
	-proc_name core::verification::build_bind_configuration_req \
	-args [list \
		[list -arg -providerName      -mand 1 -check ASCII                  -desc {Name of verification provider}] \
		[list -arg -obAlias           -mand 1 -check ASCII                  -desc {Alias of verification profile (internal)}] \
		[list -arg -providerAlias     -mand 0 -check ASCII    -default {}   -desc {Deprecated. Alias of verification profile (from provider configuration). Not to be used in conjuction with providerChecks.}] \
		[list -arg -providerId        -mand 0 -check ASCII    -default {}   -desc {Deprecated. Id of verification profile. Not to be used in conjuction with providerChecks.}] \
		[list -arg -providerChecks    -mand 0 -check ANY      -default {}   -desc {A list of name/providerCheckId pairs in dict form of provider verification profiles. Not to be used in conjuction with providerAlias & providerId.}] \
		[list -arg -status            -mand 0 -check ALNUM    -default {A}  -desc {Profile status}] \
		[list -arg -disporder         -mand 1 -check UINT                   -desc {Display order}] \
		[list -arg -verifyBankDetails -mand 0 -check ASCII    -default {N}  -desc {Flag to allow verification of bank details}] \
		[list -arg -verifyCardDetails -mand 0 -check ASCII    -default {N}  -desc {Flag to allow verification of card details}] \
		[list -arg -channels          -mand 0 -check ASCII    -default {}   -desc {Channels on which the configuration is to be active}] \
		[list -arg -frequencyType     -mand 0 -check ALNUM    -default {}   -desc {Type of frequency check: greater than or less than}] \
		[list -arg -frequencyVal      -mand 0 -check ASCII    -default {}   -desc {Frequency of the check}] \
		[list -arg -lastUpdated       -mand 0 -check ASCII    -default {}   -desc {Last update timestamp to be passed when altering existing configuration}] \
		[list -arg -extra             -mand 0 -check ANY      -default {}   -desc {List of provider specific configurations in name value pairs}] \
		[list -arg -externalClients   -mand 0 -check ANY      -default {}   -desc {A list of userName/systemId pairs in dict form of clients that are allowed to use this configuration}] \
	]

#
# This method creates / updates a link between a provider configuration and
# OpenBet configuration.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
# or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_bind_configuration_req args {

	variable CFG

	set fn {core::verification::build_bind_configuration_req}

	array set ARGS [core::args::check core::verification::build_bind_configuration_req {*}$args]

	if {[llength $ARGS(-extra)] % 2 != 0} {
		core::log::write ERROR {"Unexpected number of elements in extra parameters list: $ARGS(-extra)"}
		return [list 0 VG_ERROR_MANDATORY_FIELD -extra]
	}

	# Checking arguments to be compatible with verification gateway version.
	if {$CFG(provider.list.enabled) == 1 && \
		($ARGS(-providerAlias) != {} || $ARGS(-providerId) != {})} {

		core::log::write ERROR {-providerAlias and -providerId switches cannot \
			be used when provider.list.enabled is enabled.}
		return [list 0 VG_ERROR_MANDATORY_FIELD -providerAlias]
	} elseif {$CFG(provider.list.enabled) == 0 && $ARGS(-providerChecks) != {}} {

		core::log::write ERROR {-providerChecks cannot be used when \
			provider.list.enabled is disabled.}
		return [list 0 VG_ERROR_MANDATORY_FIELD -providerChecks]
	}

	# Build request document
	set doc [dom createDocument bindConfiguration]
	$doc encoding utf-8

	set root [$doc documentElement]

	set provider_node [core::xml::add_element -node $root -name verificationProvider]
	$provider_node setAttribute providerName $ARGS(-providerName)

	set config_node [core::xml::add_element -node $root -name verificationConfiguration]
	$config_node setAttribute obAlias       $ARGS(-obAlias)
	$config_node setAttribute disporder     $ARGS(-disporder)
	$config_node setAttribute status        $ARGS(-status)

	_set_optional_data \
		$config_node \
		Attribute \
		[list \
			verifyBankDetails $ARGS(-verifyBankDetails) \
			verifyCardDetails $ARGS(-verifyCardDetails) \
			channels          $ARGS(-channels) \
			frequencyType     $ARGS(-frequencyType) \
			frequencyVal      $ARGS(-frequencyVal) \
			lastUpdated       $ARGS(-lastUpdated)]

	foreach {name value} $ARGS(-extra) {
		if {$name != {} && $value != {}} {
			set extraNode [core::xml::add_element -node $config_node -name extraConfiguration]
			$extraNode setAttribute name  $name
			$extraNode setAttribute value $value
		}
	}

	# Provider checks.
	if {$CFG(provider.list.enabled)} {
		# Verification gateway >= 2.1.0.
		foreach provider_check $ARGS(-providerChecks) {
			set checkNode [core::xml::add_element -node $config_node -name providerCheck]
			if {[dict exists $provider_check "providerCheckId"]} {
				$checkNode setAttribute providerCheckId [dict get $provider_check "providerCheckId"]
			}
		}
	} else {
		# Verification gateway < 2.1.0.
		$config_node setAttribute providerAlias $ARGS(-providerAlias)
		$config_node setAttribute providerId    $ARGS(-providerId)
	}

	foreach ext_client $ARGS(-externalClients) {
		set clientNode [core::xml::add_element -node $config_node -name externalClient]
		if {[dict exists $ext_client "userName"]} {
			$clientNode setAttribute userName [dict get $ext_client "userName"]
		}
		if {[dict exists $ext_client "systemId"]} {
			$clientNode setAttribute systemId [dict get $ext_client "systemId"]
		}
	}

	set ret [core::verification::send_request -doc $doc -ref bindConfiguration]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set result \
		[lindex [$root selectNodes /bindConfigurationResp/@bindConfigurationResult] 0]

	core::log::write DEBUG {$fn: bindConfigurationResp node contained \
		attribute bindConfigurationResultresult=$result.}

	return [list 1 [lindex $result 1]]
}

core::args::register \
	-proc_name core::verification::build_get_verification_reference_req \
	-args [list \
		[list -arg -custIdList -mand 1 -check ASCII  -desc {List of customers to reference}] \
	]
#
# This method returns list of verification results returned by a verification
# service provider in the response to each verification attempt.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_get_verification_reference_req args {

	variable CFG

	set fn {core::verification::build_get_verification_reference_req}

	array set ARGS [core::args::check core::verification::build_get_verification_reference_req {*}$args]

	# Build request document
	set doc [dom createDocument getVerificationReference]
	$doc encoding utf-8

	set root [$doc documentElement]

	foreach custId $ARGS(-custIdList) {
		set cust_node [core::xml::add_element -node $root -name cust]
		$cust_node setAttribute id $custId
	}

	set ret [core::verification::send_request -doc $doc -ref getVerificationReference]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes /getVerificationReferenceResp]

	set result [list]
	foreach verification_result [$response childNodes] {
		set verification_info [list]

		set verification_status ""
		if {$CFG(status.list.enabled)} {
			set verification_status [dict create]
		}

		# Ensure that we set all list key-value entries
		foreach el_name {
			cust \
			verificationDateTime \
			verificationStatus \
			verificationReference \
			verificationText \
			verificationFlag \
			verificationFlagDesc \
		} {
			set element [$verification_result getElementsByTagName $el_name]

			switch $el_name {
				{cust}    {
					lappend verification_info $el_name \
						[$element getAttribute id {}]
				}
				{verificationStatus} {
					if {$CFG(status.list.enabled)} {
						# Verification gateway >= 2.1.0.

						# There can be multiple of these, so we build a dict using the check names as keys
						for {set i 0} {$i < [llength $element]} {incr i} {

							set status_elem [lindex $element $i]
							if {$status_elem != ""} {
								dict set verification_status [$status_elem getAttribute check {}] [$status_elem asText]
							}
						}
					} else {
						# Verification gateway < 2.1.0.
						if {$element != ""} {
							set verification_status [$element asText]
						}
					}
				}
				{default} {
					if {$element != ""} {
						lappend verification_info $el_name [$element asText]
					} else {
						lappend verification_info $el_name ""
					}
				}
			}
		}

		lappend verification_info "verificationStatus" $verification_status

		lappend result $verification_info
	}

	return [list 1 $result]
}


core::args::register \
	-proc_name core::verification::build_get_verification_reference_details_req \
	-args [list \
		[list -arg -providerName          -mand 1 -check ASCII              -desc {Name of verification provider}] \
		[list -arg -dateFrom              -mand 0 -check ASCII              -desc {Earlies date boundary}] \
		[list -arg -dateTo                -mand 0 -check ASCII              -desc {Latest date boundary}] \
		[list -arg -custId                -mand 0 -check STRING -default {} -desc {The customer Ids to search}] \
		[list -arg -verificationId        -mand 0 -check ALNUM  -default {} -desc {The verification request Ids to search}] \
		[list -arg -verificationStatus    -mand 0 -check STRING -default {} -desc {Status of the check, e.g. VERIFIED, REFERRED or ERROR}] \
		[list -arg -verificationReference -mand 0 -check STRING -default {} -desc {Verification reference, e.g. tracking number}] \
		[list -arg -verificationText      -mand 0 -check STRING -default {} -desc {Verification text}] \
		[list -arg -verificationFlag      -mand 0 -check STRING -default {} -desc {Verification flag}] \
		[list -arg -verificationFlagDesc  -mand 0 -check STRING -default {} -desc {Description of the verification flag}] \
		[list -arg -verificationChannel   -mand 0 -check ASCII  -default {} -desc {Verification channel}] \
		[list -arg -extra                 -mand 0 -check ANY    -default {} -desc {List of provider specific configurations in name value pairs}] \
	]

#
# This method allows searching previous verification results based on
# various criteria passed in the args. The search can return multuple
# results.
#
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{name value name1 value1...} {...}}}
#
proc core::verification::build_get_verification_reference_details_req args {

	variable CFG
	variable CUSTDATA

	array set ARGS [core::args::check core::verification::build_get_verification_reference_details_req {*}$args]

	set fn {core::verification::build_get_verification_reference_details_req}

	if {[llength $ARGS(-extra)] % 2 != 0} {
		core::log::write ERROR {Unexpected number of elements in extra parameters list: $ARGS(-extra)}
		return [list 0 VG_ERROR_MANDATORY_FIELD extra]
	}

	# Build request document
	set doc [dom createDocument getVerificationReferenceDetails]
	$doc encoding utf-8

	set root [$doc documentElement]

	set provider_node [core::xml::add_element -node $root -name verificationProvider]
	$provider_node setAttribute providerName $ARGS(-providerName)

	if {$ARGS(-dateFrom) != {} && $ARGS(-dateTo) != {}} {
		set dateNode [core::xml::add_element -node $root -name dateRange]
		$dateNode setAttribute dateFrom $ARGS(-dateFrom)
		$dateNode setAttribute dateTo   $ARGS(-dateTo)
	}

	foreach custId $ARGS(-custId) {
		set customerNode [core::xml::add_element -node $root -name customer]
		$customerNode setAttribute id $custId
	}

	set verificationNode [core::xml::add_element -node $root -name verificationResult]

	foreach verificationId $ARGS(-verificationId) {
		set verificationIdNode  [core::xml::add_element \
			-node  $verificationNode \
			-name  verificationId \
			-value $verificationId]

	}

	 foreach verificationStatus $ARGS(-verificationStatus) {
		 set verificationStatusNode  [core::xml::add_element \
			-node  $verificationNode \
			-name  verificationStatus \
			-value $verificationStatus]
	 }

	foreach verificationReference $ARGS(-verificationReference) {
		set verificationReferenceNode [core::xml::add_element \
			-node  $verificationNode \
			-name  verificationReference \
			-value $verificationReference]
	}

	foreach verificationText $ARGS(-verificationText) {
		set verificationTextNode [core::xml::add_element \
			-node  $verificationNode \
			-name  verificationText \
			-value $verificationText]
	}

	_set_optional_data \
		$verificationNode \
		Node \
		[list \
			verificationFlag      $ARGS(-verificationFlag) \
			verificationFlagDesc  $ARGS(-verificationFlagDesc) \
			verificationChannel   $ARGS(-verificationChannel)]


	foreach {name value} $ARGS(-extra) {
		if {$name != {} && $value != {}} {
			set extraNode [core::xml::add_element -node $root -name extraDetails]
			$extraNode setAttribute name  $name
			$extraNode setAttribute value $value
		}
	}

	set ret [core::verification::send_request -doc $doc -ref getVerificationReferenceDetails]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc    [lindex $ret 1]
	set root   [$doc documentElement]
	set result [list]

	# Search may return multiple "searchResult" nodes
	foreach result_node [$root selectNodes /getVerificationReferenceDetailsResp/searchResult] {

		set result_item    [list]
		set result_details [$result_node getElementsByTagName "resultDetail"]

		foreach detail $result_details {
			lappend result_item [$detail getAttribute name  {}]
			lappend result_item [$detail getAttribute value {}]
		}

		if {[llength $result_item] > 0 } {
			lappend result $result_item
		}
	}

	return [list 1 $result]
}


core::args::register \
	-proc_name core::verification::build_get_configuration_detail_req \
	-args [list \
		[list -arg -obAlias -mand 1 -check ASCII  -desc {The verification profile to be used}] \
	]

#
# This method returns the details of a verification configuration.
#
# args:   see $arg_list below
#
# return: list in form of {0 ERROR_CODE Error_description}
#         or {1 {{key value key1 value1...} {...}}}
#
proc core::verification::build_get_configuration_detail_req args {

	variable CFG

	set fn {core::verification::build_get_configuration_detail_req}

	array set ARGS [core::args::check core::verification::build_get_configuration_detail_req {*}$args]

	# Build request document
	set doc [dom createDocument getConfigurationDetail]
	$doc encoding utf-8

	set root [$doc documentElement]

	set config_node [core::xml::add_element -node $root -name verificationConfiguration]
	$config_node setAttribute obAlias $ARGS(-obAlias)

	set ret [core::verification::send_request -doc $doc -ref getConfigurationDetail]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc      [lindex $ret 1]
	set root     [$doc documentElement]
	set response [$root selectNodes \
		/getConfigurationDetailResp/verificationConfiguration]

	if {$response == ""} {
		return [list 0 VG_ERROR_NO_DATA {Verification Gateway returned empty data set}]
	}

	set result [list]

	# Ensure, that we set all list key-value entries
	foreach el_name {
		obAlias \
		status \
		disporder \
		verifyBankDetails \
		verifyCardDetails \
		channels \
		frequencyType \
		frequencyVal \
		lastUpdated \
	} {
		lappend result $el_name [$response getAttribute $el_name {}]
	}

	# External client details
	set ext_client_list [list]
	foreach conf [$root selectNodes /getConfigurationDetailResp/verificationConfiguration/externalClient] {
		set ext_client [dict create]
		dict set ext_client "systemId" [$conf getAttribute systemId {}]
		dict set ext_client "userName" [$conf getAttribute userName {}]
		lappend ext_client_list $ext_client
	}

	if {[llength $ext_client_list] > 0} {
		lappend result "externalClients"
		lappend result $ext_client_list
	}

	# Provider check aliases
	set check_list [list]
	if {$CFG(provider.list.enabled)} {
		# Verification gateway >= 2.1.0.
		foreach conf [$root selectNodes /getConfigurationDetailResp/verificationConfiguration/providerCheck] {
			set provider_check [dict create]
			dict set provider_check "providerCheckId"   [$conf getAttribute providerCheckId {}]
			dict set provider_check "providerCheckDesc" [$conf getAttribute providerCheckDesc {}]
			lappend check_list $provider_check
		}

		if {[llength $check_list] > 0} {
			lappend result "providerChecks"
			lappend result $check_list
		}
	} else {
		# Verification gateway < 2.1.0.
		lappend check_list providerAlias [$response getAttribute providerAlias {}]
		lappend check_list providerId    [$response getAttribute providerId    {}]

		lappend result $check_list
	}

	return [list 1 $result]
}

core::args::register \
	-proc_name core::verification::build_get_response_texts_req \
	-args [list \
		[list -arg -providerName -mand 1 -check ASCII  -desc {Name of verification provider}] \
	]

# Call to get verification response texts (verificationText)
# for a provider
#
# Returns:
#    [list] - 0|1 {[list]}
#
proc core::verification::build_get_response_texts_req args {

	variable CFG

	array set ARGS [core::args::check core::verification::build_get_response_texts_req {*}$args]

	# Build request document
	set doc [dom createDocument getDistinctResponseTexts]
	$doc encoding utf-8

	set root         [$doc documentElement]
	set provider_node [core::xml::add_element -node $root -name verificationProvider]
	$provider_node setAttribute providerName $ARGS(-providerName)

	set ret [core::verification::send_request -doc $doc -ref getDistinctResponseTexts]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc     [lindex $ret 1]
	set root    [$doc documentElement]
	set results [list]

	foreach {result_node} [$root selectNodes /getDistinctResponseTextsResp/responseText] {
		set node_value [$result_node asText]
		if {[string length $node_value] > 0} {
			lappend results $node_value
		}
	}

	return [list 1 {responseText} $results]
}

core::args::register \
	-proc_name core::verification::build_update_external_verification_details_req \
	-args [list \
		[list -arg -verf_id -mand 1 -check ASCII  -desc {Verification request Id}] \
		[list -arg -ext_ref_id -mand 1 -check ASCII  -desc {External Provider Id}] \
		[list -arg -cust_id -mand 1 -check ASCII  -desc {Customer Id}] \
		[list -arg -ext_provider_name -mand 0 -check ASCII  -desc {External provider name}] \
	]

# Call to link a verificationId to an External Provider
#
# Returns:
#    [list] - 0|1 {[list]}
#
proc core::verification::build_update_external_verification_details_req args {

	variable CFG

	array set ARGS [core::args::check core::verification::build_update_external_verification_details_req {*}$args]

	set fn {core::verification::build_update_external_verification_details_req}

	# Build request document
	set doc [dom createDocument updateExternalVerificationDetails]
	$doc encoding utf-8

	set root [$doc documentElement]

	core::xml::add_element \
		-node  $root \
		-name  verificationId \
		-value $ARGS(-verf_id)

	core::xml::add_element \
		-node  $root \
		-name  externalProviderName \
		-value $ARGS(-ext_provider_name)

	core::xml::add_element \
		-node  $root \
		-name  externalReferenceId \
		-value $ARGS(-ext_ref_id)

	[core::xml::add_element \
		-node  $root \
		-name  cust] setAttribute id $ARGS(-cust_id)

	set ret [core::verification::send_request -doc $doc -ref updateExternalVerificationDetails]
	if {![lindex $ret 0]} {
		return $ret
	}

	set doc    [lindex $ret 1]
	set root   [$doc documentElement]
	set result [lindex [$root selectNodes /updateExternalVerificationDetailsResp/@updateExternalVerificationDetailsResult] 0]
	set reason [lindex [$root selectNodes /updateExternalVerificationDetailsResp/@reason] 0]

	return [list 1 [lindex $result 1] [lindex $reason 1]]
}

# Call to get address references for search string 

core::args::register \
	-return_data [list \
		[list -arg -address_suggestion_list -mand 1 -check ASCII  -desc {The unique reference for the matched address or empty list if not matched}] \
	] \
	-proc_name core::verification::build_get_customer_address_reference_req \
	-args [list \
		[list -arg -search        -mand 1 -check STRING                    -desc {The string for which the address is to be searched against}] \
		[list -arg -provider_name -mand 0 -check STRING  -default experian -desc {The provider to be used for address search}] \
	] \
	-errors [list VG_ERROR_SEND_REQ INTERNAL_ERROR] \
	-body {
		set fn {core::verification::build_get_customer_address_reference_req}
		
		# Build request document
		set doc [dom createDocument getCustomerAddressReference]
		$doc encoding utf-8

		set root [$doc documentElement]
		$root setAttribute search $ARGS(-search)
		$root setAttribute providerName $ARGS(-provider_name)

		core::log::write INFO {$fn: Sending request to VG for address search string $ARGS(-search)}
		set ret [core::verification::send_request -doc $doc -ref getCustomerAddressReference]
		if {![lindex $ret 0]} {
			core::log::write ERROR {$fn: VG Request failed}
			error {VG Request failed} {} VG_ERROR_SEND_REQ
		}

		set doc      [lindex $ret 1]
		set root     [$doc documentElement]
		set response [$root selectNodes /getCustomerAddressReferenceResp]

		set address_suggestion_list [list]

		foreach address_suggestion_node [$response childNodes] {
			set address_suggestion [dict create]

			# Ensure that we set all list key-value entries
			foreach attribute_name {
				addressReference
				addressPickList
				partialAddress
			} {
				dict set address_suggestion $attribute_name [$address_suggestion_node getAttribute $attribute_name {}]
			}

			lappend address_suggestion_list $address_suggestion
		}

		return [dict create -address_suggestion_list $address_suggestion_list] 
	}
	
# Call to get the address for the address reference returned from core::verification::build_get_customer_address_reference_req

core::args::register \
	-return_data  [list \
		[list -arg -flat_number     -mand 1 -check ASCII   -desc {Flat Number}] \
		[list -arg -house_name      -mand 1 -check STRING  -desc {House Name}] \
		[list -arg -house_number    -mand 1 -check ASCII   -desc {House Number}] \
		[list -arg -street          -mand 1 -check ASCII   -desc {Street}] \
		[list -arg -city            -mand 1 -check STRING  -desc {City}] \
		[list -arg -state           -mand 1 -check STRING  -desc {State}] \
		[list -arg -postcode        -mand 1 -check STRING  -desc {Post Code}] \
    ] \
	-proc_name core::verification::build_get_customer_address_for_address_reference_req \
	-args [list \
		[list -arg -address_reference -mand 1 -check STRING  -desc {The pointer to the required address from a list of previously suggested addresses}] \
		[list -arg -provider_name     -mand 0 -check STRING  -default experian -desc {The provider to be used for address search}] \
	] \
	-errors [list VG_ERROR_SEND_REQ INTERNAL_ERROR VG_ERROR_ADDRESS_NOT_FOUND] \
	-body {
		set fn {core::verification::build_get_customer_address_for_address_reference_req}

		# Build request document
		set doc [dom createDocument getCustomerAddressForAddressReference]
		$doc encoding utf-8

		set root [$doc documentElement]
		$root setAttribute addressReference $ARGS(-address_reference)
		$root setAttribute providerName $ARGS(-provider_name)

		core::log::write INFO {$fn: Sending request to VG for address retrieval for address reference $ARGS(-address_reference)}
		set ret [core::verification::send_request -doc $doc -ref getCustomerAddressForAddressReference]
		if {![lindex $ret 0]} {
			core::log::write ERROR {$fn: VG Request failed}
			error {VG Request failed} {} VG_ERROR_SEND_REQ
		}

		set doc      [lindex $ret 1]
		set root     [$doc documentElement]
		set response [$root selectNodes /getCustomerAddressForAddressReferenceResp]

		set address_returned 0

		foreach customer_address_node [$response childNodes] {
			set address_returned 1

			set customer_address [dict create]

			foreach {attribute_name arg} {
				flatNumber  flat_number
				houseName   house_name
				houseNumber house_number
				street      street
				city        city
				state       state
				zip         postcode
			} {
				dict set customer_address -$arg [$customer_address_node getAttribute $attribute_name {}]
			}
		}

		if {!$address_returned} {
			core::log::write ERROR {$fn: VG did not return an address for the address reference}
			error {Address not found} {} VG_ERROR_ADDRESS_NOT_FOUND
		}

		return $customer_address
	}


# Call to get address references for search string.
# Added for backward compatiblity with OXi.
#
# return: returns one of the following:-
#    [list FULL_ADDRESS [list $moniker $partial_address]]
#    [list MULTIPLE [list \
#       [list $moniker $partial_address] \
#       [list $moniker $partial_address] \
#		]
#    ]
#    [list ERROR]

core::args::register \
	-proc_name core::verification::qas_do_singleline_search \
	-args [list \
		[list -arg -house_number -mand 0 -check ASCII -default {} -desc {The house name of the address to be searched}] \
		[list -arg -postcode     -mand 1 -check ASCII             -desc {The postcode of the address to be searched}] \
	] \
	-body {
		set fn {core::verification::qas_do_singleline_search}
		
		if {$ARGS(-house_number) != {}} {
			set search "$ARGS(-house_number)|$ARGS(-postcode)"
		} else {
			set search $ARGS(-postcode)
		}

		if {[catch {set result [core::verification::build_get_customer_address_reference_req -search $search]} msg]} {
			return [list ERROR $msg]
		}

		set no_address_references [llength [dict get $result -address_suggestion_list]]

		if {$no_address_references == 0} {
			return [list ERROR "No address references found"]
		}

		if {$no_address_references == 1} {
			set address_reference [dict get [lindex [dict get $result -address_suggestion_list] 0] addressReference]
			set partial_address   [dict get [lindex [dict get $result -address_suggestion_list] 0] partialAddress]
			if { $address_reference != {} && $partial_address != {}} {
				return [list \
					FULL_ADDRESS \
					[list \
						$address_reference \
						$partial_address \
					]
				]
			} else {
				return [list \
							ERROR \
							[dict get \
								[lindex [dict get $result -address_suggestion_list] 0] \
								addressPickList \
							] \
						]
			}
			
		}

		set address_reference_list [list]
		for {set i 0} {$i < $no_address_references} {incr i} {
			set address_reference \
				[list \
					[dict get [lindex [dict get $result -address_suggestion_list] $i] addressReference] \
					[dict get [lindex [dict get $result -address_suggestion_list] $i] partialAddress] \
				]

			lappend address_reference_list $address_reference
		}

		return [list MULTIPLE $address_reference_list] 
	}

# Call to get the address for a given address reference
# Added for backward compatiblity with OXi.
#
# return: Array of address lines
#
core::args::register \
	-proc_name core::verification::qas_do_get_address \
	-args [list \
		[list -arg -address_reference -mand 1 -check ASCII  -desc {The pointer to the required address from a list of previously suggested addresses}] \
	] \
	-errors [list VG_ERROR_SEND_REQ INTERNAL_ERROR VG_ERROR_ADDRESS_NOT_FOUND] \
	-body {
		set fn {core::verification::qas_do_get_address}

		set result [core::verification::build_get_customer_address_for_address_reference_req -address_reference $ARGS(-address_reference)]

		array set ADDR [list]

		foreach {array_index arg} {
			1  -street
			2  -city
			3  -state
			4  -postcode
			5  -flat_number
		} {
				set ADDR($array_index) [dict get $result $arg]
		}

		set house_number [string trim [dict get $result -house_number]]

		# we give more priority to house number, if this does not exist return house name. 
		if { $house_number != {}} {
			set ADDR(0) $house_number
		} else {
			set ADDR(0) [string trim [dict get $result -house_name]]
		}

		# Return address
		return [array get ADDR]
	}
	

core::args::register \
	-proc_name core::verification::send_request \
	-args [list \
		[list -arg -doc -mand 1 -check ALNUM  -desc {XML document reference to send}] \
		[list -arg -ref -mand 1 -check ASCII  -desc {Object reference name}] \
	]

#
# Sends REST request and returns XML response or error message on error
#
# @return list in form of {0 ERROR_CODE} or {1 "xml_data"}
#
proc core::verification::send_request args {

	variable CFG

	array set ARGS [core::args::check core::verification::send_request {*}$args]

	set doc  $ARGS(-doc)
	set ref  $ARGS(-ref)
	set root [$doc documentElement]

	set fn {core::verification::send_request}

	set request_xml "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n[$root asXML]"

	$doc delete

	foreach line [split $request_xml \n] {
		core::log::write INFO {REQ $line}
	}

	if {![info exists CFG(url,$ref)]} {
		return [list 0 VG_ERROR_SEND_REQ "Unknown reference $ref"]
	}

	if {[catch {
		set req [core::socket::format_http_req \
			-host       $CFG(service_host) \
			-method     "POST" \
			-headers    [list Content-Type application/xml] \
			-post_data  $request_xml \
			-url        $CFG(url,$ref) \
			-encoding   utf-8]
	} msg]} {
		core::log::write ERROR {$fn Unable to build verification request: $msg}
		return [list 0 VG_ERROR_SEND_REQ]
	}

	set args [list -is_http 1]
	lappend args -conn_timeout $CFG(conn_timeout)
	lappend args -req_timeout  $CFG(req_timeout)

	if {$CFG(use_ssl)} {
		lappend args -tls {}
	}

	lappend args \
		-req  $req \
		-host $CFG(service_host) \
		-port $CFG(service_port) \
		-encoding utf-8

	# Send the request to the verification module
	if {[catch {
		foreach {req_id status complete} \
		[core::socket::send_req {*}$args] {break}
	} msg]} {
		core::log::write ERROR {$fn Unexpected error contacting Verification module: $msg}
		return [list 0 VG_ERROR_SEND_REQ]
	}

	# get response
	set response [string trim [core::socket::req_info \
		-req_id $req_id \
		-item http_body]]

	core::socket::clear_req -req_id $req_id

	if {$status != "OK"} {
		set desc [_extract_http_error_desc $response]
		core::log::write ERROR {$fn Server returned error: $status : $desc}
		return [list 0 VG_ERROR_SEND_REQ $desc]
	}

	set ret [core::xml::parse -xml $response -strict 0]
	if {[lindex $ret 0] != {OK}} {
		core::log::write ERROR {$fn xml parsing failed: $msg}
		return [list 0 VG_ERROR_XML_PARSING $msg]
	}

	set doc [lindex $ret 1]

	foreach line [split $response \n] {
		core::log::write INFO {RESP $line}
	}

	return [list 1 $doc $response]
}

#
# Retrieve bank account data from the database and save it to the CCDATA array.
#
# cust_id: customer id
#
# return: 0 on error, 1 on success
#
proc core::verification::_get_bank_acc_data {cust_id} {
	variable BANKDATA
	variable CFG

	if {!$CFG(enable_ba_data)} {
		core::log::write INFO {core::verification::_get_bank_acc_data VG_ENABLE_BA_DATA disabled}
		return 0
	}

	if {[catch {set rs [core::db::exec_qry \
		-name core::verification::bank_acc_data_stmt \
		-args [list $cust_id]]
	} msg]} {
		core::log::write ERROR \
			{Failed to retrieve bank account details for cust ${cust_id}: $msg}
		return 0
	}

	if {$rs == 0} {
		core::log::write ERROR \
			{Failed to retrieve bank account details for cust ${cust_id}.}
		return 0
	}

	if {[db_get_nrows $rs] > 0} {
		set BANKDATA(bank_acct_no)   [db_get_col $rs 0 bank_acct_no]
		set BANKDATA(bank_sort_code) [db_get_col $rs 0 bank_sort_code]

		set result 1
	} else {
		# No bank account data found
		set result 0
	}

	catch {core::db::rs_close -rs $rs}
	return $result
}

core::args::register \
	-proc_name core::verification::resolve_address \
	-args [list \
		[list -arg -address1 -mand 1 -check STRING             -desc {Address field 1}] \
		[list -arg -address2 -mand 1 -check STRING             -desc {Address field 2}] \
		[list -arg -address3 -mand 1 -check STRING             -desc {Address field 3}] \
		[list -arg -address4 -mand 1 -check STRING             -desc {Address field 4}] \
		[list -arg -postcode -mand 1 -check STRING             -desc {Postcode}] \
		[list -arg -city     -mand 1 -check STRING             -desc {City}] \
		[list -arg -county   -mand 0 -check STRING -default {} -desc {County mapped to state}] \
		[list -arg -country  -mand 1 -check STRING             -desc {Country}] \
	]

#
# Naive implementation of address resolver callback
#
# @param -address1 addr_street_1 db field
# @param -address2 addr_street_2 db field
# @param -address3 addr_street_3 db field
# @param -address4 addr_street_4 db field
# @param -postcode addr_postcode db field
# @param -city     addr_city db field
# @param -county   addr_county db field
# @param -country  addr_country db field
#
# @return  : dict: {flat_number "" house_name "" house_number "" street ""
#                  district "" zip "" city "" state "" country ""}
#
proc core::verification::resolve_address args {

	array set ARGS [core::args::check core::verification::resolve_address {*}$args]

	set house_name {}
	set house_number {}

	set add1 [string trim $ARGS(-address1)]
	if {$add1 != {} && [ core::check::exp $add1 {^\d}] } {
		set house_number $add1
	} else {
		set house_name   $add1
	}

	return [dict create \
		full_address {}        \
		flat_number  $ARGS(-address2) \
		house_name   $house_name      \
		house_number $house_number    \
		street       $ARGS(-address3) \
		district     $ARGS(-address4) \
		zip          $ARGS(-postcode) \
		city         $ARGS(-city)     \
		state        {}               \
		country      $ARGS(-country)  \
		ireland_county_name {}        \
		ireland_county_code {}        \
	]
}

proc core::verification::_extract_http_error_desc {response} {

	set desc {}
	if {[catch {regexp {<h1>(.*?)</h1>} $response match desc} msg]} {
		core::log::write ERROR {Cannot parse server error response: $msg}
		return NA
	}
	if {$desc == {}} {
		if {[catch {regexp {^[^<]+$} $response desc} msg]} {
			core::log::write ERROR {Cannot parse server error response: $msg}
			return NA
		}
	}

	return $desc

}

# The following is a skeleton example of a personal data callback
proc core::verification::_modify_cust_data RAWCUSTDATA {
	array set LOCALDATA $RAWCUSTDATA

	# code to modify LOCALDATA elements as required

	return [array get LOCALDATA]
}

# Appends data items to the XML node, skipping optional and unset ones.
# Data can be appended as attributes of the node or as child nodes.
# To be called from inside "build_<%request_name%>_req" procedures after
# setting the arg_list variables
#
# args:
# @param node     The XML node to append data to
# @param type     Attribute | Node - how the items should be appended
# @param arg_list Name value pairs of optional information
#
# @return  Nothing, although the passed in node is modified
proc core::verification::_set_optional_data {node type arg_list} {
	foreach {name value} $arg_list {
		if {$value == {}} {
			continue
		}

		switch $type {
			Attribute {
				$node setAttribute [_get_xml_name $name] $value
			}
			Node {
				core::xml::add_element \
					-node  $node \
					-name  [_get_xml_name $name] \
					-value $value
			}
			default {
				core::log::write ERROR {"core::verification::_set_optional_data invalid 'type' argument: " $type}
			}
		}
	}
}



# This is (another) helper proc to map param names to
# XML attribute names.
# e.g. custId -> id
#
proc core::verification::_get_xml_name {param_name} {

	variable XML_ATTR_MAPPINGS

	if {[info exists XML_ATTR_MAPPINGS($param_name)]} {
		return $XML_ATTR_MAPPINGS($param_name)
	}

	return $param_name
}
