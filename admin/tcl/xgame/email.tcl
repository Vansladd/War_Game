# ==============================================================
# $Id: email.tcl,v 1.1.1.1 2011/10/04 10:54:25 xbourgui Exp $
#
# (C) 1999 Orbis Technology Ltd. All rights reserved.
# ==============================================================

proc format_email_string {enc_details {type "E"}} {
    set list [split $enc_details "|"]
    
    set id [lindex $list 0]
    set picks [lindex $list 1]
    set game_name [lindex $list 2]
    set num_subs [lindex $list 3]
    set sort [lindex $list 4]
    if {$type=="E"} {
	set draw_at [lindex $list 5]
    } else {
	set draw_at [lindex $list 5]
	regexp {(..)/(..)/..(..)} $draw_at dummy day month year
	set draw_at "$day/$month/$year"
    }
    
    set three_or_four ""
    if {$sort=="PBUST3"} {
	set three_or_four 3
    }
    if {$sort=="PBUST4"} {
	set three_or_four 4
    }

    set weeks "week"
    if {$num_subs>1} {
	append weeks "s"
    }

    ## Email
    if {$type=="E"} {
	set cr "\n"
	return [format {Ref S%s: %-13s with selections %s%s         for %d %s starting %s} $id $game_name $picks $cr $num_subs $weeks $draw_at]
    }
    
    ## SMS
    if {$type=="S"} {
	return "Ref S$id: PB$three_or_four nos. $picks: for $num_subs $weeks from $draw_at"
    }
    return ""
}


proc sms_on_sub_authorize {mobile_number {subtext}} {
    if {$mobile_number==""} {
	return
    }

    # Try to second guess what sort of mobile phone number this is.
    # If it start with a zero we'll assume it's a UK number and
    # replace the zero with +44
    if {[string index $mobile_number 0]=="0"} {
	set mobile_number "+44[string trimleft $mobile_number 0]"
    }
	

    set i 0
    set mymail [open "|mail littlewoods@conduit.ie" r+]
    
    set    message "From: \"Bet247 Helpdesk\" <help@Bet247.co.uk>\n"
    append message "To: <rcameron@mail.orbis-local.co.uk>\n"
    append message "Sender: help@bet247.co.uk\n"
    append message "Content-Type: text/plain;"
    append message " charset=\"iso-8859-1\"\n"
    append message "\n"
    append message "\"$mobile_number\"\n"
    
    set middle ""
    set start "Prizebuster selections are accepted:"
    set end "Your account has been debited."

    for {set i 0} {$i < [llength $subtext]} {incr i} {
	append middle [format_email_string [lindex $subtext $i] "S"]
	append middle "\n"
    }	
    append message "$start $middle$end"
    puts $mymail $message
    close $mymail
}

proc email_on_sub_authorize {address firstname lastname {subtext}} {

    set mymail [open "|mail $address" r+]
    
    set    message "From: \"Bet247 Helpdesk\" <help@Bet247.co.uk>\n"
    append message "To: \"$firstname $lastname\" <$address>\n"
    append message "Subject: Thank you for playing Prizebuster\n"
    append message "Sender: help@bet247.co.uk\n"
    append message "Content-Type: text/plain;\n"
    append message " charset=\"iso-8859-1\"\n"
    append message "\n\n"
    append message "Dear $firstname,\n\n"
    append message "Thank your for playing one of our Prizebuster games. Littlewoods would\n"
    append message "like to confirm that the following selections have been accepted into\n"
    append message "the following prize draws:\n\n"

	set previous ""
	set first_go 1
	set last_sort ""
	set sort ""

    foreach t $subtext {

		set last_sort $sort
		set list [split $t "|"]
		set sort [lindex $list 4]

		if { $first_go == 1 } {
			set previous $sort
			set first_go 0
		}

		if {$sort != $previous} {

			append message "\nYour account will be debited for the entries above.\n\n"

			if { $last_sort == "CPBUST3" } {
				append message "All net proceeds from Celtic Prizebuster (estimated at 20% of the ticket sales)\n"
				append message "after prizes and expenses go to: Celtic Development Pools Limited who will\n"
				append message "donate these proceeds to Celtic Development Fund Limited for the purposes of\n"
				append message "improvements to Youth Development facilities on behalf of Celtic FC.\n\n"				
				append message "Promoter: John Maguire, 20 Davaar Street, Glasgow, G40 3RB\n"
				append message "Registered with The Gaming Board for Great Britain under Schedule 1A to\n"
				append message "The Lotteries & Amusements Act 1976.\n\n"	
			} else {
				append message "All net proceeds (estimated at 20% of the ticket sales) after prizes\n"
				append message "and expenses go to: Roy Castle Lung Cancer Foundation. Registered Charity.\n\n"
				append message "Promoter: Ray Donelly, 200 London Road, Liverpool L3 9TA\n"
				append message "Registered with The Gaming Board for Great Britain under Schedule 1A to\n"
				append message "The Lotteries & Amusements Act 1976.\n\n"
				
			}
		}		
		set previous $sort
		append message "[format_email_string $t E]\n"
	}

	append message "\nYour account will be debited for the entries above.\n\n"
	if { $sort == "CPBUST3" } {
		append message "All net proceeds from Celtic Prizebuster (estimated at 20% of the ticket sales)\n"
		append message "after prizes and expenses go to: Celtic Development Pools Limited who will\n"
		append message "donate these proceeds to Celtic Development Fund Limited for the purposes of\n"
		append message "improvements to Youth Development facilities on behalf of Celtic FC.\n\n"				
		append message "Promoter: John Maguire, 20 Davaar Street, Glasgow, G40 3RB\n"
		append message "Registered with The Gaming Board for Great Britain under Schedule 1A to\n"
		append message "The Lotteries & Amusements Act 1976.\n\n"	
	} else {
		append message "All net proceeds (estimated at 20% of the ticket sales) after prizes\n"
		append message "and expenses go to: Roy Castle Lung Cancer Foundation. Registered Charity.\n\n"
		append message "Promoter: Ray Donelly, 200 London Road, Liverpool L3 9TA\n"
		append message "Registered with The Gaming Board for Great Britain under Schedule 1A to\n"
		append message "The Lotteries & Amusements Act 1976.\n\n"
		
	}


    append message "\n\nPrizebuster and Celtic Prizebuster form no part of the 'National Lottery.'\n\n"
    append message "Good Luck with your selections.\n\n"
    append message "Littlewoods"

	OT_LogWrite 5 "**** email is \n\n$message\n\n"

    puts $mymail $message
    close $mymail
}

proc email_on_sub_error {address firstname lastname {subtext} failure_reason} {

    set mymail [open "|mail $address" r+]
    
    set    message "From: \"Bet247 Helpdesk\" <help@Bet247.co.uk>\n"
    append message "To: \"$firstname $lastname\" <$address>\n"
    append message "Subject: Failed to place bet on Prizebuster\n"
    append message "Sender: help@bet247.co.uk\n"
    append message "Content-Type: text/plain;\n"
    append message " charset=\"iso-8859-1\"\n"
    append message "\n\n"
    append message "Dear $firstname,\n\n"
    append message "Thank your for playing Prizebuster. Littlewoods would like\n"
    append message "to inform you that the following selections have not been accepted\n"
    append message "due to $failure_reason.\n\n"
    foreach t $subtext {
	append message "[format_email_string $t E]\n"
    }
    append message "\n\nThese bets have been voided. If you wish to place further bets, please\nadd funds to your account.\n\nLittlewoods"
        
    puts $mymail $message
    close $mymail
}

proc sms_on_sub_error {mobile_number {subtext} failure_reason} {
    if {$mobile_number==""} {
	return
    }

    # Try to second guess what sort of mobile phone number this is.
    # If it start with a zero we'll assume it's a UK number and
    # replace the zero with +44
    if {[string index $mobile_number 0]=="0"} {
	set mobile_number "+44[string trimleft $mobile_number 0]"
    }
	

    set i 0
    set mymail [open "|mail littlewoods@conduit.ie" r+]
    
    set    message "From: \"Bet247 Helpdesk\" <help@Bet247.co.uk>\n"
    append message "To: <rcameron@mail.orbis-local.co.uk>\n"
    append message "Sender: help@bet247.co.uk\n"
    append message "Content-Type: text/plain;"
    append message " charset=\"iso-8859-1\"\n"
    append message "\n"
    append message "\"$mobile_number\"\n"
    
    set middle ""
    set start "Prizebuster selections are rejected due to $failure_reason:"

    for {set i 0} {$i < [llength $subtext]} {incr i} {
	append middle [format_email_string [lindex $subtext $i] "S"]
	append middle "\n"
    }	
    append message "$start $middle"
    puts $mymail $message
    close $mymail
}
