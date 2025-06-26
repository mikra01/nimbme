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
# wip
import ../runtimeconfig
import envtypes
import ../utils/charbuffer

type

  CmdType* = enum RequestResource = 1.uint8

  ResourceType* = enum ConsoleInputStream = 1.uint8   
 
  RuntimeCmd* = tuple[evt : CmdType, resourceType : ResourceType, pid : ProcessID, dest: ptr CharBuffer ]

var globalRuntimeCmdQueue* : CBuffer[DefaultRuntimeQueueSize,RuntimeCmd]

