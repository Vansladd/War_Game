# $Id: xl-compat.tcl,v 1.1 2011/10/04 12:24:33 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
#
# Handle multi-lingual compatibility with non-package APIs.
#
# The package provides wrappers for each of the older APIs which are potentially
# still been used within other shared_tcl files or the calling application.
# Avoid calling the wrapper APIs within your applications, always use the
# util_xl package (ob_xl namespace).
#
# The package should always be loaded when using util_xl 4.5 package.
# Do not source mlang.tcl when using the XL packages.
#
# Configuration:
#    XL_DEFAULT_CHARSET       default character set   (iso8859-1)
#
#
# Synopsis:
#    package require util_db_compat ?4.5?
#
# Procedures:
#    ob_xl_compat::set_lang   set the current language
#    ob_xl_compat::get_lang   get the current language
#
# Wrapper Procedures (all exported):
#    OB_mlang::ml_init        one time initialisation
#    OB_mlang::ml_printf      formatted code translation
#    OB_mlang::XL             translate a phrase
#    OB_mlang::ml_set_lang    set current language (not supported)
#    OB_mlang::subst_xth      Translate the Xth for certain markets
#

package provide util_xl_compat 4.5



# Dependencies
#
package require util_xl      4.5
package require util_log     4.5
package require util_control 4.5



# Variables
#
namespace eval ob_xl_compat {

	variable XL
	variable CFG
	variable INIT

	# set request number
	set XL(req_no) -1

	# initialise flag
	set INIT 0
}



# Export old namespace APIs
#
namespace eval OB_mlang {

	namespace export ml_init
	namespace export ml_printf
	namespace export XL
	namespace export ml_set_lang
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# One time initialisation
#
proc ob_xl_compat::init args {

	variable CFG
	variable INIT

	# already initialised?
	if {$INIT} {
		return
	}

	# init dependencies
	ob_xl::init
	ob_log::init
	ob_control::init

	# get configuration
	set CFG(default_charset) [OT_CfgGet XL_DEFAULT_CHARSET "iso8859-1"]
	set CFG(xth_market_sort) [OT_CfgGet XL_XTH_MARKET_SORT "CW"]

	# initialised
	set INIT 1
}



#--------------------------------------------------------------------------
# Current Language
#--------------------------------------------------------------------------

# Set the current language code and store in the package cache (scope of a
# request).
#
# This must be called within req_init to support backwards compliance. It is the
# callers responsibility to get the language code, as the package does not
# manipulate HTML/WML forms and/or HTTP cookies. However, DO NOT get the
# language from the login cache, e.g. ob_login::get lang, as this will result
# in a unnecessary database call on each request (see login package for
# further details). Use either a cookie or a form argument.
#
# The language code has a life-time of a request, if not set on subsequent
# requests, the current language will be set to the tControl.default_lang.
#
# Procedure will set the global LANG and CHARSET (if requested).
#
#   lang        - current language (default - "")
#                 if not defined, then set to tControl.default_lang
#   set_charset - set the global CHARSET (default - 0)
#                 if set to non-zero, then the global is set the current lang'
#   returns     - set language code
#
proc ob_xl_compat::set_lang { {lang ""} {set_charset 0} } {

	global LANG CHARSET
	variable XL
	variable CFG

	# set language, if not defined, get from control table
	if {$lang != ""} {
		set XL(lang) $lang
	} else {
		set XL(lang) [ob_control::get default_lang]
	}
	set LANG $XL(lang)

	# current language has the scope of a request
	set XL(req_no) [reqGetId]

	# set charset
	if {$set_charset} {
		set CHARSET [ob_xl::get charset $XL(lang) $CFG(default_charset)]
	}

	return $XL(lang)
}



# Get the current language code.
#
# Returns the language code previously set via ob_xl_compat::get_lang within the
# scope of a request. If a new request and the code has not been set,
# tControl.default_lang will be used.
#
#   returns - current language
#
proc ob_xl_compat::get_lang args {

	variable XL

	# if different request, set to default language
	if {$XL(req_no) != [reqGetId]} {

		set_lang
		ob_log::write WARNING \
		    {XL: current language not set, using default - $XL(lang)}
	}

	return $XL(lang)
}



#--------------------------------------------------------------------------
# Old namespace wrappers
#--------------------------------------------------------------------------

# One time initialisation
#
proc OB_mlang::ml_init args {
}



# Translate a xlate code
#
#   code    - xlate code
#   args    - format arguments
#             ignored if the translation text contains no specifiers
#   returns - translation text if found; otherwise the code
#
proc OB_mlang::ml_printf { code args } {
	return [eval {ob_xl::sprintf [ob_xl_compat::get_lang] $code} $args]
}



# Translates all symbols marked up for translation in the given phrase
#
#   str     - phrase to translate
#   returns - translated phrase
#
proc OB_mlang::XL { str } {
	return [ob_xl::XL [ob_xl_compat::get_lang] $str]
}



# Set the default language.
# util_xl and util_xl_compat packages does not handle HTML/WML forms and HTTP
# cookies.
# Use ob_xl_compat::set_lang instead
#
#   lang    - default language
#   charset - default character set
#
proc OB_mlang::ml_set_lang { {lang ""} {charset ""} } {
	error "Not supported - OB_mlang::ml_set_lang"
}


# Translate the Xth for certain markets
# For instance, "To score Xth goal", if bir_idx is 5, will be converted to
# "To score 5th goal".
#
#   code     - xlate code
#   lang     - language code
#   idx      - format arguments
#              ignored if the translation text contains no specifiers
#   mkt_sort - market sort
#   returns  - translation text if found; otherwise the code
#
#
proc OB_mlang::subst_xth {text lang idx mkt_sort} {

	variable ::ob_xl_compat::CFG

	if {[lsearch $CFG(xth_market_sort) $mkt_sort] != -1} {
		set idx [ob_xl::sprintf $lang IDX_$idx]
		regsub -all {[X|x]th} $text $idx text
	}
	return $text
}



# Translate the Xth for certain markets
# For instance, "To score Xth goal", if bir_idx is 5, will be converted to
# "To score 5th goal".
#
#   code     - xlate code
#   lang     - language code
#   idx      - format arguments
#              ignored if the translation text contains no specifiers
#   mkt_sort - market sort
#   returns  - translation text if found; otherwise the code
#
#
proc OB_mlang::subst_xth {text lang idx mkt_sort} {

	variable ::ob_xl_compat::CFG

	if {[lsearch $CFG(xth_market_sort) $mkt_sort] != -1} {
		set idx [ob_xl::sprintf $lang IDX_$idx]
		regsub -all {[X|x]th} $text $idx text
	}
	return $text
}



#--------------------------------------------------------------------------
# Start up
#--------------------------------------------------------------------------

# automatically initialise the package
ob_xl_compat::init