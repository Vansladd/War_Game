# $Id: rngclient32.tcl,v 1.1 2011/10/04 12:27:05 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# Random number generator client - 32 bit
#
# Synopsis:
#    package require rng_client 4.5
#
# Procedures:
#    ob_rngclient::init         one time init
#    ob_rngclient::next_init    get the next random number
#
#

package provide rng_client 4.5



# Dependencies
#
package require util_log     4.5



# Variables
#
namespace eval ob_rngclient {

	variable read_ended
	variable RNG
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time init
#
#  host        - RNG server host
#  port        - RNG server port number
#  timeout     - timeout value used in 3 placed: socket connection, waiting for
#                socket to be readable and reading from socket.
#  type        - RNG type, eg RNG_Pseudo
#  pool_size   - size of random number pool
#  rnd_min     - minimum random number possible in pool
#  rnd_max     - maximum random number possible in pool
#
proc ob_rngclient::init {host port timeout type {pool_size 100}} {

	variable RNG

	# init dependencies
	ob_log::init

	ob_log::write DEBUG {RNG 32: init}

	set RNG(host)      $host
	set RNG(port)      $port
	set RNG(timeout)   $timeout
	set RNG(type)      $type
	set RNG(pool_size) $pool_size

	_populate_rng_pool
}



# Private procedure to populate the RNG pool
#
proc ob_rngclient::_populate_rng_pool {} {

	variable RNG

	if {[info exists RNG(pool)]} {
		return
	}

	set RNG(pool) [_get_ints $RNG(pool_size)]

	set RNG(pointer) 0

}


#--------------------------------------------------------------------------
# RNG
#--------------------------------------------------------------------------

# Fetch the next random number from the RNG pool which must map into the
# specified lower and upper bounds.
#
#   lower          - inclusive lower bound on random number
#   upper          - inclusive upper bound on random number
#   returns        - random number, or -1 on error
#
proc ob_rngclient::next_int {lower upper} {

	variable RNG

	set lower [expr wide($lower)]
	set upper [expr wide($upper)]

	if {[expr {$upper - $lower}] < 1} {
		# Upper end of range must be greater than lower end
		return -1
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
		return -1
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




# Private procedure to gets the next random numbers from the pool and construct
# an unsigned integer of the relevant size.
#
#    bytes         - number of bytes for integer (min1, max 3)
#    returns       - -1 if the value for bytes is out of range.
#
proc ob_rngclient::_get_multibyte_int { bytes } {

	variable RNG

	if {$bytes < 1 || $bytes > 4} {
		return -1
	}

	set rnd_hex_str "0x"

	while {$bytes} {

		if {$RNG(pointer) == $RNG(pool_size)} {
			unset RNG(pool)
			_populate_rng_pool
		}

		set rnd_int [lindex $RNG(pool) $RNG(pointer)]
		incr RNG(pointer)

		set rnd_hex_str "$rnd_hex_str[format {%02x} $rnd_int]"

		incr bytes -1
	}

	return [format {%u} $rnd_hex_str]
}



# Private procedure to fetch random numbers from the RNG server.
# Procedure makes a socket connection to the RNG server, sends a simple
# request for one or more random numbers, waits for a response and then
# returns the random number(s), if an error is not encountered.
#
#   howmany        - how many random numbers to retrieve
#   returns        - list of random number(s)
#
proc ob_rngclient::_get_ints { howmany } {

	variable RNG
	variable read_ended

	set sock [ob_rngclient::_socket_create $RNG(host) $RNG(port)]

	# (Here we hard-code the lower and upper bounds for the required
	#  random numbers. This is so the code for next_int does not break
	#  as it relies on this being returned in bytes. No functionality
	#  is lost, as the next_int procedure provides scaling anyway)
	if {[catch {puts $sock "$RNG(type) $howmany 0 255"} msg]} {
		catch {close $sock}
		error "Failed to send RNG request: $msg"
	}

	set read_ended ""

	set id [after $RNG(timeout) {set ob_rngclient::read_ended TIMED_OUT}]

	set more 1

	while {$more} {
		if {[catch {gets $sock resp} msg]} {
			after cancel $id
			catch {close $sock}
			error "Failed to read RNG server response: $msg"
		}

		if {$resp != "" || [fblocked $sock] != 1} {
			after cancel $id
			catch {close $sock}
			set more 0
		} else {
			if {$read_ended == "TIMED_OUT"} {
				after cancel $id
				catch {close $sock}
				error "Timed out after $RNG(timeout) ms while reading response"
			}
			after 50
		}
	}

	set resp [split $resp " "]

	if {[lindex $resp 0] != "1"} {
		error "Failed to get random number: [lindex $resp 1]"
	}

	return [lreplace $resp 0 0]
}



# Private procedure to make a socket connection to the RNG server
#
#   host            - RNG server host
#   port            - RNG server port number
#   returns         - socket connection object
#
proc ob_rngclient::_socket_create {host port} {

	if {[catch {set sock [socket $host $port]} msg]} {
		error "Failed to create socket to RNG server: $msg"
	}

	fconfigure $sock -blocking 0

	if {[catch {gets $sock a} msg]} {
		close $sock
		error "Connection failed: $msg"
	}
	fconfigure $sock -blocking 1 -buffering line

	return $sock
}

