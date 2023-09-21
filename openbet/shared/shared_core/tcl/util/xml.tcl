# Copyright (C) 2004 Orbis Technology Ltd. All Rights Reserved.
#
# XML utilities
#

set pkgVersion 1.0
package provide core::xml $pkgVersion

# Dependencies
package require core::log   1.0
package require core::check 1.0
package require core::args  1.0
package require core::util  1.0
package require tdom

core::args::register_ns \
	-namespace core::xml \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::util] \
	-docs      util/xml.xml

# This package should not rely on a config file
namespace eval core::xml {

	variable CFG
	variable INIT 0

	set CFG(entity_escape_map) [list \
		"\"" "&quot;" \
		"\&" "\&amp;" \
		"<"  "\&lt;" \
		">"  "\&gt;" \
		"'"  "&apos;"]

	set CFG(entity_convert_map) [list \
		"&quot;" "\"" \
		"&amp;"  "\&" \
		"&lt;"   "<" \
		"&gt;"   ">" \
		"&apos;" "'"]
}

core::args::register \
	-proc_name core::xml::init \
	-args [list \
		[list -arg -force_init  -mand 0 -check BOOL  -default 0  -desc {Force initialisation}] \
		[list -arg -dtd_name    -mand 0 -check ASCII -default {} -desc {DTD name}] \
		[list -arg -dtd_dir     -mand 0 -check ASCII -default {} -desc {DTD directory}] \
		[list -arg -dtd_foreign -mand 0 -check BOOL  -default 0  -desc {Use foreign DTD}] \
		[list -arg -dtd_map     -mand 0 -check ASCII -default {} -desc {Mapping from one DTD name to another}] \
	]

proc core::xml::init args {

	variable CFG
	variable INIT

	array set ARGS [core::args::check core::xml::init {*}$args]

	if {$INIT && !$ARGS(-force_init)} {
		return
	}

	set CFG(tnc)         [expr {[catch {package require tnc}] ? 0 : 1}]
	set CFG(versions)    [lsort -dictionary -decreasing [package versions tdom]]
	set CFG(indent)      "-indent 4"
	set CFG(encoding)    "UTF-8"
	set CFG(dtd_name)    $ARGS(-dtd_name)
	set CFG(dtd_dir)     $ARGS(-dtd_dir)
	set CFG(dtd_foreign) $ARGS(-dtd_foreign)
	set CFG(dtd_map)     $ARGS(-dtd_map)

	set INIT 1
}

core::args::register \
	-proc_name core::xml::extract_data \
	-args [list \
		[list -arg -node        -mand 1 -check ASCII             -desc {dom object}] \
		[list -arg -xpath       -mand 1 -check STRING            -desc {xpath expression}] \
		[list -arg -default     -mand 0 -check ASCII -default {} -desc {Default value if xpath fails}] \
		[list -arg -return_list -mand 0 -check BOOL  -default 0  -desc {Calling proc is expecting a list returned}] \
		[list -arg -return_node -mand 0 -check BOOL  -default 0  -desc {Calling proc is expecting a node returned}] \
		[list -arg -namespaces  -mand 0 -check ASCII -default {} -desc {Any namespace aliases required}] \
	]

# Extract data from a node using xpath
# @param -node dom node object
# @param -xpath xpath expression
# @param -default default value if xpath fails
# @param -return_list Calling proc is expecting a list returned
proc core::xml::extract_data args {

	array set ARGS [core::args::check core::xml::extract_data {*}$args]

	set node    $ARGS(-node)
	set default $ARGS(-default)

	if {[llength $ARGS(-namespaces)]} {
		set data_list  [$node selectNodes -namespaces $ARGS(-namespaces) $ARGS(-xpath) type]
	} else {
		set data_list  [$node selectNodes $ARGS(-xpath) type]
	}

	set value_list [list]

	if {![llength $data_list]} {
		return $default
	}

	foreach data $data_list {
		if {[llength $data_list] == 1 && !$ARGS(-return_list)} {
			switch -- $type {
				attrnodes {return [lindex $data 1]}
				empty     {return $default}
				bool      -
				number    -
				string    {return $data}
				nodes     {
					if {$ARGS(-return_node)} {
						return $data
					} else {
						return [$data text]
					}
				}
			}
		} else {
			switch -- $type {
				attrnodes {lappend value_list [lindex $data 1]}
				empty     {lappend value_list $default}
				bool      -
				number    -
				string    {lappend value_list $data}
				nodes     {
					if {$ARGS(-return_node)} {
						lappend value_list $data
					} else {
						lappend value_list [$data text]
					}
				}
			}
		}
	}

	return $value_list
}

core::args::register \
	-proc_name core::xml::add_element \
	-args [list \
		[list -arg -node  -mand 1 -check ASCII              -desc {dom object to add child to}] \
		[list -arg -name  -mand 1 -check ASCII              -desc {Name of element}] \
		[list -arg -value -mand 0 -check ANY    -default {} -desc {Value of element}] \
		[list -arg -ns    -mand 0 -check STRING -default {} -desc {The namespace of the element to add}] \
	]

# Create a element with text node.
# @param -node  : dom node object to which the created node will be added.
# @param -name  : name of element.
# @param -value : value of element.
# @paran -ns    : the namespace of the element to add.
# @returns the added element.
proc core::xml::add_element args {

	array set ARGS [core::args::check core::xml::add_element {*}$args]

	set node  $ARGS(-node)
	set value $ARGS(-value)
	set ns    $ARGS(-ns)

	set doc  [$node ownerDocument]

	if { $ns == {} } {
		set elem [$doc createElement $ARGS(-name)]
	} else {
		set elem [$doc createElementNS $ns $ARGS(-name)]
	}

	if {$value != {}} {
		$elem appendChild [core::xml::add_textnode -node $elem -value $value]
	}

	$node appendChild $elem
	return $elem
}

core::args::register \
	-proc_name core::xml::add_CDATA \
	-args [list \
		[list -arg -node -mand 1 -check ASCII -desc {dom object}] \
		[list -arg -data -mand 1 -check ANY   -desc {CDATA data}] \
	]

# Add a CDATA section
# @param -node dom node object
# @param -data CDATA data
proc core::xml::add_CDATA args {

	array set ARGS [core::args::check core::xml::add_CDATA {*}$args]

	set node $ARGS(-node)
	set data $ARGS(-data)

	set doc   [$node ownerDocument]
	set cdata [$doc createCDATASection $data]
	$node appendChild $cdata
	return $cdata
}

core::args::register \
	-proc_name core::xml::add_comment \
	-args [list \
		[list -arg -node -mand 1 -check ASCII  -desc {dom node object}] \
		[list -arg -text -mand 1 -check ANY    -desc {Comment}] \
	]

# Add an XML comment
# @param -node dom node object
# @param -text Comment
proc core::xml::add_comment args {

	array set ARGS [core::args::check core::xml::add_comment {*}$args]

	set node $ARGS(-node)

	set doc  [$node ownerDocument]
	set text [$doc createComment $ARGS(-text)]

	$node appendChild $text
	return $text
}

core::args::register \
	-proc_name core::xml::add_textnode \
	-args [list \
		[list -arg -node  -mand 1 -check ASCII -desc {dom node object to append text node to}] \
		[list -arg -value -mand 1 -check ANY   -desc {Value of text node}] \
	]

# HEAT 27736 - encodings are causing errors to be thrown
# when attempting to create a node. Try converting to
# and converting from utf-8.
# @param -node dom node object
# @param -value Value of text node
proc core::xml::add_textnode args {

	variable CFG

	array set ARGS [core::args::check core::xml::add_textnode {*}$args]

	set node  $ARGS(-node)
	set value $ARGS(-value)

	# Apply a convert to and convert from if the text node creation fails
	if {[catch {set tn [[$node ownerDocument] createTextNode $value]} err]} {
		core::log::write ERROR {ERROR: [format "%s..." [string range $err 0 250]]}

		# Strip out any invalid XML characters
		#set value [OXi::Util::stripInvalidChars $value]

		if {[catch {set tn [[$node ownerDocument] createTextNode $value]} err]} {
			core::log::write ERROR {ERROR: Failed again $err}

			set tn [[$node ownerDocument] createTextNode {}]
		} else {
			core::log::write INFO {SUCCESS: Conversion worked}
		}
	}

	return $tn
}

# TODO - We need to have a utf8 parse
core::args::register \
	-proc_name core::xml::add_attribute \
	-args [list \
		[list -arg -node  -mand 1 -check ASCII -desc {dom node object to append text node to}] \
		[list -arg -name  -mand 1 -check ASCII -desc {Name of attribute}] \
		[list -arg -value -mand 1 -check ANY   -desc {Value of attribute}] \
	]

# Create an attribute on a node removing any illegal characters
# @param -node dom node object
# @param -name Name of attribute
# @param -value Value of attribute
proc core::xml::add_attribute args {

	array set ARGS [core::args::check core::xml::add_attribute {*}$args]

	set node  $ARGS(-node)
	set name  $ARGS(-name)
	set value $ARGS(-value)

	if {[catch {$node setAttribute $name $value} err]} {
		core::log::write WARNING {ERROR: $err}

		# Strip out any invalid XML characters
		#set value [OXi::Util::stripInvalidChars $value]

		if {[catch {$node setAttribute $name $value} err]} {
			core::log::write INFO {ERROR: Failed again $err}
			$node setAttribute $name {}
		} else {
			core::log::write INFO {SUCCESS: Conversion worked}
		}
	}
}

core::args::register \
	-proc_name core::xml::parse \
	-args [list \
		[list -arg -filename      -mand 0 -check STRING -default {} -desc {Filename to parse}] \
		[list -arg -xml           -mand 0 -check ANY    -default {} -desc {XML to parse}] \
		[list -arg -strict        -mand 0 -check BOOL   -default 1  -desc {Strict parsing with dtd validation}] \
		[list -arg -sub_directory -mand 0 -check ASCII  -default {} -desc {Name of sub directory}] \
	]

# Parse an xml message into dom
#
# @param -xml XML document to parse
# @param -strict Strict parsing with dtd validation
# @param -sub_directory Name of sub directory
proc core::xml::parse args {

	variable CFG

	array set ARGS [core::args::check core::xml::parse {*}$args]

	set xml      $ARGS(-xml)
	set filename $ARGS(-filename)

	# Check we have either an xml file or a filename to load
	if {$xml == {} && $filename == {}} {
		return [list ERROR "Expecting -filename or -xml"]
	}

	# Read the xml file ready for parsing
	if {$filename != {}} {
		if { [catch {
			set xml [core::util::read_file -file $filename]
		} msg ]} {
			return [list ERROR $msg ]
		}
		core::log::write INFO {Loaded $filename}
	}

	if {[catch {
		if {$ARGS(-strict) && $CFG(tnc)} {
			set parser [expat \
				-externalentitycommand \
					[list [namespace current]::_external_entity_ref_handler $ARGS(-sub_directory)] \
				-paramentityparsing    notstandalone \
				-useForeignDTD         $CFG(dtd_foreign)]

			tnc  $parser enable
			tdom $parser enable

			$parser parse $xml
			set doc [tdom $parser getdoc]

			# Free the memory associated with the validating parser.
			catch {
				tnc  $parser remove
				tdom $parser remove
			}

			$parser free
		} else {
			set doc [dom parse -simple $xml]
		}
	} err]} {
		catch {$doc delete}
		return [list ERROR $err]
	}

	return [list OK $doc]
}

# Used for strict DTD parsing. Callback procedure for external entities.
#
# NOTE: This proc can't use core::args
proc core::xml::_external_entity_ref_handler {sub_directory base system_id public_id} {

	variable CFG

	if {$system_id == {} && $CFG(dtd_foreign)} {
		set file [format "%s/%s" $CFG(dtd_dir) $CFG(dtd_name)]
		core::log::write INFO {Parsing $file}
		return [list filename . $file]
	}

	if {$sub_directory != {}} {
		append sub_directory /
	}

	foreach {request dir} $CFG(dtd_map) {
		if {$request == $system_id} {
			set sub_directory ${dir}/
			break
		}
	}
	set file_name [format "%s/%s%s" $CFG(dtd_dir) $sub_directory $system_id]

	# Do not allow any entities to come from outside the DTD directory
	set file_name [file normalize $file_name]
	set dtd_dir   [file normalize $CFG(dtd_dir)]

	if {![regexp -- "^$dtd_dir/" $file_name]} {
		core::log::write ERROR {WARNING: Attempted to access $file_name, which is not within the DTD directory}
		error {Invalid entity URI}
	}

	core::log::write INFO {Parsing $file_name}

	return [list filename . $file_name]
}

# Highlight the offending line in the XML DTD parsing
# @param -xml XML that has some parsing issue
# @param -err Error thrown by the parser
core::args::register \
	-proc_name core::xml::highlight_parse_error \
	-args [list \
		[list -arg -xml  -mand 1 -check ANY -desc {XML that has some parsing issue}] \
		[list -arg -err  -mand 1 -check ANY -desc {Error thrown by the parser}] \
	] \
	-body {
		set xml       $ARGS(-xml)
		set err       $ARGS(-err)
		set line_no  0
		set err_line {}

		core::log::xwrite \
			-sym_level ERROR \
			-msg       {XML parse error $err} \
			-colour    red

		if {[regexp {at line (\d+),? character (\d+)} $err all err_line err_char]} {
			# Log around the area in question
			foreach line [split $xml \n] {
				incr line_no
				if {$line_no == $err_line} {
					set err_line $line_no
					core::log::xwrite \
						-sym_level ERROR \
						-msg       {WARNING: [format "%-3d:" $line_no] $line} \
						-colour    red

				} elseif {$line_no > $err_line - 10 && $line_no < $err_line + 10} {
					core::log::xwrite \
						-sym_level ERROR \
						-msg       {WARNING: [format "%-3d:" $line_no] $line} \
						-colour    white

				} else {
					core::log::xwrite \
						-sym_level DEBUG \
						-msg       {WARNING: [format "%-3d:" $line_no] $line}
				}
			}

			if {$err_line != {}} {
				core::util::inspect_string $err_line
			}
		} else {
			foreach line [split $xml \n] {
				core::log::write DEBUG {WARNING: [format "%-3d:" [incr line_no]] $line}
			}
		}
	}

# Strip new lines and leading spaces so the XML can be transmitted over a line buffered socket
core::args::register \
	-proc_name core::xml::serialise \
	-args [list \
		[list -arg -node -mand 1 -check ASCII -desc {DOM node to serialise}] \
	] \
	-body {
		set node $ARGS(-node)
		set xml  [$node asXML]

		regsub -line -all {^\s+} $xml {} xml
		regsub       -all {\n}   $xml "" xml

		# The server is line buffering so we should re-add the newline
		append xml \n

		# Delete the dom structure
		destroy -doc [$node ownerDocument]

		return $xml
	}

# Destroy a document object
core::args::register \
	-proc_name core::xml::destroy \
	-args [list \
		[list -arg -doc -mand 1 -check ASCII -desc {DOM object references to destroy}] \
	] \
	-body {
		if {[catch {$ARGS(-doc) delete} err]} {
			core::log::xwrite \
				-sym_level ERROR \
				-msg       {ERROR $err} \
				-colour    red
		}
	}


# Handle string encoding from XML
core::args::register \
	-proc_name core::xml::escape_entity \
	-args [list \
		[list -arg -value -mand 1 -check STRING -desc {Value to be escaped}] \
	] \
	-body {
		variable CFG
		return [string map $CFG(entity_escape_map) $ARGS(-value)]
	}

# Handle string decoding for XML
core::args::register \
	-proc_name core::xml::convert_entity \
	-args [list \
		[list -arg -value -mand 1 -check ASCII -desc {Value to be converted}] \
	] \
	-body {
		variable CFG
		return [string map $CFG(entity_convert_map) $ARGS(-value)]
	}

# Detect problematic Unicode characters and suggest an alternative string to resolve any issues
# Based on http://www.w3.org/TR/xml/#charsets and http://www.w3.org/TR/unicode-xml/#Suitable
core::args::register \
	-proc_name core::xml::check_unicode \
	-desc {Detect problematic Unicode characters and suggest an alternative string to resolve any issues} \
	-args [list \
		[list -arg -string  -mand 1 -check ANY             -desc {String to check for unsuitable or invalid Unicode}] \
		[list -arg -windows -mand 0 -check BOOL -default 0 -desc {Attempt to fix Windows Code Page smart quotes, etc.}] \
		[list -arg -utf8    -mand 0 -check BOOL -default 0 -desc {Handle input string and output suggestion as raw UTF-8}] \
	] \
	-returns {List of Unicode status (OK/UNSUITABLE/INVALID) and suggested alternative for string} \
	-body {
		set str $ARGS(-string)
		set status "OK"

		if {$ARGS(-utf8)} {
			# String is raw UTF-8 (eg. because AS_CHARSET isn't set to UTF-8), convert to Unicode
			set str [encoding convertfrom utf-8 $str]
		}

		if {$ARGS(-windows)} {
			#
			# Attempt to parse "smart quotes", etc. from Windows code pages
			#
			# These code points clash with the C1 control characters
			#

			if {[regexp {[\u0080\u0082\u0084-\u0089\u008B\u0091-\u0099\u009B]} $str]} {
				set str [string map {
					"\u0080" "\u20AC"
					"\u0082" "\u201A"
					"\u0084" "\u201E"
					"\u0085" "\u2026"
					"\u0086" "\u2020"
					"\u0087" "\u2021"
					"\u0088" "\u02C6"
					"\u0089" "\u2030"
					"\u008B" "\u2039"
					"\u0091" "\u2018"
					"\u0092" "\u2019"
					"\u0093" "\u201C"
					"\u0094" "\u201D"
					"\u0095" "\u2022"
					"\u0096" "\u2013"
					"\u0097" "\u2014"
					"\u0098" "\u02DC"
					"\u0099" "\u2122"
					"\u009B" "\u203A"
				} $str]
				set status "UNSUITABLE"
			}
		}

		#
		# XML-unsuitable characters
		#

		# C0 control characters (except TAB, LF and CR) - unsuitable, remove
		if {[regsub -all {[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]} $str {} str]} {
			set status "UNSUITABLE"
		}

		# C1 control characters (except NEL) - unsuitable, remove
		if {[regsub -all {[\u0080-\u0084\u0086-\u009F]} $str {} str]} {
			set status "UNSUITABLE"
		}

		# Line separator - unsuitable, replace with line break
		if {[regsub -all {\u2028} $str "\n" str]} {
			set status "UNSUITABLE"
		}

		# Paragraph separator - unsuitable, replace with two line breaks
		if {[regsub -all {\u2029} $str "\n\n" str]} {
			set status "UNSUITABLE"
		}

		# Bi-directional embedding characters - unsuitable, remove
		if {[regsub -all {[\u202A-\u202E]} $str {} str]} {
			set status "UNSUITABLE"
		}

		# Unicode surrogates - unsuitable, replace with Replacement Character
		if {[regsub -all {[\uD800-\uDFFF]} $str "\uFFFD" str]} {
			set status "UNSUITABLE"
		}

		# Zero-width non-breaking space/byte-order mark - unsuitable, remove
		if {[regsub -all {[\uFEFF\uFFFE]} $str {} str]} {
			set status "UNSUITABLE"
		}

		# Interlinear Annotation Anchor - unsuitable, remove
		if {[regsub -all {\uFFF9} $str {} str]} {
			set status "UNSUITABLE"
		}

		# Interlinear Annotation Separator - unsuitable, replace with "["
		if {[regsub -all {\uFFFA} $str {[} str]} {
			set status "UNSUITABLE"
		}

		# Interlinear Annotation Terminator - unsuitable, replace with "]"
		if {[regsub -all {\uFFFB} $str {]} str]} {
			set status "UNSUITABLE"
		}

		# Object Replacement Character - unsuitable, remove
		if {[regsub -all {\uFFFC} $str {} str]} {
			set status "UNSUITABLE"
		}

		#
		# Invalid characters
		#

		# Non-characters - invalid, replace with Replacement Character
		if {[regsub -all {[\uFDD0-\uFDEF\uFFFF]} $str "\uFFFD" str]} {
			set status "INVALID"
		}

		#
		# Deprecated Unicode characters
		#

		# Combining Grave Tone Mark - invalid, replace with Combining Grave Mark
		if {[regsub -all {\u0340} $str "\u0300" str]} {
			set status "INVALID"
		}

		# Combining Acute Tone Mark - invalid, replace with Combining Acute Mark
		if {[regsub -all {\u0341} $str "\u0301" str]} {
			set status "INVALID"
		}

		# Khmer Independent Vowel Qaq - invalid, replace with Khmer Letter Qa
		if {[regsub -all {\u17A3} $str "\u17A2" str]} {
			set status "INVALID"
		}

		# Khmer Sign Bathamasat - invalid, replace with Replacement Character
		if {[regsub -all {\u17D3} $str "\uFFFD" str]} {
			set status "INVALID"
		}

		# Formatting characters - invalid, remove
		if {[regsub -all {[\u206A-\u206F]} $str {} str]} {
			set status "INVALID"
		}

		switch -- $status {
			"UNSUITABLE" {
				core::log::write {WARNING} \
					{WARNING: "[core::util::expand_unicode $ARGS(-string)]" contains unsuitable characters; suggest "[core::util::expand_unicode $str]"}
			}
			"INVALID" {
				core::log::write {ERROR} \
					{ERROR: "[core::util::expand_unicode $ARGS(-string)]" contains invalid characters; suggest "[core::util::expand_unicode $str]"}
			}
		}

		if {$ARGS(-utf8)} {
			# Convert back to raw UTF-8
			set str [encoding convertto utf-8 $str]
		}

		return [list $status $str]
	}

# Log an XML node, optionally with some elements masked.
core::args::register \
	-proc_name core::xml::log \
	-args [list \
		[list -arg -node             -mand 1                 -check ASCII -desc {The XML node to be logged}] \
		[list -arg -sym_level        -mand 0 -default INFO   -check ASCII -desc {The symbolic level of the logging}] \
		[list -arg -prefix           -mand 0 -default ""     -check ASCII -desc {A string to prefix the log line with}] \
		[list -arg -masked_elements  -mand 0 -default [list] -check LIST  -desc {A list of elements to be masked while logging the XML}] \
		[list -arg -prefix_all_lines -mand 0 -default 0      -check BOOL  -desc {Add prefix to each line of the XML}] \
	] \
	-body {
		set xml [mask -node $ARGS(-node) -masked_elements $ARGS(-masked_elements)]

		if {$ARGS(-prefix_all_lines) == 0} {
			core::log::write $ARGS(-sym_level) {$ARGS(-prefix)${xml}}
		} else {
			foreach xml_line [split $xml "\n"] {
				core::log::write $ARGS(-sym_level) {$ARGS(-prefix)${xml_line}}
			}
		}
	}

# Returns the XML body, optionally with some elements masked.
core::args::register \
	-proc_name core::xml::mask \
	-args [list \
		[list -arg -node             -mand 1                 -check ASCII -desc {The XML node to be masked}] \
		[list -arg -masked_elements  -mand 0 -default [list] -check LIST  -desc {A list of elements to be masked while logging the XML}] \
	] \
	-body {
		set xml [$ARGS(-node) asXML]

		foreach elem $ARGS(-masked_elements) {
			regsub -all -- [subst {(<${elem}(?:\\s\[^>\]*?\[^/\])??>).*?(</${elem}>)}] $xml {\1******\2} xml
		}

		return $xml
	}

# Retrieve the pom information
core::args::register \
	-proc_name core::xml::get_pom_info \
	-desc {Get Maven pom version} \
	-args [list \
		[list -arg -pom   -mand 0 -check STRING  -default {../pom.xml}      -desc {Maven pom file}] \
		[list -arg -xpath -mand 0 -check STRING  -default {default:version} -desc {xpath expression}] \
	] \
	-body {
		set ret [core::xml::parse \
			-filename $ARGS(-pom) \
			-strict 0]

		if {[lindex $ret 0] != {OK}} {
			error "Unable to parse pom [lindex $ret 1]" {} PARSE_ERROR
		}

		set doc     [lindex $ret 1]
		set root    [$doc documentElement]

		return [extract_data \
			-node $root \
			-xpath $ARGS(-xpath) \
			-namespaces [list default http://maven.apache.org/POM/4.0.0]]
	}

#
# Adds/modifies a property in the properties tag of a pom.xml.
# @param -pom  : the path to the pom file.
# @param -property : the name of the property to set.
# @param -value    : the value of the property to set.
# @returns         : the updated dom.
#
core::args::register \
	-proc_name core::xml::set_pom_property \
	-desc {Get Maven pom version} \
	-args [list \
		[list -arg -pom      -mand 0 -check STRING  -default {../pom.xml}      -desc {Maven pom file}] \
		[list -arg -property -mand 1 -check STRING  -desc {The property to change/create}] \
		[list -arg -value    -mand 1 -check STRING  -desc {The value to set}] \
	] \
	-body {
		set ret [core::xml::parse \
			-filename $ARGS(-pom) \
			-strict 0]

		if {[lindex $ret 0] != {OK}} {
			error "Unable to parse pom [lindex $ret 1]" {} PARSE_ERROR
		}

		set doc     [lindex $ret 1]
		set root    [$doc documentElement]

		set xpath "//default:properties/default:$ARGS(-property)"

		set value [core::xml::extract_data \
			-node $root \
			-xpath $xpath \
			-return_node 1 \
			-default {} \
			-namespaces [list default http://maven.apache.org/POM/4.0.0]]

		if {$value != {} } {
			core::log::write {INFO} {Updating existing value $ARGS(-property)}

			set textnode [$value firstChild]
			if  {$textnode!={}} {
				$value removeChild $textnode
			}

			$value appendChild [core::xml::add_textnode \
				-node $value \
				-value $ARGS(-value)]

		} else {
			core::log::write {INFO} {Adding missing property $ARGS(-property)}

			set properties [core::xml::extract_data \
				-node $root \
				-xpath //default:properties \
				-return_node 1 \
				-default {} \
				-namespaces [list default http://maven.apache.org/POM/4.0.0]]

			if {$properties == {} } {
				error "pom.xml does not have a properties tag" {} POM_NO_PROPERTIES_ERROR
			}

			core::xml::add_element \
				-node $properties \
				-name $ARGS(-property) \
				-value $ARGS(-value) \
				-ns http://maven.apache.org/POM/4.0.0
		}

		core::util::write_file \
			-file $ARGS(-pom) \
			-data [$root asXML]

		return $root
	}
