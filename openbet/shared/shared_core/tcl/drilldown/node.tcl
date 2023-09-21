# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Node interface.
# Provides functionality to query DD node hierarchy.
#
# A default implementation of this interface is present at core::dd::node::impl
#
# Example usage:
# package require core::dd::node 1.0
# package require core::dd::node::impl 1.0
#
# core::dd::node::init
#
# core::dd::node::load \
#   -channel {W} \
#   -indexes [list seo_url ob_level]
#
# set roots_of_all_the_trees \
#     [core::dd::node::get_all_roots]
#
# set root_id_fifa2014 \
#     [core::dd::node::get_root_id_by_name \
#       -node_name {FIFAWC_2014}]
#
# set root_id_fifa2015 \
#     [core::dd::node::get_root_id_by_name \
#       -node_name {FIFAWC_2015}]
#
# NOTE: drilldown_node_id is the column in tDrilldownNode, for function
# arguments we use *node_id* to represent the value of this column.  However,
# every node's dictionary has all the columns from tDrilldownNode (including
# drilldown_node_id). There's an ambuigity between node_id argument to TCL
# functions and drilldown_node_id dictionary key.
#
set pkg_version 1.0
package provide core::dd::node $pkg_version

package require core::args                 1.0
package require core::check                1.0
package require core::db                   1.0
package require core::db::schema           1.0
package require core::cache                1.0

core::args::register_ns \
	-namespace     core::dd::node \
	-version       $pkg_version \
	-dependent     [list \
						core::args \
						core::check \
						core::db \
						core::db::schema \
						core::date \
						core::interface] \
	-desc          {Core interface for drilldown nodes (and associated tags).} \
	-docs          "xml/drilldown/node.xml"


namespace eval core::dd::node {
	variable CFG

	variable CORE_DEF
	set CORE_DEF(node_base)           [list -arg -node_base       -mand 1 -check UINT  -desc {Base or Root node.}]
	set CORE_DEF(node_base,opt)       [list -arg -node_base       -mand 0 -check ASCII -desc {Base or Root node.}]
	set CORE_DEF(node_id)             [list -arg -node_id         -mand 1 -check UINT  -desc {A node id in hierarchy.}]
	set CORE_DEF(node_id,opt)         [list -arg -node_id         -mand 0 -check ASCII -desc {A node id in hierarchy.}]
	set CORE_DEF(parent_id)           [list -arg -parent_id       -mand 1 -check UINT  -desc {A parent node id in hierarchy.}]
	set CORE_DEF(parent_id,opt)       [list -arg -parent_id       -mand 0 -check ASCII -desc {A parent node id in hierarchy.}]
	set CORE_DEF(node_name)           [list -arg -node_name       -mand 1 -check ASCII -desc {Name in node hierarchy.}]
	set CORE_DEF(node_name,opt)       [list -arg -node_name       -mand 0 -check ASCII -desc {Name in node hierarchy.}]
	set CORE_DEF(node_name_regex)     [list -arg -node_name_regex -mand 1 -check ASCII -desc {A regex for node name in hierarchy.}]
	set CORE_DEF(node_name_regex,opt) [list -arg -node_name_regex -mand 0 -check ASCII -desc {A regex for node name in hierarchy.}]
	set CORE_DEF(level_num)           [list -arg -level_num       -mand 1 -check ASCII -desc {Level of the node in hierarchy.}]
	set CORE_DEF(level_num,opt)       [list -arg -level_num       -mand 0 -check ASCII -desc {Level of the node in hierarchy.}]
	set CORE_DEF(ob_id)               [list -arg -ob_id           -mand 1 -check UINT  -desc {Openbet id in node hierarchy.}]
	set CORE_DEF(ob_id,opt)           [list -arg -ob_id           -mand 0 -check ASCII -desc {Openbet id in node hierarchy.}]
	set CORE_DEF(ob_level)            [list -arg -ob_level        -mand 1 -check ASCII -desc {Openbet level in node hierarchy.}]
	set CORE_DEF(ob_level,opt)        [list -arg -ob_level        -mand 0 -check ASCII -desc {Openbet level in node hierarchy.}]
	set CORE_DEF(channel)             [list -arg -channel         -mand 1 -check ASCII -desc {Channel.}]
	set CORE_DEF(channel,opt)         [list -arg -channel         -mand 0 -check ASCII -desc {Channel.}]
	set CORE_DEF(channels)            [list -arg -channels        -mand 1 -check ASCII -desc {Channels string.}]
	set CORE_DEF(channels,opt)        [list -arg -channels        -mand 0 -check ASCII -desc {Channels string.}]
	set CORE_DEF(displayed)           [list -arg -displayed       -mand 1 -check ASCII -desc {Is the node displayed.}]
	set CORE_DEF(displayed,opt)       [list -arg -displayed       -mand 0 -check ASCII -desc {Is the node displaued.}]
	set CORE_DEF(disporder)           [list -arg -disporder       -mand 1 -check INT   -desc {Display order of the node.}]
	set CORE_DEF(disporder,opt)       [list -arg -disporder       -mand 0 -check ASCII -desc {Display order of the node.}]
	set CORE_DEF(seo_url)             [list -arg -seo_url         -mand 1 -check ASCII -desc {SEO URL for the node.}]
	set CORE_DEF(seo_url,opt)         [list -arg -seo_url         -mand 0 -check ASCII -desc {SEO URL for the node.}]
	set CORE_DEF(depth)               [list -arg -depth           -mand 1 -check UINT  -desc {Maximum depth to traverse for search.}]
	set CORE_DEF(depth,opt)           [list -arg -depth           -mand 0 -check ASCII -desc {Maximum depth to traverse for search.}]
	set CORE_DEF(force)               [list -arg -force           -mand 1 -check UINT  -desc {Force deleting node with all its children.}]
	set CORE_DEF(force,opt)           [list -arg -force           -mand 0 -check ASCII -desc {Force deleting node with all its children.}]
	set CORE_DEF(callback)            [list -arg -callback        -mand 1 -check ASCII -desc {Name of the procedure to be called when adding/updating a node.}]
	set CORE_DEF(callback,opt)        [list -arg -callback        -mand 0 -check ASCII -desc {Name of the procedure to be called when adding/updating a node.}]
	set CORE_DEF(indexes)             [list -arg -indexes         -mand 1 -check LIST  -desc {List of columns to index in-memory.}]
	set CORE_DEF(indexes,opt)         [list -arg -indexes         -mand 0 -check LIST  -desc {List of columns to index in-memory.}]
	set CORE_DEF(index)               [list -arg -index           -mand 1 -check ASCII -desc {Column name which is indexed.}]
	set CORE_DEF(index,opt)           [list -arg -index           -mand 0 -check ASCII -desc {Column name which is indexed.}]
	set CORE_DEF(value)               [list -arg -value           -mand 1 -check ASCII -desc {Column value to search in index.}]
	set CORE_DEF(value,opt)           [list -arg -value           -mand 0 -check ASCII -desc {Column value to search in index.}]
}


# initialise
core::args::register \
	-interface core::dd::node::init \
	-args [list \
		[list -arg \
			-def_dd_depth -mand 0 -check UINT -default_cfg DD_DEF_DEPTH \
			-desc {Default level to traverse the dd hierarchy tree.}] \
		[list -arg \
			-dd_cache_time -mand 0 -check UINT -default_cfg DD_CACHE_TIME \
			-desc {Time for which the drilldown hierarchy will be stored.}] \
		[list -arg \
			-channel -mand 0 -check ASCII -default_cfg DEFAULT_CHANNEL \
			-desc {Default channel to use.}] \
	] \
	-body \
{
	variable CFG

	foreach {n v} [array get ARGS] {
		set n [string trimleft $n -]
		set CFG($n) $v
		set formatted_name_value [format "%-35s = %s" $n $CFG($n)]
		core::log::write INFO {Drilldown NODE module initialised with $formatted_name_value}
	}
}


#
# Interfaces
#


#
# Load the complete forest of nodes or a specified node into memory.
#
# @param -node_name - (optional) name of the root node. if this argument is not
#                     passed load all the trees possible.
# @param -channel   - (optional) single channel to load. all if not specified.
# @param -displayed - (optional) displayed or not displayed nodes to load. all
#                     if not specified.
# @param -indexes   - (optional) list of columns to index by value. no index
#                     created if not specified.
#
# Returns:
#   - If node_name was speficied and data/tree was loaded
#     [list root_node]
#   - If node_name was not specified
#     [list 
#       ROOT_NAME1 [dict root1]
#       ROOT_NAME2 [dict root2] ...
#     ]
#
core::args::register \
	-interface core::dd::node::load \
	-desc {Load the complete forest of nodes or a specified node into memory.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_name,opt) \
		$::core::dd::node::CORE_DEF(channel,opt) \
		$::core::dd::node::CORE_DEF(displayed,opt) \
		$::core::dd::node::CORE_DEF(indexes,opt) \
	] \
	-returns {LIST}


#
# Get the node dictionary given node_id.
#
# @param -node_id - node id to get the details for
#
# Returns:
#   - If the item exists
#     [dict node]
#   - If the item does not exists
#     []
#
core::args::register \
	-interface core::dd::node::get \
	-desc {Get the node dictionary given node_id.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_id) \
	] \
	-returns {LIST}


#
# Find first item for given name or id and level in the drilldown hierarchy.
#
# @param -parent_id  - parent node where to start the search from
# @param -node_id    - id of the node to search
# @param -name       - name to search for, or
# @param -name_regex - a regular expression to match the node's name
# @param -ob_id      - node id to search for
# @param -ob_level   - openbet hierarchy level to search for
# @param -depth      - depth of hierarchy tree to traverse
#
# Returns:
#   - If the item exists
#     [list found1 found2 ...]
#   - If the item does not exist
#     [list]
#
core::args::register \
	-interface core::dd::node::first \
	-desc {Find first item for given name or id and level in the drilldown hierarchy.} \
	-args [list \
		$::core::dd::node::CORE_DEF(parent_id) \
		$::core::dd::node::CORE_DEF(node_id,opt) \
		$::core::dd::node::CORE_DEF(node_name,opt) \
		$::core::dd::node::CORE_DEF(ob_id,opt) \
		$::core::dd::node::CORE_DEF(ob_level,opt) \
		$::core::dd::node::CORE_DEF(depth,opt) \
	] \
	-returns {LIST}


#
# Find all the item(s) for given name or id and level in the drilldown
# hierarchy.
#
# @param -parent_id  - (required) parent node where to start the search from
# @param -node_id    - id of the node to search
# @param -name       - name to search for, or
# @param -name_regex - a regular expression to match the node's name
# @param -ob_id      - node id to search for
# @param -ob_level   - openbet hierarchy level to search for
# @param -depth      - depth of hierarchy tree to traverse
#
# Returns:
#   - If the item exists
#     [list child1 child2 ...]
#   - If the item does not exist
#     [list]
#
core::args::register \
	-interface core::dd::node::find \
	-desc {Find all the item(s) for given name or id and level in the drilldown
		hierarchy.} \
	-args [list \
		$::core::dd::node::CORE_DEF(parent_id) \
		$::core::dd::node::CORE_DEF(node_id,opt) \
		$::core::dd::node::CORE_DEF(node_name,opt) \
		$::core::dd::node::CORE_DEF(node_name_regex,opt) \
		$::core::dd::node::CORE_DEF(ob_id,opt) \
		$::core::dd::node::CORE_DEF(ob_level,opt) \
		$::core::dd::node::CORE_DEF(depth,opt) \
	] \
	-returns {LIST}


#
# Gets a list of root names of all the trees in the forest. 
#
# Returns:
#   [list 
#     ROOT_NAME1 [dict root1]
#     ROOT_NAME2 [dict root2] ...
#   ]
#
core::args::register \
	-interface core::dd::node::get_all_roots \
	-desc {Gets a list of root names of all the trees in the forest.} \
	-args [list] \
	-returns {LIST}


#
# Gets a list of the id of root node with the given name.
#
# @param -name  - Name of the node whose id is required
#
# Returns:
#   -  If root name is loaded and exists
#      drilldown_node_id
#   -  If root name does not exists
#      []
#
core::args::register \
	-interface core::dd::node::get_root_id_by_name \
	-desc {Gets the id of root node with the given name.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_name) \
	] \
	-returns {LIST}


#
# Gets the drilldown node id of a column value already indexed when loading.
#
# @param -index  - name of the indexed column
# @param -value  - vlaue to search in the index
#
# Returns:
#   if index exists
#     [list dd_id1 dd_id2 ...]
#   if the index doesn't exists
#     []
#
core::args::register \
	-interface core::dd::node::get_by_index \
	-desc {Gets the drilldown node id of a column value already indexed when
		loading.} \
	-args [list \
		$::core::dd::node::CORE_DEF(index) \
		$::core::dd::node::CORE_DEF(value) \
	] \
	-returns {LIST}


# 
# Create a drilldown node. If it has no parent, it is probably going to be a
# toplevel node. If channels is not specified, it will inherit from the parent.
#
# @param -parent_id - id of the node's parent
# @param -name      - name of the node
# @param -ob_id     - node id
# @param -ob_level  - openbet hierarchy level
# @param -channel   - channels this node is available to
# @param -disporder - display order of this node
#
# Returns:
#   [list OK drilldown_node_id] if insert successful
#   throws error otherwise
#
core::args::register \
	-interface core::dd::node::insert \
	-desc {Create a drilldown node. If it has no parent, it is probably going to
		be a toplevel node. If channels is not specified, it will inherit from
		the parent.} \
	-args [list \
		$::core::dd::node::CORE_DEF(parent_id,opt) \
		$::core::dd::node::CORE_DEF(level_num,opt) \
		$::core::dd::node::CORE_DEF(node_name) \
		$::core::dd::node::CORE_DEF(displayed,opt) \
		$::core::dd::node::CORE_DEF(disporder,opt) \
		$::core::dd::node::CORE_DEF(channels,opt) \
		$::core::dd::node::CORE_DEF(ob_id,opt) \
		$::core::dd::node::CORE_DEF(ob_level,opt) \
		$::core::dd::node::CORE_DEF(seo_url,opt) \
	]


#
# Update a drilldown node inplace.
#
# @param -node_id   - existing node_id in the hierarchy.
# @param -ob_id     - obenbet id to update
# @param -ob_level  - openbet hierarchy level to update
# @param -channel   - channels this node is available to
# @param -disporder - display order of this node
#
# Returns:
#   [list OK] if update successful
#   throws error otherwise
#
core::args::register \
	-interface core::dd::node::update \
	-desc {Update a drilldown node inplace.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_id) \
		$::core::dd::node::CORE_DEF(parent_id,opt) \
		$::core::dd::node::CORE_DEF(level_num,opt) \
		$::core::dd::node::CORE_DEF(node_name,opt) \
		$::core::dd::node::CORE_DEF(displayed,opt) \
		$::core::dd::node::CORE_DEF(disporder,opt) \
		$::core::dd::node::CORE_DEF(channels,opt) \
		$::core::dd::node::CORE_DEF(ob_level,opt) \
		$::core::dd::node::CORE_DEF(ob_id,opt) \
		$::core::dd::node::CORE_DEF(seo_url,opt) \
	]


#
# Delete the node specified by the node_id. If the node has children, recursive
# must be set to 1 in order to be deleted.
# 
# @param -node_id   - existing node_id in the hierarchy.
# @param -force     - force the deletion of entire subtree.
#
# Returns:
#   [list OK] if delete successful
#   throws error otherwise
#
core::args::register \
	-interface core::dd::node::delete \
	-desc {Delete the node specified by the node_id. If the node has children,
		recursive must be set to 1 in order to be deleted.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_id) \
		$::core::dd::node::CORE_DEF(force) \
	]


#
# The specified procedure will be called when attempting to add or update a
# node.
#
# @param -node_id   - existing node_id in the hierarchy.
# @param -callback  - name of the procedure (fully qualified)
#
# Returns:
#   [list] with validation status
#
core::args::register \
	-interface core::dd::node::validate \
	-desc {The specified procedure will be called when attempting to add or update
		a node.} \
	-args [list \
		$::core::dd::node::CORE_DEF(node_id) \
		$::core::dd::node::CORE_DEF(callback) \
	]



# vim: set ts=8 sw=8 nowrap noet:
