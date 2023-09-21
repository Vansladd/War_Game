# $Id: wap.tcl,v 1.1 2011/10/04 12:23:20 xbourgui Exp $
#
# WAP utilities
#
# USE:
# namespace import OB_wap::*
# before using any of the procedures must call init_wap
#
# Required Config values:
#
# WML_VER (default 1.1)
# DO_METHOD
# STYLE_DIR
# CGI_URL
# GIF_URL
# WMLS_URL
# SESSION_ID
# NO_CHECK_LOGIN_ACTION (list of actions, separated by white space which deck_init will
#                        not call ob_check_login - default "")
# PREPROCESS_TEMPLATES (default Y)
#
# Optional config values:
#
# AFFILIATE_NAMES (space separated list of affiliates' names to check for in request's url - default "")
#
#
#
# LD_LIBRARY_PATH must include the directory specification of libcltxslt.so
# if PREPROCESS_TEMPLATES != Y
#
#
# Include:
# shared_tcl/err.tcl
# shared_tcl/login.tcl
#


namespace eval OB_wap {

	namespace export AGENT
	namespace export PAGE
	namespace export AFF_POSTFIELD

	namespace export init_wap
	namespace export deck_init

	namespace export play_deck
	namespace export play_error_deck

	namespace export wml_print_ccy
	namespace export wml_print_ccy_symbol

	namespace export page_details

	namespace export set_method
	namespace export get_method

# Procedures below are not recommended for use with multi-device WAP sites including Ladbrokes

	namespace export build_anchor
	namespace export build_postfield
	namespace export build_do

	namespace export cancel_anchor
	namespace export page_details

}
#
# initialise WAP stuff
#
proc OB_wap::init_wap {} {

	variable CFG

	set CFG(CARD_TITLE)            Y
	set CFG(VERSION)               [OT_CfgGet WML_VER               1.1]
	set CFG(METHOD)                [OT_CfgGet DO_METHOD             ""]
	set CFG(STYLE_DIR)             [OT_CfgGet STYLE_DIR]
	set CFG(GIF_URL)               [OT_CfgGet GIF_URL]
	set CFG(CGI_URL)               [OT_CfgGet CGI_URL]
	set CFG(WMLS_URL)              [OT_CfgGet WMLS_URL              ""]
	set CFG(SESSION_ID)            [OT_CfgGet SESSION_ID            "SESSION_ID"]
	set CFG(NO_CHECK_LOGIN_ACTION) [OT_CfgGet NO_CHECK_LOGIN_ACTION ""]
	set CFG(PREPROCESS_TEMPLATES)  [OT_CfgGet PREPROCESS_TEMPLATES  "Y"]
	set CFG(DISPLAY_XSLT_DATA)     [OT_CfgGet DISPLAY_XSLT_DATA     "N"]
	set CFG(DISPLAY_XSLT_RET)      [OT_CfgGet DISPLAY_XSLT_RET      "N"]
	set CFG(AFFILIATE_NAMES)       [OT_CfgGet AFFILIATE_NAMES       ""]
	set CFG(AFFILIATE_ID)	       [OT_CfgGet AFFILIATE_ID          "AFFILIATE_ID"]
	set CFG(HEAD_TEMPLATE)         [OT_CfgGet HEAD_TEMPLATE         ""]

	if {$CFG(METHOD) != ""} {
		tpBindString DO_METHOD -global $CFG(METHOD)
	}
	tpBindString GIF_URL -global   $CFG(GIF_URL)
	tpBindString CGI_URL -global   $CFG(CGI_URL)
	tpBindString WMLS_URL -global  $CFG(WMLS_URL)

	tpBindTcl ERROR -global {tpBufWrite "[join [err_get_list] "<br/>"]"}

	if {$CFG(PREPROCESS_TEMPLATES) != "Y"} {
		load "libtclxslt.so"
		load_styles
		tpBufAddHook OB_wap::xslt
	}
}
#
# load style sheets
# - stores all the loaded style filenames into the variable STYLES
#
proc OB_wap::load_styles {} {

	variable STYLES
	variable CFG

	foreach style [glob $CFG(STYLE_DIR)/*.xsl] {
		if {[regexp {([A-Za-z]+)\.xsl} $style all name]} {
			set STYLES($name) [xslt_parse $style]
		}
	}
}
#
# XSLT parser
# - parses the wml deck against a XML sheet stored in the variable STYLES
# - global AGENT must define the current AGENT name (must match an element
#   within STYLES)
#
proc OB_wap::xslt {data} {

	variable STYLES
	variable CFG
	global AGENT

	if {$CFG(DISPLAY_XSLT_DATA) == "Y"} {
	}

	#
	# Only XSLT those files with an XML header
	#
	if {[regexp {^<\?xml} $data all]} {
		set a [clock clicks]
		set ret [xslt_process $data $STYLES($AGENT)]

		#
		# hack to add the <!DOCTYPE....> tag
		#
		set i [string first "<!DOCTYPE wml" $ret]
		if {$i == -1} {
			set i [string first "?>" $ret]
			set ret \
				"<?xml version=\"1.0\"?><!DOCTYPE wml PUBLIC \"-//WAPFORUM//DTD WML 1.1//EN\" \"http://www.wapforum.org/DTD/wml_1.1.xml\">[string range $ret [expr $i + 2] [string length $ret]]"
		}

		regsub -all {&amp;} $ret {\&} ret2
		if {$CFG(DISPLAY_XSLT_RET) == "Y"} {
		}
		return $ret2
	}
	return $data
}
#
# initialise a WML deck
# - call within req_init
# - sets the global AGENT to current agent name (shares a name as stored
#   within CFG(STYLES))
# - sets the tpSetVar AGENT = AGENT
# - checks login status if action is not within CFG(NO_CHECK_LOGIN_ACTION)
#
proc OB_wap::deck_init {} {

	variable CFG
	global AGENT

	set user_agent [reqGetEnv HTTP_USER_AGENT]
	ob::log::write DEV {deck_init: user_agent=$user_agent}

	OB_wap::affiliates

	switch -glob -- $user_agent {
		*Nokia-WAP-Toolkit* {set AGENT toolkit}
		Nokia-MIT-Browser*  {set AGENT toolkit}
		Nokia*              {set AGENT nokia}
		WapIDE-SDK*         {set AGENT ericsson}
		Ericsson*           {set AGENT ericcson}
		SonyEricsson*       {set AGENT ericcson}
		*UP.Link*           {set AGENT uplink}
		WapTV*              {set AGENT waptv}
		Yospace*            {set AGENT yospace}
		*Palm*              {set AGENT palm}
		default             {set AGENT default}
	}

	ob::log::write DEV {OB_wap::deck_init => AGENT = $AGENT}
	tpSetVar AGENT $AGENT
	ob::log::write INFO {>>>>>>>>>>> action =  [reqGetArg action] CFGTHING =  $CFG(NO_CHECK_LOGIN_ACTION)}

	if {[string first [reqGetArg action] $CFG(NO_CHECK_LOGIN_ACTION)] == -1} {
		set status [ob_check_login]
		ob::log::write INFO {OB_Wap::deck_init => ob_check_login = $status}
	}
	err_reset
}

#
# play a WML deck
# where:
# -nosession              do not bind session id
# -bindsession            bind session id to CFG(SESSION_ID) (default)
# -add_wml                add <?xml...>, <!DOCTYPE...> & <wml> flags
# -noadd_wml              do not add wml flags (default)
# -cache <cache>          cache deck
# -nocache                no cache (default)
# -title <title>          card title
#                         if CFG(CARD_TITLE) == Y then, binds ##TP_CARD_TITLE##"
#                         else, does not bind ##TP_CARD_TITLE##
#
proc OB_wap::play_deck { deck args } {

	variable CFG
	global AGENT

	set add_wml        N
	set bind_session   Y
	set bind_affiliate Y
	set cache          ""
	set title          ""
	set head_template  N
	set sky_terminate  N
	set ll           [llength $args]

	for {set i 0} {$i < $ll} {incr i} {
		switch -exact -- [lindex $args $i] {
			-cache {
				incr i
				set cache [lindex $args $i]
			}
			-nocache {
				set cache ""
			}
			-add_wml {
				set add_wml Y
			}
			-noadd_wml {
				set add_wml N
			}
			-bind_affiliate {
				set bind_affiliate Y
			}
			-no_affiliate {
				set bind_affiliate N
			}
			-nosession {
				set bind_session N
			}
			-bindsession {
				set bind_session Y
			}
			-title {
				incr i
				set title [lindex $args $i]
			}
			-nohead_template {
				set head_template N
			}
			-head_template {
				set head_template Y
			}
			-sky_termination {
				set sky_terminate Y
			}
			default {
				set msg "play_deck: Unknown option ([lindex $args $i])"
				error $msg
			}
		}
	}

	if {$CFG(PREPROCESS_TEMPLATES) == "Y"} {
		set deck "$AGENT/$deck"
	}
	ob::log::write DEV {play_deck: deck=$deck}

	tpBufAddHdr "Content-Type" "text/vnd.wap.wml"
	if {$cache == ""} {
		tpBufAddHdr "Cache-Control" "no-cache"
	} else {
		tpBufAddHdr "Cache-Control" "max-age=$max_age"
	}

	if {$bind_session == "Y"} {
		tpBindString $CFG(SESSION_ID) [reqGetArg sid]
	}

	if {$bind_session == "Y"} {
		tpBindString $CFG(AFFILIATE_ID) [reqGetArg af]
	}

	if {$add_wml == "Y"} {
		tpBufWrite "<?xml version=\"1.0\"?>\n"
		tpBufWrite "<!DOCTYPE wml PUBLIC \"-//WAPFORUM//DTD WML 1.1//EN\" \"http://www.wapforum.org/DTD/wml_1.1.xml\">\n"
		tpBufWrite "<wml>\n"
	}

	if {$CFG(CARD_TITLE) == "Y"} {
		tpBindString CARD_TITLE $title
	}

	if {$head_template == "Y" && $CFG(HEAD_TEMPLATE) != ""} {
		uplevel #0 asPlayFile "$AGENT/$CFG(HEAD_TEMPLATE)"
	}

	uplevel #0 asPlayFile $deck

	if {$add_wml == "Y"} {
		tpBufWrite "\n</wml>\n"
	}

	if {$sky_terminate == "Y"} {
		tpBufWrite "\r\n\r\n"
	}
}

#
# play an error page
# where:
# -deck file-spec             deck to play (default error.wml)
# -title title                card title (binds CARD_TITLE)
# -msg error-message          error message (0..n)
#                             :added to err_list which is bound by TP_ERROR
#                             :call init_wap to bind to error
# -anchor anchor-spec         wml anchor specification (0..n)
#                             :bound to TP_ANCHORS
# -back                       denote if </prev> task is added (default)
#                             :sets variable PREV = Y
# -noback                     denote that </prev> task is not added
#                             :sets variable PREV = N
# -nosession                  do not bind session id
# -bindsession                bind session id to CFG(SESSION_ID) (default)
# -add_wml                    add <?xml...>, <!DOCTYPE...> & <wml> flags
# -noadd_wml                  do not add wml flags (default)
# -cache <cache>              cache deck
# -nocache                    no cache (default)
#
proc OB_wap::play_error_deck args {

	variable CFG

	ob::log::write DEV {play_error_deck:}

	set deck "error.wml"
	set title ""
	set anchors ""
	set prev "Y"
	set cache "-nocache"
	set add_wml "-noadd_wml"
	set session_action "-bindsession"
	set title ""
	set ll [llength $args]

	for {set i 0} {$i < $ll} {incr i} {
		switch -exact -- [lindex $args $i] {
			-deck {
				incr i
				set deck [lindex $args $i]
			}
			-title {
				incr i
				set title [lindex $args $i]
			}
			-msg {
				incr i
				err_add [lindex $args $i]
			}
			-anchor {
				incr i
				append anchors [lindex $args $i]
			}
			-noback {
				set prev "N"
			}
			-back {
				set prev "Y"
			}
			-bindsession {
				set session_action "-bindsession"
			}
			-nosession {
				set session_action "-nosession"
			}
			-cache {
				incr i
				set cache [lindex $args $i]
			}
			-nocache {
				set cache "-nocache"
			}
			-add_wml {
				set add_wml "-add_wml"
			}
			-noadd_wml {
				set add_wml "-noadd_wml"
			}
			default {
				set msg "play_error_deck: Unknown option ([lindex $args $i])"
				error $msg
			}
		}
	}

	if {$anchors != ""} {
		tpBindString ANCHORS $anchors
	}
	tpSetVar PREV $prev

	if {$cache == "-nocache"} {
		play_deck $deck $session_action $add_wml -title $title
	} else {
		play_deck $deck $session_action $add_wml -cache $cache -title $title
	}
}

#
# build an anchor
# where
# -description text     anchor text
# -title text           anchor title
# -pbreak               use <br/> instead of <p>...</p>
# -nopbreak             use <p>...</p> (default)
# -nop                  dont't use <p> or </p>
# -p                    use <p> or <br/> (default)
# -postfield name/value name/value (0..n)
# -postfield_list list  list of name/value delimited by ^
# -nosession            do not add session id
# -bindsession          bind a session ID to CFG(SESSION_ID) (default)
# -newsession id        new session ID
# -bufwrite             write anchor using tpBufWrite
# -nobufwrite           return anchor (default)
#
proc OB_wap::build_anchor args {

	variable CFG
	global LOGIN_DETAILS AGENT AFF_POSTFIELD

	set description    ""
	set title          ""
	set postfield      ""
	set pbreak         "<p>"
	set pbreak_end     "</p>"
	set p              Y
	set session_action "-bindsession"
	set new_id         ""
	set buf_write      N

	set ll [llength $args]

	for {set i 0} {$i < $ll} {incr i} {
		switch -exact -- [lindex $args $i] {
			-description {
				incr i
				set description [lindex $args $i]
			}
			-title {
				incr i
				set title [lindex $args $i]
			}
			-pbreak {
				set pbreak "<br/>"
				set pbreak_end ""
			}
			-nopbreak {
				set pbreak "<p>"
				set pbreak_end "</p>"
			}
			-nop {
				set p N
			}
			-p {
				set p Y
			}
			-nobufwrite {
				set buf_write N
			}
			-bufwrite {
				set buf_write Y
			}
			-bindsession {
				set session_action "-bindsession"
			}
			-nosession {
				set session_action "-nosession"
			}
			-newsession {
				incr i
				set new_id [lindex $args $i]
				set session_action "-newsession"
			}
			-postfield {
				incr i
				# XXXX (hack around no subst in TP_TCL XXXX
				append postfield [build_postfield [subst [lindex $args $i]]]
			}
			-postfield_list {
				incr i
				set list [split [lindex $args $i] "^"]
				set l_list [llength $list]
				for {set j 0} {$j < $l_list} {incr j} {
					append postfield [build_postfield [lindex $list $j]]
				}
			}
			default {
				set msg "build_anchor: Unknown option ([lindex $args $i])"
				error $msg
			}
		}
	}

	if {$p != "Y"} {
		set pbreak     ""
		set pbreak_end ""
	}
	set anchor $pbreak
	append anchor "<anchor"
	if {$title != ""} {
		append anchor " title=\"$title\""
	}
	if {$AGENT == "waptv"} {
		append anchor "><img localsrc=\"a\" align=\"middle\" src=\"a\" alt=\"a\"/>$description"
	} else {
		append anchor ">$description"
	}
	append anchor "<go method=\"$CFG(METHOD)\" href=\"$CFG(CGI_URL)\">"
	append anchor $postfield

	if {$session_action == "-bindsession"} {
		append anchor [build_postfield "sid/[reqGetArg sid]"]
	} elseif {$session_action == "-newsession"} {
		append anchor [build_postfield "sid/$new_id"]
	}

	append anchor $AFF_POSTFIELD

	append anchor "</go></anchor>$pbreak_end"

	if {$buf_write == "Y"} {
		tpBufWrite $anchor
		return
	}

	return $anchor
}

#
# construct a postfield
# where field = name/value
#
proc OB_wap::build_postfield { field } {

	set f [split $field "/"]
	set postfield "<postfield name=\"[lindex $f 0]\" value=\""
	set ll [llength $f]
	for {set i 1} {$i < $ll} {incr i} {
		if {$i != 1} {
			append postfield "/"
		}
		append postfield [lindex $f $i]
	}
	append postfield "\"/>"
	return $postfield
}

#
# build a <do type="option"...
# where
# -label label            do label
# -name name              do name (optional)
# -postfield name/value   postfield (0..n)
# -postfield_list list    list of name/value delimited by ^
# -nosession              do not add session id
# -bindsession            add a session id (default)
# -newsession id          new session ID
# -type type              type (default options)
# -bufwrite             write anchor using tpBufWrite
# -nobufwrite           return anchor (default)
#
proc OB_wap::build_do args {

	variable CFG
	global LOGIN_DETAILS AFF_POSTFIELD

	set label          ""
	set name           ""
	set postfield      ""
	set session_action "-bindsession"
	set new_id         ""
	set type           "options"
	set buf_write      N

	set ll [llength $args]

	for {set i 0} {$i < $ll} {incr i} {
		switch -exact -- [lindex $args $i] {
			-label {
				incr i
				set label "label=\"[lindex $args $i]\""
			}
			-name {
				incr i
				set name "name=\"[lindex $args $i]\""
			}
			-postfield {
				incr i
				# XXXX (hack around no subst in TP_TCL XXXX
				append postfield [build_postfield [subst [lindex $args $i]]]
			}
			-bindsession {
				set session_action "-bindsession"
			}
			-nobufwrite {
				set buf_write N
			}
			-bufwrite {
				set buf_write Y
			}
			-nosession {
				set session_action "-nosession"
			}
			-newsession {
				incr i
				set new_id [lindex $args $i]
				set session_action "-newsession"
			}
			-postfield {
				incr i
				append postfield [build_postfield [lindex $args $i]]
			}
			-postfield_list {
				incr i
				set list [split [lindex $args $i] "^"]
				set l_list [llength $list]
				for {set j 0} {$j < $l_list} {incr j} {
					append postfield [build_postfield [lindex $list $j]]
				}
			}
			-type {
				incr i
				set type [lindex $args $i]
			}
			default {
				set msg "build_do: Unknown option ([lindex $args $i])"
				error $msg
			}
		}
	}

	set do "<do type=\"$type\" $name $label>"
	append do "<go method=\"$CFG(METHOD)\" href=\"$CFG(CGI_URL)\">"
	append do $postfield

	if {$session_action == "-bindsession"} {
		append do [build_postfield "sid/[reqGetArg sid]"]
	} elseif {$session_action == "-newsession"} {
		append do [build_postfield "sid/$new_id"]
	}

	append do $AFF_POSTFIELD

	append do "</go></do>"

	if {$buf_write == "Y"} {
		tpBufWrite $do
		return
	}

	return $do
}

#
# return a cancel anchor
#
proc OB_wap::cancel_anchor { action {pbreak "-pbreak"} {session_action "-bindsession"} {new_id ""} } {

	if {$session_action == "-newsession"} {
		return [build_anchor -description "Cancel" \
					-title "Cancel" \
					$pbreak \
					$session_action $new_id \
					-postfield "action/$action"]
	} else {
		return [build_anchor -description "Cancel" \
					-title "Cancel" \
					$pbreak \
					$session_action \
					-postfield "action/$action"]
	}
}

#
# Print a currency amount
#
proc OB_wap::wml_print_ccy { amt {ccy_code GBP} {less_than_one_special 0}} {

	global LOGIN_DETAILS

	if {$amt==""} {
		return ""
	}

	if {$ccy_code=="DEFAULT"} {
		if [info exists LOGIN_DETAILS(CCY_CODE)] {
			set ccy_code $LOGIN_DETAILS(CCY_CODE)
		} else {
			set ccy_code [OT_CfgGet DEFAULT_CCY "GBP"]
		}
	}

	set output ""
	if {$amt < 0} {
		append output "-"
		set amt [expr {0 - $amt}]
	}

	switch -- $ccy_code {
		"GBP"   {
			if { $amt < 1 && $less_than_one_special == 1} {
				append output "[expr {round($amt*100)}]p"
			} else {
				append output [wml_print_ccy_symbol $ccy_code]
				append output "[comma_num_str [format {%.2f} $amt]]"
			}
		}
		default {
			append output [wml_print_ccy_symbol $ccy_code]
			append output "[comma_num_str [format {%.2f} $amt]]"
		}
	}

	return $output
}

#
# print a currency symbol
#
proc OB_wap::wml_print_ccy_symbol { {ccy_code GBP} } {

	global LOGIN_DETAILS

	if {$LOGIN_DETAILS(CHANNEL)=="O" || $LOGIN_DETAILS(CHANNEL)=="S"} {
		set euro "&#xA4;"
	} else {
		set euro "EUR "
	}

	switch -- $ccy_code {
		"GBP"   { set output "&#163;"}
		"IEP"   { set output "IR&#163;"}
		"USD"   { set output "$$"}
	"EUR"   { set output "$euro"}
		default { set output "$ccy_code&nbsp;"}
	}
	return $output
}

#
# get & set page details
#
proc OB_wap::page_details { total_rows max_size } {

	global PAGE

	set PAGE(max)        $max_size
	set PAGE(next_start) 0
	set PAGE(prev_start) 0
	set PAGE(fields)     "max total no start end next_start prev_start next prev"

	if {$total_rows} {
		set PAGE(start) [reqGetArg s]
		if {$PAGE(start) == ""} {
			set PAGE(start) 0
		}
		set PAGE(end) [expr $PAGE(start) + $max_size]
		if {$PAGE(end) > $total_rows} {
			set PAGE(end) $total_rows
		}
		set PAGE(total) [format "%d" [expr ($total_rows / $max_size)]]
		if {[expr $total_rows % $max_size] != 0} {
			incr PAGE(total)
		}
		set PAGE(no) [format "%d" [expr ($PAGE(start) + $max_size) / $max_size]]
		if {$PAGE(no) != $PAGE(total)} {
			set PAGE(next) Y
			set PAGE(next_start) [expr $PAGE(start) + $max_size]
		} else {
			set PAGE(next) N
		}
		if {$PAGE(no) != 1} {
			set PAGE(prev) Y
			set PAGE(prev_start) [expr $PAGE(start) - $max_size]
		} else {
			set PAGE(prev) N
		}
	} else {
		set PAGE(total)      0
		set PAGE(start)      0
		set PAGE(end)        0
		set PAGE(next)       N
		set PAGE(prev)       N
		set PAGE(no)         0
	}

	ob::log::write DEV {page_details:}
	ob::log::write_array DEV PAGE

	tpBindTcl PAGE_NO "tp_write PAGE no"
	tpBindTcl PAGE_START "tp_write PAGE start"
	tpBindTcl PAGE_TOTAL "tp_write PAGE total"
	tpBindTcl NEXT_START "tp_write PAGE next_start"
	tpBindTcl PREV_START "tp_write PAGE prev_start"
}

#
# set METHOD
#
proc OB_wap::set_method { method } {

	variable CFG
	if {$method != "post" && $method != "get"} {
		error "set_method: invalid argument"
	}
	set CFG(METHOD) $method
	tpBindString DO_METHOD -global $CFG(METHOD)
}

#
# get the METHOD
#
proc OB_wap::get_method {} {

	variable CFG
	return $CFG(METHOD)
}

#
# Sorts out affiliates
#

proc OB_wap::affiliates {} {

	global AFF_POSTFIELD
	variable CFG

	set aff_pfield ""

	set affiliates_val [reqGetArg affiliates]

	#check if any affiliates are incoming; if so, add to list
	foreach f $CFG(AFFILIATE_NAMES) {
		set value [reqGetArg $f]
		if {$value != "" && [string first $f $affiliates_val] == -1} {
			if {$aff_pfield != ""} {
				append aff_pfield "^"
			}

			append aff_pfield "$f/$value"
		}
	}

	if {$affiliates_val == ""} {
		append affiliates_val $aff_pfield
	} else {
		if {$aff_pfield != ""} {
			append affiliates_val "^$aff_pfield"
		}
	}

	if {$CFG(AFFILIATE_NAMES) == "" || $affiliates_val == ""} {
		tpBindString AFF_POSTFIELD ""
		set AFF_POSTFIELD ""
	} else {
		tpBindString AFF_POSTFIELD "<postfield name='affiliates' value='$affiliates_val'/>"
		set AFF_POSTFIELD "<postfield name='affiliates' value='$affiliates_val'/>"
	}

}
