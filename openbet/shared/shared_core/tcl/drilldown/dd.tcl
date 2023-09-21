# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Provides Drilldown for various objects.
#
# NOTE: This package doesn't provide any functionality as such at present.
# However, the intention of this package is completeness. All the drilldown
# packages (including event, market, collection, commentary, node etc.) should
# belong to this package. This package should abstract all the things common in
# these sub package here.
#
# Only node interface is defined so far as core::dd::node and is implemented by
# pimpl pattern in package core::dd::node::impl
#
set pkg_version 1.0
package provide core::dd $pkg_version

package require core::args                 1.0
package require core::check                1.0

core::args::register_ns \
	-namespace     core::dd \
	-version       $pkg_version \
	-dependent     [list \
		core::args core::check core::db core::date core::interface core::security::token] \
	-desc          {Drilldown hierarchy base package.} \
	-docs          "xml/drilldown/dd.xml"

namespace eval core::dd {
	variable CFG
}


# initialise
core::args::register \
	-interface core::dd::init \
	-args {} \
	-returns {LIST} \
	-body \
{
	variable CFG

	set fn {core::dd::init}
	core::log::write INFO {$fn}

	return [list {OK}]
}



# vim: set ts=8 sw=8 nowrap noet:
