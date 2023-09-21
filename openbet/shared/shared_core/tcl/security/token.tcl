#
#

# Example usage...
#

set pkg_version 1.0
package provide core::security::token $pkg_version

package require core::security::aes 1.0
package require core::check         1.0
package require core::args          1.0
package require core::random        1.0

core::args::register_ns \
	-namespace core::security::token \
	-version   $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::random \
		core::security::aes] \
	-docs xml/security/token.xml

namespace eval core::security {
	namespace eval token {
		variable CFG
	}
}

# Initialise the security token framework
core::args::register \
	-proc_name core::security::token::init \
	-args [list \
		[list -arg -pad_data -mand 0 -check BOOL -default 1 -desc {Add padding to data (unless appserver > 2.19)}] \
	] \
	-body {
		core::security::aes::init -pad_data $ARGS(-pad_data)
		
		core::log::write INFO {Initalised the security token package}
	}

# Create a secure token
core::args::register \
	-proc_name core::security::token::create \
	-args [list \
		[list -arg -aes_key  -mand 1 -check HEX    -desc {AES key}] \
		[list -arg -hmac_key -mand 1 -check HEX    -desc {HMAC key}] \
		[list -arg -type     -mand 1 -check STRING -desc {Unique string identifying the purpose of the token e.g. passwordreset}] \
		[list -arg -content  -mand 0 -check ANY                       -default {}  -desc {Data to encrypt}] \
		[list -arg -encoding -mand 0 -check {ENUM -args {BASE64 HEX}} -default HEX -desc {Encoding of token: BASE64 or HEX.}] \
	] \
	-body {
		variable CFG
		
		set aes_key  $ARGS(-aes_key)
		set hmac_key $ARGS(-hmac_key)
		set content  $ARGS(-content)
		set type     $ARGS(-type)
		
		# Check the keys are not the same
		if {$aes_key == $hmac_key} {
			core::log::write ERROR {AES key cannot be the same as the HMAC key}
			error "AES key cannot be the same as the HMAC key"
		}
		
		if {[string bytelength $hmac_key] < 32} {
			core::log::write ERROR {HMAC key should be greater than 16 bytes of hex}
			error "HMAC key should be greater than 16 bytes of hex"
		}
		
		# Strip the pipe symbol out of the type string so that we can use it as a separator
		regsub -all {\|} $type {} type
		
		# Prepend content with identifier
		set content "$type|$content"
		
		# Generate random IV
		set iv [core::random::get_rand_hex -num_bytes 16]
		
		set content [convertto bin -string $content]
		
		# Encrypt the token with AES 128 CBC
		set token [core::security::aes::encrypt \
			-iv      $iv \
			-hex_key $aes_key \
			-content $content]

		# Prepend token with IV
		set token "${iv}${token}"
		
		# preprend token with SHA1 HMAC
		set hmac  [hmac \
			-hash   sha1 \
			-string $hmac_key \
			-string $token]

		# prepend version of the token and the HMAC
		set token "01${hmac}${token}"

		if {$ARGS(-encoding) == {BASE64}} {
			set token [convertto b64 -hex $token]
		}

		return $token
	}

# Verify and decrypt the AES-128 encrypted token
core::args::register \
	-proc_name core::security::token::verify \
	-args [list \
		[list -arg -aes_key  -mand 1 -check HEX    -desc {AES key}] \
		[list -arg -hmac_key -mand 1 -check HEX    -desc {HMAC key}] \
		[list -arg -type     -mand 1 -check STRING -desc {Unique string identifying the purpose of the token e.g. passwordreset}] \
		[list -arg -token    -mand 0 -check ANY                       -default {} -desc {Token to decrypt}] \
		[list -arg -encoding -mand 0 -check {ENUM -args {BASE64 HEX}} -default HEX -desc {Encoding of token: BASE64 or HEX.}] \
	] \
	-body {
		variable CFG
		
		set aes_key  $ARGS(-aes_key)
		set hmac_key $ARGS(-hmac_key)
		set token    $ARGS(-token)
		set type     $ARGS(-type)
		set content  {}

		if {$ARGS(-encoding) == {BASE64}} {
			set token [convertto hex -b64 $token]
		}

		# Get token version
		set version [string range $token 0 1]
		
		switch -- $version {
			{01} {
				set hmac    [string range $token 2 41]
				set iv      [string range $token 42 73]
				set aes_enc [string range $token 74 end]
			
				core::log::write DEBUG {Token decomposed in $hmac | $iv | $aes_enc}

				# check HMAC
				set hmac_check [hmac \
					-hash    sha1 \
					-string  $hmac_key \
					-string "${iv}${aes_enc}"]

				if {$hmac_check != $hmac} {
					core::log::write ERROR {ERROR: HMAC failed check}
					error "HMAC failed check"
				}
				
				# Decrypt AES 128 CBC
				set content [core::security::aes::decrypt \
					-iv       $iv \
					-hex_key  $aes_key \
					-hex_data $aes_enc]
					
				# Strip the pipe symbol out of the type string so that we can use it as a separator
				regsub -all {\|} $type {} type
				
				# Check token type
				set token_type [lindex [split $content |] 0]
				if {$token_type != $type} {
					core::log::write ERROR {ERROR: Token type mismatch Expecting token of type $type. Encrypted token contents was $aes_enc}
					error "Token type mismatch"
				}
				
				# Remove the identifier. We should return in the data in the same
				# format as it was created with core::security::encrypt
				regsub "^${token_type}\\|" $content {} content

				# Reverse the string->binary conversion that was done before encryption
				set content [convertto string -bin $content]
			}
			default {
				core::log::write ERROR {ERROR: Version $version unsupported}
				error "Version $version unsupported"
			}
		}
		
		return $content
	}
