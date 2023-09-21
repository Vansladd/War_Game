#
#

# Single use token implementation, utilising core::security::token
# Wrapper around core::security::token to store an expiry date in tSglUseToken
# upon creation, and validate the expiry date has not passed upon validation.

# Tokens which expire will be left in the DB - to clean these up, a standalone
# cleanup script is provided which can be run as a cron job at:
# generic/scripts/purge_single_use_tokens/purge_single_use_tokens.tcl
#

set pkg_version 1.0
package provide core::security::single_use_token $pkg_version

package require core::security::token 1.0
package require core::check           1.0
package require core::args            1.0
package require core::db              1.0

core::args::register_ns \
	-namespace core::security::single_use_token \
	-version $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::security::token] \
	-docs xml/security/single_use_token.xml

namespace eval core::security {
	namespace eval single_use_token {
		variable INITIALISED
		set INITIALISED 0
	}
}

# Initialise the security single use token framework
core::args::register \
	-proc_name core::security::single_use_token::init \
	-args [list \
		[list -arg -pad_data -mand 0 -check BOOL -default 1 -desc {Add padding to data (unless appserver > 2.19)}] \
	] \
	-body {
		variable INITIALISED

		if {$INITIALISED} {
			return
		}

		core::db::init

		core::security::token::init -pad_data $ARGS(-pad_data)
		_prepare_qrys
		core::log::write INFO {Initialised the security single use token package}

		set INITIALISED 1
	}

# Create a secure single use token
core::args::register \
	-proc_name core::security::single_use_token::create \
	-args [list \
		[list -arg -aes_key  -mand 1 -check HEX    -desc {AES key}] \
		[list -arg -hmac_key -mand 1 -check HEX    -desc {HMAC key}] \
		[list -arg -type     -mand 1 -check STRING -desc {Unique string identifying the purpose of the token e.g. passwordreset}] \
		[list -arg -content  -mand 0 -check ANY                       -default {}  -desc {Data to encrypt}] \
		[list -arg -encoding -mand 0 -check {ENUM -args {BASE64 HEX}} -default HEX -desc {Encoding of token: BASE64 or HEX.}] \
		[list -arg -expiry   -mand 1 -check INT -desc {Expiry time in seconds, from creation of the token.}] \
	] \
	-body {
		set fn {core::security::single_use_token::create}
		set expiry $ARGS(-expiry)

		if {$expiry == "" || $expiry <= 0} {
			core::log::write ERROR {$fn: expiry date cannot be blank}
			error {$fn: expiry date cannot be blank} $::errorInfo ERR_BAD_EXPIRY
		}

		# Insert a row into the DB and get the ID
		if {[catch {
			set rs [core::db::exec_qry \
				-name core::security::single_use_token::insert_token \
				-args [list $expiry] \
			]
		} msg]} {
			core::log::write ERROR {$fn: $msg}
			error {$fn: $msg} $::errorInfo $::errorCode
		}

		set nrows [db_get_nrows $rs]
		if {$nrows != 1} {
			core::db::rs_close -rs $rs
			core::log::write ERROR {$fn: core::security::single_use_token::insert_token returned $nrows rows}
			error {$fn: Error inserting single use token} $::errorInfo ERR_NO_DATA
		}

		set sgl_use_token_id [db_get_coln $rs 0 0]

		core::db::rs_close -rs $rs

		set content "$sgl_use_token_id#$ARGS(-content)"

		# Now return token::create
		set token [core::security::token::create \
			-aes_key  $ARGS(-aes_key) \
			-hmac_key $ARGS(-hmac_key) \
			-type     $ARGS(-type) \
			-content  $content \
			-encoding $ARGS(-encoding) \
		]
		return $token
	}

# Verify, decrypt and remove the single use token
core::args::register \
	-proc_name core::security::single_use_token::verify \
	-args [list \
		[list -arg -aes_key  -mand 1 -check HEX    -desc {AES key}] \
		[list -arg -hmac_key -mand 1 -check HEX    -desc {HMAC key}] \
		[list -arg -type     -mand 1 -check STRING -desc {Unique string identifying the purpose of the token e.g. passwordreset}] \
		[list -arg -token    -mand 0 -check ANY                       -default {} -desc {Token to decrypt}] \
		[list -arg -encoding -mand 0 -check {ENUM -args {BASE64 HEX}} -default HEX -desc {Encoding of token: BASE64 or HEX.}] \
	] \
	-body {
		# verify the token
		set content [core::security::token::verify \
			-aes_key  $ARGS(-aes_key) \
			-hmac_key $ARGS(-hmac_key) \
			-type     $ARGS(-type) \
			-token    $ARGS(-token) \
			-encoding $ARGS(-encoding) \
		]

		# Get the record ID and remove it from the token
		set sgl_use_token_id [lindex [split $content #] 0]
		regsub "^${sgl_use_token_id}#" $content {} content

		# Check the DB to see if the token has been already used or has expired
		if {![_delete_token $sgl_use_token_id]} {
			core::log::write ERROR {Token $sgl_use_token_id has been used or has expired}
			error "Token has been used or has expired" $::errorInfo EXPIRED
		}

		return $content
	}

# Deletes a single use token if it is valid.  if the token has expired it will
# not be deleted, so the calling code knows that it is invalid.
proc core::security::single_use_token::_delete_token {id} {
	if {[catch {
		core::db::exec_qry \
			-name core::security::single_use_token::delete_token \
			-args [list $id]
	} msg]} {
		error "Error executing core::security::single_use_token::delete_token: $msg" \
			$::errorInfo $::errorCode
	}

	set nrows [core::db::garc \
		-name core::security::single_use_token::delete_token \
	]
	return $nrows
}

# Prepare DB queries
proc core::security::single_use_token::_prepare_qrys args {

	core::db::store_qry \
		-name core::security::single_use_token::insert_token \
		-qry {
			execute procedure pInsSglUseToken (
				p_expiry_seconds = ?
			)
		}

	core::db::store_qry \
		-name core::security::single_use_token::delete_token \
		-qry {
			delete from
				tSglUseToken
			where
				token_id = ?
			and expiry_utc > DBINFO('utc_to_datetime', DBINFO('utc_current'))
		}
}
