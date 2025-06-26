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

# arm performance monitor helper
#ID	Event Type
#0x03	L1 Data Cache Miss
#0x04	L1 Instruction Cache Miss
#0x07	Instruction Executed
#0x0C	Data Read
#0x0D	Data Write
#0x0E	Cache Access
#0x0F	Cache Miss
#0x10	Branch Executed
#0x12	Branch Mispredicted

# counter1/2/3

type
    IRQCycleStats* = object
      cummulatedCyclesSinceStartup* : uint64         
      cyclesLastRun* : uint32   
      executionCountSinceStartup* : uint64

var irqCycleStats* : IRQCycleStats