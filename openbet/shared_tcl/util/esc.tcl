##
# $Id: esc.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# Copyright (C) 2008 Orbis Technology Ltd. All rights reserved.
#
# Escaping functions, including those intended for use with ##TP_ESC##.
#
# Synopsis:
#
#   package require util_esc ?4.5?
#
# Procedures:
#
#   ::esc_js       - Escape string for safe use in Javascript string literal.
#   ::esc_js_value - Escape typed value for use in Javascript / JSON.
#   ::esc_html     - Escape string for safe use in HTML markup.
#   ::esc_none     - The identity function.
#
#   ::ot::codec_*  - Encoding/decoding functions (implementation here only
#                    used if not already provided by the appserver).
#
##

package provide util_esc 4.5

#
# Escape a string so that it may be safely used in a Javascript string
# literal - i.e. without any special meaning to the JS interpreter.
#
# Intended for use with the ##TP_ESC## directive - e.g:
#
#   <script type="text-javascript">
#     ##TP_ESC esc_js ##
#       var foo = '##TP_foo##';
#       var bar = "##TP_bar##";
#     ##TP_ESC##
#   </script>
#

set ::_esc_js_map \
  [list \
     "'"    "\\'"    \
     "\""   "\\\""   \
     "\\"   "\\\\"   \
     "\n"   "\\n"    \
     "\r"   "\\r"    \
     "</"   "<\\/"   ]

proc ::esc_js { s } {
	return [string map $::_esc_js_map $s]
}



# Escape a Tcl value for use as a Javascript / JSON literal.
# Since Tcl is typeless, the caller must specify the type of the value.
#
# The types and the values allowed for each are as follows:
#
#  STRING
#    Anything.
#    e.g. STRING {hello 'world'} => 'hello \'world\''
#  BOOL
#    Anything that can be used in a Tcl "if {$value} ..." statement.
#    e.g. BOOL "3" => true
#  NUMBER
#    Almost any integer or floating point value (including NaN, but not Inf).
#    e.g. NUMBER 1.23 => 1.23
#  ARRAY
#    A valid Tcl list, whose elements will be treated as having type STRING.
#    e.g. ARRAY [list 1 2 3] => ["1","2","3"]
#  ARRAY(<subtype>)
#    A valid Tcl list, whose elements will be treated as all having the type
#    given by <subtype>. There's no way to do arrays of mixed type.
#    e.g. ARRAY(BOOL) [list 0 0 2] => [false,false,true]
#    The subtype can itself be a typed array; e.g.
#    ARRAY(ARRAY(NUMBER)) { {1 2 3} {10 20} } => [[1, 2, 3], [10, 20]]
#  OBJECT
#    A Tcl list of the form:
#    {name1 type1 value1 ... nameN typeN valueN}
#    where nameN gives the name of the Nth property of the object,
#    typeN gives its type, and valueN gives its value. e.g.
#      OBJECT [list age NUMBER 27 name STRING Kieran]
#      => {age: 27, name: 'Kieran'}
#    Note that nested OBJECTs are perfectly fine; e.g.
#      OBJECT {map OBJECT {x NUMBER 1 y OBJECT {i NUMBER 2 j NUMBER 0}}}
#      => {map: {x: 1, y: {i: 2, j: 0}}}
#    It's probably best to avoid giving object properties "unusual" names.
#
# Returns a well-formed javascript literal, or throws an error if the value
# is not appropriate for the type.
#
proc ::esc_js_value {type value} {

	if {[regexp {^ARRAY\(([A-Z()]+)\)$} $type junk subtype]} {
		set type "ARRAY"
	} else {
		set subtype ""
	}

	switch -exact -- $type {
		"STRING" {
			return "'[esc_js $value]'"
		}
		"BOOL" {
			if {[catch {
				set js_value [expr {$value ? "true" : "false"}]
			} msg]} {
				error "Value \"$value\" is not valid for\
				       type \"$type\" ($msg)"
			}
			return $js_value
		}
		"NUMBER" {
			if {[string is double -strict $value]} {
				return $value
			} else {
				error "Value \"$value\" is not valid for\
				       type \"$type\""
			}
		}
		"ARRAY" {
			if {$subtype == ""} {
				set subtype "STRING"
			}
			if {[catch {llength $value} msg]} {
				error "Value \"$value\" is not valid for\
				       type \"$type\" ($msg)"
			}
			set js_entries [list]
			foreach entry $value {
				lappend js_entries [esc_js_value $subtype $entry]
			}
			return "\[[join $js_entries {, }]\]"
		}
		"OBJECT" {
			if {[catch {llength $value}] || [llength $value] % 3} {
				set msg "must be in form {name1 type1 value1 ...\
				         nameN typeN valueN}"
				error "Value \"$value\" is not valid for\
				       type \"$type\""
			}
			set properties [list]
			foreach {name type subval} $value {
				if {[regexp {^[A-Za-z_][A-Za-z_0-9]*$} $name]} {
					set js_name $name
				} else {
					set js_name "\"[esc_js $name]\""
				}
				lappend properties \
				  "${js_name}: [esc_js_value $type $subval]"
			}
			return "{[join $properties {, }]}"
		}
		default {
			error "Unknown type \"$type\"; should be\
			       STRING, BOOL, NUMBER, ARRAY or OBJECT."
		}
	}
}



#
# Escape a string so that it may be safely be used in HTML markup -
# i.e. with no special meaning to the browser.
#
# Intended for use with the ##TP_ESC## directive - e.g:
#
#   <html><body>
#     ##TP_ESC esc_html ##
#       <input type="text" name="##TP_name##" value='##TP_value##'>
#       <##TP_tag##>
#         ##TP_message##
#       </##TP_tag##>
#     ##TP_ESC##
#   </body></html>
#

set ::_esc_html_map \
  [list \
     "<"    "&lt;"   \
     ">"    "&gt;"   \
     "\""   "&quot;" \
     "'"    "&#39;"  ]

proc ::esc_html { s } {
	# Prevent it substituting for html characters, i.e. leave &amp;
	# &#41; &65; alone.
	regsub -all {&(?!(#\d+|#x[::xdigit::]+|\w+);)} $s {\&amp;} s

	return [string map $::_esc_html_map $s]
}


#
# The identity function. Returns s unchanged.
#
# Intended for use when a ##TP_ESC## directive needs to be temporarily
# disabled for one or two datasites - e.g.
#
#   <html><body>
#     ##TP_ESC esc_htm##
#       ##TP_message##
#       <script type="text-javascript">
#       ##TP_ESC esc_js ##
#         var foo = '##TP_foo##';
#         ##TP_ESC esc_none##
#         var mylist = ##TP_an_already_escaped_well_formed_js_list##;
#         ##TP_ESC##
#         var bar = "##TP_bar##";
#       ##TP_ESC##
#       </script>
#     ##TP_ESC##
#   </html></body>
#
# Relies on ##TP_ESC##'s nesting behaviour, which is to use only the
# innermost directive.
#
# Obviously, even though it's an identity function, the procedure call
# from C -> Tcl and back has considerable overhead ...
#

proc ::esc_none { s } {
	return $s
}



#
# Encoder/decoder (codec) commands.
#
# A codec object is used to encode/escape data in some way,
# and to decode/unescape it again.
#
# Each codec object has a codec type which defines the
# general behaviour of the codec object.
#
# Newer versions of the appserver (and libOT_Tcl.so) provide
# fast C versions of these commands; this Tcl implementation
# is provided for users of older appservers that lack them.
#
# Commands:
#
#   ot::codec_create <type> <type_specific_args...>
#    Create a codec object of a given type.
#    See the "Codec Types" section for details of the other
#    arguments required for each type of codec.
#
#   ot::codec_encode <codec> <data>
#     Encode data using codec object <codec>.
#
#   ot::codec_decode <codec> <enc_data>
#     Decode data that was presumably encoded with a codec
#     object equivalent to <codec>.
#
#   ot::codec_delete <codec>
#     Delete a previously created codec object.
#
#   ot::codec_type_exists <type>
#     Does codec type <type> exist?
#
#   ot::codec_type_add <type> <create_proc>
#     Define a new codec type <type> with the given procedure
#     for creating a codec of that type. The <create_proc> can
#     accept a variable number of type-specific arguments, and
#     must return a three-element list containing Tcl commands
#     (expressed as lists) for encoding, decoding and deleting.
#     The encoding and decoding commands will have the data or
#     enc_data args lappend-ed to them before being evaluated.
#
# Codec Types:
#
#   srec - simple record codec
#
#     Overview of the srec codec:
#
#       The srec codec encodes a list of fields into an record string
#       by replacing certain characters within the fields with escape
#       sequences (escaping), and joining the escaped fields with a
#       separator character.
#
#       Escape sequences consist of the chosen escape character,
#       followed by the chosen escape code for the character being
#       escaped. The escape codes for the separator and escape
#       characters are the same as the characters themselves.
#
#     Creating an srec codec:
#
#       To create an srec codec, use:
#
#         ot::codec_create "srec" sep esc map
#
#       where:
#
#         sep      = Field separator char.
#         esc      = Escape char.
#         map      = A list of chars alternated with their escape codes,
#                    where each char is to be replaced by the escape char
#                    followed by its escape code when encoding.
#
#     Example of an srec codec:
#
#       We want to use the simple record codec (srec) to encode fields
#       into records, using pipes as a separator, a hat as the escape
#       character, and we don't want angle brackets in our records -
#       so we escape them with l and r codes for left and right.
#
#       % set my_codec [ot::codec_create srec "|" "^" {< l > r}]
#       codec1
#
#       % ot::codec_encode $my_codec [list a b c | ^ 123 <tag>]
#       a|b|c|^||^^|123|^ltag^r
#
#       % ot::codec_decode $my_codec a|b|c|^||^^|123|^ltag^r
#       a b c | ^ 123 <tag>
#
#

if {![llength [info commands ::ot::codec_create]]} {

	# The appserver doesn't support the ::ot::codec_* commands,
	# so we'll need to define them ourselves in Tcl.

	namespace eval ::ot {
		# internal
		variable CODEC
		variable CODEC_TYPE
		set CODEC(last_id) 0
	}

	proc ::ot::codec_type_exists {type} {
		variable CODEC_TYPE
		return [info exists CODEC_TYPE($type)]
	}

	proc ::ot::codec_type_create {type create_proc} {
		variable CODEC_TYPE
		set CODEC_TYPE($type) $create_proc
		return {}
	}

	proc ::ot::codec_create {type args} {
		variable CODEC_TYPE
		variable CODEC
		set codec "codec[incr CODEC(last_id)]"
		set codec_entry [eval $CODEC_TYPE($type) $args]
		set CODEC($codec) $codec_entry
		return $codec
	}

	proc ::ot::codec_encode {codec data} {
		variable CODEC
		return [eval [lindex $CODEC($codec) 0] [list $data]]
	}

	proc ::ot::codec_decode {codec enc_data} {
		variable CODEC
		return [eval [lindex $CODEC($codec) 1] [list $enc_data]]
	}

	proc ::ot::codec_delete {codec} {
		variable CODEC
		eval [lindex $CODEC($codec) 2] $args
		unset CODEC($codec)
		return {}
	}

	# end "if codec commands exists"
}

if {![::ot::codec_type_exists "srec"]} {

	# The appserver doesn't support the "srec" codec type,
	# so we'll need to define it ourselves in Tcl.

	# Validate that a string contains a single non-null
	# ASCII character - used when creating srec codecs.
	proc ::ot::_srec_codec_is_ascii {str} {
		foreach c [split $str {}] {
			set cp [scan $c %c]
			if {$cp < 1 || $cp > 126} {
				return 0
			}
		}
		return 1
	}

	proc ::ot::_srec_codec_create {sep esc map} {

		if {![_srec_codec_is_ascii $sep] || [string length $sep] != 1} {
			error "bad separator \"$sep\"; must be single ASCII char"
		}
		if {![_srec_codec_is_ascii $esc] || [string length $esc] != 1} {
			error "bad escape character \"$esc\"; must be single ASCII char"
		}
		if {[llength $map] % 2} {
			error "bad map \"$map\"; must have even number of items"
		}
		if {$sep == $esc} {
			error "separator and escape character must differ"
		}

		set enc_map [list $sep ${esc}${sep} $esc ${esc}${esc}]

		# When decoding, we really really want to use the Tcl
		# [split] command because it's much faster then writing
		# anything similar in Tcl. However, because we escape
		# the separator char as escape char separator char, we
		# can't simply split on the separator. Instead, we use
		# a clever trick - before decoding, we map the esc-sep
		# equence to a char that can never appear in our string,
		# then split on the separator, then undo the mapping.
		# We also have to map the esc-esc sequence to something
		# out-of-band to avoid being confused by an esc-esc-sep.
		# The Unicode standards defines the FFDx codepoints as
		# being invalid for interchange, but OK for internal use.

		set subEscEsc \uFDD1
		set subEscSep \uFDD2
		set dec_map_1 [list ${esc}${esc} $subEscEsc ${esc}${sep} $subEscSep]
		set dec_map_2 [list $subEscEsc $esc $subEscSep $sep]

		foreach {char code} $map {
			if {![_srec_codec_is_ascii $char]} {
				error "bad map char item \"$char\"; must be single ASCII char"
			}
			if {![_srec_codec_is_ascii $code]} {
				error "bad map code item \"$code\"; must be single ASCII char"
			}
			if {$char == $sep} {
				error "bad map char item \"$char\"; cannot include separator in map"
			}
			if {$char == $esc} {
				error "bad map char item \"$char\"; cannot include escape char in map"
			}
			if {$code == $sep} {
				error "bad map code item \"$code\"; cannot be same as separator"
			}
			if {$code == $esc} {
				error "bad map code item \"$code\"; cannot be same as escape char"
			}
			if {[info exists Seen($char)]} {
				error "bad map char item \"$char\"; can only appear once in map"
			}
			set Seen($char) 1
			lappend enc_map   $char ${esc}${code}
			lappend dec_map_2 ${esc}${code} $char
		}

		return \
		[list \
			[list ::ot::_srec_codec_encode $sep $enc_map] \
			[list ::ot::_srec_codec_decode $sep $dec_map_1 $dec_map_2] \
			[list ::ot::_srec_codec_delete] \
		]
	}

	proc ::ot::_srec_codec_encode {sep enc_map data} {
		set esc_fields [list]
		foreach field $data {
			lappend esc_fields [string map $enc_map $field]
		}
		return [join $esc_fields $sep]
	}

	proc ::ot::_srec_codec_decode {sep dec_map_1 dec_map_2 enc_data} {
		# Remove esc-sep sequences before decoding so that
		# we may use Tcl's split command.
		set escsep_free_enc_data [string map $dec_map_1 $enc_data]
		set fields [list]
		set esc_fields [split $escsep_free_enc_data $sep]
		foreach esc_field $esc_fields {
			lappend fields [string map $dec_map_2 $esc_field]
		}
		return $fields
	}

	proc ::ot::_srec_codec_delete {} {}

	::ot::codec_type_create "srec" ::ot::_srec_codec_create

	# end "if srec codec type exists"
}


