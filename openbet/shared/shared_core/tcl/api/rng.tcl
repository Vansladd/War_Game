# $Id$
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Random number generator client
#
# Synopsis:
#    package require rng_client 4.5
#
# Procedures:
#    core::api::rng::init         one time init
#    core::api::rng::next_init    get the next random number
#
#

set pkg_version 1.0
package provide core::api::rng $pkg_version
#
# Dependencies
package require core::log      1.0
package require core::args     1.0
package require core::socket   1.0

# Variables
#
namespace eval core::api::rng {

	variable read_ended
	variable CFG
	set INIT 0
}
core::args::register_ns \
	-namespace core::api::rng \
	-version   $pkg_version \
	-desc {
API for calling an instance of an Openbet RNG Server.

To mitigate the effect of latency talking to the RNG, this will
cache a pool of random numbers from the RNG Server, and service requests from this cache,
replenished as necessary from the RNG server

Several servers can be specified - the API will load balance the servers and failover if some aren't available.

Usage:

1. Initialise once using core::api::rng::init, which initalises the hosts and pool size.
2. Obtain random numbers using  core::api::rng::next_int. This will get random numberd from the pool, and replenish if necessary by calling the RNG.

} -dependent [list \
		core::log \
		core::args \
		core::check \
		core::socket] \
	-docs xml/api/rng.xml

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

#
core::args::register \
	-proc_name core::api::rng::init \
	-desc {
	Initialisers the API.

	Several RNG servers can be specified - the API will randomly load balance amongst the servers.
	A connection error will result in a new server being attempted.

	} -args [list \
			[list -arg -hosts         -mand 0 -check STRING     -default_cfg CORE.API.RNG.HOSTS           -default {}          -desc {List of RNG hosts, of form "host1:port host2:port"}] \
			[list -arg -timeout       -mand 0 -check UINT       -default_cfg CORE.API.RNG.TIMEOUT         -default {30000}     -desc {Timeout in ms, for connection (unless overridden), and reading numbers}] \
			[list -arg -conn_timeout  -mand 0 -check INT        -default_cfg CORE.API.RNG.CONN_TIMEOUT    -default {-1}        -desc {Timeout in ms, for connection, if not specified defaults to the value of -timeout}] \
			[list -arg -type          -mand 0 -check STRING		-default_cfg CORE.API.RNG.TYPE            -default {}          -desc {RNG type, eg RNG_DevRandom}] \
			[list -arg -pool_size     -mand 0 -check UINT 		-default_cfg CORE.API.RNG.POOL_SIZE       -default {100}       -desc {Size of random number pool}] \
	] \
	-body {
		set fn {core::api::rng::init}
		variable CFG
		variable INIT
		if {$INIT} {
			core::log::write DEV {$fn: Already initialised}
			return
		}
		core::log::write INFO {RNG: Init}
		set timeout               $ARGS(-timeout)
		set conn_timeout          $ARGS(-conn_timeout)

		#  If no connection_timeout is given then it defaults to -1
		#  Therefore use the timeout value instead.
		if {$conn_timeout < 0} {
			set conn_timeout $timeout
		}

		set CFG(req_timeout)      $timeout
		set CFG(conn_timeout)     $conn_timeout
		set CFG(type)             $ARGS(-type)
		set CFG(pool_size)        $ARGS(-pool_size)

		set lhost [list]
		foreach l  $ARGS(-hosts) {
			if {[regexp -- {([a-z0-9\.\-]+):([0-9]+)} $l --> host port]} {
				lappend lhost [list $host $port]
			} else {
				error "$fn: Invalid hosts spec $l"
			}
		}
		set CFG(lhost) $lhost

		foreach n [lsort [array names CFG]] {
			core::log::write INFO {$fn: CFG $n: $CFG($n)}
		}

		if {$CFG(type) == ""} {
			error "$fn: RNG Type -type must be specified"
		}

		set INIT 1
	}


core::args::register \
	-proc_name core::api::rng::next_int \
	-desc {
	Fetch the next random number from the RNG pool which must map into the
	specified lower and upper bounds.

	To mitigate network latencym this will request a pool of random numbers from If required will call the RNG to re-new the RNG pool

	} \
	-args [list \
			[list -arg -lower      -mand 1 -check INT        -desc {Inclusive lower bound on random number}] \
			[list -arg -upper      -mand 1 -check INT        -desc {Inclusive upper bound on random number, must be > the value in -low }] \
	] -returns {
		A random integer between -lower and -upper inclusive, uniformly distributed.
		Throws exception in case of error, including invalid input data
	} -body {
		variable CFG
		set fn {core::api::rng::next_int}
		set lower $ARGS(-lower)
		set upper $ARGS(-upper)

		set lower [expr wide($lower)]
		set upper [expr wide($upper)]

		if {[expr {$upper - $lower}] < 1} {
			error "$fn: Upper end of range ($upper) must be greater than lower end ($lower)"
		}

		set rangesize [expr {$upper - $lower + 1}]

		if {$rangesize <= 256} {
			set bytes 1
			set diff 256
		} elseif {$rangesize <= 65536} {
			set bytes 2
			set diff 65536
		} elseif {$rangesize <= 16777216} {
			set bytes 3
			set diff 16777216
		} elseif {$rangesize <= [expr {wide(4294967296)}]} {
			set bytes 4
			set diff [expr {wide(4294967296)}]
		} else {
			# Range cannot be greater than 4294967296 in size, or scaling
			# will no longer work.
			error "$fn: Range cannot be greater than 4294967296, range = $rangesize"
		}

		#
		# We have to discard the random number if it's greater than or
		# equal to diff - (diff % rangesize)
		#
		set do 1
		while {$do} {
			set rnd [_get_multibyte_int $bytes]

			if {$rnd < $diff - ($diff % $rangesize)} {
					set do 0
			}
		}

		return [expr {($rnd % $rangesize) + $lower}]
	}


#--------------------------------------------------------------------------
# RNG  Private procs
#--------------------------------------------------------------------------


# Private procedure to populate the RNG pool
#
proc core::api::rng::_populate_rng_pool {} {

	variable CFG
	variable POOL
	variable POINTER

	if {[info exists POOL]} {
		return
	}

	set POOL [_get_ints $CFG(pool_size)]
	set POINTER 0
}


# Private procedure to gets the next random numbers from the pool and construct
# an unsigned integer of the relevant size.
#
#    bytes         - number of bytes for integer (min1, max 3)
#    returns       - -1 if the value for bytes is out of range.
#
proc core::api::rng::_get_multibyte_int { bytes } {

	variable CFG
	variable POOL
	variable POINTER
	set fn {core::api::rng::_get_multibyte_int}
	if {$bytes < 1 || $bytes > 4} {
		return -1
	}

	set rnd_hex_str "0x"

	#  The first time we are called we
	#  need to initalise the pool
	#  for subsequent calls
	if {![info exists POOL]} {
		core::log::write INFO {$fn: Initialising Pool}
		_populate_rng_pool
	}

	while {$bytes} {

		if {$POINTER == $CFG(pool_size)} {
			unset POOL
			_populate_rng_pool
		}

		set rnd_int [lindex $POOL $POINTER]
		incr POINTER

		set rnd_hex_str "$rnd_hex_str[format {%02x} $rnd_int]"

		incr bytes -1
	}

	return [format {%u} $rnd_hex_str]
}

#  Proc to pick a value at random
#  from a list, and remove from the
#  list in one go
#
#  list_var  - variable containing list
proc core::api::rng::_random_pick {list_var} {
	upvar 1 $list_var l

	set len [llength $l]
	if {$len <= 0} {
		return {}
	}
	set i [expr {int ($len * rand()) % $len}]
	set item [lindex $l $i]
	set l [lreplace $l $i $i]
	return $item
}

# Private procedure to fetch random numbers from the RNG server.
# Procedure makes a socket connection to the RNG server, sends a simple
# request for one or more random numbers, waits for a response and then
# returns the random number(s), if an error is not encountered.
#
#   howmany        - how many random numbers to retrieve
#   returns        - list of random number(s)
#
proc core::api::rng::_get_ints { howmany } {

	variable CFG
	set fn {core::api::rng::_get_ints}
	set lhost $CFG(lhost)

	set retry 1
	set count 0
	while {$retry} {
		incr count
		set retry 0
		core::log::write DEBUG {core::api::rng: Calling RNG, attempt $count, available hosts: $lhost}
		#  Pull servers out of the list at random
		if {[llength $lhost] == 0} {
			error "$fn: Cannot find active RNG host after $count attempts"
		}
		set l [_random_pick lhost]
		lassign $l host port

		set ret [_call_rng_server \
				$howmany $CFG(type) \
				$host $port \
				$CFG(conn_timeout) \
				$CFG(req_timeout) ]
		lassign $ret status data
		core::log::write INFO {$fn: Calling RNG server $host:$port returned status $status}

		if {$status eq "socket.conn_fail"} {
			#  Connection timeout - retry next server
			core::log::write INFO {core::api::rng: Attempt $count, Host $host:$port returned $status - retrying with remaining hosts: $lhost}
			set retry 1
		}
	}

	if {$status != "ok"} {
		core::log::write ERROR {$fn: Error $status : $data}
		error "Failed to get random number: $status : $data"
	}
	return $data
}


#  Makes a call to a specific
#  RNG Server server
#
#  Returns [error_code data]
#  either
#          [list ok <list_of_random_numbers>]
#  OR
#         [list <err_code> error_msg]
#         socket.conn_timeout        Connection timeout
#         socket.conn_error          Request Error
#         socket.error               Request Error
#         response.bad               Invalid response from server
proc core::api::rng::_call_rng_server {howmany rng_type host port conn_timeout req_timeout} {

#	variable CFG
	set fn {core::api::rng::_call_rng_server}
	# (Here we hard-code the lower and upper bounds for the required
	#  random numbers. This is so the code for next_int does not break
	#  as it relies on this being returned in bytes. No functionality
	#  is lost, as the next_int procedure provides scaling anyway)
	set lower 0
	set upper 255
	set req_data "$rng_type $howmany $lower $upper\n"

	if {[catch {
		core::log::write INFO  {core::api::rng: Calling RNG server on $host:$port conn_timeout $conn_timeout, req_timeout $req_timeout}
		lassign [core::socket::send_req \
			-req          $req_data \
			-tls          -1 \
			-is_http      0 \
			-conn_timeout $conn_timeout \
			-req_timeout  $req_timeout  \
			-host         $host \
			-port         $port] req_id status complete
	} err]} {
		core::log::write ERROR {$fn: Error contacting ${host}:${port} : $err}
		return [list socket.error $err]
	}

	# Retrieve the response
	set response [core::socket::req_info -req_id $req_id -item response]
	set response_len [string length $response]
	core::log::write INFO {core::api::rng:: Got response size $response_len from $host:$port}
	core::log::write DEV {core::api::rng:: Raw response $response}

	# Clear up the socket
	core::socket::clear_req -req_id $req_id

	switch -- $status {
		OK             {}
		CONN_TIMEOUT   {return [list socket.conn_fail    $status]}
		CONN_FAIL      {return [list socket.conn_fail    $status]}
		SEND_FAIL      {return [list socket.send         $status]}
		default {
			return [list socket.error $status]
		}
	}

	if {[string length $response] == 0} {
		core::log::write ERROR {$fn: Error - response is blank}
		return [list response.bad "Blank response"]
	}

	#  So we have a status of OK
	if {[catch {
		set lresp [split $response " "]
	} msg]} {
		core::log::write ERROR {$fn: Error '$msg' parsing response}
		core::log::write ERROR {$fn: Response is '$response'}
		return [list response.bad $msg]
	}
	core::log::write DEV {$fn: Got list $lresp}

	if {[lindex $lresp 0] != 1} {
		return [list response.error [lrange $lresp 1 end]]
	}
	set lrandom_numbers [lrange $lresp 1 end]
	#  Check all the integers are valid
	foreach num $lrandom_numbers {
		if {! ([string is integer -strict $num] && $num >= $lower && $num <= $upper)} {
			core::log::write ERROR {$fn: Invalid number $num in output $lrandom_numbers}
			return [list response.bad "Invalid response element '$num'"]
		}
	}
	return [list ok $lrandom_numbers]
}


