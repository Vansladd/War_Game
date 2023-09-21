# $Id: multipart.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# Copyright (c) 2003 Orbis Technology Ltd. All Rights Reserved.
#
# Handle multipart/form-data encoded POST requests.
#
# You'll need a recent version of the appserv to use this -
# it must support reqGetRawPostBytes.
#


##
#
# Call this from req_init to pick up any args passed as a
# multipart/form-data encoded POST request.
#
# Having done so, any args passed in such an encoding
# will be visible to reqGetArg.
#
# For file arguments, reqGetArg will return the client
# filename and the global array REQ_FILES(arg) will
# contain the file data.
#
##
proc process_any_multipart_args {} {

	global REQ_FILES

	if { [info exists REQ_FILES] } { unset REQ_FILES }

	if {![regexp -nocase {\s*multipart/form-data\s*;\s*boundary\s*=\s*(\S+)} [reqGetEnv CONTENT_TYPE] {} boundary]} {
		return
	}

	OT_LogWrite 5 "Found multipart/form-data encoded POST request"

	if {[catch {
		set parts [decode_multipart_mime [reqGetRawPostBytes] $boundary]
	} msg]} {
		OT_LogWrite 2 "Error decoding multipart form data: $msg"
		return 0
	}

	set part_no 0

	foreach part $parts {
		incr part_no
		set processed 0
		set data [lindex $part 1]
		foreach {header_name header_value} [lindex $part 0] {
			if {$header_name == "content-disposition"} {
				if {[regexp {form-data\s*;\s*name\s*=\s*"([^"]+)"(?:\s*;\s*filename\s*=\s*"([^"]+)")?} $header_value all name filename]} {
					if {$filename == ""} {
						OT_LogWrite 5 "Found multipart arg $name"
						reqSetArg $name $data
					} else {
						OT_LogWrite 5 "Found multipart file $name with filename of $filename"
						set REQ_FILES(attached_file_name) $filename
						reqSetArg $name $filename
						set REQ_FILES($name) $data
					}
					set processed 1
				} else {
					OT_LogWrite 5 "Warning: unknown content-disposition $header_value in multipart section $part_no"
				}
			} else {
				OT_LogWrite 5 "Warning: ignoring header $header_name in multipart section $part_no"
			}
		}
		if {!$processed} {
			OT_LogWrite 5 "Warning: ignoring multipart section $part_no"
		}
	}
	return 1
}



proc _test_and_consume {buffer_name buffer_posn_name test} {
	upvar $buffer_name buffer
	upvar $buffer_posn_name i
	if {[string compare [string range $buffer $i [expr {$i + [string length $test] - 1}]] $test] == 0} {
		incr i [string length $test]
		return 1
	} else {
		return 0
	}
}



#
# Split multipart MIME content into parts.
#
# Returns a list of parts, where each part is a two element list containing
# a list of headers name/values and the content:
#
# [[[header_name header_value header_name header_value ...] content] ... ]
#
#
proc decode_multipart_mime {content boundary} {

	set parts [list]

	# The content could contain binary data, so convert
	# it to a hex string.
	set hex_buffer [bintohex $content]
	set i 0
	set hex_nl ""

	while {1} {
		# Read boundary separator
		if {![_test_and_consume hex_buffer i [bintohex "--${boundary}"]]} {
			error "Expected boundary separator at character position [expr {$i / 2}]"
		}
		# Check if it's the last separator
		if {[_test_and_consume hex_buffer i [bintohex "--"]]} {
			# Not sure all browsers put a newline in after last separator, so
			# we won't throw an error if there isn't one.
			_test_and_consume hex_buffer i $hex_nl
			if {$i != [string length $hex_buffer]} {
				error "Extra characters after final boundary separator at character position [expr {$i / 2}]"
			} else {
				return $parts
			}
		} else {
			if {$hex_nl == ""} {
				# Need to figure out what type of newline we're going to be
				# dealing with the first time we see one.
				if {[_test_and_consume hex_buffer i "0a"]} {
					append hex_nl "0a"
					if {[_test_and_consume hex_buffer i "0d"]} {
						append hex_nl "0d"
					}
				} elseif {[_test_and_consume hex_buffer i "0d"]} {
					append hex_nl "0d"
					if {[_test_and_consume hex_buffer i "0a"]} {
						append hex_nl "0a"
					}
				} else {
					error "Expected newline at character position [expr {$i / 2}]"
				}
				set nl [hextobin $hex_nl]
			} else {
				if {![_test_and_consume hex_buffer i $hex_nl]} {
					error "Expected newline at character position [expr {$i / 2}]"
				}
			}
			# Read MIME headers
			set headers [list]
			while {1} {
				set next_i [string first $hex_nl $hex_buffer $i]
				if {$next_i == -1} {
					error "Expected MIME header followed by newline at character position [expr {$i / 2}]"
				}
				set header_line [hextobin [string range $hex_buffer $i [expr {$next_i - 1}]]]
				set i [expr {$next_i + [string length $hex_nl]}]
				if {$header_line == ""} {
					break
				}
				set colon_pos [string first ":" $header_line]
				if {$colon_pos == -1} {
					error "Invalid MIME header at character position [expr {$i / 2}]"
				}
				lappend headers [string tolower [string range $header_line 0 [expr {$colon_pos - 1}]]]
				lappend headers [string trim [string range $header_line [expr {$colon_pos + 1}] end]]
			}

			# Read data up to next separator
			set next_i [string first [bintohex "${nl}--${boundary}"] $hex_buffer $i]
			if {$next_i == -1} {
				error "No boundary separator found after character position [expr {$i / 2}]"
			} else {
				set data [string range $content [expr {$i / 2}] [expr {$next_i / 2 - 1}]]
				set i [expr {$next_i + [string length $hex_nl]}]
			}
			lappend parts [list $headers $data]
		}
	}
}
