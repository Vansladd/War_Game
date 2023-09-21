set pkg_version 1.0
package provide core::security::gpg::agent $pkg_version

package require core::args  1.0
package require core::check 1.0
package require core::log   1.0

core::args::register_ns                   \
	-namespace core::security::gpg::agent \
	-version   $pkg_version               \
	-dependent [list                      \
		core::check                       \
		core::log                         \
		core::args                        \
	]                                     \
	-docs xml/security/gpg_agent.xml

namespace eval core::security {
	namespace eval gpg::agent {
	}
}

core::args::register \
	-proc_name core::security::gpg::agent::start \
	-args [list \
		[list -arg -homedir -mand        0 \
							-check       ANY \
							-default     "" \
							-default_cfg GPG_HOME_DIRECTORY \
							-desc        {GnuPG config directory}] \
	] \
	-body {

		set fn [lindex [info level 0] 0]

		if { $ARGS(-homedir) ne "" } {
			set agent_args [list --homedir [file normalize $ARGS(-homedir)]]
			core::log::write DEBUG {$fn: agent_args = $agent_args}
		} else {
			set agent_args [list]
		}

		if { [catch {
			exec -ignorestderr -- gpg-agent --daemon \
											--quiet \
											--batch \
											--allow-preset-passphrase \
											{*}$agent_args
		} results options] } {
			core::log::write ERROR {$fn: Failed to start GnuPG agent: $results}
			return -options $options $results
		} else {
			core::log::write DEV {$fn: results = $results}
		}

		regexp {GPG_AGENT_INFO=([^;]+);} $results {} agent_info

		set ::env(GPG_AGENT_INFO) $agent_info

		core::log::write DEBUG {$fn: GPG_AGENT_INFO = $agent_info}

	}

core::args::register \
	-proc_name core::security::gpg::agent::stop \
	-args [list] \
	-body {

		set fn [lindex [info level 0] 0]

		append get_agent_pid            \
			"/subst\n"                  \
			"/serverpid\n"              \
			"/echo \${get serverpid}\n" \
			"/bye\n"

		if { [catch {
			exec -- << $get_agent_pid gpg-connect-agent | xargs kill -TERM
		} results options] } {
			core::log::write ERROR {$fn: Failed to stop GnuPG agent: $results}
			return -options $options $results
		}

		array unset ::env GPG_AGENT_INFO

	}
