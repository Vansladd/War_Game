#
# © 2013 OpenBet Technology Ltd. All rights reserved.
#
# Provides convinience method for sending emails.
# Specifically, it improves on ezsmtp by providing a better method of sending
# emails with HTML and plain text versions, as well as providing support for
# different charsets and encodings.
#
# Synopsis:
#   package require core::email 1.0
#
# Configuration:
#   EMAIL_SERVERS - The servers to use for sending email, defaults to
#                   SMTP_SERVER if specified, or localhost if not.
#   EMAIL_XMAILER - Default X-Mailer.
#   EMAIL_FROM    - Default from address.
#   EMAIL_QUEUE   - Whether to queue message for later sending (1).
#
# Procedures:
#   core::email::init - Initialise
#   core::email::send - Sends an email.
#   core::email::plain_to_html - Convert plain to simple HTML.
#   core::email::html_to_plain - Convert HTML to plain.
#
# See also:
#   http://www.tcl.tk/community/tcl2004/Tcl2003papers/kupries-doctools/tcllib.doc/mime/mime.html
#   http://www.tcl.tk/community/tcl2004/Tcl2003papers/kupries-doctools/tcllib.doc/mime/smtp.html
#
#   SourceForge Tcllib Bug 447037
#

set pkg_version 1.0
package provide core::email $pkg_version

# Dependecies
package require core::log      1.0
package require core::util     1.0
package require core::check    1.0
package require core::args     1.0
package require core::xl       1.0
package require mime           1.3.1
package require smtp           1.3.1

core::args::register_ns \
	-namespace core::email \
	-version   $pkg_version \
	-dependent [list \
		core::check \
		core::log \
		core::args \
		core::xml \
		core::util] \
	-docs util/email.xml


namespace eval core::email {

	variable CFG
	variable INIT 0
	variable CONTENT_TYPE


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
}

core::args::register \
	-proc_name core::email::init \
	-desc {Initialise Email} \
	-args [list \
		[list -arg -email_servers    -mand 0 -check STRING -default_cfg EMAIL_SERVERS            -default {}           -desc {Email Servers}] \
		[list -arg -smtp_servers     -mand 0 -check STRING -default_cfg SMTP_SERVERS             -default {localhost}  -desc {SMTP Servers}] \
		[list -arg -xmailer          -mand 0 -check STRING -default_cfg EMAIL_XMAILER            -default OpenBet      -desc {SET}] \
		[list -arg -smtp_queue       -mand 0 -check STRING -default_cfg EMAIL_QUEUE              -default 1            -desc {Enable queueing of emails via smtp server}] \
		[list -arg -enable_templates -mand 0 -check STRING -default_cfg EMAIL_TEMPLATES_ENABLED  -default 0            -desc {Enable email templates}] \
	] \
	-body {
		variable CFG
		variable INIT

		if {$INIT} {
			return
		}

		set CFG(servers)          $ARGS(-email_servers)
		set CFG(smtp_servers)     $ARGS(-smtp_servers)
		set CFG(xmailer)          $ARGS(-xmailer)
		set CFG(smtp_queue)       $ARGS(-smtp_queue)
		set CFG(enable_templates) $ARGS(-enable_templates)

		if {$CFG(servers) == {}} {
			set CFG(servers) $CFG(smtp_servers)
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

		# Only prep the queries if we are enabling templates or openbet queuing
		if {$CFG(enable_templates)} {
			_prep_qrys
		}

		set INIT 1
	}


proc core::email::_prep_qrys args {

	# Get the email body from the db
	core::db::store_qry \
		-name get_email_details \
		-cache 60 \
		-qry {
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
				e.email_id = b.email_id
			and e.type     = t.type_id
			and t.name     = ?
			and b.language = ?
			and b.format   = ?
			order by
				b.body_id;
		}

	# queues an email in the database for sending via the emailer
	# standalone app.
	core::db::store_qry \
		-name core::email::queue_email \
		-qry {
			execute procedure pInsEmailQueue (
				p_email_type = ?,
				p_cust_id    = ?,
				p_msg_type   = ?,
				p_ref_key    = ?,
				p_ref_id     = ?,
				p_reason     = ?
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
core::args::register \
	-proc_name core::email::send \
	-args [list \
		[list -arg -to            -mand 1 -check STRING                            -desc {The to address of the email}] \
		[list -arg -from          -mand 1 -check STRING                            -desc {The from address of the email}] \
		[list -arg -subject       -mand 1 -check STRING                            -desc {The subject of the email}] \
		[list -arg -recipients    -mand 0 -check STRING -default {}                -desc {List of one or more recipients to send the email to}] \
		[list -arg -plain         -mand 0 -check STRING -default {}                -desc {Optional plaintext of the email's body}] \
		[list -arg -html          -mand 0 -check STRING -default {}                -desc {Optional HTML of the email's body}] \
		[list -arg -attachments   -mand 0 -check STRING -default {}                -desc {list of filenames and content}] \
		[list -arg -headers       -mand 0 -check STRING -default {}                -desc {list of headers}] \
		[list -arg -encoding      -mand 0 -check STRING -default {8bit}            -desc {Optional encoding type. e.g. base64  (see config)}] \
		[list -arg -charset       -mand 0 -check STRING -default [encoding system] -desc {Optional charset of the plaintext and email.}] \
		[list -arg -xmailer       -mand 0 -check STRING -default {}                -desc {Optional X-Mailer header (see config).}]
	] \
	-body {
		variable CFG
		variable CONTENT_TYPE

		# Initialise the package
		init

		set EMAIL(to)          $ARGS(-to)
		set EMAIL(from)        $ARGS(-from)
		set EMAIL(subject)     $ARGS(-subject)
		set EMAIL(recipients)  $ARGS(-recipients)
		set EMAIL(plain)       $ARGS(-plain)
		set EMAIL(html)        $ARGS(-html)
		set EMAIL(plain)       $ARGS(-plain)
		set EMAIL(attachments) $ARGS(-attachments)
		set EMAIL(headers)     $ARGS(-headers)
		set EMAIL(encoding)    $ARGS(-encoding)
		set EMAIL(charset)     $ARGS(-charset)
		set EMAIL(xmailer)     $ARGS(-xmailer)

		if {$EMAIL(plain) == {} && $EMAIL(html) == {}} {
			error "must specify either -plain or -html" {} INVALID_ARGUMENTS
		}

		if {$EMAIL(recipients) == {}} {
			set EMAIL(recipients) $EMAIL(to)
		}

		# check the attachments are of know types
		foreach {filepath content} $EMAIL(attachments) {
			set extension [string trimleft [file extension $filepath] .]

			if {![info exists CONTENT_TYPE($extension)]} {
				error "Content type for file type $extension is unknown" {} UNKNOWN_CONTENT_TYPE
			}

			# make sure images which are not-prefixed with http are referencing the
			# email's insides
			if {$EMAIL(html) == {}} {
				set filename [file tail $filepath]

				# if the image is in quotes, then make it reference the attachment,
				# i.e. <img src="orbis.gif"> becomes <img srg="cid:orbis.gif"> and is
				# visible in the email
				regsub "\"$filename\"" $EMAIL(html) "\"cid:$filename\"" EMAIL(html)
			}
		}

		# we must log all communication with external systems,
		core::log::write INFO \
			{email: sending email from $EMAIL(from), recipients \
			$EMAIL(recipients), subject '$EMAIL(subject)'}

		core::log::write_array DEBUG EMAIL

		if {$EMAIL(plain) != {} && $EMAIL(html) != {}} {

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

		} elseif {$EMAIL(html) != {}} {

			set token [mime::initialize \
				-canonical text/html \
				-string    $EMAIL(html) \
				-encoding  $EMAIL(encoding) \
				-param     [list charset $EMAIL(charset)] \
			]

		} elseif {$EMAIL(plain) != {}} {

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

				core::log::write DEBUG {email: attaching $filename}

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
				-queue      $CFG(smtp_queue) \
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

		core::log::write DEBUG {$cmd}

		# an error may occur, but we still need to clean up
		set caught [catch {
			# evaluate the command with extra headers
			eval $cmd
		} err]

		# using subordinates also finalizes the attachments
		mime::finalize $token -subordinates all

		if {$caught} {
			core::log::write ERROR {ERROR $err}
			error $err $::errorInfo $::errorCode
		}
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
core::args::register \
	-proc_name core::email::html_to_plain \
	-desc {Convert HTML to plain text} \
	-args [list \
		[list -arg -html  -check STRING -desc {HTML to convert to plain text}] \
	] \
	-body {
		set html $ARGS(-html)

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
core::args::register \
	-proc_name core::email::plain_to_html \
	-desc {Convert plain text to HTML} \
	-args [list \
		[list -arg -plain  -check STRING -desc {Plain text to convert to HTML}] \
	] \
	-body {
		set plain $ARGS(-plain)

		regsub -all {\n}           $plain {<br>}      plain
		regsub -all {\*([^\*]*)\*} $plain {<b>\1</b>} plain
		regsub -all {_([^_]*)_}    $plain {<u>\1</u>} plain

		foreach ext {gpf jpg png bmp} {
			regsub -all [format {([^ ]*\.%s)} $ext] $plain {<img src="\1">} plain
		}

		return $plain
	}

# Converts the body of an email to Quoted Printable. This encodes non-ascii characters into their hex value
# preceeded with an =. E.g., =  ---> =3D.
# Due to the problems they cause, cr and lf are not encoded (13 and 10 or, 0D and 0A). If they are encoded,
# everything ends up on 1 line, which is split due to line length limits. This split will occur randomly
# and can happen in the middle of a html tag, causing it to break.
#
proc core::email::_bintoquot {text} {

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
