# ==============================================================
# $Id: parse_xml.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# (C) 2000 Orbis Technology Ltd. All rights reserved.
# ==============================================================


#-----------------------------------------------------------------------------
# set up an event parser, this reads nodes and text values associated
# with the nodes into the XML_REPONSE array
#
# NB it doesn't check the validity or wellformedness
#
# to use just call parseBody with the XML, this will generate an array
# in the form:
#
# XML_RESPONSE(elements)       <list of nodes>
# XML_RESPONSE(attribute)      <value>
# XML_RESPONSE(node,elements)  <list of sub-nodes>
# XML_RESPONSE(node,attribute) <value>
# etc...
#-----------------------------------------------------------------------------

package require xml
package require OB_Log

namespace eval parse_xml {

proc parseBody {xml_body {store_vals_list 0}} {

	variable XML_RESPONSE
	variable XML_NAME

	parse_xml::clean

	set XML_NAME ""
	array set XML_RESPONSE ""

	set parser [xml::parser]

	$parser configure -elementstartcommand parse_xml::handleStart

	# in order to better handle multiple elements with the same name, specify
	# whether to store element values as a list
	if {$store_vals_list} {
		$parser configure -characterdatacommand parse_xml::handleTextList
	} else {
		$parser configure -characterdatacommand parse_xml::handleText
	}

	$parser configure -elementendcommand parse_xml::handleEnd

	$parser parse $xml_body

	if {$XML_NAME != ""} {
		ob::log::write ERROR {Warning XML improperly formed}
		return 0
	}

	ob::log::write_array DEV XML_RESPONSE

	catch {unset XML_NAME}
	return 1
}

proc clean {} {
	variable XML_RESPONSE
	variable XML_NAME

	catch {unset XML_NAME}
	catch {unset XML_RESPONSE}
}

proc handleStart {name attlist {args {}}} {
	variable XML_NAME
	variable XML_RESPONSE

	set prekey [join [concat $XML_NAME elements] ,]

	lappend XML_RESPONSE($prekey) $name
	lappend XML_NAME $name

	foreach {e f} $attlist {
		set prekey [join $XML_NAME ,]
		set XML_RESPONSE($prekey,$e) $f
	}
}

proc handleText {data} {
	variable XML_NAME
	variable XML_RESPONSE

	set trimmed [string trim $data]
	if {$trimmed != ""} {
		set array_key [join $XML_NAME ,]
		set XML_RESPONSE($array_key) $trimmed
	}
}

proc handleTextList {data} {
	variable XML_NAME
	variable XML_RESPONSE

	set trimmed [string trim $data]
	if {$trimmed != ""} {
		set array_key [join $XML_NAME ,]
		lappend XML_RESPONSE($array_key) $trimmed
	}
}

proc handleEnd args {
	variable XML_NAME

	set XML_NAME [lrange $XML_NAME 0 end-1]
}

}


