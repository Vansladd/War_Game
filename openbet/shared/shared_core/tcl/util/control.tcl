# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle control table (tControl)
#
# Configuration:
#
# Synopsis:
#     package require core::control ?1.0?
#
# Public Procedures:
#    core::control::init    one time initialisation
#    core::control::get     get a control data value
#    core::control::set_cfg set a control data value

set pkg_version 1.0
package provide core::control $pkg_version

# Dependencies
package require core::log        1.0
package require core::check      1.0
package require core::args       1.0
package require core::db         1.0
package require core::db::schema 1.0

core::args::register_ns \
	-namespace core::control \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::db core::db::schema] \
	-docs      util/control.xml

namespace eval core::control {

	variable CFG
	variable CONTROL
	variable OB_CONFIG

	set CFG(init) 0
	set CONTROL(req_no) ""
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#

core::args::register \
	-proc_name core::control::init \
	-args [list \
		[list -arg -func_site_operator      -mand 0 -check BOOL -default_cfg FUNC_SITE_OPERATOR      -default 0 -desc {Enable site operator configuration}] \
		[list -arg -func_control_config     -mand 0 -check BOOL -default_cfg FUNC_OB_CONTROL_CONFIG  -default 0 -desc {Enable tOpenBetCfg config}] \
		[list -arg -func_async_fine_grained -mand 0 -check BOOL -default_cfg FUNC_ASYNC_FINE_GRAINED -default 0 -desc {Configure to use fine grained controls}] \
	] \
	-body {
		variable CFG

		# already initialised
		if {$CFG(init)} {
			return
		}

		core::log::write DEBUG {CONTROL: init}
		
		# init dependencies
		core::db::schema::init

		# can auto reset the flags?
		if {[info commands reqGetId] != "reqGetId"} {
			error "CONTROL: reqGetId not available for auto reset"
		}
		
		set CFG(func_site_operator)      $ARGS(-func_site_operator)
		set CFG(func_control_config)     $ARGS(-func_control_config)
		set CFG(func_async_fine_grained) $ARGS(-func_async_fine_grained)
		set CFG(epoch)                   "1970-01-01 00:00:00"
		
		set control_cust_grp [core::db::schema::table_exists -table tControlCustGrp]
		set site_operator    [core::db::schema::table_exists -table tSiteOperator]
		set channel_cfg      [core::db::schema::table_exists -table tChannelCfg]
		set channel_grp_link [core::db::schema::table_exists -table tChanGrpLink]
		
		set CFG(enabled,get_group_control)          $control_cust_grp
		set CFG(enabled,get_chan_config)            $channel_cfg
		set CFG(enabled,get_site_operator_channels) $site_operator
		set CFG(enabled,get_channel_group_channels) \
			[expr {$channel_grp_link && $site_operator && $channel_cfg}]
		
		_prepare_qrys
		
		set CFG(init) 1
	}

# Has the package been initialised
core::args::register \
	-proc_name core::control::is_initialised \
	-body {
		variable CFG
		return $CFG(init)
	}


# Private procedure to prepare the package queries
proc core::control::_prepare_qrys args {

	variable CFG

	# get control info (cached)
	core::db::store_qry \
		-name  core::control::get_control \
		-cache 600 \
		-qry {
			select * from tControl
		}

	# get group specific control info
	if {$CFG(enabled,get_group_control)} {
		core::db::store_qry \
			-name core::control::get_group_control \
			-cache 600 \
			-qry {
				select * from tControlCustGrp
			}
	}

	# get site operator channels (cached)
	if {$CFG(enabled,get_site_operator_channels)} {
		core::db::store_qry \
			-name core::control::get_site_operator_channels \
			-cache 600 \
			-qry {
				select
					ch.channel_id,
					so.site_operator_id,
					so.name as site_operator_name
				from
					tChannel ch,
					tSiteOperator so
				where
					ch.site_operator_id = so.site_operator_id
			}
	}

	# get channel configs (cached)
	if {$CFG(enabled,get_chan_config)} {
		core::db::store_qry \
			-name  core::control::get_chan_config \
			-cache 600 \
			-qry {
				select
					channel,
					cfg_name,
					cfg_value
				from
					tChannelCfg
			}
	}

	# get channels in a group
	if {$CFG(enabled,get_channel_group_channels)} {
		core::db::store_qry \
			-name core::control::get_channel_group_channels \
			-cache 600 \
			-qry {
				select
					l.channel_id,
					g.desc as channel_group_name,
					o.name as site_op_name
				from
					tChannelGrp g,
					tChanGrpLink l,
					tChannel s,
					tSiteOperator o
				where
					g.channel_grp = l.channel_grp and
					l.channel_id = s.channel_id and
					s.site_operator_id = o.site_operator_id
				order by
					2
			}
	}

	# get last update
	# cache on this query is the gatekeeper for ob_config_control::get_group*
	core::db::store_qry \
		-name core::control::get_last_updated \
		-cache 600 \
		-qry [subst {
			select
				NVL(max(last_updated),'$CFG(epoch)') as last_updated
			from
				tOpenBetCfgVal v
		}]

	# get last update for a given control group
	core::db::store_qry \
		-name core::control::get_group_last_updated \
		-cache 600 \
		-qry [subst {
			select
				NVL(max(last_updated),'$CFG(epoch)') as last_updated
			from
				tOpenBetCfg c,
				outer tOpenBetCfgVal v
			where
				c.cfg_name = v.cfg_name
				and c.cfg_group = ?
				and v.last_updated <= ?
		}]

	# get ob config control info
	# need to ANSI join due to post join filter on tOpenBetCfgVal
	core::db::store_qry \
		-name core::control::get_group \
		-cache 3600 \
		-qry {
			select
				c.cfg_name,
				c.cfg_default,
				c.cfg_group,
				v.cfg_value,
				r.cfg_ref_key,
				r.cfg_ref_val
			from
				(
					tOpenBetCfg c 
					left outer join tOpenBetCfgVal v on (
						c.cfg_name = v.cfg_name
					)
				) left outer join tOpenBetCfgRef r on (
					v.cfg_ref_id = r.cfg_ref_id
				)
			where
				c.cfg_group = ?
				and (
					v.last_updated <= ?
					or v.last_updated is null
				)
		}

	# get group name by config name
	core::db::store_qry \
		-name core::control::get_group_name \
		-cache 3600 \
		-qry {
			select
				c.cfg_group
			from
				tOpenBetCfg c
			where
				cfg_name = ?
		}

	# update ob config data value
	core::db::store_qry \
		-name core::control::update_ob_cfg \
		-qry {
			execute procedure pUpdOpenBetCfg (
				p_adminuser     = ?,
				p_cfg_name      = ?,
				p_cfg_value     = ?,
				p_cfg_ref_key   = ?,
				p_cfg_ref_val   = ?,
				p_transactional = ?
			)
		}
}

#--------------------------------------------------------------------------
# Get Control
#--------------------------------------------------------------------------
#
# Get a control data value.
# If the control data have been previously loaded, then retrieve the value
# from a cache, else take from the database (copies all the data to the cache).
# The data is always re-loaded on each request.
#
# @param -name Control column name
# @param -channel channel of the customer who placed bet, to
#    override channel specific controls
#
# @param -in_running Status of the event when bet is placed    NOTE THIS SHOULD BE REMOVED
# @param -cust_code Customer's group to overrive group specific controls NOTE THIS SHOULD BE REMOVED
# @param -cfg_ref_key tOpenBetCfgRef.cfg_ref_key
# @param -cfg_ref_val tOpenBetCfgRef.cfg_ref_val
# @param -strict Always return cfg_value (rather than cfg_default if cfg_value == "")
#
# @return Control column name data value,or an empty string if col is not found
#
#   e.g. [core::control::get \
#           -name       async_off_timeout \
#           -channel    $channel \
#           -in_running $BET(in_running)]
#
core::args::register \
	-proc_name core::control::get \
	-args [list \
		[list -arg -name       -mand 1 -check ASCII              -desc {Control column name}] \
		[list -arg -ref_key    -mand 0 -check STRING -default {} -desc {Reference key tOpenBetCfgRef}] \
		[list -arg -ref_val    -mand 0 -check STRING -default {} -desc {Reference value tOpenBetCfgRef}] \
		[list -arg -strict     -mand 0 -check BOOL   -default 0  -desc {Always return cfg_value}] \
		[list -arg -channel    -mand 0 -check ASCII  -default {} -desc {Async Override channel}] \
		[list -arg -cust_code  -mand 0 -check ASCII  -default {} -desc {Async customer group to overrive group specific controls}] \
		[list -arg -in_running -mand 0 -check ASCII  -default {} -desc {Async Betting in running}] \
	] \
	-body {
		variable CONTROL
		variable OB_CONFIG
		variable CFG
		
		set name    $ARGS(-name)
		set ref_key $ARGS(-ref_key)
		set ref_val $ARGS(-ref_val)
		set strict  $ARGS(-strict)
		
		set fn "core::control::get"
		set is_control_config 0

		# prevent reloading the CONTROL cache if we are sure this is OB_CONFIG
		if {$CFG(func_control_config) && [info exists OB_CONFIG(link,$name)]} {
			set is_control_config 1
		}
		# re-load the control data?
		if {!$is_control_config && [_auto_reset]} {
			_load
		}
		# re-load the config control data
		if {$CFG(func_control_config) && [_auto_reset_cfg $name]} {
			_load_cfg $name
		}

		# If we are configured to use fine grained controls and have been passed
		# channel or group value id then do async override
		#
		# THIS SHOULD NOT BE PART OF THIS PACKAGE
		if {$CFG(func_async_fine_grained) && ($ARGS(-channel) != "" || $ARGS(-cust_code) != "")} {
			return [_get_async \
				$name \
				$ARGS(-channel) \
				$ARGS(-cust_code) \
				$ARGS(-in_running)]
		}

		# Simplest case - default control package operation
		if {[info exists CONTROL($name)]} {
			return $CONTROL($name)
		}

		# If there is no default CONTROL package item, check in OB_CONFIG (no ref_key)
		if {$CFG(func_control_config) && [info exists OB_CONFIG(link,$name)] && $ref_key == ""} {
			set group $OB_CONFIG(link,$name)
			
			# sanity check
			if {[info exists OB_CONFIG($group,$name)]} {
				return $OB_CONFIG($group,$name)
			}
		}

		# Finally check in OB_CONFIG (if we have ref_key)
		if { $CFG(func_control_config) && $ref_key != "" } {
			return [_get_config_ref \
				$name \
				$ref_key \
				$ref_val \
				$strict]
		}

		return ""
	}

#--------------------------------------------------------------------------
# Set Config
#--------------------------------------------------------------------------
#
# Set a control data value.
# This is only valid for tOpenBetCfg (wrapper for pUpdOpenBetCfg).
# Breaks the request cache so that any subsequent core::control::get calls will
# go back to the database rather than using the cache (and thus returning
# incorrect data).
#
#   Arguments:
#
#   adminuser   - admin username         (Optional)
#   name        - config name
#   value       - config value
#   ref_key     - config reference key   (Optional)
#   ref_val     - config reference value (Optional)
#
#   Returns:
#
#   success     - 1
#   failure     - {0 <msg>}
#
#   e.g. [core::control::set_cfg adminuser $USERNAME name $name value $val]
#
core::args::register \
	-proc_name core::control::set_cfg \
	-args [list \
		[list -arg -adminuser     -mand 1 -check ASCII              -desc {Admin username}] \
		[list -arg -name          -mand 1 -check ASCII              -desc {Config name}] \
		[list -arg -value         -mand 1 -check ASCII              -desc {Config value}] \
		[list -arg -ref_key       -mand 0 -check STRING -default {} -desc {Reference key tOpenBetCfgRef}] \
		[list -arg -ref_val       -mand 0 -check STRING -default {} -desc {Reference value tOpenBetCfgRef}] \
		[list -arg -transactional -mand 0 -check BOOL   -default 1  -desc {Whether to use a transaction for the update}] \
	] \
	-body {
		variable CFG
		variable OB_CONFIG

		set fn "core::control::set_cfg"
		set name          $ARGS(-name)
		set transactional [expr {$ARGS(-transactional) == 1 ? {Y} : {N}}]

		# throw an errorif this is an invalid call
		if {!$CFG(func_control_config)} {
			return [list 0 "Cannot call $fn when ob_control_config off"]
		}

		# Update the database
		if {[catch {
			core::db::exec_qry \
				-name core::control::update_ob_cfg \
				-args [list \
					$ARGS(-adminuser) \
					$name \
					$ARGS(-value) \
					$ARGS(-ref_key) \
					$ARGS(-ref_val) \
					$transactional \
				]
		} msg]} {
			return [list 0 $msg]
		}
		
		# DB update was succesful, break the local req cache
		if {[info exists OB_CONFIG(link,$name)]} {
			set group $OB_CONFIG(link,$name)

			set OB_CONFIG($group,updated) 1

			# Update the last updated to make sure we get the new values out of the db
			set rs [core::db::exec_qry \
				-name core::control::get_group_last_updated \
				-args [list \
					$group \
					[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]]
			
			set OB_CONFIG($group,last_updated) [db_get_col $rs 0 last_updated]

			core::db::rs_close -rs $rs
		}

		return [list 1]
	}

# Get the site operator configs
# @param -name Site operator name
core::args::register \
	-proc_name core::control::get_site_operator_channels \
	-args [list \
		[list -arg -name  -mand 1 -check ASCII -desc {Site operator name}] \
	] \
	-body {
		variable CONTROL

		# re-load the control data?
		if {[_auto_reset]} {
			_load
		}
		
		set name $ARGS(-name)
		
		# already retrieved the control data?
		if {[info exists CONTROL(site_operators,$name,channels)]} {
			return $CONTROL(site_operators,$name,channels)
		}

		return {}
	}

# Get the site operator configs
# @param -channel Channel
# @param -name Config name 
core::args::register \
	-proc_name core::control::get_channel_cfg \
	-args [list \
		[list -arg -channel -mand 1 -check ASCII -desc {Channel}] \
		[list -arg -name    -mand 1 -check ASCII -desc {Config name}] \
	] \
	-body {
		variable CONTROL
		
		set name    $ARGS(-name)
		set channel $ARGS(-channel)

		# re-load the control data?
		if {[_auto_reset]} {
			_load
		}

		if {[info exists CONTROL(channel_cfg,$channel,$name)]} {
			return $CONTROL(channel_cfg,$channel,$name)
		}

		return {}
	}

# Get the site operator configs
# @param -name Channel group
core::args::register \
	-proc_name core::control::get_channel_group_channels \
	-args [list \
		[list -arg -name -mand 1 -check ASCII -desc {Channel group name}] \
	] \
	-body {
		variable CONTROL
		
		set name $ARGS(-name)

		# re-load the control data?
		if {[_auto_reset]} {
			_load
		}

		if {[info exists CONTROL(channel_groups,$name,channels)]} {
			return $CONTROL(channel_groups,$name,channels)
		}

		return {}
	}

# Get the site operator configs
# @param -name Channel group
core::args::register \
	-proc_name core::control::get_channel_per_grp_and_operator \
	-args [list \
		[list -arg -oper_name  -mand 1 -check ASCII -desc {Operator name}] \
		[list -arg -group_name -mand 1 -check ASCII -desc {Group name}] \
	] \
	-body {
		variable CONTROL
		
		set oper_name  $ARGS(-oper_name)
		set group_name $ARGS(-group_name)

		# re-load the control data?
		if {[_auto_reset]} {
			_load
		}

		if {[info exists CONTROL(site_operator,$oper_name,channel_group,$group_name,channels)]} {
			return $CONTROL(site_operator,$oper_name,channel_group,$group_name,channels)
		}

		return {}
	}

#
# The tOpenBetCfgX case is a bit more complicated due to the possible
# ref keys
#
# If we are configured to use tOpenBetCfgs through control and have
# been passed a config group name we hit this proc
#
#  ref_key - reference key
#  ref_val - reference value for the key
#
#  For configuring by reference to something, for example language, category,
#  event or a combination, ref_key represents what you are configuring by
#       e.g. LANG, CATEGORY, EVID, LANG_CATEGORY, LANG_EVID
#  ref_val defines the value of the key
#       e.g. en, FOOTBALL, 12345, en_FOOTBALL, en_12345
#
#  Alternatively ref_key can be used to enumerate or override cfg_name
#  values, in which case ref_val may be null.

proc core::control::_get_config_ref {cfg_name ref_key ref_val strict} {

	variable OB_CONFIG

	set val ""
	set fn  "core::control::_get_config_ref"

	if {[info exists OB_CONFIG(link,$cfg_name)]} {
		set group $OB_CONFIG(link,$cfg_name)

		if {$ref_val == "" && [info exists OB_CONFIG($group,$cfg_name,$ref_key)]} {
			set val $OB_CONFIG($group,$cfg_name,$ref_key)
		} elseif {[info exists OB_CONFIG($group,$cfg_name,$ref_key,$ref_val)] } {
			set val $OB_CONFIG($group,$cfg_name,$ref_key,$ref_val)
		}

		# we can pass the default value back if not in strict mode
		if {$val == "" && $strict != "Y" && [info exists OB_CONFIG($group,$cfg_name)] } {
			set val $OB_CONFIG($group,$cfg_name)
		}
	}

	return $val
}

# Private procedure to load the control data from the database and store
# within the package cache. The database result-set is cached.
#
proc core::control::_load args {

	variable CONTROL
	variable CFG

	set fn "core::control::_load"

	# Global settings from tControl
	set rs   [core::db::exec_qry -name core::control::get_control]
	set cols [db_get_colnames $rs]

	if {[db_get_nrows $rs] == 1} {
		foreach c $cols {
			set CONTROL($c) [db_get_col $rs 0 $c]
		}
	}

	core::db::rs_close -rs $rs
	
	# If we're not using fine grained controls then don't bother
	# loading the overrides
	if {$CFG(func_async_fine_grained)} {
		# Overrides from tControlCustGrp
		if {$CFG(enabled,get_group_control)} {
			set rs   [core::db::exec_qry -name core::control::get_group_control]
			set cols [db_get_colnames $rs]

			for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
				set group [db_get_col $rs $r cust_code]

				foreach c $cols {
					set CONTROL(group_$group,$c) [db_get_col $rs $r $c]
				}
			}

			core::db::rs_close -rs $rs
		}
	}

	# Site Operator configuration
	if {$CFG(enabled,get_site_operator_channels) && $CFG(func_site_operator)} {
		set rs [core::db::exec_qry -name core::control::get_site_operator_channels]
		
		set CONTROL(site_operators)    {}
		set CONTROL(site_operator_ids) {}

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set site_operator_id   [db_get_col $rs $i site_operator_id]
			set site_operator_name [db_get_col $rs $i site_operator_name]
			set channel            [db_get_col $rs $i channel_id]

			if {[lsearch $CONTROL(site_operators) $site_operator_name] == -1} {
				lappend CONTROL(site_operators)    $site_operator_name
				lappend CONTROL(site_operator_ids) $site_operator_id
				set CONTROL(site_operators,$site_operator_name,channels) $channel
			} else {
				lappend CONTROL(site_operators,$site_operator_name,channels) $channel
			}
		}
		core::db::rs_close -rs $rs
	}
	
	# Per channel configuration
	if {$CFG(enabled,get_chan_config)} {
		set rs [core::db::exec_qry -name core::control::get_chan_config]
		set cols [db_get_colnames $rs]

		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set channel    [db_get_col $rs $i channel]
			set cfg_name   [db_get_col $rs $i cfg_name]
			set cfg_value  [db_get_col $rs $i cfg_value]

			set CONTROL(channel_cfg,$channel,$cfg_name) $cfg_value
		}
		
		core::db::rs_close -rs $rs
	}

	# Channel groups
	if {$CFG(enabled,get_channel_group_channels)} {
		set rs [core::db::exec_qry -name core::control::get_channel_group_channels]
		
		for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
			set channel_group_name [db_get_col $rs $i channel_group_name]
			set channel            [db_get_col $rs $i channel_id]
			set site_operator      [db_get_col $rs $i site_op_name]

			# Populate structure for channel groups
			if {[info exists CONTROL(channel_groups,$channel_group_name,channels)]} {
				lappend CONTROL(channel_groups,$channel_group_name,channels) $channel
			} else {
				set CONTROL(channel_groups,$channel_group_name,channels) $channel
			}

			# Populate structure for channel groups per operator
			if {[info exists CONTROL(channel_groups,$channel_group_name,site_operator,$site_operator,channels)]} {
				lappend CONTROL(site_operator,$site_operator,channel_group,$channel_group_name,channels) $channel
			} else {
				set CONTROL(site_operator,$site_operator,channel_group,$channel_group_name,channels) $channel
			}
		}
		
		core::db::rs_close -rs $rs
	}
}


#
# Private procedure to determine if the config package cache should be reloaded
#
# Returns :
#   0 - The group does not need loading
#   1 - The group needs loading
#
proc core::control::_auto_reset_cfg { name } {

	variable OB_CONFIG
	variable CONTROL

	set fn "core::control::_auto_reset_cfg"
	set id [reqGetId]

	if {[info exists CONTROL($name)]} {
		# this cfg is a member of one of the tControl tables (not tOpenBetConfig)
		return 0
	}

	if {[info exists OB_CONFIG(link,$name)]} {
		set group $OB_CONFIG(link,$name)
	} else {
		# we've never seen this before so load it
		return 1
	}

	# if we have updated this group in this request, then we want to refetch
	if {[info exists OB_CONFIG($group,updated)]} {
		if { $OB_CONFIG($group,updated) == 1 } {
			set OB_CONFIG($group,updated) 0
			return 1
		}
	}

	# we only want to hit db for last updated if we haven't done so in this request
	if {![info exists OB_CONFIG($group,req_no)] || $OB_CONFIG($group,req_no) != $id} {

		# update group ID to show we have hit on this req
		set OB_CONFIG($group,req_no) $id

		# PERF - check global tOpenBetCfg last updated first (quick)
		set rs                [core::db::exec_qry -name core::control::get_last_updated]
		set last_updated_glob [db_get_col $rs 0 last_updated]

		core::db::rs_close -rs $rs

		# we need to store last_updated_glob by group, else we get into a scenario where group1 has been updated
		# but group2 is requested, updating the last_updated_glob without updating group1. Therefore when group1 is next
		# requested the package last_updated_glob will relfect the DB, and group1 will not be loaded.
		if {![info exists OB_CONFIG($group,last_updated_glob)]} {
			# only reached on first load of this group
			set OB_CONFIG($group,last_updated_glob) $last_updated_glob
		}

		if {[clock scan $OB_CONFIG($group,last_updated_glob)] >= [clock scan [set OB_CONFIG($group,last_updated_glob) $last_updated_glob]]} {
			return 0
		}

		# Now check the group for update -- this query runs slower than global
		set rs [core::db::exec_qry \
			-name core::control::get_group_last_updated \
			-args [list $group $last_updated_glob]]

		set last_updated_group [db_get_col $rs 0 last_updated]

		core::db::rs_close -rs $rs

		if {[clock scan $OB_CONFIG($group,last_updated)] <= [clock scan [set OB_CONFIG($group,last_updated) $last_updated_group]]} {
			return 1
		}
	}

	# already loaded
	return 0
}

#
# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc core::control::_auto_reset { } {

	variable CONTROL

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$CONTROL(req_no) == $id} {
		
		# already loaded
		return 0
	}
	
	array set CONTROL [array unset CONTROL]
	set CONTROL(req_no) $id
	core::log::write DEV {CONTROL: auto reset cache, req_no=$id}

	return 1
}

#
# private procedure to load the tOpenBetCfg tables (by group)
#
# name   - The config to load, used to derive group
#
proc core::control::_load_cfg { name } {

	variable CONTROL
	variable OB_CONFIG
	variable CFG
	
	# Load in tOpenBetCfgX controls if enabled
	if {$CFG(func_control_config)} {
	
		# only hit db for group name if we haven't linked before
		if {![info exists OB_CONFIG(link,$name)]} {

			# get group name first so we can check last updated
			set rs  [core::db::exec_qry \
				-name core::control::get_group_name \
				-args [list $name]]
				
			# if the request is for a config which is not present in the standard control
			# packages it will drop through here - if we have no rows we can bail out
			# without loading anything
			if { ![db_get_nrows $rs] } {
				core::db::rs_close -rs $rs
				return
			}

			set group [db_get_col $rs 0 cfg_group]
			set OB_CONFIG(link,$name) $group

			core::db::rs_close -rs $rs
			
			# we haven't linked (therefore loaded) this group before we need to set the
			# last updated value. We can't use current YTS storage in the package cache
			# as we want all children to hit the same cache on the get_group query.
			set rs [core::db::exec_qry \
				-name core::control::get_group_last_updated \
				-args [list \
					$group \
					[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]]

			set OB_CONFIG($group,last_updated) [db_get_col $rs 0 last_updated]

			core::db::rs_close -rs $rs
		} else {
			set group $OB_CONFIG(link,$name)
		}

		set rs [core::db::exec_qry \
			-name core::control::get_group \
			-args [list \
				$group \
				$OB_CONFIG($group,last_updated)]]
		
		set cols [db_get_colnames $rs]
		
		# spin through this group and unset all configs before loading
		# cant just unset $group,* as we store req_id and last_updated referenced by group
		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			set cfg_name [db_get_col $rs $r cfg_name]
			catch array {
				unset OB_CONFIG "${group},${cfg_name}*"
			}
		}

		for {set r 0} {$r < [db_get_nrows $rs]} {incr r} {
			foreach c $cols {
				set $c [db_get_col $rs $r $c]
			}

			# check for no dupe in CONTROL - this is 'fatal' to the group load
			if {[info exists CONTROL($cfg_name)]} {
				core::log::write ERROR {$fn - $cfg_name in tOpenBetCfg \
					conflicts with a column in a tControl table}
				return
			}

			# establish link if none exists (clean load)
			if {![info exists OB_CONFIG(link,$cfg_name)]} {
				set OB_CONFIG(link,$cfg_name) $group
			}

			# if we don't have a value for this config set default
			if {![info exists OB_CONFIG($group,$cfg_name)]} {
				set OB_CONFIG($group,$cfg_name) $cfg_default
			}

			if {$cfg_ref_key != {}} {
				# multi value configs reference off CONTROL($cfg_name)
				if {$cfg_ref_val == {}} {
					set OB_CONFIG($group,$cfg_name,$cfg_ref_key) $cfg_value
				} else {
					set OB_CONFIG($group,$cfg_name,$cfg_ref_key,$cfg_ref_val) $cfg_value
				}
			} else {
				# only overwrite the base default if there is a base value
				if {$cfg_value != {}} {
					set OB_CONFIG($group,$cfg_name) $cfg_value
				}
			}
		}

		core::db::rs_close -rs $rs
	}
}

#
# Get a channel or group override column. Split from the main
# get proc during the OpenBetCfg rewrite
#
#
# THIS SHOULD NOT BE IN THIS PACKAGE
proc core::control::_get_async { col channel cust_code in_running} {

	variable CONTROL

	# At this point we have a channel or group override
	if {$cust_code != ""} {
		set prefix group_$cust_code
	} else {
		set prefix chan_$channel
	}

	# Check if col is async_off_timeout to switch on IR or pre-match
	if {$col == "async_off_timeout"} {
		if {$in_running == "Y" || $in_running == 1} {
			set col async_off_ir_timeout
		} else {
			set col async_off_pre_timeout
		}
	}

	if {[info exists CONTROL($prefix,$col)]} {
		return $CONTROL($prefix,$col)
	} else {
		return ""
	}
}
