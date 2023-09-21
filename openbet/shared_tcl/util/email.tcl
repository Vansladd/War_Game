# $Id: email.tcl,v 1.1 2011/10/04 12:24:32 xbourgui Exp $
# © 2007 Orbis Technology Ltd. All rights reserved.
#
# Provides convinience method for sending emails.
# Specifically, it improves on ezsmtp by providing a better method of sending
# emails with HTML and plain text versions, as well as providing support for
# different charsets and encodings.
#
# Synopsis:
#   package require util_email ?0.1?
#
# Configuration:
#   EMAIL_SERVERS - The servers to use for sending email, defaults to
#                   SMTP_SERVER if specified, or localhost if not.
#   EMAIL_XMAILER - Default X-Mailer.
#   EMAIL_FROM    - Default from address.
#   EMAIL_QUEUE   - Whether to queue message for later sending (1).
#
# Procedures:
#   ob_email::init - Initialise
#   ob_email::send - Sends an email.
#   ob_email::is_valid_email - The validity of an email address.
#   ob_email::plain_to_html - Convert plain to simple HTML.
#   ob_email::html_to_plain - Convert HTML to plain.
#
# See also:
#   http://www.tcl.tk/community/tcl2004/Tcl2003papers/kupries-doctools/tcllib.doc/mime/mime.html
#   http://www.tcl.tk/community/tcl2004/Tcl2003papers/kupries-doctools/tcllib.doc/mime/smtp.html
#
#   SourceForge Tcllib Bug 447037
#

package provide util_email 4.5



# Dependecies
#
package require mime 1.3.1
package require smtp 1.3.1

package require util_log



# Variables
#
namespace eval ob_email {

	variable CFG
	variable INIT 0
}



#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

# Initiliase the namespace, pulling in the args into the main space
#
proc ob_email::init args {

	variable CFG
	variable INIT

	if {$INIT} {
		return
	}

	ob_log::init

	foreach {n v} $args {
		set CFG([string trimleft $n -]) $v
	}

	foreach {n v} [list \
		servers  [OT_CfgGet EMAIL_SERVERS \
			[list [OT_CfgGet SMTP_SERVER localhost]]] \
		xmailer  OpenBet \
		queue    1 \
	] {
		if {![info exists CFG($n)]} {
			set CFG($n) [OT_CfgGet "EMAIL_[string toupper $n]" $v]
		}
	}

	if {$CFG(servers) == ""} {
		error "You must specify some servers"
	}

	if {$CFG(xmailer) == ""} {
		error "You must specify an xmailer"
	}

	if {[info commands OT_UniqueId] == ""} {
		error "OT_UniqueId not available"
	}

	_prep_qrys

	set INIT 1
}



proc ob_email::_prep_qrys args {

	# Get the email body from the db
	ob_db::store_qry get_email_details {
		select
			e.from_code,
			b.subject,
			b.body_id,
			b.email_id,
			b.body_seq_id,
			b.cr_date,
			b.language,
			b.body,
			b.format
		from
			tEmailType t,
			tEmail e,
			tEmailBody b
		where
			e.email_id = b.email_id and
			e.type     = t.type_id and
			t.name     = ? and
			b.language = ? and
			b.format   = ?
		order by b.body_id;
	}


	# queues an email in the database for sending via the emailer
	# standalone app.
	ob_db::store_qry ob_email::queue_email {
		execute procedure pInsEmailQueue (
			p_email_type = ?,
			p_cust_id	 = ?,
			p_msg_type	 = ?,
			p_ref_key	 = ?,
			p_ref_id	 = ?,
			p_reason	 = ?
		);
	}
}



#--------------------------------------------------------------------------
# Procedures
#--------------------------------------------------------------------------

# Sends an email. The email can be plain, HTML or both, depending on which
# options are specified. Pay special attention to the quote of email addresses.
#
# For options such as CC and BCC, you can specify these as headers using
# -header.
#
#   -recipients  - List of one or more recipients to send the email to,
#                  e.g. john.doe@customer.co.uk
#                  If unspecifed, defaults to the to address.
#   -from        - The from address of the email,
#                  e.g. "Bookmaker Customer Support <support@bookmaker.com>"
#                  If this is not specified (see config).
#   -to          - The to address of the email,
#                  e.g. "John Doe <john.doe@customer.com>"
#   -subject     - The subject of the email.
#   -plain       - Optional plaintext of the email's body.
#   -html        - Optional HTML of the email's body.
#   -header      - Header
#   -attachment  - a list of filenames and content
#   -encoding    - Optional encoding type. e.g. base64  (see config)
#   -charset     - Optional charset of the plaintext and email.
#                  It is assumed that both plaintext and HTML parts are in
#                  the same charset and encoding  (see config).
#   -xmailer     - Optional X-Mailer header (see config).
#
# The procedure also checks the attachments, if any of the filenames appear
# in the html in quotes then, this is replaced with a reference to the
# attachement, this means that images sent as attachments, will appear as
# inline pictures.
#
proc ob_email::send args {

	variable CFG

	# parse the arguments

	set EMAIL(headers)      [list]
	set EMAIL(attachments) [list]

	# parse the args
	foreach {n v} $args {
		if {$n == "-header"} {
			# we want a flattened list
			eval lappend EMAIL(headers) $v
		} elseif {$n == "-attachment"} {
			# we want a flattened list
			eval lappend EMAIL(attachments) $v
		} else {
			set EMAIL([string trimleft $n -]) $v
		}
	}

	# check the required args are specified
	if {![info exists EMAIL(to)] || $EMAIL(to) == ""} {
		error "argument to is absent or blank"
	}

	# if the following options are missing, get them from cfg or system
	foreach {n v} [list       \
		encoding   8bit              \
		charset    [encoding system] \
		recipients $EMAIL(to)        \
	] {
		if {![info exists EMAIL($n)]} {
			set EMAIL($n) $v
		}
	}

	foreach n {to from subject recipients subject} {
		if {![info exists EMAIL($n)] || $EMAIL($n) == ""} {
			ob_log::write ERROR {argument/config item $n is absent or blank}
			error "argument/config item $n is absent or blank"
		}
	}

	foreach n {plain html} {
		if {[info exists EMAIL($n)] && $EMAIL($n) == ""} {
			error "argument $n is blank"
		}
	}
	if {![info exists EMAIL(plain)] && ![info exists EMAIL(html)]} {
		error "must specify either -plain or -html"
	}

	# standard content types, add more here if needs be
	array set CONTENT_TYPE {
		html text/html
		xml  text/xml
		txt  text/plain
		css  text/css
		js   text/javascript
		gif  image/gif
		jpg  image/jpg
		png  image/png
		bmp  image/bmp
		csv  text/comma-separated-values
	}

	# check the attachments are of know types
	foreach {filename content type} $EMAIL(attachments) {
		set extension [string trimleft [file extension $filename] .]
		if {![info exists CONTENT_TYPE($extension)]} {
			error "Content type for file type $extension is unknown"
		}
	}

	# make sure images which are not-prefixed with http are referencing the
	# email's insides
	if {[info exists EMAIL(html)]} {
		# if the image in in quotes, then make it reference the attachment,
		# i.e. <img src="orbis.gif"> becomes <img srg="cid:orbis.gif"> and is
		# visible in the email
		foreach {filename filecontent} $EMAIL(attachments) {
			set filetail  [file tail $filename]
			regsub "\"$filetail\"" $EMAIL(html) "\"cid:$filetail\"" EMAIL(html)
		}
	}

	# IMPORTANT: must clean up after this point, all code after here must be
	# thoroughly tested, as it will produce memory leaks othewise

	# we must log all communication with external systems,
	ob_log::write INFO \
		{email: sending email from $EMAIL(from), recipients \
		$EMAIL(recipients), subject '$EMAIL(subject)'}

	ob_log::write_array DEBUG EMAIL

	# prepare the mime parts

	# create the suitable token, either a multipart/alternative
	# if both html and plain are specified,
	# a text/plain if -plain only is specified or
	# a text/html if -html is specified
	if {[info exists EMAIL(plain)] && [info exists EMAIL(html)]} {

		set parts [list \
			[mime::initialize \
				-canonical text/plain \
				-string    $EMAIL(plain) \
				-encoding  $EMAIL(encoding) \
				-param     [list charset $EMAIL(charset)] \
			] \
			[mime::initialize \
				-canonical text/html \
				-string    $EMAIL(html) \
				-encoding  $EMAIL(encoding) \
				-param     [list charset $EMAIL(charset)] \
			] \
		]

		set token [mime::initialize \
			-canonical multipart/alternative \
			-parts     $parts \
		]

	} elseif {[info exists EMAIL(html)]} {

		set token [mime::initialize \
			-canonical text/html \
			-string    $EMAIL(html) \
			-encoding  $EMAIL(encoding) \
			-param     [list charset $EMAIL(charset)] \
		]

	} elseif {[info exists EMAIL(plain)]} {

		set token [mime::initialize \
			-canonical text/plain \
			-string    $EMAIL(plain) \
			-encoding  $EMAIL(encoding) \
			-param     [list charset $EMAIL(charset)] \
		]

	}

	# add attachments
	if {[llength $EMAIL(attachments)]} {
		set parts [list $token]

		# add each of the attachments
		foreach {filename filecontent} $EMAIL(attachments) {

			ob_log::write DEBUG {email: attaching $filename}

			# we need to find out the extenstion
			set filetail  [file tail $filename]
			set extension [string trimleft [file extension $filename] .]

			lappend parts [mime::initialize \
				-canonical "$CONTENT_TYPE($extension); name=\"$filetail\"" \
				-header    [list Content-ID "<$filetail>"] \
				-header    "Content-Disposition attachment" \
				-string    $filecontent \
			]
		}

		set token [mime::initialize \
			-canonical multipart/mixed \
			-parts     $parts \
		]
	}

	set cmd [list \
		smtp::sendmessage \
			$token \
			-servers    $CFG(servers) \
			-queue      $CFG(queue) \
			-recipients $EMAIL(recipients) \
			-header     [list Date     [clock format [clock seconds] -gmt 1]] \
			-header     [list X-Mailer $CFG(xmailer)] \
			-header     [list From     $EMAIL(from)] \
			-header     [list To       $EMAIL(to)] \
			-header     [list Subject  $EMAIL(subject)] \
			-header     [list X-OBUID  [OT_UniqueId]]
	]

	# add extra headers
	foreach {name value} $EMAIL(headers) {
		lappend cmd -header [list $name $value]
	}

	# an error may occur, but we still need to clean up
	set caught [catch {
		# evaluate the command with extra headers
		eval $cmd
	} msg]

	# clear up

	# using subordinates also finalizes the attachments
	mime::finalize $token -subordinates all

	if {$caught} {
		error $msg
	}
}



# Checks to see if the email address is validly formatted.
#
#   email   - The email address to check.
#   returns  - Wether or not the address is valid.
#
proc ob_email::is_valid_email {email} {

	set RX \
		{^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$}

	return [regexp $RX $email]
}



# Make an HTML email all plain.
#
# <br>   to \n
# <p|h?> to \n
# <a href="...">...</a> to ... (...)
#
#   html    - html to strip
#   returns - plain text
#
proc ob_email::html_to_plain {html} {

	# they are using break/para. remove lines breaks
	regsub {\n} $html {} html

	regsub -all {<br>} $html {\n} html

	foreach tag {p h1 h2 h3 h4 h5 h6 div} {
		# non greedy regexp
		regsub -all [format {<%s[^>]*>(.*?)</%s>} $tag $tag] {\1\n} html
	}
	regsub -all {<hr>} $html {---} html

	# links, non-greedy, backreferenced
	regsub -all {<a href=(.)(.*?)\1[^>]*>(.*?)</a>} $html {\3 (\2)\n} html

	# remove all others, regexp non-greedy with back reference
	regsub -all {<([^ >]+)[^>]*>(.*?)</\1>} $html {\2} html

	# remove anything else
	regsub -all {<[^>]*>} $html {} html

	return $html
}



# Make a plain email all HTML.
#
# \n      to <br>
# *xxx*   to <b>xxx</b>
# _xxx_   to <u>xxx</u>
# ---     to <hr>
# xxx.jpg to <img src="xxx.jpg">
#
#   plain   - plain text
#   returns - HTML
#
proc ob_email::plain_to_html {plain} {

	regsub -all {\n}           $plain {<br>}      plain
	regsub -all {\*([^\*]*)\*} $plain {<b>\1</b>} plain
	regsub -all {_([^_]*)_}    $plain {<u>\1</u>} plain

	foreach ext {gpf jpg png bmp} {
		regsub -all [format {([^ ]*\.%s)} $ext] $plain {<img src="\1">} plain
	}

	return $plain
}



# Returns:
#  On Error:   [list 0]
#  On Success: [list 1 $body $from $subject $format]
#
proc ob_email::get_email_details {type lang format} {

	# Attempt to get the email details
	if {[catch {set rs [ob_db::exec_qry get_email_details $type $lang $format]} err_msg]} {
		ob::log::write ERROR {Could not get email details ($err_msg)}
		return [list 0]
	}

	# Check that we actually got something back
	if {[db_get_nrows $rs] == 0} {
		ob::log::write ERROR {Could not find email details}
		ob_db::rs_close $rs
		return [list 0]
	}

	set body    {}
	set from    [ob_xl::sprintf $lang [db_get_col $rs 0 from_code]]
	set subject [ob_xl::sprintf $lang [db_get_col $rs 0 subject]]

	for {set i 0} {$i < [db_get_nrows $rs]} {incr i} {
		set fragment [db_get_col $rs $i body]
		while {$i < ([db_get_nrows $rs] - 1) && [string length $fragment] < 2048} {
			append fragment " "
		}
		append body $fragment
	}

	ob_db::rs_close $rs

	if {$format == {H}} {
		set format html
	} else {
		set format plain
	}

	return [list 1 $body $from $subject $format]
}



# Sends an of the given type to the address specified.
#
# type:      the type of the email (tEmailType.name)
# lang:      the language to send the email in
# format:    the format to send the message in:
#              H: HTML
#              P: Plain text
#              B: Both HTML and plain text
# sub:       a list of substitutions to apply to the email.
#            this should consist of "name value" pairs - all instances of the
#            name in the email body will be replaced with the value.
# reply_to:  the reply-to address on the email
# no_send:   1/0: If set to 1, the full substituted email will be returned
#                 if not, it will be sent as normal
#
proc ob_email::fast_send {to type lang format {sub {}} {reply_to {}} {no_send 0} {charset "iso8859-1"} {encode 1}} {

	ob::log::write INFO {ob_email::fast_send $to $type $lang $format}

	set from      {}
	set subject   {}
	set plainbody {}
	set htmlbody  {}

	# Get HTML version
	if {$format == "H" || $format == "B"} {
		set res       [ob_email::get_email_details $type $lang H]

		if {[lindex $res 0]} {
			set htmlbody  [lindex $res 1]
			set from      [lindex $res 2]
			set subject   [lindex $res 3]

			foreach {name value} $sub {
				regsub -all $name $htmlbody $value htmlbody
			}
		}
	}

	# Get plain text version
	if {$format == "P" || $format == "B"} {
		set res       [ob_email::get_email_details $type $lang P]

		if {[lindex $res 0]} {
			set plainbody [lindex $res 1]
			set from      [lindex $res 2]
			set subject   [lindex $res 3]

			foreach {name value} $sub {
				regsub -all $name $plainbody $value plainbody
			}
		}
	}

	# If we're just returning it, may as well return it now
	if {$no_send} {
		return $htmlbody
	}

	# Check that we actually have something to send
	if {$subject == "" || $from == ""} {
		ob::log::write ERROR {ob_email::fast_send no subject or from address available}
		return 0
	}

	lappend switches -from     $from
	lappend switches -to       $to
	lappend switches -subject  $subject

	if {[catch {
		ob_email::send_email \
			$from \
			$to \
			$subject \
			$plainbody \
			$htmlbody \
			$charset \
			$encode
	} err_msg]} {
		ob::log::write ERROR {Problem sending email: $err_msg}
		return 0
	}

	return 1
}

# An alternative to the send function
# This was pulled from ladbrokes/lbr_portal/tcl/lb_email.tcl
proc ob_email::send_email {from to subject {plainbody ""} {htmlbody ""} {charset "iso8859-1"} {encode 1}} {

	set charset [expr {$charset=="gb2312"?"euc-cn":$charset}]

	# I expect the mime/smtp packages already do this.
	#
	if {$encode} {
		#set typeextra "charset=$charset"
		set plainbody [bintoquot $plainbody]
		set htmlbody [bintoquot $htmlbody]
		set encoding "quoted-printable"
		ob::log::write DEV {encoding}
	} else {
		set encoding "7bit"
	}

	# Ezsmtp may be buggy.
	#
	set cmd [list send \
		-from     $from \
		-to       $to \
		-subject  $subject \
		-charset  $charset \
		-encoding $encoding]

	if {$plainbody != "" && $htmlbody != ""} {
		lappend cmd -plain $plainbody -html $htmlbody
	} elseif {$plainbody != ""} {
		lappend cmd -plain $plainbody
	} elseif {$htmlbody != ""} {
	 	lappend cmd -html $htmlbody
	} else {
		error "must specify either plain, HTML or both"
	}

	eval $cmd
}



# Converts the body of an email to Quoted Printable. This encodes non-ascii characters into their hex value
# preceeded with an =. E.g., =  ---> =3D.
# Due to the problems they cause, cr and lf are not encoded (13 and 10 or, 0D and 0A). If they are encoded,
# everything ends up on 1 line, which is split due to line length limits. This split will occur randomly
# and can happen in the middle of a html tag, causing it to break.
#
proc ob_email::bintoquot {text} {

	set qp ""
	foreach byte [split $text ""] {
		scan $byte %c i
		if {("$byte" == "=" || $i < 32 || $i > 127) && $i != 13 && $i != 10} {
			append qp [format =%02X $i]
		} else {
			append qp $byte
		}
	}
	return $qp
}



# Queue an email for sending later via emailer standalone app. All this does
# is take the information given and put an entry in tEmailQueue. Additional
# information can be stored in the email queue, such as a reference to an
# additional database table - allowing the emailer app to put specific details
# into the email (eg payment amount).
#
# email_type - The type of email to send. The available email types are found
#              in tEmailType and can be change on a customer to customer basis.
# cust_id    - The id of the customer to send the email to.
# msg_type   - (E)mail or (S)MS.
# ref_key    - Reference to another db table:
#                  PMT - tPmt
#                  MADJ - tManAdj
#                  LIM  - tCgCustLimit
# ref_id     - Id for the table referred to.
# reason     - Additional text field for inserting extra information into an email
#
proc ob_email::queue_email {email_type \
							cust_id \
							{msg_type "E"} \
							{ref_key ""} \
							{ref_id ""} \
							{reason ""}} {

	ob_log::write INFO {ob_email::queue_email}

	foreach v [list email_type cust_id msg_type ref_key ref_id reason] {
		ob_log::write DEBUG {-----> $v = [set $v]}
	}

	# queue email
	if {[catch {set rs [ob_db::exec_qry ob_email::queue_email \
							$email_type $cust_id $msg_type $ref_key $ref_id $reason]} msg]} {

		ob_log::write ERROR {EMAIL -> Error queueing email $email_type for $cust_id: $msg}
		return 0
	}

	ob_log::write INFO {ob_email::queue_email -> Queued $email_type email for cust_id $cust_id}

	ob_db::rs_close $rs

	return 1
}

