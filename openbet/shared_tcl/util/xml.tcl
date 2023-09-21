# $Id: xml.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Manages parsing and validation of XML documents. This is designed to support
# two type of usage. In-bound commuinication with a server and out-bound
# communication with a third party.
#
# Synopsis:
#   package require util_xml 4.5
#
# Configuration:
#   XML_DTD_DIR  - the DTD directory
#   XML_VALIDATE - whether or not to validate the XML
#
# Procedures:
#   ob_xml::init     - initilaise
#   ob_xml::parse    - parse an XML document
#   ob_xml::entitize - replace special characters with entity symbols
#
# See also:
#   http://nnsa.dl.ac.uk/MIDAS/manual/ActiveTcl8.4.9.0-html/tdom/expat.html

package provide util_xml 4.5



# Dependencies
#
package require util_log

package require tnc
package require tdom



# Variables
#
namespace eval ob_xml {

	variable CFG
	variable INIT 0

	# List of currently open documents.
	#
	variable docs [list]
	variable last_req_id -1

	# An array of reference handlers, indexed on the glob of document base.
	# Each element should be a list of three items as described in the
	# externalentitycommand section of the reference manual for expat.
	#
	variable ENTITIY_REF_HANDLERS

	# array of XML entity symbols
	variable ENTITIES
	array set ENTITIES {
		\"  {"quotation mark" "&quot;"  "&#34;"}
		'   {apostrophe       "&apos;"  "&#39;"}
		&   {ampersand 	      "&amp;"   "&#38;"}
		<   {less-than        "&lt;"    "&#60;"}
		>   {greater-than     "&gt;"    "&#62;"}
	}
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Initialise.
#
proc ob_xml::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init

	foreach {n v} $args {
		set CFG($n) $v
	}

	foreach {n v} {
		dtd_dir   dtd
		validate  1
	} {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet XML_[string toupper $n] $v]
		}
	}

	# note that we expect to change into the HTML directory shortly, so
	# after this point, all use of the DTD directory will need to be
	# prefixed by ../
	if {![file isdirectory $CFG(dtd_dir)]} {
		ob_log::write WARNING {Config item XML_DTD_DIR is not a directory}
	}

	if {![string is integer -strict $CFG(validate)]} {
		error "Config item XML_VALIDATE is not a boolean (0|1)"
	}

	# ensure that the DTD directory is absolute
	if {![string match /* $CFG(dtd_dir)]} {
		set CFG(dtd_dir) [file join [pwd] $CFG(dtd_dir)]
	}

	if {$CFG(validate)} {
		ob_log::write INFO {xml: Using the XML DTD validator, with DTD \
			directory '$CFG(dtd_dir)'}
	} else {
		ob_log::write INFO {xml: Not using DTD validation}
	}

	set INIT 1
}



#--------------------------------------------------------------------------
# Procedures
#--------------------------------------------------------------------------

# Reset critical details.
#
proc ob_xml::_auto_reset {} {

	variable docs
	variable last_req_id

	if {$last_req_id == [reqGetId]} {
		return
	}

	set last_req_id [reqGetId]

	foreach doc $docs {
		# may have already been deleted
		catch {$doc delete}
	}

	set docs [list]
}



# Parses an xml file into tdom using validation if the program is in development.
#
# ob_xml::parse xml ?-validate|-novalidate?
#
#   xml         - an xml string
#   -validate   - force validation (may override the config )
#   -novalidate - for no validation (may override the config )
#   returns     - a tdom document for manipulation
#
proc ob_xml::parse {xml args} {

	variable CFG
	variable docs

	_auto_reset

	ob_log::write DEV {xml: parsing $xml}

	set validate [expr {
		[lsearch $args "-validate"] >= 0 ? 1 :
			([lsearch $args "-novalidate"] >= 0 ? 0 : $CFG(validate))}]

	# validate the xml
	if {$validate} {
		set caught [catch {
			set parser [expat]

			$parser configure \
				-externalentitycommand	[namespace which \
					_external_entity_ref_handler] \
				-paramentityparsing 	notstandalone \
			]

			tnc $parser enable
			tdom $parser enable

			$parser parse $xml

			set doc [tdom $parser getdoc]
		} msg]

		catch {tnc $parser remove}
		catch {tdom $parser remove}
		catch {$parser free}

		if {$caught} {
			error $msg $::errorInfo $::errorCode
		}
	} else {
		set doc [dom parse -simple $xml]
	}

	lappend docs $doc

	return $doc
}



# Add a reference handler, this can be used to override the default behaviour
# of looking in the DTD directory for a file. This command is not expected to
# be used a great deal.
#
#   base    - document base (glob experssion
#   handler - a command to evaluated with three arguments, the document base
#             the system_id and the publid id.
#             This must return a three element list, see expat documentation
#
proc ob_xml::add_external_entity_ref_handler {base handler} {

	variable ENTITIY_REF_HANDLERS

	set ENTITIY_REF_HANDLERS($base) $handler
}



# Find handler for different DTDs.
#
#   base      - unknown
#   system_id - unknown
#   public_id - unknown
#
proc ob_xml::_external_entity_ref_handler {base system_id public_id} {

	variable CFG
	variable ENTITIY_REF_HANDLERS

	ob_log::write DEV {xml: getting external handler for '$base', \
		'$system_id', '$public_id'}

	set handler [list filename . $CFG(dtd_dir)/$system_id]

	# sorting encourages more specific patterns
	foreach base_pattern [lsort -decreasing [array names ENTITIY_REF_HANDLERS]] {
		if {[string match $handler $base_pattern]} {
			set handler [uplevel #0 $ENTITIY_REF_HANDLERS($base_pattern) \
				[list $base $system_id $public_id]]
			break
		}
	}

	return $handler
}



# Removes bad characters from text and turns them into entitiy symbols.
#
#   s      - string to entitize
#   method - type of entity symbol to use, name or number, name should work
#            in all cases
#
proc ob_xml::entitize {s {method name}} {

	variable ENTITIES

	switch $method {
		name {
			set entity_idx 1
		}
		number {
			set entity_idx 2
		}
		default {
			error "Method unknown"
		}
	}

	set map [list]

	foreach n [array names ENTITIES] {
		lappend map $n [lindex $ENTITIES($n) $entity_idx]
	}

	return [string map $map $s]
}

# replace the content of certain xml nodes with ****
#
#    xml - xml to parse
#    nodes - list of node names
#
proc ob_xml::mask_nodes {xml nodes} {

	foreach node $nodes {
		set xml [regsub "(<$node.*>).*(</$node>)" $xml {\1****\2}]
	}

	return $xml
}
