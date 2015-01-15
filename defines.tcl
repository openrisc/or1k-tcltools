proc BLOCK_SIZE				{}	{ return 64 }

# Definitions for the top-level debug unit.  This really just consists
# of a single register, used to select the active debug module ("chain").
proc DBG_MODULE_SELECT_REG_SIZE		{}	{ return 2 }
proc DBG_MAX_MODULES			{}	{ return 4 }

proc DC_WISHBONE			{}	{ return 0 }
proc DC_CPU0				{}	{ return 1 }
proc DC_CPU1				{}	{ return 2 }
proc DC_JSP				{}	{ return 3 }

# Polynomial for the CRC calculation
# Yes, it's backwards.  Yes, this is on purpose.
# The hardware is designed this way to save on logic and routing,
# and it's really all the same to us here.
proc ADBG_CRC_POLY			{}	{ return 0xEDB88320 }

# These are for the internal registers in the Wishbone module
# The first is the length of the index register,
# the indexes of the various registers are defined after that
proc DBG_WB_REG_SEL_LEN			{}	{ return 1 }
proc DBG_WB_REG_ERROR			{}	{ return 0 }

# Opcode definitions for the Wishbone module
proc DBG_WB_OPCODE_LEN			{}	{ return 4 }
proc DBG_WB_CMD_NOP			{}	{ return 0x0 }
proc DBG_WB_CMD_BWRITE8			{}	{ return 0x1 }
proc DBG_WB_CMD_BWRITE16		{}	{ return 0x2 }
proc DBG_WB_CMD_BWRITE32		{}	{ return 0x3 }
proc DBG_WB_CMD_BREAD8			{}	{ return 0x5 }
proc DBG_WB_CMD_BREAD16			{}	{ return 0x6 }
proc DBG_WB_CMD_BREAD32			{}	{ return 0x7 }
proc DBG_WB_CMD_IREG_WR			{}	{ return 0x9 }
proc DBG_WB_CMD_IREG_SEL		{}	{ return 0xd }

# Internal register definitions for the CPU0 module
proc DBG_CPU0_REG_SEL_LEN		{}	{ return 1 }
proc DBG_CPU0_REG_STATUS		{}	{ return 0 }

# Opcode definitions for the first CPU module
proc DBG_CPU0_OPCODE_LEN		{} { return 4 }
proc DBG_CPU0_CMD_NOP			{} { return 0x0 }
proc DBG_CPU0_CMD_BWRITE32		{} { return 0x3 }
proc DBG_CPU0_CMD_BREAD32		{} { return 0x7 }
proc DBG_CPU0_CMD_IREG_WR		{} { return 0x9 }
proc DBG_CPU0_CMD_IREG_SEL		{} { return 0xd }

# Internal register definitions for the CPU1 module
proc DBG_CPU1_REG_SEL_LEN		{}	{ return 1 }
proc DBG_CPU1_REG_STATUS		{}	{ return 0 }

# Opcode definitions for the second CPU module
proc DBG_CPU1_OPCODE_LEN		{} { return 4 }
proc DBG_CPU1_CMD_NOP			{} { return 0x0 }
proc DBG_CPU1_CMD_BWRITE32		{} { return 0x3 }
proc DBG_CPU1_CMD_BREAD32		{} { return 0x7 }
proc DBG_CPU1_CMD_IREG_WR		{} { return 0x9 }
proc DBG_CPU1_CMD_IREG_SEL		{} { return 0xd }

# GPR address
proc R0					{}	{ return 0x400 }
proc R1					{}	{ return 0x401 }
proc R2					{}	{ return 0x402 }
proc R3					{}	{ return 0x403 }
proc R4					{}	{ return 0x404 }
proc R5					{}	{ return 0x405 }
proc R6					{}	{ return 0x406 }
proc R7					{}	{ return 0x407 }
proc R8					{}	{ return 0x408 }
proc R9					{}	{ return 0x409 }
proc R10				{}	{ return 0x40a }
proc R11				{}	{ return 0x40b }
proc R12				{}	{ return 0x40c }
proc R13				{}	{ return 0x40d }
proc R14				{}	{ return 0x40e }
proc R15				{}	{ return 0x40f }

# SPR
proc NPC				{}	{ return 0x10 }
