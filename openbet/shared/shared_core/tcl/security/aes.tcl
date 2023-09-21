#
#

# Wrapper around aes to handle padding

set pkg_version 1.0
package provide core::security::aes $pkg_version

package require core::check  1.0
package require core::args   1.0
package require core::random 1.0

core::args::register_ns \
	-namespace core::security::aes \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::random] \
	-docs      xml/security/aes.xml

namespace eval core::security {
	namespace eval aes {
		variable CFG
		
		set CFG(appserv_pkg_version) -1
		set CFG(pad_data)            0
	}
}

# Initialise the security token framework
core::args::register \
	-proc_name core::security::aes::init \
	-args [list \
		[list -arg -pad_data -mand 0 -check BOOL -default 1 -desc {Add padding to aes data (unless appserver > 2.19)}] \
	] \
	-body {
		variable CFG
		
		set CFG(pad_data) $ARGS(-pad_data)
		
		catch {
			set CFG(appserv_pkg_version) [package present OT_AppServ]
		}
	}

# Encrypt using aes
core::args::register \
	-proc_name core::security::aes::encrypt \
	-args [list \
		[list -arg -hex_key  -mand 1 -check HEX                -desc {AES key}] \
		[list -arg -content  -mand 0 -check ANY    -default {} -desc {Data to encrypt}] \
		[list -arg -iv       -mand 0 -check HEX    -default {} -desc {Ivec}] \
	] \
	-body {
		variable CFG

		set hex_key    $ARGS(-hex_key)
		set content    $ARGS(-content)
		set iv         $ARGS(-iv)
		set key_length [expr {[string bytelength $hex_key] / 2}]

		# Ensure the key is valid
		if {[lsearch {16 24 32} $key_length] == -1} {
			error "HEX key should be either 16, 24 or 32 bytes ($key_length bytes)"
		}

		set content [convertto bin -string $content]

		# Pad data according to
		# PKCS#5, RFC2630, and NIST 800-38A: add 1-16 bytes to the end of
		# the string with a value equal to the number of bytes added
		#
		# Only perform if we are using < v2.19
		if {$CFG(appserv_pkg_version) < 2.19 || $CFG(pad_data)} {
			set pad_length [expr {16 - ([string length $content] % 16)}]
			set pad_string [string repeat [format "%c" $pad_length] $pad_length]
			
			append content $pad_string
		}

		if {$iv != {}} {
			# Encrypt the token with AES 128 CBC
			set encrypted [aes encrypt \
				-mode cbc \
				-hex  $iv \
				-hex  $hex_key \
				-bin  $content]
		} else {
			# Encrypt the token with AES 128 CBC
			set encrypted [aes encrypt \
				-mode cbc \
				-hex  $hex_key \
				-bin  $content]
		}

		return $encrypted
	}

# Decrypt the AES-128 encrypted token
core::args::register \
	-proc_name core::security::aes::decrypt \
	-args [list \
		[list -arg -hex_key  -mand 1 -check HEX              -desc {Hex AES key}] \
		[list -arg -hex_data -mand 0 -check HEX  -default {} -desc {AES encrypted data to decrypt}] \
		[list -arg -iv       -mand 0 -check HEX  -default {} -desc {Ivec}] \
	] \
	-body {
		variable CFG

		set hex_key   $ARGS(-hex_key)
		set hex_data  $ARGS(-hex_data)
		set iv        $ARGS(-iv)
		set content   {}
		set key_length [expr {[string bytelength $hex_key] / 2}]

		# Ensure the key is valid
		if {[lsearch {16 24 32} $key_length] == -1} {
			error "HEX key should be either 16, 24 or 32 bytes ($key_length bytes)"
		}

		if {$iv != {}} {
			# Decrypt AES 128 CBC with Ivec
			set content [aes decrypt \
				-mode cbc \
				-hex  $iv \
				-hex  $hex_key \
				-hex  $hex_data]
		} else {
			# Decrypt AES 128 CBC
			set content [aes decrypt \
				-mode cbc \
				-hex  $hex_key \
				-hex  $hex_data]
		}

		if {$CFG(appserv_pkg_version) < 2.19 || $CFG(pad_data)} {
			# Remove padding
			set padding_length [string range \
				$content \
				[expr {[string length $content] - 2}] \
				[expr {[string length $content] - 1}]]

			scan $padding_length %x decimal_length
			set content [convertto string -hex $content]
			set content [string range \
				$content \
				0 \
				[expr [string length $content] - $decimal_length - 1]]
		} else {
			set content [convertto string -hex $content]
		}

		return $content
	}
