#
#

# Password hashing functionality
#
# Version 0 (versions & 1): operator specific, an implementation for interface core::security::passwd::create_v0_password_hash must be defined to use this
# Version 1 (versions & 2): SHA256(salt16, password) (The salt and the password should just be concatenated together)
# Version 2 (versions & 4): PBKDF2(SHA1, password, salt16, 4096, 32)
# Version 3 (versions & 8): PBKDF2(SHA256, password, salt16, 4096, 32)
#
#
# https://jira.openbet.com/browse/OBCORE-498
# The password procs take a 'versions' parameter where each set bit position indicates that the
# corresponding password hash algorithm needs to be used, starting at the lowest bit and working up,
# where the output of one algorithm is the input to another. E.g. 5 is 00000101, so use algorithms
# 0 and 2, with 0 taking the password and 2 taking the output of 0
#
# SHA-256 is available in OpenSSL as a simple digest from 0.9.8, and is
# supported in the app-server from 1.41
#
# PBKDF2 is available in OpenSSL from 0.9.8 but only the SHA-1 digest was
# supported before 1.0.0; it is available in the app-server from 2.4.49
# and 1.40.31.29 and supports whatever digests are available in the under-
# lying OpenSSL installation.
#

set pkg_version 1.0
package provide core::security::passwd $pkg_version

package require core::check  1.0
package require core::args   1.0
package require core::random 1.0
package require tls

core::args::register_ns \
	-namespace core::security::passwd \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args core::random] \
	-docs      xml/security/passwd.xml

namespace eval core::security {
	namespace eval passwd {
		variable CFG
	}
}

# Initialise the security passwd framework
core::args::register \
	-proc_name core::security::passwd::init \
	-args [list \
		[list -arg -salt_enc_key      -mand 0 -check STRING -default_cfg PWD_SALT_ENC_KEY -default {}    -desc {Salt encryption key}] \
		[list -arg -block_cipher_mode -mand 0 -check {ENUM -args {ecb cbc}}     -default_cfg PWD_BLOCK_CIPHER_MODE       -default {ecb} -desc {Block cipher mode of operation: Caution must be taken if changing}] \
		[list -arg -openssl_version   -mand 0 -check STRING -default_cfg OPENSSL_VERSION  -default {}    -desc {OpenSSL Version}] \
		[list -arg -check_padding  -mand 0 -check BOOL -default_cfg AES_CHECK_PADDING  -default 1    -desc {whether to check the aes command in the appserver to see whether it has PKCS#5 padding by default}] \
	] \
	-body {
		variable CFG

		set CFG(openssl_version)   -1
		set CFG(block_cipher_mode) $ARGS(-block_cipher_mode)

		# Establish the openssl version
		if {$ARGS(-openssl_version) eq ""} {
			regexp {^OpenSSL\s+([\d\.]+)} [::tls::version] all CFG(openssl_version)
		} else {
			set CFG(openssl_version) $ARGS(-openssl_version)
		}

		set CFG(salt_enc_key)           $ARGS(-salt_enc_key)
		set CFG(SHA256_enabled)         [expr {[lsearch [info commands] dgst]  > -1}]
		set CFG(pbkdf2_SHA1_enabled)    [expr {[lsearch [info commands] pbkdf2] > -1} ]
		set CFG(pbkdf2_SHA256_enabled)  \
			[expr {[lsearch [info commands] pbkdf2]  > -1 && $CFG(openssl_version) > 1}]
		set CFG(pbkdf2_iterations)      4096
		set CFG(pbkdf2_key_length)      32

		# This is a dummy key generated to verify if the aes appserv command has PKCS#5 padding by default
		set aes_dummy_key [aes encrypt -mode $ARGS(-block_cipher_mode) \
			-hex  00000000000000000000000000000000 \
			-hex  00000000000000000000000000000000]
		set no_padding {}

		if {[string length $aes_dummy_key] == 64 && $ARGS(-check_padding) == 1} {
			set no_padding "-nopad"
		}

		set CFG(aes_nopad) $no_padding

		core::log::write INFO {Initalised the security passwd package using $CFG(block_cipher_mode) openssl $CFG(openssl_version), [string length $aes_dummy_key], $ARGS(-check_padding), $no_padding}
	}

# Interface for procedure to create version 0 password hash
core::args::register \
	-interface core::security::passwd::create_v0_password_hash \
	-desc {Create the operator specific version 0 password hash} \
	-returns HEX \
	-args [list \
		[list -arg -password -mand 1 -check ASCII -desc {The plaintext password to be hashed}] \
		[list -arg -salt     -mand 0 -check HEX   -desc {The salt used to create the password hash}] \
	]

# Create a password hash.
# Versions 2 & 3 rely on pdkdf2 which is available in appserver 2.23.1 and above
# pbkdf2 ?-hmac md5|ripemd160|sha1|sha256|sha512? ?-bin|-utf8? pass -bin|-hex|-b64 salt nr-iters key-len.
# dgst -digest sha1|md5|ripemd160|sha256|sha512 -bin|-utf8|-string data
core::args::register \
	-proc_name core::security::passwd::create_password_hash \
	-args [list \
		[list -arg -versions -mand 1 -check UINT -desc {Bitfield indicating which hashing algorithms to use}] \
		[list -arg -password -mand 1 -check ANY  -desc {Plaintext password to hash}] \
	] \
	-body {
		return [_create_password_hash \
			$ARGS(-versions)  \
			$ARGS(-password) \
			[core::random::get_rand_hex -num_bytes 16]]
	}

# Re-create a password hash given a fix salt.
# This should never be used for creating the initial hash or for
# verifying a password instead should be used create_password_hash or verify_password_hash respectively.
# This recreate_password_hash proc is mostly intended to be used for generating classic OB encrypted authentication
# tokens that have to contain the password hash for compatibility.
core::args::register \
	-proc_name core::security::passwd::recreate_password_hash \
	-args [list \
		[list -arg -versions -mand 1 -check UINT -desc {Bitfield indicating which hashing algorithms to use}] \
		[list -arg -password -mand 1 -check ANY  -desc {Plaintext password to hash}] \
		[list -arg -enc_salt -mand 1 -check HEX  -desc {The encrypted salt used to create the password hash}] \
	] \
	-body {

		variable CFG

		set enc_salt       $ARGS(-enc_salt)

		# The salt passed in needs to be AES128� decrypted using CFG(block_cipher_mode)
		# before being used to generate the password hash.
		set salt [aes decrypt \
			{*}$CFG(aes_nopad) \
			-mode $CFG(block_cipher_mode) \
			-hex  $CFG(salt_enc_key) \
			-hex  $enc_salt]

		return [_create_password_hash \
			$ARGS(-versions) \
			$ARGS(-password) \
			$salt]
	}

# Private procedure to create password
proc core::security::passwd::_create_password_hash {versions password salt} {
		variable CFG

		core::log::write INFO {Create password hash, versions=$versions}

		# Create AES128� encrypted salt using CFG(block_cipher_mode)
		set enc_salt [aes encrypt \
			{*}$CFG(aes_nopad) \
			-mode $CFG(block_cipher_mode) \
			-hex  $CFG(salt_enc_key) \
			-hex  $salt]

		if {$versions == 0} {
			error "versions must be non-zero" {} INVALID_VERSIONS
		}

		set versions_mask $versions

		# The versions parameter is a bitfield where each bit represents the hashing algorithm
		# with the same number of the position of the bit. For example, if versions = 11 which
		# in binary is 00001011, then we want to apply hash versions 0, 1, and 3. The algorithms
		# are applied sequentially in ascending order with the first one taking the plaintext
		# password as input, and each successive algorithm taking the hash output from the previous
		# one. The following loop iterates over every hash version, checks the value of
		# the least significant bit in versions_mask to decide whether or not to apply the hash, and
		# finally does a bitwise shift-right on versions_mask.
		for {set version_counter 0} {$version_counter < 4} {incr version_counter} {
			if {$versions_mask & 1} {
				core::log::write INFO {Applying v$version_counter hash}
				switch -- $version_counter {
					0 {
						# Version 0 hash method is operator specific
						set password [create_v0_password_hash \
							-password $password \
							-salt $salt]
					}
					1 {
						# Version 1 hash = SHA256(salt16, password)
						if {!$CFG(SHA256_enabled)} {
							error "sha256 is not available" {} UNSUPPORTED_HASH
						}
						set password [dgst -digest sha256 -bin "${salt}$password"]
					}
					2 {
						# Version 2 hash = PBKDF2(SHA1, password, salt16, 4096, 32)
						set password [_pbkdf2 \
							-hmac    sha1 \
							-bin     $password \
							-salt    $salt]
					}
					3 {
						# Version 3 hash = PBKDF2(SHA256, password, salt16, 4096, 32)
						set password [_pbkdf2 \
							-hmac    sha256 \
							-bin     $password \
							-salt    $salt]
					}
				}
			}
			set versions_mask [expr {$versions_mask >> 1}]
		}

		# if versions_mask is not zero by this point then something is wrong
		if {$versions_mask != 0} {
			error "invalid versions value" {} INVALID_VERSIONS
		}

		set password_hash $password

		core::log::write INFO {Created v$versions hash $password_hash with salt (enc) $enc_salt}

		return [dict create \
			-versions      $versions \
			-salt          $enc_salt \
			-password_hash $password_hash]
	}

# Verify a password against a hash
# @return 0 = the password did not verify, 1 = the password verifies
core::args::register \
	-proc_name core::security::passwd::verify_password_hash \
	-args [list \
		[list -arg -versions      -mand 1 -check UINT  -desc {Bitfield specifying which hashing algorithms to use}] \
		[list -arg -enc_salt      -mand 1 -check HEX   -desc {The encrypted salt used to create the password hash}] \
		[list -arg -password_hash -mand 1 -check ANY   -desc {The password hash}] \
		[list -arg -password      -mand 1 -check ANY   -desc {The password to compare against the password hash}] \
	] \
	-body {
		variable CFG

		set versions       $ARGS(-versions)
		set enc_salt       $ARGS(-enc_salt)
		set password_hash  $ARGS(-password_hash)
		set password       $ARGS(-password)

		core::log::write INFO {Verify password hash, versions=$versions}

		# The salt passed in needs to be AES128� decrypted using CFG(block_cipher_mode)
		# before being used to generate the password hash.
		set salt [aes decrypt \
			{*}$CFG(aes_nopad) \
			-mode $CFG(block_cipher_mode) \
			-hex  $CFG(salt_enc_key) \
			-hex  $enc_salt]

		set hash_dict [_create_password_hash \
			$versions \
			$password \
			$salt]

		# Compare the hashes
		if {$password_hash != [dict get $hash_dict -password_hash]} {
			return 0
		}

		# The hashes match
		return 1
	}

# PBKDF2 (Password-Based Key Derivation Function 2)
# http://en.wikipedia.org/wiki/PBKDF2
#
# @param -hmac HMAC type to use
# @param -bin Binary data to hash
# @param -salt Salt
core::args::register \
	-proc_name core::security::passwd::_pbkdf2 \
	-args [list \
		[list -arg -hmac     -mand 1 -check ANY -desc {HMAC type to use}] \
		[list -arg -bin      -mand 1 -check ANY -desc {Binary data to hash}] \
		[list -arg -salt     -mand 1 -check HEX -desc {The salt used to create the password hash}] \
	] \
	-body {
		variable CFG

		switch -- $ARGS(-hmac) {
			sha1 {
				# Use pbkdf2 SHA1
				if {!$CFG(pbkdf2_SHA1_enabled)} {
					error "pbkdf2 SHA1 is not available" {} UNSUPPORTED_HASH
				}
			}
			sha256 {
				# Check pbkdf2 SHA256 is available
				if {!$CFG(pbkdf2_SHA256_enabled)} {
					error "pbkdf2 SHA56 is not available" {} UNSUPPORTED_HASH
				}
			}
			default {
				error "unsupported hmac: $ARGS(-hmac)" {} UNSUPPORTED_HASH
			}
		}

		core::log::write DEBUG {pbkdf2 -hmac $ARGS(-hmac) -bin $ARGS(-bin) -hex  $ARGS(-salt) $CFG(pbkdf2_iterations) $CFG(pbkdf2_key_length)}

		return [pbkdf2 \
			-hmac $ARGS(-hmac) \
			-bin  $ARGS(-bin) \
			-hex  $ARGS(-salt) \
			$CFG(pbkdf2_iterations) \
			$CFG(pbkdf2_key_length)]
	}
