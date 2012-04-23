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

# Loads constants definition
source [file dirname [info script]]/defines.tcl
# Loads usefull functions
source [file dirname [info script]]/functions.tcl

proc adbg_select_module {chain} {

	set data [expr ($chain | (1 << [DBG_MODULE_SELECT_REG_SIZE]))]
	device_virtual_dr_shift -instance_index 0 -length 3 -dr_value $data -value_in_hex -no_captured_dr_value
}

#
# Set the index of the desired register in the currently selected module
# 1 bit module select command
# 4 bits opcode
# n bits index
# Make sure the corrent module/chain is selected before calling this
#
proc adbg_select_ctrl_reg { chain regidx} {

  # If this reg is already selected, don't do a JTAG transaction
  #if(current_reg_idx[current_chain] == regidx)
  #  return APP_ERR_NONE;

	switch $chain {
		# DC_WISHBONE
		0	{
				set index_len [DBG_WB_REG_SEL_LEN]
				set opcode [DBG_WB_CMD_IREG_SEL]
		}
		# DC_CPU0
		1	{
				set index_len [DBG_CPU0_REG_SEL_LEN]
				set opcode [DBG_CPU0_CMD_IREG_SEL]
		}
		# DC_CPU1
		2	{	set index_len [DBG_CPU1_REG_SEL_LEN]
				set opcode [DBG_CPU1_CMD_IREG_SEL]
		}

		default		{ puts "ERROR! Illegal debug chain selected while selecting control register!" }
	}


	# Set up the data.
	set data [expr (($opcode & ~(1 << [DBG_WB_OPCODE_LEN])) << $index_len)]
	set data [expr ($data | $regidx)]

	set data [format %02X $data]

	set length [expr (5 + $index_len)]

	device_virtual_dr_shift -instance_index 0 -length $length -dr_value $data -value_in_hex -no_captured_dr_value

}

#
# Sends out a generic command to the selected debug unit module, LSB first.  Fields are:
# MSB: 1-bit module command
# 4-bit opcode
# m-bit register index
# n-bit data (LSB)
# Note that in the data array, the LSB of data[0] will be sent first,
# (and become the LSB of the command)
# up through the MSB of data[0], then the LSB of data[1], etc.
#
proc adbg_ctrl_write { chain regidx cmd_data length_bits} {

	switch $chain {
		# DC_WISHBONE
		0	{
				set index_len [DBG_WB_REG_SEL_LEN]
				set opcode [DBG_WB_CMD_IREG_WR]
		}
		# DC_CPU0
		1	{
				set index_len [DBG_CPU0_REG_SEL_LEN]
				set opcode [DBG_CPU0_CMD_IREG_WR]
		}
		# DC_CPU1
		2	{	set index_len [DBG_CPU1_REG_SEL_LEN]
				set opcode [DBG_CPU1_CMD_IREG_WR]
		}

		default		{ puts "ERROR! Illegal debug chain selected while selecting control register!" }
	}

	# Set up the data.
	set data [expr (($opcode & ~(1 << [DBG_WB_OPCODE_LEN])) << $index_len)]
	set data [expr ($data | $regidx)]

	set data [expr (($data << $length_bits) | $cmd_data)]

	set len	[expr ($length_bits + 5 + $index_len)]

	set data [format %02X $data]

	device_virtual_dr_shift -instance_index 0 -length $len -dr_value $data -value_in_hex -no_captured_dr_value

}

# reads control register (internal to the debug unit)
# Currently only 1 register in the CPU module, so no register select
#
proc adbg_ctrl_read { chain data databits} {

	switch $chain {
		# DC_WISHBONE
		0	{
				set opcode_len [DBG_WB_OPCODE_LEN]
				set opcode [DBG_WB_CMD_NOP]
		}
		# DC_CPU0
		1	{
				set opcode_len [DBG_CPU0_OPCODE_LEN]
				set opcode [DBG_CPU0_CMD_NOP]
		}
		# DC_CPU1
		2	{	set opcode_len [DBG_CPU1_OPCODE_LEN]
				set opcode [DBG_CPU1_CMD_NOP]
		}

		default		{ puts "ERROR! Illegal debug chain selected while doing control read!" }
	}

	set outdata [expr ($opcode & ~(0x1 << $opcode_len))]

	set len [expr ($databits + $opcode_len + 1)]

	set nb_nibble [expr ($len / 4)]

	if { [expr ($len % 4)] != 0 } {
		incr nb_nibble
	}

	set outdata "0$outdata"

	set data [device_virtual_dr_shift -instance_index 0 -length $len -dr_value $outdata -value_in_hex ]
}

proc adbg_burst_command {opcode address length} {

	set data0 [expr { $length | $address << 16 }]
	set data0hex [format %08X $data0]

	set data1 [ expr { ($address >> 16) | (($opcode & 0xf) << 16) & ~(0x1<<20) } ]
	set data1hex [format %06X $data1]

	set data $data1hex$data0hex

	device_virtual_dr_shift -instance_index 0 -length 53 -dr_value $data -value_in_hex -no_captured_dr_value

}

proc adbg_wb_burst_read {chain word_size_bytes word_count start_address} {

	switch $chain {
	# DC_WISHBONE
	0	{
			if {$word_size_bytes == 1} {
				set opcode [DBG_WB_CMD_BREAD8]
			} elseif {$word_size_bytes == 2} {
				set opcode [DBG_WB_CMD_BREAD16]
			} elseif {$word_size_bytes == 4} {
				set opcode [DBG_WB_CMD_BREAD32]
			} else {
					puts "Tried burst read with invalid, defaulting to 4-byte words"
					set opcode [DBG_WB_CMD_BREAD32]
			}
	}
	# DC_CPU0
	1	{
			if {$word_size_bytes == 4} {
				set opcode [DBG_CPU0_CMD_BREAD32]
			} else {
					puts "Tried burst read with invalid word size, defaulting to 4-byte words"
					set opcode [DBG_CPU0_CMD_BREAD32]
			}
	}
	# DC_CPU1
	2	{
			if {$word_size_bytes == 4} {
				set opcode [DBG_CPU1_CMD_BREAD32]
			} else {
					puts "Tried burst read with invalid word size, defaulting to 4-byte words"
					set opcode [DBG_CPU1_CMD_BREAD32]
			}
	}

		default { puts  "ERROR! Illegal debug chain selected while doing burst read!" }
	}

	adbg_burst_command $opcode $start_address $word_count

	#len = $word_size_bytes * 8 * $word_count + crc_bit_len + ready_bit
	set len [expr ($word_size_bytes * 8 * $word_count + 32 + 1)]

	enable_debug
	set result [device_virtual_dr_shift -instance_index 0 -length $len -value_in_hex ]

	return $result
}

proc adbg_wb_burst_write {chain word_size_bytes word_count start_address data_array} {

	upvar $data_array data

	switch $chain {
	# DC_WISHBONE
	0	{
			if {$word_size_bytes == 1} {
				set opcode [DBG_WB_CMD_BWRITE8]
			} elseif {$word_size_bytes == 2} {
				set opcode [DBG_WB_CMD_BWRITE16]
			} elseif {$word_size_bytes == 4} {
				set opcode [DBG_WB_CMD_BWRITE32]
			} else {
					puts "Tried burst read with invalid, defaulting to 4-byte words"
					set opcode [DBG_WB_CMD_BWRITE32]
			}
	}
	# DC_CPU0
	1	{
			if {$word_size_bytes == 4} {
				set opcode [DBG_CPU0_CMD_BWRITE32]
			} else {
					puts "Tried burst read with invalid word size, defaulting to 4-byte words"
					set opcode [DBG_CPU0_CMD_BWRITE32]
			}
	}
	# DC_CPU1
	2	{
			if {$word_size_bytes == 4} {
				set opcode [DBG_CPU1_CMD_BWRITE32]
			} else {
					puts "Tried burst read with invalid word size, defaulting to 4-byte words"
					set opcode [DBG_CPU1_CMD_BWRITE32]
			}
	}

		default { puts  "ERROR! Illegal debug chain selected while doing burst read!" }
	}

	# Sends then burst command
	adbg_burst_command $opcode $start_address $word_count

	# len = match_bit + crc_size + $word_size_bytes * 8 * $word_count + ready_bit
	set len [expr (1 + 32 + $word_size_bytes * 8 * $word_count + 1)]

	set word_size_bit [expr ($word_size_bytes * 8)]

	# Compute CRC on data
	set crc [get_crc data $word_size_bit]

	# We need to add the CRC value at the end of array. So get the last index and do it.
	#set array_size [array size data]
	set data($word_count) $crc
	#incr array_size

	# There is a start bit as then first bits of the bitstream. We need to shift the
	# array in order to insert this starting bit.
	set carry [shift_array_l data $word_size_bit]
	set data(0) [expr ($data(0) | 1)]

	# Building of then output string
	set output ""
	for {set i 0} { $i < [expr ($word_count + 1)]} { incr i} {
		switch $word_size_bit {
			8  { set output [format %02X $data($i)]$output }
			16 { set output [format %04X $data($i)]$output }
			32 { set output [format %08X $data($i)]$output }
			default { set output [format %08X $data($i)]$output }
		}
	}

	#If there is a carry then the last nibble should be "1" else "0"
	if {$carry == 1} {
		set output 1$output
	} else {
		set output 0$output
	}

	# Bitstream length is (nb_data * word_size_bit) + crc_size + start_bit + match_bit
	set length [expr (($word_count * $word_size_bit) + 32 + 1 + 1)]

	# Send the command to the TAP
	device_virtual_dr_shift -instance_index 0 -length $length -dr_value $output -value_in_hex
}


proc registers {} {
	setup_jtag

	stall_cpu0

	adbg_select_module [DC_CPU0]
	set result [adbg_wb_burst_read [DC_CPU0] 4 32 0x400]

	unstall_cpu0

	print_registers $result
	close_jtag
}

proc reset_cpu0 {} {
	adbg_select_module [DC_CPU0]
	adbg_select_ctrl_reg [DC_CPU0] [DBG_CPU0_REG_STATUS]
	adbg_ctrl_write [DC_CPU0] [DBG_CPU0_REG_STATUS] 2 2
	adbg_ctrl_write [DC_CPU0] [DBG_CPU0_REG_STATUS] 0 2
}

proc stall_cpu0 {} {
	adbg_select_module [DC_CPU0]
	adbg_select_ctrl_reg [DC_CPU0] [DBG_CPU0_REG_STATUS]
	adbg_ctrl_write [DC_CPU0] [DBG_CPU0_REG_STATUS] 1 2
}

proc unstall_cpu0 {} {
	adbg_select_module [DC_CPU0]
	adbg_select_ctrl_reg [DC_CPU0] [DBG_CPU0_REG_STATUS]
	adbg_ctrl_write [DC_CPU0] [DBG_CPU0_REG_STATUS] 0 2
}

proc run_cpu0 {} {
	set D(0) 0x100
	adbg_select_module [DC_CPU0]
	adbg_wb_burst_write [DC_CPU0] 4 1 0x10 D
	adbg_select_ctrl_reg [DC_CPU0] [DBG_CPU0_REG_STATUS]
	adbg_ctrl_write [DC_CPU0] [DBG_CPU0_REG_STATUS] 0 2
}

proc write_wb { word_size_bytes word_count start_address data_array } {
	upvar $data_array data
	adbg_select_module [DC_WISHBONE]
	adbg_wb_burst_write [DC_WISHBONE] $word_size_bytes $word_count $start_address data
}

proc setup_jtag {} {
	jtag_open
	device_lock -timeout 10000
	enable_debug
	puts " "
}

proc close_jtag {} {
	disable_debug
	device_unlock
	close_device
}

proc off {} {
	device_unlock
	close_device
}

proc print_registers {result} {

	set word_count 32

	set current_lsb 0
	set current_msb 0

	set current_ptr [ expr [string length $result] - 1 ]

	if {[string range $result 0 0] == 0} {
		set carry 0
	} else {
		set carry 1;
	}

	for {set i 0} { $i < [expr ($word_count + 1)]} { incr i} {
		set current_lsb [expr ($current_ptr - ($i * 8))]
		set current_msb [expr ($current_ptr - (($i * 8) + 7))]
		set hex "0x"
		set data($i) $hex[string range $result $current_msb $current_lsb]
	}

	shift_array_r data 32 $carry

	#set crc $data($word_count)
	#puts [format %08X $crc]

	format_table data

	for {set i 0} { $i < $word_count } { incr i} {
		set test($i) $hex$data($i)
	}

	puts " "
	#puts [format %08X [get_crc test 32]]

}

proc jtag_open {} {
	# Get the list of JTAG controllers
	set hardware_names [get_hardware_names]
	# Select the first JTAG controller
	set hardware_name [lindex $hardware_names 0]
	# Get the list of FPGAs in the JTAG chain
	set device_names [get_device_names -hardware_name $hardware_name]
	# Select the first FPGA
	set device_name [lindex $device_names 0]
	puts "\nJTAG: $hardware_name, FPGA: $device_name"
	open_device -hardware_name $hardware_name -device_name $device_name
}

proc jtag_close {} {
close_device
}

proc enable_debug {} {
device_virtual_ir_shift -instance_index 0 -ir_value 8 -no_captured_ir_value
}

proc disable_debug {} {
device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
}
