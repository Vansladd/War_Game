# (C) 2011 Orbis Technology Ltd. All rights reserved.
#
# Caching functionality
#
#
# Features
# * Distributed cache handling
# * gzip compression
# * Cache key prefix
# * Expired cache handling
#

set pkgVersion 1.0
package provide core::cache $pkgVersion

# Dependencies
package require core::log   1.0
package require core::check 1.0
package require core::args  1.0
package require core::gc    1.0

core::args::register_ns \
	-namespace core::cache \
	-version   $pkgVersion \
	-dependent [list core::check core::log core::args core::gc] \
	-docs      xml/appserv/cache.xml

# This package should not rely on a config file
namespace eval core::cache {

	variable CFG
	variable INIT
	variable CACHE_DATA
	variable PREFIX

	set INIT 0
}

core::args::register \
	-proc_name core::cache::init \
	-args [list \
		[list -arg -force_init             -mand 0 -check BOOL                                -default 0 -desc {Force initialisation}] \
		[list -arg -compress               -mand 0 -check BOOL                                -default 1 -desc {Enable compression as default}] \
		[list -arg -compress_level         -mand 0 -check UINT                                -default 6 -desc {Define compression level}] \
		[list -arg -dist_cache             -mand 0 -check BOOL -default_cfg AS_USE_DIST_CACHE -default 0 -desc {Distribute cache using memcached}] \
		[list -arg -play_expired_cache     -mand 0 -check BOOL                                -default 0 -desc {Play expired cache if rebuilding (needed for dist_cache)}] \
	]

# Initialise the package. This should be performed at startup
proc core::cache::init args {

	variable CFG
	variable INIT
	variable PREFIX

	array set ARGS [core::args::check core::cache::init {*}$args]

	if {!$ARGS(-force_init) && $INIT == 1} {
		return
	}

	set PREFIX {}

	set CFG(compress)           $ARGS(-compress)
	set CFG(compress_level)     $ARGS(-compress_level)
	set CFG(dist_cache)         $ARGS(-dist_cache)
	set CFG(play_expired_cache) $ARGS(-play_expired_cache)

	# Setup the default cache times
	set CFG(sym_time,NONE)  0
	set CFG(sym_time,PRICE) 10
	set CFG(sym_time,EVENT) 60
	set CFG(sym_time,TYPE)  300
	set CFG(sym_time,CLASS) 600

	set dist_cache_servers [OT_CfgGet AS_DIST_CACHE_SERVERS ""]

	# Are we using a distributed cache
	# NOTE: you have to allow expired cache for this
	if {$CFG(dist_cache)} {

		if {$dist_cache_servers == ""} {
			error "AS_DIST_CACHE_SERVERS config must be populated to use distributed cache"
		}

		set CFG(cache_method) "DIST_CACHE"

		if {!$CFG(play_expired_cache)} {
			error "distributed cache enabled but expired cache is not"
		}
	} else {

		if {$dist_cache_servers != ""} {
			error "AS_DIST_CACHE_SERVERS config must be unset or blank when not using distributed cache"
		}

		if {$CFG(play_expired_cache)} {
			set CFG(cache_method) "EXPIRED_CACHE"
		} else {
			set CFG(cache_method) "SHM"
		}
	}

	core::gc::add core::cache::PREFIX
	core::gc::add core::cache::CACHE_DATA

	set INIT 1
}

core::args::register \
	-proc_name core::cache::add_time \
	-args [list \
		[list -arg -sym_time -mand 1 -check ASCII -desc {The symbolic name for the cache time}] \
		[list -arg -time     -mand 1 -check UINT  -desc {The time in seconds to cache a template for}] \
	]

# Add a symbolic cache time to the package
proc core::cache::add_time args {

	variable CFG

	array set ARGS [core::args::check core::cache::add_time {*}$args]

	set sym_time $ARGS(-sym_time)
	set time     $ARGS(-time)

	if {[info exists CACHE(sym_time,$sym_time)]} {
		core::log::write WARN {Overwritten symbolic time $sym_time $CFG(sym_time,$sym_time)}
	}

	set CFG(sym_time,$sym_time) $time

	core::log::write INFO {Setting symbolic time $sym_time $time}
}

core::args::register \
	-proc_name core::cache::set_prefix \
	-args [list \
		[list -arg -key_prefix -mand 1 -check ASCII -desc {The prefix for the cache key for the current request}] \
	]

# Add a prefix to the cache key to simplify adding multiple objects to the cache
proc core::cache::set_prefix args {

	variable CFG
	variable PREFIX

	array set ARGS [core::args::check core::cache::set_prefix {*}$args]

	set key_prefix $ARGS(-key_prefix)

	set PREFIX $key_prefix

	core::log::write INFO {Setting key prefix: $key_prefix}
}

core::args::register \
	-proc_name core::cache::get_prefix

# Get the current prefix
proc core::cache::get_prefix args {

	variable CFG
	variable PREFIX

	if {[info exists PREFIX]} {
		return $PREFIX
	}

	return {}
}

core::args::register \
	-proc_name core::cache::store \
	-args [list \
		[list -arg -data     -mand 1 -check ANY   -desc {The data to write to SHM}] \
		[list -arg -key      -mand 1 -check ASCII -desc {The cache key to read/write to SHM}] \
		[list -arg -sym_time -mand 1 -check ASCII -desc {The symbolic name for the cache time. These are setup on startup}] \
	]

# Store an object in cache
proc core::cache::store args {

	variable CFG
	variable CACHE_DATA

	core::gc::add core::cache::PREFIX
	core::gc::add core::cache::CACHE_DATA

	array set ARGS [core::args::check core::cache::store {*}$args]

	set data     $ARGS(-data)
	set key      $ARGS(-key)
	set sym_time $ARGS(-sym_time)

	if {![info exists CFG(sym_time,$sym_time)]} {
		error "Unknown sym time $sym_time"
	}

	set key        [get_prefix]-$key
	set cache_time $CFG(sym_time,$sym_time)

	# Store the data in SHM and
	if {$CFG(compress)} {
		append key -compress

		if {[info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8"} {
			set compressed [compress -string -level $CFG(compress_level) $data]
		} else {
			set compressed [compress -bin -level $CFG(compress_level) $data]
		}

		asStoreString -bin $compressed $key $cache_time
	} else {
		asStoreString $data $key $cache_time
	}

	core::log::write DEBUG {Stored $key ${cache_time}s}

	# Cache the data in a local garbage collected variable for the lifetime of the request
	set CACHE_DATA($key,time)       [clock seconds]
	set CACHE_DATA($key,template)   $data
}


core::args::register \
	-proc_name core::cache::check \
	-args [list \
		[list -arg -key -mand 1 -check ASCII -desc {The cache key to read/write to SHM}] \
	]

# Check if an object is in cache
#
# dist_status :
#   NOT_CHECKED
#   UNLOCKED
#   LOCKED
proc core::cache::check args {

	variable CFG
	variable CACHE_DATA

	core::gc::add core::cache::PREFIX
	core::gc::add core::cache::CACHE_DATA

	array set ARGS [core::args::check core::cache::check {*}$args]

	# Apply the prefix to the key
	set key   [get_prefix]-$ARGS(-key)
	set mode  {}
	set found 1

	if {$CFG(compress)} {
		append key -compress
		set mode -bin
	}

	# Check if the object is in the local cache before checking SHM
	if {[info exists CACHE_DATA($key,template)]} {
		core::log::write DEBUG {HIT: found $key in local cache}
		return 1
	}

	# if we missed cache first time we looked, still return missing -
	# otherwise the 80% time appserver re-build will fail (as the 2nd call to
	# asFindString will find the item and we won't store a new version)
	if {[info exists CACHE_DATA($key,miss)]} {
		set miss_time [clock format $CACHE_DATA($key,miss) -format "%Y-%m-%d %H:%M:%S"]
		core::log::write DEBUG {MISS: previous cache miss: $key @ $miss_time}
		return 0
	}

	core::log::write DEBUG {Checking $CFG(cache_method) $key}

	set options     {-with-info}
	set dist_status {}
	set ret         {}
	set data        {}
	set status      {}

	# Handle distributed cache
	switch -- $CFG(cache_method) {
		DIST_CACHE {
			set options {-expired -with-info -dist-status dist_status}
		}
		EXPIRED_CACHE {
			set options {-expired -with-info}
		}
	}

	# Try and retrieve the object from cache
	#
	# Passing -with-info will cause asFindString to, on finding the data string,
	# return a 3-element list containing the data string,
	# its status ("OK", "80PCT", "90PCT", "EXPIRED") and its sequence-number.
	# The -with-info option implies -expired.
	if {[catch {
		set ret [asFindString {*}$mode {*}$options $key]
		lassign $ret data status
	} msg]} {
		core::log::write DEBUG {ERROR: $msg}
		set found 0
	} elseif {$dist_status == "UNLOCKED"} {
		set found 0
	} elseif { \
		$CFG(cache_method) != "DIST_CACHE" && \
		($status == "80PCT" || $status == "90PCT" || \
			($status == "EXPIRED" && $CFG(cache_method) != "EXPIRED_CACHE"))} {

			# We got some data back, but can we use it?
			# If we aren't using a distributed cache, we rebuild if we got
			#   80%
			#   90%
			#   EXPIRED and we don't allow expired data to be returned.
			set found 0
	}

	set status_and_info [lrange $ret 1 end]
	core::log::write DEBUG {$key $status_and_info ($dist_status)}

	if {$found} {
		if {$CFG(compress)} {
			if {[info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8"} {
				set data [uncompress -string $data]
			} else {
				set data [uncompress -bin $data]
			}
		}

		core::log::write DEBUG {HIT: found $key in cache using $CFG(cache_method)}
		set CACHE_DATA($key,template)   $data
		set CACHE_DATA($key,time)       [clock seconds]
		return 1
	}

	# Set a flag to indicate that the cache was missed
	set CACHE_DATA($key,miss) [clock seconds]

	# Unable to find the object
	core::log::write INFO {MISS: unable to find $key in cache, status: $status using $CFG(cache_method)}
	return 0
}

core::args::register \
	-proc_name core::cache::get \
	-args [list \
		[list -arg -key -mand 1 -check ASCII -desc {The cache key to read from local cache}] \
	]

# Retrieve an object from local cache
proc core::cache::get args {

	variable CFG
	variable CACHE_DATA

	array set ARGS [core::args::check core::cache::get {*}$args]

	# Apply the prefix to the key
	set key   [get_prefix]-$ARGS(-key)
	set found 1
    
	if {$CFG(compress)} {
		append key -compress
	}  

	# Retrieve object from local cache
	if {[info exists CACHE_DATA($key,template)]} {
		return [list 1 $CACHE_DATA($key,template)]
	}

	return [list 0]
}

# Generate a semaphore key
core::args::register \
	-proc_name core::cache::gen_key \
	-args [list \
		[list -arg -port -mand 0 -default_cfg PORTS -check ASCII -desc {Port including optional IP address}] \
	] \
	-body {
		set port $ARGS(-port)

		# IP address plus port no. gives 48 bits, which we need to reduce
		# to 32; therefore hash the four octets in the address and the two
		# in the port-number.  I've cribbed the algorithm from Tcl's hash-
		# table implementation.
		if { [regexp {^(.+):([^:]+)$} $port {} addr port] } {

			set     octets [split $addr .]
			lappend octets [expr { $port >> 8 }] [expr { $port & 0xff }]

			set key 0

			foreach octet $octets {
				set key [expr {($key * 9 + $octet) & 0xffffffff }]
			}

		} else {
			# No IP address, so use the port number as-is.
			set key $port
		}

		return $key
	}
