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

import strutils
import ../../../envconfig
type
  ArmCpuState* {.exportc, packed.}  = object
   r*: array[13, uint]  
   pc*: uint # r15
   lr*: uint # r14
   sp*: uint # r13
   cpsr*: uint # used to load spsr (feature not implemented)

type
  ArmCpuStateFastLoad* {.exportc, packed.}  = object
   r*: array[2, uint]  
   pc*: uint # r15

proc `=copy`(a:var ArmCpuState, b:ArmCpuState){.error.}  

const ArmCpuStateSize* : uint = cast[uint](sizeOf(ArmCpuState))
const ArmCpuStateSize_no_cpsr* : uint = cast[uint](sizeOf(ArmCpuState)-4)
const ArmCpuStateFastLoadSize* : uint = cast[uint](sizeOf(ArmCpuStateFastLoad))

proc `$`*(f: ptr ArmCpuState): string =
  var buf = newSeqOfCap[string]( (ArmCpuStateSize shl 3) + 80)
  buf.add("HALRegisterDump: ") # cpsr: " & toHex(f.cpsr,8))
  buf.add(config_consoleNewlineChar & "")
  buf.add(" sp: ")
  buf.add(toHex(f.sp,8))
  buf.add(config_consoleNewlineChar & "")
  buf.add(" lr: ")
  buf.add(toHex(f.lr,8))
  buf.add(config_consoleNewlineChar & "")
  for i in low(f.r) .. high(f.r):
    buf.add(" R")
    buf.add($i)
    buf.add(" : 0x")
    buf.add(toHex(f.r[i],8))
    buf.add(config_consoleNewlineChar & "")
  
  return buf.join