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
# sram impl
# wip
{.emit: """ 
  extern int _nvram_start,_nvram_end;
""".}  

proc nvRamLowWatermark* {.importc:"_nvram_start", nodecl.}
proc nvRamHighWatermark*{.importc:"_nvram_end",nodecl.}
let nvRamSize* : uint =  cast[uint](nvRamHighWatermark) - cast[uint](nvRamLowWatermark )

proc needInit*() : bool =
  # true if checksum not present    
  false

proc chksumValid() : bool = 
    true

proc initChkSum*()  =
    discard
