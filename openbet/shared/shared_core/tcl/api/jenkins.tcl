#
#
# Copyright (c) 2001, 2002, 2003 Orbis Technology Ltd. All rights reserved.
#

# Handle http requests
set pkg_version 1.0
package provide core::api::jenkins $pkg_version

package require core::log           1.0
package require core::util          1.0
package require core::check         1.0
package require core::args          1.0
package require core::gc            1.0
package require core::xml           1.0
package require tls
package require tdom
package require http

core::args::register_ns \
	-namespace core::api::jenkins \
	-version   $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::xml \
		core::util] \
	-docs xml/api/jenkins.xml

# Available requests
#    copy-job   - Copy a Jenkins Job
#    get-job    - Retrieve the xml config information

namespace eval ::core::api::jenkins {
	variable CFG

	set CFG(ssh_host)    {}
	set CFG(ssh_port)    {}
	set CFG(job_config)  {}
	set CFG(initialised) 0
	set CFG(commands) {
		copy-job
		get-job
	}
}

# Initialise the API
core::args::register \
	-proc_name core::api::jenkins::init \
	-desc {Initialise Jenkins API} \
	-args [list \
		[list -arg -ssh_host   -mand 0 -check STRING -default {ci01.openbet}  -desc {Jenkins Host}] \
		[list -arg -ssh_port   -mand 0 -check INT    -default 52025           -desc {Jenkins SSL server port}] \
		[list -arg -job_config -mand 0 -check STRING -default config.xml      -desc {Jenkins job config file}] \
	] \
	-body {
		variable CFG

		if {$CFG(initialised)} {
			core::log::write INFO {API already Initialised}
			return
		}

		set CFG(ssh_host)   $ARGS(-ssh_host)
		set CFG(ssh_port)   $ARGS(-ssh_port)
		set CFG(job_config) $ARGS(-job_config)

		core::log::write INFO {API Initialised $CFG(ssh_host)@$CFG(ssh_port)}
	}

# Re-configure
core::args::register \
	-proc_name core::api::jenkins::configure \
	-desc {Configure Jenkins API} \
	-args [list \
		[list -arg -name   -mand 1 -check STRING -desc {Configuration name}] \
		[list -arg -value  -mand 1 -check STRING -desc {Configuration value}] \
	] \
	-body {
		variable CFG

		set name  $ARGS(-name)
		set value $ARGS(-value)

		if {![info exists CFG($name)]} {
			error "Unknown Configuration $name" {} UNKNOWN_CONFIG
		}


		set CFG($name) $value
	}

# Make the ssh call
# Copy an existing jenkins job
core::args::register \
	-proc_name core::api::jenkins::_ssh \
	-is_public 0 \
	-args [list \
		[list -arg -command    -mand 1 -check ASCII                         -desc {Jenkins SSH command}] \
		[list -arg -error_code -mand 0 -check STRING -default UNKNOWN_ERROR -desc {Error code}] \
		[list -arg -params     -mand 0 -check ANY    -default {}            -desc {Command arguments}] \
	] \
	-body {
		variable CFG

		set command    $ARGS(-command)
		set error_code $ARGS(-error_code)
		set params     $ARGS(-params)

		core::log::write INFO {Executing $command $params}

		if {[catch {
			set ret [exec ssh -p $CFG(ssh_port) $CFG(ssh_host) $command {*}$params]
		} err]} {
			core::log::write ERROR {$err}
			error $err $::errorInfo $error_code
		}

		return $ret
	}

# Copy an existing jenkins job
core::args::register \
	-proc_name core::api::jenkins::copy-job \
	-desc {Copy an existing jenkins job} \
	-args [list \
		[list -arg -old_job -mand 1 -check STRING -desc {Existing Jenkins job}] \
		[list -arg -new_job -mand 1 -check STRING -desc {New Jenkins job}] \
	] \
	-body {
		_ssh -command copy-job -params [list  $ARGS(-old_job) $ARGS(-new_job)]
	}

# Retrieve a jenkins job config.xml
core::args::register \
	-proc_name core::api::jenkins::get-job \
	-desc {Retrieve an existing jobs config.xml} \
	-args [list \
		[list -arg -job -mand 1 -check STRING -desc {Jenkins job}] \
	] \
	-body {
		return [_ssh -command get-job -params $ARGS(-job)]
	}

# Delete a jenkins job
core::args::register \
	-proc_name core::api::jenkins::delete-job \
	-desc {Remove a job from Jenkins} \
	-args [list \
		[list -arg -job -mand 1 -check STRING -desc {Jenkins job}] \
	] \
	-body {
		_ssh -command delete-job -params $ARGS(-job)
	}

# Enable a jenkins job
core::args::register \
	-proc_name core::api::jenkins::enable-job \
	-desc {Remove a job from Jenkins} \
	-args [list \
		[list -arg -job -mand 1 -check STRING -desc {Jenkins job}] \
	] \
	-body {
		_ssh -command enable-job -params $ARGS(-job)
	}

# Update a jenkins job
core::args::register \
	-proc_name core::api::jenkins::update-job \
	-desc {Update a Jenkins job} \
	-args [list \
		[list -arg -job -mand 1 -check STRING -desc {Jenkins job}] \
		[list -arg -xml -mand 1 -check ANY    -desc {Jenkins config.xml}] \
	] \
	-body {
		variable CFG

		# Write the config to file
		core::util::write_file \
			-file $CFG(job_config) \
			-data $ARGS(-xml)

		_ssh -command update-job -params [list $ARGS(-job) < $CFG(job_config)]
	}

# Update a jenkins job
core::args::register \
	-proc_name core::api::jenkins::build \
	-desc {Run a Jenkins job} \
	-args [list \
		[list -arg -job  -mand 1 -check STRING             -desc {Jenkins job}] \
		[list -arg -args -mand 0 -check ANY    -default {} -desc {Optional args}] \
	] \
	-body {
		_ssh -command build -params [list $ARGS(-job) $ARGS(-args)]
	}