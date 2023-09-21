# (C) 2015 OpenBet Technology Ltd. All rights reserved.
#
# Expose multi-tenancy configuration.
#
# Configuration:
#
# Synopsis:
#     package require core::multitenant ?1.0?
#

set pkg_version 1.0
package provide core::multitenant $pkg_version

package require core::check  1.0
package require core::args   1.1

core::args::register_ns \
	-namespace core::multitenant \
	-version   $pkg_version \
	-dependent [list core::check core::args] \
	-docs      api/multitenant.xml

namespace eval core::multitenant {

	variable CFG
	variable INIT
	set INIT 0

}

core::args::register \
	-proc_name core::multitenant::init \
	-desc {Initialise multi-tenancy configutation package.} \
	-args [list \
		[list -arg -systems -mand 0 -check LIST -default_cfg MULTITENANT.SYSTEMS -desc {List of systems, which there may be multiple of.}] \
		[list -arg -names   -mand 0 -check LIST -default_cfg MULTITENANT.CONFIG_NAMES -desc {Names of the config items of interest.}] \
	] \
	-body {

		variable CFG
		variable INIT

		if {$INIT} {
			return
		}

		foreach system $ARGS(-systems) {
			foreach remote_system [OT_CfgGet MULTITENANT.$system.REMOTE_SYSTEMS] {
				foreach name $ARGS(-names) {
					set CFG($system,$remote_system,$name) \
						[OT_CfgGet MULTITENANT.$system.$remote_system.$name {}]
				}
			}
		}
		set INIT 1
	}



core::args::register \
	-proc_name core::multitenant::get \
	-desc {Retrieve configuration ...} \
	-args [list \
		[list -arg -system        -mand 1 -check STRING -desc {The name of the system information is required about}] \
		[list -arg -name          -mand 1 -check STRING -desc {The name of the configutation item of interest.}] \
		[list -arg -remote_system -mand 1 -check STRING -desc {If we don't know the customer, give the remote system.}] \
	] \
	-errors [list MULTITENANT_MISSINGCONFIG] \
	-body {

		variable CFG

		set system $ARGS(-system)
		set name $ARGS(-name)
		set remote_system $ARGS(-remote_system)

		if {[info exists CFG($system,$remote_system,$name)]} {
			return $CFG($system,$remote_system,$name)
		}

		error "Configuration $system,$remote_system,$name not found" {} \
			MULTITENANT_MISSINGCONFIG
	}
