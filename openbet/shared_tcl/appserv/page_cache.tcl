# $Id: page_cache.tcl,v 1.1 2011/10/04 12:26:35 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle control table (tControl)
#
# Configuration:
#
# Synopsis:
#     package require appserv_page_cache ?4.5?
#
# Procedures:
#    ob_page_cache::init    one time initialisation
#    ob_page_cache::start   start a new buffer in memory
#    ob_page_cache::play    play a template into the latest buffer
#    ob_page_cache::finish  store the buffer into SHM and playback to browser
#    ob_page_cache::terminate destroy the buffer
#

package provide appserv_page_cache 4.5


# Dependencies
#
package require util_log 4.5



# Variables
#
namespace eval ob_page_cache {
	variable CFG
	variable INIT 0
	variable BUFFERS
	variable REQ_NO -1
}


#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation.
# Get the package configuration and prepare queries.
#
proc ob_page_cache::init args {

	variable CFG
	variable INIT

	# already initialised
	if {$INIT} {
		return
	}

	# initialise dependencies
	ob_log::init

	ob_log::write DEBUG {PAGE_CACHE: init}

	array set OPT [list \
		use_compression 0 \
		use_page_cache  0 \
		page_charset    "utf-8" \
	]

	foreach c [array names OPT] {
		set CFG($c) [OT_CfgGet [string toupper $c] $OPT($c)]
	}

	# can auto reset the flags?
	if {[info commands reqGetId] != "reqGetId"} {
		error "PAGE_CACHE: reqGetId not available for auto reset"
	}

	set INIT 1
}



# Private procedure to determine if the package cache should be reloaded.
# If the current request number is different, then denote the package cache
# should be reloaded.
#
#   returns - non-zero if the cache should be reloaded, zero if
#             cache is up to date in scope of the request
#
proc ob_page_cache::_auto_reset args {

	variable BUFFERS
	variable REQ_NO

	# get the request id
	set id [reqGetId]

	# different request numbers, must reload cache
	if {$REQ_NO != $id} {

		array unset BUFFERS

		ob_log::write DEV {PAGE_CACHE: auto reset cache, req_no=$id}

		set REQ_NO $id

		set BUFFERS(buffers)     [list]
		set BUFFERS(is_open)     1

		return 1
	}

	# already loaded
	return 0
}



#----------------------------------------------------------------------------
# Page Caching
#----------------------------------------------------------------------------

# Prepare the buffer for cache key. If this cache key is
# still in the page cache, return it straight away. Pages stored in
# the cache are always gzip-ped.
#
#   cache_key  - the unique string that identifies this new buffer
#   cache_time - how long to store this buffer in cache after
#                ob_page_cache::finish has been called
#
#   returns - 1 if the page is in the cache. It will be played
#               and the calling page need not do anything else
#             0 on error, if the page is not in the cache or
#               caching is turned off. The calling code needs
#               bind the page up again.
#
proc ob_page_cache::start {cache_key {cache_time -1}} {

	variable CFG
	variable BUFFERS

	# reset the page caching data
	_auto_reset

	if {[lsearch $BUFFERS(buffers) $cache_key] != -1} {
		ob_log::write WARNING {PAGE_CACHE $cache_key: Buffer already exists, continuing ignoring this call}
		return 1
	}

	ob_log::write DEBUG {PAGE_CACHE $cache_key: Creating with timeout $cache_time}

	# add the buffer
	lappend BUFFERS(buffers)     $cache_key

	# initialise the buffer
	set BUFFERS($cache_key,buffer) ""
	set BUFFERS($cache_key,cache_time) $cache_time
	set BUFFERS($cache_key,is_open)    1

	# if page caching is turned on and the timeout is -1, attempt to
	# store it in the SHM cache
	if {$CFG(use_page_cache) == 1} {

		if {[catch {set str_gz [asFindString -bin $cache_key]} msg]} {
			ob_log::write DEBUG {PAGE_CACHE $cache_key: Cannot find in SHM cache}
			return 0
		}

	} else {
		ob_log::write DEBUG {PAGE_CACHE $cache_key: Page caching is turned off}
		return 0
	}

	ob_log::write INFO {PAGE_CACHE $cache_key: Found in SHM cache}

	# Uncompress the SHM string and store it. Also set the cache
	# time to -1, we dont want to keep refreshing this!
	set BUFFERS($cache_key,buffer)      [uncompress -bin $str_gz]
	set BUFFERS($cache_key,cache_time) -1
	set BUFFERS($cache_key,is_open)     0

	return 1
}

# Store a buffer in the SHM.
#
proc ob_page_cache::finish {cache_key} {

	variable CFG
	variable BUFFERS

	# reset the page caching data
	_auto_reset

	# if page caching is turned on and the timeout is -1, attempt to
	# store it in the SHM cache
	if {$CFG(use_page_cache) == 1 && $BUFFERS($cache_key,cache_time) != -1 && $BUFFERS(is_open) && $BUFFERS($cache_key,is_open)} {

		ob_log::write INFO {PAGE_CACHE $cache_key: Storing in SHM}

		set str_gz [compress -bin $BUFFERS($cache_key,buffer)]

		# We want to store this in the page cache anyway
		if {[catch {asStoreString -bin $str_gz $cache_key $BUFFERS($cache_key,cache_time)} msg]} {
			ob_log::write WARNING {PAGE_CACHE: Cannot store page in SHM. $msg}
		}
	}

	return 1
}

# A critical error happened, prevent the buffers to be saved to SHM.
#
proc ob_page_cache::terminate {{cache_key ""}} {

	variable CFG
	variable BUFFERS

	if {$cache_key == ""} {
		set BUFFERS(is_open)            0
	} else {
		set BUFFERS($cache_key,is_open) 0
	}
}

# Play a template into the top level buffer.
#
proc ob_page_cache::play {cache_key template {lang en}} {

	variable BUFFERS

	# reset the page caching data
	_auto_reset

	if {[lsearch $BUFFERS(buffers) $cache_key] == -1} {
		ob_log::write ERROR {PAGE_CACHE: Cannot find $cache_key buffer to play page into}
		return 0
	}

	if {$BUFFERS($cache_key,is_open) != 1} {
		ob_log::write ERROR {PAGE_CACHE: $cache_key buffer is closed.}
		return 0
	}

	ob_log::write INFO {PAGE_CACHE $cache_key: Playing $template}

	# Play the template and append it to the buffer.
	set str [uplevel #0 tpTmplPlay -tostring -force -lang $lang $template]

	if {[OT_CfgGet HTML_STRIP_WHITESPACE 1]} {
		# Purge out the whitespace that bloats the page. We are going to serve
		# this page to many users, so lets incur the cost once now. This can
		# take out ~20% of the page size.
		set cpu_time [time {
			# Remove blank lines
			set blank_lines  [regsub -all {(?n)^\s*$} $str "" str]
			# Remove leading whitespace
			set leading_space  [regsub -all {\n+\s*} $str "\n" str]
		}]
		ob_log::write INFO {Removed $blank_lines blank lines, $leading_space leading space from $cache_key in $cpu_time}
	}
	append BUFFERS($cache_key,buffer) $str

	return 1
}

# Return the contents of a buffer. We assume the page has either be
# retrieved from the SHM cache, or was built up manuall in this request.
# We then just return what is in the buffer.
#
proc ob_page_cache::get {cache_key} {

	variable BUFFERS

	# reset the page caching data
	_auto_reset

	if {[lsearch $BUFFERS(buffers) $cache_key] == -1} {
		ob_log::write ERROR {PAGE_CACHE $cache_key: Cannot find buffer}
		return ""
	}

	return $BUFFERS($cache_key,buffer)
}
