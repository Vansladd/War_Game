# (C) 2012 OpenBet Technology Ltd. All rights reserved.
#
# Random number generation using /dev/urandom. Caches data for
# performance reasons (not the numbers just the entropy).
#
# Configuration:
#
#    enc_key_use_conf     0
#    crypto_retry_errs    [list]
#    crypto_max_retries   1
#
# Synopsis:
#
#    package require :core::random
#
#    ob_enc_key::_get_keys_from_db
#

set pkg_version 1.0
package provide core::random $pkg_version

package require core::check 1.0
package require core::args  1.0

core::args::register_ns \
	-namespace core::random \
	-version   $pkg_version \
	-dependent [list core::check core::log core::args] \
	-docs      util/random.xml

namespace eval core::random {} {

	variable CFG
	variable RANDOM_CACHE

	set RANDOM_CACHE {}
	set CFG(block_size)   4096
}

core::args::register \
	-proc_name core::random::init \
	-args [list \
		[list -arg -block_size -mand 0 -check UINT -default 4096 -desc {Block size}] \
	] \
	-body {
		variable CFG

		set CFG(block_size) $ARGS(-block_size)
	}


#
# Generates specified number of random bytes as a random binary string of random hex
#
# @param -num_bytes - number of bytes wanted
#
# @return
#    n bytes of random characters converted to hex
#    Thus (2 x n) hex characters
#
core::args::register \
	-proc_name core::random::get_rand_bin \
	-args [list \
		[list -arg -num_bytes -mand 1 -check UINT -desc {number of bytes wanted}] \
	] \
	-body {
		return [_get_rand_bin $ARGS(-num_bytes)]
	}


#
# Generates specified number of bytes of random hex
#
# @param -num_bytes - number of bytes wanted
#
# @return
#    n bytes of random characters converted to hex
#    Thus (2 x n) hex characters
#
core::args::register \
	-proc_name core::random::get_rand_hex \
	-args [list \
		[list -arg -num_bytes -mand 1 -check UINT -desc {number of bytes wanted}] \
	] \
	-body {
		return [bintohex [_get_rand_bin $ARGS(-num_bytes)]]
	}


#
# Generates specified number of random ascii characters
#
# @param -num_chars - number of characters wanted
#
# @return random ascii characters
#
core::args::register \
	-proc_name core::random::rand_ascii \
	-args [list \
		[list -arg -num_chars -mand 1 -check UINT -desc {number of characters wanted}] \
	] \
	-body {
		set a [_get_rand_bin $ARGS(-num_chars)]
		set ret ""

		foreach c [split $a {}] {
			scan $c "%c" n
			set ascii_n [expr {33 + ($n % 94) }]
			set a       [format "%c" $ascii_n]
			append ret $a
		}
		return $ret
	}

#
# Generates specified number of random alpha-numeric characters
#
# @param -num_chars - number of characters wanted
#
# @return random alpha-numeric characters
#
core::args::register \
	-proc_name core::random::rand_alphanumeric \
	-args [list \
		[list -arg -num_chars -mand 1 -check UINT -desc {number of characters wanted}] \
	] \
	-body {

	set a [_get_rand_bin $ARGS(-num_chars)]
	set ret ""

	foreach c [split $a {}] {
		scan $c "%c" n
		set ascii_n [expr {48 + ($n % 74) }]
	while {($ascii_n > 57 && $ascii_n < 65) || ($ascii_n > 90 && $ascii_n < 97)} {
		scan [get_rand_hex -num_bytes 1] "%c" n
		set ascii_n [expr {48 + ($n % 74) }]
	}
		set a [format "%c" $ascii_n]
		append ret $a
	}

	return $ret
}

core::args::register \
	-proc_name core::random::get_rand_int \
	-desc {
	Fetch the next random number from the RNG pool which must map into the
	specified lower and upper bounds.

	} \
	-args [list \
			[list -arg -lower      -mand 1 -check INT        -desc {Inclusive lower bound on random number}] \
			[list -arg -upper      -mand 1 -check INT        -desc {Inclusive upper bound on random number, must be > the value in -low }] \
	] -returns {
		A random integer between -lower and -upper inclusive, uniformly distributed.
		Throws exception in case of error, including invalid input data
	} -body {
		variable CFG
		set fn {core::random::get_rand_int}
		set lower $ARGS(-lower)
		set upper $ARGS(-upper)
		if {[expr {$upper - $lower}] < 1} {
			error "$fn: Upper end of range ($upper) must be greater than lower end ($lower)" {} rng::BAD_PARAM
		}
		set rangesize [expr {$upper - $lower + 1}]
		set rnd       [_get_int $rangesize]
		return [expr {$rnd + $lower}]
}

#  Returns a random int
#  from 0 to rangesize inclusive
#
proc core::random::_get_int {rangesize} {
	set fn {core::random::_get_int}

	# Work out how many bytes we need
	lassign [_find_enclosing_bytes $rangesize] bytes diff

	#
	# We have to discard the random number if it's greater than or
	# equal to diff - (diff % rangesize)
	# or the distribution will be biased
	set do 1
	while {$do} {
		set rnd_bytes [_get_rand_bin $bytes]
		set rnd [_bintoint $rnd_bytes]
		if {$rnd < $diff - ($diff % $rangesize)} {
				set do 0
		}
	}
	return [expr {$rnd % $rangesize}]
}


#
#  Converts a binary string into an integer
#  bigendian byte order
#
proc core::random::_bintoint {bin} {
	if {[string length $bin] == 0} {
		return {}
	}
	set ret 0
	binary scan $bin {c*} lnum
	foreach num $lnum {
		# Convert to unsigned byte (i,e -1 -> 255)
		set num [expr { $num & 0xff }]
		set ret [expr {$ret*256 + $num}]
	}
	return $ret
}



#  Find the min number of bytes needed
#  to generate a number greater than or equal to this
#  number
#  n must be  >= 0 and an integer
#
#  Returns a list of [list n_bytes n_bytes*256]
#
proc core::random::_find_enclosing_bytes {n} {
	if {$n < 0} {
		error "core::random::_find_enclosing_bytes: '$n' must be >=0"
	}
	set i    1
	set mult 256
	set m    $mult
	while {$n >= $m} {
		incr i
		set m [expr {$m * $mult}]
	}
	return [list $i $m]
}


#   Proc to get a random byte array
#   from the cache or dev/urandom
#
#
proc core::random::_get_rand_bin {num_bytes} {

		variable CFG
		variable RANDOM_CACHE

		if {[string length $RANDOM_CACHE] < $num_bytes} {
			append RANDOM_CACHE [_get_raw_rand [expr {$CFG(block_size) + $num_bytes}]]
		}
		set result [string range $RANDOM_CACHE 0 [expr {$num_bytes - 1}]]
		set RANDOM_CACHE [string range $RANDOM_CACHE [expr {$num_bytes}] end]
		return $result
}



# Open a handle to and read a configurable number of
# characters from /dev/urandom.
proc core::random::_get_raw_rand {num_chars} {

	set fd [open {/dev/urandom}]

	fconfigure $fd -encoding binary -translation binary

	set ret [read $fd $num_chars]

	close $fd
	return $ret
}
