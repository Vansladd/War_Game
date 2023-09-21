# ==============================================================
# $Id: upload.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

if {[OT_CfgGetTrue FUNC_OVS]} {
	package require ovs_ovs
}

namespace eval ADMIN::UPLOAD {

asSetAct ADMIN::UPLOAD::GoUpload     [namespace code go_upload]
asSetAct ADMIN::UPLOAD::DoUpload     [namespace code do_upload]
asSetAct ADMIN::UPLOAD::GoUploadFile [namespace code go_upload_file]
asSetAct ADMIN::UPLOAD::DoUploadFile [namespace code do_upload_file]


variable UPLOAD_FMT
variable UPLOAD_CHEQUES_HEADER

variable UPLOAD_TYPE

variable UPLOAD_SQL

variable UPLOAD_FILE_HTML

set upload_type_list [list\
EVT,sorts    {events markets selections results fbscores xgame pools variant}\
PMT,sorts    {payments adjustments cheques}\
FBT,sorts    {freebets}\
MISC,sorts   {account_closure man_bets segments custmsgs cust_notices ext_ids exclusions stmt_record}\
AFF,sorts    {affiliates}\
SEARCH,sorts {synonyms predefined}\
LOGTRIG,sorts {trigger_accts}\
ADV,sorts    {advertisers}\
EVT,html     "upload/upload.html"\
PMT,html     "upload/pmt_upload.html"\
FBT,html     "upload/freebet_upload.html"\
MISC,html    "upload/upload_misc.html" \
AFF,html     "upload/aff_upload.html"\
SEARCH,html  "upload/search_upload.html"\
LOGTRIG,html "upload/login_trigger_upload.html"\
ADV,html     "upload/affutd_upload.html"\
]

#upload with non-openbet functionality
if {[OT_CfgGet FUNC_EXT_UPLOAD 0]} {

	set external_upload_defs [ADMIN::EXT::upload]

	for {set i 0} {$i < [llength $external_upload_defs]} {incr i} {

		set upload_def [lindex $external_upload_defs $i]

		foreach {
			id
			html
			sorts
		} $upload_def {

			set htmlExists [lsearch $upload_type_list "$id,html"]
			set sortsExists [lsearch $upload_type_list "$id,sorts"]

			#
			# external code can override the html that is played
			# or add new templates for new uploads seperate from openbet
			#
			if {$htmlExists==-1} {
				lappend upload_type_list "${id},html" $html
			} else {
				set htmlPos [expr $htmlExists+1]
				set upload_type_list [lreplace $upload_type_list $htmlPos $htmlPos $html]
			}

			set l_sorts [list]
			foreach {sort format sql html} $sorts {
				lappend l_sorts $sort
				set UPLOAD_FMT($sort) $format
				set UPLOAD_SQL($sort) $sql
				set UPLOAD_FILE_HTML($sort) $html
			}

			#
			# external code can add to the sorts in a grouping of uploads
			# or add new groupings for new uploads seperate from openbet
			#
			if {$sortsExists==-1} {
				lappend upload_type_list "${id},sorts" $l_sorts
			} else {
				set sortsPos [expr $sortsExists+1]
				set currentSorts [lindex $upload_type_list $sortsPos]

				set l_sorts [concat $l_sorts $currentSorts]
				set upload_type_list [lreplace $upload_type_list $sortsPos $sortsPos $l_sorts]
			}
		}
	}
}
ob::log::write DEV {upload_type_list: $upload_type_list}

array set UPLOAD_TYPE $upload_type_list

#
# Definitions of file formats,  first argument of the column list is now
# a list which defines the type of field (M)andatory (D)iscard or (A)dd
# if Add then the second entry in the ist is the default added if this
# column is not defined in the upload file
#
# Added MC field type - this is a mandatory field, however, if the value
# for a row,column is not specified then we can specify another column to
# look for on that row which if available will be used instead
# (fb side -> fb result)
#
# MI field type:-  Only mandatory if the other specified column is present

set UPLOAD_FMT(events) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "COUNTRY"]\
	[list [list M] "VENUE"]\
	[list [list M] "SORT"]\
	[list [list M] "STATUS"]\
	[list [list M] "DISPLAYED"]\
	[list [list M] "DISPORDER"]\
	[list [list M] "SUSPEND AT"]\
	[list [list M] "URL"]\
	[list [list M] "TAX RATE"]\
	[list [list M] "MIN BET"]\
	[list [list M] "MAX BET"]\
	[list [list D] "FB RISK CAT"]\
	[list [list A ""] "MAX BET SP"]\
	[list [list A ""] "MAX PLACE LP"]\
	[list [list A ""] "MAX PLACE SP"]\
	[list [list M] "FB DOM/INT"]\
	[list [list A ""] "EXT KEY"]\
	[list [list A ""] "MULT KEY"]\
	[list [list M ""] "CLASS SORT"]\
	[list [list A ""] "HOME TEAM"]\
	[list [list A ""] "AWAY TEAM"]\
	[list [list A ""] "CHANNELS"]\
	[list [list A ""] "CALENDAR"]\
	[list [list A ""] "EVENT LL"]\
	[list [list A ""] "EVENT LTL"]\
	[list [list A ""] "EVENT LM"]\
	[list [list A ""] "EVENT MM"]\
	[list [list A ""] "OFF"]\
	[list [list A ""] "FLAGS"]\
	[list [list D ""] "STATIONS"]\
	[list [list D "N"] "PREVIOUS ODDS"]\
	[list [list D ""] "BAW GROUP"]\
]



set UPLOAD_FMT(markets) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "MARKET"]\
	[list [list A ""] "MARKET NAME"]\
	[list [list M] "STATUS"]\
	[list [list M] "DISPLAYED"]\
	[list [list M] "DISPORDER"]\
	[list [list M] "TAX RATE"]\
	[list [list M] "LIVE PRICE"]\
	[list [list M] "STARTING PRICE"]\
	[list [list A "N"] "GUARANTEED PRICE"]\
	[list [list M] "FORECAST"]\
	[list [list M] "TRICAST"]\
	[list [list M] "EACH-WAY"]\
	[list [list M] "PLACE"]\
	[list [list M] "NUM PLACES"]\
	[list [list M] "PLACE FRACTION" FRACTION]\
	[list [list M] "TERMS WITH BET"]\
	[list [list M] "ACC MIN"]\
	[list [list M] "ACC MAX"]\
	[list [list A ""] "HANDICAP"]\
	[list [list M] "LIAB LIMIT"]\
	[list [list A ""] "EXT KEY"]\
	[list [list A ""] "CHANNELS"]\
	[list [list A "N"] "AP"]\
	[list [list A "N"] "BET_IN_RUN"]\
	[list [list A ""] "MAX MULTIPLE BET"]\
	[list [list A ""] "WIN LP"]\
	[list [list A ""] "WIN SP"]\
	[list [list A ""] "WIN EP"]\
	[list [list A ""] "PLACE LP"]\
	[list [list A ""] "PLACE SP"]\
	[list [list A ""] "PLACE EP"]\
	[list [list A -1] "LEAST MAX BET"]\
	[list [list A -1] "MOST MAX BET"]\
	[list [list A "N"] "AUTO DH REDUCTIONS"]\
	[list [list D ""] "TAG"]\
	[list [list D "I"] "TAG CHANNELS"]\
	[list [list D "N"] "SHOW PRICE AVAILABLE"]\
	[list [list D ""] "FINANCIAL OPENING TIME"]\
	[list [list D ""] "FINANCIAL OPENING LEVEL"]\
	[list [list D ""] "FINANCIAL SUSPEND TIME"]\
	[list [list D ""] "FINANCIAL CLOSE TIME"]\
	[list [list D ""] "FINANCIAL MARKET INFO"]\
	[list [list A "1"] "HCAP PRECISION"]\
	[list [list D ""] "TELEBET DISPLAY ORDER"]\
]

set UPLOAD_FMT(selections) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "MARKET"]\
	[list [list M] "SELECTION"]\
	[list [list D ""] "JOCKEY"]\
	[list [list M] "STATUS"]\
	[list [list M] "DISPLAYED"]\
	[list [list M] "DISPORDER"]\
	[list [list M] "MIN BET"]\
	[list [list M] "MAX BET"]\
	[list [list A ""] "MAX BET SP"]\
	[list [list A ""] "MAX PLACE LP"]\
	[list [list A ""] "MAX PLACE SP"]\
	[list [list M] "MAX TOTAL"]\
	[list [list M] "STK/LBT"]\
	[list [list M] "LIVE PRICE" PRICE]\
	[list [list M] "SP GUIDE" PRICE]\
	[list [list MC "FB SIDE"] "FB RESULT" FB_RESULT]\
	[list [list D] "FB SIDE"] \
	[list [list A ""] "EXT KEY"]\
	[list [list A ""] "MULT KEY"]\
	[list [list A ""] "CHANNELS"]\
	[list [list D ""] "PRICE TYPE"]\
	[list [list A ""] "LINK KEY"]\
	[list [list D "N"] "LOCK STAKE LIMIT"]\
	[list [list D ""] "TEXT NAME"]\
	[list [list D ""] "SCREENS NAME"]\
]

set UPLOAD_FMT(variant) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "MARKET"]\
	[list [list M] "SELECTION"]\
	[list [list M] "STATUS"]\
	[list [list A "Y"] "DISPLAYED"]\
	[list [list M] "DISPORDER"]\
	[list [list M] "PRICE NUM"]\
	[list [list M] "PRICE DEN"]\
	[list [list A ""] "VALUE"]\
	[list [list A ""] "DESC"]\
	[list [list A "HC"] "TYPE"]\
	[list [list A "A"] "APPLY PRICE"]]


set UPLOAD_FMT(results) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "MARKET"]\
	[list [list M] "SELECTION"]\
	[list [list M] "RESULT"]\
	[list [list M] "PLACE"]\
	[list [list M] "STARTING PRICE" PRICE]\
	[list [list M] "WIN DH REDUCTION" FRACTION]\
	[list [list M] "PLACE DH REDUCTION" FRACTION]]

set UPLOAD_FMT(fbscores) [list\
	[list [list M] "CATEGORY"]\
	[list [list M] "CLASS"]\
	[list [list M] "TYPE"]\
	[list [list M] "NAME"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "HALFTIME SCORE"]\
	[list [list M] "FULLTIME SCORE"]]

set UPLOAD_FMT(payments) [list\
	[list [list M] "USERNAME"] \
	[list [list M] "ACCOUNT NUMBER"]\
	[list [list A ""] "LAST NAME"]\
	[list [list M] "DESCRIPTION"]\
	[list [list M] "EXTRA INFO"]\
	[list [list M] "PAYMENT TYPE"]\
	[list [list M] "AMOUNT"]\
	[list [list M] "CURRENCY CODE"]\
	[list [list A "P"] "CHANNEL"]]

set UPLOAD_CHEQUES_HEADER "DATE,BATCHNUMBER,ACCOUNTNUMBER,CHEQUENUMBER,VALUE"
set UPLOAD_FMT(cheques) [list\
	[list [list M] "DATE"]\
	[list [list M] "BATCHNUMBER"]\
	[list [list M] "ACCOUNTNUMBER"]\
	[list [list M] "CHEQUENUMBER"]\
	[list [list M] "VALUE"]]

set UPLOAD_FMT(pools) [list\
	[list [list M] "SORT"]\
	[list [list M] "DATE/TIME"]\
	[list [list M] "MATCH NUMBER"]\
	[list [list M] "TEAM 1"]\
	[list [list M] "TEAM 2"]]


set UPLOAD_FMT(adjustments) [list\
	[list [list M] "USERNAME"]\
	[list [list M] "ACCOUNT NUMBER"]\
	[list [list A ""] "LAST NAME"]\
	[list [list M] "DESCRIPTION"]\
	[list [list M] "WITHDRAWABLE"]\
	[list [list M] "AMOUNT"]\
	[list [list M] "CURRENCY CODE"]\
	[list [list M] "TYPE"]\
	[list [list A ""] "SUBTYPE"]\
	[list [list M] "BOOKMAKER ACCOUNT"]\
	[list [list A ""] "SYSTEM NAME"]]



set UPLOAD_FMT(freebets) [list\
	[list [list M] "TOKEN ID"]\
	[list [list M] "USERNAME"]\
	[list [list M] "CCY CODE"]]

set UPLOAD_FMT(statements) [list\
	[list [list M] "ACCOUNT NUMBER"]]

set UPLOAD_FMT(account_closure) [list\
	[list [list M] "ACCOUNT NUMBER"]]
# String match format
set UPLOAD_FMT(account_closure,header_format) [OT_CfgGet ACCOUNT_CLOSURE_UPLOAD_HEADER_FORMAT {01SICCTCLOS[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-4][0-5][0-9][0-5][0-9]}]
# Regexp format
set UPLOAD_FMT(account_closure,body_format)   [OT_CfgGet ACCOUNT_CLOSURE_UPLOAD_BODY_FORMAT   {^(02)([0-9]{9})(.)$}]
# String match format
set UPLOAD_FMT(account_closure,footer_format) [OT_CfgGet ACCOUNT_CLOSURE_UPLOAD_FOOTER_FORMAT {03SIC[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-4][0-5][0-9][0-5][0-9]*}]

set UPLOAD_FMT(man_bets) [list\
	[list [list M] "ACCOUNT NUMBER"]\
	[list [list M] "DESCRIPTION"]\
	[list [list MI "CLASS"] "CATEGORY"]\
	[list [list MI "TYPE"] "CLASS"]\
	[list [list A ""] "TYPE"]\
	[list [list M] "CHANNEL"]\
	[list [list M] "STAKE"]\
	[list [list M] "PAY NOW"]\
	[list [list A ""] "SETTLE AT"]\
	[list [list M] "TAX TYPE"]\
	[list [list M] "TAX RATE"]\
	[list [list A "0.00"] "TAX"]\
	[list [list A ""] "RESULT"]\
	[list [list MI "RESULT"] "WINNINGS"]\
	[list [list MI "RESULT"] "REFUNDS"]\
	[list [list A ""] "SETTLEMENT COMMENT"]\
	[list [list A ""] "ACTUAL DATE PLACED"]\
	[list [list A ""] "REP CODE"]\
	[list [list A ""] "COURSE TYPE"]]

set UPLOAD_FMT(segments) [list\
	[list [list M] "CUSTOMER ID"]\
	[list [list M] "GROUP NAME"]\
	[list [list M] "GROUP VALUE"]]

set UPLOAD_FMT(custgroups) [list\
	[list [list M] "CUSTOMER ID"]\
	[list [list M] "GROUP"]\
	[list [list M] "VALUE"]]

# NOTE: If you change this, you'll need to change do_upload_load - extid checking has
#       hardcoded columns 1, 2 and 3 for Group, ExtID and Master
set UPLOAD_FMT(ext_ids) [list\
	[list [list M] "USERNAME"]\
	[list [list M] "GROUP_CODE"]\
	[list [list M] "EXTERNAL_ID"]\
	[list [list M] "MASTER"]]

set UPLOAD_FMT(exclusions) [list\
	[list [list M] "ACCOUNT ID"]\
	[list [list M] "TYPE"]\
	[list [list A ""] "SYSTEM"]\
	[list [list A ""] "CHANNEL"]]

set UPLOAD_FMT(custmsgs) [list\
	[list [list A ""] "ACCOUNT ID"]\
	[list [list A ""] "CUSTOMER ID"]\
	[list [list M] "TYPE"]\
	[list [list M] "MESSAGE"]]

set UPLOAD_FMT(cust_notices) [list\
	[list [list A ""] "CUST_ID"]\
	[list [list A ""] "ACCT_ID"]\
	[list [list M] "MESSAGE CODE"]\
	[list [list A ""] "FROM DATE"]\
	[list [list A ""] "TO DATE"]]

set UPLOAD_FMT(affiliates)  [list\
	[list [list M] "AFFILIATE"]\
	[list [list M] "BF_ID"]\
	[list [list M] "PROGRAM"]\
	[list [list M] "BET"]\
	[list [list M] "REGISTRATION"]]
set UPLOAD_FMT(synonyms) [list\
    [list [list M] "KEYWORD"] \
    [list [list M] "SYNONYM"] \
    [list [list A ""] "LANGUAGE"] \
    [list [list A "1"] "DISPORDER"]]

set UPLOAD_FMT(predefined) [list\
    [list [list M] "KEYWORD"] \
    [list [list M] "LINK TEXT"] \
    [list [list M] "URL ADDRESS"] \
    [list [list M] "LANGUAGE"] \
    [list [list A "1"] "DISPORDER"] \
    [list [list M] "CANVAS_NAME"]]

set UPLOAD_FMT(stmt_record) [list\
	[list [list M] "ACCOUNT NUMBER"] \
	[list [list M] "DATE FROM"] \
	[list [list M] "DATE TO"] \
	[list [list A "ALL"] "PRODUCT FILTER"]]

set UPLOAD_FMT(translations) [list\
	[list [list M] "CODE"] \
	[list [list M] "GROUP"] \
	[list [list M] "STATUS"] \
	[list [list A ""] "ENGLISH"] \
	[list [list M] "LANG"] \
	[list [list A ""] "TRANS"]]

set UPLOAD_FMT(advertisers) [list\
	[list [list M] "ADVERTISER"] \
	[list [list A ""] "DESCRIPTION"]]

# Used by login_triggers
set UPLOAD_FMT(trigger_accts) [list\
    [list [list M] "ACCT_NO"]]


variable CS_RX
variable HF_RX
variable GC_TAGS_LIST
variable GC_FB_RES_LIST
variable TG_TAGS_LIST
variable TG_FB_RES_LIST
variable TG_RX
variable HF_MAP
variable CFG

set CS_RX {^([0-9]+)-([0-9]+)$}
set HF_RX {^(HH|HD|HA|DH|DD|DA|AH|AD|AA)$}

#set up total goals / goal crazy data
foreach prefix [list GC TG] {
	set ${prefix}_TAGS_LIST [list]
	set ${prefix}_FB_RES_LIST [list]

	set temp_list [split [ADMIN::MKTPROPS::mkt_flag FB $prefix tags]]

	foreach {fb_res tag} $temp_list {
		lappend ${prefix}_FB_RES_LIST $fb_res
		lappend ${prefix}_TAGS_LIST [string trim $tag \"]
	}
}
array set HF_MAP [list HH 1 HD 2 HA 3 DH 4 DD 5 DA 6 AH 7 AD 8 AA 9]


set CFG(ovs)                 [OT_CfgGetTrue FUNC_OVS]
# MAC (Missing Account Creation) setup
set CFG(MAC,enabled)         [OT_CfgGetTrue MISSING_ACCOUNT_CREATION.ENABLED]
if {$CFG(MAC,enabled)} {
	set CFG(MAC,ccy)             [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_CCY     "EUR"]
	set CFG(MAC,pwd)             [md5 [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_PWD "something"]]
	set CFG(MAC,txt)             [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_TXT     "SIC Auto Account Creation"]
	set CFG(MAC,lang)            [OT_CfgGet MISSING_ACCOUNT_CREATION.DFLT_LANG    "fr"]
	set CFG(MAC,country_code)    [OT_CfgGet MISSING_ACCOUNT_CREATION.COUNTRY_CODE "FR"]
}

#
# ----------------------------------------------------------------------------
# Validate a line of an uploaded file
# ----------------------------------------------------------------------------
#
proc upload_val_line {sort line {header 0}} {

	variable UPLOAD_FMT

	set spec $UPLOAD_FMT($sort)

	if {$header} {
		for {set i 0; set j 0} {$i < [llength $spec]} {} {

			set s_line      [string trim [lindex $spec $i]]
			set f_type      [string trim [lindex $s_line 0]]
			set f_type_spec [string trim [lindex $f_type 0]]
			set f_name		[string trim [lindex $s_line 1]]

			if {$f_type_spec == "M" || $f_type_spec == "MC"} {
				#
				# this column must be present
				#
				if {$f_name != [lindex $line $j]} {
					return 0
				}
				incr i
				incr j

			} elseif {$f_type_spec == "D" || $f_type_spec == "A" } {
				#
				# this column may or may not be present
				#
				if {$f_name == [lindex $line $j]} {
					incr i
					incr j
				} else {
					incr i
				}
			} elseif {$f_type_spec == "MI"} {
				#
				# this column must be present only if another specified
				# column is present
				#
				if {$f_name != [lindex $line $j]} {
					set req_col [lindex $f_type 1]
					if {$req_col == [lindex $line $j]} {
						return 0
					}
					incr i
				} else {
					incr i
					incr j
				}
			} else {
				error "unrecognised field type"
			}
		}
	}

	return 1
}

#
# ----------------------------------------------------------------------------
# Go to upload page
# ----------------------------------------------------------------------------
#
proc go_upload args {

	global FILE
	variable UPLOAD_TYPE

	set upload_type [reqGetArg upload_type]
	tpBindString upload_type $upload_type

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set action [reqGetArg SubmitName]
	if {$action=="uploaded"} {
		tpSetVar UPLOADED 1
	} else {
		tpSetVar UPLOADED 0
	}

	set months [list "" Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]

	set mrx {([12][09][0-9][0-9])-([01][0-9])-([0-3][0-9])}
	set trx {([012][0-9]):([0-5][0-9]):([0-5][0-9])}

	set drx ${mrx}_${trx}\$

	set n_files 0

	set sorts $UPLOAD_TYPE($upload_type,sorts)

	foreach dt $sorts {

		set files [glob -nocomplain $UPLOAD_DIR/$dt/*]

		foreach f $files {
			set ftail [file tail $f]
			if [regexp $drx $ftail time y m d hh mm ss] {

				if [regsub _$drx $ftail "" ftrunc] {

					set m [lindex $months [string trimleft $m 0]]

					set FILE($n_files,type)     $dt
					set FILE($n_files,date)     "$y-$m-$d $hh:$mm:$ss"
					set FILE($n_files,fullname) [urlencode $ftail]
					set FILE($n_files,trunc)    [html_encode $ftrunc]
					set FILE($n_files,time)     $time
					set FILE($n_files,is_reject) [string equal -length 8 $FILE($n_files,fullname) "REJECTED"]

					incr n_files
				}
			}
		}
	}

	tpSetVar NumFiles $n_files

	tpBindVar FileType FILE type      file_idx
	tpBindVar FileTime FILE date      file_idx
	tpBindVar FileName FILE trunc     file_idx
	tpBindVar FileKey  FILE fullname  file_idx
	tpBindVar IsReject FILE is_reject file_idx

	asPlayFile -nocache $UPLOAD_TYPE($upload_type,html)

	catch {unset FILE}
}


proc do_upload {args} {

	global REQ_FILES
	variable UPLOAD_FMT

	set filename    [reqGetArg filename]
	set filetype    [reqGetArg filetype]
	set upload_type [reqGetArg upload_type]

	set upload_dir [OT_CfgGet UPLOAD_DIR]

	OT_LogWrite 1 "filename: $filename"
	OT_LogWrite 1 "filetype: $filetype"
	OT_LogWrite 1 "upload_type: $filetype"
	OT_LogWrite 1 "upload_dir: $upload_dir"

	set date_suffix [clock format [clock seconds] -format "%Y-%m-%d_%H:%M:%S"]

	if {[OT_CfgGet UPLOAD_ALLOW_FILENAME_SPACES 1]} {
		# Map spaces to underscores, just for safety
		set filename_server [string map {" " "_"} $filename]
		set fname "${upload_dir}/${filetype}/${filename_server}_${date_suffix}"
	} else {
		set fname "${upload_dir}/${filetype}/${filename}_${date_suffix}"
	}


	# Special case for account_closure as it has a dynamic header and also possibly a footer
	if {$filetype == "account_closure"} {

		# In case this came from DOS
		set file_lines [string map {"\r" ""} $REQ_FILES(filename)]

		set file_lines [split $file_lines "\n"]

		# In case this came from DOS
		if {[lindex $file_lines end] == ""} {
			set file_lines [lreplace $file_lines end end]
		}

		set header_line [lindex $file_lines 0]
		if {[string match $UPLOAD_FMT(account_closure,header_format) $header_line]} {
			set file_lines [lreplace $file_lines 0 0 "ACCOUNT NUMBER"]
		} else {
			err_bind "Failed to write file $fname (Invalid file header: $header_line)"
			go_upload
			return
		}

		if {[OT_CfgGet ACCOUNT_CLOSURE_UPLOAD_FOOTER_EXISTS 1]} {
			set footer_line [lindex $file_lines end]
			if {[string match $UPLOAD_FMT(account_closure,footer_format) $footer_line]} {
				set file_lines [lreplace $file_lines end end]
			} else {
				err_bind "Failed to write file $fname (Invalid file footer: $header_line)"
				go_upload
				return
			}
		}

		for {set i 1} {$i < [llength $file_lines]} {incr i} {

			set line [lindex $file_lines $i]

			if {![regexp -- $UPLOAD_FMT(account_closure,body_format) $line all lead extracted_acct_num tail]} {
				err_bind "Failed to write file $fname (Invalid line [expr {$i+1}]: $line)"
				go_upload
				return
			}

			set file_lines   [lreplace $file_lines $i $i $extracted_acct_num]
		}

		# Finally put everything back into REQ_FILES
		set REQ_FILES(filename) [join $file_lines "\n"]
	}

	set c [catch {
		set fp [open $fname w]
	} msg]

	if {$c} {
		err_bind "Failed to write file $fname ($msg)"
		go_upload
		return
	}

	puts -nonewline $fp $REQ_FILES(filename)

	close $fp

	tpSetVar UPLOADED 1

	go_upload
}


#
# ----------------------------------------------------------------------------
# Read a (supposed) CSV file into global FILE array
# ----------------------------------------------------------------------------
#
proc do_upload_load_file {type name {path ""}} {

	global FILE
	variable UPLOAD_CHEQUES_HEADER

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR ""]
	set sub_dir /$type/$name

	if {$path != ""} {
		set sub_dir $path$name
	}

	set f [open $UPLOAD_DIR/$sub_dir r]

	if {$type == "cheques"} {
    		set line $UPLOAD_CHEQUES_HEADER
	} else {
		if {[gets $f line] <= 0} {
			close $f
			set FILE(HEADER,OK) 0
			ob::log::write ERROR "Error with gets $f line"
			return 0
		}
	}

	set ok 1

	set header [csv_split $line]

	#
	# Check the file header - if it's not ok, we take an early bath...
	#
	if {[upload_val_line $type $header 1]} {
		set ncols [llength $header]
		for {set c 0} {$c < $ncols} {incr c} {
			set FILE($c,HEADER) [string trim [lindex $header $c]]
		}
		set FILE(HEADER,OK) 1
		set FILE(HEADER,NUM_COLS) $ncols
	} else {
		set FILE(HEADER,OK) 0
	}

	if {!$FILE(HEADER,OK)} {
		close $f
		ob::log::write ERROR "empty return while the rest returns 0 or 1"
		err_bind "error in the format of csv file"
		return 0
	}

	ob::log::write INFO "Checking each line of file $f"
	set line_num 0

	#
	# Check each line of the file
	#
	while {[gets $f line] >= 0} {
		#
		# Trim any leading or trailing crud
		#
		set line [string trim $line]

		set data [csv_split $line]

		if {[upload_val_line $type $data]} {
			set ncols [llength $data]
			for {set c 0} {$c < $FILE(HEADER,NUM_COLS)} {incr c} {
				if {$c > $ncols} {
					set col_data ""
				} else {
					set col_data [lindex $data $c]
				}
				set FILE($line_num,$c,DATA) $col_data
			}
			set FILE($line_num,OK) 1
		} else {
			set FILE($line_num,DATA) $line
			set FILE($line_num,OK) 0
			set ok 0
		}
		incr line_num
	}

	set FILE(NUM_LINES) $line_num

	close $f

	return $ok
}


#
# ----------------------------------------------------------------------------
# Show an uploaded file
# ----------------------------------------------------------------------------
#
proc go_upload_file args {

	global FILE

	variable UPLOAD_FILE_HTML
	variable UPLOAD_CHEQUES_HEADER

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set type [reqGetArg FileType]
	set name [reqGetArg FullName]
	set edit [reqGetArg edit]
	set course  [reqGetArg course]
	set meeting [reqGetArg meeting]
	set ocb_id  [reqGetArg ocb_id]

	ob::log::write INFO "File type is: $type"
	tpSetVar FileType $type

	if {$edit==""} {
		set edit 0
	}

	set upload_type [reqGetArg upload_type]
	tpBindString upload_type $upload_type

	tpBindString per_line_tran_chkd "checked"

	if {$type == "adjustments" \
	    && [OT_CfgGetTrue FORCE_MAN_ADJ_PER_LINE_TXN]} {
		tpBindString per_line_tran_disabled "disabled"
	}

	## External games files are a special case
	if {$type=="xgame"} {
		xgame_import_file
		return
	}

	set f [open $UPLOAD_DIR/$type/$name r]

	if {$type == "cheques"} {
		set line $UPLOAD_CHEQUES_HEADER
	} else {
		if {[gets $f line] <= 0} {
  			close $f
  			error "file is empty"
  		}
	}

	set mrx {([12][09][0-9][0-9])-([01][0-9])-([0-3][0-9])}
	set trx {([012][0-9]):([0-5][0-9]):([0-5][0-9])}
	set drx ${mrx}_${trx}\$

	regsub _$drx $name "" plain_name

	tpBindString FileType [html_encode $type]
	tpBindString FullName [html_encode $name]
	tpBindString FileName [html_encode $plain_name]

	set ok 1

	set header [csv_split $line]

	#
	# Check the file header - if it's not ok, we take an early bath...
	#
	if {[upload_val_line $type $header 1]} {
		set ncols [llength $header]
		for {set c 0} {$c < $ncols} {incr c} {
			set FILE($c,HEADER) [string trim [lindex $header $c]]
		}
		set FILE(HEADER,OK) 1

		tpSetVar HeaderOK 1
	} else {
		tpSetVar     HeaderOK   0
		tpSetVar     FileOK     0
		tpBindString NumCols    1
		tpBindString HeaderLine $line

		if {[info exists UPLOAD_FILE_HTML($type)]} {
			asPlayFile -nocache $UPLOAD_FILE_HTML($type)
		} else {
			asPlayFile -nocache upload/upload_file.html
		}

		catch {unset FILE}
		return
	}

	set ok       1
	set line_num 0

	#
	# Check each line of the file
	#
	while {[gets $f line] >= 0} {

		#
		# Trim amy leading or trailing crud
		#
		set line [string trim $line]

		set data [csv_split $line]

		if {[upload_val_line $type $data]} {
			set ncols [llength $data]
			for {set c 0} {$c < $ncols} {incr c} {
				set FILE($line_num,$c,DATA) [lindex $data $c]
			}
			set FILE($line_num,OK) 1
		} else {
			set FILE($line_num,DATA) $line
			set FILE($line_num,OK) 0
			set ok 0
		}

		incr line_num
	}

	close $f

	tpSetVar     NumLines     $line_num
	tpSetVar     NumCols      [llength $header]
	tpBindString NumCols      [llength $header]
	tpBindString NumColsPlus1 [expr {1+[llength $header]}]

	tpBindVar FileHeader FILE HEADER col_idx
	tpBindVar FileData   FILE DATA   line_idx col_idx
	tpBindVar BadData    FILE DATA   line_idx

	tpSetVar FileOK $ok

	if {$type == "man_bets" || $type == "adjustments"} {

		if {[OT_CfgGet FUNC_MAN_ADJ_BALANCE_CHK 1]} {
			tpBindString BalanceChkChecked "checked"
		} else {
			tpBindString BalanceChkChecked ""
		}

		set batch_ref_id [reqGetArg batch_ref_id]
		if {$batch_ref_id != ""} {
			tpBindString BatchRefID $batch_ref_id
		}
		if {[reqGetArg use_batch_ref] == 1} {
			tpBindString BatchRefChecked "checked"
		}
		if {$course != ""} {
			tpBindString CourseKey $course
		}
		if {$meeting != ""} {
			tpBindString MeetingKey $meeting
		}
		tpBindString OCBId $ocb_id
	}

	if {$edit} {
		asPlayFile -nocache upload/edit_file.html
	} elseif {[info exists UPLOAD_FILE_HTML($type)]} {
		asPlayFile -nocache $UPLOAD_FILE_HTML($type)
	} else {
		if {[info exists UPLOAD_FILE_HTML($type)]} {
			asPlayFile -nocache $UPLOAD_FILE_HTML($type)
		} else {
			asPlayFile -nocache upload/upload_file.html
		}
	}

	catch {unset FILE}
}


#
# ----------------------------------------------------------------------------
# Do file upload
# ----------------------------------------------------------------------------
#
proc do_upload_file args {

	OT_LogWrite 20 "raw post[reqGetRawPost]"
	OT_LogWrite 20 "url is [reqGetEnv REQUEST_URI]"

	set op [reqGetArg SubmitName]

	set upload_type [reqGetArg upload_type]
	tpBindString upload_type $upload_type

	if {$op == "FileLoad"} {
		do_upload_load
	} elseif {$op == "FileDel"} {
		do_upload_delete
	} elseif {$op == "Back"} {
		go_upload
	} elseif {$op == "FileEdit"} {
		do_edit 0
	} elseif {$op == "SaveAndLoad"} {
		do_edit 1
	} else {
		error "unexpected operation : $op"
	}
}

proc do_edit {save_and_load} {

	global FILE

	set lines_to_write [list]

	set FILE(HEADER,OK) 1
	set FILE(HEADER,NUM_COLS) [reqGetArg col_count]
	set FILE(NUM_LINES)       [reqGetArg row_count]
	set type                  [reqGetArg FileType]
	set name                  [reqGetArg FullName]


	for {set line 0} {$line < $FILE(NUM_LINES)} {incr line} {
		for {set col 0} {$col < $FILE(HEADER,NUM_COLS)} {incr col} {
			if {$line==0} {
				set get_string "header_${col}"
				set FILE($col,HEADER) [string trim [reqGetArg $get_string]]
			}

			set get_string "col_${col}_line_${line}"
			set FILE($line,$col,DATA) [reqGetArg $get_string]
		}

		lappend lines_to_write [expr {$line+1}]
	}

	create_failed_file $lines_to_write $type $name "update"

	if {$save_and_load} {
		do_upload_load
	} else {
		tpSetVar edited 1
		reqSetArg edit 1
		go_upload_file
	}

	catch {unset FILE}
}

proc do_upload_load args {

	global DB USERNAME FILE USERID

	variable UPLOAD_FMT
	variable UPLOAD_SQL
	variable CFG


	set type  [reqGetArg FileType]
	set fname [reqGetArg FileName]
	set name  [reqGetArg FullName]


	set result [load_file $type $name "" $fname]
}

proc load_file {type name {path ""} {fname ""}} {

	global DB USERNAME FILE USERID

	variable UPLOAD_FMT
	variable UPLOAD_SQL
	variable CFG

	set batch_ref_id ""

	ob::log::write INFO "*** Read request parameters"

	# Request parametres
	# On course:        course, meeting,rep_code
	# transaction:      per_line_Transaction
	# batch reference:  use_batch_ref, batch_ref_id, batch_ref_location,
	#                   batch_ref_reuse
	# queue size:       drip_feed_enabled
	# balance checking: no_balance_chk
	foreach reqArg {course \
			meeting \
			rep_code \
			ocb_id \
			per_line_trans \
			use_batch_ref \
			batch_ref_reuse \
			drip_feed_enabled \
			no_balance_chk \
			do_update_seln } {

		set $reqArg [reqGetArg $reqArg]
	}

	if {$do_update_seln == ""} {set do_update_seln 0}

	if {$use_batch_ref == 1} {
		set batch_ref_id       [string trim [reqGetArg batch_ref_id]]
		set batch_ref_location [reqGetArg batch_ref_location]
	}


	# On Course
	if {$rep_code != "" || $course != "" || $meeting != ""} {
		set is_oncourse 1
	} else {
		set is_oncourse 0
	}


	ob::log::write INFO "*** Start of do_upload_load"

	# deal with batch reference IDs, if needed
	set prev_batch_add 0
	if {$use_batch_ref == 1} {
		ob::log::write INFO "Batch reference being used, ID given is: $batch_ref_id"

		if {$batch_ref_id != ""} {
			# ensure given batch reference is valid
			if {![regexp {^[0-9]+$} $batch_ref_id match]} {
				set err_msg "Batch reference ID is not a positive integer"
				ob::log::write ERROR $err_msg
				err_bind $err_msg
				error $err_msg
			}

			# check if a given batch reference has been previously used
			set batch_ref_sql {
				select count(*) br_count
				from tBatchReference
				where batch_ref_id = ?
			}
			set batch_stmt [inf_prep_sql $DB $batch_ref_sql]
			set rs         [inf_exec_stmt $batch_stmt $batch_ref_id]
			set nrows      [db_get_nrows $rs]
			if {$nrows == 1} {
				set br_count [db_get_col $rs 0 br_count]
				if {$br_count > 0} {
					ob::log::write INFO "Batch reference $batch_ref_id has been used before"
					catch {db_close $rs}
					if {$batch_ref_reuse != 1} {

						# ask customer if they still want to proceed
						tpBindString BatchRefID $batch_ref_id
						tpBindString BatchRefChecked "checked"
						tpSetVar BatchRefReuse 1
						reqSetArg course $course
						reqSetArg meeting $meeting
						reqSetArg ocb_id $ocb_id
						go_upload_file
						return
					} else {
						set prev_batch_add 1
					}
				}
			} else {
				catch {db_close $rs}
				set err_msg "Cannot check current batch reference ID against database"
				ob::log::write ERROR $err_msg
				err_bind $err_msg
				error $err_msg
			}
		} else {
			# no batch reference given, create our own
			set batch_ref_sql {
				select max(batch_ref_id) max_batch_ref from tBatchReference
			}
			set batch_stmt [inf_prep_sql $DB $batch_ref_sql]
			set rs         [inf_exec_stmt $batch_stmt $batch_ref_id]
			set nrows      [db_get_nrows $rs]
			if {$nrows == 1} {
				set temp_ref_id [string trim [db_get_col $rs 0 max_batch_ref]]
				if {$temp_ref_id == ""} {
					set temp_ref_id 0
				}
				set batch_ref_id [expr {$temp_ref_id + 1}]
				ob::log::write DEBUG "Next batch reference ID from DB: $batch_ref_id"
				catch {db_close $rs}
			} else {
				catch {db_close $rs}
				set err_msg "Cannot create a system-set batch reference ID"
				ob::log::write ERROR $err_msg
				err_bind $err_msg
				error $err_msg
			}
		}
	} else {
		set batch_ref_id ""
	}


	ob::log::write INFO "end batch comprobations, batch_ref_id=$batch_ref_id"

	# transactions db
	if {$per_line_trans==""} {
		set per_line_trans 0
	} else {
		tpBindString per_line_tran_chkd "checked"
	}

	ob::log::write INFO "per line transaction: $per_line_trans"

	# dates
	set mrx {([0-3][0-9])[-/]([01][0-9])[-/]([12][09][0-9][0-9])}
	set trx {([012][0-9]):([0-5][0-9])}
	set drx "$mrx $trx\$"

	# syntax errors in the file
	if {![do_upload_load_file $type $name $path]} {
		set err_msg "failed to load $type file $name"
		err_bind $err_msg
		ob::log::write ERROR $err_msg
		error $err_msg
	}

	ob::log::write INFO "after do_upload_load_file"

	# Type of file: events, selections...
	set fields $UPLOAD_FMT($type)

	if {[OT_CfgGet FUNC_GEN_EV_CODE 0]} {
		set gen_code ",p_gen_code=\'Y\'"
	} else {
		set gen_code ",p_gen_code=\'N\'"
	}

	ob::log::write INFO "before queries"

	# queries
	switch -- $type {
		events {
			set sql [subst {
				execute procedure pUpl_Ev(
					p_adminuser = ?,
					p_category = ?,
					p_class = ?,
					p_ev_type = ?,
					p_desc = ?,
					p_start_time = ?,
					p_country = ?,
					p_venue = ?,
					p_sort = ?,
					p_status = ?,
					p_displayed = ?,
					p_disporder = ?,
					p_suspend_at = ?,
					p_url = ?,
					p_tax_rate = ?,
					p_min_bet = ?,
					p_max_bet = ?,
					p_sp_max_bet = ?,
					p_max_place_lp = ?,
					p_max_place_sp = ?,
					p_fb_dom_int = ?,
					p_ext_key = ?,
					p_mult_key = ?,
					p_class_sort = ?,
					p_home_team = ?,
					p_away_team = ?,
					p_channels = ?,
					p_calendar = ?,
					p_event_ll = ?,
					p_event_ltl = ?,
					p_event_lm = ?,
					p_event_mm = ?,
					p_is_off = ?,
					p_flags = ?,
					p_do_tran = 'N'
					$gen_code
				)
			}]
		}
		markets {
			set sql [subst {
				execute procedure pUpl_EvMkt(
					p_adminuser = ?,
					p_ev_mkt_id = ?,
					p_category = ?,
					p_class = ?,
					p_ev_type = ?,
					p_ev_name = ?,
					p_ev_start_time = ?,
					p_market = ?,
					p_market_name = ?,
					p_status = ?,
					p_displayed = ?,
					p_disporder = ?,
					p_tax_rate = ?,
					p_lp_avail = ?,
					p_sp_avail = ?,
					p_gp_avail = ?,
					p_fc_avail = ?,
					p_tc_avail = ?,
					p_ew_avail = ?,
					p_pl_avail = ?,
					p_ew_places = ?,
					p_ew_fac_num = ?,
					p_ew_fac_den = ?,
					p_ew_with_bet = ?,
					p_acc_min = ?,
					p_acc_max = ?,
					p_hcap_value = ?,
					p_liab_limit = ?,
					p_ext_key = ?,
					p_channels = ?,
					p_is_ap_mkt = ?,
					p_bet_in_run = ?,
					p_max_multiple_bet = ?,
					p_win_lp = ?,
					p_win_sp = ?,
					p_win_ep = ?,
					p_place_lp = ?,
					p_place_sp = ?,
					p_place_ep = ?,
					p_min_bet      = ?,
					p_max_bet      = ?,
					p_auto_dh_redn = ?,
					p_hcap_precision  = ?
				)
			}]
		}
		selections {
			set sql [subst {
				execute procedure pUpl_EvOc(
					p_adminuser = ?,
					p_ev_oc_id = ?,
					p_category = ?,
					p_class = ?,
					p_ev_type = ?,
					p_ev_name = ?,
					p_ev_start_time = ?,
					p_market = ?,
					p_desc = ?,
					p_status = ?,
					p_displayed = ?,
					p_disporder = ?,
					p_min_bet = ?,
					p_max_bet = ?,
					p_sp_max_bet = ?,
					p_max_place_lp = ?,
					p_max_place_sp = ?,
					p_max_total = ?,
					p_stk_or_lbt = ?,
					p_lp_num = ?,
					p_lp_den = ?,
					p_sp_num_guide = ?,
					p_sp_den_guide = ?,
					p_fb_result = ?,
					p_cs_home = ?,
					p_cs_away = ?,
					p_ext_key = ?,
					p_mult_key = ?,
					p_channels = ?,
					p_link_key = ?,
					p_do_tran = 'N'
					$gen_code
				)
			}]
		}

		variant {
			set sql [subst {
				execute procedure pUpl_EvOcVariant(
					p_adminuser = ?,
					p_category = ?,
					p_class = ?,
					p_ev_type = ?,
					p_ev_name = ?,
					p_ev_start_time = ?,
					p_market = ?,
					p_selection = ?,
					p_status = ?,
					p_displayed = ?,
					p_disporder = ?,
					p_price_num = ?,
					p_price_den = ?,
					p_value =?,
					p_desc = ?,
					p_type = ?,
					p_apply_price = ?
				)
			}]
		}

		results {
			set sql [subst {
				execute procedure pUpl_Result(
					p_adminuser = ?,
					p_category = ?,
					p_class = ?,
					p_ev_type = ?,
					p_ev_name = ?,
					p_ev_start_time = ?,
					p_market = ?,
					p_ev_oc_name = ?,
					p_result = ?,
					p_place = ?,
					p_sp_num = ?,
					p_sp_den = ?,
					p_win_dh_red_num = ?,
					p_win_dh_red_den = ?,
					p_pl_dh_red_num = ?,
					p_pl_dh_red_den = ?
				)
			}]
		}
		fbscores {
			# HEAT 12417 - jbrandt
			# function to actually update results in autores.tcl
			# only updates all results if SetResults is not ""
			reqSetArg SetResult "Y"
			set handle_proc "ADMIN::AUTORES::upload_qr"
			set sql ""
		}
		payments {
			set sql [subst {
				execute procedure pUpl_Payment(
					p_oper_id = ?,
					p_ipaddr = ?,
					p_username = ?,
					p_acct_no = ?,
					p_lname = ?,
					p_blurb = ?,
					p_extra_info = ?,
					p_pay_type = ?,
					p_amount = ?,
					p_ccy_code = ?,
					p_source = ?,
					p_require_lname = ?,
					p_case_ins_username = ?
				)
			}]
		}
		cheques {
			set sql [subst {
				execute procedure pUpl_Chq(
					p_adminuser = ?,
					p_date = ?,
					p_batch_no = ?,
					p_acct_no = ?,
					p_pay_type = 'CHQ',
					p_cheque_number = ?,
					p_ccy_code = 'GBP',
					p_amount = ?,
					p_require_lname = ?,
					p_case_ins_username = ?
				)
			}]
		}
		adjustments {

			if {$CFG(MAC,enabled)} {
				# Get cust_id_from_acct_no
				set sql [subst {
					select
						count(*)
					from
						tCustomer c
					where
						c.acct_no = ?
				}]
				set stmt_check_acct_no_exists  [inf_prep_sql $DB $sql]

				# Insert customer stub
				set sql [subst {
					execute procedure pInsCustomerStub(
						p_acct_no       = ?,
						p_ccy_code      = ?,
						p_reg_combi     = 'I',
						p_transactional = 'N',
						p_password      = ?,
						p_code_txt      = ?,
						p_country_code  = ?,
						p_lang          = ?
					)
				}]
				set stmt_ins_cust_stub  [inf_prep_sql $DB $sql]
			}


			set sql [subst {
				execute procedure pUpl_ManAdj(
					p_adminuser         = ?,
					p_username          = ?,
					p_acct_no           = ?,
					p_lname             = ?,
					p_desc              = ?,
					p_withdrawable      = ?,
					p_amount            = ?,
					p_ccy_code          = ?,
					p_type              = ?,
					p_subtype           = ?,
					p_bm_acct_type      = ?,
					p_system_name       = ?,
					p_require_lname     = ?,
					p_check_balance     = ?,
					p_batch_ref_id      = ?,
					p_case_ins_username = ?,
					p_pending           = ?
				)
			}]

			if {[OT_CfgGetTrue FORCE_MAN_ADJ_PER_LINE_TXN]} {
				set per_line_trans 1
			}
		}
		pools {
			set sql [subst {
				execute procedure pUpl_Pools(
					p_adminuser = ?,
					p_sort = ?,
					p_draw_at = ?,
					p_ball_no = ?,
					p_team1 = ?,
					p_team2 = ?
				)
			}]
		}
		freebets {
			set sql [subst {
				execute procedure pUplFreeBetToken(
					p_adminuser = ?,
					p_token_id = ?,
					p_username = ?,
					p_currency = ?
				)
			}]
		}
		account_closure {
			set sql [subst {
				execute procedure pUpl_AccountClosure(
					p_adminuser = ?,
					p_acct_no   = ?
				)
			}]
		}
		man_bets {
			set sql [subst {
				execute procedure pUpl_ManBet(
					p_admin_user = ?,
					p_acct_no = ?,
					p_desc_1  = ?,
					p_desc_2  = ?,
					p_desc_3  = ?,
					p_desc_4  = ?,
					p_category = ?,
					p_class = ?,
					p_type = ?,
					p_channel = ?,
					p_stake = ?,
					p_pay_now = ?,
					p_settle_at = ?,
					p_tax_type = ?,
					p_tax_rate = ?,
					p_tax = ?,
					p_result = ?,
					p_winnings = ?,
					p_refund = ?,
					p_stl_comment = ?,
					p_real_cr_date = ?,
					p_rep_code = ?,
					p_on_course_type = ?,
					p_max_payout = ?,
					p_check_balance = ?,
					p_batch_ref_id = ?,
					p_man_bet_in_summary = ?,
					p_receipt_format = ?,
					p_receipt_tag = ?
				)
			}]
		}
		segments {
			set sql [subst {
				execute procedure pUpl_Segment(
					p_cust_id = ?,
					p_group_name = ?,
					p_group_value = ?
				)
			}]

			# can be huge amount of lines
			# do each in its own transaction
			set per_line_trans 1
		}

		custgroups {
			set sql [subst {
				execute procedure pUpl_Segment(
					p_cust_id = ?,
					p_group_name = ?,
					p_group_value = ?
				)
			}]
			set stmt [inf_prep_sql $DB $sql]
			set handle_proc {inf_exec_stmt $stmt}
		}

		ext_ids {
			set sql [subst {
				execute procedure pUplExtCusts(
					p_adminuser = ?,
					p_username = ?,
					p_code = ?,
					p_ext_cust_id = ?,
					p_master = ?
				)
			}]
		}

		custmsgs {
			set sql [subst {
				execute procedure pUplCustMsgs(
					p_adminuser = ?,
					p_username = ?,
					p_cust_id = ?,
					p_type = ?,
					p_msg = ?
				)
			}]
		}
		cust_notices {
			set sql {
				execute procedure pUplCustNotice(
					p_adminuser  = ?,
					p_cust_id    = ?,
					p_acct_id    = ?,
					p_ntc_title  = ?,
					p_from_date  = ?,
					p_to_date    = ?
				)
			}
		}
		exclusions {
			set sql {
				execute procedure pUplExclusions(
					p_adminuser      = ?,
					p_acct_no        = ?,
					p_type           = ?,
					p_sys_group_name = ?,
					p_channel_name   = ?
				)
			}
		}
		affiliates {
			set sql {
				execute procedure pUplBeFreeAff(
					p_adminuser  = ?,
					p_source_id  = ?,
					p_affiliate  = ?,
					p_bf_id      = ?,
					p_program    = ?,
					p_bet_aff    = ?,
					p_reg_aff    = ?
				)
			}
		}
		synonyms {
			set sql [subst {
				execute procedure pSearchInsSynonym(
					p_adminuser = ?,
					p_keyword   = ?,
					p_synonym   = ?,
					p_lang      = ?,
					p_disporder = ?
				)
			}]
		}

		predefined {
			set sql [subst {
				execute procedure pSearchInsPredefined(
					p_adminuser   = ?,
					p_keyword     = ?,
					p_link        = ?,
					p_url         = ?,
					p_lang        = ?,
					p_disporder   = ?,
					p_canvas_name = ?
				)
			}]
		}

		stmt_record {
			set sql [subst {
				execute procedure pUpl_StmtRecord(
					p_adminuser      = ?,
					p_review_date    = ?,
					p_acct_no        = ?,
					p_date_from      = ?,
					p_date_to        = ?,
					p_product_filter = ?
				)
			}]
		}

		trigger_accts {
			set sql [subst {
				execute procedure pUpl_LoginActCust(
					p_adminuser    = ?,
					p_acct_no      = ?,
					p_action_code  = 'UPDATE_DETAILS',
					p_batch_ref_id = ?
				)
			}]
		}

		advertisers {
			set sql {
				execute procedure pUpl_AUAdvertisers(
					p_adminuser  = ?,
					p_advertiser = ?,
					p_desc       = ?
				)
			}
		}

		default {
			ob::log::write INFO {default external sql for $type}
			#may be a non-openbet table upload
			set sql [set UPLOAD_SQL($type)]
		}
	}

	if {![info exists handle_proc]} {
		set stmt [inf_prep_sql $DB $sql]
	}

	ob::log::write INFO "after queries"



	if { $type == "selections" || $type == "markets" } {

		if {$type == "selections"} {
			set get_mkt_grp_sql {

				select
					m.sort
				from
					tevmkt m,
					tev e,
					tevtype t,
					tevclass c
				where
					m.name        = ? and
					m.ev_id       = e.ev_id and
					e.desc        = ? and
					e.start_time  = ? and
					e.ev_type_id  = t.ev_type_id and
					t.name        = ? and
					t.ev_class_id = c.ev_class_id and
					c.name        = ? and
					c.category    = ?
			}
			if {$do_update_seln} {
				set get_ev_oc_id_sql [subst {

					select
						s.ev_oc_id
					from
						tevoc s,
						tevmkt m,
						tev e,
						tevtype t,
						tevclass c
					where
						s.desc        = ? and
						s.ev_mkt_id   = m.ev_mkt_id and
						m.name        = ? and
						m.ev_id       = e.ev_id and
						e.desc        = ? and
						e.start_time  = ? and
						e.ev_type_id  = t.ev_type_id and
						t.name        = ? and
						t.ev_class_id = c.ev_class_id and
						c.name        = ? and
						c.category    = ?
				}]
				set get_ev_oc_id_stmt [inf_prep_sql $DB $get_ev_oc_id_sql]
			}
		} else {
			set get_mkt_grp_sql {

				select distinct
					g.sort
				from
					tevocgrp g,
					tevtype t,
					tevclass c
				where
					t.ev_type_id = g.ev_type_id
					and c.ev_class_id = t.ev_class_id
					and t.name=?
					and g.name=?
					and c.name=?
			}
			if {$do_update_seln} {
				set get_ev_mkt_id_sql [subst {

					select
						m.ev_mkt_id
					from
						tevmkt m,
						tev e,
						tevtype t,
						tevclass c
					where
						m.name        = ? and
						m.ev_id       = e.ev_id and
						e.desc        = ? and
						e.start_time  = ? and
						e.ev_type_id  = t.ev_type_id and
						t.name        = ? and
						t.ev_class_id = c.ev_class_id and
						c.name        = ? and
						c.category    = ?
				}]
				set get_ev_mkt_id_stmt [inf_prep_sql $DB $get_ev_mkt_id_sql]
			}
		}

		set get_mkt_grp_stmt [inf_prep_sql $DB $get_mkt_grp_sql]
	}
	set bad 0

	set rollback 0

	ob::log::write INFO "after queries selection market"

	# Dealing with the file
	if {!$per_line_trans} {
		ob::log::write DEBUG "do_upload_load: Beginning txn, *no* per-line functionality"
		inf_begin_tran $DB
		set rollback 1

		# we need to create a row in tBatchReference if necessary-
		# this will rollback if the manual adjustments fail.
		if {($type == "adjustments" || $type == "man_bets")\
			 && $use_batch_ref == 1 && $prev_batch_add == 0} {
			set batch_ref_create_sql {
				insert into tBatchReference(batch_ref_id,location) values(?,?)
			}
			set batch_create_stmt [inf_prep_sql $DB $batch_ref_create_sql]
			set err [catch {db_close [inf_exec_stmt $batch_create_stmt $batch_ref_id $batch_ref_location]} msg]
			catch {inf_close_stmt $batch_create_stmt}
			if {$is_oncourse} {
				# If is on-course transaction, and the reference was created successfully
				# associate the reference to the course
				set batch_course_sql {
					execute procedure pInsOnCourseBatch (
						p_ocb_id        =  ?
						p_batch_ref_id  =  ?,
						p_meeting_key   =  ?,
						p_course        =  ?,
						p_process_date  =  ?
					)
				}
				set batch_course_stmt [inf_prep_sql $DB $batch_course_sql]
				set err [catch {db_close [inf_exec_stmt $batch_course_stmt $ocb_id $batch_ref_id $meeting $course [clock format [clock seconds] -format {%Y-%m-%d %T}]]} msg]
				catch {inf_close_stmt $batch_course_stmt}
			}
			if {$err} {
				ob::log::write ERROR "Failed to insert row into tBatchReference: $msg"
				err_bind $msg
				error $msg
			} else {
				ob::log::write DEBUG "Inserted row $batch_ref_id, $batch_ref_location into tBatchReference"
			}

			tpBindString BatchRefID $batch_ref_id

		}

	}

	# we use tBatchReference to store the filename when uploading for tLoginActCust
	# we do this here regardless of per_line_trans to reuse the same id
	if {$type == "trigger_accts"} {
		# get new batch ref id
		set batch_ref_sql {
			select max(batch_ref_id) max_batch_ref from tBatchReference
		}
		set batch_stmt [inf_prep_sql $DB $batch_ref_sql]
		set rs         [inf_exec_stmt $batch_stmt]
		set nrows      [db_get_nrows $rs]
		if {$nrows == 1} {
			set temp_ref_id [string trim [db_get_col $rs 0 max_batch_ref]]
			if {$temp_ref_id == ""} {
				set temp_ref_id 0
			}
			set batch_ref_id [expr {$temp_ref_id + 1}]
			ob::log::write DEBUG "Next batch reference ID from DB: $batch_ref_id"
			catch {db_close $rs}
		} else {
			catch {db_close $rs}
			set err_msg "Cannot create a system-set batch reference ID"
			ob::log::write ERROR $err_msg
			err_bind $err_msg
			error $err_msg
		}

		# store this value
		set batch_ref_create_sql {
			insert into tBatchReference(batch_ref_id,location) values(?,?)
		}
		set batch_create_stmt [inf_prep_sql $DB $batch_ref_create_sql]
		set err [catch {db_close [inf_exec_stmt $batch_create_stmt $batch_ref_id $fname]} msg]
		catch {inf_close_stmt $batch_create_stmt}

	}

	set line_num 0

	set failed_list [list]
	set errors ""

	set batch_ref_ins 0


	set session_names [list]
	foreach n [OT_CfgGet UPLOAD_DRIPFEED_SESSIONS ""] {
		lappend session_names "'$n'"
	}

	if {[OT_CfgGet UPLOAD_DRIPFEED_ENABLED 0] && $session_names != ""} {
		set oxi_queue_size_qry [subst {
			select
				name,
				(select max(msg_id) from tOXiMsg) - last_ack_id as queue
			from
				tOXiRepSess
			where
				name in ([join $session_names ,])
		}]

		set oxi_queue_size_stmt [inf_prep_sql $DB $oxi_queue_size_qry]

	}

	for {set l 0} {$l < $FILE(NUM_LINES)} {incr l} {

		set rollback 1

		if {[catch {

			# line_num set here to avoid array indexing errors in create_failed_file
			set line_num $l

			# DO OVS check.

			if {$CFG(ovs)} {
				switch -- $type {
					adjustments -
					payments {
						set result [do_ovs_chk $l $type]
						if {![lindex $result 0]} {
							set rollback 0

							set err_msg "[lindex $result 1]"
							err_bind $err_msg
							error $err_msg
						}
					}
				}
			}
			switch -- $type {
				cheques -
				payments {
					set result [do_cust_limit_check $l $type]
					if {![lindex $result 0]} {
						set rollback 0
						error "[lindex $result 1]"
					}
				}
			}

			#
			# One-at-a-time transactions
			#
			if {$per_line_trans} {
				ob::log::write DEBUG "do_upload_load: Beginning txn, with per-line functionality"

				tpBindString BatchRefID $batch_ref_id

				inf_begin_tran $DB
				set rollback 1

				# we need to create a row in tBatchReference if necessary-
				# this will rollback if the manual adjustments fail.
				# NB - per line functionality: do it only once!
				if {($type == "adjustments" || $type == "man_bets")\
					 && $use_batch_ref == 1 && $batch_ref_ins == 0  && $prev_batch_add == 0} {
					set batch_ref_create_sql {
						insert into tBatchReference(batch_ref_id,location) values(?,?)
					}
					set batch_create_stmt [inf_prep_sql $DB $batch_ref_create_sql]
					set err [catch {db_close [inf_exec_stmt $batch_create_stmt $batch_ref_id $batch_ref_location]} msg]
					catch {inf_close_stmt $batch_create_stmt}
					if {$is_oncourse} {
						# If is on-course transaction, and the reference was created successfully
						# associate the reference to the course
						set batch_course_sql {
							execute procedure pInsOnCourseBatch (
								p_ocb_id        =  ?,
								p_batch_ref_id  =  ?,
								p_meeting_key   =  ?,
								p_course        =  ?,
								p_process_date  =  ?
							)
						}
						set batch_course_stmt [inf_prep_sql $DB $batch_course_sql]
						set err [catch {db_close [inf_exec_stmt $batch_course_stmt $ocb_id $batch_ref_id $meeting $course [clock format [clock seconds] -format {%Y-%m-%d %T}]]} msg]
						catch {inf_close_stmt $batch_course_stmt}
					}
					if {$err} {
						ob::log::write ERROR "Failed to insert row into tBatchReference: $msg"
						err_bind $msg
						error $msg
					} else {
						ob::log::write DEBUG "Inserted row $batch_ref_id into tBatchReference"
						set batch_ref_ins 1
					}

					tpBindString BatchRefID $batch_ref_id
				}
			}

			# set $line_num at the top of the loop in case of error.
			# set line_num $l

			# We check the queue size every UPLOAD_DRIPFEED_CHECK_INTERVAL and
			# if it's over UPLOAD_DRIPFEED_MAX_QUEUE we'll pause for
			# UPLOAD_DRIPFEED_PAUSE_SECONDS seconds
			ob::log::write INFO "Drip Feed logic settings for $type: \
								UPLOAD_DRIPFEED_ENABLED=[OT_CfgGet UPLOAD_DRIPFEED_ENABLED 0] \
								UPLOAD_DRIPFEED_TYPES=[OT_CfgGet UPLOAD_DRIPFEED_TYPES {}] \
								drip_feed_enabled checkbox flag value=$drip_feed_enabled"
			if {[OT_CfgGet UPLOAD_DRIPFEED_ENABLED 0] &&
				[lsearch [OT_CfgGet UPLOAD_DRIPFEED_TYPES ""] $type] != -1 &&
				$session_names != "" && $drip_feed_enabled != 0
			} {

				set drip_feed_abort 0

				if {$l % [OT_CfgGet UPLOAD_DRIPFEED_CHECK_INTERVAL 50] == 0} {
					set proceed 0
					set start_time [clock scan now]
					while {!$proceed} {
						if {[catch {
							set res [inf_exec_stmt $oxi_queue_size_stmt]
						} msg]} {
							err_bind $msg
							error $msg
						}
						set nrows [db_get_nrows $res]
						set max_queue 0
						set max_queue_sess ""
						for {set i 0} {$i < $nrows} {incr i} {
							set queue [db_get_col $res $i queue]
							if {$queue > $max_queue} {
								set max_queue $queue
								set max_queue_sess [db_get_col $res $i name]
							}
						}
						db_close $res
						# Check the queue length and how long we've taken so
						# far
						set time_diff [expr {[clock scan now] - $start_time}]
						if {$max_queue > [OT_CfgGet UPLOAD_DRIPFEED_MAX_QUEUE 1000] &&
							$time_diff < [OT_CfgGet UPLOAD_DRIPFEED_MAX_WAIT 60]} {
							set pause [expr {1000 * [OT_CfgGet UPLOAD_DRIPFEED_PAUSE_SECONDS]}]
							ob::log::write INFO "OXi rep queue of $max_queue for for sess $max_queue_sess.  Pausing for $pause ms"
							after $pause
							ob::log::write INFO "checking again..."
						} elseif {$time_diff < [OT_CfgGet UPLOAD_DRIPFEED_MAX_WAIT 60]} {
							set proceed 1
						} else {
							set drip_feed_abort 1
							ob::log::write ERROR "Waited ${time_diff}s for OXi \
							   replication queue to reduce - aborting"
							set err_msg "Waited ${time_diff}s for OXi replication \
								queue '$max_queue_sess' to reduce to less than \
								[OT_CfgGet UPLOAD_DRIPFEED_MAX_QUEUE 1000]. \
								$max_queue_sess queue size is $max_queue. Aborted."
							err_bind $err_msg
							error $err_msg
						}
					}
				}
			}

			if {[info exists handle_proc]} {
				set row "$handle_proc "
			} elseif {$type == "segments"} {
				set row "inf_exec_stmt $stmt "
			} elseif {$type != "payments"} {
				set row "inf_exec_stmt $stmt {$USERNAME} "
			} else {
				set row "inf_exec_stmt $stmt $USERID [reqGetEnv REMOTE_ADDR] "
			}

			if { $type == "markets" || $type == "selections" } {
				set type_name      $FILE($l,[locate_field TYPE],DATA)
				set ev_oc_grp_name $FILE($l,[locate_field MARKET],DATA)
				set class_name     $FILE($l,[locate_field CLASS],DATA)
				set event_name     $FILE($l,[locate_field NAME],DATA)
				set start_time     $FILE($l,[locate_field DATE/TIME],DATA)
				set category_name  $FILE($l,[locate_field CATEGORY],DATA)

				set market_name $ev_oc_grp_name
				if { $type == "markets" && [info exists FILE($l,[locate_field "MARKET NAME"],DATA)]} {
					set market_name_col    $FILE($l,[locate_field "MARKET NAME"],DATA)
					if {$market_name_col != ""} {
						set market_name $market_name_col
					}

				}
				if { $type == "selections" } {
					set rs [inf_exec_stmt $get_mkt_grp_stmt $market_name $event_name $start_time $type_name $class_name $category_name]
				} else {
					set rs [inf_exec_stmt $get_mkt_grp_stmt $type_name $ev_oc_grp_name $class_name]
				}

				if {[db_get_nrows $rs]!=1} {
					catch {db_close $rs}

					set err_msg "Can't find market group $ev_oc_grp_name in  $class_name -> $type_name"

					if { $type == "selections" } {
						set err_msg "Can't find market $market_name in $category_name -> $class_name -> $type_name -> $event_name $start_time "
					}
					ob::log::write ERROR {$err_msg}

					err_bind $err_msg
					error $err_msg
				}
				set mkt_sort [db_get_col $rs 0 sort]
				db_close $rs
				if { $type == "selections"} {
					set ev_oc_id  -1
					if {$do_update_seln} {
						set seln_name $FILE($l,[locate_field SELECTION],DATA)
						catch {[
							set rs   [inf_exec_stmt $get_ev_oc_id_stmt $seln_name $market_name $event_name $start_time $type_name $class_name $category_name]
						] msg} {
							set err_msg "error executing query: $msg"
							err_bind $err_msg
							error $err_msg
						}
						if {[db_get_nrows $rs]!=1} {
							db_close $rs
							set err_msg "Update: can't find selection name $seln_name for market $market_name in type $type_name"
							ob::log::write ERROR {$err_msg}
							err_bind $err_msg
							error $err_msg
						}
						set ev_oc_id [db_get_col $rs 0 ev_oc_id]
						db_close $rs
					}
					append row "{$ev_oc_id} "
				} elseif { $type == "markets"} {
					set ev_mkt_id -1
					if {$do_update_seln} {
						catch {[
							set rs   [inf_exec_stmt $get_ev_mkt_id_stmt $market_name $event_name $start_time $type_name $class_name $category_name]
						] msg} {
							set err_msg "error executing query: $msg"
							err_bind $err_msg
							error $err_msg
						}
						if {[db_get_nrows $rs]!=1} {
							db_close $rs
							ob::log::write ERROR {Update: can't find market $market_name in type $type_name}
							set err_msg "Update: can't find market $market_name in type $type_name"
							err_bind $err_msg
							error $err_msg
						}
						set ev_mkt_id [db_get_col $rs 0 ev_mkt_id]
						db_close $rs
					}
					append row "{$ev_mkt_id} "
				}

				#
				# Convert hcap to internal integer value if necessary.
				#
				if { $type == "markets"
						&& [lsearch [list AH A2 hl] $mkt_sort] != -1} {
					set index [locate_field HANDICAP]
					set FILE($l,$index,DATA) [parse_hcap_str $FILE($l,$index,DATA)]
				}

			}

			if {$type == "affiliates"} {
				set prog_name  $FILE($l,[locate_field PROGRAM],DATA)
				set bf_id      $FILE($l,[locate_field BF_ID],DATA)

				# Get the program id
				set prog_id_sql {
					select
						prog_id
					from
						tProgram
					where
						prog_name = ?
					and
						status = 'A'
				}

				set prog_stmt [inf_prep_sql $DB $prog_id_sql]
				set rs        [inf_exec_stmt $prog_stmt $prog_name]
				set nrows     [db_get_nrows $rs]

				# Get the source id from BeFree
				if {$nrows > 0} {
					set prog_id [db_get_col $rs 0 prog_id]

					# Get the source id via the http request
					set prog_name [string toupper $prog_name]
					set bfmid [OT_CfgGet "MERCHANT_$prog_name"]

					if {[catch {set http_response [http::geturl "[OT_CfgGet BEFREE_SOURCE_ID_URL]?bfmid=$bfmid&siteid=$bf_id&bfpage=bf_advanced&bfurl=http%3A%2F%2Fwww%2Eladbrokes%2Ecom&bfcookietest=N"]} msg]} {
						ob::log::write ERROR {Failed to retrieve response from BeFree server: $msg}
						err_bind $msg
					}

					# check that the response is valid
					set result [validate_response $http_response]
					if {[lindex $result 0]>0} {
						ob::log::write ERROR {Bad response from BeFree server: [lindex $result 1]}
						err_bind [lindex $result 1]
					}

					ob::log::write INFO "Got URL response: [http::data $http_response]"
					regexp {sourceid=([^&]+)} [http::data $http_response] unused source_id

					set source_id "$source_id "

					ob::log::write INFO {Adding new BeFree affiliate. source_id = $source_id}

					# Append the source id to the statement
					append row $source_id

					# Garbage collect request
					http::cleanup $http_response
				} else {
					set err_msg "do_upload_load => No prog_id defined for $prog_name in tProgram"
					ob::log::write ERROR {$err_msg}
					err_bind $err_msg
					reqSetArg course $course
					reqSetArg meeting $meeting
					reqSetArg ocb_id $ocb_id
					asPlayFile -nocache $UPLOAD_TYPE($type,html)

					if {[OT_CfgGet UPLOAD_DRIPFEED_ENABLED 0]} {
						inf_close_stmt $oxi_queue_size_stmt
					}
					return
				}

				db_close $rs
				unset rs nrows
			}

			if {$type == "stmt_record"} {
				# check for review date if debt management turned on
				if {[OT_CfgGet FUNC_DEBT_MANAGEMENT 0]} {
					set acct_no  $FILE($l,[locate_field "ACCOUNT NUMBER"],DATA)
					# Get review date
					set sql {
						select
							f.flag_value
						from
							tCustomer     c,
							tCustomerFlag f
						where
								c.cust_id = f.cust_id
							and f.flag_name = 'ChaseArrGrace'
							and c.acct_no = ?
					}

					set review_date_stmt    [inf_prep_sql $DB $sql]
					set rs                  [inf_exec_stmt $review_date_stmt $acct_no]
					set nrows               [db_get_nrows $rs]

					if {$nrows != 1} {
						set num_days [OT_CfgGet DEBT_MAN_GRACE_PERIOD 11]
					} else {
						set num_days  [db_get_col $rs 0 flag_value]
					}
					inf_close_stmt $review_date_stmt
					db_close $rs
					unset rs nrows

					set review_date [clock format [clock scan "+$num_days days"\
						-base [clock seconds]] -format "%Y-%m-%d"]

				} else {
					set review_date {}
				}

				set review_date "{$review_date} "
				append row $review_date
			}

			#
			# build up the arguments
			#
			for {set i 0; set j 0} {$i < [llength $fields]} {} {

				#
				# generate the argument(s)
				#
				set f_spec    [string trim [lindex $fields $i]]
				set f_type    [string trim [lindex $f_spec 0]]
				set f_name    [string trim [lindex $f_spec 1]]
				set f_special [string trim [lindex $f_spec 2]]

				ob::log::write DEV "do_upload_load: f_spec: $f_spec f_type: $f_type f_name: $f_name f_special: $f_special"

				if {$f_special=="FB_RESULT" && $type=="selections"} {
					set f_special ${f_special}_${mkt_sort}
				}
				if {$j < $FILE(HEADER,NUM_COLS)} {

					set l_data    [string trim $FILE($l,$j,DATA)]

					## Due to Bluesq/Littlewoods confusion football pools dates are sent in the format
					## DD-MM-YYYY HH:MM or DD/MM/YYYY HH:MM
					## This must be stored in database as YYYY-MM-DD HH:MM:SS
					## i.e. pools.csv contains 04/06/2002 15:00
					## Store this as 2002-06-04 15:00:00

					if {[regexp $drx $l_data time d m y hh mm]} {
						set l_data "$y-$m-$d $hh:$mm:00"
					}
					set l_name    $FILE($j,HEADER)

				} else {
					set l_data    ""
					set l_name    ""
				}

				# for the betlive schedule
				# entry could be Y or N, depends if the betlive schedule flag has to be on or off
				#
				if {$f_name == "BETLIVE SCHEDULE" && $type=="events"} {
					if {$l_data == "N"} {
						set l_data "RN"
					}
					if {$l_data == "Y"} {
						set l_data "RN,BS"
					}
				}

				#
				# see if we're copying from another column
				#
				if {[lindex $f_type 0] == "MC" && $l_data == ""} {
					set col [locate_field [lindex $f_type 1]]
					if {$col == -1} {
						set al_data ""
					} else {
						set al_data [string trim $FILE($l,$col,DATA)]
					}
				}

				if {[lindex $f_type 0] == "M"} {
					#
					# Mandatory field
					#
					if {$f_name != $l_name} {
						set err_msg "mandatory field not present"
						err_bind $err_msg
						error $err_msg
					}
					if {$f_name == "DESCRIPTION" && $type == "man_bets"} {
						append row [get_args_for "DESCRIPTION" $l_data $type]
					} else {

						set row_val [get_args_for $f_special $l_data $type]

  						if { $type == "cheques" &&  $f_name == "VALUE" } {

  					   		# This ugly, but the value has curley brackets around it {123} including space char, extract the number
  					   		set row_val [ string trim $row_val " " ]
  					   		set row_val [ string range $row_val 1 [expr [string length $row_val] - 2] ]

  					   		# Now convert from pence to pound
  					   		set row_val [expr {$row_val * 0.01}]

  					   		# Now put back to previous format !!
  					   		set row_val "{$row_val} "
  						}

						if {$type == "adjustments"} {
							# This is pretty hacky, but we need these values to check
							# the operator has permission for this value manual adjustment
							set trimmed_val [ string trim $row_val " " ]
							set trimmed_val [ string range $trimmed_val 1 [expr [string length $trimmed_val] - 2] ]
							switch -- $f_name {
								"AMOUNT"        {set man_adj_amount $trimmed_val}
								"CURRENCY CODE" {set man_adj_ccy    $trimmed_val}
								"TYPE"          {set man_adj_type   $trimmed_val}
							}
						}

						append row $row_val
					}
					incr i
					incr j
				} elseif {[lindex $f_type 0] == "MI"} {
					#
					# If not not present, append empty arg
					#
					if {$l_data != ""} {
						append row [get_args_for $f_special $l_data $type]
					} else {
						append row "{} "
					}
					incr i
					incr j
				} elseif {[lindex $f_type 0] == "MC"} {
					#
					# Mandatory copy field, if no value is supplied for this column
					# then check to see if we can copy from another columns
					# (ie. fb_side -> fb_result
					#
					if {$f_name != $l_name} {
						set err_msg "mandatory field not present"
						err_bind $err_msg
						error $err_msg
					}
					if {$l_data != ""} {
						append row [get_args_for $f_special $l_data $type]
					} else {
						append row [get_args_for $f_special $al_data $type]
					}
					incr i
					incr j

				} elseif {[lindex $f_type 0] == "D"} {
					#
					# Discard this column
					#
					if {$f_name == $l_name} {
						incr j
					}
					incr i

				} elseif {[lindex $f_type 0] == "A"} {
					#
					# Add this column to the data if not present
					# (with default value if available)
					#
					if {$f_name == $l_name} {
						append row [get_args_for $f_special $l_data $type]
						incr j
					} else {
						append row [get_args_for $f_special [lindex $f_type 1] $type]
					}
					incr i

				} else {
					set err_msg "unrecognised field spec"
					err_bind $err_msg
					error $err_msg
				}

				if {$CFG(MAC,enabled) \
				    && $type   == "adjustments" \
				    && $f_name == "USERNAME" \
				} {
					set cust_username $l_data
				}

			}

			if {$type == "adjustments"} {
				# Check operator has permission for this manual adjustment
				if {[OT_CfgGet FUNC_MANADJ_IMMEDIATE 0]} {
					set action_name AdHocFundsXfer
					set stage "N"
				} else {
					set action_name ManAdjRaise
					set stage "R"
				}

				if {[OT_CfgGet FUNC_MANADJ_PERM_BY_TYPE 0]} {
					foreach {succ msg} [ADMIN::ADJ::check_type_perm $stage $man_adj_type] {
						if {$succ != "OB_OK"} {
							OT_LogWrite 1 $msg
							error $msg
						}
					}
				} else {
					if {![op_allowed $action_name]} {
						OT_LogWrite 1 "missing permission $action_name"
						error "missing permission $action_name"
					}
				}

				if {[OT_CfgGet FUNC_MAN_ADJ_THRESHOLDS 0] == 1} {
					if {![ADMIN::CUST::check_threshold \
							$man_adj_amount \
							[split [OT_CfgGet MAN_ADJ_RAISE_THRESHOLD_LEVELS] ","] \
							$man_adj_ccy \
							"R" \
					]} {
						OT_LogWrite 1 "Admin user doesn't have permission required for a manual adjustment of size [reqGetArg Amount]"
						error "You don't have permission to raise manual adjustments this large"
					}
				}
			}

			if {$type == "adjustments" || $type == "man_bets"} {
				if {$no_balance_chk == 1} {
					set check_balance "N"
				} else {
					set check_balance "Y"
				}
				ob::log::write DEBUG "Balance checking for adjustments/man_bets: $check_balance"
			}

			if {$type == "adjustments"} {
				# we don't require an lname with an acct_no
				append row "N "
				append row "$check_balance "

				if {$batch_ref_id == ""} {
					append row "{} "
				} else {
					append row "$batch_ref_id "
				}

				if {[OT_CfgGet FUNC_DEF_CASE_INS_SEARCH 0]} {
					# search using case insensitive username
					append row "Y "
				} else {
					append row "N "
				}

				if {[OT_CfgGet FUNC_MANADJ_IMMEDIATE 0]} {
					append row "N"
				} else {
					append row "R"
				}

				# Does this username exist?
				if {$CFG(MAC,enabled)} {

					if {[catch {
						set res [inf_exec_stmt $stmt_check_acct_no_exists $cust_username]
					} msg]} {

						ob::log::write ERROR "ERRORS check_acct_no_exists: $msg"
						error "Internal error code 1"

					}

					set num_custs [db_get_coln $res 0 0]
					if {$num_custs != 1} {

						db_close $res

						# If the account does not exist, create it
						if {($num_custs == 0)} {
							if {[catch {
								# For PMU, usernames and acct_no as the same
								set res [inf_exec_stmt $stmt_ins_cust_stub \
									$cust_username \
									$CFG(MAC,ccy) \
									$CFG(MAC,pwd) \
									$CFG(MAC,txt) \
									$CFG(MAC,country_code) \
									$CFG(MAC,lang) \
								]
							} msg]} {

								ob::log::write ERROR "ERRORS ins_cust_stub: $msg"
								error "Internal error code 2"
							}

							set cust_id  [db_get_coln $res 0 0]
							ob::log::write INFO "Account {$cust_username} does not exist. Created cust_id $cust_id."
							db_close $res

						} else {

							ob::log::write ERROR "ERRORS get_cust_id_from_acct_no: there is not exactly one row. There has been a problem somewhere."
							error "Internal error code 3"
						}
					} else {
						db_close $res
					}

				}

			}

			if {$type == "man_bets"} {
				append row "{[OT_CfgGet DFLT_MAX_PAYOUT 1000]} "
				append row "$check_balance "
				if {$batch_ref_id == ""} {
					append row "{} "
				} else {
					append row "$batch_ref_id "
				}

				# insert some manual bets into tBetSummary
				set summarize_bet "N"
				if {[OT_CfgGet FUNC_SUMMARIZE_ONCOURSE_BETS 0] &&
					($course != "" || $meeting != "")} {
						set summarize_bet "Y"
				}
				append row "$summarize_bet "

				# Receipt formatting options
				append row "{[OT_CfgGet BET_RECEIPT_FORMAT 0]} "
				append row "{[OT_CfgGet BET_RECEIPT_TAG {}]} "
			}

			if {$type == "payments"  ||  $type == "cheques"} {
				# we don't require an lname with an acct_no
				append row "N "
				if {[OT_CfgGet FUNC_DEF_CASE_INS_SEARCH 0]} {
					# we require a case insensitive username search
					append row "Y"
				} else {
					append row "N"
				}
			}


			if {$type == "trigger_accts"} {
				append row "$batch_ref_id"
			}

			ob::log::write INFO { \n Before: The row is $row }

			set row [get_static_args $row]

			#
			# execute the procedure with built up args
			#
			ob::log::write DEBUG "row is : $row"
			set res [eval $row]
		} msg]} {
			set bad 1

			if {$per_line_trans} {
				if {$path != ""} {
					append errors "\n"
				} else {
					append errors "<br>&nbsp;&nbsp;&nbsp;&nbsp;"
				}
			}
			append errors "Line: [expr {$line_num+1}] Error: $msg"
			ob::log::write INFO "Error: Rolling back txn (${msg})"

			if {$rollback} {
				inf_rollback_tran $DB
			}

			tpSetVar UploadFailed 1
			tpBindString ErrLine [expr {$line_num+1}]
			# Don't change this index - we want to send a zero-indexed $line_num
			# to the failed_list proc, NOT ($line_num+1)
			lappend failed_list [expr {$line_num}]

			#
			# break out of loop if we treat whole upload as transaction
			#
			if {!$per_line_trans} {
				break
			}

		} else {
			tpSetVar UploadOK 1

			#
			# End one-at-a-time transaction
			#
			if {$per_line_trans} {
				inf_commit_tran $DB
			}
		}
	}

	# Close it only after the loop. Otherwise it will produce errors
	if {[OT_CfgGet UPLOAD_DRIPFEED_ENABLED 0]} {
		inf_close_stmt $oxi_queue_size_stmt
	}

	#
	# if there were no errors and the entire upload is in a transaction
	# we commit it now
	#
	if {![info exists handle_proc] && !$per_line_trans && !$bad} {
		inf_commit_tran $DB
	}

	if {$type == "selections"} {
		inf_close_stmt $get_mkt_grp_stmt
		if {$do_update_seln} {
			inf_close_stmt $get_ev_oc_id_stmt
		}
	}

	if {$type == "markets"} {
		if {$do_update_seln} {
			inf_close_stmt $get_ev_mkt_id_stmt
		}
	}

	if {![info exists handle_proc]} {
		inf_close_stmt $stmt
	}

	set value_return SUCCESS

	if {$bad} {

		if {$path != ""} {
			err_bind $errors 1
		} else {
			err_bind $errors
		}

		# if we treat each row in the upload as a transaction and some errors were present at the end of the loop,
		# generate a file of REJECTED rows
		#
		if {$per_line_trans} {

			set rejected_name [create_failed_file $failed_list $type $name "" $path]

			tpSetVar RejectedFileCreated 1
			tpSetVar num_success [expr {$FILE(NUM_LINES) - [llength $failed_list]}]

			#It is possible that some succeeded and some failed.
			if {[tpGetVar num_success 0] > 0 } {
				tpSetVar PartialUpload 1
				if {$path != ""} {
					create_success_file $failed_list $type $name $path
				}
			}

			tpSetVar num_total $FILE(NUM_LINES)

			reqSetArg FullName $rejected_name
			reqSetArg edit 1
		}

		set value_return ERROR
	}

	catch {unset FILE}

	reqSetArg course        $course
	reqSetArg meeting       $meeting
	reqSetArg ocb_id        $ocb_id
	if {$path != ""} {
		return $value_return
	} else {
 		go_upload_file
	}
}



#
# Do age verification check for a line/type.
#
proc do_ovs_chk {line type} {
	global DB FILE

	set acct_no  $FILE($line,[locate_field "ACCOUNT NUMBER"],DATA)
	set username $FILE($line,[locate_field "USERNAME"],DATA)

	# Get acct_id
	set sql {
		select
			a.acct_id
		from
			tCustomer c,
			tAcct     a
		where
				c.cust_id = a.cust_id
			and  (c.acct_no = ? or c.username = ?)
	}
	set stmt    [inf_prep_sql $DB $sql]
	set rs      [inf_exec_stmt $stmt $acct_no $username]
	set nrows   [db_get_nrows $rs]

	if {!$nrows} {
		return [list 0 "Account Number invalid"]
	}

	set acct_id  [db_get_col $rs 0 acct_id]
	set pay_sort [expr {$FILE($line,[locate_field "AMOUNT"],DATA) < 0 ? "W" : "D"}]

	switch -- $type {
		payments {
			# Do OVS check.
			set pmt_type $FILE($line,[locate_field "PAYMENT TYPE"],DATA)

			set chk_resp [verification_check::do_verf_check \
				$pmt_type \
				$pay_sort \
				$acct_id \
				"Y"]

			# Error get caught generically.
			if {![lindex $chk_resp 0]} {
				return [list 0 "[lindex $chk_resp 2]"]
			}
		}
		adjustments {
			set chk_resp [verification_check::do_verf_check \
				"ADJ" \
				$pay_sort \
				$acct_id \
				"Y"]

			# Error get caught generically.
			if {![lindex $chk_resp 0]} {
				return [list 0 "[lindex $chk_resp 2]"]
			}
		}
	}

	return 1
}

proc do_cust_limit_check {line type} {

	global DB FILE

	if {$type == "cheques"} {
		set acct_no  $FILE($line,[locate_field "ACCOUNTNUMBER"],DATA)
		set amount  $FILE($line,[locate_field "VALUE"],DATA)

		# For cheques, the amount is in pence. We need to convert it to
		# pounds before we do the limits check
		set amount [expr {$amount * 0.01}]

	} elseif {$type == "payments"} {
		set acct_no  $FILE($line,[locate_field "ACCOUNT NUMBER"],DATA)
		set amount  $FILE($line,[locate_field "AMOUNT"],DATA)
	} else {
		# should never enter here
		return [list 0 "Cannot perform deposit limit check for $type upload type"]
	}

	# Get cust_id
	set sql {
		select
			cust_id
		from
			tCustomer
		where
			acct_no = ?
	}
	set stmt    [inf_prep_sql $DB $sql]
	set rs      [inf_exec_stmt $stmt $acct_no]
	set nrows   [db_get_nrows $rs]

	if {!$nrows} {
		return [list 0 "Account Number invalid"]
	}
	set cust_id  [db_get_col $rs 0 cust_id]

	#check dep limits
	set dep_limits [ob_srp::check_deposit $cust_id $amount]

	set dep_allowed [lindex $dep_limits 0]
	set min_dep     [lindex $dep_limits 1]
	set max_dep     [lindex $dep_limits 2]
	set reason      [lindex $dep_limits 3]
	if {[lindex $dep_limits 0] != 1} {
		return [list 0 "Deposit not allowed: $reason min deposit:$min_dep max deposit:$max_dep"]
	}

	return 1
}

proc get_static_args {row} {
	set static_arg_count [reqGetArg static_arg_count]

	if {$static_arg_count!=""} {
		for {set i 0} {$i < $static_arg_count} {incr i} {
			set argument [reqGetArg static_arg_${i}]
			append row "{$argument} "
			tpSetVar static_arg_${i}_val $argument

		}
	}
	return $row
}

proc create_failed_file {lines_to_write type name {update ""} {path ""}} {
	global FILE

	ob::log::write DEV "creating failed file. Parametres:"
	ob::log::write DEV "text = $lines_to_write"
	ob::log::write DEV "type = $type"
	ob::log::write DEV "name = $name"
	ob::log::write DEV "update = $update"
	ob::log::write DEV "path = $path"

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR ""]

	## this code is a little convoluted to take in to account files generated before the rejected files were numbered
	if {$update != "update"} {
		if {[string equal -length 8 $name "REJECTED"]} {
			set eighth [string index $name 8]
			if {$eighth == "_"} {
				set count 1
				set name_start 9
			} else {
				set count [expr $eighth + 1]
				set name_start 10
			}
			set name [string range $name $name_start [string length $name]]
			set name "REJECTED${count}_${name}"
		} else {
			set name "REJECTED1_${name}"
		}

	}

	set sub_dir /$type/$name
	if {$path != ""} {
		set sub_dir /$path/$name
	}


	set fileHandle [open $UPLOAD_DIR$sub_dir w]

	set num_cols $FILE(HEADER,NUM_COLS)
	set header [list]

	## write header
	for {set c 0} {$c < $num_cols} {incr c} {
		lappend header $FILE($c,HEADER)
	}

	set header "[join $header {,}]"

	if { $type != "cheques" } {
		puts $fileHandle $header
	}

	## write lines
	for {set l 0} {$l < [llength $lines_to_write]} {incr l} {
		set line_num [expr [lindex $lines_to_write $l] - 1]

		set line [list]
		for {set col_num 0} {$col_num < $num_cols} {incr col_num} {
			lappend line $FILE($line_num,$col_num,DATA)
		}
		set line "[join $line {,}]"

		puts $fileHandle $line
	}

	flush $fileHandle
	close $fileHandle

	return $name

}

proc create_success_file {lines_to_ignore type name path} {
	global FILE

	ob::log::write DEV "creating partialy success file. Parametres:"
	ob::log::write DEV "text = $lines_to_ignore"
	ob::log::write DEV "type = $type"
	ob::log::write DEV "name = $name"
	ob::log::write DEV "path = $path"

	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR ""]

	if {[string equal -length 14 $name "PARTIAL_UPLOAD"]} {

		set fourteen [string index $name 14]
		set count [expr $fourteen + 1]
		set name_start 16

		set name [string range $name $name_start [string length $name]]
		set name "PARTIAL_UPLOAD${count}_${name}"
	} else {
		set name "PARTIAL_UPLOAD1_${name}"
	}


	set sub_dir /$type/$name
	if {$path != ""} {
		set sub_dir /$path/$name
	}

	set fileHandle [open $UPLOAD_DIR$sub_dir w]

	err_bind "CREATING SUCCESS FILE"

	set num_cols $FILE(HEADER,NUM_COLS)
	set header [list]

	## write header
	for {set c 0} {$c < $num_cols} {incr c} {
		lappend header $FILE($c,HEADER)
	}

	set header "[join $header {,}]"

	puts $fileHandle $header


	## write lines
	for {set l 0} {$l < $FILE(NUM_LINES)} {incr l} {
		if {[lsearch $lines_to_ignore $l] == -1} {
			set line [list]
			for {set col_num 0} {$col_num < $num_cols} {incr col_num} {
				lappend line $FILE($l,$col_num,DATA)
			}
			set line "[join $line {,}]"

			puts $fileHandle $line
		}
	}

	flush $fileHandle
	close $fileHandle
}

proc locate_field {field} {

	global FILE
	for {set i 0} {$i < $FILE(HEADER,NUM_COLS)} {incr i} {
		if {$FILE($i,HEADER) == $field} {
			return $i
		}
	}
	return -1
}



proc get_args_for {special data {type ""}} {

	global FILE
	variable CS_RX
	variable HF_RX
	variable HF_MAP
	variable GC_TAGS_LIST
	variable GC_FB_RES_LIST
	variable TG_TAGS_LIST
	variable TG_FB_RES_LIST

	set row ""
	set fb_result $data
	set cs_home   ""
	set cs_away   ""

	ob::log::write DEV "get_args_for: special: $special data: $data type: $type"

	if {$special != ""} {
		switch -regexp $special {
			^PRICE$ {
				set prc_parts [get_price_parts $data]
				append row "{[lindex $prc_parts 0]} "
				append row "{[lindex $prc_parts 1]} "
			}
			^FRACTION$ {
				set parts [split $data /]
				append row "{[lindex $parts 0]} "
				append row "{[lindex $parts 1]} "
			}
			^FB_RESULT_(GC|TG)$ {

				if { $special == "FB_RESULT_GC" } {
					set sort GC
				} else {
					set sort TG
				}

				set idx [lsearch -exact [subst $[subst $sort]_TAGS_LIST] $data]

				if { $idx == -1 } {
					error {fb_result not set correctly for a Goal Crazy market}
				}

				set fb_result [lindex [subst $[subst $sort]_FB_RES_LIST] $idx]
				set cs_home [ADMIN::MKTPROPS::seln_flag FB $sort $fb_result cs_home]
				set cs_away [ADMIN::MKTPROPS::seln_flag FB $sort $fb_result cs_away]

				append row "{$fb_result} "
				append row "{$cs_home} "
				append row "{$cs_away} "

			}
			^FB_RESULT_CS$ {
				if {[regexp $CS_RX $data all h a]} {
					set fb_result S
					set cs_home   $h
					set cs_away   $a

				}
				append row "{$fb_result} "
				append row "{$cs_home} "
				append row "{$cs_away} "
			}
			^FB_RESULT_HF$ {
				if {[regexp $HF_RX $data all h]} {
					set fb_result $HF_MAP($h)
				}
				append row "{$fb_result} "
				append row "{$cs_home} "
				append row "{$cs_away} "
			}
			^FB_RESULT_.{2}$ {
				append row "{$fb_result} "
				append row "{$cs_home} "
				append row "{$cs_away} "
			}
			^DESCRIPTION$ {
				if {$type == "man_bets"} {
					set str_len [string length $data]
					if {$str_len > 255} {
						if {$str_len > 510} {
							if {$str_len > 765} {
								append row "{[string range $data 0 254]} "
								append row "{[string range $data 255 509]} "
								append row "{[string range $data 510 764]} "
								append row "{[string range $data 765 end]} "
							} else {
								append row "{[string range $data 0 254]} "
								append row "{[string range $data 255 509]} "
								append row "{[string range $data 510 764]} "
								append row "{} "
							}
						} else {
							append row "{[string range $data 0 254]} "
							append row "{[string range $data 255 509]} "
							append row "{} "
							append row "{} "
						}
					} else {
						append row "{$data} "
						append row "{} "
						append row "{} "
						append row "{} "
					}
				} else {
					append row "{$data} "
				}
			}
			default {
				error "unknown special type ($special)"
			}
		}

	} else {
		append row "{$data} "
	}
	return $row
}


proc do_upload_delete args {
	set UPLOAD_DIR [OT_CfgGet UPLOAD_DIR]

	set type [reqGetArg FileType]
	set name [reqGetArg FullName]

	ob::log::write INFO "Deleting uploaded $type file: $name"

	if {[catch {
		file delete $UPLOAD_DIR/$type/$name
	} msg]} {
		error "failed to delete $UPLOAD_DIR/$type/$name"
	}

	go_upload
}

# Return the fields for the upload format type specified
proc get_upload_fields {type} {
	variable UPLOAD_FMT
	return $UPLOAD_FMT($type)
}

#########################
proc validate_response {http_response} {
#########################
	set http_error          [http::error $http_response]
	set http_code           [http::code $http_response]
	set http_wait           [http::wait $http_response]

	if {$http_wait != "ok"} {
		return [list 1 "TIMEOUT (code=$http_wait)"]
	}
	if {$http_error != ""} {
		return [list 1 "HTTP_ERROR (code=$http_error)"]
	}
	if {$http_code != "HTTP/1.1 200 OK" && $http_code != "HTTP/1.1 302 Found"} {
		return [list 1 "HTTP_WRONG_CODE (code=$http_code)"]
	}
	return [list 0 OK]
}

}

