# ==============================================================
# $Id: email.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.
# ==============================================================


namespace eval ADMIN::EMAIL {
}

##
# ADMIN::EMAIL::send_email - Simple wrapper for ezsmtp::send
#
# SYNOPSIS
#
#    [Admin_mail::send_email <from> <to> <subject> <body> \[<charset>\]]
#
# SCOPE
#
#    public
#
# PARAMS
#
#     [from] - 'Example <example@example.com>'
#
#     [to] - List of recipients
#
#     [subject]
#
#     [body] - message body
#
#    *[charset] - defaults to ""
#
#    *[type] - defaults to plain
#
# RETURN
#
#
#
# DESCRIPTION
#
#    Will use the CHARSET global if none is explicitly provided.
#    Errors should be caught in the calling procedure.
##
proc ADMIN::EMAIL::send_email {from to replyto subject body {charset ""} {type plain} {encode 0} } {

	global CHARSET

	if {$charset==""} {set charset $CHARSET}

	ob::log::write INFO {Sending email to: $to}

	lappend switches -from     $from
	lappend switches -tolist   $to
	lappend switches -replyto  $replyto
	lappend switches -subject  $subject
	lappend switches -charset  [expr {$charset=="gb2312"?"euc-cn":$charset}]

	if {$encode} {
		lappend switches -headers  [list Content-Type "text/${type}; charset=$charset" Content-Transfer-Encoding base64]
		lappend switches -body     [bintob64 $body]
	} else {
		lappend switches -headers  [list Content-Type "text/${type}"]
		lappend switches -body     $body
	}
	lappend switches -mailhost [OT_CfgGet SMTP_SERVER localhost]
	eval "ezsmtp::send $switches"
}
