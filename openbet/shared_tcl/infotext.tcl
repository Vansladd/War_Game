# ==============================================================
# $Id: infotext.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
#
# (C) 2001 Orbis Technology Ltd. All rights reserved.
# ==============================================================

#---------------------------------------------------------------------------
# InfoText communications protocols
#---------------------------------------------------------------------------

proc bgerror {msg} {
	puts "---------------> $msg"
}

namespace eval OB_InfoText {
	variable TINFO
	variable err_msg
	variable cust_msg
	variable major_ver 1
	variable minor_ver 0
	variable form_str
	variable err_str
	variable cust_str
	variable err_action
	variable race_type
	variable race_status
	variable sock
	variable interrupt 0
	variable timeout 60000
	variable timeout_handle
	variable waiting_cmd ""
	variable cb_ret
	variable callback
	variable is_server 0
	variable signed_on 0
	variable reqd_date ""
	variable serv_date ""
	variable CONN_WAIT 0
	variable conn_timeout 3000

	namespace export err_msg
	namespace export cust_msg
	namespace export TINFO

	namespace export cb_packet_error
	namespace export cb_sign_on
	namespace export cb_sign_off
	namespace export cb_bet_sell

	namespace export sign_on
	namespace export sign_off
	namespace export pin_change
	namespace export track_list
	namespace export race_list
	namespace export race_details
	namespace export account_details
	namespace export connect
	namespace export disconnect
	namespace export bet_sell

	array set form_str {}

	trace variable form_str r create_form_str

	array set err_str {
		00 {Update successful}
		01 {Datagram checksum error}
		02 {Datagram length error}
		03 {Unrecognised datagram type}
		04 {Datagram format not supported}
		05 {Client version no longer supported}
		06 {Tote system unavaiable}
		07 {Too many outstanding requests}
		08 {Request rejected for other reasons}
		09 {Not defined}
		10 {Invalid account details}
		11 {Account already active}
		12 {Account locked}
		13 {Account closed}
		14 {Not signed on yet}
		15 {Bad PIN number}
		16 {Insufficient funds in account}
		17 {Not defined}
		18 {Not defined}
		19 {Not defined}
		20 {Bad track code}
		21 {Bad race number}
		22 {Bad pool type}
		23 {Bad bet type}
		24 {Bad unit cost}
		25 {Bad runner or selection list}
		26 {Amount too small}
		27 {Amount too large}
		28 {Not defined}
		29 {Not defined}
		30 {No betting on this track}
		31 {No betting on this race}
		32 {Race closed}
		33 {Results not available for this race}
		34 {Pool not available for this race}
		35 {Scratched runner or runners}
		36 {Standings not available for this pool}
		37 {Track list not currently available}
		38 {Race list not currently available}
		39 {Race details not currently available}
		40 {Pool details not currently available}
	}

	set std_err {{This pool is currently not available for betting.  Please try again later}}
	array set cust_str [subst {
		00 {Your bet has been successfully placed}
		01 $std_err
		02 $std_err
		03 $std_err
		04 $std_err
		05 $std_err
		06 $std_err
		07 $std_err
		08 $std_err
		09 $std_err
		10 $std_err
		11 $std_err
		12 $std_err
		13 $std_err
		14 $std_err
		15 $std_err
		16 $std_err
		17 $std_err
		18 $std_err
		19 $std_err
		20 $std_err
		21 $std_err
		22 $std_err
		23 $std_err
		24 {Your stake must be in \$1 multiples}
		25 $std_err
		26 {Your stake must be at least \$2}
		27 $std_err
		28 $std_err
		29 $std_err
		30 {Betting from this track is currently unavailable}
		31 $std_err
		32 {Betting on this race has now closed}
		33 $std_err
		34 $std_err
		35 {One of your selections has been withdrawn}
		36 $std_err
		37 $std_err
		38 $std_err
		39 $std_err
	}]

	array set err_action {
		00 {OK}
		01 {REJECT}
		02 {REJECT}
		03 {REJECT}
		04 {REJECT}
		05 {REJECT}
		06 {REJECT}
		07 {REJECT}
		08 {REJECT}
		09 {REJECT}
		10 {REJECT}
		11 {REJECT}
		12 {REJECT}
		13 {REJECT}
		14 {REJECT}
		15 {REJECT}
		16 {REJECT}
		17 {REJECT}
		18 {REJECT}
		19 {REJECT}
		20 {REJECT}
		21 {REJECT}
		22 {REJECT}
		23 {REJECT}
		24 {REJECT}
		25 {REJECT}
		26 {REJECT}
		27 {REJECT}
		28 {REJECT}
		29 {REJECT}
		30 {REJECT}
		31 {REJECT}
		32 {REJECT}
		33 {REJECT}
		34 {REJECT}
		35 {REJECT}
		36 {REJECT}
		37 {REJECT}
		38 {REJECT}
		39 {REJECT}
		40 {REJECT}
	}

	array set race_type {
		T "Thoroughbred Racing"
		H "Harness Racing"
		G "Greyhound Racing"
		J "Jai-Alai"
		L "Lottery"
		N "Numbers Games"
	}

	array set race_status {
		B "Betting available"
		N "No more bets"
		R "Results available"
	}

	if {[info commands OT_LogWrite] == "OT_LogWrite"} {
		proc log {level msg} {
			OT_LogWrite $level $msg
		}
	} else {
		proc log {level msg} {
			puts "[clock format [clock seconds] -format "%d/%m/%Y %H:%M:%S"] \[[format "%02d" $level]\]: $msg"
		}
	}

	proc create_form_str {var idx op} {
		upvar $var v

		if {[info exists v($idx)]} {
			return
		}

		regsub -all -- {([0-9]+)A} $idx {%- \1s} out
		regsub -all -- {([0-9]+)N} $out {% \1u} out
		regsub -all -- {([0-9]+)Z} $out {%0\1u} out

		while {[regexp -- {([0-9]+)L} $out all match]} {
			set str ""
			for {set i 0} {$i < $match} {incr i} {
				append str "%02u"
			}
			append str "/"
			regsub -- {[0-9]+L} $out $str out
		}

		set v($idx) $out
	}

	proc checksum {data} {
		if {![binary scan $data "c*" num]} {
			error "error creating checksum"
		}

		set val [expr [join $num +]]
		set low [expr ($val & 0x7f) | 0x80]
		set high [expr (($val >> 7) & 0x7f) | 0x80]

		return [format "%c%c" $low $high]
	}

	proc build_req_nc {form len args} {
		variable form_str

		log 5 "form_str($form): $form_str($form) $args"
		if {[catch {set data [eval format \"$form_str($form)\" $args]} err]} {
			error "error formating paramaters: $err"
		}

		return $data
	}

	proc build_req {form len args} {
		set data [eval build_req_nc $form $len $args]
		append data [checksum $data]

		if {$len != 0 && [string length $data] != $len} {
			error "wrong length, expected $len, got [string length $data]"
		}

		return $data
	}

	proc snd_msg {msg {p_timeout ""}} {
		variable timeout
		variable interrupt
		variable cb_ret
		variable sock
		variable waiting_cmd
		variable timeout
		variable err_msg
		variable err_action

		if {$p_timeout == ""} {
			set p_timeout $timeout
		}

#		log 10 "snd_msg: sending $msg"
		set timeout_handle [after $timeout [namespace code {set interrupt 0}]]

		set waiting_cmd [set code [string tolower [string range $msg 0 1]]]
		puts -nonewline $sock $msg

		while {$waiting_cmd == $code} {
			vwait ::OB_InfoText::interrupt

			if {$interrupt == 0} {
				after cancel $timeout_handle
				set err_msg "Timed out waiting for reply from server"
				return TIMEOUT
			}

			if {$waiting_cmd == $code} {
				set waiting_cmd ""
			}
		}

		after cancel $timeout_handle
		return $err_action($cb_ret)
	}

	proc sign_on {acct pin {mtg_date ""} {profile ""} {option ""}} {
		variable major_ver
		variable minor_ver
		variable reqd_date

		if {$mtg_date != ""} {
			if {![regexp {20([0-9][0-9])-([0-1][0-9])-([0-3][0-9])} $mtg_date all yr mn dy]} {
				set err_msg "bad meeting date $mtg_date"
				return ERROR
			}
			set reqd_date [clock scan $mtg_date]
		} else {
			set reqd_date ""
		}

		return [snd_msg [build_req "SN2Z2Z1A1A10Z4Z" 24 $major_ver $minor_ver \
							 $profile $option $acct $pin] 10000]
	}

	proc sign_off {} {
		variable signed_on

		if {$signed_on == 0} {
			return OK
		}

		return [snd_msg [format "SO%2s" [checksum "SO"]] 2000]
	}

	proc pin_change {old_pin new_pin} {
		return [snd_msg [build_req "PC4Z4Z" 12 $old_pin $new_pin]]
	}

	proc track_list {} {
		return [snd_msg [format "TL%2s" [checksum "TL"]]]
	}

	proc race_list {meeting} {
		return [snd_msg [build_req "RL3A" 7 $meeting]]
	}

	proc race_details {meeting race} {
		return [snd_msg [build_req "RD3A2N" 9 $meeting $race]]
	}

	proc pool_details {meeting race pool} {
		return [snd_msg [build_req "PD3A2N3A" 12 $meeting $race $pool]]
	}

	proc pool_standings {meeting race pool} {
		return [snd_msg [build_req "PS3A2N3A" 12 $meeting $race $pool]]
	}

	proc finish_details {meeting race} {
		return [snd_msg [build_req "FD3A2N" 9 $meeting $race]]
	}

	proc pool_payoff {meeting race pool} {
		return [snd_msg [build_req "PP3A2N3A" 12 $meeting $race $pool]]
	}

	proc bet_cost {ref meeting race pool doll cent legs selns} {
		set rep [eval build_req_nc \"BC6Z3A2N3A6N2Z2N\" \
					 0 $ref $meeting $race $pool $doll $cent \
					 $legs]
		append rep $selns
		append rep [checksum $rep]

		return [snd_msg $rep]
	}

	proc bet_sell {ref meeting race pool b_doll b_cent legs selns
				   v_doll v_cent} {
		variable signed_on
		variable err_msg

		if {$signed_on != 1} {
			set err_msg "not signed on"
			return ERROR
		}

		log 20 "bet_sell: reference\#: $ref"
		log 20 "bet_sell: meeting    : $meeting"
		log 20 "bet_sell: race\#     : $race"
		log 20 "bet_sell: pool       : $pool"
		log 20 "bet_sell: unit stake : [format "%0.2f" "$b_doll.$b_cent"]"
		log 20 "bet_sell: tot, stake : [format "%0.2f" "$v_doll.$v_cent"]"
		log 20 "bet_sell: num legs   : $legs"
		log 20 "bet_sell: runners    : $selns"

		set rep [eval build_req_nc \"BS6Z3A2N3A6N2Z2N\" 0 \
					 $ref $meeting $race $pool $b_doll $b_cent \
					 $legs]
		append rep $selns
		append rep [eval build_req_nc \"8N2Z\" 0 $v_doll $v_cent]
		log 20 "sending: $rep"
		append rep [checksum $rep]

		return [snd_msg $rep]
	}

	proc bet_only {ref acct pin meeting race pool b_doll b_cent legs
				   selns v_doll v_cent {profile ""} {option ""}} {
		variable major_ver;
		variable minor_ver;

		set rep [eval build_req \"BO6Z2N2N1A1A3A2N3A6N2Z2N\" \
					 0 $ref $major_ver $minor_ver $profile $option \
					 $meeting $race $pool $b_doll $b_cent $legs]
		append rep $selns
		append rep [eval build_req \"8N2Z\" $v_doll $v_cent]
		append rep [checksum $rep]

		return [snd_msg $rep]
	}

	proc account_details {acct pin {profile ""} {option ""}} {
		variable major_ver;
		variable minor_ver;

		return [snd_msg [build_req "AD2N2N1A1A10N4Z" 24 $major_ver $minor_ver $profile $option $acct $pin]]
	}

	# Cheeky function which takes a format string and some data followed by a list of
	# variables to populate. It'll disect the string according to the format string
	# placing each element into each successive variable
	proc disect {data form args} {
		set start 0
		set parts [regexp -all -inline -- {[ABHNZ]|[0-9]+} $form]

		if {[expr [llength $parts] % 2] != 0} {
			error "invalid format string"
		}

		for {set idx 0} {$idx < [llength $parts] && $data != ""} {incr idx 2} {
			set end [expr $start + ([lindex $parts $idx] - 1)]
			# Check to make sure we don't run out of data
			if {$end > [string length $data]} {
				return 1
			}
			uplevel "set [lindex $args [expr $idx / 2]] \"[string range $data $start $end]\""
			set start [expr $end + 1]
		}
		return 0
	}

	proc strip0 {str} {
		if {$str != ""} {
			set new [string trimleft $str "0 \t"]
		}

		if {$new == ""} {
			set new 0
		}

		return $new
	}

	proc stripws {str} {
		return [string trim $str " \t"]
	}

	set callback(xx) [namespace code cb_packet_error]
	proc cb_packet_error {data} {
		variable err_str
		variable err_msg
		variable err_action
		set err_msg "server error: $err_str($data)"

		return $err_action($data)
	}

	set callback(sn) [namespace code cb_sign_on]
	proc cb_sign_on {data} {
		variable TINFO
		variable err_action
		variable err_str
		variable cust_str
		variable err_msg
		variable cust_msg
		variable signed_on
		variable reqd_date
		variable serv_date

		set success_code [string range $data 0 1]
		set err_msg $err_str($success_code)
		set cust_msg $cust_str($success_code)

		if {$success_code == "00"} {
			disect $data "2Z2Z2Z2Z2Z2Z2Z2Z2Z1A1A30A8N2Z8N2Z4N2Z" success_code \
				TINFO(maj_ver) TINFO(min_ver) TINFO(day) TINFO(month) TINFO(year) \
				TINFO(hour) TINFO(minute) TINFO(second) TINFO(profile) TINFO(option) \
				TINFO(name) TINFO(bal_doll) TINFO(bal_cent) TINFO(hold_doll) \
				TINFO(hold_cent) TINFO(access_doll) TINFO(access_cent)

			set signed_on 1
			set serv_date [clock scan "$TINFO(year)-$TINFO(month)-$TINFO(day)"]

			log 10 "cb_sign_on: reqd_date=$reqd_date, serv date $serv_date"
			if {$reqd_date != ""} {
				if {$reqd_date != $serv_date} {
					set signed_on 0
					set success_code "-1"
					set err_msg "Server on wrong day"
				}
			}
		} else {
			log 10 "cb_sign_on: sign_on failed - $err_msg. data - $data"
		}


		return $success_code
	}

	set callback(so) [namespace code cb_sign_off]
	proc cb_sign_off {data} {
		variable err_action
		variable err_str
		variable err_msg
		variable signed_on

		set success_code [string range $data 0 1]
		set err_msg $err_str($success_code)

		if {$success_code == "00"} {
			disect $data "2Z2Z2Z2Z" success_code TINFO(hour) TINFO(minute) TINFO(second)
		}

		set signed_on 0
		return $success_code
	}

	set callback(pv) [namespace code cb_pin_change]
	proc cd_pin_change {data} {
		variable err_msg
		variable err_str

		disect $data "2Z" success_code

		if {[strip0 $success_code] != 0} {
			set err_msg "pin change error: $err_str($success_code)"
		}
		return 1
	}

	set callback(tl) [namespace code cb_track_list]
	proc cb_track_list {data} {
		variable err_msg
		variable err_str
		variable TINFO

		disect $data "2Z2N" success_code num_tracks

		if {[strip0 $success_code] != 0} {
			set err_msg "server error: $err_str($success_code)"
			return 0
		}

		if {[expr ([string length $data] - 4) / 20] != $num_tracks} {
			set err_msg "expected $num_tracks tracks, message wrong size"
			return 0
		}

		# Trash any track information and replace it with this new lot
		catch {unset TINFO}

		set tracks [string range $data 4 end]
		for {set track 0} {$track < $num_tracks} {incr track} {
			set track_info [string range $tracks 0 19]
			set tracks [string range $tracks 20 end]

			disect $track_info "3A1A14A2A" track_code type_code meeting reserved

			set track_code [stripws $track_code]
			lappend TINFO(codes) [stripws $track_code]
			set TINFO($track_code,type) $type_code
			set TINFO($track_code,name) [stripws $meeting]
		}

		return 1
	}

	set callback(rl) [namespace code cb_race_list]
	proc cb_race_list {data} {
		variable err_str
		variable err_msg
		variable TINFO

		disect $data "2Z3A1A2N" success_code track_code reserved num_races

		if {[strip0 $success_code] != 0} {
			set err_msg "server error: $err_str($success_code)"
			return 0
		}

		set num_races [strip0 $num_races]

		if {[expr ([string length $data] - 8) / 16] != $num_races} {
			set err_msg "expected $num_races races, message wrong size"
			return 0
		}

		set TINFO($track_code,num_races) $num_races

		# Clear any existing race data for this track
		foreach name [array names TINFO "$track_code,races*"] {
			catch {unset TINFO($name)}
		}

		set races [string range $data 8 end]
		for {set race 0} {$race < $num_races} {incr race} {
			set race_info [string range $races 0 15]
			set races [string range $races 16 end]

			disect $race_info "2N1A13A" race_num status reserved
			set race_num [strip0 $race_num]

			lappend TINFO($track_code,races) $race_num
			set TINFO($track_code,races,$race_num,status) $status
		}

		return 1
	}

	set callback(rd) [namespace code cb_race_details]
	proc cb_race_details {data} {
		puts "race details"
	}

	set callback(pd) [namespace code cb_pool_details]
	proc cb_pool_details {data} {
		variable err_str
		variable TINFO
		puts "pool details"

		set pk "$track_code,races,$race_num,$type"

		disect $data "2Z3A1A2N3A1A4N2Z6N2Z1A1A1A1A2N" \
			success_code \
			track_code \
			res \
			race_num \
			type \
			res \
			TINFO($pk,min_doll) \
			TINFO($pk,min_cent) \
			TINFO($pk,max_doll) \
			TINFO($pk,max_cent) \
			TINFO($pk,mult_min) \
			TINFO($pk,pennies) \
			TINFO($pk,mult_fifty) \
			res \
			TINFO($pk,num_races)

		if {$success_code != 0} {
			set err_msg "server error: $err_str($success_code)"
			return 0
		}

		set races [string range $data 32 end]

		for {set race 1} {$race <= $num_races} {incr race} {
			disect $races "2N1A" race_num res
			set races [string range $races 3 end]

			while {$races != ""} {
				set idx [string first "/" $races]
				set num_runners [expr $idx / 2]
				for {set runner_num 0} {$runner_num < $num_runners} {incr runner_num} {
					lappend TINFO($pk,runners,$race_num) [strip0 [string range $races [expr $runner_num * 2] [expr ($runner_num * 2) + 1]]]
				}
				set races [string range $races [expr $idx + 1] end]
			}
		}

		return 1
	}

	set callback(ps) [namespace code cb_pool_standings]
	proc cb_pool_standings {data} {
		variable TINFO
		variable err_str
		variable err_msg

		puts "pool standings"

		disect $data "2Z3A1A2N3A1A6Z3A1A2N" success_code track_code res race_num \
			type res minutes res t num_legs

		if {$success_code != 0} {
			set err_msg "server error: $err_str($success_code)"
			return 0
		}

		set pk "$track_code,races,$race_num,$type"
		set data [string range $data 26 end]

		for {leg 1} {$leg <= $num_legs} {incr leg} {
			set TINFO($pk,positions,$leg) [strip0 [string range $data  1]]
			set data [string range $data 2 end]
		}

		# Need to add some more shit but don't fully understand
		# the messages so I'm leaving it for now

		return 1
	}

	set callback(bc) [namespace code cb_bet_cost]
	proc cb_bet_cost {data} {
		puts "bet cost"
		disect $data "2Z6Z8N2Z2A" success_code ref doll cent res

		if {$success_code != 0} {
			puts "bet cost error: $err_str($success_code)"
		} else {
			puts "Ref#: $ref"
			puts [format "Cost: %d.%02d" [strip0 $doll] [strip0 $cent]]
		}

		return $success_code
	}

	set callback(bs) [namespace code cb_bet_sell]
	proc cb_bet_sell {data} {
		variable TINFO
		variable err_str
		variable cust_str
		variable err_msg
		variable cust_msg

		set success_code [string range $data 0 1]
		set err_msg  $err_str($success_code)
		set cust_msg $cust_str($success_code)

		if {$success_code == 00} {
			disect $data "2Z6Z8N2Z12H5Z3A2Z2Z2Z8N2Z4N2Z" success_code TINFO(ref) \
				TINFO(bet_sell_doll) TINFO(bet_sell_cent) TINFO(bet_sell_serial) \
				TINFO(ver) res \
				TINFO(bet_sell_hour) TINFO(bet_sell_minute) TINFO(bet_sell_second) \
				TINFO(bet_sell_cur_doll) TINFO(bet_sell_cur_cent) \
				TINFO(bet_sell_acc_doll) TINFO(bet_sell_acc_cent)
		}

		return $success_code
	}

	set callback(bo) [namespace code cb_bet_only]
	proc cb_bet_only {data} {
		puts "bet only"
		disect $data "2Z6Z2Z2Z8N2Z12H5Z3A2Z2Z2Z" success_code ref maj min doll cent serial ver res hour minute second

		if {$success_code != 0} {
			puts "bet only error: $err_str($success_code)"
		} else {
			puts "Ref#: $ref"
			puts "Version: $maj.$min"
			[format "Cost: %d.%02d" $doll $cent]
			puts "Serial: $serial"
			puts "AW Version: $ver"
			[format "Time: %02d:%02d:%02d" $hour $minute $second]
		}

		return 1
	}

	set callback(ad) [namespace code cb_account_details]
	proc cb_account_details {data} {
		variable err_str
		variable err_msg

		set success_code [string range $data 0 1]
		set err_msg $err_str($success_code)

		if {$success_code == 0} {
			disect $data "2Z2Z2Z1A1A30A8N2Z8N2Z4N2Z" success_code maj min res res name cur_doll cur_cent hold_doll hold_cent acc_doll acc_cent
			puts "Version: $maj.$min"
			puts "Account name: $name"
			puts [format "Balance: %d.%02d" [strip0 $cur_doll] [strip0 $cur_cent]]
			puts [format "Hold balance: %d.%02d" [strip0 $hold_doll] [strip0 $hold_cent]]
			puts [format "Charge: %d.%02d" [strip0 $acc_doll] [strip0 $acc_cent]]
		}

		return $success_code
	}

	proc handle_packet {pkt} {
		variable err_msg
		variable err_str
		variable race_type
		variable race_status
		variable waiting_cmd
		variable cb_ret
		variable interrupt
		variable callback

		if {[set len [string length $pkt]] < 2} {
			log 3 "handle_packet: invalid packet: $pkt"
		}

		set code [string range $pkt 0 1]
		set data [string range $pkt 2 [expr $len - 3]]
		set sum [string range $pkt [expr $len - 2] end]

		log 10 "handle_packet: code($code) data($data)"

		if {$sum != [checksum "$code$data"]} {
			log 3 "handle_packet: invalid checksum: revieved $sum, expected [checksum "$code$data"]"
			return
		}

		if {[info exists callback($code)]} {
			if {[set cb_ret [eval $callback($code) {$data}]] != 00} {
				log 1 "handle_packet: $callback($code) returned error: $err_msg"
				incr interrupt
				return
			}

			if {$waiting_cmd == $code} {
				incr interrupt
			}
		} else {
			puts "handle_packet: unknown response code: $code"
		}
	}

	proc read_sock {} {
		variable sock
		if {[eof $sock]} {
			close $sock
			return
		}

		if {[set msg [read $sock 4096]] > 0} {
			handle_packet $msg
		}
	}

	#
	# need to do a non blocking connect as the TRNI
	# server has a nasty habit of hanging during the TLS
	# handshake without closing the socket
	#

	proc connect {server {port 443} {conn_wait_time 2}} {
		variable sock
		variable err_msg
		variable CONN_WAIT
		variable connected ""
		variable conn_timeout

		return [expr {![catch {


			# Create and connect the socket in non-blocking mode
			# if the TRNI server is down we need to cancel the bet

			set id [after $conn_timeout {set OB_InfoText::connected "TIMED_OUT"}]
			set sock [socket -async $server $port]

			fileevent $sock w {set OB_InfoText::connected "OK"}
			vwait OB_InfoText::connected

			after cancel $id
			fileevent $sock w {}


			if {$connected == "TIMED_OUT"} {
				catch {close $sock}
				error "Connection attempt timed out after $conn_timeout ms"

			} else {
				# why do we need this, I forget
				fconfigure $sock -blocking 0
				if [catch {gets $sock a}] {
					close $sock
					error "Connection failed"
				}

				fconfigure $sock -blocking 1 -buffering line
			}


			# tls doesn't seem to work in non-blocking mode
			# fconfigure $sock -blocking 0 -buffering none -translation binary

			set sock [tls::import $sock]

			# spin for $conn_wait_time secs while doing the
			# handshake with the other end

			set itvl 50
			set count [expr {(1000 * $conn_wait_time) / $itvl}]
			set CONN_WAIT 0

			while {![tls::handshake $sock]} {
				after $itvl {incr OB_InfoText::CONN_WAIT}
				vwait CONN_WAIT

				if {$CONN_WAIT == $count} {
					error "failed to connect to TRNI server after $conn_wait_time seconds"
				}
			}

			# Configure the socket
			fconfigure $sock -blocking 0 -buffering none -buffersize 4096 -translation binary -eofchar {}

			# Setup asynchronous reads
			fileevent $sock readable [namespace code read_sock]
		} err_msg]}]
	}

	proc disconnect {} {
		variable sock
		variable signed_on

		set signed_on 0
		catch {close $sock}
	}
}
