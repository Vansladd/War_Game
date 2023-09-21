# ==============================================================================
# $Id: aff_utd.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# aff_utd.tcl: A shared library for dealing with Affiliates United registrations.
#
# procs:	init - initialises
#			_prepare_queries   - sets up SQL statements.
#			get                - returns a value from the variable array
#								 CREFERER_VALS.
#			set_creferer_vals - sets the CREFERER_VAL values from either POST,
#								 a cookie or OXi xml.
#			au_tag_customer   - tags a customer with affiliate data in the db.
#			do_aff_utd         - calls au_tag_customer for affiliates united
#								 registrations.
#			do_OXi           - calls set_creferer_vals and do_aff_utd
#								 for OXi registrations.
#
# (C) 2009 Orbis Technology Ltd. All rights reserved.
# ==============================================================================

namespace eval aff_utd {

	variable CREFERER_VALS
	variable CFG
}

proc aff_utd::init args {

	variable CFG

	set CFG(banner_cookie_name)   [OT_CfgGet AU_BANNER_COOKIE "banner_click"]
	set CFG(download_cookie_name) [OT_CfgGet DL_BANNER_COOKIE "banner_download"]

	_prepare_queries

}


proc aff_utd::_prepare_queries {} {

	# Tag a customer with an Affiliates United banner
	ob_db::store_qry aff_utd::add_au_banner_tag {
		insert into
			tAUCust (
				cust_id,
				xsys_promo_code,
				advertiser,
				bannerid,
				profileid,
				refererurl,
				admap,
				affiliate_id,
				channel,
				promo_code_passed,
				time,
				zone,
				creferer
			)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	}

	# Tag just the temp values for a customer AU banner
	ob_db::store_qry aff_utd::add_au_temp {
		insert into tAUCustParamTemp (
			cust_id,
			value,
			temp_num
		)
		values ( ?, ?, ? )
	}

	# Looks for a user entered promo code in the db
	ob_db::store_qry aff_utd::find_promo_code {
		select
			a.advertiser,
			p.override
		from
			tAUPromo p,
			tAUAdvertiser a
		where
			promo_code = ? and
			a.adv_id = p.adv_id
	}

	ob_db::store_qry aff_utd::get_product_source_value {
		select
			product_source
		from
			tProductSource
		where
			product_source = ?
	}
}



#
# Attempts to get a value from CREFERER_VALS
#
proc aff_utd::get arg {

	variable CREFERER_VALS

	if {[info exists CREFERER_VALS($arg)]} {
		return $CREFERER_VALS($arg)
	} else {
		ob_log::write ERROR {aff_utd::get: Couldn't retrieve CREFERER_VALS($arg),\
								as it doesn't exist}
		return ""
	}
}


#
# Sets the crefer values (and other Affiliates United parameters) in
# CREFERER_VALS.  First of all attempts to get the POST values, then if that
# fails tries to get values from banner_click cookie.  Failing this, it sets
# CREFERER_VALS to hold "" except for promo_code which is set to the
# user_promo.  Note that POST values take precedence over cookie values when
# registration is done from the sportsbook and the download cookie takes precendence
# over the banner_click cookie.
#
# user_promo - the promotional code entered on the registration screen.
#              If this isn't the same as the OXi/POST/cookie value, then only the
#              promotional code is set.
#
# aff_string - xml string passed in from oxifeed registrations.  Blank for sb
# 			   registrations, but if there is any value here it won't check
#              request arguments or the cookie
#
# returns    - 1 if OXi/POST/cookie data has been found, 0 otherwise
#
proc aff_utd::set_creferer_vals { {user_promo ""} {aff_string ""} } {

	variable CFG
	variable CREFERER_VALS

	# Reset the array
	ob_gc::add aff_utd::CREFERER_VALS

	ob_log::write INFO {aff_utd::set_creferer_vals user_promo: $user_promo, aff_string: $aff_string}

	# To determine whether we've got anything from POST
	set params_exist  0
	set parameters    [list]
	set banner_cookie ""

	if {$aff_string != ""} {

		ob_log::write INFO {aff_utd::set_creferer_vals: OXi registration: getting\
								values from xml string}

		set params_exist 1

		# Split xml string by commas
		set parameters [split $aff_string ","]

	} else {

		foreach {p} {
			advertiser
			bannerid
			profileid
			refererurl
		} {
			set CREFERER_VALS($p) [string range [ob_chk::get_arg $p -on_err "" SAFE] 0 99]
			if {$CREFERER_VALS($p) != ""} {
				set params_exist 1
			}
		}

		# Get creferer as unsafe
		set CREFERER_VALS(creferer) ""
		set creferer [ob_chk::get_arg creferer -unsafe -on_err "" \
										{RE -args {[^[:cntrl:]]}}]

		set x [regsub -all {[\[\]\\{}\$]} $creferer {} CREFERER_VALS(creferer)]

		if {$CREFERER_VALS(creferer) != ""} {
			set params_exist 1
		}
	}

	set p_len [llength $parameters]

	# Do we have parameters?  If not, need to try and get cookie. Look for
	# download cookie first and then banner_click cookie
	if {!$params_exist && [llength $parameters] == 0} {
		ob_log::write INFO {aff_utd::set_creferer_vals: No POST values found, checking cookie}
		if {[set banner_cookie [ob_util::get_cookie $CFG(download_cookie_name)]] != ""} {
			ob_log::write INFO {aff_utd::set_creferer_vals: \
						$CFG(download_cookie_name) cookie found, retrieving values}

			set params_exist 1

			# Split cookie value by commas
			set parameters [split $banner_cookie ","]

		} elseif {[set banner_cookie [ob_util::get_cookie $CFG(banner_cookie_name)]] != ""} {
			ob_log::write INFO {aff_utd::set_creferer_vals: \
				$CFG(banner_cookie_name) cookie found, retrieving values}

			set params_exist 1

			# Split cookie value by commas
			set parameters [split $banner_cookie ","]
		}

	} else {
		ob_log::write INFO {aff_utd::set_creferer_vals: POST values found}
	}

	# If we've got parameters from a cookie or from the aff_utd parameter,
	# fill CREFERER_VALS
	if {[llength $parameters] != 0} {

		# Trim to 100 characters as can't store more in DB (except
		# creferer, which we split up later)
		if {[llength $parameters] == 5} {
			set CREFERER_VALS(advertiser) [string range [lindex $parameters 0] 0 99]
			set CREFERER_VALS(bannerid)   [string range [lindex $parameters 1] 0 99]
			set CREFERER_VALS(profileid)  [string range [lindex $parameters 2] 0 99]
			set CREFERER_VALS(refererurl) [string range [lindex $parameters 3] 0 99]
			set CREFERER_VALS(creferer)   [lindex $parameters 4]
		} else {
			ob_log::write WARNING {aff_utd::set_creferer_vals: WARNING - \
				incorrect number of parameters in cookie, blanking values}
			ob_log::write WARNING {aff_utd::set_creferer_vals: Cookie \
				values: $banner_cookie, Passed values: $aff_string}
			set CREFERER_VALS(advertiser) ""
			set CREFERER_VALS(bannerid)   ""
			set CREFERER_VALS(profileid)  ""
			set CREFERER_VALS(refererurl) ""
			set CREFERER_VALS(creferer)   ""
		}
	}

	#
	# Need to split the creferer values
	#

	# Initialise parameters we're going to need to pass for stored proc when hitting DB
	set CREFERER_VALS(admap)              ""
	set CREFERER_VALS(affiliate_id)       ""
	set CREFERER_VALS(channel)            ""
	set CREFERER_VALS(promo_code)         ""
	set CREFERER_VALS(time)               ""
	set CREFERER_VALS(zone)               ""
	set CREFERER_VALS(promo_code_passed)  ""

	# Keep track of number of temp variables in creferer
	set temp_count 0

	if {$CREFERER_VALS(creferer) != ""} {

		# Split creferer into seperate name:value pairs
		set creferer_params [split [urldecode $CREFERER_VALS(creferer)] ";"]
		set CREFERER_VALS(creferer) [join $creferer_params ";"]
		
		## Tag source onto end of creferer
		set source_product [ob_chk::get_arg source -unsafe -on_err "" ALNUM]

		# Validate product source
		if {[catch {set rs [ob_db::exec_qry aff_utd::get_product_source_value $source_product]} msg]} {
			ob_log::write ERROR {aff_utd::set_creferer_vals ERROR: $msg}
		}
		set nrows [db_get_nrows $rs]
	
		if {$source_product != ""} {
			if {$nrows > 0} {
				append CREFERER_VALS(creferer) ";tab:$source_product"
			} else {
				append CREFERER_VALS(creferer) ";tab:XX"
			}	
		}

				
		foreach {param} $creferer_params {

			set terms [split $param ":"]

			if {[llength $terms] == 2} {
				set name  [string trim [lindex $terms 0]]
				set value [string range [string trim [lindex $terms 1]] 0 99]
				# Need to handle temp terms differently as there may be multiple
				# temp terms
				if {[regexp {temp} $name]} {
					incr temp_count
					set CREFERER_VALS(temp,$temp_count) $value
				} else {
					set CREFERER_VALS($name) $value
				}
			} else {
				ob_log::write WARNING {aff_utd::set_creferer_vals: Parameter \
					is not in field:value format - $param}
			}
		}
		
		
	} else {
		ob_log::write WARNING {aff_utd::set_creferer_vals: No creferer value found}
	}

	# Store the number of temp values
	set CREFERER_VALS(temp_count) $temp_count

	#
	# Do promotional codes match?
	#

	# Has user changed promo code?  Ignore if blank.
	if {$user_promo != $CREFERER_VALS(promo_code) && $user_promo != ""} {
		set promo_codes_match 0
	} else {
		set promo_codes_match 1
	}


	if {!$promo_codes_match} {

		# Check the db for the user entered promo code.  If it exists and has
		# override = 'Y' then use this promocode and overwrite the advertiser code
		# with that in the db.

		ob_log::write INFO {aff_utd::set_creferer_vals: Customer and cookie \
							promotional codes don't match, setting to customer \
							value and checking db for override}

		if {[catch {set rs [ob_db::exec_qry aff_utd::find_promo_code $user_promo]} msg]} {
			ob_log::write ERROR {aff_utd::set_creferer_vals ERROR: $msg}
		}

		set nrows [db_get_nrows $rs]
		set override ""

		if {$nrows > 0} {
			set advertiser_db [db_get_col $rs 0 advertiser]
			set override      [db_get_col $rs 0 override]
			if {$override == "Y"} {
				set CREFERER_VALS(promo_code_passed) $CREFERER_VALS(promo_code)
				set CREFERER_VALS(promo_code)        $user_promo
				set CREFERER_VALS(advertiser)        $advertiser_db
			} else {
				set CREFERER_VALS(promo_code)        $user_promo
			}

		}

		ob_db::rs_close $rs
	}

	return $params_exist

}


#
# Tags a customer with the current CREFERER_VALS values, returning success
# or failure.
#
#     cust_id - the cust_id of the customer to be tagged
#
#     returns - 1 if successful, 0 otherwise
#
proc aff_utd::au_tag_customer {cust_id} {

	variable CREFERER_VALS

	set success 1
	
	# Do the bulk of the insert
	if {[catch [ob_db::exec_qry aff_utd::add_au_banner_tag \
				$cust_id                          \
				$CREFERER_VALS(promo_code)        \
				$CREFERER_VALS(advertiser)        \
				$CREFERER_VALS(bannerid)          \
				$CREFERER_VALS(profileid)         \
				$CREFERER_VALS(refererurl)        \
				$CREFERER_VALS(admap)             \
				$CREFERER_VALS(affiliate_id)      \
				$CREFERER_VALS(channel)           \
				$CREFERER_VALS(promo_code_passed) \
				$CREFERER_VALS(time)              \
				$CREFERER_VALS(zone)              \
				$CREFERER_VALS(creferer)
	] msg]} {
		ob_log::write ERROR {aff_utd::au_tag_customer ERROR: $msg}
		set success 0
	}

	for {set i 1} {$i <= $CREFERER_VALS(temp_count)} {incr i} {

		# Now we need to do all the temp values
		if {[catch [ob_db::exec_qry aff_utd::add_au_temp \
					$cust_id                     \
					$CREFERER_VALS(temp,$i)      \
					$i
		] msg]} {
			ob_log::write ERROR {aff_utd::au_tag_customer ERROR: $msg}
			set success 0
		}
	}

	if {$success} {
		ob_log::write INFO {aff_utd::au_tag_customer: Successfully tagged \
						customer $cust_id with new Affiliates United banner}
	}
	return $success

}



#
# Tag a customer with Affiliates United data, this is to be called as part of
# the customer registration.
#
proc aff_utd::do_aff_utd { pc cust_id } {

	set pc_success 0

	if {[catch {set pc_rs [ob_db::exec_qry sb_reg::get_ext_promo $pc]} msg]} {
		ob_log::write ERROR {aff_utd::do_affiliate ERROR: $msg}
	} else {
		set system_name ""

		# Get the system for this promo_code
		if {[db_get_nrows $pc_rs] == 1} {
			set system_name [db_get_coln $pc_rs 0 0]
		} else {
			## This could be a promo code linked to an advertiser code
			## not an external promo code so check for that

			if {[catch {
				set adv_rs [ob_db::exec_qry aff_utd::find_promo_code $pc]
			} msg]} {
				ob_log::write ERROR {aff_utd::do_affiliate ERROR: $msg}
			}

			if {[db_get_nrows $adv_rs] > 0} {
				# It is linked:
				set adv_code [db_get_col $adv_rs 0 advertiser]
				ob_log::write INFO {aff_utd::do_affiliate: Customer $cust_id \
						promotional code $pc linked to advertiser code $adv_code, Storing data}
				set pc_success [aff_utd::au_tag_customer $cust_id]
			} else {
				# Note we're not setting the pc_success here as it's an
				# invalid promo_code so we still want to tell the customer
				ob_log::write INFO {aff_utd::do_affiliate: Customer $cust_id \
						promotional code $pc invalid, Storing data anyway}
				aff_utd::au_tag_customer $cust_id
			}
			ob_db::rs_close $adv_rs
		}

		ob_db::rs_close $pc_rs

		if {$system_name == "AffiliatesUnited"} {

			ob_log::write INFO {aff_utd::do_affiliate: Customer $cust_id \
					promotional code $pc for Affiliates United}
			set pc_success [aff_utd::au_tag_customer $cust_id]

		} elseif {$system_name == "InternalMarket"} {

			# If an internal market, we want to blank all creferer
			# values which aren't temp, promo_code, promo_code_passed
			# or time

			set re {^temp,\d+$}

			foreach {name} [array names CREFERER_VALS] {

				set tmp [regexp $re $name]

				if {!($name == "promo_code_passed"|| $name == "promo_code" ||
						$name == "time" || $name == "temp_count" ||
						[regexp $re $name])} {

					set CREFERER_VALS($name) ""

				}
			}

			ob_log::write INFO {aff_utd::do_affiliate: Customer $cust_id \
					promotional code $pc for Internal Marketing, \
					stripping out non-essential items}
			set pc_success [aff_utd::au_tag_customer $cust_id]
		}
	}

	return $pc_success
}


#
# Does affiliate stuff for OXi registrations.  Returns 1 if successful and the
# promo codes (customer supplied and sent by OXi) match, 0 otherwise.
#
# cust_id    - cust_id of the customer to add the Affiliates United data to
# user_promo - User entered promo code (i.e. a promo code a customer has
#              entered while registering)
# aff_string - String of Affilates United values, being in the format:
#
#                   advertiser,bannerid,profileid,refererurl,creferer
#
#              where creferer is in the format:
#
#                   key1:value1;key2:value2;...;keyN:valueN
#
proc aff_utd::do_OXi {cust_id {user_promo ""} {aff_string ""}} {

	set success 0

	set pc_is_au [aff_utd::set_creferer_vals $user_promo $aff_string]
	set pc [aff_utd::get promo_code]

	# This check is not strictly nessecary because all OXi registrations that
	# have affiliate info will be affiliates united.
	if {$pc_is_au} {
		if {$pc != ""} {
			set success [aff_utd::do_aff_utd $pc $cust_id]
		} else {
			# If there's no promo_code, we still want to store any data held in
			# the xml
			ob_log::write INFO {aff_utd::do_OXi: No promotional code, saving AU data anyway}
			set success [aff_utd::au_tag_customer $cust_id]
		}
	}
	return $success
}
