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

proc hal_util_vcResponsetoMacAddr(tuple[m1 : uint32, m2: uint32]) : array[6,byte] =
    # network byte order to local byte order
    var buff : array[6,byte]
    buff[0] = cast[byte](m1)
    buff[1] = cast[byte]((m1 shr 8))
    buff[2] = cast[byte]((m1 shr 16))
    buff[3] = cast[byte]((m1 shr 24))
    buff[4] = cast[byte]((m2))
    buff[5] = cast[byte]((m2 shr 8))
    
