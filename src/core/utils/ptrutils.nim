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

# ptrutil template taken from https://forum.nim-lang.org/t/1188
template usePtr*[T](body : untyped) =
  template `+`(p: ptr T, off: SomeInteger): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) +% int(off) * sizeof(p[]))
        
  template `+=`(p: ptr T, off: SomeInteger) =
    p = p + off
        
  template `-`(p: ptr T, off: SomeInteger): ptr T =
    cast[ptr type(p[])](cast[ByteAddress](p) -% int(off) * sizeof(p[]))
        
  template `-=`(p: ptr T, off: SomeInteger) =
    p = p - int(off)
        
  template `[]`(p: ptr T, off: SomeInteger): T =
    (p + int(off))[]
        
  template `[]=`(p: ptr T, off: SomeInteger, val: T) =
    (p + off)[] = val

  body   