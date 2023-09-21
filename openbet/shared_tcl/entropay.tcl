# $Id: entropay.tcl,v 1.1 2011/10/04 12:23:19 xbourgui Exp $
# (C) 2004 Orbis Technology Ltd. All rights reserved.

namespace eval entropay {
	variable CFG
	array set CFG [list \
		ENTROPAY      [OT_CfgGetTrue ENTROPAY] \
		URL           [OT_CfgGet     ENTROPAY_URL           "https://secure1.entropay.com/<landingURI>"] \
		ID            [OT_CfgGet     ENTROPAY_ID            ""] \
		URL_KEY       [OT_CfgGet     ENTROPAY_URL_KEY       ""] \
		CARD_KEY      [OT_CfgGet     ENTROPAY_CARD_KEY      ""] \
		BINS          [OT_CfgGet     ENTROPAY_BINS          [list 410162]] \
		SCHEMES       [OT_CfgGet     ENTROPAY_SCHEMES       [list VC VD]] \
		COUNTRIES     [OT_CfgGet     ENTROPAY_COUNTRIES     [list {*HONG KONG*} {*SINGAPORE*}]] \
		DEVELOPMENT   [OT_CfgGet     DEVELOPMENT            "N"] \
	]
	variable HEX_TO_BIN [list 0 0000 1 0001 2 0010 3 0011 4 0100 \
		5 0101 6 0110 7 0111 8 1000 9 1001 \
		a 1010 b 1011 c 1100 d 1101 e 1110 f 1111 \
		A 1010 B 1011 C 1100 D 1101 E 1110 F 1111]
	variable BINS [list]

	namespace export init
	namespace export is_entropay_cust
	namespace export is_entropay_bin
	namespace export should_use_entropay
	namespace export identify
	namespace export upd_entropay_cpm
	namespace export is_entropay_cpm
	namespace export get_register_url
}

proc entropay::init {} {
	variable CFG

	if {$CFG(ENTROPAY)} {
		chk_cfg
		prep_qrys

		ob::log::write INFO {using entropay}
	} else {
		ob::log::write INFO {not using entropay}
	}
}

# check the values in the CFG are acceptable
proc entropay::chk_cfg {} {
	variable CFG

	if {![string match https://* $CFG(URL)] && $CFG(DEVELOPMENT) != "Y"} {
		error "ENTROPY_URL must be https when not in development mode"
	}

	if {$CFG(URL)       == ""} {error "ENTROPY_URL is blank"}
	if {$CFG(ID)        == ""} {error "ENTROPY_ID is blank"}
	if {$CFG(URL_KEY)   == ""} {error "ENTROPY_URL_KEY is blank"}

	if {$CFG(CARD_KEY)  == ""} {error "ENTROPY_CARD_KEY is blank"}

	if {$CFG(BINS)      == ""} {error "ENTROPAY_BINS is blank"}

	if {$CFG(COUNTRIES) == ""} {error "ENTROPAY_COUNTRIES is blank"}
	if {$CFG(SCHEMES)   == ""} {error "ENTROPAY_SCHEMES is blank"}

	ob::log::write DEBUG {entropay: checking for bins in $CFG(BINS)}
	ob::log::write DEBUG {entropay: checking for countries in $CFG(COUNTRIES)}
	ob::log::write DEBUG {entropay: checking for schemes in $CFG(SCHEMES)}
}


proc entropay::prep_qrys {} {
	variable CFG

	# check the card's bin range is valid
	db_store_qry ENTROPAY_chk_should_use_entropay_bin {
		select
			first 1
			NVL(i.scheme, s.scheme) as scheme,
			i.country
		from
			tCardInfo   i,
		outer
			tcardscheme s
		where
			i.card_bin = ? and
			s.bin_lo <= i.card_bin and
			s.bin_hi >= i.card_bin;
	}

	db_store_qry ENTROPAY_get_entropay_cpm {
		select
			card_bin,
			cpm.type
		from
			tCpmCC       cc,
			tCustPayMthd cpm
		where
			cc.cpm_id       = cpm.cpm_id
		and cpm.cpm_id      = ?
	}

	# update a card to identify it as entropay
	db_store_qry ENTROPAY_upd_cpm_type {
		update tCustPayMthd
		set    type   = 'EN'
		where  cpm_id = ?
	}
}

proc entropay::should_use_entropay {bin} {
	variable CFG
	variable BINS

	if {!$CFG(ENTROPAY)} {return 0}

	ob::log::write DEV {entropay: checking to see if the bin $bin should be using entropay}

	# if this is an entropay card, just return now
	if {[entropay::is_entropay_bin $bin]} {return 0}

	if {[catch {
		set rs [db_exec_qry ENTROPAY_chk_should_use_entropay_bin $bin]
	} msg]} {
		catch {db_close $rs}
		ob::log::write ERROR {entropay: failed to see if the bin should use entropay: $msg}
		return 0
	}
	set nrows [db_get_nrows $rs]

	if {$nrows > 0} {
		set scheme   [string toupper [db_get_col $rs 0 scheme]]
		set country  [string toupper [db_get_col $rs 0 country]]

		ob::log::write DEV {entropay: scheme = $scheme, country = $country}

		# Check if this card bin indicates that entropay should be used
		if {[lsearch $CFG(SCHEMES) $scheme] != -1} {
			# treat each of the countries in the CFG as a glob pattern
			foreach country_pattern $CFG(COUNTRIES) {
				if {[string match $country_pattern $country]} {
					return 1
				}
			}
		}
	}
	db_close $rs

	return 0
}

# tell you wether the card bin is an entropay one
proc entropay::is_entropay_bin {bin} {
	variable CFG

	if {!$CFG(ENTROPAY)} {return 0}

	ob::log::write DEV {entropay: checking bin}

	if {[lsearch $CFG(BINS) $bin] == -1} {
		return 0
	}

	return 1
}

# return a two element list
# the first element is whether or not that card is an entropay one
# the second is either the 'real' entropay card number
# or the original card no
proc entropay::identify {card_no} {
	variable CFG

	if {!$CFG(ENTROPAY)} {return [list 0 $card_no]}

	ob::log::write DEV {entropay: identifying card}

	# check that the bin range
	set bin [string range $card_no 0 5]

	if {![is_entropay_bin $bin]} {return [list 0 $card_no]}

	# we now know that it is a card

	# if the card is less that 24 chars, then we know that is is unecrypted
	if {[string length $card_no] < 24} {
		ob::log::write DEV {entropay: card length is less than 24, assuming unencrypted}
		return [list 1 $card_no]
	}

	# decrypt the card number
	if {[catch {
		set card_no [decrypt_card_no $card_no]
	} msg]} {
		ob::log::write ERROR {entropay: failed to decrypt card no. (maybe unencrypted?): $msg}
		return [list 1 $card_no]
	}

	ob::log::write DEV {entropay: card is entropay}

	return [list 1 $card_no]
}


# set the card to be an entropay card
# you must ensure that the card is corrrect (bin/ccy)
proc entropay::upd_entropay_cpm {cpm_id} {
	variable CFG

	if {!$CFG(ENTROPAY)} {return}

	ob::log::write DEV {entropay: updating card type to EN for cpm $cpm_id}

	if [catch {
		db_close [db_exec_qry ENTROPAY_upd_cpm_type $cpm_id]
	} msg] {
		ob::log::write ERROR {entropay: failed to update tCustPayMthd.type: $msg}
	}
}

# return whether or not the card is entropay
proc entropay::is_entropay_cpm {cpm_id} {
	variable CFG

	if {!$CFG(ENTROPAY)} {return 0}

	ob::log::write DEV {entropay: checking cpm $cpm_id is entropay}

	if {[catch {
		set rs [db_exec_qry ENTROPAY_get_entropay_cpm $cpm_id]
	} msg]} {
		catch {db_close $rs}
		ob::log::write ERROR {entropay: failed to check is card in entropay: $msg}
		return 0
	}
	set nrows [db_get_nrows $rs]

	if {$nrows == 0} {
		db_close $rs
		return 0
	}

	set card_bin    [db_get_col $rs 0 card_bin]
	set type        [db_get_col $rs 0 type]

	db_close $rs

	# if the type is EN then it is entropay, we don't want it turning entropay cards into
	# non-ones when bin range change occurs
	if {$type == "EN"} {return 1}

	# if the bin range is an entropay bin, then it is entropay
	return [is_entropay_bin $card_bin]
}

# genereate a small random nonce
proc entropay::gen_nonce {} {

	ob::log::write DEV {entropay: generating nonce}

	set nonce [expr {int(rand() * pow(2, 31))}]

	if {[string length $nonce] > 8} {
		set nonce [string range $nonce [expr {[string length $nonce] - 8}] end]
	}

	return $nonce
}

# get the url the customer should click on to register their entropay card
proc entropay::get_register_url {} {
	variable CFG

	ob::log::write DEV {entropay: getting url}

	if {!$CFG(ENTROPAY)} {return ""}

	# set the basic args
	set referrerID  $CFG(ID)
	set timestamp   [clock format [clock seconds] -format {%Y%m%d%H%M%S}]
	set nonce       [gen_nonce]
	set referrerKey $CFG(URL_KEY)

	set params      referrerID=$referrerID&timestamp=$timestamp&nonce=$nonce

	# calculate the hash
	set hashMD5     [md5 $params&referrerKey=$referrerKey]

	append params   &hashMD5=$hashMD5

	set url         $CFG(URL)&$params

	ob::log::write INFO {entropay: url = $url}

	return $url
}


#############################################################
# the following are procs for decryption algorithm
# you should not need to call any of these directly

# convert hex to a binary string
proc entropay::hex2bin {hex} {
	variable HEX_TO_BIN

	regsub {^0[xX]} $hex {} hex

	set bin [string map -nocase $HEX_TO_BIN $hex]

	return $bin
}

# convert binary string into decimal
proc entropay::bin2dec {bin} {
	set r 0
	foreach d [split $bin {}] {
		incr r $r
		incr r $d
	}
	return $r
}

# generate a key from a seed
proc entropay::gen_key {seed} {
	variable CFG

	set buf     $seed&$CFG(CARD_KEY)
	set hash    [md5 $buf]
	set bin     [hex2bin $hash]
	# by removing the top bit (using only the last 31) we get a positive int
	set result  [string range $bin [expr {[string length $bin] - 31}] end]

	return      [bin2dec $result]
}

# decrypt a part of a card using key
proc entropay::decrypt_card_no_part {card_no_part gen_key} {
	# so that it doesn't think it's an octal number
	set card_no_part [string trimleft $card_no_part 0]
	return [expr {
		[_decrypt_card_no_part 1        $card_no_part $gen_key] +
		[_decrypt_card_no_part 10       $card_no_part $gen_key] +
		[_decrypt_card_no_part 100      $card_no_part $gen_key] +
		[_decrypt_card_no_part 1000     $card_no_part $gen_key] +
		[_decrypt_card_no_part 10000    $card_no_part $gen_key] +
		[_decrypt_card_no_part 100000   $card_no_part $gen_key] +
		[_decrypt_card_no_part 1000000  $card_no_part $gen_key] +
		[_decrypt_card_no_part 10000000 $card_no_part $gen_key]
	}]
}

# helper method for decrypting card numbers
proc entropay::_decrypt_card_no_part {mult card_no_part gen_key} {
	return [expr { (($card_no_part / $mult + (10 - ($gen_key / $mult) % 10)) % 10) * $mult }]
}

# generate a mod 10 check digit
proc entropay::checksum {card_no} {
	# extra padding digit needed to ensure that there's something there to replace
	set luhn [luhn ${card_no}0]

	return [expr { -$luhn % 10 }]
}

# generate a LUHN check of a number
proc entropay::luhn {card_no} {
	set doublepos [expr {[string length $card_no] % 2}]
	set total 0
	set i 0
	foreach n [split $card_no ""] {
		if {$i % 2 == $doublepos} {incr n $n}

		incr total [digsum $n]
		incr i
	}
	return [expr {$total % 10}]
}

# sum the digits of a number
proc entropay::digsum {n} {
	return [expr ([join [split $n ""] +])]
}

# decrypt a card number
proc entropay::decrypt_card_no {card_no} {
	if {[string length $card_no] != 24} {
		error "entropay: card number is the wrong length"
	}

	set bin          [string range $card_no 0  5]
	set range        [string range $card_no 6  6]
	set nonce        [string range $card_no 7  14]
	set var          [string range $card_no 15 22]
	set checksum     [string range $card_no 23 23]

	# if we don't validate the checksum the algorithm will create one and turn an
	# invalid card into a possibly valid one
	if {[checksum $bin$range$nonce$var] != $checksum} {
		error "entropay: checksum invalid"
	}

	set gen_key      [expr {[gen_key $bin$range$nonce] % 100000000}]

	set var_prime    [decrypt_card_no_part $var $gen_key]
	set var_prime    [format {%08u} $var_prime]

	set result       $bin$range$var_prime

	set checksum     [checksum $result]

	return $result$checksum
}
