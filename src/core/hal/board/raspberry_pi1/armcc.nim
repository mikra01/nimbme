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

# arm perf cycle counter
{.emit: """
// see arm doc
#define writeCycleCounterReg(v)  asm volatile("mcr p15, 0, %0, c15, c12, 0" :: "r"(v) :) // write
#define readCycleCounterReg(v)  asm volatile("mrc p15, 0, %0, c15, c12, 1" : "=r"(v) : :) // read
""".}

proc hal_armcc_resetCycleCounter*() =
  # activate PMU and reset all counter (bits 0 | 1 | 2)
  # 1 -> enable counter / 4 -> reset cycle counter reg / 8 -> enable divider (64)
  {.emit: "writeCycleCounterReg(1|4);" .}


proc hal_armcc_readCycleCounter*(): uint {.inline.}  =
    {.emit:"""
    __asm__ volatile (
    "mrc p15, 0, %[res], c15, c12, #1 \n"
    : [res] "=r" (`result`)
    : 
    :
    );
  """.}

proc hal_armcc_getCyclesDiff*(prevVal : uint) : uint {.inline.} =
  let curr = hal_armcc_readCycleCounter()
  if curr < prevVal:
    result = (uint32.high - prevVal) + curr
  else:
    result = curr - prevVal


