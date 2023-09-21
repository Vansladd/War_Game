# (C) 2013 Openbet Technology Ltd. All rights reserved.
#
# Bitwise Utility Procedures
#
# The utility procedures below perform bitwise operations on a lists of integers
# that together represent a binary mask of unlimited precision. The binary masks
# are broken down into 32 bit integers, chosen as the maximum integer precision
# supported by Javascript.
#
# Therefore each 32 positions map to an integer element within the list, e.g.:
#
#       positions 0-31       positions 32-63      etc
# [list 0xff00ff00ff00ff00   0xff00ff00ff00ff00   ......]

set pkgVersion 1.0
package provide core::bitwise $pkgVersion
package require core::log  1.0
package require core::args 1.0

core::args::register_ns \
	-namespace core::bitwise \
	-version   $pkgVersion \
	-dependent [list core::args core::log] \
	-desc      {Bitwise utilities} \
	-docs      util/bitwise.xml

namespace eval core::bitwise {
	variable P2

	# Powers of 2 are stored within the P2 array for fast lookup, written out
	# longhand below for readability, i.e.:
	#   P2(0) = 2^0 = 1
	#   P2(1) = 2^1 = 2
	#   etc.
	#
	set P2(0)        0x01
	set P2(1)        0x02
	set P2(2)        0x04
	set P2(3)        0x08
	set P2(4)        0x10
	set P2(5)        0x20
	set P2(6)        0x40
	set P2(7)        0x80
	set P2(8)      0x0100
	set P2(9)      0x0200
	set P2(10)     0x0400
	set P2(11)     0x0800
	set P2(12)     0x1000
	set P2(13)     0x2000
	set P2(14)     0x4000
	set P2(15)     0x8000
	set P2(16)   0x010000
	set P2(17)   0x020000
	set P2(18)   0x040000
	set P2(19)   0x080000
	set P2(20)   0x100000
	set P2(21)   0x200000
	set P2(22)   0x400000
	set P2(23)   0x800000
	set P2(24) 0x01000000
	set P2(25) 0x02000000
	set P2(26) 0x04000000
	set P2(27) 0x08000000
	set P2(28) 0x10000000
	set P2(29) 0x20000000
	set P2(30) 0x40000000
	set P2(31) 0x80000000

	# The inverted values are written out here. Used for clearing bits
	set INVP2(0)  0xFFFFFFFE
	set INVP2(1)  0xFFFFFFFD
	set INVP2(2)  0xFFFFFFFB
	set INVP2(3)  0xFFFFFFF7
	set INVP2(4)  0xFFFFFFEF
	set INVP2(5)  0xFFFFFFDF
	set INVP2(6)  0xFFFFFFBF
	set INVP2(7)  0xFFFFFF7F
	set INVP2(8)  0xFFFFFEFF
	set INVP2(9)  0xFFFFFDFF
	set INVP2(10) 0xFFFFFBFF
	set INVP2(11) 0xFFFFF7FF
	set INVP2(12) 0xFFFFEFFF
	set INVP2(13) 0xFFFFDFFF
	set INVP2(14) 0xFFFFBFFF
	set INVP2(15) 0xFFFF7FFF
	set INVP2(16) 0xFFFEFFFF
	set INVP2(17) 0xFFFDFFFF
	set INVP2(18) 0xFFFBFFFF
	set INVP2(19) 0xFFF7FFFF
	set INVP2(20) 0xFFEFFFFF
	set INVP2(21) 0xFFDFFFFF
	set INVP2(22) 0xFFBFFFFF
	set INVP2(23) 0xFF7FFFFF
	set INVP2(24) 0xFEFFFFFF
	set INVP2(25) 0xFDFFFFFF
	set INVP2(26) 0xFBFFFFFF
	set INVP2(27) 0xF7FFFFFF
	set INVP2(28) 0xEFFFFFFF
	set INVP2(29) 0xDFFFFFFF
	set INVP2(30) 0xBFFFFFFF
	set INVP2(31) 0x7FFFFFFF
}


# Set a single bit within a binary mask and return the result.
#
#   mask       - a list of 32 bit integers (see above)
#   n          - the bit to set
#
core::args::register \
	-proc_name core::bitwise::set_bit \
	-desc      {Set a single bit within a binary mask and return the result} \
	-args      [list \
		[list -arg -mask    -mand 1 -check LIST -desc {A list of 32 bit integers that make up the mask}] \
		[list -arg -bit_pos -mand 1 -check UINT -desc {The postion of the bit to set}] \
	] \
	-body {
		variable P2

		set mask $ARGS(-mask)
		set n    $ARGS(-bit_pos)


		# The masks are broken down into 32 bit integers, as this is what JS can
		# handle. So each 32 positions map to a mask integer.
		set mask_idx      [expr {$n / 32}]
		set mask_position [expr {$n % 32}]

		# Ensure that enough masks are initialised to accomodate this position.
		while {[set sub_mask [lindex $mask $mask_idx]] == ""} {
			lappend mask 0
		}

		# Apply change to the relevant sub group with the list of binary masks.
		lset mask $mask_idx [expr {$sub_mask | $P2($mask_position)}]

		return $mask
	}

# Set a single bit within a binary mask and return the result.
#
#   mask       - a list of 32 bit integers (see above)
#   n          - the bit to set
#
core::args::register \
	-proc_name core::bitwise::clear_bit \
	-desc      {Clear a single bit within a binary mask and return the result} \
	-args      [list \
		[list -arg -mask    -mand 1 -check LIST -desc {A list of 32 bit integers that make up the mask}] \
		[list -arg -bit_pos -mand 1 -check UINT -desc {The postion of the bit to clear}] \
	] \
	-body {
		variable INVP2

		set mask $ARGS(-mask)
		set n    $ARGS(-bit_pos)


		# The masks are broken down into 32 bit integers, as this is what JS can
		# handle. So each 32 positions map to a mask integer.
		set mask_idx      [expr {$n / 32}]
		set mask_position [expr {$n % 32}]

		# Ensure that enough masks are initialised to accomodate this position.
		while {[set sub_mask [lindex $mask $mask_idx]] == ""} {
			lappend mask 0
		}

		# Apply change to the relevant sub group with the list of binary masks. Use inverted power
		# value to clear the list using AND
		lset mask $mask_idx [expr {$sub_mask & $INVP2($mask_position)}]

		return $mask
	}

# Count he number of bits set in the mask
#
#   mask       - a list of 32 bit integers (see above)
#
core::args::register \
	-proc_name core::bitwise::count_set_bits \
	-desc      {Count he number of bits set in the mask} \
	-args      [list \
		[list -arg -mask    -mand 1 -check LIST -desc {A list of 32 bit integers that make up the mask}] \
	] \
	-body {
		set count 0

		foreach v $ARGS(-mask) {

			for {set i 0} {$i < 32} {incr i} {
				if {$v & 0x01} {
					incr count
				}

				set v [expr {$v >> 1}]
			}
		}

		return $count
	}

# Perform a bitwise or on 2 binary masks and return the result.
#
#   a           - a list of 32 bit integers representing a binary mask (see
#                 above). The first operand for the bitwise or.
#                to use in the bitwise or operation.
#   b           - a list of 32 bit integers representing a binary mask (see
#                 above). The second operand for the bitwise or.
#
core::args::register \
	-proc_name core::bitwise::or \
	-desc      {Perform a bitwise or on 2 binary masks and return the result} \
	-args      [list \
		[list -arg -mask_a -mand 1 -check LIST -desc {A list of 32 bit integers representing a binary mask}] \
		[list -arg -mask_b -mand 1 -check LIST -desc {A list of 32 bit integers representing a binary mask}] \
	] \
	-body {
		set a $ARGS(-mask_a)
		set b $ARGS(-mask_b)

		set al [llength $a]
		set bl [llength $b]

		if {$al > $bl} {
			set l $al
		} else {
			set l $bl
		}

		set ret [list]

		for {set i 0} {$i < $l} {incr i} {

			set sub_a [lindex $a $i]
			set sub_b [lindex $b $i]

			if {$sub_a eq ""} {
				set sub_a 0
			}
			if {$sub_b eq ""} {
				set sub_b 0
			}

			lappend ret [expr {$sub_a | $sub_b}]
		}

		while {[lindex $ret end] == 0} {
			set ret [lrange $ret 0 end-1]
		}

		return $ret
	}



# Perform a bitwise left shift on a binary mask and return the result.
#
#   mask        - a list of 32 bit integers representing a binary mask (see
#                 above). The operand to apply the left shift.
#   shift       - integer giving the number of bit positions to shift.
#
core::args::register \
	-proc_name core::bitwise::left_shift \
	-desc      {Perform a bitwise left shift on a binary mask and return the result} \
	-args      [list \
		[list -arg -mask    -mand 1 -check LIST -desc {A list of 32 bit integers that make up the mask}] \
		[list -arg -shift   -mand 1 -check UINT -desc {Number of bits to shift}] \
	] \
	-body {

		if {$ARGS(-shift) == 0} {
			return $ARGS(-mask)
		}

		set mask  $ARGS(-mask)
		set shift $ARGS(-shift)


		set n [expr {($shift/32) + 1}]

		# Shift 32 bits at a time, otherwise the data is lost due to overflow.
		for {set i 0} {$i < $n} {incr i} {

			set curr_shift [expr {$shift - ($i * 32)}]
			if {$curr_shift >= 32} {

				# Simply append 32 0s to the front.
				set mask [concat [list 0] $mask]
				continue
			}

			set prev_overflow 0

			set l [llength $mask]

			for {set j 0} {$j < $l} {incr j} {

				set sub_mask [expr {[lindex $mask $j] << $curr_shift}]
				lset mask $j [expr {($sub_mask | $prev_overflow) & 0xffffffff}]
				set prev_overflow [expr {$sub_mask >> 32}]
			}

			if {$prev_overflow != 0} {
				lappend mask [expr {$prev_overflow & 0xffffffff}]
			}
		}

		return $mask
	}


# Initialise a bitmask
#
#   num_positions  - number of elements to be represented in the bitmask
#
#   returns an initialised bitmask
#
core::args::register \
	-proc_name core::bitwise::init_mask \
	-desc      {Initialise a bitmask} \
	-args      [list \
		[list -arg -num_positions -mand 1 -check UINT            -desc {number of bits to be represented in the bitmask}] \
		[list -arg -set_all_bits  -mand 0 -check BOOL -default 0 -desc {Set all bits in the initialised bit mask}] \
	] \
	-body {
		variable P2

		set num_positions $ARGS(-num_positions)
		set set_all_bits  $ARGS(-set_all_bits)

		set mask [list]

		set num_parts      [expr {(($num_positions - 1) / 32) + 1}]
		set remaining_bits [expr {$num_positions % 32}]

		for {set i 0} {$i < $num_parts} {incr i} {
			if {$set_all_bits} {
				lappend mask [expr {0xffffffff}]
			} else {
				lappend mask 0
			}
		}

		if {$set_all_bits && $remaining_bits != 0} {

			set last_part 0

			for {set i 0} {$i < $remaining_bits} {incr i} {
				set last_part [expr {$last_part + $P2($i)}]
			}

			set mask [lreplace $mask end end $last_part]
		}

		return $mask
	}
