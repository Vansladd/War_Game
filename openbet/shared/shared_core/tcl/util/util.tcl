# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Miscellaneous utilities
#
set pkg_version 1.0
package provide core::util $pkg_version

package require core::check 1.0
package require core::args  1.0

core::args::register_ns \
	-namespace core::util \
	-version   $pkg_version \
	-dependent [list core::check core::args] \
	-docs      xml/util/util.xml

namespace eval core::util {

	if {[info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8"} {
		set ENCODING_FLAG -utf8
	} else {
		set ENCODING_FLAG -bin
	}
}

# Load a tcl package
# @return version loaded
core::args::register \
	-proc_name core::util::load_package \
	-args      [list \
		[list -arg -package     -mand 1 -check ASCII             -desc {Package name}] \
		[list -arg -version     -mand 0 -check ASCII -default {} -desc {Package version}] \
		[list -arg -ignore_list -mand 0 -check ANY   -default {} -desc {Ignore a list of packages}] \
	] \
	-body {
		set package     $ARGS(-package)
		set version     $ARGS(-version)
		set ignore_list $ARGS(-ignore_list)
		set has_error   0

		# Re-write package so we can intercept the package requires
		if {[llength $ignore_list]} {
			set ignore_body {}
			foreach {ignore_pkg ignore_version} $ignore_list {
				core::log::xwrite -msg {Ignoring Package $ignore_pkg $ignore_version} -colour red
				lappend ignore_body [subst -nocommands {
					if {"$ignore_pkg" == [lindex \$args 1]} {
						puts "SKIPPING package $ignore_pkg $ignore_version (\$args)"
						return
					}
				}]
			}

			set body [subst {
				if {\[lindex \$args 0\] == {require}} {
					[join $ignore_body \n]
				}

				::_package {*}\$args
			}]

			proc ::_stubbed_package args $body

			rename ::package          ::_package
			rename ::_stubbed_package ::package
		}

		if {$version != {}} {
			if {[catch {set version [package require $package $version]} err]} {
				incr has_error
			}
		} else {
			if {[catch {set version [package require $package]} err]} {
				incr has_error
			}
		}

		# Re-instate the original package as we have done our job
		if {[llength $ignore_list]} {
			rename ::package  ::_stubbed_package
			rename ::_package ::package
		}

		if {$has_error} {
			error "[info script] [uplevel [list namespace current]] ERROR Loading $package $err" $::errorInfo
		}

		if {$package in $ignore_list} {
			core::log::xwrite -sym_level WARNING -msg {WARNING $package explicitly ignored} -colour red
		} else {
			core::log::write DEBUG {Loaded package $package v$version}
		}

		return $version
	}

# Gets a list of packages that must be loaded
# Calls load_package to load each of them
core::args::register \
	-proc_name core::util::init_packages \
	-args      [list \
		[list -arg -packages     -mand 1 -check LIST             -desc {Packages that need to be loaded}] \
	] \
	-body {

		set fn {core::util::init_packages}

		foreach package $ARGS(-packages) {
			lassign $package module version init
			if {[catch {
				core::util::load_package -package $module -version $version
				if {$init != {}} {
					$init
				}
			} err]} {
				core::log::write ERROR \
					{$fn: Could not initialize package '$package' - $err}
					error "Could not initialize package $package" $::errorInfo INIT_ERROR
			}
		}
	}

# Untabify a string.
# Replaces all tabs with spaces
#
# @param str string to untabify
# @param tablen - tab length; determines the number of space characters per tab
#             (default: 4)
#
# @return string with tabs replaced by spaces
#
# TODO - Replace with package require textutil::tabify  ? 0.7 ?
proc core::util::untabify { str {tablen 4} } {

	set out ""
	while {[set i [string first "\t" $str]] != -1} {
		set j [expr {$tablen - ($i % $tablen)}]
		append out [string range $str 0 [incr i -1]][format %*s $j " "]
		set str [string range $str [incr i 2] end]
	}
	return $out$str
}

# Count how many leading spaces that can be stripped from each string in a list
#
# @param str string list
#
# @return number of leading spaces
#
proc core::util::lead_space_count { str } {

	set min -1
	foreach s $str {
		regsub {^\s+} $s {} n
		set c [expr {[string length $s] - [string length $n]}]
		if {$min == -1} {
			set min $c
		} elseif {$c < $min} {
			set min $c
		}
	}
	return [expr {($min < 0) ? 0 : $min}]
}

# Check whether a tcl string contains any unsafe characters '[][${}\\]'.
# If CHARSET is set, the string will be encoded first.
#
# @param str string to check
#
# @return non-zero if the string is safe, else zero if unsafe
#
proc core::util::is_safe { str } {

	global CHARSET

	if {[info exists CHARSET]} {
		if {!([info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8")} {
			set str [encoding convertfrom $CHARSET $str]
		}
	}

	if {[regexp {[][{}\\<>$]} $str]} {
		return 0
	}
	return 1
}

# Find the min value in a given list
#
# @param args list of args
#
# @return min value in the list
#
# TODO replace with package require math::statistics 0.5
proc core::util::min { args } {

	switch [llength $args] {
		0 {return {}}
		1 {return [lindex $args 0]}
		default {
			set a [lindex $args 0]
			set b [eval min [lrange $args 1 end]]
			if {$b == ""} {
				return $a
			} elseif {$a == ""} {
				return $b
			} elseif {$a < $b} {
				return $a
			} else {
				return $b
			}
		}
	}

}

# Find the max value in a given list
#
# @param args list of args
#
# @return max value in the list
#
# TODO replace with package require math::statistics 0.5
proc core::util::max { args } {

	switch [llength $args] {
		0 {return {}}
		1 {return [lindex $args 0]}
		default {
			set a [lindex $args 0]
			set b [eval max [lrange $args 1 end]]
			if {$b == ""} {
				return $a
			} elseif {$a == ""} {
				return $b
			} elseif {$a > $b} {
				return $a
			} else {
				return $b
			}
		}
	}
}

# Removes duplicates without sorting the input list.
# Returns a new list.
#
# @paran l List that might contain duplicates.
#
# @return r List that has the elements of the original list minus any duplicates.
#
proc core::util::luniq {l} {

	set r {}

	foreach i $l {
		if {[lsearch -exact $r $i] == -1} {
			lappend r $i
		}
	}

	return $r
}

# Remove an item from a list
# @param list List from which item will be removed
# @param value Value to be removed from the list
# @param idx Position of value if known
proc core::util::ldelete {list value {idx -1}} {
	if {$idx == -1} {
		set idx [lsearch -exact $list $value]
	}
	return [expr {$idx >= 0 ? [lreplace [K $list [set list {}]] $idx $idx] : $list}]
}

# Util function used by ldelete to speed up lreplace
proc core::util::K {x y} {
	set x
}

# Inspect and display the UTF-8 and Unicode information about a string
#
# @param string String to inspect
# @return list of characters, unicode and utf-8
proc core::util::inspect_string {string} {

	binary scan [encoding convertto utf-8 $string] H* hex

	set utf8    [list]
	set unicode [list]
	set text    [list]

	set utf8_hex    ""
	set unicode_bin ""
	set unicode_hex ""

	set continuation 0

	foreach {h l} [split $hex {}] {
		set byte [string toupper "$h$l"]

		switch -glob -- $byte {
			"[89AB]*" {
				binary scan [binary format H* $byte] B* bin

				append utf8_hex      $byte
				append unicode_bin   [string range $bin 2 end]
				incr   continuation -1

				if {!$continuation} {
					while {[string length $unicode_bin] % 4} {
						set unicode_bin "0$unicode_bin"
					}
					regsub {^(0{4})*(.)} $unicode_bin {\2} unicode_bin

					set unicode_hex ""
					foreach {a b c d} [split $unicode_bin {}] {
						binary scan [binary format B4 "$a$b$c$d"] H1 nibble
						append unicode_hex [string toupper $nibble]
					}

					lappend utf8    $utf8_hex
					lappend unicode $unicode_hex
					lappend text    [encoding convertfrom utf-8 [binary format H* $utf8_hex]]
				}
			}
			"[CD]*" {
				binary scan [binary format H* $byte] B* bin

				set utf8_hex      "$byte"
				set unicode_bin   [string range $bin 3 end]
				set continuation 1
			}
			"E*" {
				binary scan [binary format H* $byte] B* bin

				set utf8_hex      "$byte"
				set unicode_bin   [string range $bin 4 end]
				set continuation 2
			}
			"F*" {
				binary scan [binary format H* $byte] B* bin

				set utf8_hex      "$byte"
				set unicode_bin   [string range $bin 5 end]
				set continuation 3
			}
			default {
				regsub {^0*(.)} $byte {\1} ubyte

				lappend utf8    $byte
				lappend unicode $ubyte
				lappend text    [encoding convertfrom utf-8 [binary format H* $byte]]
				set continuation 0
			}
		}
	}

	set char_out [list]
	foreach c $text utf8_hex $utf8 {
		lappend char_out [format "%[string length $utf8_hex]s" $c]
	}

	set unicode_out [list]
	foreach u $unicode utf8_hex $utf8 {
		lappend unicode_out [format "%[string length $utf8_hex]s" $u]
	}

	return [list $char_out $unicode_out $utf8]
}

#
# Expand non-ASCII characters in a string to Unicode escape sequences (\uNNNN) for logging
#
core::args::register \
	-proc_name core::util::expand_unicode \
	-desc {Expand non-ASCII characters in a string to Unicode escape sequences (\uNNNN) for logging} \
	-args [list \
		[list -arg -string -mand 1 -check ANY -desc {String to expand}] \
	] \
	-returns {String with non-ASCII characters expanded to Unicode escape sequences} \
	-body {
		set expanded_str ""
		foreach char [split $ARGS(-string) {}] {
			if {[regexp {^[\x20-\x7E]$} $char]} {
				append expanded_str $char
			} else {
				append expanded_str [format {\u%04X} [scan $char %c]]
			}
		}
		return $expanded_str
	}

# Convert a list of lists into a csv file
# http://en.wikipedia.org/wiki/Comma-separated_values
#
#  * fields that contain commas, double-quotes, or line-breaks must be quoted,
#  * a quote within a field must be escaped with an additional quote immediately preceding the literal quote,
#  * space before and after delimiter commas may be trimmed (which is prohibited by RFC 4180), and
#  * a line break within an element must be preserved.
core::args::register \
	-proc_name core::util::list_to_csv \
	-args [list \
		[list -arg -list      -mand 1 -check ANY                 -desc {List to convert to CSV file}] \
		[list -arg -delimiter -mand 0 -check STRING -default {,} -desc {Field delimiter}] \
	] \
	-body {
		set list      $ARGS(-list)
		set delimiter $ARGS(-delimiter)

		set csv_list [list]
		foreach record $list {
			set csv_sub_list [list]
			set re [subst -nocommands {[\"${delimiter}\n\r]}]

			foreach field $record {
				if {[regexp $re $field]} {
					regsub -all {(\n\r?|\r\n?)} $field "\n" field
					regsub -all {\"} $field "\"\"" field
					set field "\"$field\""
				}
				if {$field == {}} {
					lappend csv_sub_list "\"\""
				} else {
					lappend csv_sub_list $field
				}
			}

			lappend csv_list [join $csv_sub_list $delimiter]

		}
		return [join $csv_list "\n"]
	}

# Randomise a list of sub-lists
core::args::register \
	-proc_name core::util::lrandomise \
	-args [list \
		[list -arg -list -mand 1 -check ANY -desc {List of lists to randomise}] \
	] \
	-body {
		set n     1
		set slist {}
		foreach item $ARGS(-list) {
			set index [expr {int(rand()*$n)}]
			set slist [linsert $slist $index $item]
			incr n
		}

		return $slist
	}

# Return the intersection of two lists
proc core::util::intersection {a b} {
	set ret [list]
	array set A {}
	foreach elem $a {
		set A($elem) 1
	}
	foreach elem $b {
		if {[info exists A($elem)]} {
			lappend ret $elem
		}
	}
	return $ret
}

# Return the symmetric difference of two lists (elements that exist only in one of the two lists).
proc core::util::lxor {a b} {
	set ret [list]

	foreach elem $a {
		if {$elem in $b} {
			set b [ldelete $b $elem]
		} else {
			lappend ret $elem
		}
	}

	lappend ret {*}$b
	return $ret
}

# Chop a list into sublists and pad - Replaces core::util::group
core::args::register \
	-proc_name core::util::lchop \
	-args [list \
		[list -arg -list     -mand 1 -check ANY                -desc {List to chop}] \
		[list -arg -size     -mand 1 -check UINT               -desc {Number of items per list}] \
		[list -arg -pad_list -mand 0 -check BOOL   -default 0  -desc {Pad final list with padding}] \
		[list -arg -padding  -mand 0 -check STRING -default -1 -desc {Padding}] \
	] \
	-body {
		set temp {}
		set l    $ARGS(-list)
		set size $ARGS(-size)

		while {[llength $l] > $size} {
			set chopped [lrange $l 0 [expr {$size -1}]]
			set l       [lreplace $l 0 [expr {$size -1}]]
			lappend temp $chopped
		}

		if {$ARGS(-pad_list)} {
			lappend temp [_lpad $l $ARGS(-padding) $size]
		} else {
			lappend temp $l
		}

		return $temp
	}

# Pad a list
core::args::register \
	-proc_name core::util::lpad \
	-desc      {Pad a list} \
	-args [list \
		[list -arg -list     -mand 1 -check ANY                -desc {List to pad}] \
		[list -arg -size     -mand 1 -check UINT               -desc {Final padded size}] \
		[list -arg -padding  -mand 0 -check STRING -default -1 -desc {Padding}] \
	] \
	-body {
		_lpad $ARGS(-list) $ARGS(-padding) $ARGS(-size)
	}

# Private proc used by lchop for speed
proc core::util::_lpad {l padding size} {
	set pad_count [expr {$size - [llength $l]}]
	if {$pad_count > 0} {
		return [lappend l {*}[lrepeat $pad_count $padding]]
	}

	# If the size is less than the length of the list we should
	# chop the list back. It doesn't make a huge amount of sense
	# padding a list and asking for less than the length to be
	# returned but it could be possible.
	return [lrange $l 0 [expr {$size -1}]]
}

# Convert data
proc core::util::convert_encoding {value} {

	# Check to see if the value needs conversion
	if {[regexp {^[\x00-\x7F]*$} $value]} {
		return $value
	}

	set native     [encoding convertfrom utf-8 $value]
	set utf8_value [encoding convertto   utf-8 $native]

	if {[string equal $value $utf8_value]} {
		return $native
	}

	return $value
}

# Read data from a file
core::args::register \
	-proc_name core::util::open_file \
	-desc {Open a file and return the file descriptor} \
	-args [list \
		[list -arg -file        -mand 1 -check STRING                -desc {Filename}] \
		[list -arg -translation -mand 0 -check STRING -default auto  -desc {File translation}] \
		[list -arg -encoding    -mand 0 -check STRING -default utf-8 -desc {File encoding}] \
		[list -arg -access      -mand 0 -check STRING -default r     -desc {File accesss (r,r+,w,w+,a,a+)}] \
		[list -arg -buffersize  -mand 0 -check UINT   -default 4096  -desc {File buffer size}] \
	] \
	-body {
		set file $ARGS(-file)

		if {[catch {
			set fd [open $file $ARGS(-access)]
			fconfigure $fd -translation $ARGS(-translation)
			fconfigure $fd -encoding    $ARGS(-encoding)
			fconfigure $fd -buffersize  $ARGS(-buffersize)
		} err]} {
			error "Unable to open file $file $err" $::errorInfo FILE_OPEN_ERROR
		}

		core::log::write DEBUG {Opened $file [fconfigure $fd]}

		return $fd
	}

# Read data from a file
core::args::register \
	-proc_name core::util::read_file \
	-desc {Read the contents of a file} \
	-args [list \
		[list -arg -file        -mand 1 -check STRING                -desc {Filename}] \
		[list -arg -translation -mand 0 -check STRING -default auto  -desc {File translation}] \
		[list -arg -encoding    -mand 0 -check STRING -default utf-8 -desc {File encoding}] \
	] \
	-body {
		set fd [open_file \
			-file        $ARGS(-file) \
			-translation $ARGS(-translation) \
			-encoding    $ARGS(-encoding)]

		if {[catch {
			set data [read $fd]
			close    $fd
		} err]} {
			error "Unable to read $ARGS(-file): $err" $::errorInfo FILE_READ_ERROR
		}

		# Remove the BOM (byte order mark)
		regsub {^(\ufeff|\xef\xbb\xbf)} $data {} data

		return $data
	}

# Write data to file
core::args::register \
	-proc_name core::util::write_file \
	-desc {Write the contents to a file} \
	-args [list \
		[list -arg -file        -mand 1 -check STRING                -desc {Filename}] \
		[list -arg -data        -mand 1 -check ANY                   -desc {Data}] \
		[list -arg -translation -mand 0 -check STRING -default auto  -desc {File translation}] \
		[list -arg -encoding    -mand 0 -check STRING -default utf-8 -desc {File encoding}] \
		[list -arg -access      -mand 0 -check STRING -default w     -desc {File accesss (r,r+,w,w+,a,a+)}] \
		[list -arg -buffersize  -mand 0 -check UINT   -default 4096  -desc {File buffer size}] \
	] \
	-body {
		set fd [open_file \
			-file        $ARGS(-file) \
			-translation $ARGS(-translation) \
			-encoding    $ARGS(-encoding) \
			-access      $ARGS(-access)]

		if {[catch {
			puts  $fd $ARGS(-data)
			close $fd
		} err]} {
			error "Unable to write to $ARGS(-file): $err" $::errorInfo FILE_WRITE_ERROR
		}
	}

core::args::register \
	-proc_name core::util::escape_js \
	-desc {
		Escape javascript
	} \
	-args [list \
		[list -arg -js_str -mand 1 -check ANY -desc {Javascript to escape}] \
	] \
	-body {
		variable ENCODING_FLAG
		return [ot_js_encode  $ENCODING_FLAG $ARGS(-js_str)]
	}

core::args::register \
	-proc_name core::util::make_js \
	-desc {
		Make JS object from TCL
	} \
	-args [list \
		[list -arg -type        -mand 1 -check {RE -args {^STRING|BOOL|NUMBER|ARRAY\(?[A-Z()]*\)?|OBJECT$}} -desc {Type}] \
		[list -arg -value       -mand 1 -check ANY                                                          -desc {Value to transform}] \
	] \
	-dynatrace 1 \
	-body {

		set type  $ARGS(-type)
		set value $ARGS(-value)

		return [make_js_fast $type $value]
	}

proc core::util::make_js_fast {type value} {
	variable ENCODING_FLAG
	
	if {$type ni {STRING NUMBER ARRAY OBJECT} && [regexp {^ARRAY\(([A-Z()]+)\)$} $type junk subtype]} {
		set type "ARRAY"
	} else {
		set subtype ""
	}

	if {$type eq "STRING"} {
		return "\"[ot_js_encode $ENCODING_FLAG $value]\""
	} elseif {$type eq "BOOL"} {
		if {[catch {
			set js_value [expr {$value ? "true" : "false"}]
		} msg]} {
			error "Value \"$value\" is not valid for\
				type \"$type\" ($msg)"
		}
		return $js_value
	} elseif {$type eq "NUMBER"} {
		if {[string is double -strict $value]} {
			return $value
		} else {
			error "Value \"$value\" is not valid for\
				type \"$type\""
		}
	} elseif {$type eq "ARRAY"} {
		if {$subtype == ""} {
			set subtype "STRING"
		}
		if {[catch {llength $value} msg]} {
			error "Value \"$value\" is not valid for\
					type \"$type\" ($msg)"
		}
		set js_entries "\["
		set i 0
		foreach entry $value {
			if {$i == 0} {
				incr i
			} else {
				append js_entries ", "
			}
			append js_entries [core::util::make_js_fast $subtype $entry]
		}
		append js_entries "\]"
		return $js_entries
	} elseif {$type eq "OBJECT"} {
		if {[catch {set len [llength $value]}] || $len % 3} {
			set msg "must be in form {name1 type1 value1 ...\
					nameN typeN valueN}"
			error "Value \"$value\" is not valid for\
				  type \"$type\""
		}
		set properties "{"
		set i 0
		foreach {name type subval} $value {
			if {$i == 0} {
				incr i
			} else {
				append properties ", "
			}
			append properties \
				"\"[ot_js_encode $ENCODING_FLAG $name]\": [core::util::make_js_fast $type $subval]"
		}
		append properties "}"
		return $properties
	}
}

core::args::register \
	-proc_name core::util::mask_string \
	-desc {
		Mask a string using a set template
	} \
	-args [list \
		[list -arg -mask_type -mand 1 -check {ENUM -args {CC FULL}} -desc {Type of mask}] \
		[list -arg -value     -mand 1 -check ANY                    -desc {Value to apply the mask}] \
	] \
	-body {
		set type  $ARGS(-mask_type)
		set value $ARGS(-value)

		switch -- $type {
			CC {
				# Partial Masking, leave last 4 digits
				set mask  [format "XXXX-XXXX-XXXX-%s" [string range $value end-3 end]]
			}
			FULL {
				# Full Masking with ***
				set mask [string repeat * [string length $value]]
			}
			default {
				error "Unknown mask $type" {} UNKNOWN_MASK
			}
		}

		return $mask
	}

core::args::register \
	-proc_name core::util::get_manifest_property \
	-desc {
		Get a property from the manifest
	} \
	-args [list \
		[list -arg -file  -mand 0 -check STRING -default {manifest.xml} -desc {Manifest file}] \
		[list -arg -xpath -mand 0 -check STRING -default {/artifact/@version}      -desc {xpath expression}] \
	] \
	-body {
		set ret [core::xml::parse \
			-filename $ARGS(-file) \
			-strict 0]

		if {[lindex $ret 0] != {OK}} {
			error "Unable to parse pom [lindex $ret 1]" {} PARSE_ERROR
		}

		set doc   [lindex $ret 1]
		set root  [$doc documentElement]

		set ret [core::xml::extract_data -node $root -xpath $ARGS(-xpath)]

		core::xml::destroy -doc $doc

		return $ret
	}

core::args::register \
	-proc_name core::util::parse_dn_string \
	-desc      {Parse a distiguished name string into a dict containing the rdns split into attr types and values} \
	-args [list \
		[list -arg -dn_string -mand 1 -check STRING -desc {Distiguished name (DN) string to parse}] \
	] \
	-body {
		set dn_string $ARGS(-dn_string)

		set state     ATT_TYPE
		set item      {}
		set quoted    0
		set escaped   0
		set att_type  {}
		set rdn_index 0
		set parsed_dn {}

		# Run through the string character by character
		foreach char [split $dn_string {}] {
			switch -exact -- $state {
				ATT_TYPE {
					if {$char == { } && $item == {}} {continue}

					if {[string is alnum $char] || \
						([string length $item] > 0 && [string is alnum $char]) || \
						([string length $item] > 0 && $char == {.}) } {
						append item $char
						continue
					}

					if {$char == {=}} {
						if {$item == {}} {
							error {RDN has an empty attribute type} {} DN_PARSE_ERROR
						}
						set att_type $item
						set item     {}
						set state    ATT_VALUE
						continue
					}
					error "Invalid character $char found in DN attribute type" {} DN_PARSE_ERROR
				}
				ATT_VALUE {
					if {$char == "\\"} {
						set escaped 1
						continue
					}

					if {$escaped} {
						append item $char
						set escaped 0
						continue
					} else {
						if {!$quoted} {
							switch -exact -- $char {
								\" {
									set quoted 1
									continue
								}
								; -
								, {
									set state ATT_TYPE
									dict set parsed_dn $rdn_index $att_type $item
									set item {}
									incr rdn_index
									continue
								}
								+ {
									set state ATT_TYPE
									dict set parsed_dn $rdn_index $att_type $item
									set item {}
									continue
								}
								"#" {
									if {$item != {}} {
										error "Invalid character # found. # Character may only appear at the begining of the attribute value\
										in DN attribute value \"$att_type=$item\"" {} DN_PARSE_ERROR
									} else {
										append item $char
									}
								}
								= -
								< -
								> {
									error "Invalid character \"$char\" found in DN attribute value \"$att_type=$item\"" {} DN_PARSE_ERROR
								}
								default {
									append item $char
								}
							}
						} else {
							switch -exact -- $char {
								\" {
									set quoted 0
									continue
								}
								default {
									append item $char
									continue
								}
							}
						}
					}
				}
			}
		}
		if {$quoted} {
			error {Unterminated DQUOTE in attribute value} {} DN_PARSE_ERROR
		} elseif {$escaped} {
			error {Escape character at the end of the string with nothing to escape} {} DN_PARSE_ERROR
		}

		if {$state == {ATT_VALUE}} {
			# Set the final rdn value once we hit the end of the string
			dict set parsed_dn $rdn_index $att_type $item
		} else {
			error {RDN has no attribute value component, possibly missing "="} {} DN_PARSE_ERROR
		}

		return $parsed_dn
	}


core::args::register \
	-proc_name core::util::expand_markup \
	-desc      {Perform data markup substitutions using TiddlyWiki markup and extra colouring markup as per http://www.tiddlywiki.org/wiki/TiddlyWiki_Markup} \
	-args [list \
		[list -arg -data           -mand 1 -check NONE  -desc {String to subst}]\
		[list -arg -markup_list    -mand 0 -check LIST  -desc {The markup spec} -default [list]]\
		[list -arg -sub_list       -mand 0 -check LIST  -desc {A list of simple one to one substitutions} -default [list]]\
		[list -arg -strip          -mand 0 -check BOOL  -desc {Remove the markup tags and dont add the span tags} -default 0]\
		[list -arg -highlight_only -mand 0 -check BOOL  -desc {Keep the markup after subst} -default 0]\
	] \
	-body {

		set data           $ARGS(-data)
		set markup_list    $ARGS(-markup_list)
		set sub_list       $ARGS(-sub_list)
		set strip          $ARGS(-strip)
		set highlight_only $ARGS(-highlight_only)

		set longest_token 0
		foreach {token value} $sub_list {
			if {[string length $token] > $longest_token} {set longest_token [string length $token]}
		}
		foreach {open close type} $markup_list {
			if {[string length $open ] > $longest_token} {set longest_token [string length $open ]}
			if {[string length $close] > $longest_token} {set longest_token [string length $close]}
		}

		set i          0
		set out        ""
		set open_markup [list]

		while {$i < [string length $data]} {
			set skip [string equal [lindex $open_markup end] __SKIP__]

			set next_match [string length $data]
			set match     ""
			set replace   ""
			set action    ""

			if {!$skip} {
				foreach {token value} $sub_list {
					set idx [string first $token $data $i]
					if {$idx != -1 && $idx < $next_match} {
						set next_match $idx
						set match $token
						set replace $value
						set action ""
					}
				}
			}

			foreach {open close type} $markup_list {
				if {$skip && ![string equal $type __SKIP__]} {
					continue
				}

				if {[string equal $open $close]} {
					set idx [string first $open $data $i]
					if {$idx != -1 && $idx < $next_match} {
						set next_match $idx
						set match $open
						if {[string equal [lindex $open_markup end] $type]} {
							if {![string equal $type __SKIP__] && $type != {}} {
								set replace "</span>"
							} else {
								set replace ""
							}
							set action "-$type"
						} else {
							if {![string equal $type __SKIP__ ] && $type != {}} {
								set replace "<span class=\"$type\">"
							} else {
								set replace ""
							}
							set action "+$type"
						}
					}
				} else {
					if {!$skip} {
						set idx [string first $open $data $i]
						if {$idx != -1 && $idx < $next_match} {
							set next_match $idx
							set match $open
							if {![string equal $type __SKIP__] && $type != {}} {
								set replace "<span class=\"$type\">"
							} else {
								set replace ""
							}
							set action "+$type"
						}
					}

					set idx [string first $close $data $i]
					if {$idx != -1 && $idx < $next_match} {
						set next_match $idx
						set match $close
						if {[string equal [lindex $open_markup end] $type]} {
							if {![string equal $type __SKIP__] && $type != {}} {
								set replace "</span>"
							} else {
								set replace ""
							}
							set action "-$type"
						} else {
							set replace ""
							set action ""
						}
					}
				}
			}

			set sign {}
			if {[regexp {^([+-])(.*)$} $action all sign type]} {
				if {[string equal $sign "+"]} {
					lappend open_markup $type
				} else {
					set open_markup [lrange $open_markup 0 end-1]
				}
			}

			append out [string range $data $i [expr {$next_match - 1}]]

			if {$highlight_only && $sign == {-}} {
				# Add the markup back in
				append out [string range $data $next_match [expr {$next_match + [string length $match] -1}]]
			}

			if {[string length $replace] && !$strip} {
				append out $replace
			}

			if {$highlight_only && $sign == {+}} {
				# Add the markup back in
				append out [string range $data $next_match [expr {$next_match + [string length $match] -1}]]
			}


			set i [expr {$next_match + [string length $match]}]
		}

		if {!$strip} {
			foreach type $open_markup {
				if {![string equal $type __SKIP__]} {
					append out "</span>"
				}
			}
		}

		return $out
	}

core::args::register \
	-proc_name core::util::find_files \
	-desc {
		Recursively find files in a directory
	} \
	-args [list \
		[list -arg -dir     -mand 0 -check STRING -default {.} -desc {Directory name}] \
		[list -arg -pattern -mand 0 -check STRING -default {}  -desc {File pattern to match}] \
	] \
	-body {
		set res {}
		foreach i [lsort [glob -nocomplain -dir $ARGS(-dir) *]] {
			if {[file type $i] eq {directory}} {
				eval lappend res [find_files -dir $i -pattern $ARGS(-pattern)]
			} else {
				if {$ARGS(-pattern) == {} || [regexp $ARGS(-pattern) $i all]} {
					lappend res $i
				}
			}
		}
		return $res
	}


#
# Split <str> into one or more pieces, with the length of each
# piece no greater than <piecelen> when measured in bytes.
#
# If <max_pieces> is non-blank then at most <max_pieces> pieces
# will be returned. If this is not possible (i.e. <str> is too long)
# then an error will be returned.
#
# The <trailing_spaces> argument controls whether the piece(s) may
# end in space (ASCII 0x20) characters. This is important if the
# piece(s) will be stored in Informix CHAR fields since subsequent
# retrieval is likely to remove any trailing space.
#
# It may take the following values:
#
# <trailing_space>   Meaning
#
# Y                  The piece(s) may end in spaces.
#
# N                  The piece(s) may never end in spaces. An error
#                    will be returned if this is unavoidable.
#
# M                  The piece(s) will end in spaces only if <str>
#                    could not otherwise be accomodated in <max_pieces>
#                    pieces or fewer.
#
# Note that if <trailing_space> is N or M, trailing spaces will be
# stripped from <str> prior to splitting.
#
core::args::register \
        -proc_name core::util::split_str_to_pieces \
        -desc      {Split a string into no more than max_pieces, with each piece being the length of piece_length when measured in bytes.} \
        -args [list \
                [list -arg -string               -mand 1 -check STRING               -desc {The string to be cut into pieces}]\
                [list -arg -piece_length         -mand 1 -check INT                  -desc {The length of the pieces which the string will be cut into}]\
                [list -arg -max_pieces           -mand 1 -check INT                  -desc {Maximum number of pieces a string can be cut into where string lt piece_length * max_pieces}]\
                [list -arg -allow_trailing_space -mand 1 -check {ENUM -args {Y N M}} -desc {Flag indicating whether white space is allowed in each piece}]\
        ] \
        -body {

	set str            $ARGS(-string)
	set piecelen       $ARGS(-piece_length)
	set max_pieces     $ARGS(-max_pieces)
	set trailing_space $ARGS(-allow_trailing_space)

	# Sanity checks

	if {$max_pieces != "" && \
		(![string is integer -strict $max_pieces] || $max_pieces < 1)} {
		error "max_pieces must be blank or at least 1" {} INVALID_MAX_PIECES
	}

	if {$trailing_space in [list Y M N] == -1} {
		error "allow_trailing_space must be one of Y,M or N" {} INVALID_ALLOW_TRAILING_SPACE
	}

	# Quick check on length first.
	# Note that we can still run out of room later since a piece
	# will be less than <piecelen> bytes if:
	#  a) we cannot fit a multibyte character in at the end of the piece
	# or
	#  b) we have had to move spaces to the start of the
	#     next piece to meet the <trailing_space> requirement.

	if {$max_pieces != ""} {
		if {[string bytelength $str] > ($piecelen * $max_pieces)} {
			error "string too long ([string bytelength $str] bytes)" {} STRING_TOO_LONG
		}
	}

	# If <trailing_space> is M, recurse with a <trailing_space> of N
	# first, and if that fails try again with a <trailing_space> of Y.

	if {$trailing_space == "M"} {

		if {[catch {
			set pieces [split_str_to_pieces $piecelen $str $max_pieces N]
		}]} {
			set str [string trimright $str " "]
			set pieces [split_str_to_pieces $piecelen $str $max_pieces Y]
		}

		return $pieces

	}

	# If we have restrictions on trailing space in output
	# then strip any trailing space in input.

	if {$trailing_space == "N"} {

		set str [string trimright $str " "]
	}

	# List of pieces to return

	set pieces [list]

	# Current piece we are building up

	set piece ""

	# Whether we had to move spaces to prevent
	# them trailing

	set moved_spaces 0

	# Loop over characters in <str>

	foreach c [split $str {}] {

		set c_b [string bytelength $c]
		set p_b [string bytelength $piece]

		# Is there room to add this character?

		if {$p_b + $c_b <= $piecelen} {

			append piece $c

		} else {

			# No more room, so start new piece.

			# Check first whether we've hit <max_pieces> yet

			if {$max_pieces != "" && [llength $pieces] == $max_pieces} {
				set msg "unable to fit string into $max_pieces \
					   of length $piecelen bytes"
				if {$moved_spaces} {
					append msg " without leaving trailing spaces"
				}
				error $msg {} STRING_TOO_LONG
			}

			if {$trailing_space == "Y"} {

				lappend pieces $piece
				set piece $c

			} else {

				# We must not leave spaces at the end of our current piece
				# since they will get stripped on retrieval.

				if {[regexp {^[ ]*$} $piece]} {

					# However, in this case there's not much we can do since the
					# whole piece consists of space.
					error "unable to split string without creating pieces with trailing space" {} STRING_TOO_LONG

				} else {

					# Move trailing space into start of new piece

					set spaces {}
					while {[string index $piece end] == " "} {
						append spaces [string index $piece end]
						set piece [string range $piece 0 end-1]
					}

					if {[string length $spaces] > 0} {
						set moved_spaces 1
					}

					lappend pieces $piece
					set piece $spaces
					append piece $c

				}

			}

		}
	}

	# Need not check for trailing space in the last piece
	# since if <trailing_space> was N, we removed any
	# trailing space from the input earlier.

	if {[string length $piece] > 0} {
		lappend pieces $piece
	}

	# However, we should check if we've exceeded <max_pieces>.

	if {$max_pieces != "" && [llength $pieces] > $max_pieces} {
		set msg "unable to fit string into $max_pieces \
			   of length $piecelen bytes"
		if {$moved_spaces} {
			append msg " without leaving trailing spaces"
		}
		error $msg {} STRING_TOO_LONG
	}

	return $pieces

}
