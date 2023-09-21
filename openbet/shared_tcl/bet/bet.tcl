################################################################################
# $Id: bet.tcl,v 1.1 2011/10/04 12:26:11 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Bet placement initialisation and high level functionality
#
# Configuration:
#    Does not read config file use ob_bet::init -[various options] to
#    customise
#
# Synopsis:
#    package require bet_bet ?4.5?
#
# Procedures:
#    ob_bet::init  Initialise and customise placebet
#    ob_bet::load_snashot Load a memory snapshot into placebet (debug)
#    ob_bet::clear Reset bet placement memory
#    ob_bet::snapshot Print out contents of bet placement array (debug)
#    ob_bet::get_config Get config setting
#    ob_bet::set_config Set config setting for this request
#    ob_bet::get_type   Get bet type information
#    ob_bet::add_leg_param Add leg parameter
#    ob_bet::reg_external Register an "external" bet flavour
################################################################################

namespace eval ob_bet {

	variable RESETABLE_ARRAYS
	variable RST_ARRAY_CACHE_T
	variable ALL_ARRAYS
	variable SNAPSHOT_ARRAYS
	variable OFFLINE
	set OFFLINE 0

	set RESETABLE_ARRAYS [list\
		CUST\
		CUST_DETAILS\
		LEG\
		SELN\
		VERIFY\
		GROUP\
		BET\
		OVERRIDE\
		COMBI\
		LIAB\
		TOKEN\
		VALID_TOKENS\
		SESSION_CONFIG\
		FREEBET_CHECKS\
		TYPE\
		XSTK\
		BET_TYPE_LIMITS]

	# The TYPE array is a bit of a nuisance; PPW want changes they
	# make to tBetType via the admin screens to get picked up
	# reasonably timely but at the same time we want to avoid loading
	# the types too often - especially since that discards the lines
	# info created by ::ob_bet::_bet_type_lines. We also need to consider:
	#  - Don't want to have the TYPE array change in the middle of a request.
	#  - TYPE array is a bit big to array get/set out of SHM each request.
	#  - Some functions bypass _get_type (and for good reasons).
	# So we'll use the _smart_reset mechanism, but with
	# a tweak to cache TYPE across requests for RST_ARRAY_CACHE_T seconds.
	# Unfortunately, the caching is per-child - but we can mitigate it
	# by setting a small db query cache time which we should take into
	# account when choosing the TYPE array cache time.

	catch {unset RST_ARRAY_CACHE_T}
	array set RST_ARRAY_CACHE_T \
	  [list\
	    TYPE [expr {600 - 60}] ]

	set ALL_ARRAYS [list\
		CONFIG\
		SESSION_CONFIG\
		TYPE\
		CHANNEL\
		CUST\
		CUST_DETAILS\
		LEG\
		LEG_FORMAT\
		SELN\
		VERIFY\
		GROUP\
		BET\
		OVERRIDE\
		COMBI\
		LIAB\
		TOKEN\
		VALID_TOKENS\
		BET_TYPE_LIMITS\
		FREEBET_CHECKS]

	set SNAPSHOT_ARRAYS $ALL_ARRAYS

	variable MAX_SELN_PLACEHOLDERS
	variable MAX_MULT_SELNS
	variable TYPE
	variable CHANNEL
	variable CONFIG

	# Limited number of placeholders in selection queries
	set MAX_SELN_PLACEHOLDERS 20

	namespace export init
	namespace export load_snapshot
	namespace export clear
	namespace export snapshot
	namespace export get_config
	namespace export set_config
	namespace export get_type
}



#API:init Initialises bet placement
# Usage:
# ob_bet::init args
#
# This must be called first to initialise the bet package.
# Functions include preparing the queries,
# and loading up bet type and channel information
# This can also be used to configure the bet placement package.
#
# Parameters:
# args takes a name value list of configuration items
# possible names value pairs are:
#
# -source:
#    FORMAT : CHAR(1)
#    DESC   : Source of the requests ie: I internet, P tbet etc..
#    DEFAULT: I
#
# -receipt_format_proc:
#    FORMAT : Proc name
#    DESC   : Procedure to call to format the bet receipt
#    DEFAULT: ""
#
# -sep_cum_max_stk:
#    FORMAT : Y|N
#    DESC   : Treat bets placed at SP seperatly to LP when
#             calculating max stakes
#    DEFAULT: N
#
# -snapshot:
#    FORMAT : Y|N|S - Yes, No or Small (Without bet types)
#    DESC   : Produce a snapshot of all the arrays in memory on error
#    DEFAULT: Y
#
# -combi_mkts:
#    FORMAT : LIST of class_id1 {mkt_sort1 mkt_sort2 ...}
#                     class_id2 {mkt_sort3 ..} ...
#    DESC   : List of market sorts that can be combined under the same event.
#             For instance you may well want to combine Odd/Even markets with
#             Head to Head markets if you deem the two to be unrelated
#    EXAMPLE: Basket ball we are going to allow HH to be combined with OE
#             ob_bet::init -combi_mkts {"BB" {"OE" "HH"}}
#    DEFAULT: {}
#
# -ew_mixed_multiple
#    FORMAT : Y|N
#    DESC   : If N: every leg needs eachway available for the bet to be each way
#             If Y: Only one leg needs to have each way available, the rest
#             will have lines on the win leg where they would have been places.
#    EXAMPLE: Selection A - EW not avail, B EW avail C EW not avail
#             Treble would have two lines:
#             Win Line  : A Wins - B Wins   - C Wins
#             Place Line: A Wins - B Places - C Wins
#    DEFAULT: Y
#
#
# -leg_max_combi
#    FORMAT : LIST  leg_type1 allow_combi1 max_combi1 max_selns1
#                   leg_type2 allow_combi2 max_combi2 ...
#    DESC   : Allows the site to limit accumulators on certain bet types
#             n.b. There is no need to set for Tricasts/Combination Tricasts
#             Fist Scorer/Correct Score SC and AH as these
#             are constrained in the
#             Database to only be in Singles.
#             Can combi indicates whether the leg can be permed at all ie
#             Y 1 1 would indicate that the selection can only be singles
#             but may be placed in a permed single
#             N 1 1 would indicate that the leg can only be placed in a single
#             by itself
#    EXAMPLE: I want to only allow FS in singles and SF,RF,CF in maximum of
#             trebles from 8 selections
#             ob_bet::init -leg_max_combi {FS Y 1 1 SF Y 3 8 RF Y 3 8 CF Y 3 8}
#    DEFAULT: {}
#
# -sources
#    FORMAT : STRING of Channels that we will be using from this application.
#    DESC   : This allows the data associated with these channels to be loaded
#             on startup.
#             nb: No other channels other than thoses listed on start up can
#             be used in bet placement
#    EXAMPLE: I might want to place bets from my applcation via the elite
#             telebet and shop channels
#             ob_bet::init -sources "LPS"
#    DEFAULT: {}
#
# -exotic_prices
#    FORMAT : LIST of price_type1 {class_sort1 class_sort 2...} ...
#    DESC   : Price type other than L Live S Starting and D Dividends that
#             are used normally in racing
#             Allowed exotic price types are:
#             B - Best Price
#             1 - First Show
#             2 - Second Show
#             N - Next Show
#    EXAMPLE: We want to allow all the above exotic types on Horse Racing
#             and Greyhounds
#             ob_bet::init -exotic_prices {B {HR GR} 1 {HR GR}\
#                                          2 {HR GR} N {HR GR}}
#    DEFAULT: {}
#
# -max_mult_selns
#    FORMAT  : SMALLINT
#    DESC    : Maximum number of selections that can be accumuated in a
#              multiple
#    DEFAULT : 20
#
# -cum_stakes_qry
#   FORMAT   : DB QUERY - must take 22 args -
#              cust_id
#              cumulative stake time (in seconds)
#              Up to 20 selections
#   DESC     : If you want to use a query that will only take into account
#              singles or certain leg types this can be registered here
#   DEFAULT  : {}
#
# -anon_cum_stakes_delay
#   FORMAT   : INT
#   DESC     : Anonymous cumulative stakes delay. Set this to 0 if you dont
#              want an anonymous cumulative stakes delay. If you dont set this
#              then it will get the anonymous cumulative stakes delay from
#              tControl. Set tControl to 0 if you dont want an anonymous
#              cumulative stakes delay across all channels.
#   DEFAULT  : {}
#
# -liabs
#   FORMAT   : Y|N
#   DESC     : Have bets placed update the liability tables
#   DEFAULT  : Y
#
# -seln_scale_factor_proc
#
# -fscs_price_proc
#
# -potential_winnings
#   FORMAT   : Y|N
#   DESC     : Work out the potential winnings for a bet
#   DEFAULT  : N
#
# -gp_potential_winnings
#   FORMAT   : Y|N
#   DESC     : Work out the potential winnings for a Guaranteed Price bet
#              (price_type = G)
#              -potential_winnings needs to enabled for the flag to take
#              effect
#   DEFAULT  : N
#
# -allow_pl_on_ew
#   FORMAT   : Y|N
#   DESC     : Will allow customers to place place bets if market has ew_avail or pl_avail
#   DEFAULT  : N
#
# -allow_perm
#   FORMAT   : Y|N
#   DESC     : Should perming of bets be allowed
#   DEFAULT  : Y
#
# -credit_pay_stake_later
#   FORMAT   : Y|N
#   DESC     : Should credit customers always pay later or only on ante-post bets
#   DEFAULT  : N
#
# -ah_split_line_two_legs
#   FORMAT   : Y|N
#   DESC     : If the split line is two legs, AH bets are singles only
#              Otherwise they can be places as multiples (but you should
#              check that your APC can handle this before saying Y)
#   DEFAULT  : Y
#
# -ignore_price_change
#   FORMAT   : prc_better|prc_prompt|prc_all|N|Y
#   DESC     : If prc_better, we ignore price changes if the odds have lengthened
#              The reasoning is that if the bet loses, the customer doesn't
#              care what the price was, and if it wins, the customer will
#              be pleased that they got a better price. If prc_all it will accept
#              all price changes even if the odds have shortened and finally
#              if the value is prc_prompt it will cause an override in any case.
#              The N and Y are just included for backwards compatibility. These
#              are mapped as follows:
#                N -> prc_better
#                Y -> prc_all
#   DEFAULT  : prc_better
#
#
# -ignore_hcap_change
#   FORMAT   : Y|N
#   DESC     : If Y we dont display Hcap changes
#              If N we DO display hcap changes
#   DEFAULT  : N
#
# -best_price_change
#   FORMAT   : Y|N
#   DESC     : Only applicable if -server_price_change=Y
#              If Y and the price has lengthened take the best price, i.e.
#              the database price. If N, then use the submitted price
#   DEFAULT  : Y
#
# -allow_ew_on_favourite
#   FORMAT   : Y|N
#   DESC     : If set to no, do not allow each-way bets to be placed on an
#              unnamed favourite.
#   DEFAULT  : Y
#
# -oc_variants
#   FORMAT   : Y|N
#   DESC     : If yes, adjust betting limits for "oc variants". OC variants
#              appear in handicap markets where the customer can adjust the
#              handicap line
#   DEFAULT  : N
#
# -locale_inclusion
#   FORMAT   : Y|N
#   DESC     : Do sports bets include customer locale information
#   DEFAULT  : N
#
# -server_bet_delay
#   FORMAT   : Y|N
#   DESC     : Any bet[s] made against a started BIR market that has a bir_delay,
#              will be held in a queue and processed by the bet_delay application
#              (this includes BIR bets that part of combination). After 'n' seconds the
#              application will attempt to place the bet. The caller must poll the DB every
#              'n' seconds and wait for bet_delay's outcome. Once the outcome is found,
#              caller should display the bet-receipt or overrides.
#              The delay will stop any advantage gained at being at the event,
#              or viewing via a faster feed, e.g. terrestrial is quicker than satellite,
#              etc.
#   DEFAULT  : N
#
# -server_bet_def_delay
#   FORMAT   : INT
#   DESC     : Denote a default bir_delay (seconds), if zero, then no default
#              If supplied, then any market which does not have a bir_delay, then this
#              value will be used as the bet delay
#   DEFAULT  : 0
#
# -async_bet
#    FORMAT  : Y|N
#    DESC    : Enable Asynchronous Betting - bet is parked if it exceeds some limits.
#              If enabled, the package will always check tControl.async_bet when
#              placing/checking the bets.
#    DEFAULT : Y
#
# -async_bet_rules
#    FORMAT  : Y|N
#    DESC    : Enable Asynchronous Betting Rules - enable the auto-referral 1,2 and liability rules
#    DEFAULT : N
#
# -async_enable_intercept
#
#    FORMAT  : Y|N
#    DESC    : Enable Asynchronous Intercept Value Logic- enable intercept value logic
#    DEFAULT : N
#
# -async_enable_liab
#
#    FORMAT  : Y|N
#    DESC    : Enable Bets to Go Async when liability is breached
#    DEFAULT : N
#
# -async_do_liab_on_check
#
#    FORMAT  : Y|N
#    DESC    : Enable async liability check to be performed when calling check bet
#    DEFAULT : N
#
# -async_num_bet
#    FORMAT  : INT
#    DESC    : Max number of bets that are allowed to be refered
#    DEFAULT : -1
#
# -async_no_intercept_grp
#    FORMAT  : STRING
#    DESC    : liab group that is never referred from tLiabGroup
#    DEFAULT : ""
#
# -async_bet_recent_time
#    FORMAT  : INT
#    DESC    : Time interval in hours to look for resubmission of async bets
#              A value of 0 will turn this off
#    DEFAULT : 0
#
# -manual_bet_max_payout
#    FORMAT  : FLOAT
#    DESC    : The max payout for manual bets (in GBP)
#    DEFAULT : ""
#
# -manual_bet_allow_on_course
#    FORMAT  : Y|N
#    DESC    : Allow On Course manual bets
#    DEFAULT : N
#
# -manual_bet_allow_unvetted
#    FORMAT  : Y|N
#    DESC    : Allow manual bets without an admin checking them first
#    DEFAULT : Y
#
# -max_mult_bet
#   FORMAT   : Y|N
#   DESC     : If yes, use max_multiple_bet values for multiple bet limits
#   DEFAULT  : Y
#
# -keep_uid
#   FORMAT   : Y|N
#   DESC     : On placement of multiple bets, share the same uid.
#              If N, then the uid is only set for the 1st bet, remaining will be blank
#   DEFAULT  : Y
#
# -offline_liab_eng_rum
#   FORMAT   : Y|N
#   DESC     : Queue the bet for the RUM engine.  Usually bets are only taken into
#              consideration for RUM when the selection is resulted.  Turning this on
#              will make RUM pick it up at bet placement.
#   DEFAULT  : N
#
# -offline_liab_eng_sgl
#   FORMAT   : Y|N
#   DESC     : Queue singles as well as multiples (see offline_liab_eng_rum)
#   DEFAULT  : N
#
# -bet_receipt_format
#   FORMAT   : int
#   DESC     : parameter used to set optional receipt formats in pBetReceiptNum
#   DEFAULT  : 0
#
# -bet_receipt_tag
#   FORMAT   : char(1)
#   DESC     : an optional tag to add to the receipt format. For example 'F' or
#              'N' to designate onshore/offshore systems.
#   DEFAULT  : ""
#
#
# -inc_plc_in_constr_liab
#   FORMAT   : Y|N
#   DESC     : If yes, take place stake into account when updating the
#              tEvOcConstr and tEvMktConstr tables used by the stake/liab
#              alarms.
#   DEFAULT  : N
#
# -allow_stk_fac_profiles
#   FORMAT   : Y|N
#   DESC     : If yes, then apply stake factor profiles hanging off the
#              tStkFacProfile table, which allows (for example) stake factors
#              to be modified depending on the time to the start
#   DEFAULT  : N
#
# -link_accounts
#   FORMAT   : Y|N
#   DESC     : If yes, we will treat accounts that have been flagged as
#              'linked' as one single account. This means cumulative stakes
#              are combined and the lowest customer max stake factor is used.
#   DEFAULT  : N
#
# -freebet_in_tran
#   FORMAT   : Y|N
#   DESC     : If no then freebets are taken out of the placebet transaction
#              to reduce the length of the transaction
#   DEFAULT  : Y
#
# -scale_bet_type_max
#   FORMAT   : Y|N
#   DESC     : If yes, adjust the tBetType.max_bet according the the scale
#              factor for the bet.
#   DEFAULT  : Y
#
# -cross_bet_maxima
#   FORMAT   : Y|N
#   DESC     : If yes, take into account stakes from the other bets when
#              calculating the max bet for each bet at placement.
#   DEFAULT  : N
#
# -use_tolerance
#   FORMAT   : Y|N
#   DESC     : flag to activate/deactivate index delta tolerance.
#              Tolerance is important in financial markets where the index/handicap
#              value changes very frequently. If the changes are within a tolerance
#              margin the customer will not be prompted and the bet will be placed.
#              Otherwise the customer will be alerted about the changes in the index.
#   DEFAULT  : Y
#
# -low_funds_override
#   FORMAT   : Y|N
#   DESC     : If set to N, prevent the bet packages to raise the LOW_FUNDS override
#   DEFAULT  : Y
#
# -seln_suspended_override
#   FORMAT   : Y|N
#   DESC     : If set to N, prevent the bet packages to raise the SELN override
#   DEFAULT  : Y
#
# -ev_started_override
#   FORMAT   : Y|N
#   DESC     : If set to N, prevent the bet packages to raise the START override
#   DEFAULT  : Y
#
# -shop_bet_referral
#   FORMAT   : Y|N
#   DESC     : If set to Y, indicates that this is a case of shop betting submitted for
#              for referral. In this case all bets will be async parked with the reason
#              ASYNC_PARK_SHOP_REFERRAL
#   DEFAULT  : N
#
# -shop_bet_notification
#   FORMAT   : Y|N
#   DESC     : If set to Y, indicates that this is a case of a shop account making
#              bet notifications. Certain errors won't get raised if that's the case.
#              (Because the bet has already been placed and money has been exchanged)
#
# -async_intercept_on_place
#    FORMAT  : Y|N
#    DESC    : If set to Y, intercept and park any bets that breach liability
#              limits on bet placement, if N then proceed as normal and allow
#              bet to be placed (as some apps may already have checked this)
#
# -log_punter_total_bets
#   FORMAT   : Y|N
#   DESC     : If set to Y, get stake already placed on bets for logged shop
#              punters from other shops
#   DEFAULT  : N
#
#
# -dflt_sp_num_guide
#   FORMAT   : int
#   DESC     : default guide starting price if not set in the event hierarchy
#   DEFAULT  : 5
#
# -dflt_sp_den_guide
#   FORMAT   : int
#   DESC     : default guide starting price if not set in the event hierarchy
#   DEFAULT  : 2
#
proc ::ob_bet::init args {

	# log input params
	_log INFO "API(init): $args"

	variable TYPE
	variable CHANNEL
	variable INIT
	variable CONFIG

	if {[info exists INIT] && $INIT == 1} {
		#already inistialised
		_log WARN "Bet package already initialised."
		return
	}

	_log INFO "Initialising bet package ..."
	set INIT 0

	_log INFO "Configuring bet package ..."

	# defaults
	set CONFIG(source)                 I
	set CONFIG(max_mult_selns)         20
	set CONFIG(sep_cum_max_stk)        N
	set CONFIG(cum_stakes_qry)         "ob_bet::cum_stake"
	set CONFIG(anon_cum_stakes_delay)  ""
	set CONFIG(snapshot)               Y
	set CONFIG(seln_scale_factor_proc) ""
	set CONFIG(receipt_format_proc)    ""
	set CONFIG(combi_mkts)             ""
	set CONFIG(ew_mixed_multiple)      Y
	set CONFIG(fscs_price_proc)        "_get_fscs_price"
	set CONFIG(fscs_price_proc_args)   [list\
		sc_type\
		lp_num_CS\
		lp_den_CS\
		lp_num_FS\
		lp_den_FS\
		lp_num_MR\
		lp_den_MR\
		fs_result\
		cs_home\
		cs_away\
	]
	set CONFIG(liabs)                  Y
	set CONFIG(potential_winnings)     Y
	set CONFIG(gp_potential_winnings)  N
	set CONFIG(allow_pl_on_ew)         N
	set CONFIG(allow_perm)             Y
	set CONFIG(credit_pay_stake_later) N
	set CONFIG(allow_cash_customer)    N
	set CONFIG(ah_split_line_two_legs) Y
	set CONFIG(ignore_price_change)    "prc_better"
	set CONFIG(ignore_hcap_change)     N
	set CONFIG(best_price_change)      Y
	set CONFIG(allow_ew_on_favourite)  Y
	set CONFIG(oc_variants)            N
	set CONFIG(locale_inclusion)       N
	set CONFIG(server_bet_delay)       N
	set CONFIG(server_bet_def_delay)   0
	set CONFIG(async_bet)              Y
	set CONFIG(async_bet_rules)        N
	set CONFIG(async_enable_intercept) Y
	set CONFIG(async_enable_liab)      N
	set CONFIG(async_do_liab_on_check) N
	set CONFIG(async_num_bet)          -1
	set CONFIG(async_no_intercept_grp) ""
	set CONFIG(async_bet_recent_time)  0
	set CONFIG(manual_bet_max_payout)  ""
	set CONFIG(manual_bet_allow_on_course) N
	set CONFIG(manual_bet_allow_unvetted)  Y
	set CONFIG(max_mult_bet)           Y
	set CONFIG(keep_uid)               Y
	set CONFIG(offline_liab_eng_rum)   N
	set CONFIG(offline_liab_eng_sgl)   N
	set CONFIG(bet_receipt_format)     0
	set CONFIG(bet_receipt_tag)        ""
	set CONFIG(inc_plc_in_constr_liab) N
	set CONFIG(freebet_fast_action)    Y
	set CONFIG(allow_stk_fac_profiles) N
	set CONFIG(link_accounts)          N
	set CONFIG(freebet_in_tran)        Y
	set CONFIG(scale_bet_type_max)     Y
	set CONFIG(cross_bet_maxima)       Y
	set CONFIG(use_tolerance)          Y
	set CONFIG(low_funds_override)     Y
	set CONFIG(seln_suspended_override) Y
	set CONFIG(ev_started_override)    Y
	set CONFIG(shop_bet_referral)      N
	set CONFIG(shop_bet_notification)  N
	set CONFIG(async_intercept_on_place)     Y
	set CONFIG(log_punter_total_bets)  N
	set CONFIG(dflt_sp_num_guide)      5
	set CONFIG(dflt_sp_den_guide)      2

	eval _set_config $args


	# default add_leg parameters
	_log INFO "default leg parameters..."

	#              name         type      optional  min max default
	_add_leg_param leg_sort     CHAR      1         2   2
	_add_leg_param price_type   CHAR      1         1   1
	_add_leg_param lp_num       INT       1         1
	_add_leg_param lp_den       INT       1         1
	_add_leg_param hcap_value   NUMERIC   1
	_add_leg_param bir_index    INT       1         0
	_add_leg_param banker       YN        0         1   1   N
	_add_leg_param selns        LIST_INTS 0
	_add_leg_param ew_fac_num   INT       1         1
	_add_leg_param ew_fac_den   INT       1         1
	_add_leg_param ew_places    INT       1         1
	_add_leg_param prev_lp_num  INT       1         1
	_add_leg_param prev_lp_den  INT       1         1
	_add_leg_param prev_hcap_value NUMERIC   1


	# prepare package queries
	::ob_bet::_log INFO "preparing queries ..."
	_prepare_bet_qrys
	_prepare_place_qrys
	_prepare_seln_qrys
	_prepare_cust_qrys
	_prepare_util_qrys
	_prepare_override_qrys
	_prepare_liab_qrys
	_prepare_fbet_qrys
	_prepare_async_qrys
	_prepare_manual_qrys
	_prepare_bir_qrys
	_prepare_limit_qrys


	# The bet type info will be loaded on demand.
	catch {unset TYPE}

	# Channel information
	_log INFO "initialising channel info ..."
	set rs [ob_db::exec_qry ob_bet::get_channel]
	set n_rows [db_get_nrows $rs]

	for {set r 0} {$r < $n_rows} {incr r} {
		set chn [db_get_col $rs $r channel_id]
		if {[string first $chn $CONFIG(sources)] != -1} {
			set CHANNEL($chn,max_stake_mul) [db_get_col $rs $r max_stake_mul]
			# TODO - do we need this?
			set CHANNEL($chn,tax_rate) [db_get_col $rs $r tax_rate]
		}
	}
	ob_db::rs_close $rs

	if {[get_config freebet_fast_action] == "Y"} {
		package require fbets_fbets
		ob_fbets::init
	}

	# If we're using the bet-delay package, we'll need to import the cust_flag package
	if {$CONFIG(server_bet_delay) == "Y"} {
		package require cust_flag
		ob_cflag::init
	}

	set INIT 1
	::ob_bet::_log INFO "End of bet package initialisation"
}



#API:load_snapshot - Load a memory snapshot from the logfile
# Usage:
# ob_bet::load_snapshot {id filename}
#
# For use in debugging purposes. Can be given a snapshot
# and initiate the arrays to those values so that errors
# may be recreated easily
#
# Parameters:
# id:
#    FORMAT : VARCHAR
#    DESC   : Full snapshots will be logged with a snapshot id.
# filename:
#    FORMAT : Filename
#    DESC   : Filename containing the snapshot
#
# offline:
#    FORMAT : 1|0
#    DESC   : if true will assume that the information has been loaded
#             from a different DB and and hence will not attempt to execute
#             any queries based on the loaded data
#
# EXAMPLE:
#
#   We have a log file bet_test.log.20040611 contailing the following extract
#      ...
#      SNAPSHOT-1029922291 CONFIG cum_stakes_qry = ob_bet::cum_stake
#      SNAPSHOT-1029922291 CONFIG sep_cum_max_stk = N
#      SNAPSHOT-1029922291 CONFIG receipt_format_proc =
#      ...
#
#   To load the extract into memory as it was at that time:
#      ::ob_bet::load_snapshot SNAPSHOT-1029922291 bet_test.log.20040611 1
#
proc ::ob_bet::load_snapshot {id filename {offline 1}} {

	# log input params
	_log INFO "API(load_snapshot) $id $filename"

	variable ALL_ARRAYS
	variable OFFLINE

	set OFFLINE $offline

	foreach arr $ALL_ARRAYS {
		variable $arr
		array unset $arr
	}

	set fh [open $filename r]

	# regexping for somthing like
	# SNAPSHOT-747354948 GROUP 0,7,num_lines = 1
	set re [subst\
				-nocommands\
				-nobackslashes\
				{${id}\s([^\s]+)\s([^\s]+)\s=\s(.*)}]
	puts $re
	while {![eof $fh]} {
		gets $fh line
		if {[regexp $re $line all arr n v]} {
			_log INFO "loading $arr $n $v ..."
			set ${arr}($n) $v
		}
	}
	close $fh
}



#API:clear - Resets bet placement memory
# Usage:
# ob_bet::clear {}
#
# Will clear all data generated on a request
#
# Parameters: none
#
proc ::ob_bet::clear {} {

	# log input params
	_log INFO "API(clear)"

	if {[catch {
		set ret [_clear]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:snapshot - Write a memory snapshot to the log file
# Usage:
# ob_bet::snapshot {arr ""}
#
# provide snapshot of memory contents to the log file
# Can be useful for debugging purposes
#
# Parameters:
# arr:
#    FORMAT : Array name
#    DESC   : If blank a snapshot of all the arrays is written to the logs
#             else only the array specified
#    DEFAULT: ""
#
# Example: Print out the contents of the bet array
#          ob_bet::snapshot BET
#
proc ::ob_bet::snapshot {{arr ""}} {

	# log the input parameters
	_log INFO "API(snapshot): $arr"

	if {[catch {
		set ret [eval _snapshot {$arr}]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:get_config Get current settings of a congif parameter
# Usage
# ::ob_bet::get_config param
#
# Parameters:
# param:   FORMAT: VARCHAR DESC: Paramters described in ob_bet::init
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_config sources
# 1 IP
# > ::ob_bet::get_config exotic_prices
# 0 "" # not found
proc ::ob_bet::get_config {param} {

	# log input params
	_log INFO "API(get_config) $param"

	if {[catch {
		set ret [eval _get_config {$param}]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:set_config - Set a bet placement config parameter
# Usage:
# ob_bet::set_config args
#
# Used to change configuration parameters without reinitialising bet placement
# only the following args can be set from non-initialisation:
#
# -source
# -sep_cum_max_stk
# -combi_mkts
# -ew_mixed_multiple
#
# see init above for parameter descriptions
#
proc ::ob_bet::set_config args {

	# log input params
	_log INFO "API(set_config) $args"

	if {[catch {
		set ret [eval _set_config $args]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:get_type Get bet type information
# Usage
# ::ob_bet::get_type bet_type param
#
# Parameters:
# bet_type FORMAT: CHAR(4) DESC: tBetType.bet_type
# param:   FORMAT: VARCHAR
#          DESC:   bet_type,bet_name,num_selns,num_lines
#                  min_bet,max_bet,is_perm,max_perms
#                  min_combi,max_combi,num_bets_per_seln,channels
#                  disporder
#
# RETURNS:
# {found 0|1 value}
#
# EXAMPLE:
# > ::ob_bet::get_type PAT num_lines
# 1 7
# > ::ob_bet::get_type ALPH max_bet
# 0 "" # not found
proc ::ob_bet::get_type {bet_type param} {

	# log input params
	_log INFO "API(get_type): $bet_type,$param"

	if {[catch {
		set ret [eval _get_type {$bet_type} {$param}]
	} msg]} {
		_err $msg
	}

	return $ret
}



#API:add_leg_param Adds a new parameter to the leg format definition
# Usage
# ::ob_bet::add_leg_param name type optional ?min ?max ?default
#
# Called during the initialization of the bet package to set the default format
# of a leg.
#
# Parameters:
# name      FORMAT: VARCHAR  DESC: leg parameter name (i.e. price_type)
# type      FORMAT: VARCHAT  DESC: leg parmaeter data type
#                                  INT|NUMERIC|YN|LISTS_INTS
# optional  FORMAT: 0|1      DESC: defines if a parameter value can be null
# min       FORMAT: INT      DESC: parameter min length
#                            DEF:  ""
# max       FORMAT: INT      DESC: parameter max length
#                            DEF:  ""
# def       FORMAT: VARCHAR  DESC: value representing the default value
#                                 (only used when the parameter is not optional)
#                            DESC: ""
#
# RETURNS:
# 1
#
proc ::ob_bet::add_leg_param {name type optional {min ""} {max ""} {def ""}} {

	_log INFO "API(add_leg_param): $name,$type,$optional,$min,$max,$def"

	if {[catch {
		set ret [_add_leg_param $name $type $optional $min $max $def]
	} msg]} {
		_err $msg
	}

	return $ret
}

#API:reg_external Register an "external" bet flavour.
#
# Parameters:
#
#   externalFlavour
#     A name for this type of external bet (e.g. MAN, XGAME, POOL)
#
#   checkCmd
#     Fully-qualified Tcl command to call to verify that a given external
#     bet of this flavour could be placed. The command will receive 2 args:
#     ob_bet_num and externalRef. checkCmd must return the cost of the bet
#     in the customer's currency. checkCmd should normally use procedure
#     *ob_bet::need_override* to indicates problems with the bet. However,
#     it may throw an error to indicate the bet is bad. checkCmd may or may
#     not be called within a transaction.
#
#   placeCmd
#     Fully-qualified Tcl command to call to place a given external bet of
#     this flavour. It will receive 3 args: ob_bet_num, externalRef and
#     placeInfo, where placeInfo is a name-value pair list containing keys:
#       cust_id, uid, ip_addr, placed_by, term_code, call_id, aff_id, slip_id
#     placeCmd will be called within a transaction to place the bet. It may
#     assume that checkCmd has been called for the bet in the same transaction
#     and any overrides have been dealt with. It should return a two-element
#     list containing the bet identifier and receipt on success, or throw an
#     error on failure (in which case the bet packages will take
#     responsibility for rolling back the transaction). Note that it is too
#     late to request overrides by this stage - this will have no effect.
#
#   completeCmd (Optional)
#     Fully-qualified Tcl command to call to complete a given external bet.
#     This happens outside the bet placement transaction and was originally
#     added for pools bets that cannot be placed during a transaction as they
#     make calls to 3rd parties.
#     It will receive the bet identifier that placeCmd returned and does not
#     need to return anything, but should throw an error if it has any
#     problems.
#
# Returns:
#
#   Nothing useful.
#
# Notes:
#
#   Sometimes non-sports bets such as xgame or pools bets need to be placed
#   at the same time as regular sports bets. These non-sports bets are known
#   as "external bets" from the point-of-view of the bet packages.
#
#   It's useful to add the external bets to the bet packages so that the bet
#   packages can handle funds checks and overrides for them, and also so that
#   they can be placed in the same transaction as the sports bets.
#
#   *ob_bet::reg_external* can be used to register a particular "flavour" of
#   external bet (e.g. MAN or XGAMES). This involves supplying procs that the
#   bet packages can call to check & place external bets of that flavour.
#
#   *ob_bet::add_bet_external* can then be used to add external bets to the
#   packages. These will be checked and placed along with the other bets when
#
proc ob_bet::reg_external {externalFlavour checkCmd placeCmd {completeCmd ""}} {

	#log input params
	_log INFO "API([info level 0])"

	if {[catch {
		set ret [_reg_external $externalFlavour $checkCmd $placeCmd $completeCmd]
	} msg]} {
		_err $msg
	}

	return $ret
}

# API:get_leg_param_names Get the leg parameter names
# Usage
# ::ob_bet::get_leg_param_names
#
# Parameters:
#
# RETURNS:
# List of the leg parameters name
#
proc ::ob_bet::get_leg_param_names {} {

	if {[catch {
		set ret [_get_leg_param_names]
	} msg]} {
		_err $msg
	}
	return $ret

}

# API:get_leg_param_format Get the format of a specific leg parameters
#
# Parameters:
#  - name, name of the leg parameter
#
# RETURNS:
#  - parameter format
#     {type optional min max default} if parameter name was found
#
proc ::ob_bet::get_leg_param_format {name} {

	#log input params
	_log INFO "API(get_leg_param_format): $name"


	if {[catch {
		set ret [_get_leg_param_format $name]
	} msg]} {
		_err $msg
	}
	return $ret

}

#END OF API..... private procedures



# prepare DB queries
#
proc ::ob_bet::_prepare_bet_qrys {} {

	ob_db::store_qry ob_bet::get_types {
		select
		  bet_type,
		  bet_name,
		  blurb,
		  num_selns,
		  num_lines,
		  min_bet,
		  max_bet,
		  is_perm,
		  max_perms,
		  min_combi,
		  max_combi,
		  num_bets_per_seln,
		  channels,
		  bet_settlement,
		  line_type,
		  disporder,
		  stake_factor
		from
		  tBetType
		where
		  status = 'A'
		order by disporder
	}

	ob_db::store_qry ob_bet::get_channel {
		select
		  channel_id,
		  tax_rate,
		  NVL(max_stake_mul, 1.00) as max_stake_mul
		from
		  tChannel
	}

	# horrible table scanning query but only
	# actioned on start up
	ob_db::store_qry ob_bet::get_CB_id {
		select
		  cust_id
		from
		  tcustomer
		where
		  type = 'H'
		and
		  status = 'A'
	}

	ob_db::store_qry ob_bet::get_risk_limit_info {
		select
			num_legs,
			num_legs_risky,
			win_limit,
			bet_limit
		from
			tMulRiskLimit
		order by
			num_legs,
			num_legs_risky
	} 3600
}

# part of the hack used in shake a bet - one step bet placement
#
proc ::ob_bet::clear_bet_array {} {
	variable BET
	array unset BET
}

# just_db will not reset CUST and LEG details if non zero
#
proc ::ob_bet::_clear {{just_db 0}} {

	variable CUST
	variable CUST_DETAILS
	variable LEG
	variable SELN
	variable VERIFY
	variable GROUP
	variable BET
	variable OVERRIDE
	variable COMBI
	variable LIAB
	variable TOKEN
	variable VALID_TOKENS
	variable FREEBET_CHECKS

	::ob_bet::_log INFO "Clearing existing data"

	if {!$just_db} {
		array unset CUST
		array unset LEG
		array unset SESSION_CONFIG
	}
	array unset CUST_DETAILS
	array unset SELN
	array unset VERIFY
	array unset GROUP
	array unset BET
	array unset OVERRIDE
	array unset COMBI
	array unset LIAB
	array unset TOKEN
	array unset VALID_TOKENS
	array unset FREEBET_CHECKS
}



# take a snapshot of memory
#
proc ::ob_bet::_snapshot {{arr ""}} {

	variable SNAPSHOT_ARRAYS

	_log INFO "SNAPSHOT arrays: $SNAPSHOT_ARRAYS"

	# for debug purposes print out whats in arrays
	if {$arr == ""} {
		set snapshot_id "SNAPSHOT[clock clicks]"
	} else {
		set snapshot_id ""
	}

	foreach a $SNAPSHOT_ARRAYS {
		if {$arr == "" || $arr == $a} {
			variable $a
			if {[info exists $a]} {
				foreach n [lsort -dictionary [array names $a]] {
					_log INFO "$snapshot_id $a $n = [set ${a}($n)]"
				}
			} else {
				_log INFO "$a not set"
			}
		}
	}
}



# set a config parameter - If the bet package has already been initialised
# it will only set the parameter for that request
#
proc ::ob_bet::_set_config args {

	variable INIT
	variable CONFIG
	variable SESSION_CONFIG
	variable LEG_MAX_COMBI
	variable SNAPSHOT_ARRAYS
	variable ALL_ARRAYS

	# Has bet package been initialised?
	if {![info exists INIT]} {
		error\
			"Bet package hasn't been initialised call ob_bet::init"\
			""\
			BET_NOT_INITIALISED
	}

	# correct number of args
	if {([llength $args] % 2) != 0} {
		error\
			"usage ::ob_bet::config -cfg_nm1 cfg_val1 -cfg_nm2 cfg_val2 ..."\
			""\
			BET_SETCONFIG_USAGE
	}

	if {$INIT} {
		# already initialised just set the value for this session
		_smart_reset SESSION_CONFIG
		set arr SESSION_CONFIG
	} else {
		set arr CONFIG
	}

	# process arguments
	foreach {n v} $args {
		switch -- $n {
			"-source" {
				if {[string length $v] != 1} {
					error\
						"source should only be 1 character long"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(source) $v
			}
			"-receipt_format_proc" {
				set ${arr}(receipt_format_proc) $v
			}
			"-sep_cum_max_stk" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -sep_cum_max_stk Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(sep_cum_max_stk) $v
			}
			"-snapshot" {
				if {$INIT != 0} {
					error\
						"snapshot can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N" && $v != "S"} {
					error\
						"usage: -snapshot Y|N|S"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(snapshot) $v

				if {$v == "S"} {
					# a small snapshot not including type info
					set SNAPSHOT_ARRAYS [list]
					foreach a $ALL_ARRAYS {
						if {$a != "TYPE"} {
							lappend SNAPSHOT_ARRAYS $a
						}
					}
				}
			}
			"-combi_mkts" {
				if {[llength $v] % 2 != 0} {
					error\
						"usage: -combi_mkts class_id1 {mkt_sort1 mkt_sort2} ."\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(combi_mkts) $v
			}
			"-ew_mixed_multiple" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -ew_mixed_multiple Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(ew_mixed_multiple) $v
			}
			"-leg_max_combi" {
				if {$INIT != 0} {
					error\
						"max_mult_selns can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}

				if {[llength $v] % 4 != 0} {
					error\
						"usage: -leg_max_combi {leg1 can_combi1 max_combi1 max_selns1}"\
						""\
						BET_INVALID_CONFIGURATION
				}
				foreach {leg can_combi max_combi max_selns}  $v {
					if {[lsearch [list CT TC CS] $leg] != -1 && $can_combi != "N"} {
						error\
							"Cannot set leg sort for $leg: max combi = 1"\
							""\
							BET_INVALID_CONFIGURATION
					}
					set LEG_MAX_COMBI($leg)\
						[list $can_combi $max_combi $max_selns]
				}
			}
			"-sources" {
				if {$INIT != 0} {
					error\
						"max_mult_selns can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(sources) $v
			}
			"-exotic_prices" {
				if {$INIT != 0} {
					error\
						"max_mult_selns can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {[llength $v] % 2 != 0} {
					error\
						"usage: -exotic_prices price_type1 {class_sort1 ..} ."\
						""\
						BET_INVALID_CONFIGURATION
				}
				foreach {price class_sorts} $v {
					set ${arr}(exotic_prices,$price) $class_sorts
				}
			}
			"-max_mult_selns" {
				if {$INIT != 0} {
					error\
						"max_mult_selns can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(max_mult_selns) $v
			}
			"-cum_stakes_qry" {
				if {$INIT != 0} {
					error\
						"cum_stakes_qry can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(cum_stakes_qry) $v
			}
			"-anon_cum_stakes_delay" {
				if {$INIT != 0} {
					error\
						"anon_cum_stakes_delay can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(anon_cum_stakes_delay) $v
			}
			"-seln_scale_factor_proc" {
				if {$INIT != 0} {
					error\
						"seln_scale_factor_proc can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(seln_scale_factor_proc) $v
			}
			"-liabs" {
				if {$INIT != 0} {
					error\
						"liabs can only be turned on/off on init"\
						""\
						BET_INVALID_CONFIGURATION
				} elseif {$v != "Y" && $v != "N"} {
					error\
						"usage: -liabs Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(liabs) $v
			}
			"-fscs_price_proc" {
				if {$INIT != 0} {
					error\
						"fscs_price_proc can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(fscs_price_proc) $v
			}
			"-fscs_price_proc_args" {
				if {$INIT != 0} {
					error\
						"fscs_price_proc_args can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(fscs_price_proc_args) $v
			}
			"-potential_winnings" {
				if {$INIT != 0} {
					error\
						"winnings can only be turned on/off on init"\
						""\
						BET_INVALID_CONFIGURATION
				} elseif {$v != "Y" && $v != "N"} {
					error\
						"usage: -potential_winnings Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(potential_winnings) $v
			}
			"-gp_potential_winnings" {
				if {$INIT != 0} {
					error\
						"winnings can only be turned on/off on init"\
						""\
						BET_INVALID_CONFIGURATION
				} elseif {$v != "Y" && $v != "N"} {
					error\
						"usage: -gp_potential_winnings Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(gp_potential_winnings) $v
			}
			"-allow_pl_on_ew" {
				if {$INIT != 0} {
					error\
						"allow_pl_on_ew can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -allow_pl_on_ew Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(allow_pl_on_ew) $v
			}
			"-allow_perm" {
				if {$INIT != 0} {
					error\
						"allow_perm can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -allow_perm Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(allow_perm) $v
			}
			"-credit_pay_stake_later" {
				if {$INIT != 0} {
					error\
						"credit_pay_stake_later can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -credit_pay_stake_later Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(credit_pay_stake_later) $v
			}
			"-ah_split_line_two_legs" {
				if {$INIT != 0} {
					error\
						"ah_split_line_two_legs can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -ah_split_line_two_legs Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(ah_split_line_two_legs) $v
			}
			"-ignore_price_change" {
				if {$v != "prc_better" && $v != "prc_all" && $v != "prc_prompt" &&
					$v != "Y" && $v != "N"} {
					error\
						"usage: -ignore_price_change prc_better|prc_all|prc_prompt|N|Y"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(ignore_price_change) $v
				if {$v == "Y"} {
					set ${arr}(ignore_price_change) "prc_all"
				} elseif {$v == "N"} {
					set ${arr}(ignore_price_change) "prc_better"
				}
			}
			"-ignore_hcap_change" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -ignore_hcap_change Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(ignore_hcap_change) $v
			}
			"-best_price_change" {
				if {$INIT != 0} {
					error\
						"best_price_change can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -best_price_change Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(best_price_change) $v
			}
			"-allow_ew_on_favourite" {
				if {$INIT != 0} {
					error\
						"allow_ew_on_favourite can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -allow_ew_on_favourite Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(allow_ew_on_favourite) $v

			}
			"-oc_variants" {
				if {$INIT != 0} {
					error \
						"oc_variants can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -oc_variants Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(oc_variants) $v
			}
			"-max_mult_bet" {
				if {$INIT != 0} {
					error \
						"max multiple bet can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -max_mult_bet Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(max_mult_bet) $v
			}
			"-locale_inclusion" {
				if {$INIT != 0} {
					error \
						"locale_inclusion can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -locale_inclusion Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(locale_inclusion) $v
			}
			"-server_bet_delay" {
				if {$INIT != 0} {
					error \
						"server_bet_delay can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -server_bet_delay Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(server_bet_delay) $v
			}
			"-server_bet_def_delay" {
				if {$INIT != 0} {
					error \
						"server_bet_def_delay can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v] || $v < 0} {
					error\
						"usage: -server_bet_min_delay INTEGER >= 0"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(server_bet_def_delay) $v
			}
			"-async_bet" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_bet Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_bet) $v
			}
			"-async_bet_rules" {
				if {$INIT != 0} {
					error \
						"async_bet_rules can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_bet_rules Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_bet_rules) $v
			}
			"-async_enable_intercept" {
				if {$INIT != 0} {
					error \
						"async_enable_intercept can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_enable_intercept Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_enable_intercept) $v
			}
			"-async_enable_liab" {
				if {$INIT != 0} {
					error \
						"async_enable_liab can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_enable_liab Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_enable_liab) $v
			}
			"-async_do_liab_on_check" {
				if {$INIT != 0} {
					error \
						"async_do_liab_on_check can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_do_liab_on_check Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_do_liab_on_check) $v
			}
			"-async_num_bet" {
				if {$INIT != 0} {
					error \
						"async_num_bet can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v]} {
					error\
						"usage: -async_num_bet INTEGER"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_num_bet) $v
			}
			"-async_no_intercept_grp" {
				if {$INIT != 0} {
					error \
						"async_no_intercept_grp can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_no_intercept_grp) $v
			}
			"-async_bet_recent_time" {
				if {$INIT != 0} {
					error \
						"async_bet_recent_time can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v] || $v < 0} {
					error\
						"usage: -async_bet_recent_time INTEGER >= 0"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_bet_recent_time) $v
			}
			"-manual_bet_max_payout" {
				if {$INIT != 0} {
					error \
						"manual_bet_max_payout can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(manual_bet_max_payout) $v
			}
			"-manual_bet_allow_on_course" {
				if {$INIT != 0} {
					error \
						"manual_bet_allow_on_course can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(manual_bet_allow_on_course) $v
			}
			"-manual_bet_allow_unvetted" {
				if {$INIT != 0} {
					error \
						"manual_bet_allow_unvetted can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(manual_bet_allow_unvetted) $v
			}
			"-keep_uid" {
				if {$INIT != 0} {
					error \
						"keep_uid can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -keep_uid Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(keep_uid) $v
			}
			"-offline_liab_eng_rum" {
				if {$INIT != 0} {
					error \
						"offline_liab_eng_rum can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -offline_liab_eng_rum Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(offline_liab_eng_rum) $v
			}
			"-offline_liab_eng_sgl" {
				if {$INIT != 0} {
					error \
						"offline_liab_eng_sgl can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -offline_liab_eng_sgl Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(offline_liab_eng_sgl) $v
			}
			"-bet_receipt_format" {
				if {$INIT != 0} {
					error \
						"bet_receipt_format can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v]} {
					error\
						"usage: -bet_receipt_format <int>"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(bet_receipt_format) $v
			}
			"-bet_receipt_tag" {
				if {$INIT != 0} {
					error \
						"bet_receipt_tag can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {[regexp {[A-Za-z]} $v] == 0 && $v != ""} {
					error\
						"usage: -bet_receipt_tag <char(1)>"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(bet_receipt_tag) $v
			}
			"-inc_plc_in_constr_liab" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -inc_plc_in_constr_liab Y|N"\
						""\
						BET_INVALID_CONFIGURATION
					}
					set ${arr}(inc_plc_in_constr_liab) $v
				}
			"-freebet_fast_action" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -freebet_fast_action Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(freebet_fast_action) $v
			}
			"-allow_stk_fac_profiles" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -allow_stk_fac_profiles Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(allow_stk_fac_profiles) $v
			}
			"-link_accounts" {
				if {$INIT != 0} {
					error \
						"link_accounts can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -link_accounts Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(link_accounts) $v
			}
			"-freebet_in_tran" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -freebet_in_tran Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(freebet_in_tran) $v
			}
			"-scale_bet_type_max" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -scale_bet_type_max Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(scale_bet_type_max) $v
			}
			"-cross_bet_maxima" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -cross_bet_maxima Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(cross_bet_maxima) $v
			}
			"-use_tolerance" {
				if {$INIT != 0} {
					error \
						"use_tolerance can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -use_tolerance Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {$v == "Y"} {
					set ${arr}(use_tolerance) 1
				} else {
					set ${arr}(use_tolerance) 0
				}

			}
			"-low_funds_override" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -low_funds_override Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(low_funds_override) $v
			}
			"-seln_suspended_override" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -seln_suspended_override Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(seln_suspended_override) $v
			}
			"-ev_started_override" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -ev_started_override Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(ev_started_override) $v
			}
			"-shop_bet_referral" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -shop_bet_referral Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(shop_bet_referral) $v
			}
			"-shop_bet_notification" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -shop_bet_notification Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(shop_bet_notification) $v
			}
			"-log_punter_total_bets" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -log_punter_total_bets Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(log_punter_total_bets) $v
			}
			"-async_intercept_on_place" {
				if {$v != "Y" && $v != "N"} {
					error\
						"usage: -async_intercept_on_place Y|N"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(async_intercept_on_place) $v
			}
			"-dflt_sp_num_guide" {
				if {$INIT != 0} {
					error \
						"dflt_sp_num_guide can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v]} {
					error\
						"usage: -dflt_sp_num_guide <int>"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(dflt_sp_num_guide) $v
			}
			"-dflt_sp_den_guide" {
				if {$INIT != 0} {
					error \
						"dflt_sp_den_guide can only be set on init"\
						""\
						BET_INVALID_CONFIGURATION
				}
				if {![string is integer -strict $v]} {
					error\
						"usage: -dflt_sp_den_guide <int>"\
						""\
						BET_INVALID_CONFIGURATION
				}
				set ${arr}(dflt_sp_den_guide) $v
			}
			default {
				error\
					"unknown option $n"\
					""\
					BET_UNKNOWN_CONFIG_ITEM
			}
		}
	}

	# check source
	if {![info exists CONFIG(sources)]} {
		set CONFIG(sources) $CONFIG(source)
	}
	if {[string first $CONFIG(source) $CONFIG(sources)] == -1} {
		error\
			"source can only be set to $CONFIG(sources)"\
			""\
			BET_INVALID_SOURCE
	}

	# log the config entries on change for support purposes
	# as config files may have been changed
	_snapshot CONFIG

	# Log session configs as well as these take precedence
	# over the normal config, which might be the most confusing
	_snapshot SESSION_CONFIG
}



# get a config setting
#
proc ::ob_bet::_get_config {name} {

	variable CONFIG
	variable SESSION_CONFIG

	_smart_reset SESSION_CONFIG

	if {[info exists SESSION_CONFIG($name)]} {
		return $SESSION_CONFIG($name)
	}

	if {[info exists CONFIG($name)]} {
		return $CONFIG($name)
	}

	error\
		"Config param $name not found"\
		""\
		"BET_NO_CONFIG"
}



# throw an application error
#
proc ::ob_bet::_err {msg} {

	global errorInfo errorCode
	variable CONFIG

	_log ERROR $msg
	if {[_get_config snapshot] != "N"} {
		_snapshot
	}
	error $msg $errorInfo $errorCode
}



#This will reset the array if it hasn't already been set in this request
proc ::ob_bet::_smart_reset {array_name} {

	variable RESETABLE_ARRAYS
	variable RST_ARRAY_CACHE_T
	set reset 0

	if {[lsearch $RESETABLE_ARRAYS $array_name] == -1} {
		_err "Array $array_name is not resetable"
	}
	variable $array_name
	set req_id [reqGetId]

	if {![info exists ${array_name}(req_id)]} {
		set reset 1
	} elseif {[set ${array_name}(req_id)] != $req_id} {
		if {![info exists RST_ARRAY_CACHE_T($array_name)]} {
			# This array is reset on every request.
			set reset 1
		} else {
			# This array is reset at the start of a request only if
			# it hasn't been reset for a certain length of time.
			# Obviously, it's never appropriate to cache an
			# array that contains customer-specific info - be
			# careful what you put in RST_ARRAY_CACHE_T...
			set cache_t $RST_ARRAY_CACHE_T($array_name)
			if {![info exists ${array_name}(rst_t)]} {
				# We don't know when it was last reset.
				set reset 1
			} else {
				set rst_t [set ${array_name}(rst_t)]
				set age   [expr {[clock seconds] - $rst_t}]
				if {$age > $cache_t} {
					_log INFO "Will reset $array_name:\
				           age is $age vs cache time of $cache_t"
					set reset 1
				} else {
					set reset 0
				}
			}
			if {!$reset} {
				# Even though we're not resetting the array, we need
				# to update the req_id to avoid resetting it later in
				# this request.
				set ${array_name}(req_id) $req_id
			}
		}
	} else {
		set reset 0
	}

	if {$reset} {
		::ob_bet::_log DEBUG "Resetting $array_name array"

		array unset ${array_name}
		set ${array_name}(req_id) $req_id
		set ${array_name}(num)    0
		if {[info exists RST_ARRAY_CACHE_T($array_name)]} {
			set ${array_name}(rst_t) [clock seconds]
		}
	}

	return $reset
}


# Internal - load the bet type info into the TYPE array.
# Caller is responsible for resetting array first.
proc ::ob_bet::_load_bet_types {} {

	variable TYPE
	variable CONFIG

	::ob_bet::_log INFO "loading bet types ..."

	set rs [ob_db::exec_qry ob_bet::get_types]
	set n_rows [db_get_nrows $rs]
	set TYPE(COLS) [db_get_colnames $rs]

	for {set r 0} {$r < $n_rows} {incr r} {
		set bet_type [db_get_col $rs $r bet_type]
		set ip [db_get_col $rs $r is_perm]
		if {$ip == "Y" && $CONFIG(allow_perm) == "Y"} {
			set is_perm 1
		} else {
			set is_perm 0
		}
		set TYPE($bet_type,is_perm) $is_perm
		set num_selns [db_get_col $rs $r num_selns]

		set max_perms [db_get_col $rs $r max_perms]
		if {$max_perms == ""} {
			set max_perms $CONFIG(max_mult_selns)
		}

		set channels [db_get_col $rs $r channels]

		for {set s 0} {$s < [string length $CONFIG(sources)]} {incr s} {
			set src [string index $CONFIG(sources) $s]
			if {[string first [string index $CONFIG(sources) $s] $channels] != -1} {
				#bucket into number of selections
				if {$is_perm} {
					for {set i $num_selns} {$i <= $max_perms} {incr i} {
						lappend TYPE($src,$i) $bet_type
					}
				} else {
					lappend TYPE($src,$num_selns) $bet_type
				}
			}
		}

		foreach f $TYPE(COLS) {
			if {$f != "bet_type" &&
				$f != "channels" &&
				$f != "is_perm"} {
				set TYPE($bet_type,$f) [db_get_col $rs $r $f]
			}
		}
	}

	ob_db::rs_close $rs

	::ob_bet::_log INFO "Bet types loaded"

	return 1
}

# Get information about a bet type.
proc ::ob_bet::_get_type {bet_type param} {

	variable TYPE

	if {[_smart_reset TYPE]} {
		_load_bet_types
	}

	if {[info exists TYPE($bet_type,$param)]} {
		return [list 1 $TYPE($bet_type,$param)]
	} else {
		return [list 0 ""]
	}
}



# Get Multiples Risk Limits. Result set is cached and the relevant row is
# identified by db_search so no need to store data in an array.
#
proc ::ob_bet::_get_mul_risk_limits {num_legs num_legs_risky} {

	set rs [ob_db::exec_qry ob_bet::get_risk_limit_info]

	set row_num [db_search -sorted $rs [list \
									"num_legs"       int $num_legs \
									"num_legs_risky" int $num_legs_risky]]
	if {$row_num == -1} {
		ob_db::rs_close $rs
		return [list "" ""]
	}

	set win_limit [db_get_col $rs $row_num win_limit]
	set bet_limit [db_get_col $rs $row_num bet_limit]

	ob_db::rs_close $rs

	return [list $win_limit $bet_limit]
}

# Adds a new parameter to the leg format definition
#
proc ::ob_bet::_add_leg_param { name type optional {min ""} {max ""} {def ""} } {

	variable INIT
	variable LEG_FORMAT

	# bet package been initialised
	if {![info exists INIT]} {
		error\
			"Bet package hasn't been initialised call ob_bet::init"\
			""\
			BET_NOT_INITIALISED
	}

	# has this parameter already been defined
	if {[info exists LEG_FORMAT($name,type)]} {
		error\
			"Trying to overwrite LEG_FORMAT for $name"\
			""\
			LEG_PARAM_ALREADY_INITIALISED
	}

	set LEG_FORMAT($name,type)     $type
	set LEG_FORMAT($name,optional) $optional
	set LEG_FORMAT($name,min)      $min
	set LEG_FORMAT($name,max)      $max
	set LEG_FORMAT($name,def)      $def

	lappend LEG_FORMAT(names) $name

	return 1
}


# Register a flavour of external bet.
#
proc ob_bet::_reg_external {externalFlavour checkCmd placeCmd completeCmd} {

	variable CONFIG

	set CONFIG(ext,$externalFlavour,checkCmd)    $checkCmd
	set CONFIG(ext,$externalFlavour,placeCmd)    $placeCmd
	set CONFIG(ext,$externalFlavour,completeCmd) $completeCmd

	return
}


#API:get_leg_param_names Get the leg parameter names
# Usage
# ::ob_bet::get_leg_param_names
#
# Parameters:
#
# RETURNS:
# List of the leg parameters name
#
proc ::ob_bet::get_leg_param_names {} {

	if {[catch {
		set ret [_get_leg_param_names]
	} msg]} {
		_err $msg
	}
	return $ret

}

# Get all the leg parameter names
#
proc ::ob_bet::_get_leg_param_names {} {

	variable LEG_FORMAT
	variable INIT

	#Has bet package been initialised?
	if {![info exists INIT] || ![info exists LEG_FORMAT(names)]} {
		error\
			"Bet package hasn't been initialised call ob_bet::init"\
			""\
			BET_NOT_INITIALISED
	}

	return $LEG_FORMAT(names)
}


# API:get_leg_param_format Get the format of a specific leg parameters
#
# Parameters:
#  - name, name of the leg parameter
#
# RETURNS:
#  - parameter format
#     {type optional min max default} if parameter name was found
#
proc ::ob_bet::get_leg_param_format {name} {

	#log input params
	_log INFO "API(get_leg_param_format): $name"


	if {[catch {
		set ret [_get_leg_param_format $name]
	} msg]} {
		_err $msg
	}
	return $ret

}

# Get the specific leg parameters format
#
proc ::ob_bet::_get_leg_param_format {name} {
	variable LEG_FORMAT
	variable INIT

	#Has bet package been initialised?
	if {![info exists INIT]} {
		error\
			"Bet package hasn't been initialised call ob_bet::init"\
			""\
			BET_NOT_INITIALISED
	}

	if {[info exists LEG_FORMAT($name,type)]} {
		return [list $LEG_FORMAT($name,type) \
					 $LEG_FORMAT($name,optional) \
					 $LEG_FORMAT($name,min) \
					 $LEG_FORMAT($name,max) \
					 $LEG_FORMAT($name,def)]
	} else {
		error\
			"$name is not a valid leg parameter name."\
			""\
			BET_NOT_VALID_LEG_PARAMETER
	}
}



#API:get_limits_param_names Get the limits parameter names
# Usage
# ::ob_bet::get_limits_param_names
#
# Parameters:
#
# RETURNS:
# List of the limit parameters name
#
proc ::ob_bet::get_limits_param_names {} {

	#log input params
	_log INFO "API(get_limits_param_names)"

	if {[catch {
		set ret [_get_limits_param_names]
	} msg]} {
		_err $msg
	}
	return $ret

}

# Get all the limit parameter names
#
proc ::ob_bet::_get_limits_param_names {} {

	variable INIT

	#Has bet package been initialised?
	if {![info exists INIT]} {
		error\
			"Bet package hasn't been initialised call ob_bet::init"\
			""\
			BET_NOT_INITIALISED
	}

	return \
	  [list \
		num_lines \
		max_W\
		max_P\
		max_L_W\
		max_L_P\
		max_S_W\
		max_S_P\
		max_F\
		max_T\
		min]
}

::ob_bet::_log INFO "sourced bet.tcl"
