#
#  This file is part of nimbme (nim bare-metal environment)
#  Copyright (c) 2025 Michael Krauter <michakr@atomicmail.io>
# 
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, version 3.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <https://www.gnu.org/licenses/>.
# 

# soc dependend helper for clock management
# wip

type
  ClkSrc*  = enum Osc = 0, PllA = 1, PllC = 2, PllD = 3, Hdmi = 4
  
const
  PERIPHERAL_BASE = 0x20000000'u32
  CM_BASE         = PERIPHERAL_BASE + 0x101000'u32

  # Clock Manager Register Offsets
  CM_GP0CTL   = CM_BASE + 0x070
  CM_GP0DIV   = CM_BASE + 0x074
  CM_GP1CTL   = CM_BASE + 0x078
  CM_GP1DIV   = CM_BASE + 0x07C
  CM_GP2CTL   = CM_BASE + 0x080
  CM_GP2DIV   = CM_BASE + 0x084
  CM_PCMCTL   = CM_BASE + 0x098
  CM_PCMDIV   = CM_BASE + 0x09C
  CM_PWMCTL   = CM_BASE + 0x0A0
  CM_PWMDIV   = CM_BASE + 0x0A4
  CM_UARTCTL  = CM_BASE + 0x0A0
  CM_UARTDIV  = CM_BASE + 0x0A4
  CM_SPI0CTL  = CM_BASE + 0x0A8
  CM_SPI0DIV  = CM_BASE + 0x0AC
  CM_SPI1CTL  = CM_BASE + 0x0B0
  CM_SPI1DIV  = CM_BASE + 0x0B4
  CM_I2CCTL   = CM_BASE + 0x0B8
  CM_I2CDIV   = CM_BASE + 0x0BC
  CM_EMMCCTL  = CM_BASE + 0x0C0
  CM_EMMCDIV  = CM_BASE + 0x0C4

  # Clock Source IDs
  CM_SRC_GND       = 0'u32
  CM_SRC_OSC       = 1'u32    # 19.2 mHz
  CM_SRC_DBG0      = 2'u32
  CM_SRC_DBG1      = 3'u32
  CM_SRC_PLLA      = 4'u32    # CPU core
  CM_SRC_PLLC      = 5'u32    # GPU core
  CM_SRC_PLLD      = 6'u32    # 500 mHz
  CM_SRC_HDMI      = 7'u32

  # Control Bits
  CM_PASSWORD      = 0x5A000000'u32
  CM_CTL_MASH_MASK = 0b11'u32 shl 9
  CM_CTL_FLIP      = 1'u32 shl 8
  CM_CTL_BUSY      = 1'u32 shl 7
  CM_CTL_KILL      = 1'u32 shl 5
  CM_CTL_ENAB      = 1'u32 shl 4
  CM_CTL_SRC_MASK  = 0b1111'u32

#proc readReg(addr: uint32): uint32 =
#  cast[ptr  uint32](addr)[]

#proc writeReg(addr: uint32, value: uint32) =
#  cast[ptr uint32](addr)[] = value

