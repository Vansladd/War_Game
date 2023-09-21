# $Id: country_check.tcl,v 1.1 2011/10/04 12:25:34 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Country checking
#
# NB: IP checking software must be initialised separately such that the call
#     specified by CCHK_IP_TO_CC_CALL is available
#
# Configurations:
#   CCHK_IP_TO_CC_CALL  call to convert ip to country code         - ("")
#                       e.g. ob_geopoint::ip_to_cc
#   CCHK_USE_DB_FLAGS   get CCHK_BLOCK_FLAGS from db?              - (0)
#   CCHK_BLOCK_FLAGS    override default set of block flags list   - ("")
#   CCHK_BLOCK_CCS      list of ISO country codes to block         - ("")
#   CCHK_EXTRA_FIELDS   store extra items in country check cookie? - (0)
#   CCHK_FRAUD_MATRIX   fraud matrix                          - ("0,0,0,0,0,0")
#
# Synopsis:
#   package require security_cntrychk ?4.5?
#
# Procedures:
#   ob_countrychk::init           one time initialisation
#   ob_countrychk::fraud_check    fraud check
#   ob_countrychk::cookie_check   fraud check with session cookie
#

package provide security_cntrychk 4.5



# Dependencies
#
package require util_log     4.5
package require util_db      4.5
package require util_crypt   4.5
package require util_control 4.5
package require cust_flag    4.5



# Variables
#
namespace eval ob_countrychk {

	variable IP
	variable CFG
	variable INIT
	variable COOKIE_FMT
	variable CCHK_BLOCK_FLAGS
	variable US_POSTCODE_RX
	variable CC_EXPANSION

	# current request number
	set IP(req_no) ""

	set COOKIE_FMT {
	    expires
	    cust_id
	    flag
	    ip_country
	    ip_city
	    ip_routing
	    country_cf
	    ip_addr
	    ip_is_blocked
	}

	set CCHK_BLOCK_FLAGS {
	    YYY
	    YYN
	    YY-
	    YNY
	    Y-Y
	    Y-N
	    Y--
	    NYY
	    -YY
	    -Y-
	    -NY
	    --Y
	    ---
	}

	set US_POSTCODE_RX {^\s*([A-Z]+\W*)?\d{5}(\W\d{4})?\D*$}

	# Long tedious list of country names and their ISO codes
	array set CC_EXPANSION {
		{ANDORRA} AD
		{UNITED ARAB EMIRATES} AE
		{AFGHANISTAN} AF
		{ANTIGUA AND BARBUDA} AG
		{ANTIGUA & BARBUDA} AG
		{ANTIGUA} AG
		{BARBUDA} AG
		{ANGUILLA} AI
		{ALBANIA} AL
		{ARMENIA} AM
		{NETHERLANDS ANTILLES} AN
		{ANGOLA} AO
		{ANTARCTICA} AQ
		{ARGENTINA} AR
		{AMERICAN SAMOA} AS
		{AUSTRIA} AT
		{AUSTRALIA} AU
		{ARUBA} AW
		{AZERBAIJAN} AZ
		{BOSNIA AND HERZEGOVINA} BA
		{BOSNIA & HERZEGOVINA} BA
		{BOSNIA} BA
		{HERZEGOVINA} BA
		{BARBADOS} BB
		{BANGLADESH} BD
		{BELGIUM} BE
		{BURKINA FASO} BF
		{BULGARIA} BG
		{BAHRAIN} BH
		{BURUNDI} BI
		{BENIN} BJ
		{BERMUDA} BM
		{BRUNEI DARUSSALAM} BN
		{BRUNEI} BN
		{BOLIVIA} BO
		{BRAZIL} BR
		{BAHAMAS} BS
		{BHUTAN} BT
		{BOUVET ISLAND} BV
		{BOTSWANA} BW
		{BELARUS} BY
		{BELIZE} BZ
		{CANADA} CA
		{COCOS (KEELING) ISLANDS} CC
		{COCOS ISLANDS} CC
		{KEELING ISLANDS} CC
		{CENTRAL AFRICAN REPUBLIC} CF
		{CONGO} CG
		{SWITZERLAND} CH
		{COTE D'IVOIRE} CI
		{IVORY COAST} CI
		{COOK ISLANDS} CK
		{CHILE} CL
		{CAMEROON} CM
		{CHINA} CN
		{CHINA, PEOPLE'S REP. OF} CN
		{CHINA, PEOPLES REP. OF} CN
		{CHINA, PEOPLE'S REPUBLIC OF} CN
		{CHINA, PEOPLES REPUBLIC OF} CN
		{PEOPLE'S REP. OF CHINA} CN
		{PEOPLES REP. OF CHINA} CN
		{PEOPLE'S REPUBLIC OF CHINA} CN
		{PEOPLES REPUBLIC OF CHINA} CN
		{COLOMBIA} CO
		{COSTA RICA} CR
		{CZECHOSLOVAKIA} CS
		{CUBA} CU
		{CAPE VERDE} CV
		{CHRISTMAS ISLAND} CX
		{CYPRUS} CY
		{CZECH REPUBLIC} CZ
		{GERMANY} DE
		{DJIBOUTI} DJ
		{DENMARK} DK
		{DOMINICA} DM
		{DOMINICAN REPUBLIC} DO
		{ALGERIA} DZ
		{ECUADOR} EC
		{ESTONIA} EE
		{EGYPT} EG
		{WESTERN SAHARA} EH
		{ERITREA} ER
		{SPAIN} ES
		{ETHIOPIA} ET
		{EUROPE} EU
		{FINLAND} FI
		{FIJI} FJ
		{FALKLAND ISLANDS} FK
		{MALVINAS} FK
		{MICRONESIA} FM
		{FAROE ISLANDS} FO
		{FRANCE} FR
		{GABON} GA
		{GREAT BRITAIN} GB
		{ENGLAND} GB
		{SCOTLAND} GB
		{WALES} GB
		{NORTHERN IRELAND} GB
		{UNITED KINGDOM} GB
		{UK} GB
		{U.K.} GB
		{G.B.} GB
		{GRENADA} GD
		{GEORGIA} GE
		{FRENCH GUIANA} GF
		{GHANA} GH
		{GIBRALTAR} GI
		{GREENLAND} GL
		{GAMBIA} GM
		{GUINEA} GN
		{GUADELOUPE} GP
		{EQUATORIAL GUINEA} GQ
		{GREECE} GR
		{GUATEMALA} GT
		{GUAM} GU
		{GUINEA BISSAU} GW
		{GUYANA} GY
		{HONG KONG} HK
		{HONG-KONG} HK
		{HONG KONG, CHINA} HK
		{HONG-KONG, CHINA} HK
		{HEARD AND MCDONALD ISLANDS} HM
		{HONDURAS} HN
		{CROATIA} HR
		{HRVATSKA} HR
		{HAITI} HT
		{HUNGARY} HU
		{INDONESIA} ID
		{IRELAND} IE
		{IRELAND, REPUBLIC OF} IE
		{REPUBLIC OF IRELAND} IE
		{EIRE} IE
		{ISRAEL} IL
		{INDIA} IN
		{IRAQ} IQ
		{IRAN} IR
		{ISLAMIC REPUBLIC OF IRAN} IR
		{ICELAND} IS
		{ITALY} IT
		{JAMAICA} JM
		{JORDAN} JO
		{JAPAN} JP
		{KENYA} KE
		{KYRGYZSTAN} KG
		{CAMBODIA} KH
		{KIRIBATI} KI
		{COMOROS} KM
		{SAINT KITTS AND NEVIS} KN
		{SAINT KITTS-NEVIS} KN
		{SAINT KITTS & NEVIS} KN
		{ST. KITTS AND NEVIS} KN
		{ST. KITTS-NEVIS} KN
		{ST. KITTS & NEVIS} KN
		{NORTH KOREA} KP
		{KOREA, REPUBLIC OF} KR
		{REPUBLIC OF KOREA} KR
		{SOUTH KOREA} KR
		{KOREA} KR
		{KUWAIT} KW
		{CAYMAN ISLANDS} KY
		{KAZAKHSTAN} KZ
		{LAOS} LA
		{LEBANON} LB
		{SAINT LUCIA} LC
		{ST. LUCIA} LC
		{LIECHTENSTEIN} LI
		{SRI LANKA} LK
		{LIBERIA} LR
		{LESOTHO} LS
		{LITHUANIA} LT
		{LUXEMBOURG} LU
		{LATVIA} LV
		{LIBYA} LY
		{MOROCCO} MA
		{MONACO} MC
		{MOLDOVA} MD
		{MADAGASCAR} MG
		{MARSHALL ISLANDS} MH
		{MACEDONIA} MK
		{MALI} ML
		{MYANMAR} MM
		{MONGOLIA} MN
		{MACAO} MO
		{MACAU} MO
		{NORTHERN MARIANA ISLANDS} MP
		{MARTINIQUE} MQ
		{MAURITANIA} MR
		{MONTSERRAT} MS
		{MALTA} MT
		{MAURITIUS} MU
		{MALDIVES} MV
		{MALAWI} MW
		{MEXICO} MX
		{MALAYSIA} MY
		{MOZAMBIQUE} MZ
		{NAMIBIA} NA
		{NEW CALEDONIA} NC
		{NIGER} NE
		{NORFOLK ISLAND} NF
		{NIGERIA} NG
		{NICARAGUA} NI
		{NETHERLANDS} NL
		{THE NETHERLANDS} NL
		{HOLLAND} NL
		{NORWAY} NO
		{NEPAL} NP
		{NAURU} NR
		{NIUE} NU
		{NEW ZEALAND} NZ
		{AOTEAROA} NZ
		{OMAN} OM
		{PANAMA} PA
		{PERU} PE
		{FRENCH POLYNESIA} PF
		{PAPUA NEW GUINEA} PG
		{PHILIPPINES} PH
		{PAKISTAN} PK
		{POLAND} PL
		{ST PIERRE AND MIQUELON} PM
		{ST PIERRE & MIQUELON} PM
		{PITCAIRN} PN
		{PUERTO RICO} PR
		{PORTUGAL} PT
		{PALAU} PW
		{PARAGUAY} PY
		{QATAR} QA
		{REUNION} RE
		{ROMANIA} RO
		{RUSSIA} RU
		{RUSSIAN FEDERATION} RU
		{RWANDA} RW
		{SAUDI ARABIA} SA
		{BRITISH SOLOMON ISLANDS} SB
		{SOLOMON ISLANDS} SB
		{SEYCHELLES} SC
		{SUDAN} SD
		{SWEDEN} SE
		{SINGAPORE} SG
		{ST HELENA} SH
		{SLOVENIA} SI
		{SVALBARD AND JAN MAYEN ISLANDS} SJ
		{SVALBARD & JAN MAYEN ISLANDS} SJ
		{SLOVAK REPUBLIC} SK
		{SLOVAKIA} SK
		{SIERRA LEONE} SL
		{SAN MARINO} SM
		{SENEGAL} SN
		{SOMALIA} SO
		{SURINAME} SR
		{SAO TOME AND PRINCIPE} ST
		{SAO TOME & PRINCIPE} ST
		{USSR} SU
		{EL SALVADOR} SV
		{SYRIA} SY
		{SWAZILAND} SZ
		{TURKS AND CAICOS ISLANDS} TC
		{TURKS & CAICOS ISLANDS} TC
		{CHAD} TD
		{FRENCH SOUTHERN TERRITORIES} TF
		{TOGO} TG
		{THAILAND} TH
		{TAJIKISTAN} TJ
		{TOKELAU} TK
		{TURKMENISTAN} TM
		{TUNISIA} TN
		{TONGA} TO
		{EAST TIMOR} TP
		{TURKEY} TR
		{TRINIDAD AND TOBAGO} TT
		{TRINIDAD & TOBAGO} TT
		{TRINIDAD} TT
		{TOBAGO} TT
		{TUVALU} TV
		{TAIWAN} TW
		{TANZANIA} TZ
		{UKRAINE} UA
		{UGANDA} UG
		{AMERICA} US
		{UNITED STATES} US
		{U.S.} US
		{UNITED STATES OF AMERICA} US
		{USA} US
		{U.S.A.} US
		{URUGUAY} UY
		{UZBEKISTAN} UZ
		{VATICAN CITY STATE} VA
		{HOLY SEE} VA
		{SAINT VINCENT AND THE GRENADINES} VC
		{SAINT VINCENT & THE GRENADINES} VC
		{SAINT VINCENT & GRENADINES} VC
		{SAINT VINCENT} VC
		{ST. VINCENT AND THE GRENADINES} VC
		{ST. VINCENT & THE GRENADINES} VC
		{ST. VINCENT & GRENADINES} VC
		{ST. VINCENT} VC
		{THE GRENADINES} VC
		{VENEZUELA} VE
		{BRITISH VIRGIN ISLANDS} VG
		{VIRGIN ISLANDS (BRITISH)} VG
		{US VIRGIN ISLANDS} VI
		{U.S. VIRGIN ISLANDS} VI
		{VIRGIN ISLANDS (US)} VI
		{VIRGIN ISLANDS (U.S.)} VI
		{VIRGIN ISLANDS} VI
		{VIET NAM} VN
		{VIETNAM} VN
		{VANUATU} VU
		{WALLIS AND FUTUNA ISLANDS} WF
		{SAMOA} WS
		{YEMEN} YE
		{MAYOTTE} YT
		{YUGOSLAVIA} YU
		{SOUTH AFRICA} ZA
		{ZAMBIA} ZM
		{ZAIRE} ZR
		{ZIMBABWE} ZW
	}

	# init flag
	set INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Prepares the package queries and set package configuration.
#
proc ob_countrychk::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# init dependencies
	ob_db::init
	ob_log::init
	ob_crypt::init
	ob_control::init
	ob_cflag::init

	ob_log::write DEBUG {COUNTRYCHK: init}

	# get configuration
	array set OPT [list \
	    use_db_flags      0\
	    block_flags       ""\
	    block_ccs         ""\
	    fraud_matrix      "0,0,0,0,0,0"\
	    extra_fields      0\
	    ip_to_cc_call     ""\
	    cookie_keepalive  -1]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet CCHK_[string toupper $c] $OPT($c)]
	}

	set CFG(block_flags) [string toupper $CFG(block_flags)]
	set CFG(block_ccs)   [string toupper $CFG(block_ccs)]

	# can auto reset the ip-list?
	if {[info commands reqGetId] != "reqGetId"} {
		error "LOGIN: reqGetId not available for auto reset"
	}

	_prepare_qrys

	# use the database for block flags
	if {$CFG(use_db_flags)} {
		if {[catch {\
		        set CFG(block_flags) [_get_block_list_from_database]} msg]} {
			ob_log::write CRITICAL\
				{COUNTRYCHK: failed to block flags from db - $msg}
			error $msg
		}
	}

	# initialised
	set INIT 1
}



# Private procedure to prepare the package queries.
#
proc ob_countrychk::_prepare_qrys args {

	# get country for particular card bin
	ob_db::store_qry ob_countrychk::get_card_country {
		select
		    country
		from
		    tCardInfo
		where
		    card_bin = ?
	}

	# log a customer check
	ob_db::store_qry ob_countrychk::log_check {
		insert into	tCustCheck (
		    cust_id,
		    ipaddr,
		    card_bin,
		    postcode,
		    ip_country,
		    cc_country,
		    check_flags,
		    result
		) values (
		    ?, ?, ?, ?, ?, ?, ?, ?
		)
	}

	# get customer's postcode
	ob_db::store_qry ob_countrychk::get_cust_postcode {
		select
		    addr_postcode
		from
		    tCustomerReg
		where
		    cust_id = ?
	}

	# get block list
	ob_db::store_qry ob_countrychk::get_block_list {
		select *
		from
		    tPmtCntryChk
	}

	# get country for ccy_code
	ob_db::store_qry ob_countrychk::get_ccy_country {
		select
		    country_code
		from
		    tCountry
		where
		    ccy_code = ?
	}

	# get country for ccy_code
	ob_db::store_qry ob_countrychk::get_specific_ccy_country {
		select
		    country_code
		from
		    tCountry
		where
		    ccy_code = ?
		and country_code = ?
	}

	# get blocked ip
	ob_db::store_qry ob_countrychk::get_ip_blocked {
		select 1
		from
		    tIPBlock
		where
		    ip_addr_lo <= ?
		and ip_addr_hi >= ?
		and (
		    expires is null
	    or
		    expires > current
		)
	}

	# log blocked ip
	ob_db::store_qry ob_countrychk::insert_ip_block_log {
		insert into tBlockedAccessLog (
		    ip_address,
		    date
		) values (
		    ?, current
		)
	}

	# get active customer's card
	ob_db::store_qry ob_countrychk::get_active_cust_card {
		select
		    cpm.enc_card_no
		from
		    tCustPayMthd m,
		    tCPMCC cpm
		where
		    m.status = 'A'
		and m.cust_id = ?
		and cpm.cpm_id = m.cpm_id
	}
}



# Private procedure to get the block list from the database (overrides supplied
# configuration).
#
#    returns - block list
#
proc ob_countrychk::_get_block_list_from_database {} {

	set options [list Y N -]
	set block_list ""

	set rs [ob_db::exec_qry ob_countrychk::get_block_list]
	if {[db_get_nrows $rs]!=9} {
		ob_db::rs_close $rs
		error "Wrong number of rules in tPmtCntryChk"
	}
	#

	# convert data from matrix into list of block flags
	for {set row 0} {$row < 9} {incr row} {
		for {set col 0} {$col < 3} {incr col} {
			if {[db_get_coln $rs $row [expr {$col+1}]]=="B"} {
				set ip    [lindex $options [expr {$row/3}]]
				set bin   [lindex $options $col]
				set pc    [lindex $options [expr {$row%3}]]
				ob_log::write INFO\
					{COUNTRYCHK: row=$row, col=$col, ip=$ip, bin=$bin, pc=$pc}

				lappend block_list "$ip$bin$pc"
			}
		}
	}
	ob_db::rs_close $rs

	ob_log::write INFO {COUNTRYCHK: block_list = $block_list}
	return $block_list
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_countrychk::_auto_reset args {

	variable IP

	# get the request id
	set id [reqGetId]

	# different request number, must reload cache
	if {$IP(req_no) != $id} {
		catch {unset IP}
		set IP(req_no) $id
		ob_log::write DEV {COUNTRYCHK: auto reset cache, req_no=$id}

		return 1
	}

	# already loaded
	return 0
}



#--------------------------------------------------------------------------
# Fraud check
#--------------------------------------------------------------------------

# Fraud check.
# Get ip-country, currency-country, address-country and card-country and verify
# if they match, awarding points for mismatches.
#
#     cust_id   - customer identifier
#     ipaddr    - customer's IP address
#     card_bin  - customer's card bin number
#     country   - customer's country code
#     ccy       - customer's currency code
#     returns   - Total points, 0 indicates OK, > 0 indicates mismatches
#
proc ob_countrychk::fraud_check { cust_id ipaddr card_bin country ccy } {

	variable CFG

	ob_log::write DEBUG {COUNTRYCHK: fraud_check cust_id=$cust_id}

	# get the country codes for supplied ip, card & ccy
	set ip_country 		[lindex [_get_ip_country $ipaddr] 0]
	set card_country 	[_get_card_country $card_bin]
	set ccy_country		[_get_ccy_country $ccy]
	set addr_country 	$country

	ob_log::write INFO {COUNTRYCHK: ip country  : $ip_country}
	ob_log::write INFO {COUNTRYCHK: card country: $card_country}
	ob_log::write INFO {COUNTRYCHK: ccy country : $ccy_country}
	ob_log::write INFO {COUNTRYCHK: addr country: $addr_country}

	# Add points for countries that do not match
	set list [split $CFG(fraud_matrix) ,]
	set points 0

	# compare ip country with card country
	if {![string equal $ip_country "A!"] &&
		![string equal $ip_country $card_country] &&
		![string equal $ip_country "??"] &&
		![string equal $card_country "??"]} {

		ob_log::write DEV {COUNTRYCHK: failed ip country with card country}
		incr points [lindex $list 0]
	}

	# compare addr country with card country
	if {![string equal $addr_country $card_country] &&
		![string equal $addr_country "--"] &&
		![string equal $card_country "??"]} {

		ob_log::write DEV {COUNTRYCHK: failed addr country with card country}
		incr points [lindex $list 1]
	}

	# compare ccy country with card country
	if {$ccy_country == "--" && ![string equal $card_country "??"]} {

		set rs [ob_db::exec_qry ob_countrychk::get_specific_ccy_country\
		            $ccy $card_country]
		if {[db_get_nrows $rs] == 0} {
			ob_log::write DEV {COUNTRYCHK: failed ccy country with card country}
			incr points [lindex $list 2]
		}
		ob_db::rs_close $rs

	} elseif {![string equal $ccy_country $card_country] &&
			  ![string equal $ccy_country "??"] &&
			  ![string equal $card_country "??"]} {

		ob_log::write DEV {COUNTRYCHK: failed ccy country with card country}
		incr points [lindex $list 2]
	}

	# compare ip country with addr country
	if {![string equal $ip_country "A!"] &&
		![string equal $ip_country $addr_country] &&
		![string equal $ip_country "??"] &&
		![string equal $addr_country "--"]} {

		ob_log::write DEV {COUNTRYCHK: failed ip country with addr country}
		incr points [lindex $list 3]
	}

	# compare addr country with ccy country
	if {$ccy_country == "--" && ![string equal $addr_country "--"]} {

		set rs [ob_db::exec_qry ob_countrychk::get_specific_ccy_country\
		            $ccy $addr_country]
		if {[db_get_nrows $rs] == 0} {
			ob_log::write DEV {COUNTRYCHK: failed addr country with ccy country}
			incr points [lindex $list 4]
		}
		ob_db::rs_close $rs

	} elseif {![string equal $addr_country $ccy_country] &&
		      ![string equal $addr_country "--"] &&
		      ![string equal $ccy_country "??"]} {

		ob_log::write DEV {COUNTRYCHK: failed addr country with ccy country}
		incr points [lindex $list 4]
	}

	# compare ip country with ccy country
	if {$ccy_country == "--" &&
		![string equal $ip_country "??"] &&
		![string equal $ip_country "A!"]} {

		set rs [ob_db::exec_qry ob_countrychk::get_specific_ccy_country\
		            $ccy $ip_country]
		if {[db_get_nrows $rs] == 0} {
			ob_log::write DEV {COUNTRYCHK: failed ip country with ccy country}
			incr points [lindex $list 5]
		}
		ob_db::rs_close $rs

	} elseif {![string equal $ip_country "A!"] &&
		      ![string equal $ip_country $ccy_country] &&
		      ![string equal $ip_country "??"] &&
		      ![string equal $ccy_country "??"]} {

		ob_log::write DEV {COUNTRYCHK: failed ip country with ccy country}
		incr points [lindex $list 5]
	}

	return $points
}



# Private procedure to get the country code for a particular card number via
# tCardInfo.
#
#   card_bin - card bin number
#   returns - country code
#
proc ob_countrychk::_get_card_country { card_bin } {

	variable CC_EXPANSION

	set card_bin [string range $card_bin 0 5]

	set card_cc "??"

	regsub -all {\D} $card_bin {} card_bin

	if {[regexp {^\d\d\d\d\d\d} $card_bin]} {

		set rs [ob_db::exec_qry ob_countrychk::get_card_country $card_bin]

		# resolve country code against CC_EXPANSION list
		if {[db_get_nrows $rs] == 1} {
			set db_cntry [string toupper [db_get_col $rs 0 country]]
			foreach expand_cc [array names CC_EXPANSION] {
				if {[string first $expand_cc $db_cntry] == 0} {
					set card_cc $CC_EXPANSION($expand_cc)
					break
				}
			}
		}
		ob_db::rs_close $rs
	}

	if {$card_cc == "GB" || ($card_cc == "??" && [regexp {^6} $card_bin]) } {
		set card_cc "UK"
	}

	return $card_cc
}



# Private procedure to get the country information for an IP.
# The config value CCHK_IP_TO_CC_CALL defines the procedure (callback) which can
# is used to get the country code, e.g. ob_geopoint::ip_to_cc (Geopoint). If not
# defined, then unknown country details are returned.
#
# Procedure uses a cache of previously resolved ip country details which is
# reset on detection of a new request number. This should avoid calling the
# the ip_to_cc procedure multiple times within the one request.
#
#   ipaddr  - IP address
#   returns - list {country_code is_aol city routing country_cf}
#
proc ob_countrychk::_get_ip_country {ipaddr} {

	variable IP
	variable CFG

	ob_log::write DEBUG {COUNTRYCHK: _get_ip_country $ipaddr}

	set info_list [list "??" "" "" "" ""]

	# have we seen this ip-address within the scope of this request
	_auto_reset
	if {[info exists IP($ipaddr)]} {
		ob_log::write DEBUG {COUNTRYCHK: using cached info list for $ipaddr}
		return $IP($ipaddr)
	}

	if {$CFG(ip_to_cc_call) != ""} {
		if {[regexp {^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$} $ipaddr]} {
			set info_list [eval $CFG(ip_to_cc_call) $ipaddr]
		}

		if {[lindex $info_list 0] == "GB"} {
			set info_list [lreplace $info_list 0 0 "UK"]
		}
	} else {
		ob_log::write WARNING\
		    {COUNTRYCHK: ip_to_cc_call not defined, using default info_list}
	}

	# add ip info list to cache
	set IP($ipaddr) $info_list

	return $info_list
}



# Private procedure to get the country code for a particular currency code.
#
#   ccy      - currency code
#   returns  - county code, or -- if an unknown ccy code
#
proc ob_countrychk::_get_ccy_country {ccy} {

	set ccy_country "??"

	set rs [ob_db::exec_qry ob_countrychk::get_ccy_country $ccy]
	set nrows [db_get_nrows $rs]

	if {$nrows == 1} {
		set ccy_country [db_get_col $rs country_code]
	} elseif {$nrows > 1} {
		set ccy_country "--"
	}

	return $ccy_country
}



#--------------------------------------------------------------------------
# Fraud check with session cookie
#--------------------------------------------------------------------------

# Fraud check.
# Wraps up a call to ::fraud_check method, but adds session cookie caching
# functionality, i.e. when the check is first performed it will store the
# result inside a session cookie and any subsequent calls use the cookie.
#
# It will be the responsibility of the caller to create the actually cookie,
# e.g. add to HTTP header. This procedure will create the cookie string/value.
#
#    cust_id   - customer identifier
#    cc_cookie - cookie string
#    ipaddr    - customer's IP address (default - "")
#    card_bin   - customer's card bin number (default - "")
#    postcode  - customer's postcode (default - "")
#    returns   - list {flag outcome cc_cookie ip_country ip_is_aol ip_city
#                      ip_routing ip_is_blocked}
#                where:
#                   flag      - is IP is blocked
#                   outcome   - error message
#                   cc_cookie - encrypted cookie (containing this list)
#
proc ob_countrychk::cookie_check {cust_id cc_cookie {ipaddr ""} {card_bin ""} \
	                              {postcode ""}} {

	variable CFG
	variable COOKIE_FMT

	ob_log::write DEBUG {COUNTRYCHK: cookie_check cust_id=$cust_id}

	set ip_is_blocked "N"
	set ip_is_aol  ""
	set ip_city    ""
	set ip_routing ""
	set country_cf ""

	# decode the cookie
	set cookie [_decode_cc_cookie $cc_cookie]

	# Cookie is for the wrong customer or the cookie info is not present
	if {[lindex $cookie [lsearch $COOKIE_FMT cust_id]] != $cust_id ||
				[lindex $cookie [lsearch $COOKIE_FMT flag]] == ""} {

		if {$card_bin == ""} {
			set card_bin [string range [_get_active_cust_card $cust_id] 0 5]
		}
		if {$ipaddr == ""} {
			set ipaddr [reqGetEnv REMOTE_ADDR]
			ob_log::write INFO {COUNTRYCHK: retrieved client IP as $ipaddr}
		}
		if {$postcode == ""} {
			set rs [ob_db::exec_qry ob_countrychk::get_cust_postcode $cust_id]
			set postcode [db_get_col $rs 0 addr_postcode]
			ob_log::write INFO\
				{COUNTRYCHK: retrieved customer postcode: $postcode}
			ob_db::rs_close $rs
		}

		# perform check
		foreach {flag ip_country\
		         ip_is_aol\
		         ip_city \
		         ip_routing \
		         country_cf}\
			[_check $cust_id $ipaddr $card_bin $postcode] {break}

		# Specific IP banning
		set ip_is_blocked [_check_ip_banned $ipaddr]

		if {$ip_is_blocked == "Y"} {
			set flag 1
		}

		# See if we need to override
		if {$flag != 0} {
			if {[ob_countrychk::_check_block_override $cust_id]} {
				ob_log::write INFO\
					{COUNTRYCHK: overriding customer check for cust_id $cust_id}
				set flag 0
			}
		}

		# encode the cookie
		if {$CFG(extra_fields)} {
			set cc_cookie [_encode_cc_cookie\
			               $cust_id\
			               $flag\
			               $ip_country\
			               $ip_city\
			               $ip_routing\
			               $country_cf\
			               $ipaddr\
			               $ip_is_blocked]

		} else {
			set cc_cookie [_encode_cc_cookie\
			               $cust_id\
			               $flag\
			               $ip_country\
			               "" "" ""\
			               $ipaddr\
			               $ip_is_blocked]
		}

	# get details from cookie
	} else {

		set flag          [lindex $cookie [lsearch $COOKIE_FMT flag]]
		set ip_is_blocked [lindex $cookie [lsearch $COOKIE_FMT ip_is_blocked]]
		set ip_country    [lindex $cookie [lsearch $COOKIE_FMT ip_country]]
	}

	if {$ip_is_blocked == "Y"} {
		set outcome "IP_BLOCKED"
		ob_db::exec_qry ob_countrychk::insert_ip_block_log $ipaddr
	} else {
		set outcome "IP_NOT_BLOCKED"
	}

	ob_log::write INFO {COUNTRYCHK: flag          : $flag}
	ob_log::write INFO {COUNTRYCHK: ip_country    : $ip_country}
	ob_log::write INFO {COUNTRYCHK: ip_is_aol     : $ip_is_aol}
	ob_log::write INFO {COUNTRYCHK: ip_city       : $ip_city}
	ob_log::write INFO {COUNTRYCHK: ip_routing    : $ip_routing}
	ob_log::write INFO {COUNTRYCHK: ip_is_blocked : $ip_is_blocked}

	return [list $flag $outcome $cc_cookie $ip_country $ip_is_aol $ip_city\
	        $ip_routing $ip_is_blocked]
}



# Private procedure to decode the check cookie.
#
#   cc_cookie - encoded cookie
#   returns   - decoded cookie, or "" if not defined or illegal format
#
proc ob_countrychk::_decode_cc_cookie {cc_cookie} {

	variable COOKIE_FMT

	if {$cc_cookie == ""} {
		return ""
	}

	set dec_cookie [ob_crypt::decrypt_by_bf $cc_cookie]

	set cookie [split $dec_cookie |]
	if {[llength $cookie] != [llength $COOKIE_FMT]} {
		ob_log::write DEBUG\
			{COUNTRYCHK: cc_cookie is malformed [llength $cookie]}
		return ""
	} elseif {[lindex $cookie 0] < [clock seconds]} {
		ob_log::write DEBUG {COUNTRYCHK:: cc_cookie has expired}
		return ""
	}

	return $cookie
}



# Private procedure to encode the check cookie.
#
#   cust_id       - customer identifier
#   flag          - blocked flag
#   ip_country    - IP's country code
#   ip_city       - IP's city
#   ip_routing    - IP routing
#   country_cf    - IP country cf
#   ip_addr       - IP address
#   ip_is_blocked - is IP blocked
#   returns       - encoded cookie string
#
proc ob_countrychk::_encode_cc_cookie {
	cust_id
	flag
	ip_country
	ip_city
	ip_routing
	country_cf
	ip_addr
	ip_is_blocked
} {
	variable COOKIE_FMT
	variable CFG

	if {$CFG(cookie_keepalive) == -1 } {
		set keepalive [ob_control::get login_keepalive]
	} else {
		set keepalive $CFG(cookie_keepalive)
	}
	set now       [clock seconds]
	set expires   [expr {$now + $keepalive}]

	foreach v $COOKIE_FMT {
		lappend cookie_data [set $v]
	}

	set cookie_data [join $cookie_data |]
	set enc_cookie  [ob_crypt::encrypt_by_bf $cookie_data]

	return $enc_cookie
}



# Private procedure to perform a fraud check via ::check_cookie
#
#   cust_id  - customer identifier
#   ipaddr   - customer's ip address
#   card_bin  - customer's card bin number
#   postcode - customer's postcode
#   returns  - list {blocked ip_country ip_is_aol ip_routing ip_is_blocked
#                    country_cf}
#
proc ob_countrychk::_check {cust_id ipaddr card_bin postcode} {

	variable CFG
	variable US_POSTCODE_RX

	# get country details for IP address
	foreach {ip_country \
	         ip_is_aol \
	         ip_city \
	         ip_routing \
	         country_cf} [_get_ip_country $ipaddr] {break}

	# get country code for card
	if {$card_bin == ""} {
		set card_country "??"
	} else {
		set card_country [_get_card_country $card_bin]
	}

	# Check postcode format
	if {[regexp {^\s*$} $postcode]} {
		set postcode_country "??"
	} elseif {[regexp -nocase $US_POSTCODE_RX $postcode]} {
		set postcode_country "US"
	} else {
		set postcode_country "OK"
	}

	# Form check flag string (Y for US, - for ??, N otherwise)
	set check_flags ""
	switch -- $ip_country {
		US		{ append check_flags "Y" }
		??		{ append check_flags "-" }
		default	{ append check_flags "N" }
	}
	switch -- $card_country {
		US		{ append check_flags "Y" }
		??		{ append check_flags "-" }
		default	{ append check_flags "N" }
	}
	switch -- $postcode_country {
		US		{ append check_flags "Y" }
		??		{ append check_flags "-" }
		default	{ append check_flags "N" }
	}

	ob_log::write DEV {COUNTRYCHK: check_flags=$check_flags}

	# Look for this flag combination in the block list or the ip_country
	# in the country codes list
	if {[lsearch -exact $CFG(block_flags) $check_flags] >= 0} {
		set block 1
	} elseif {[lsearch -exact $CFG(block_flags) $ip_country] >= 0} {
		set block 1
	} else {
		set block 0
	}

	ob_db::exec_qry ob_countrychk::log_check\
					 $cust_id\
					 $ipaddr\
					 $card_bin\
					 $postcode\
					 $ip_country\
					 $card_country\
					 $check_flags\
					 $block

	ob_log::write INFO\
		{COUNTRYCHK:_check - IP:$ipaddr ($ip_country), BIN:$card_bin ($card_country), ZIP:$postcode ($postcode_country), blocked=$block}

	return [list $block $ip_country $ip_is_aol $ip_city $ip_routing $country_cf]
}



# Private procedure to check if a customer has a block override set-up.
#
#   cust_id - customer identifier
#   returns - 1 if block override is set, else 0
#
proc ob_countrychk::_check_block_override {cust_id} {

	set skip_check_flag [ob_cflag::get "SkipIPCheck" $cust_id]

	if {$skip_check_flag == "Y"} {
		return 1
	} else {
		return 0
	}
}



# Private procedure to get the customer's active card number
#
#    cust_id - customer identifier
#    returns - card bin number
#
proc ob_countrychk::_get_active_cust_card { cust_id } {

	set rs  [ob_db::exec_qry ob_countrychk::get_active_cust_card $cust_id]

	set card ""
	if {[db_get_nrows $rs] == 1} {
		set card [ob_crypt::decrypt_cardno [db_get_col $rs 0 enc_card_no] 0]
	}
	ob_db::rs_close $rs

	return $card
}



# Private procedure to check if IP is banned
#
#   ip_address - IP address to check
#   returns    - Y|N
#
proc ob_countrychk::_check_ip_banned { ip_address } {

	set banned "N"

	set int_ip [ob_util::ip_to_int $ip_address]

	set rs [ob_db::exec_qry ob_countrychk::get_ip_blocked $int_ip $int_ip]
	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
	 	set banned "Y"
		ob_log::write INFO\
			{COUNTRYCHK: Attempt at banned action from blocked ip $ip_address}
	}
	ob_db::rs_close $rs

	return $banned
}
