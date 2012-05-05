#/***************************************************************************
# *                                                                         *
# *   Copyright (C) 2012 Franck Jullien                                     *
# *   franck.jullien@elec4fun.fr                                            *
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
source [file dirname [info script]]/loader.tcl

proc or1krun { file_name } {

	set file [open $file_name r]
	fconfigure $file -translation binary

	set start_time [clock milliseconds]
	set total_size 0

	set e_ident [read $file 16]
	binary scan $e_ident H2H2H2H2H2H2H2H2H2H12H2 EI_MAG0 EI_MAG1 EI_MAG2 EI_MAG3 EI_CLASS EI_DATA EI_VERSION EI_OSABI EI_ABIVERSION EI_PAD EI_NIDENT

	if { $EI_MAG0 != "7f" || $EI_MAG1 != "45" || $EI_MAG2 != "4c" || $EI_MAG3 != "46" } {
		puts "\nBad ELF format\n"
		return
	}

	set e_type [read $file 2]
	binary scan $e_type H4 e_type

	set e_machine [read $file 2]
	binary scan $e_machine H4 e_machine

	set e_version [read $file 4]
	binary scan $e_version H8 e_version

	set e_entry [read $file 4]
	binary scan $e_entry H8 e_entry

	set e_phoff [read $file 4]
	binary scan $e_phoff H8 e_phoff

	set e_shoff [read $file 4]
	binary scan $e_shoff H8 e_shoff

	set e_flags [read $file 4]
	binary scan $e_flags H8 e_flags

	set e_ehsize [read $file 2]
	binary scan $e_ehsize H4 e_ehsize

	set e_phentsize [read $file 2]
	binary scan $e_phentsize H4 e_phentsize

	set e_phnum [read $file 2]
	binary scan $e_phnum H4 e_phnum

	set e_shentsize [read $file 2]
	binary scan $e_shentsize H4 e_shentsize

	set e_shnum [read $file 2]
	binary scan $e_shnum H4 e_shnum

	set e_shtrndx [read $file 2]
	binary scan $e_shtrndx H4 e_shtrndx

	# Program header
	seek $file "0x$e_phoff" start

	set e_phnum "0x$e_phnum"

	puts " "

	if { $e_phnum != 0 } {

		setup_jtag
		stall_cpu0

		for { set i 0 } { $i < $e_phnum } { incr i } {
			set temp [read $file "0x$e_phentsize"]
			binary scan $temp H8H8H8H8H8H8H8H8 p_type p_offset p_vaddr p_paddr p_filesz p_memsz p_flags p_align

			set p_paddr "0x$p_paddr"
			set p_filesz "0x$p_filesz"
			set xmit_bytes 0
			set percent 0
			set total_size [expr ($total_size + $p_filesz)]

			# Save file pointer
			set back [tell $file]

			seek $file "0x$p_offset" start

			set nb_block [expr int($p_filesz / [expr ([BLOCK_SIZE] * 4)])]
			set spare_words [expr ($p_filesz % [expr ([BLOCK_SIZE] * 4)])]

			set index 0
			set write_address $p_paddr

			for { set block 0 } { $block < $nb_block } { incr block } {

				set offset [expr ($block * [BLOCK_SIZE] * 8)]
				set index 0

				set temp [read $file [expr ([BLOCK_SIZE] * 4)]]
				binary scan $temp H* temp

				for { set j 0 } { $j < [BLOCK_SIZE] } { incr j } {

					set start [expr ($j * 8)]
					set end [expr (7 + ($j * 8))]

					set word [string range $temp $start $end]

					set data($j) "0x$word"
					#puts $data($j)
				}

				set xmit_bytes [expr ($xmit_bytes + ([BLOCK_SIZE] * 4))]
				set percent [expr ($xmit_bytes * 100) / $p_filesz ]
				puts -nonewline "Program header $i: addr 0x$p_paddr, size 0x$p_filesz ($percent%)\r"

				write_wb 4 [BLOCK_SIZE] $write_address data
				set write_address [expr ($write_address + [expr ([BLOCK_SIZE] * 4)])]

			}

			set spare [expr ($spare_words / 4)]

			set temp [read $file $spare_words]
			binary scan $temp H* temp

			for { set j 0 } { $j < $spare } { incr j } {
				set start [expr ($j * 8)]
				set end [expr (7 + ($j * 8))]
				set word [string range $temp $start $end]
				#puts $word
				set data($j) "0x$word"
			}

			puts "Program header $i: addr 0x$p_paddr, size 0x$p_filesz (100%)"
			write_wb 4 $spare $write_address data

			# Restore file pointer
			seek $file $back

		}

	} else {

		# Section header
		seek $file "0x$e_shoff" start

		set e_shnum "0x$e_shnum"
		incr e_shnum

		# Save the current file pointer
		set fp [tell $file]

		for { set i 0 } { $i < $e_shnum } { incr i } {
			set temp [read $file "0x$e_shentsize"]
			binary scan $temp H8H8H8H8H8H8H8H8H8H8 sh_name sh_type sh_flags sh_addr sh_offset sh_size sh_link sh_info sh_addralign sh_entsize
			if { "0x$sh_type" == 3 } {
				set sh_addr "0x$sh_addr"
				set sh_offset "0x$sh_offset"
				seek $file [expr ($sh_addr + $sh_offset)] start
				set strtab [read $file "0x$sh_size"]
			}
		}

		# Restore file pointer
		seek $file $fp

		for { set i 0 } { $i < $e_shnum } { incr i } {
			set temp [read $file "0x$e_shentsize"]
			binary scan $temp H8H8H8H8H8H8H8H8H8H8 sh_name sh_type sh_flags sh_addr sh_offset sh_size sh_link sh_info sh_addralign sh_entsize

			set sh_type "0x$sh_type"
			set sh_flags "0x$sh_flags"
			set sh_addr "0x$sh_addr"
			set sh_size "0x$sh_size"
			set xmit_bytes 0
			set percent 0

			if { ($sh_type == 1) && [expr ($sh_flags & 2)] && ($sh_size != 0)} {

				set src "0x$sh_name"
				set end $src
				set ascii 255

				while { $ascii != 0} {
					incr end
					scan [ string range $strtab $end $end ] %c ascii
				}

				set end [expr ($end - 1)]

				set name [ string range $strtab $src $end ]

				setup_jtag
				stall_cpu0

				# Save file pointer
				set back [tell $file]
				seek $file "0x$sh_offset" start

				set total_size [expr ($total_size + $sh_size)]

				set nb_block [expr int($sh_size / [expr ([BLOCK_SIZE] * 4)])]
				set spare_words [expr ($sh_size % [expr ([BLOCK_SIZE] * 4)])]

				set write_address $sh_addr

				for { set block 0 } { $block < $nb_block } { incr block } {

					set offset [expr ($block * [BLOCK_SIZE] * 8)]
					set index 0

					set temp [read $file [expr ([BLOCK_SIZE] * 4)]]
					binary scan $temp H* temp

					for { set j 0 } { $j < [BLOCK_SIZE] } { incr j } {
						set start [expr ($j * 8)]
						set end [expr (7 + ($j * 8))]
						set word [string range $temp $start $end]
						set data($j) "0x$word"
					}

					set xmit_bytes [expr ($xmit_bytes + ([BLOCK_SIZE] * 4))]
					set percent [expr ($xmit_bytes * 100) / $sh_size ]
					puts -nonewline "Loading section [format %10s $name], size $sh_size lma $sh_addr ($percent%)\r"

					write_wb 4 [BLOCK_SIZE] $write_address data
					set write_address [expr ($write_address + [expr ([BLOCK_SIZE] * 4)])]

				}

				set offset [expr ($nb_block * [BLOCK_SIZE] * 8)]
				set index 0

				set spare [expr ($spare_words / 4)]

				set temp [read $file [expr ($spare_words * 4)]]
				binary scan $temp H* temp

				for { set j 0 } { $j < $spare } { incr j } {
					set start [expr ($j * 8)]
					set end [expr (7 + ($j * 8))]
					set word [string range $temp $start $end]
					set data($j) "0x$word"
				}

				puts "Loading section [format %10s $name], size $sh_size lma $sh_addr (100%)"
				write_wb 4 $spare $write_address data

				# Restore file pointer
				seek $file $back
			}
		}
	}

	run_cpu0

	close_jtag

	set end_time [clock milliseconds]

	puts " "
	puts -nonewline "Download time : "
	set  time [expr ((double($end_time) - $start_time) / 1000)]
	puts -nonewline [format %.2f $time]
	puts s

	puts -nonewline "Download speed: "
	set speed [expr ($total_size / double($time)) / 1024]
	puts -nonewline [format %.2f $speed]
	puts KB/s

	puts " "

	close $file
}
