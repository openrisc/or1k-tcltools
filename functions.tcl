#/***************************************************************************
# *                                                                         *
# *   Copyright (C) 2012 Franck Jullien                                     *
# *   franck.jullien@elec4fun.fr                                            *
# *                                                                         *
# *   From adv_jtag_bridge which is:                                        *
# *   Copyright (C) 2008-2010 Nathan Yawn                                   *
# *   nyawn@opencores.net                                                   *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
# ***************************************************************************/

#
# Left shift a value and return the carry bit
#
proc shl {in_value word_size_bit} {

	upvar $in_value value

	set carry 0

	if {$value & [expr (1 << ($word_size_bit - 1))]} {
		set carry 1
	}

	switch $word_size_bit {
		8  { set value [expr (($value << 1) & 0xFF)] }
		16 { set value [expr (($value << 1) & 0xFFFF)] }
		32 { set value [expr (($value << 1) & 0xFFFFFFFF)] }
		default { set value [expr (($value << 1) & 0xFFFFFFFF)] }
	}

	return $carry
}

#
# Right shift a value and return the carry bit
#
proc shr {in_value word_size_bit carry} {

	upvar $in_value value

	switch $word_size_bit {
		8  { set value [expr (($value >> 1) & 0xFF)] }
		16 { set value [expr (($value >> 1) & 0xFFFF)] }
		32 { set value [expr (($value >> 1) & 0xFFFFFFFF)] }
		default { set value [expr (($value >> 1) & 0xFFFFFFFF)] }
	}

	set value [expr ($value | ($carry << ($word_size_bit - 1)))]
}

#
# Left shift an array and return the carry bit
#
proc shift_array_l { tbl word_size_bit} {

	upvar $tbl table

	set last_carry 0
	set carry 0

	for { set i 0 } { $i < [array size table] } { incr i} {
		set carry [shl table($i) $word_size_bit]
		set table($i) [expr ($table($i) | $last_carry)]
		set last_carry $carry
	}

	return $carry
}

#
# Right shift an array and return the carry bit
#
proc shift_array_r { tbl word_size_bit carry_in } {

	upvar $tbl table

	for { set i 0 } { $i < [expr ([array size table] - 1)] } { incr i} {
		set next [expr ($i + 1)]
		set value $table($next)
		set carry [expr ($value & 1) ]
		shr table($i) $word_size_bit $carry
	}

	shr table([expr ([array size table] - 1)]) $word_size_bit $carry_in
}

#
# Format table
#
proc format_table { tbl } {

	upvar $tbl table

	puts " "
	puts "CPU GPR"
	puts "--------------------------------"

	for { set i 0 } { $i < [expr ([array size table] - 1)] } { incr i} {
		set table($i) [format %08X $table($i)]
		puts -nonewline "R"
		puts -nonewline $i
		puts -nonewline ":\t0x"
		puts $table($i)
	}
}

#
# Compute CRC over an array
#
proc get_crc { tbl word_size_bit} {

	upvar $tbl table

	set crc_calc 0xFFFFFFFF

	for { set i 0 } { $i < [array size table] } { incr i} {
		set crc_calc [adbg_compute_crc $crc_calc $table($i) $word_size_bit]
	}

	return $crc_calc
}

#
# Compute CRC on a single value
#
proc adbg_compute_crc {crc_in data_in length_bits} {

	set crc_out $crc_in

	for {set i 0} { $i < $length_bits } { incr i 1} {
		set d [expr ((($data_in >> $i) & 0x1) ? 0xffffffff : 0)]
		set c [expr (($crc_out & 0x1) ? 0xffffffff : 0)]
		set crc_out [expr ($crc_out >> 1)]
		set crc_out [expr ($crc_out ^ (($d ^ $c) & [ADBG_CRC_POLY]))]
	}

	return $crc_out
}