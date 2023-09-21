#-------------------------------------------------------------------------------
# Copyright (C) 2013 OpenBet Technology Ltd. All Rights Reserved.
#
# Customer Matcher API
#
# Provide a callback interface for generic customer matching.
#
# Synopsis:
#    package require core::cust::matcher ?1.0?
#
# Procedures:
#    core::cust::matcher::init              - Initialise this package.
#    core::cust::matcher::register_rule     - Registers a matching rule.
#    core::cust::matcher::register_filter   - Registers a match filter.
#    core::cust::matcher::register_alias    - Registers a rule alias.
#    core::cust::matcher::find_rule         - Finds a rule from a name/alias.
#    core::cust::matcher::set_hash          - Sets a customer's lookup hash.
#    core::cust::matcher::get_hash          - Gets a customer's lookup hash.
#    core::cust::matcher::get_hash_matches  - Finds customers with a given hash.
#    core::cust::matcher::get_hash_clusters - Finds all lookup hash matches.
#    core::cust::matcher::get_rules         - Gets a list of available rules.
#    core::cust::matcher::get_filters       - Gets a list of available filters.
#    core::cust::matcher::match_customer    - Get matches for a customer ID.
#    core::cust::matcher::match_detail      - Get matches from customer details.
#    core::cust::matcher::match_cross       - Find matches across all customers.
#
# Configuration:
#   CORE.CUSTOMER.MATCHER.ALIAS.<NAME>
#     - Sets the rule name or alias that should be used when a rule name of
#       '<NAME>' is given, evaluated recursively until a rule name is found.
#
#   CORE.CUSTOMER.MATCHER.RULE.DEFAULT
#     - Sets the default rule to use for all match types. This rule is used when
#       either no rule name is provided, or the provided name is not defined and
#       strict mode is not set. By default, this is the null matcher, which
#       returns no matches.
#
#   CORE.CUSTOMER.MATCHER.RULE.DEFAULT.CUSTOMER
#   CORE.CUSTOMER.MATCHER.RULE.DEFAULT.DETAIL
#   CORE.CUSTOMER.MATCHER.RULE.DEFAULT.CROSS
#     - Sets the default rule for customer, detail and cross matching,
#       respectively. This takes precedence over the default setting for all
#       match types, given above.
#
#   CORE.CUSTOMER.MATCHER.STRICT
#     - Sets whether strict mode is on by default for match requests. When
#       strict mode is enabled an error will be thrown if the match rule given
#       does not exist, whereas in non-strict mode the default will be used,
#       or the null matcher if the configured default is also invalid. By
#       default, strict mode is enabled.
#
#   CORE.CUSTOMER.MATCHER.MINIMUM_SIZE
#     - Sets the default minimum amount of matches to be used for a cross match,
#       allowing small groups of customers to be eliminated. The default value
#       is '2'.
#
#   CORE.CUSTOMER.MATCHER.PACKAGES
#     - Allows for a set of packages to be automatically initialized alongside
#       the customer matcher (eg: those containing any callback definitions).
#       This is a list of each package definition, with each item containing
#       elements: the package name, package version, and an optional init proc
#       to be invoked.
#-------------------------------------------------------------------------------
set pkg_version 1.0
package provide core::cust::matcher $pkg_version

package require core::log  1.0
package require core::args 1.0
package require core::db   1.0
package require core::util 1.0

core::args::register_ns \
	-namespace core::cust::matcher \
	-version   $pkg_version \
	-dependent [list core::log core::args core::db core::util] \
	-docs      "xml/cust/matcher.xml"

namespace eval core::cust::matcher {

	variable CFG
	variable MATCHER
	variable FILTER
	variable ALIAS

	set CFG(INIT) 0
}



#-------------------------------------------------------------------------------
# Initialisation.
#-------------------------------------------------------------------------------

# Main procedure for module initialisation. This should always be called to
# ensure that all data structures, configuration, etc. have been initialised.
#
core::args::register \
	-proc_name core::cust::matcher::init \
	-desc      "Initialises the customer matching module." \
	-body {
		variable CFG

		if {$CFG(INIT)} {
			return
		}

		set CFG(INIT) 1

		# Initialise dependencies.

		core::log::init
		core::args::init
		core::db::init

		core::log::write INFO {core::cust::matcher::init}

		# Prepare internal data structures, configuration and database queries.

		_prep_data
		_prep_cfg
		_prep_sql

		# Load any additional packages needed.

		foreach package $CFG(packages) {
			lassign $package module version init
			if {[catch {
				core::util::load_package -package $module -version $version
				if {$init != {}} {
					$init
				}
			} err]} {
				core::log::write ERROR \
					{$fn: Could not initialize package '$package' - $err}
			}
		}
	}



# Internal procedure used during initialisation to reset the data structures
# used and to create the null matcher used for non-strict match requests.
#
core::args::register \
	-proc_name core::cust::matcher::_prep_data \
	-is_public 0 \
	-desc      "Used during initialisation to set up internal data structures." \
	-body {
		variable CFG
		variable MATCHER

		set fn {core::cust::matcher::_prep_data}
		core::log::write DEBUG {$fn}

		# Clear the available rules; both globally and for each match type.

		set MATCHER(rules)          [list]
		set MATCHER(rules,customer) [list]
		set MATCHER(rules,detail)   [list]
		set MATCHER(rules,cross)    [list]

		# Create null matcher implementations, and set it as the default.

		set null "_NULL_[OT_UniqueId]"

		register_rule \
			-rule     $null \
			-type     customer \
			-callback core::cust::matcher::null_match_customer \
			-filters  [list]

		register_rule \
			-rule     $null \
			-type     detail \
			-callback core::cust::matcher::null_match_detail \
			-filters  [list]

		register_rule \
			-rule     $null \
			-type     cross \
			-callback core::cust::matcher::null_match_cross \
			-filters  [list]

		set CFG(matcher,null)             $null
		set CFG(matcher,default,customer) $null
		set CFG(matcher,default,detail)   $null
		set CFG(matcher,default,cross)    $null
	}



# Internal procedure used to read and act on all related configuration items for
# the module. The exact set of available configuration items is dynamic, based
# on the set of rules, filters and aliases being defined.
#
core::args::register \
	-proc_name core::cust::matcher::_prep_cfg \
	-is_public 0 \
	-desc      "Used during initialisation to read and interpret configuration items." \
	-body {
		variable CFG

		set fn {core::cust::matcher::_prep_cfg}
		core::log::write DEBUG {$fn}

		set prefix "CORE.CUSTOMER.MATCHER"

		# Read package configuration.

		set CFG(packages) [OT_CfgGet "${prefix}.PACKAGES" [list]]

		# Configure the default matchers.

		set CFG(matcher,default)          [OT_CfgGet "${prefix}.RULE.DEFAULT"          $CFG(matcher,null)]
		set CFG(matcher,default,customer) [OT_CfgGet "${prefix}.RULE.DEFAULT.CUSTOMER" $CFG(matcher,default)]
		set CFG(matcher,default,detail)   [OT_CfgGet "${prefix}.RULE.DEFAULT.DETAIL"   $CFG(matcher,default)]
		set CFG(matcher,default,cross)    [OT_CfgGet "${prefix}.RULE.DEFAULT.CROSS"    $CFG(matcher,default)]

		# Read alias configuration, and register each one.

		set configs [lsearch -all -inline -glob [OT_CfgGetNames] "${prefix}.ALIAS.*"]

		foreach config $configs {
			if {![regexp -- {${prefix}\.ALIAS\.(.*)$} $config -> alias]} {
				register_alias \
					-alias   $alias \
					-mapping [OT_CfgGet $config]
			}
		}

		return
	}



# Internal procedure used to prepare database queries used by the package.
#
core::args::register \
	-proc_name core::cust::matcher::_prep_sql \
	-is_public 0 \
	-desc      "Used during initialisation to prepare database queries." \
	-body {
		core::log::write DEBUG {core::cust::matcher::_prep_sql}

		core::db::store_qry \
			-name core::cust::matcher::add_hash \
			-qry {
				execute procedure pUpdCustHashes(
					p_cust_id   = ?,
					p_hash_type = ?,
					p_hash      = ?
				)
			}

		core::db::store_qry \
			-name core::cust::matcher::get_hash \
			-qry {
				select
					l.value as value
				from
					tCustDetailLookup     l,
					tCustDetailLookupType t
				where
					    l.type_id = t.type_id
					and l.cust_id = ?
					and t.type    = ?
			}

		core::db::store_qry \
			-name core::cust::matcher::get_hash_matches \
			-qry {
				select
					l.cust_id as cust_id
				from
					tCustDetailLookup     l,
					tCustDetailLookupType t
				where
					    l.type_id = t.type_id
					and t.type    = ?
					and l.value   = ?
			}

		core::db::store_qry \
			-name core::cust::matcher::get_hashes \
			-qry {
				select
					l.cust_id  as cust_id,
					l.value    as hash
				from
					tCustDetailLookup     l,
					tCustDetailLookupType t
				where
					    l.type_id = t.type_id
					and t.type    = ?
			}
	}



#-------------------------------------------------------------------------------
# Registration/Setup Procedures
#-------------------------------------------------------------------------------

# Registers the callback and filters to use for a specified rule name and type.
# The filters are optional, and will be used if a match request is made without
# a set of filters being explicitly provided.
#
# @param -rule     The name of the rule being registered.
# @param -type     The type of match this rule is being registered for.
# @param -callback The name of a proc to be called for this rule name and type.
# @param -filters  An optional list of filter names, which will be used by
#                  default on match requests for this rule and type.
#
core::args::register \
	-proc_name core::cust::matcher::register_rule \
	-desc "Registers a callback and default filters for the specified rule name/type." \
	-args [list \
		[list -arg -rule     -mand 1 -check ASCII                       -desc "The rule name to registered."] \
		[list -arg -type     -mand 1 -check ASCII                       -desc "The match type to registered (ie: 'Customer', 'Detail' or 'Cross')."] \
		[list -arg -callback -mand 1 -check STRING                      -desc "The callback to be used for matching customers when the rule and match type is invoked."] \
		[list -arg -filters  -mand 0 -check LIST   -default "_DEFAULT_" -desc "Optionally, a set of default filters to apply when filters are not specified during an invocation of this rule and match type."] \
	] \
	-body {
		variable MATCHER

		set fn {core::cust::matcher::register_rule}
		core::log::write DEBUG {$fn}

		set rule     $ARGS(-rule)
		set type     $ARGS(-type)
		set callback $ARGS(-callback)
		set filters  $ARGS(-filters)

		# Check that the match type is valid.

		set type [string tolower $type]

		switch -exact -- $type {
			customer -
			detail   -
			cross    {
				core::log::write INFO {$fn: Registering '$type' rule: $rule}
			}
			default  {
				error "Unknown match type: $ARGS(-type)" {} UNKNOWN_MATCH_TYPE
			}
		}

		# Check that we are not overriding an existing callback.

		if {[info exists MATCHER($rule,$type,callback)]} {
			core::log::write WARNING {$fn: Rule '$rule' ($type) already registered; overriding...}
		}

		set MATCHER($rule,$type,callback) $callback

		# Set the filters, if specified.

		if {$filters != "_DEFAULT_"} {
			set MATCHER($rule,$type,filters) $filters
		} else {
			unset -nocomplain MATCHER($rule,$type,filters)
		}

		# Update the list of know rule names, both globally and for this type.

		if {[lsearch $MATCHER(rules) $rule] == -1} {
			lappend MATCHER(rules) $rule
		}

		if {[lsearch $MATCHER(rules,$type) $rule] == -1} {
			lappend MATCHER(rules,$type) $rule
		}

		return
	}



# Registers the callback to be invoked when the specified filter name is
# encountered.
#
# @param -filter   The name of the filter being registered.
# @param -callback The callback to be invoked for this filter.
#
core::args::register \
	-proc_name core::cust::matcher::register_filter \
	-desc "Registers a results filter." \
	-args [list \
		[list -arg -filter   -mand 1 -check ASCII  -desc "The filter name to registered."] \
		[list -arg -callback -mand 1 -check STRING -desc "The callback to be used when this filter is invoked."] \
	] \
	-body {
		variable FILTER

		set fn {core::cust::matcher::register_filter}
		core::log::write DEBUG {$fn}

		set filter   $ARGS(-filter)
		set callback $ARGS(-callback)

		# Check if this filter has already been defined.

		if {[info exists FILTER($filter)]} {
			core::log::write WARNING {Filter '$filter' already registered; overriding...}
		}

		set FILTER($filter) $callback

		return
	}



# Registers an alias, which can be used in place of a rule name for match calls.
#
# @param -alias   The alias name being registered.
# @param -mapping The rule or alias this name should map to.
#
core::args::register \
	-proc_name core::cust::matcher::register_alias \
	-desc "Registers an alias mapping." \
	-args [list \
		[list -arg -alias   -mand 1 -check ASCII -desc "The alias name to registered."] \
		[list -arg -mapping -mand 1 -check ASCII -desc "The rule or alias this name should map to."] \
	] \
	-body {
		variable ALIAS

		set fn {core::cust::matcher::register_alias}
		core::log::write DEBUG {$fn}

		set alias   $ARGS(-alias)
		set mapping $ARGS(-mapping)

		# Check if this alias has already been defined.

		if {[info exists ALIAS($alias)]} {
			core::log::write WARNING {Alias '$alias' already registered; overriding...}
		}

		set ALIAS($alias) $mapping

		return
	}



#-------------------------------------------------------------------------------
# Utility Procedures
#-------------------------------------------------------------------------------

# Recursively applies aliases until a rule name is found. Note that there is no
# check against a callback/implementation being registered for a specific match
# type; this is to ensure that a given alias always maps to the same rule.
#
# @param -rule The rule name or alias to look for.
#
# @return The rule name found by applying aliases recursively, or an empty
#         string in the event that no rule can be found.
#
core::args::register \
	-proc_name core::cust::matcher::find_rule \
	-desc      "Iteratively maps aliases to find a defined matching rule." \
	-returns   "The name of the matching rule found." \
	-args [list \
		[list -arg -rule -mand 1 -check ASCII -desc "A rule name or alias."] \
	] \
	-body {
		variable MATCHER
		variable ALIAS

		set fn {core::cust::matcher::find_rule}
		core::log::write DEBUG {$fn}

		set rule  $ARGS(-rule)
		set rules [list $rule]

		while {1} {
			if {[lsearch $MATCHER(rules) $rule] != -1} {
				break
			}
			if {[info exists ALIAS($rule)]} {
				set rule $ALIAS($rule)
				if {[lsearch $rules $rule] != -1} {
					set rules [join $rules { -> }]
					core::log::write WARNING {$fn: Alias loop detected: $rules -> $rule}
					set rule {}
					break
				}
				lappend rules $rule
				continue
			}
			set rule {}
			break
		}

		if {$rule == {}} {
			core::log::write WARNING {$fn: No rule found for rule name '$ARGS(-rule)'.}
		} else {
			set rules [join $rules " -> "]
			core::log::write INFO {$fn: Found rule: $rules}
		}

		return $rule
	}



# Sets the lookup value for a given customer and type. An SHA-1 cryptographic
# hash is applied to the value before storing it.
#
# @param -cust_id The customer ID for which the value is being set.
# @param -type    They type of lookup value which is being set.
# @param -value   The value to which the lookup should be set.
#
core::args::register \
	-proc_name core::cust::matcher::set_hash \
	-desc      "Generates and sets the lookup value for a customer." \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT   -desc "The customer ID for which the lookup value is being set."] \
		[list -arg -type    -mand 1 -check ASCII -desc "The type of lookup value being set."] \
		[list -arg -value   -mand 1 -check ASCII -desc "The value to which the lookup should be set."] \
	] \
	-body {
		set fn {core::cust::matcher::set_hash}
		core::log::write DEBUG {$fn}

		set cust_id $ARGS(-cust_id)
		set type    $ARGS(-type)
		set value   $ARGS(-value)

		if {[catch {
			set hash [sha1 $value]
			core::db::exec_qry \
				-name core::cust::matcher::add_hash \
				-args [list \
					$cust_id \
					$type \
					$hash \
				]
		} err]} {
			core::log::write ERROR {$fn: Could not update hash: $err}
			error "Could not update hash: $err" $::errorInfo SYSTEM_ERROR
		}

		return
	}



# Retrieves the lookup value of the lookup hash for a given customer and hash
# type. The returned value will be SHA-1 hashed.
#
# @param -cust_id The customer for which the lookup value is being retrieved.
# @param -type    The type of lookup value to be returned.
#
# @return A SHA-1 hash of the lookup value for the specified customer and type.
#
core::args::register \
	-proc_name core::cust::matcher::get_hash \
	-desc      "Retrieves the lookup value for a customer." \
	-returns   "A string containing the SHA-1 hash for the customer ID and lookup type specified." \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT   -desc "The customer ID for which the lookup value is being retrieved."] \
		[list -arg -type    -mand 1 -check ASCII -desc "The type of lookup value being retrieved."] \
	] \
	-body {
		set fn {core::cust::matcher::get_hash}
		core::log::write DEBUG {$fn}

		set cust_id $ARGS(-cust_id)
		set type    $ARGS(-type)

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::cust::matcher::get_hash \
				-args [list \
					$cust_id \
					$type \
				]]

			if {[db_get_nrows $rs]} {
				set value [db_get_col $rs 0 value]
			} else {
				core::log::write WARNING {$fn: No hash set for customer.}
				set value {}
			}
		} err]} {
			core::log::write ERROR {$fn: Could not retrieve hash: $err}
			set value {}
		}

		catch {core::db::rs_close -rs $rs}

		return $value
	}



# Returns the set of customers sharing a specified lookup value for a given
# lookup type. An SHA-1 cryptographic hash is applied to the provided value
# before searching.
#
# @param -type  The lookup type to be searched.
# @param -value The lookup value to be used for the search.
#
# @return A list containing each customer ID with a matching lookup value for
#         the provided type.
#
core::args::register \
	-proc_name core::cust::matcher::get_hash_matches \
	-desc      "Retrieves the set of customer ID's matching a given lookup value." \
	-returns   "A list of matching customer ID's" \
	-args [list \
		[list -arg -type    -mand 1 -check ASCII -desc "The lookup type being searched."] \
		[list -arg -value   -mand 1 -check ASCII -desc "The lookup value to be used for the search."] \
	] \
	-body {
		set fn {core::cust::matcher::get_hash_matches}
		core::log::write DEBUG {$fn}

		set type  $ARGS(-type)
		set value $ARGS(-value)

		if {[catch {
			set hash [sha1 $value]
			set rs [core::db::exec_qry \
				-name core::cust::matcher::get_hash_matches \
				-args [list \
					$type \
					$hash \
				]]
		} err]} {
			core::log::write ERROR {$fn: Could not retrieve matches: $err}
			error "Could not retrieve matches: $err" $::errorInfo SYSTEM_ERROR
		}

		set matches [list]
		set nrows   [db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			set cust_id [db_get_col $rs $r cust_id]
			lappend matches $cust_id
		}

		catch {core::db::rs_close -rs $rs}

		return $matches
	}



# Retrieves all sets of customers for a given lookup type, grouped by the
# lookup value stored.
#
# @param -type The type of lookup value against which customers should be
#              grouped.
#
# @return A list of customer groups, with each element itself being a list of
#           customer ID's.
#
core::args::register \
	-proc_name core::cust::matcher::get_hash_clusters \
	-desc      "Retrieves all sets of customer ID's with matching values for a given lookup type." \
	-returns   "A list of matching customer ID's" \
	-args [list \
		[list -arg -type -mand 1 -check ASCII -desc "The lookup type being searched."] \
	] \
	-body {
		set fn {core::cust::matcher::get_hash_clusters}
		core::log::write DEBUG {$fn}

		set type $ARGS(-type)

		if {[catch {
			set rs [core::db::exec_qry \
				-name core::cust::matcher::get_hashes \
				-args [list \
					$type \
				]]
		} err]} {
			core::log::write ERROR {$fn: Could not retrieve hashes: $err}
			error "Could not retrieve hashes: $err" $::errorInfo SYSTEM_ERROR
		}

		set matches [list]
		set nrows   [db_get_nrows $rs]

		for {set r 0} {$r < $nrows} {incr r} {
			set cust_id [db_get_col $rs $r cust_id]
			set hash    [db_get_col $rs $r value]
			lappend CLUSTERS($hash) $cust_id
		}

		catch {core::db::rs_close -rs $rs}

		set clusters [list]
		foreach hash [array names CLUSTERS] {
			lappend clusters $CLUSTERS($hash)
		}

		return $clusters
	}



# Retrieves the set of available matching rules. If a match type is specified,
# only those rules with an implementation/callback defined for that match type
# will be returned.
#
# @param -match_type An optional matching type ('customer', 'detail' or
#                    'cross'), which will limit the results to only those rules
#                    with an implementation/callback defined for the given type.
#
# @return The list of available matching rules found.
#
core::args::register \
	-proc_name core::cust::matcher::get_rules \
	-desc      "Retrieves the set of rule names available." \
	-returns   "A list containing each rule name available." \
	-args [list \
		[list -arg -match_type -mand 0 -default {} -check ASCII -desc "Restricts the results to only those rules with an implementation for the specified match type (ie: customer, detail or cross)."] \
	] \
	-body {
		variable CFG
		variable MATCHER

		set fn {core::cust::matcher::get_rules}
		core::log::write DEBUG {core::cust::matcher::get_rules}

		set match_type $ARGS(-match_type)

		# Get all rules for the specified type.

		switch -exact -- [string toupper $match_type] {
			CUSTOMER { set rules $MATCHER(rules,customer) }
			DETAIL   { set rules $MATCHER(rules,detail)   }
			CROSS    { set rules $MATCHER(rules,cross)    }
			{}       { set rules $MATCHER(rules)          }
			default  {
				core::log::write ERROR {$fn: Unknown match type - $match_type}
				error "Unknown match type - $match_type" {} UNKNOWN_MATCH_TYPE
			}
		}

		# Remove the null matcher, as this is only used internally.

		set rules [lsearch -inline -all -not -exact $rules $CFG(matcher,null)]

		return $rules
	}


# Returns the list of filters that have been defined.
#
# @return A list of available filters.
#
core::args::register \
	-proc_name core::cust::matcher::get_filters \
	-desc      "Retrieves the set of filter names available." \
	-returns   "A list containing each filter name available." \
	-body {
		variable FILTER

		core::log::write DEBUG {core::cust::matcher::get_filters}

		return [array names FILTER]
	}



# Ensures that a match result set contains all necessary fields by adding empty
# values where necessary.
#
# @param -matches The match result set to be completed.
#
# @return A copy of the result passed in, with all missing fileds completed.
#
core::args::register \
	-proc_name core::cust::matcher::complete_match \
	-desc      "Fills in missing fields for a dictionary containing match results." \
	-returns   "A copy of the result passed in, with all missing fileds completed." \
	-args [list \
		[list -arg -matches -mand 1 -check NONE -desc "The match result set to be completed."] \
	] \
	-body {
		core::log::write DEBUG {core::cust::matcher::complete_match}

		set matches $ARGS(-matches)

		if {![dict exists $matches identifier]} {
			dict set matches identifier [list]
		}

		if {![dict exists $matches master]} {
			dict set matches master [list]
		}

		return $matches
	}



#-------------------------------------------------------------------------------
# Customer Matching
#-------------------------------------------------------------------------------

# Callback interface for matching against a specific customer ID.
#
# @param -cust_id The customer ID against which matches should be generated.
#
# @return The set of matches, along with an optional master customer and
#         identifier, in the common match dict format.
#
core::args::register \
	-interface core::cust::matcher::interface_match_customer \
	-desc      "An interface defining the structure of callbacks for matching on a customer ID." \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT -desc "The customer ID against which the match should be performed."] \
	]



# Performs a search for matches against a provided customer ID, using the rule
# and result filters specified.
#
# @param -cust_id The customer ID against which matches should be generated.
# @param -rule    The name of a matching rule or alias, specifying the ruleset
#                 to be used for finding matches. If not provided, the
#                 configured default rule is used.
# @param -filters An optional list of filters to apply to the results. If not
#                 provided, the default set of filters for the specified rule
#                 will be used. To use no filters, an empty list can be passed.
# @param -strict  Specifies explicitly if strict mode should be used when
#                 evaluating the rule/alias. If not provided, the configured
#                 default setting is used.
#
# @return The set of matches, along with an optional master customer and
#         identifier, in the common match dict format.
#
core::args::register \
	-proc_name core::cust::matcher::match_customer \
	-desc      "Performs a customer match from the rule name and customer ID provided." \
	-args [list \
		[list -arg -cust_id -mand 1                                                                  -check INT   -desc "The customer ID against which the match should be performed."] \
		[list -arg -rule    -mand 0 -default ""                                                      -check ASCII -desc "The name of the matching rule that should be used to apply the match."] \
		[list -arg -filters -mand 0 -default "_DEFAULT_"                                             -check LIST  -desc "An optional list of filters that should be used instead of the default for that rule."] \
		[list -arg -strict  -mand 0 -default 1           -default_cfg "CORE.CUSTOMER.MATCHER.STRICT" -check BOOL  -desc "Indicates if an error should be thrown if no implementation for the matching rule has been defined (strict) or if the code should revert to the default rule (non-strict)."] \
	] \
	-body {
		variable CFG
		variable MATCHER
		variable FILTER

		set fn {core::cust::matcher::match_customer}
		core::log::write DEBUG {$fn}

		set cust_id $ARGS(-cust_id)
		set rule    $ARGS(-rule)
		set filters $ARGS(-filters)
		set strict  $ARGS(-strict)

		# Determine which matching rule should be used.

		if {$rule == {}} {
			set rule $CFG(matcher,default,customer)
		}

		set rule [find_rule -rule $rule]

		# Check that an implementation exists, falling back to the default if
		# one doesn't.

		if {![info exists MATCHER($rule,customer,callback)]} {
			if {$strict} {
				error "Matching implementation undefined for rule: $rule (Customer)" {} UNDEFINED_RULE
			}
			set rule [find_rule -rule $CFG(matcher,default,customer)]
		}

		# If an implementation still doesn't exist, default to the null matcher.

		if {![info exists MATCHER($rule,customer,callback)]} {
			set rule $CFG(matcher,null)
		}

		# Perform a callback to get the set of matches

		if {[catch {
			set matches [$MATCHER($rule,customer,callback) -cust_id $cust_id]
			set matches [complete_match -matches $matches]
		} err]}	{
			core::log::write ERROR {$fn: Could not retrieve matches - $err}
			error "Could not retrieve matches - $err" $::errorInfo SYSTEM_ERROR
		}

		# Determine what set of filters to apply to the results, then iterate
		# over each one in turn applying it.

		if {$filters == "_DEFAULT_"} {
			if {[info exists MATCHER($rule,customer,filters)]} {
				set filters $MATCHER($rule,customer,filters)
			} else {
				set filters [list]
			}
		}

		foreach filter $filters {
			if {[llength [dict get $matches matches]] == 0} {
				break
			}
			if {![info exists FILTER($filter)]} {
				core::log::write WARNING {Unknown filter: $filter}
				continue
			}
			if {[catch {
				set matches [$FILTER($filter) -matches $matches]
				set matches [complete_match -matches $matches]
			} err]} {
				core::log::write ERROR {$fn: Could not apply filter '$filter' - $err}
				error "Could not apply filter '$filter' - $err" $::errorInfo SYSTEM_ERROR
			}
		}

		# Return the results.

		return $matches
	}



#-------------------------------------------------------------------------------
# Detail Matching
#-------------------------------------------------------------------------------

# Callback interface for matching against a set of customer details.
#
# @param -details A dict containing the customer details to be matched.
#
# @return The set of matches, along with an optional master customer and
#         identifier, in the common match dict format.
#
core::args::register \
	-interface core::cust::matcher::interface_match_detail \
	-desc      "An interface defining the structure of callbacks for matching on a customer details." \
	-args [list \
		[list -arg -details -mand 1 -check NONE -desc "The customer details against which the match should be performed."] \
	]



# Performs a search for matches against a set of customer details, using the
# rule and result filters specified.
#
# @param -details A dict containing the customer details against which matches
#                 should be generated.
# @param -rule    The name of a matching rule or alias, specifying the ruleset
#                 to be used for finding matches. If not provided, the
#                 configured default rule is used.
# @param -filters An optional list of filters to apply to the results. If not
#                 provided, the default set of filters for the specified rule
#                 will be used. To use no filters, an empty list can be passed.
# @param -strict  Specifies explicitly if strict mode should be used when
#                 evaluating the rule/alias. If not provided, the configured
#                 default setting is used.
#
# @return The set of matches, along with an optional master customer and
#         identifier, in the common match dict format.
#
core::args::register \
	-proc_name core::cust::matcher::match_detail \
	-desc      "Performs a customer match from the rule name and customer details provided." \
	-args [list \
		[list -arg -details -mand 1                                                                  -check NONE  -desc "A dictionary containing customer details that will be passed to the matcher."] \
		[list -arg -rule    -mand 0 -default ""                                                      -check ASCII -desc "The name of the matching rule that should be used to apply the match."] \
		[list -arg -filters -mand 0 -default "_DEFAULT_"                                             -check LIST  -desc "An optional list of filters that should be used instead of the default for that rule."] \
		[list -arg -strict  -mand 0 -default 1           -default_cfg "CORE.CUSTOMER.MATCHER.STRICT" -check BOOL  -desc "Indicates if an error should be thrown if no implementation for the matching rule has been defined (strict) or if the code should revert to the default rule (non-strict)."] \
	] \
	-body {
		variable CFG
		variable MATCHER
		variable FILTER

		set fn {core::cust::matcher::match_detail}
		core::log::write DEBUG {$fn}

		set details $ARGS(-details)
		set rule    $ARGS(-rule)
		set filters $ARGS(-filters)
		set strict  $ARGS(-strict)

		# Determine which matching rule should be used.

		if {$rule == {}} {
			set rule $CFG(matcher,default,detail)
		}

		set rule [find_rule -rule $rule]

		# Check that an implementation exists, falling back to the default if
		# one doesn't.

		if {![info exists MATCHER($rule,detail,callback)]} {
			if {$strict} {
				error "Matching implementation undefined for rule: $rule (Detail)" {} UNDEFINED_RULE
			}
			set rule [find_rule -rule $CFG(matcher,default,detail)]
		}

		# If an implementation still doesn't exist, default to the null matcher.

		if {![info exists MATCHER($rule,detail,callback)]} {
			set rule $CFG(matcher,null)
		}

		# Perform a callback to get the set of matches.

		if {[catch {
			set matches [$MATCHER($rule,detail,callback) -details $details]
			set matches [complete_match -matches $matches]
		} err]}	{
			core::log::write ERROR {$fn: Could not retrieve matches - $err}
			error "Could not retrieve matches - $err" $::errorInfo SYSTEM_ERROR
		}

		# Determine what set of filters to apply to the results, then iterate
		# over each one in turn applying it.

		if {$filters == "_DEFAULT_"} {
			if {[info exists MATCHER($rule,detail,filters)]} {
				set filters $MATCHER($rule,detail,filters)
			} else {
				set filters [list]
			}
		}

		foreach filter $filters {
			if {[llength [dict get $matches matches]] == 0} {
				break
			}
			if {![info exists FILTER($filter)]} {
				core::log::write WARNING {Unknown filter: $filter}
				continue
			}
			if {[catch {
				set matches [$FILTER($filter) -matches $matches]
				set matches [complete_match -matches $matches]
			} err]} {
				core::log::write ERROR {$fn: Could not apply filter '$filter' - $err}
				error "Could not apply filter '$filter' - $err" $::errorInfo SYSTEM_ERROR
			}
		}

		# Return the results.

		return $matches
	}



#-------------------------------------------------------------------------------
# Cross Matching
#-------------------------------------------------------------------------------

# Callback interface for performing matches across the entire customer base.
#
# @return A list containing each group of matches. Each element should be in the
#         common match dict format, optionally containing a master customer
#         and unique identifier for the group.
#
core::args::register \
	-interface core::cust::matcher::interface_match_cross \
	-desc      "An interface defining the structure of callbacks for performing full cross matches." \
	-args      [list]



# Performs a search for matches across the entire customer base, using the rule
# and result filters specified.
#
# @param -rule     The name of a matching rule or alias, specifying the ruleset
#                  to be used for finding matches. If not provided, the
#                  configured default rule is used.
# @param -filters  An optional list of filters to apply to the results. If not
#                  provided, the default set of filters for the specified rule
#                  will be used. To use no filters, an empty list can be passed.
# @param -min_size The minimum size for groups of matches to be included in the
#                  results. If not provided, the configured default setting is
#                  used.
# @param -strict   Specifies explicitly if strict mode should be used when
#                  evaluating the rule/alias. If not provided, the configured
#                  default setting is used.
#
# @return A list containing each group of matches. Each element should be in the
#         common match dict format, optionally containing a master customer
#         and unique identifier for the group.
#
core::args::register \
	-proc_name core::cust::matcher::match_cross \
	-desc      "Performs a full cross customer match for the rule name provided." \
	-args [list \
		[list -arg -rule     -mand 0 -default ""                                                            -check ASCII -desc "The name of the matching rule that should be used to apply the match."] \
		[list -arg -filters  -mand 0 -default "_DEFAULT_"                                                   -check LIST  -desc "An optional list of filters that should be used instead of the default for that rule."] \
		[list -arg -min_size -mand 0 -default 2           -default_cfg "CORE.CUSTOMER.MATCHER.MINIMUM_SIZE" -check INT   -desc "Minimum size of any matched cluster to be included in the results."] \
		[list -arg -strict   -mand 0 -default 1           -default_cfg "CORE.CUSTOMER.MATCHER.STRICT"       -check BOOL  -desc "Indicates if an error should be thrown if no implementation for the matching rule has been defined (strict) or if the code should revert to the default rule (non-strict)."] \
	] \
	-body {
		variable CFG
		variable MATCHER
		variable FILTER

		set fn {core::cust::matcher::match_cross}
		core::log::write DEBUG {$fn}

		set rule     $ARGS(-rule)
		set filters  $ARGS(-filters)
		set min_size $ARGS(-min_size)
		set strict   $ARGS(-strict)

		# Determine which matching rule should be used.

		if {$rule == {}} {
			set rule $CFG(matcher,default,cross)
		}

		set rule [find_rule -rule $rule]

		# Check that an implementation exists, falling back to the default if
		# one doesn't.

		if {![info exists MATCHER($rule,cross,callback)]} {
			if {$strict} {
				error "Matching implementation undefined for rule: $rule (cross)" {} UNDEFINED_RULE
			}
			set rule [find_rule -rule $CFG(matcher,default,cross)]
		}

		# If an implementation still doesn't exist, default to the null matcher.

		if {![info exists MATCHER($rule,cross,callback)]} {
			set rule $CFG(matcher,null)
		}

		# Perform a callback to get the set of matches

		if {[catch {
			set clusters [$MATCHER($rule,cross,callback)]
		} err]}	{
			core::log::write ERROR {$fn: Could not retrieve matches - $err}
			error "Could not retrieve matches - $err" $::errorInfo SYSTEM_ERROR
		}

		# Determine what set of filters to apply to the results, based on the
		# list passed in, or defaults as necessary. We check in advance that
		# each filter has been defined to avoid logging the same warning for
		# every cluster as we iterate through.

		if {$filters == "_DEFAULT_"} {
			if {[info exists MATCHER($rule,cross,filters)]} {
				set filters $MATCHER($rule,cross,filters)
			} else {
				set filters [list]
			}
		}

		for {set i 0} {$i < [llength $filters]} {incr i} {
			set filter [lindex $filters $i]
			if {![info exists FILTER($filter)]} {
				core::log::write WARNING {Unknown filter: $filter}
				lreplace $filters $i $i
			}
		}

		# Finally, filter and return the results.

		set results [list]

		foreach cluster $clusters {
			set cluster [complete_match -matches $cluster]
			foreach filter $filters {
				if {[llength [dict get $cluster matches]] < $min_size} {
					break
				}
				if {[catch {
					set cluster [$FILTER($filter) -matches $cluster]
					set cluster [complete_match -matches $cluster]
				} err]} {
					core::log::write ERROR {$fn: Could not apply filter '$filter' - $err}
					error "Could not apply filter '$filter' - $err" $::errorInfo SYSTEM_ERROR
				}
			}
			if {[llength [dict get $cluster matches]] >= $min_size} {
				lappend results $cluster
			}
		}

		return $results
	}



#-------------------------------------------------------------------------------
# Result Filtering
#-------------------------------------------------------------------------------

# Callback interface for filtering a set of results.
#
# @param -matches The unfiltered set of matches, in common match dict format.
#
# @return The set of matches, in common match dict format, with the filtered
#         customers removed.
#
core::args::register \
	-interface core::cust::matcher::interface_filter \
	-desc      "An interface defining the structure of callbacks for filtering match results." \
	-args      [list \
		[list -arg -matches -mand 1 -check NONE -desc "The match result set to be filtered."] \
	]


core::args::register \
	-interface core::cust::matcher::update_hashes \
	-desc      {An interface defining the structure that callbacks for updating hashes in the database must follow} \
	-args      [list \
		[list -arg -cust_id      -mand 1 -check UINT  -desc {Customer Id of the customer to update the hashes for}] \
		[list -arg -cust_details -mand 1 -check NONE  -desc {Dict containing the customer details}] \
	]
#-------------------------------------------------------------------------------
# Null Matcher
#-------------------------------------------------------------------------------
core::args::register \
	-proc_name core::cust::matcher::null_match_customer \
	-clones    core::cust::matcher::interface_match_customer \
	-is_public 0 \
	-args [list \
		[list -arg -cust_id -mand 1 -check INT] \
	] \
	-body {
		core::log::write DEBUG {core::cust::matcher::null_match_customer}

		return [dict create \
			identifier [list] \
			master     [list] \
			matches    [list] \
		]
	}



core::args::register \
	-proc_name core::cust::matcher::null_match_detail \
	-clones    core::cust::matcher::interface_match_detail \
	-is_public 0 \
	-args [list \
		[list -arg -details -mand 1 -check NONE] \
	] \
	-body {
		core::log::write DEBUG {core::cust::matcher::null_match_detail}

		return [dict create \
			identifier [list] \
			master     [list] \
			matches    [list] \
		]
	}



core::args::register \
	-proc_name core::cust::matcher::null_match_cross \
	-clones    core::cust::matcher::interface_match_cross \
	-is_public 0 \
	-body {
		core::log::write DEBUG {core::cust::matcher::null_match_cross}

		return [list]
	}
