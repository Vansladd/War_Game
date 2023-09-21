set pkg_version 1.0
package provide core::security::gpg::simple $pkg_version

package require core::args  1.0
package require core::check 1.0
package require core::log   1.0

core::args::register_ns                    \
	-namespace core::security::gpg::simple \
	-version   $pkg_version                \
	-dependent [list                       \
		core::check                        \
		core::log                          \
		core::args                         \
	]                                      \
	-docs xml/security/gpg_simple.xml

namespace eval core::security {

	namespace eval gpg::simple {

		variable  CFG
		array set CFG [list init 0]

		variable  CACHE
		array set CACHE [list]

	}

}

core::args::register \
	-proc_name core::security::gpg::simple::init \
	-args [list \
		[list -arg -use_agent   -mand        0                            \
								-check       BOOL                         \
								-default     1                            \
								-desc        {GnuPG agent required}]      \
		[list -arg -homedir     -mand        0                            \
								-check       ANY                          \
								-desc        {GnuPG config directory}]    \
		[list -arg -libexecdir  -mand        0                            \
								-check       ANY                          \
								-desc        {GnuPG libexec directory}]   \
		[list -arg -cache_ttl   -mand        0                            \
								-check       INT                          \
								-default     3600                         \
								-default_cfg GPG_AGENT_CACHE_TTL          \
								-desc        {Number of seconds gpg-agent \
											  should cache passphrases}]  \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		variable CFG

		if { !$CFG(init) } {

			if { $ARGS(-homedir) ne "" } {
				global env
				set env(GNUPGHOME) [file normalize $ARGS(-homedir)]
				core::log::write DEBUG {$fn: GNUPGHOME = $env(GNUPGHOME)}
			}

			if { $ARGS(-libexecdir) eq "" } {
				set prefix [file dirname [file dirname [auto_execok gpg]]]
				set ARGS(-libexecdir) [file join $prefix libexec]
			}

			core::log::write_array DEV ARGS

			set CFG(use_agent) $ARGS(-use_agent)
			set CFG(cache_ttl) $ARGS(-cache_ttl)

			global env

			if { $CFG(use_agent) } {

				if { ![info exists env(GPG_AGENT_INFO)] } {

					package require core::security::gpg::agent
					core::security::gpg::agent::start

				}

				set CFG(gpg_preset_passphrase) \
					[file join $ARGS(-libexecdir) gpg-preset-passphrase]

			} else {

				if { ![info exists env(GPG_AGENT_INFO)] } {
					set env(GPG_AGENT_INFO) /dev/null
				}

			}

			core::log::write_array DEV CFG

			package require gpg

			set CFG(ctx) [gpg::new]

			$CFG(ctx) set -property encoding -value binary

			set CFG(init) 1

			core::log::write INFO {$fn: Initalized the simple GnuPG package}

		}

	}

core::args::register \
	-proc_name core::security::gpg::simple::sign \
	-args [list \
		[list -arg -keyid       -mand    1                    \
								-check   ASCII                \
								-desc    {Signing key ID}]    \
		[list -arg -passphrase  -mand    0                    \
								-check   ANY                  \
								-desc    {Passphrase}]        \
		[list -arg -data        -mand    1                    \
								-check   ANY                  \
								-desc    {Data to be signed}] \
		[list -arg -encoding    -mand    0                    \
								-check   ASCII                \
								-default binary               \
								-desc    {Data encoding}]     \
		[list -arg -mode        -mand    0                    \
								-check   ASCII                \
								-default normal               \
								-desc    {Signing mode}]      \
		[list -arg -armor       -mand    0                    \
								-check   BOOL                 \
								-default 1                    \
								-desc    {ASCII armour}]      \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		variable CFG

		set keyid      $ARGS(-keyid)
		set passphrase $ARGS(-passphrase)
		set data       $ARGS(-data)
		set mode       $ARGS(-mode)
		set armor      $ARGS(-armor)
		set encoding   $ARGS(-encoding)

		$CFG(ctx) set -property armor    -value $armor
		$CFG(ctx) set -property encoding -value $encoding

		set cmd [list $CFG(ctx) sign -input $data -mode $mode]

		if { "-passphrase" in $args } {
			_eval_cmd $cmd $keyid 1 $passphrase
		} else {
			_eval_cmd $cmd $keyid 1
		}

	}

core::args::register \
	-proc_name core::security::gpg::simple::verify \
	-args [list \
		[list -arg -signature -mand    1                \
							  -check   ANY              \
							  -desc    {Signature}]     \
		[list -arg -data      -mand    0                \
							  -check   ANY              \
							  -desc    {Signed data}]   \
		[list -arg -encoding  -mand    0                \
							  -check   ASCII            \
							  -default binary           \
							  -desc    {Data encoding}] \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		variable CFG

		set vrfy_args [list -signature $ARGS(-signature)]

		if { "-data" in $args } {
			lappend vrfy_args -input $ARGS(-data)
		}

		core::log::write DEV {$fn: $CFG(ctx) verify $vrfy_args}

		$CFG(ctx) set -property encoding -value $ARGS(-encoding)

		return [$CFG(ctx) verify {*}$vrfy_args]

	}

core::args::register \
	-proc_name core::security::gpg::simple::encrypt \
	-args [list \
		[list -arg -recipients  -mand    1                       \
								-check   LIST                    \
								-desc    {Recipient key ID's}]   \
		[list -arg -data        -mand    1                       \
								-check   ANY                     \
								-desc    {Data to be encrypted}] \
		[list -arg -encoding    -mand    0                       \
								-check   ASCII                   \
								-default binary                  \
								-desc    {Data encoding}]        \
		[list -arg -signer      -mand    0                       \
								-check   ASCII                   \
								-desc    {Signing key ID}]       \
		[list -arg -passphrase  -mand    0                       \
								-check   ANY                     \
								-desc    {Passphrase}]           \
		[list -arg -armor       -mand    0                       \
								-check   BOOL                    \
								-default 1                       \
								-desc    {ASCII armour}]         \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		variable CFG

		set recipients $ARGS(-recipients)
		set data       $ARGS(-data)
		set armor      $ARGS(-armor)
		set encoding   $ARGS(-encoding)

		set signer     $ARGS(-signer)
		set passphrase $ARGS(-passphrase)

		set recip [gpg::recipient]

		foreach recipient $recipients {

			lassign $recipient name validity

			core::log::write DEV {$fn: name = $name, validity = $validity}

			if { $validity ne "" } {
				$recip add -name $name -validity $validity
			} else {
				$recip add -name $name
			}

		}

		$CFG(ctx) set -property armor    -value $armor
		$CFG(ctx) set -property encoding -value $encoding

		set cmd [list $CFG(ctx) encrypt -input $data -recipients $recip]

		if { $signer ne "" } {

			lappend cmd -sign 1

			if { "-passphrase" in $args } {
				_eval_cmd $cmd $signer 1 $passphrase
			} else {
				_eval_cmd $cmd $signer 1
			}

		} else {
			{*}$cmd
		}

	}

core::args::register \
	-proc_name core::security::gpg::simple::decrypt \
	-args [list \
		[list -arg -keyid       -mand    1                       \
								-check   ASCII                   \
								-desc    {Decryption key ID}]    \
		[list -arg -passphrase  -mand    0                       \
								-check   ANY                     \
								-desc    {Passphrase}]           \
		[list -arg -data        -mand    1                       \
								-check   ANY                     \
								-desc    {Data to be decrypted}] \
		[list -arg -encoding    -mand    0                       \
								-check   ASCII                   \
								-default binary                  \
								-desc    {Data encoding}]        \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		variable CFG

		set keyid      $ARGS(-keyid)
		set passphrase $ARGS(-passphrase)
		set data       $ARGS(-data)
		set encoding   $ARGS(-encoding)

		$CFG(ctx) set -property encoding -value $encoding

		set cmd [list $CFG(ctx) decrypt -input $data -checkstatus true]

		if { "-passphrase" in $args } {
			_eval_cmd $cmd $keyid 0 $passphrase
		} else {
			_eval_cmd $cmd $keyid 0
		}

	}

proc core::security::gpg::simple::_load_keys { secretonly args } {

	set fn [lindex [info level 0] 0]

	variable CFG

	set fingerprints [$CFG(ctx) list-keys -patterns   $args \
										  -secretonly $secretonly]

	set keys [list]

	foreach fp $fingerprints {

		set key [$CFG(ctx) info-key -key $fp]

		core::log::write DEV {$fn: key-info = $key}

		lappend keys $key

	}

	return $keys

}

proc core::security::gpg::simple::_eval_cmd { cmd keyid sign args } {

	set fn [lindex [info level 0] 0]

	variable CFG

	core::log::write DEV {$fn: cmd = $cmd}

	array set key_info [lindex [_load_keys 1 $keyid] 0]

	if { [llength $args] > 0 } {
		_store_passphrase key_info [lindex $args 0]
	}

	if { $sign } {
		$CFG(ctx) set -property signers -value [list $key_info(fingerprint)]
	}

	catch { {*}$cmd } results options

	if { $sign } {
		$CFG(ctx) set -property signers -value [list]
	}

	if { [llength $args] > 0 } {
		_clear_passphrase
	}

	return -options $options $results

}

proc core::security::gpg::simple::_store_passphrase { key_var passphrase } {

	set fn [lindex [info level 0] 0]

	variable CFG

	if { $CFG(use_agent) } {

		upvar $key_var key_info

		_cache_passphrase $key_info(fingerprint) $passphrase

		if { [info exists key_info(subkeys)] } {

			foreach subkey_list $key_info(subkeys) {

			  array set subkey $subkey_list

			  _cache_passphrase $subkey(fingerprint) $passphrase

			}

		}

	}

	core::log::write DEV {$fn: setting passphrase call-back\
		to "[list [namespace current]::_return_passphrase ********]"}

	$CFG(ctx) set -property passphrase-callback -value \
		[list [namespace current]::_return_passphrase $passphrase]

}

proc core::security::gpg::simple::_cache_passphrase { fingerprint passphrase } {

	set fn [lindex [info level 0] 0]

	variable CFG
	variable CACHE

	set now [clock seconds]

	if { ![info exists CACHE($fingerprint)] || $CACHE($fingerprint) < $now } {

		core::log::write DEV {$fn: caching $fingerprint}

		if { [catch {
			exec -- $CFG(gpg_preset_passphrase) \
						--preset \
						--passphrase $passphrase \
						$fingerprint
		} results options] } {
			core::log::write ERROR {$fn: Failed to store passphrase: $results}
			return -options $options $results
		} else {
			set CACHE($fingerprint) [expr { $now + $CFG(cache_ttl) }]
		}

	} else {
		core::log::write DEBUG \
			{$fn: $fingerprint cached till $CACHE($fingerprint)}
	}

}

proc core::security::gpg::simple::_return_passphrase { passphrase args } {

	return $passphrase

}

proc core::security::gpg::simple::_clear_passphrase {} {

	variable CFG

	$CFG(ctx) set -property passphrase-callback -value [list]

}
