# (C) 2015 OpenBet Technology Ltd. All rights reserved.
#
# Universally Unique ID package
#
# Configuration:
#
# Synopsis:
#     package require core::uuid ?1.0?
#
set pkg_version 1.0
package provide core::uuid $pkg_version

# Dependencies
package require core::check      1.0
package require core::args       1.0
package require core::random     1.0

core::args::register_ns \
	-namespace core::uuid \
	-version   $pkg_version \
	-dependent [list core::check core::args] \
	-docs      util/uuid.xml

namespace eval core::uuid {}

	core::args::register \
	-proc_name core::uuid::v4 \
	-desc "Generates and returns a unique ID following the RFC 4122 version 4 UUID standard." \
	-body {

		#   Get 128 bit = 8 octets from core::random
		set rand_hex [core::random::get_rand_hex -num_bytes 16]
		set uuid [_gen_uuid_v4_from_rand $rand_hex]
		return $uuid

	}


#  Converts a 128 bit random hex string into a v4 UUID
proc _gen_uuid_v4_from_rand {rand_hex} {

	# Version 4 UUIDs have the form xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx where x is any hexadecimal digit and y is one of 8, 9, A, or B (e.g., f47ac10b-58cc-4372-a567-0e02b2c3d479).
	# 
	#  a) The first 4 bits of the 7th octet should be 0100 (i.e. hex is  0x4x )
	#  b) The two most significant bits of the 9th octe should be 10 (i.e., the hex will always be 8, 9, A, or B)

	#  0          1            2         3
	#  01234567 8901 2345 6789 012345678901
	#  xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

	set uuid {}
	append uuid [string range $rand_hex 0 7]
	append uuid {-}
	append uuid [string range $rand_hex 8 11]
	#  The first 4 bits of the 7th octet should be 0100 (i.e. hex is  0x4x )
	append uuid {-4}
	append uuid [string range $rand_hex 13 15]
	append uuid {-}
	#  The two most significant bits of the 9th octet (index 8) should be 10 
	#  i.e., the hex will always be 8, 9, A, or B
	#  Do this by:
	#  a) Bitwise AND with 1011 1111 = 0xbf, to set 0 in 10
	#  b) Bitwise OR  with 1000 0000 = 0x80  to set the 1 in 10
	set octet_8 "0x[string range $rand_hex 16 17]"
	append uuid [format {%x} [expr {$octet_8&0xbf|0x80}]]
	append uuid [string range $rand_hex 18 19]
	append uuid {-}
	append uuid [string range $rand_hex 20 32]

	return $uuid


}