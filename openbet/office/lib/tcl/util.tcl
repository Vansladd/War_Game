# $Id: util.tcl,v 1.1 2011/10/04 12:37:09 xbourgui Exp $
# (C) 2005 Orbis Technology Ltd. All rights reserved.
#
# OpenBet Office API
# Utilities
#
# Synopsis:
#    package require office ?1.0?
#
# Configuration:
#    USE_COMPRESSION                    use compression on content
#    COMPRESSION_XTN                    file extensions which can be compressed
#                                       (space delimited list or ALL)
#    USE_LANG_CHARSET                   Use charset on a per language basis, which implies
#                                       on a per request basis
#
# Procedures:
#    ob_office::util::play              template play
#    ob_office::util::play_string       play string
#    ob_office::util::play_from_cache   play template from cache
#    ob_office::util::use_compression   compress HTML, etc..
#    ob_office::util::get_html_charset  returns a language specific charset
#                                       based on config settings
#    ob_office::util::req_init          generic request initialisation
#

# Variables
#
namespace eval ob_office::util {

	variable USE_COMPRESSION
	variable COMPRESSION_XTN
	variable CFG
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Private procedure to perform one-time initialisation
#
proc ob_office::util::_init {} {

	variable USE_COMPRESSION
	variable COMPRESSION_XTN
	variable CFG

	ob_log::write DEBUG {OFFICE util:init}

	if {[llength [info commands tpBufCompress]] > 0} {
		set USE_COMPRESSION [OT_CfgGet USE_COMPRESSION 0]
		set COMPRESSION_XTN [OT_CfgGet COMPRESSION_XTN ALL]
		if {$COMPRESSION_XTN != "ALL"} {
			set COMPRESSION_XTN [split $COMPRESSION_XTN " "]
		}
	} else {
		set USE_COMPRESSION 0
	}

	ob_log::write INFO {OFFICE: USE_COMPRESSION=$USE_COMPRESSION}

	set CFG(use_lang_charset) [OT_CfgGet OFFICE_USE_LANG_CHARSET 0]
}



#--------------------------------------------------------------------------
# Util
#--------------------------------------------------------------------------

# Handle generic request initialisation, i.e check for logged in status
# and initialise request specific variables
#  action - request action
proc ob_office::util::req_init {action} {

	# Logged in status
	ob_office::login::req_init $action

	# Character sets per language
	foreach xtn [list html css xml] {
		set name ${xtn}_charset
		tpBindString [string toupper $name] [ob_office::util::get_lang_charset $xtn]
	}
}



# Play a template.
#
#   template    template to play
#   cache       HTTP cache-control time - seconds (0)
#   add_hdr     add HTTP headers     (1)
#   lang        template translation language ("")
#               if not defined, then uses the global LANG, or 'en' if LANG
#               is not defined
#   tp_cache    cache the template (1)
#   charset     use a specific charset
#
proc ob_office::util::play {
	template
	{cache 0}
	{add_hdr 1}
	{lang ""}
	{tp_cache 1}
	{charset ""}} {

	global LANG

	if {$lang == ""} {
		if {![info exists LANG] || $LANG == ""} {
			set lang en
		} else {
			set lang $LANG
		}
	}

	ob_log::write DEBUG {OFFICE: play $template\
	    cache=$cache tp_cache=$tp_cache add_hdr=$add_hdr lang=$lang \
	    charset=$charset}

	# set the content-type
	if {$add_hdr} {
		set xtn [_get_xtn $template]

		if {$charset == ""} {
			if {[info exists ob_office::CFG(${xtn}_charset)]} {
				set charset ";charset=$ob_office::CFG(${xtn}_charset)"
			}
		} else {
			set charset ";charset=${charset}"
		}

		ob_log::write DEV {OFFICE: play Content-Type=text/$xtn$charset}

		tpBufAddHdr "Content-Type" "text/${xtn}${charset}"

		# use compression
		use_compression $xtn
	}

	set lang_opt ""
	if {$lang != ""} {
		set lang_opt "-lang $lang"
	}

	# play template
	if {$cache == 0} {
		if {$add_hdr} {
			tpBufAddHdr "Pragma" "no-cache"
			tpBufAddHdr "Expires" "-1"
			tpBufAddHdr "Cache-Control" "no-cache; no-store"
			tpBufAddHdr "Connection"    "close"
		}
	} else {
		if {$add_hdr} {
			tpBufAddHdr "Connection"    "close"
			tpBufAddHdr "Cache-control" "private"
			tpBufAddHdr "Cache-control" "max-age=$cache"
		}
	}

	if {$tp_cache == 1} {
		set tp_cache -cache
	} else {
		set tp_cache -nocache
	}

	uplevel #0 asPlayFile $lang_opt $tp_cache $template
}



# Play a string. The string is not processed though the template player, but
# simply played to standard output (use tpStringPlay to process a
# string-template)
#
#   string      string to play
#   cache       HTTP cache-control time - seconds (0)
#   add_hdr     add HTTP headers     (1)
#   xtn         charset extension (html)
#   charset     use a specific charset
#
proc ob_office::util::play_string {
	string
	{cache 0}
	{add_hdr 1}
	{xtn html}
	{charset ""}} {

	ob_log::write DEBUG\
		{OFFICE: play_string cache=$cache add_hdr=$add_hdr xtn=$xtn}

	if {$add_hdr} {

		if {$charset == ""} {
			if {[info exists ob_office::CFG(${xtn}_charset)]} {
				set charset ";charset=$ob_office::CFG(${xtn}_charset)"
			}
		} else {
			set charset ";charset=${charset}"
		}

		ob_log::write DEV {OFFICE: play_string Content-Type=text/$xtn$charset}

		tpBufAddHdr "Content-Type" "text/${xtn}${charset}"

		# use compression
		use_compression $xtn

		# cache
		if {$cache == 0} {
			tpBufAddHdr "Connection"    "close"
			tpBufAddHdr "Cache-Control" "no-cache"
		} else {
			tpBufAddHdr "Connection"    "close"
			tpBufAddHdr "Cache-control" "private"
			tpBufAddHdr "Cache-control" "max-age=$cache"
		}
	}

	tpBufWrite $string
}



# Play a template from cache (child's parent's shared memory).
# If the template is not in the cache, then the template will be played, then
# stored in the cache (compressed), with a cache-time.
#
#   template    template to play
#   cache_time  cache time (seconds)
#   http_cache  HTTP cache-control time - seconds (0)
#   add_hdr     add HTTP headers     (1)
#   lang        template translation language ("")
#               if not defined, then uses the global LANG, or 'en' if LANG
#               is not defined
#   tp_cache    cache the template (1)
#   charset     use a specific charset
#   name        cache name ("")
#               if not defined, then we use lang//template
#               the name should be unique
#
proc ob_office::util::play_from_cache {
	template
	cache_time
	{http_cache 0}
	{add_hdr 1}
	{lang ""}
	{tp_cache 1}
	{charset ""}
	{name ""}
} {

	global LANG

	if {$lang == ""} {
		if {![info exists LANG] || $LANG == ""} {
			set lang en
		} else {
			set lang $LANG
		}
	}

	set fn "OFFICE: play_from_cache"
	if {$name == ""} {
		set name "${lang}//${template}"
	}

	ob_log::write DEBUG {$fn\
	    name=$name\
	    cache_time=$cache_time\
	    http_cache=$http_cache\
	    add_hdr=$add_hdr\
	    lang=$lang\
	    tp_cache=$tp_cache}

	# if template not cached, or timed out, then play template and store
	if {[catch {set out_gz [asFindString -bin $name]} msg]} {
		ob_log::write WARNING {$fn $name not cached - $msg}

		if {$tp_cache} {
			set tp_cache "-cache"
		} else {
			set tp_cache "-nocache"
		}

		set lang_opt ""
		if {$lang != ""} {
			set lang_opt "-lang $lang"
		}

		set out [uplevel #0 tpTmplPlay $tp_cache -tostring $lang_opt $template]
		set out_gz [compress -bin -level 6 $out]

		if {[catch {asStoreString -bin $out_gz $name $cache_time} msg]} {
			ob_log::write ERROR {$fn $msg}
		}

	# in cache
	} else {
		ob_log::write DEBUG {$fn getting $name from cache}
		set out [uncompress -bin $out_gz]
	}

	# compress and play
	play_string $out $http_cache $add_hdr [_get_xtn $template] $charset
}



# Use compression on content - sets HTTP header Content-Encoding to gzip
#
proc ob_office::util::use_compression { xtn } {

	variable USE_COMPRESSION
	variable COMPRESSION_XTN

	if {!$USE_COMPRESSION} {
		return
	}

	if {$COMPRESSION_XTN != "ALL" && [lsearch $COMPRESSION_XTN $xtn] == -1} {
		ob_log::write DEBUG {OFFICE: not compressing, unrecognized file - $xtn}
		tpBufCompress 0
		return
	}

	set browser [reqGetEnv HTTP_USER_AGENT]
	if {[string first "MSIE 4" $browser] >= 0} {
		ob_log::write DEBUG {OFFICE: not compressing, browser $browser}
		tpBufCompress 0
		return
	}

	set compress 0
	set accept_encoding [reqGetEnv HTTP_ACCEPT_ENCODING]

	# HTTP_ACCEPT_ENCODING, can we gzip
	if {$accept_encoding != ""} {
		foreach e [split $accept_encoding ","] {
			if {[string trim $e] == "gzip"} {
				set compress 1
				break
			}
		}

	# HTTP_ACCEPT_ENCODING not set. If this looks like a known
	# browser then we will turn compression on
	} else {

		if {
			[string first "Mozilla/4" $browser] >= 0 ||
			[string first "Mozilla/5" $browser] >= 0 ||
			[string first "Opera/8" $browser] >= 0 ||
			[string first "Opera/7" $browser] >= 0
		} {
			set compress 1
		}
	}

	if {$compress} {
		ob_log::write DEBUG\
			{OFFICE: encoding to gzip, accept_encoding=$accept_encoding browser=$browser}

		tpBufAddHdr "Content-Encoding" "gzip"
	}
	tpBufCompress $compress
}



# Get the html charset to use based on the global LANG if set
#
#   returns  - charset ("" if none found)
#
proc ob_office::util::get_html_charset args {

	global LANG

	if {![info exists LANG] || $LANG == ""} {
		set charset ""
	} else {
		set config_item   [string toupper HTML_${LANG}_CHARSET]
		set charset [OT_CfgGet $config_item ""]
	}

	return $charset
}



# Get the charset to use based on the global LANG if set
#   xtn      - file extension (html|css|xml)
#   returns  - charset (default charset set on ob_office::init if not found)
#
proc ob_office::util::get_lang_charset {xtn} {

	variable CFG
	global LANG

	upvar #0 ob_office::CFG OFFICE

	if {
		!$CFG(use_lang_charset) ||
		![info exists LANG] || $LANG == "" ||
		[set charset [OT_CfgGet [string toupper ${xtn}_${LANG}_CHARSET] ""]] == ""
	} {
		return $OFFICE(${xtn}_charset)
	}

	return $charset
}



# Private function to determine what is a template's file extension
#
#   template  - template
#   returns   - extension
#
proc ob_office::util::_get_xtn { template } {

	set xtn [string last "." $template]
	if {$xtn != -1} {
		set xtn [string range $template [expr {$xtn + 1}] end]
	} else {
		set xtn "html"
	}
	if {$xtn == "xsl"} {
		set xtn "xml"
	} elseif {$xtn == "xhtml"} {
		set xtn "html"
	} elseif {$xtn == "json" || $xtn == "txt"} {
		set xtn "plain"
	}

	return $xtn
}
