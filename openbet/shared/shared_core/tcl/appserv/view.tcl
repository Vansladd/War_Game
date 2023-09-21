# (C) 2011 Orbis Technology Ltd. All rights reserved.
#
# Request  Model
#

set pkgVersion 1.0
package provide core::view $pkgVersion


# Dependencies
#
package require core::gc         1.0
package require core::log        1.0
package require core::check      1.0
package require core::args       1.0
package require core::controller 1.0


core::args::register_ns \
	-namespace core::view \
	-version   $pkgVersion \
	-dependent [list core::gc core::log core::check core::args] \
	-docs      xml/appserv/view.xml

namespace eval core::view {

	variable CFG
	variable INIT
	variable TMPL_INIT
	variable APP_CFG
	variable FILETYPES

	variable REQ_CFG
	variable REQ_ESC
	variable REQ_COOKIES
	variable REQ_HEADERS

	set INIT 0
	set TMPL_INIT 0
}

core::args::register \
	-proc_name core::view::init \
	-args      [list \
		[list -arg -strict_mode           -mand 1 -check BOOL              -desc {Strict-mode!.}] \
		[list -arg -default_charset       -mand 1 -check ASCII             -desc {The application specific default charset.}] \
		[list -arg -default_lang          -mand 0 -check ALNUM -default {} -desc {The application specific default language.}] \
		[list -arg -use_compression       -mand 0 -check BOOL  -default 0  -desc {Turn on or off appserv compression. }] \
		[list -arg -compress_level        -mand 0 -check UINT  -default 1  -desc {Compression level when appserv compression is turned on.}] \
		[list -arg -include_ua            -mand 0 -check ASCII -default {} -desc {List of user agents to turn appserv compression on.}] \
		[list -arg -exclude_ua            -mand 0 -check ASCII -default {} -desc {List of user agents to turn appserv compression off.}] \
		[list -arg -strip_whitespace      -mand 0 -check UINT  -default 1  -desc {Strip leading and trailing whitespace from the output of any template that has been played.}] \
		[list -arg -allowed_template_path -mand 0 -check ASCII -default {} -desc {If not empty, the template player will only be allowed to play template files under this directory. Needs appserv 2.36.5+.}] \
		[list -arg -force                 -mand 0 -check BOOL  -default 0  -desc {Only the first call to core::view::init has any effect unless this flag is used to force re-initialisation. Useful for unit-testing.}] \
]

proc core::view::init args {

	variable APP_CFG
	variable INIT
	variable TMPL_INIT
	variable FILETYPES
	variable HTTP_STATUS
	variable CURRENT_TMPL_FILTER

	array set my_args [core::args::check core::view::init {*}$args]

	if {$INIT && !$my_args(-force)} {
		return
	}

	core::log::write INFO {VIEW: init args=$args}

	if {$my_args(-force)} {
		set INIT 0
		set TMPL_INIT 0
	}

	set APP_CFG(strict_mode)     $my_args(-strict_mode)
	set APP_CFG(default_lang)    $my_args(-default_lang)
	set APP_CFG(default_charset) $my_args(-default_charset)

	# Appserv Compression
	set APP_CFG(use_compression) $my_args(-use_compression)
	set APP_CFG(include_ua)      $my_args(-include_ua)
	set APP_CFG(exclude_ua)      $my_args(-exclude_ua)
	set APP_CFG(compress_level)  $my_args(-compress_level)

	# Appserv encoding
	if {[info exists ::env(AS_CHARSET)] && $::env(AS_CHARSET) == "UTF-8"} {
		set APP_CFG(encoding_flag) -utf8
	} else {
		set APP_CFG(encoding_flag) -bin
	}

	# Strip whitespace
	set APP_CFG(strip_whitespace) $my_args(-strip_whitespace)

	# Allowed template path.
	_setup_template_path_filter $my_args(-allowed_template_path)

	# Make sure the Appserv actually supports compression
	if {$APP_CFG(use_compression)} {
		if {![tpBufCanCompress] || [info command tpBufCompress] != "tpBufCompress"} {
			set APP_CFG(use_compression) 0
		}
	}

	array unset HTTP_STATUS
	# 2xx Success
	set HTTP_STATUS(200) "200 OK"
	# 3xx Redirection
	set HTTP_STATUS(301) "301 Moved Permanently"
	set HTTP_STATUS(302) "302 Found"
	set HTTP_STATUS(303) "303 See Other"
	set HTTP_STATUS(304) "304 Not Modified"
	set HTTP_STATUS(307) "307 Temporary Redirect"
	# 4xx Client Error
	set HTTP_STATUS(404) "404 Not Found"
	set HTTP_STATUS(410) "410 Gone"
	# 5xx Server Error
	set HTTP_STATUS(500) "500 Internal Server Error"

	array unset FILETYPES
	set FILETYPES(names) [list]
	register_filetype -name html -pp ::core::view::preprocess_html
	register_filetype -name css  -pp ::core::view::preprocess_css
	register_filetype -name js   -pp ::core::view::preprocess_js
	register_filetype -name raw  -pp ::core::view::preprocess_raw

	if {!$TMPL_INIT} {
		tmpl_init
	}

	set INIT 1

	return
}


# What version of the appserver are we running inside?
proc core::view::_get_appserv_version {} {
	variable APP_CFG
	if {![info exists APP_CFG(appserv_version)]} {
		set APP_CFG(appserv_version) \
		  [core::controller::get_cfg -config  appserv_pkg_version -default 0]
	}
	return $APP_CFG(appserv_version)
}


# Setup a filter to check that all template files played are inside the
# allowed_template_path (unless it's the empty string).
# Note that this will affect all calls to tpTmplPlay, not just those
# from inside core:view.
proc core::view::_setup_template_path_filter {allowed_template_path} {

	variable APP_CFG
	variable CURRENT_TMPL_FILTER

	set APP_CFG(allowed_template_path) $allowed_template_path

	if {$APP_CFG(allowed_template_path) eq ""} {
		# Oddly, there's no way to undo a tpTmplFilter call other than
		# registering a dummy filter proc that always says "yes".
		# We only need to do this if someone first called core::view::init
		# with an allowed_template_path, then called it again without one
		# (but with the -force 1 argument). Pretty weird so we log it.
		set dummy_tmpl_filter [namespace code _dummy_template_path_filter]
		if {[info exists CURRENT_TMPL_FILTER] && 
		    ![string equal $CURRENT_TMPL_FILTER $dummy_tmpl_filter]} {
			core::log::write WARNING \
			  {VIEW: disabling previously registered template path filter.}
			tpTmplFilter $dummy_tmpl_filter
			set CURRENT_TMPL_FILTER $dummy_tmpl_filter
		}
		return
	}

	# Normalize (make absolute) the path at this point to avoid unpredictable
	# behaviour as might occur if we waited until the 1st template is played.
	# (e.g. the appserv changes working directory somewhere between main_init
	#  and req_init, so the meaning of a relative path could change)
	# NB: an alternative would be to just mandate that an absolute path is
	#     configured (can check with file pathtype and throw an error?).

	set original_path $APP_CFG(allowed_template_path)
	set APP_CFG(allowed_template_path) [file normalize $original_path]
	if {![string equal $original_path $APP_CFG(allowed_template_path)]} {
		core::log::write INFO {VIEW: normalized allowed_template_path from\
			                   "$original_path" to "$APP_CFG(allowed_template_path)".}
	}

	# Unfortunately, while tpTmplFilter has been in the appserv for a while, it had a
	# bug likely to cause segfaults when templates are played prior to version 2.36.5.
	# To avoid providing a false sense of security, we choose to refuse to initialise
	# if we can't honor the caller's request to enforce an allowed_template_path.
	# Worse alternatives would be:
	#   - fallback to Tcl code; but one key reason to have tpTmpFilter in the appserv was
	#     so we could tell auditors the protection is built-in - plus it would complicate
	#     the code base (especially if we hook into all tpTmplPlay calls - and if we don't
	#     then we get weird changes in behaviour between the Tcl vs appserv implementation).
	#   - log a warning and don't enforce the allowed_template_path; but apart from the
	#     false sense of security this would introduce a risk that an appserv upgrade
	#     would break code by making allowed_template_path suddenly work again.

	set appserv_version [_get_appserv_version]
	# NB: the dash at the end of the required version means we accept 3.x, 4.x, etc.
	set tmpl_filter_fix_requires "2.36.5-"
	if {![package vsatisfies $appserv_version $tmpl_filter_fix_requires]} {
		set reason "Refusing to initialise since cannot enforce\
		            -allowed_template_path because appserv version ($appserv_version)\
		            too old - require $tmpl_filter_fix_requires."
		core::log::write ERROR {VIEW: $reason}
		error $reason {} VIEW_UNSUPPORTED_APPSERV_VERSION
	} else {
		set tmpl_filter [namespace code _filter_template_path]
		tpTmplFilter $tmpl_filter
		set CURRENT_TMPL_FILTER $tmpl_filter
	}

	return
}


# Warning: this seems to be called before core::view::init sometimes
# (e.g. if an app calls core::view::escape_js before core::view::init).
proc core::view::tmpl_init args {

	variable APP_CFG
	variable TMPL_INIT

	if {$TMPL_INIT} {
		return
	}

	# Use the appserv functionality if we have the appropriate version
	set appserv_version [_get_appserv_version]
	if {[package vsatisfies $appserv_version 2.21]} {
		core::log::write INFO {VIEW: Using appserv code for escaping JS & HTML}
		set APP_CFG(escape_js)   core::view::escape_js_appserv
		set APP_CFG(escape_html) core::view::escape_html_appserv
	} else {
		core::log::write INFO {VIEW: Using Tcl code for escaping JS & HTML}
		set APP_CFG(escape_js)   core::view::escape_js_tcl
		set APP_CFG(escape_html) core::view::escape_html_tcl
	}

	set TMPL_INIT 1

	return
}



core::args::register \
	-proc_name core::view::register_filetype \
	-args      [list \
		[list -arg -name -mand 1 -check ASCII -desc {The name of the filetype (html etc).}] \
		[list -arg -pp   -mand 1 -check ASCII -desc {The name of the on-load preprocessor proc. Used as the onload param to tpTmplPlay.}] \
	]

proc core::view::register_filetype args {

	variable FILETYPES
	array set my_args [core::args::check core::view::register_filetype {*}$args]

	set name $my_args(-name)
	set pp   $my_args(-pp)

	if {[lsearch $FILETYPES(names) $name] == -1} {
		lappend FILETYPES(names) $name
	}

	set FILETYPES(pp,$name) $pp
}



core::args::register \
	-proc_name core::view::add_header \
	-args      [list \
		[list -arg -name  -mand 1 -check ASCII             -desc {The name of the HTTP Header}] \
		[list -arg -value -mand 1 -check HTTP_HEADER_VALUE -desc {The value of the HTTP Header}] \
	]

proc core::view::add_header args {

	variable REQ_CFG
	variable REQ_HEADERS

	core::gc::add core::view::REQ_CFG
	core::gc::add core::view::REQ_HEADERS

	# If we have already played headers, we dont want to play them again in this
	# request. So log a warning and bail.
	if {[info exists REQ_CFG(played_headers)]} {
		core::log::write INFO {VIEW: Error already played headers when adding a header. Refusing to add another one.}
		return 0
	}

	array set my_args [core::args::check core::view::add_header {*}$args]

	set hdr $my_args(-name)

	core::log::write DEV {VIEW: add_header name=$my_args(-name) value=$my_args(-value)}

	if {[info exists REQ_HEADERS($hdr,name)]} {
		core::log::write WARNING {VIEW: Warning overwriting HTTP header $hdr}
	}

	set REQ_HEADERS($hdr,name)  $hdr
	set REQ_HEADERS($hdr,value) $my_args(-value)

	return 1
}



core::args::register \
	-proc_name core::view::set_cookie \
	-args      [list \
		[list -arg -name      -mand 1 -check COOKIE_NAME               -desc {The name of the cookie}] \
		[list -arg -value     -mand 0 -check COOKIE_VALUE -default {}  -desc {The cookie value. This can be blank, or not included, if you wish to clear a cookie.}] \
		[list -arg -path      -mand 0 -check ASCII        -default {/} -desc {The path for which the cookie should be set. }] \
		[list -arg -expires   -mand 0 -check ASCII        -default {}  -desc {The expiry time of the cookie}] \
		[list -arg -domain    -mand 0 -check ASCII        -default {}  -desc {The domain of the cookie}] \
		[list -arg -secure    -mand 0 -check BOOL         -default 1   -desc {Is the cookie secure attribute turned on?}] \
		[list -arg -http_only -mand 0 -check BOOL         -default 1   -desc {Is the cookie httponly attribute turned on? https://www.owasp.org/index.php/HttpOnly}] \
	]

proc core::view::set_cookie args {

	variable REQ_CFG
	variable REQ_COOKIES

	core::gc::add core::view::REQ_CFG
	core::gc::add core::view::REQ_COOKIES

	# If we have already played headers, we dont want to play them again in this
	# request. So log a warning and bail.
	if {[info exists REQ_CFG(played_headers)]} {
		core::log::write INFO {VIEW: Error already played headers when adding a cookie. Refusing to add another one.}
		return 0
	}

	array set my_args [core::args::check core::view::set_cookie {*}$args]

	set cookie $my_args(-name)
	set secure $my_args(-secure)

	# Check if the request was made over https
	if {![core::controller::get_req_cfg -config is_https -default 0]} {
		set secure 0
	}

	core::log::write DEV {VIEW: set_cookie name=$my_args(-name) path=$my_args(-path) expires=$my_args(-expires) domain=$my_args(-domain) secure=$secure http_only=$my_args(-http_only)}

	if {[info exists REQ_COOKIES($cookie,name)]} {
		core::log::write WARNING {VIEW: Warning overwriting cookie $cookie}
	}

	set REQ_COOKIES($cookie,name)      $cookie
	set REQ_COOKIES($cookie,value)     $my_args(-value)
	set REQ_COOKIES($cookie,path)      $my_args(-path)
	set REQ_COOKIES($cookie,expires)   $my_args(-expires)
	set REQ_COOKIES($cookie,domain)    $my_args(-domain)
	set REQ_COOKIES($cookie,secure)    $secure
	set REQ_COOKIES($cookie,http_only) $my_args(-http_only)

	return 1
}



#----------------------------------------------------------------------------
# Template Playing Procedures
#----------------------------------------------------------------------------

set arg_filename  [list -arg -filename      -mand 1 -check ASCII             -desc {The filename of the template to play.}]
set arg_filetype  [list -arg -filetype      -mand 1 -check ALNUM             -desc {The content type of the template. Possible values are html, css, js or raw. A raw file type will not be escaped, implying the application has already escaped the data.}]
set arg_lang      [list -arg -lang          -mand 0 -check ALNUM -default {} -desc {The language to use when playing a template.}]
set arg_charset   [list -arg -charset       -mand 0 -check ASCII -default {} -desc {The character set to use when playing a template.}]
set arg_output_to [list -arg -output_to     -mand 0 -check ALNUM -default {} -desc {The output mode of tpTmplPlay. 'string' causes -tostring mode, anything else will default to -tobuf mode.}]
set arg_flush_hdr [list -arg -flush_headers -mand 0 -check BOOL  -default 0  -desc {Whether to force flushing headers prematurely}]

set args_with_type    [list $arg_filename $arg_filetype $arg_lang $arg_charset $arg_output_to $arg_flush_hdr]
set args_without_type [list $arg_filename               $arg_lang $arg_charset $arg_output_to $arg_flush_hdr]

core::args::register \
	-proc_name core::view::play \
	-args      $args_without_type

proc core::view::play args {

	array set my_args [core::args::check core::view::play {*}$args]

	# Try to determine the filetype based on the filename.
	# Yuck.
	#
	switch -regexp -- $my_args(-filename) {
		{^.*\.htm$}  -
		{^.*\.html$} { set my_args(-filetype) html }
		{^.*\.js$}   { set my_args(-filetype) js }
		{^.*\.css$}  { set my_args(-filetype) css }
		default      { set my_args(-filetype) raw }
	}

	return [play_file {*}[array get my_args]]
}



core::args::register \
	-proc_name core::view::play_html \
	-args      $args_without_type

proc core::view::play_html args {

	array set my_args [core::args::check core::view::play_html {*}$args]

	set my_args(-filetype) html

	return [play_file {*}[array get my_args]]
}



core::args::register \
	-proc_name core::view::play_js \
	-args      $args_without_type

proc core::view::play_js args {

	array set my_args [core::args::check core::view::play_js {*}$args]

	set my_args(-filetype) js

	return [play_file {*}[array get my_args]]
}



core::args::register \
	-proc_name core::view::play_css \
	-args      $args_without_type

proc core::view::play_css args {

	array set my_args [core::args::check core::view::play_css {*}$args]

	set my_args(-filetype) css

	return [play_file {*}[array get my_args]]
}



core::args::register \
	-proc_name core::view::play_raw \
	-args      $args_without_type

proc core::view::play_raw args {

	array set my_args [core::args::check core::view::play_raw {*}$args]

	set my_args(-filetype) raw

	return [play_file {*}[array get my_args]]
}



core::args::register \
	-proc_name core::view::play_file \
	-args      $args_with_type

proc core::view::play_file args {

	variable APP_CFG
	variable FILETYPES
	variable TMPL_QUEUE

	core::gc::add core::view::TMPL_QUEUE

	array set my_args [core::args::check core::view::play_file {*}$args]

	if {![info exists TMPL_QUEUE(tmpl)]} {
		set TMPL_QUEUE(tmpl) [list]
		set TMPL_QUEUE(head) -1
	}

	set tmpl_list $TMPL_QUEUE(tmpl)

	# We play the headers if
	#   - this is the first template being played tobuf
	#     and the first ever template being queued was not
	#     to string.
	#   - we force flushing the headers because we know
	#     that we've queued templates tostring and this is
	#     the outermost template we are playing
	if {
		$my_args(-flush_headers) ||
		(
			$my_args(-output_to) != "string" && ![llength $tmpl_list]
			&& $TMPL_QUEUE(head) != "string"
		)
	} {
		_play_headers
	}

	if {$my_args(-output_to) != "string"} {
		lappend TMPL_QUEUE(tmpl) $my_args(-filename)
	}

	if {$TMPL_QUEUE(head) == -1} {
		set TMPL_QUEUE(head) $my_args(-output_to)
	}

	set filetype   $my_args(-filetype)
	set preprocess $FILETYPES(pp,$filetype)

	core::log::write DEBUG {VIEW: play_file $args}

	if {$my_args(-lang) == ""} {
		set my_args(-lang) $APP_CFG(default_lang)
	}
	if {$my_args(-charset) == ""} {
		set my_args(-charset) $APP_CFG(default_charset)
	}
	if {$my_args(-output_to) == "string"} {

		set output [uplevel #0 tpTmplPlay \
			-tostring -force \
			-preprocess $preprocess \
			-lang       $my_args(-lang) \
			$my_args(-filename)]

		if {$APP_CFG(strip_whitespace) == 1} {
			set l0 [string length $output]
			set t0 [OT_MicroTime]
			regsub -all {\s*\n+\s*} [string trim $output] "\n" output
			set t1 [OT_MicroTime]
			set l1 [string length $output]

			core::log::write DEBUG {VIEW: Stripped [expr {$l0 - $l1}] bytes in [format %0.3f [expr {$t1 - $t0}]] microseconds from $my_args(-filename)}
		}

		return $output
	} else {
		return [uplevel #0 tpTmplPlay \
			-tobuf \
			-preprocess $preprocess \
			-lang       $my_args(-lang) \
			$my_args(-filename)]
	}
}

# Append the given string to the buffer. If the -bin option is used,
# then the lower 8 bits of each non-ASCII character in str will be
# appended to the buffer (and the upper 8 bits of each non-ASCII character discarded).
core::args::register \
	-proc_name core::view::write \
	-desc      {Write a string to the buffer} \
	-args      [list \
		[list -arg -str  -mand 1 -check ANY                 -desc {The string to write to the buffer}]\
		[list -arg -desc -mand 0 -check ASCII -default {}   -desc {The description of the string}]\
		[list -arg -mode -mand 0 -check ASCII -default -str -desc {-str | -bin (string or binary)}]\
		[list -arg -raw  -mand 0 -check BOOL  -default 0    -desc {Play a non escaped string}]\
		$arg_lang \
		$arg_charset \
		$arg_output_to]

proc core::view::write args {

	variable APP_CFG

	array set my_args [core::args::check core::view::write {*}$args]

	set str $my_args(-str)

	set tmpls [tpSiteTmpls]

	# We only want to play the headers if we're not inside another template.
	if {![llength $tmpls]} {
		_play_headers
	}

	set bytelength [string bytelength $str]
	core::log::write DEBUG {VIEW: write $my_args(-mode) $my_args(-desc) ($bytelength bytes)}

	if {$my_args(-raw)} {
		tpBindString core_view_RAW_STRING $str
		return [uplevel #0 tpStringPlay \
			-tobuf \
			-lang en \
			{{##TP_ESC {core::view::preprocess_raw}####TP_core_view_RAW_STRING####TP_ESC##}} \
		]
	} else {
		tpBufPut $my_args(-mode) $str
	}
}


core::args::register \
	-proc_name core::view::redirect \
	-args      [list \
		[list -arg -url         -mand 1 -check ASCII              -desc {The URL to redirect to}] \
		[list -arg -status_code -mand 0 -check UINT  -default 302 -desc {The HTTP status code to use for the redirect.}] \
		[list -arg -req_args    -mand 0 -check ASCII -default {}  -desc {A list of name-value pairs to add to the end of the url as request args (e.g. name=val)}] \
		[list -arg -orig_args   -mand 0 -check ASCII -default {}  -desc {Parameter name for the original request arguments to be encoded with, if not present parameter will not be encoded}] \
	]

proc core::view::redirect args {

	variable HTTP_STATUS

	array set my_args [core::args::check core::view::redirect {*}$args]

	set status         $my_args(-status_code)
	set url            $my_args(-url)
	set orig_args_name $my_args(-orig_args)

	# If we have been passed a value for -orig_args then encode the parameters
	# from the original request into the redirect
	if {$orig_args_name != {}} {
		set orig_args_val {}
		for {set i 0} {$i < [$::core::request::PROCS(reqGetNumVals)]} {incr i} {
			set arg_name [$::core::request::PROCS(reqGetNthName) $i]
			set arg_val  [$::core::request::PROCS(reqGetNthVal) $i]

			if {$arg_name != {}} {
				append orig_args_val $arg_name {=} $arg_val {&}
			}
		}
		set orig_args_val [string trimright $orig_args_val {&}]
		lappend my_args(-req_args) $orig_args_name $orig_args_val
	}

	core::log::write DEBUG {VIEW: redirect status=$status url=$url}

	if {[llength $my_args(-req_args)] > 0} {
		if {[string first "?" $url] == -1} {
			append url "?"
		}

		foreach {name value} $my_args(-req_args) {
			append url "&"
			append url [urlencode $name]
			append url "="
			append url [urlencode $value]
		}
	}

	if {![info exists HTTP_STATUS($status)]} {
		core::log::write INFO {VIEW: Cannot find HTTP status code $status}
		return 0
	}

	if {[_can_redirect]} {
		core::view::add_header -name Status   -value $HTTP_STATUS($status)
		core::view::add_header -name Location -value $url
		_play_headers
	} else {
		set redirect [subst {<html><head><script>location.replace('$url')</script></head><body></body></html>}]
		core::view::write -str $redirect
	}

	return 1
}



#----------------------------------------------------------------------------
# Private Procedures
#----------------------------------------------------------------------------

# Determine's whether we can use a server redirect.
#
#   returns - 1 if the browser support redirection, 0 otherwise
#
proc core::view::_can_redirect args {

	set ua [core::request::_get_http_user_agent]

	if {[regexp -- {MSIE [1-6]\.[0-9]} $ua]} {
		return 0
	}

	return 1
}



# Actually play all of the headers to the template player. This includes
# setting cookies too.
#
#   returns - 1 if successful, 0 otherwise
#
proc core::view::_play_headers args {

	variable APP_CFG
	variable REQ_CFG
	variable REQ_HEADERS
	variable REQ_COOKIES

	core::gc::add ::core::view::REQ_CFG
	core::gc::add ::core::view::REQ_HEADERS
	core::gc::add ::core::view::REQ_COOKIES

	# If we have already played headers, we dont want to play them again in this
	# request.
	if {[info exists REQ_CFG(played_headers)]} {
		return 0
	}

	if {![info exists REQ_HEADERS(Content-Type,name)]} {
		core::log::write WARNING {VIEW: Warning Cannot find a Content-Type header}
	}

	# Need to figure out if we can/want to turn on appserv compression. If we do,
	# we need to add an extra header.
	if {[_use_compression]} {
		add_header -name "Content-Encoding" -value "gzip"
		tpBufCompress $APP_CFG(compress_level)
	}

	# Now set all of the headers
	foreach n [array names REQ_HEADERS "*,name"] {
		set hdr $REQ_HEADERS($n)
		core::log::write DEV {VIEW: _play_headers name=$hdr value=$REQ_HEADERS($hdr,value)}
		tpBufAddHdr $hdr $REQ_HEADERS($hdr,value)
	}

	# Set all of the cookies too
	foreach n [array names REQ_COOKIES "*,name"] {
		core::log::write DEV {VIEW: _play_headers cookie=$REQ_COOKIES($n)}
		tpBufAddHdr "Set-Cookie" [_build_cookie $REQ_COOKIES($n)]
	}

	set REQ_CFG(played_headers) 1

	return 1
}



# Does the web browser support compression?
#
#   returns - 1 if it does support compression, 0 otherwise
#
proc core::view::_use_compression args {

	variable APP_CFG

	if {!$APP_CFG(use_compression)} {
		return 0
	}

	set user_agent [core::request::_get_http_user_agent]

	# Ignore MS Internet Explorer 4. This seems to be common across all
	# customer screens/sportsbooks.
	if {[string first "MSIE 4" $user_agent] >= 0} {
		return 0
	}

	# Exclude browsers first, as certain browsers that we want to exclude
	# may contain in their user agent a string used to identify a browser that
	# we want to include
	foreach ua $APP_CFG(exclude_ua) {
		if {[string first $ua $user_agent] >= 0} {
			return 0
		}
	}

	set accept_encoding [string tolower \
		[core::request::_get_http_accept_encoding]]

	if {$accept_encoding != ""} {
		foreach e [split $accept_encoding ","] {
			if {[string trim $e] == "gzip"} {
				return 1
			}
		}
	}

	# Turn on compression for specific user agents.
	foreach ua $APP_CFG(include_ua) {
		if {[string first $ua $user_agent] >= 0} {
			return 1
		}
	}

	return 0
}



# Build a string for a cookie.
#
#   returns - cookie string
#
proc core::view::_build_cookie {name} {

	variable REQ_COOKIES

	core::gc::add core::view::REQ_COOKIES

	if {![info exists REQ_COOKIES($name,name)]} {
		error "VIEW: ERROR Cannot find cookie $name"
	}

	set cookie_str "$REQ_COOKIES($name,name)=$REQ_COOKIES($name,value)"

	# We always want the path set.
	append cookie_str "; path=$REQ_COOKIES($name,path)"

	# And now the expiry.
	if {$REQ_COOKIES($name,expires) != ""} {
		set expires [_format_expires_date $REQ_COOKIES($name,expires)]
		append cookie_str "; expires=$expires"
	}

	# And the domain.
	if {$REQ_COOKIES($name,domain) != ""} {
		append cookie_str "; domain=$REQ_COOKIES($name,domain)"
	}

	if {$REQ_COOKIES($name,secure)} {
		append cookie_str "; secure"
	}

	if {$REQ_COOKIES($name,http_only)} {
		append cookie_str "; HttpOnly"
	}

	return $cookie_str
}



# Build an expiry date for a cookie, based on cookie spec.
#
#   returns - expiry date string
#
proc core::view::_format_expires_date { expires } {

	# 10.1.2  Expires and Max-Age
	# Netscape's original proposal defined an Expires header that took a
	# date value in a fixed-length variant format in place of Max-Age:
	# Wdy, DD-Mon-YY HH:MM:SS GMT

	# (We could do this with a regexp, but that might make things *more* complicated.)
	set parts [split $expires { }]
	set timezone [lindex $parts 2]

	set ob_date [join [lrange $parts 0 1]]
	set seconds [clock scan $ob_date]

	set cookie_format {%a, %d %b %Y %H:%M:%S}
	set cookie_expires [clock format $seconds -format $cookie_format]

	append cookie_expires " $timezone"

	return $cookie_expires
}


# Check if a template is considered safe to play based on its filename.
#
# Callback registered with tpTmplFilter and invoked when tpTmplPlay is called
# with the filename (may be relative) of template that is to be played.
#
#    returns - true if safe to play the given template file, false if not.
#
proc core::view::_filter_template_path {tmpl_filename} {

	variable APP_CFG

	if {$APP_CFG(allowed_template_path) eq ""} {
		return 1
	}

	return [_is_file_within $tmpl_filename $APP_CFG(allowed_template_path)]
}

# Check if a file is inside a directory.
#
#    returns - true if file fname lies within the directory fpath
#              (including within sub-directories), or false otherwise.
#
# NB: will normalize fname and fpath, but won't check if they exist.
# 
proc core::view::_is_file_within {fname fpath} {
	set abs_fname [file normalize $fname]
	set abs_fpath [file normalize $fpath]
	set abs_fname_parts [file split $abs_fname]
	set abs_fpath_parts [file split $abs_fpath]
	set i 0
	foreach abs_fpath_part $abs_fpath_parts {
		set abs_fname_part [lindex $abs_fname_parts $i]
		if {![string equal $abs_fpath_part $abs_fname_part]} {
			return 0
		}
		incr i
	}
	if {$i == [llength $abs_fname_parts]} {
		# don't consider e.g. /a/b/c to be inside /a/b/c.
		return 0
	}
	return 1
}


# Dummy template path filter that allows all files to be played.
proc core::view::_dummy_template_path_filter {tmpl_filename} {
	return 1
}


#----------------------------------------------------------------------------
# Preprocess and Escaping Procedures
#----------------------------------------------------------------------------

# Deal with javascript.
#
proc core::view::preprocess_js { js_str } {

	variable TMPL_INIT
	variable APP_CFG

	if {!$TMPL_INIT} {tmpl_init}

	return "##TP_ESC $APP_CFG(escape_js)##${js_str}##TP_ESC##"
}

proc core::view::escape_js { js_str } {

	variable TMPL_INIT
	variable APP_CFG

	if {!$TMPL_INIT} {tmpl_init}

	return [$APP_CFG(escape_js) $js_str]
}

proc core::view::escape_js_appserv { js_str } {

	variable APP_CFG

	return [ot_js_encode $APP_CFG(encoding_flag) $js_str]
}

proc core::view::escape_js_tcl { js_str } {

	# Old escaping approach. Please use the latest version of the appserver
	set esc_js_map [list \
		"'"    "\\'"    \
		"\""   "\\\""   \
		"\\"   "\\\\"   \
		"\n"   "\\n"    \
		"\r"   "\\r"    \
		"</"   "<\\/"   \
	]

	return [string map $esc_js_map $js_str]
}

proc core::view::unescape_js { js_str } {

	variable APP_CFG

	return [ot_js_decode $APP_CFG(encoding_flag) $js_str]
}


# Deal with css.
#
proc core::view::preprocess_css { css_str } {
	return "##TP_ESC ::core::view::escape_css##${css_str}##TP_ESC##"
}

proc core::view::escape_css { css_str } {

	variable APP_CFG

	return [ot_css_encode $APP_CFG(encoding_flag) $css_str]
}

proc core::view::unescape_css { css_str } {

	variable APP_CFG

	return [ot_css_decode $APP_CFG(encoding_flag) $css_str]
}



# Deal with html.
#
proc core::view::preprocess_html { html_str } {

	variable TMPL_INIT
	variable APP_CFG

	if {!$TMPL_INIT} {tmpl_init}

	return "##TP_ESC $APP_CFG(escape_html)##${html_str}##TP_ESC##"
}

proc core::view::escape_html { html_str } {

	variable TMPL_INIT
	variable APP_CFG

	if {!$TMPL_INIT} {tmpl_init}

	return [$APP_CFG(escape_html) $html_str]
}

proc core::view::escape_html_appserv { html_str } {

	variable APP_CFG

	return [ot_html_encode $APP_CFG(encoding_flag) $html_str]
}

proc core::view::escape_html_tcl { html_str } {

	# Old escaping approach. Please use the latest version of the appserver
	set esc_html_map [list \
		"<"    "&lt;"   \
		">"    "&gt;"   \
		"\""   "&quot;" \
		"'"    "&#39;"  \
	]

	# Prevent it substituting for html characters, i.e. leave &amp;
	# &#41; &65; alone.
	regsub -all {&(?!(#\d+|#x[::xdigit::]+|\w+);)} $html_str {\&amp;} html_str

	return [string map $esc_html_map $html_str]
}

# Unescape escaped html
proc core::view::unescape_html {escaped_html} {

	variable APP_CFG

	return [ot_html_decode $APP_CFG(encoding_flag) $escaped_html]
}


# Do not do any escaping
proc core::view::preprocess_raw { raw_str } {
	set_current_escaping "NONE"
	return $raw_str
}


# Public accessor to what the current escaping is in the sense
# of the core::view package
#
proc core::view::get_current_escaping {} {

	variable REQ_ESC
	core::gc::add core::view::REQ_ESC

	if {[info exists REQ_ESC(mode)]} {
		return $REQ_ESC(mode)
	}

	return "NONE"
}


# Memorize what the current escaping is.
# Can be called as many times as required.
#
proc core::view::set_current_escaping {mode} {

	variable REQ_ESC
	core::gc::add core::view::REQ_ESC

	set REQ_ESC(mode) $mode
}


# Have we played the headers to the buffer?
# @return boolean
core::args::register \
	-proc_name core::view::has_played_headers \
	-body {
		variable REQ_CFG
		if {[info exists REQ_CFG(played_headers)] && $REQ_CFG(played_headers)} {
			return 1
		}

		return 0
	}
