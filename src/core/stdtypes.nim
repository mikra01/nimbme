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

type
  Micros32* = uint
  Micros64* = uint64
  #IdleCallback* = proc (a: cint) {.cdecl.} # should be allowed to be used by the app
  ProcessID* = int16
  DeadlinedProcessID* = int16
  PState*  = enum Free = 0, Created = 1, Running = 2, Waiting = 3, Suspended = 4, Killed = 5, Faulted = 6
  PType* = enum OneShot = 1, Restartable = 2 # Restartable: default
  PUserPri* = enum Low = 0, Medium, High   # check if deprecated
  
  CPUFault* = enum cpuDataAbort= 0, cpuPrefetchAbort, cpuAlignmentFault, cpuUndefined
  
  CPUException* = tuple[faultType: CPUFault, eaddr : ptr uint, opcode : uint,dfsrCode:byte] # errored address and opcode

  RuntimeException* = tuple[error : string, unused : int]
  MemChunk* = tuple[memloc : pointer, size : int]
  
  MessageCommand* = enum WaitTillResume=0.byte,SpawnProc,KillProc,RouteMessage
  RuntimeMessage* = tuple[piD:ProcessID,cmd:MessageCommand,unused:uint16,payload:uint]
  StackPointer* = ptr uint