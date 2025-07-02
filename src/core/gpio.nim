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

import ../core/hal/hal
import event

type
  IOType*  = enum Input, Output
  Behaviour* = enum Normal, TriState, Async
  EdgeDetect* = enum Rising, Falling
  LevelDetect* = enum High, Low

  GpioState* {. requiresInit.}  = object
    ioType : IOType
    behaviour : Behaviour
    edgeDetect : EdgeDetect
    levelDetect : LevelDetect
    allocatedPID* : ProcessID    # cleanup
    callback : EventCallback
    val : uint


#proc newGpioState*(num : uint, cb : EventCallback ) :  GpioState =
#    return GpioState(ioType : Input,behaviour : Normal, edgeDetect : Rising, levelDetect : High, allocatedPID: 99.toPID, callback: cb, val : num)