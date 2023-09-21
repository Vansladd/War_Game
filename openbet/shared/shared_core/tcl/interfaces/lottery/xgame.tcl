# Copyright (C) 2015 Orbis Technology Ltd. All Rights Reserved.
#
# XGame bet placement interface
#
#
set pkg_version 1.0
package provide core::lottery::xgame $pkg_version

# Dependencies
package require core::log      1.0
package require core::args     1.0

core::args::register_ns \
	-namespace core::lottery::xgame \
	-version   $pkg_version \
	-dependent [list \
		core::args \
		core::log \
	] \
	-docs "interfaces-lottery/xgame.xml"

namespace eval core::lottery::xgame {
}

# core::lottery::xgame::init
#
# Interface for one time initialisation of xgame bet placement code
#
core::args::register \
	-interface core::lottery::xgame::init \
	-desc      {Initialise xgame bet placement interface} \
	-args [list \
		[list -arg -locale           -mand 0 -check STRING   -default_cfg LOCALE      -default {en}  -desc {Language}] \
		[list -arg -cache_xlong      -mand 0 -check UINT     -default_cfg CACHE_XLONG -default 1800  -desc {Xtra Long cache time}] \
	]


# core::lottery::xgame::place_bet
#
# Interface for placing an xgame bet
#
core::args::register \
	-interface core::lottery::xgame::place_bet \
	-desc      {Inserts bets into tXGameBet and tXGameSub} \
	-allow_rpc 1 \
	-args      [list \
		[list -arg -xgame_id         -mand 1 -check UINT                         -desc {Unique Identifier for XGame}] \
		[list -arg -bet_type         -mand 1 -check STRING                       -desc {Type of bet being placed}] \
		[list -arg -ipaddr           -mand 1 -check STRING                       -desc {IP Address of the request}] \
		[list -arg -acct_id          -mand 1 -check UINT                         -desc {Account ID from which the request was placed}] \
		[list -arg -stake_per_bet    -mand 1 -check MONEY                        -desc {Stake per bet}] \
		[list -arg -stake_per_line   -mand 1 -check MONEY                        -desc {Stake per line}] \
		[list -arg -picks            -mand 1 -check STRING                       -desc {Numbers chosen by the customer}] \
		[list -arg -num_selns        -mand 1 -check UINT                         -desc {Number of selections}] \
		[list -arg -num_subs         -mand 1 -check UINT                         -desc {Number of subscriptions}] \
		[list -arg -xgame_betslip_id -mand 1 -check UINT                         -desc {Xgame betslip ID for this bet}] \
		[list -arg -auto_pick        -mand 1 -check STRING                       -desc {Denotes if the bet is quick pick or self pick}] \
		[list -arg -source           -mand 1 -check STRING                       -desc {Channel through which request was received}] \
		[list -arg -sub_draws        -mand 0 -check STRING   -default {}         -desc {Subscription draws}] \
		[list -arg -prices           -mand 0 -check UMONEY   -default {}         -desc {List of prices}] \
		[list -arg -free_subs        -mand 0 -check UINT     -default 0          -desc {Free Subscription}] \
		[list -arg -token_value      -mand 0 -check UINT     -default 0          -desc {Token Value}] \
		[list -arg -unique_id        -mand 0 -check UINT     -default 0          -desc {Unique identifier}] \
		[list -arg -placed_by        -mand 0 -check UINT     -default {}         -desc {User ID of the user who placed the request}] \
		[list -arg -receipt_format   -mand 0 -check UINT     -default 0          -desc {Format of receipt}] \
		[list -arg -receipt_tag      -mand 0 -check STRING   -default {}         -desc {Receipt Tag}] \
		[list -arg -ext_sys_name     -mand 0 -check STRING   -default {}         -desc {External System Name}] \
		[list -arg -ext_ref          -mand 0 -check STRING   -default {}         -desc {External Reference}] \
		[list -arg -void_reason      -mand 0 -check STRING   -default {}         -desc {Void Reason}] \
		[list -arg -is_prepaid       -mand 0 -check STRING   -default {N}        -desc {Denotes if it is prepaid or not}] \
	]

# core::lottery::xgame::draws_init
#
# Interface for one time initialisation of xgame draws code
#
core::args::register \
	-interface core::lottery::xgame::draws_init \
	-desc      {Initialise xgame draws interface} \


# core::lottery::xgame::insert_draw
#
# Interface for creating draw details
#
core::args::register \
	-interface core::lottery::xgame::insert_draw \
	-desc      {Inserts draw details into tXGame} \
	-allow_rpc 1 \
	-args  [list \
		[list -arg -sort             -mand 1 -check STRING                       -desc {Sort to which the game belongs}] \
		[list -arg -comp_no          -mand 0 -check UINT       -default {}       -desc {Competition number}] \
		[list -arg -shut_at          -mand 1 -check DATETIME                     -desc {Date and time of end of the game}] \
		[list -arg -draw_at          -mand 1 -check DATETIME                     -desc {Date and time at which draw is declared}] \
		[list -arg -desc             -mand 1 -check STRING                       -desc {Description of the game}] \
		[list -arg -draw_desc_id     -mand 1 -check UINT                         -desc {Uniquie identifier for draw description}] \
		[list -arg -results          -mand 0 -check STRING     -default {}       -desc {Results of the game}] \
		[list -arg -open_at          -mand 0 -check DATETIME   -default {}       -desc {Date and time of start of the game}] \
		[list -arg -status           -mand 0 -check STRING     -default {S}      -desc {Status of the game}] \
		[list -arg -misc_desc        -mand 0 -check STRING     -default {}       -desc {Miscellaneous description for the game}] \
	]

# core::lottery::xgame::update_draw
#
# Interface for updating draw details
#
core::args::register \
	-interface core::lottery::xgame::update_draw \
	-desc      {Updates draw details} \
	-allow_rpc 1 \
	-args  [list \
		[list -arg -xgame_id         -mand 1 -check UINT                         -desc {Unique identifier of xgame that needs to be updated}] \
		[list -arg -sort             -mand 0 -check STRING      -default {}      -desc {Sort to which the game belongs}] \
		[list -arg -comp_no          -mand 0 -check UINT        -default {}      -desc {Competition number}] \
		[list -arg -shut_at          -mand 0 -check DATETIME    -default {}      -desc {Date and time of end of the game}] \
		[list -arg -draw_at          -mand 0 -check DATETIME    -default {}      -desc {Date and time at which draw is declared}] \
		[list -arg -desc             -mand 0 -check STRING      -default {}      -desc {Description of the game}] \
		[list -arg -draw_desc_id     -mand 0 -check UINT        -default {}      -desc {Uniquie identifier for draw description}] \
		[list -arg -results          -mand 0 -check STRING      -default {}      -desc {Results of the game}] \
		[list -arg -open_at          -mand 0 -check DATETIME    -default {}      -desc {Date and time of start of the game}] \
		[list -arg -status           -mand 0 -check STRING      -default {}      -desc {Status of the game}] \
		[list -arg -misc_desc        -mand 0 -check STRING      -default {}      -desc {Miscellaneous description for the game}] \
	]

# core::lottery::xgame::get_active_draws
#
# Interface for updating draw details
#
core::args::register \
	-interface core::lottery::xgame::get_active_draws \
	-desc      {Retrieves all active draws for sort} \
	-allow_rpc 1 \
	-args  [list \
		[list -arg -sort  -mand 1 -check STRING  -desc {Sort to which the game belongs}] \
	]