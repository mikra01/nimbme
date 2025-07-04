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

import std/[strutils,volatile]
import utils/[charbuffer,mempool,timerpool]
import ../envconfig
import stdtypes,event

include hal/generic/consts

var uartInputBuffer* : CharBuffer[UartBufferInCharSize]
var uartOutputBuffer* : CharBuffer[UartBufferOutCharSize]
var fixedStackSpace*{.align(8).} : array[cast[int](UserProcessStackSize_bytes) * (MaxUserProcessCount),byte]

type
  ProcessWrapperHook* = proc(pid : cint, customVal : uint) {.cdecl.} # includes entry and exit
  ProcessHook* =  proc( pid : ProcessID, customVal: uint) : int

  ResourceRequestType* = enum Alloc, RRFree
  ResourceState* = enum Free=0.uint8, Allocated 
  ResourceResultCode* = enum Init= 0.uint8, Error, Valid, Waiting
  
  Resource* = object
    state* : ResourceState
    allocatedPID* : ProcessID    # cleanup
    internalHandle : pointer
    resourcePointer* : pointer

  ResourceID* = int  
  ResourceRequest* = tuple[resourceId: ResourceID, pid : ProcessID, rqtype : ResourceRequestType] 
  ResourceHandle* = tuple[resourcePointer : pointer , rc :ResourceResultCode] 

  DeviceId* = byte
  DeviceType* = enum  USB_dev = 0, USB_host = 1, SPI, I2C, NET, GPIO
  
  DeviceMsg* = object
    testval : int # TODO: define

  DeviceIsrCallback* = proc()
  DeviceServiceCallback* = proc()

  DeviceEntry* = object 
    isrCallback*: DeviceIsrCallback
    serviceCall* : DeviceServiceCallback
    isrService* : bool = false
    ownerPid* : ProcessID
    msgIn* : CBuffer[4,DeviceMsg]
    msgOut* : CBuffer[4,DeviceMsg]
    free*: bool

  RegResult* = tuple[errorCode : int, dId : DeviceId]

  HwDevice*[n : static[int]] = object
    used*  : uint16 = 0
    free*  : uint16 = 0
    devices* : array[n,DeviceEntry]


  ProcStartupParams* = object
    executionHook* : ProcessHook         # the task which is executed
    wrapperHook* : ProcessWrapperHook    # the wrapper which manages execution -> TODO: probe exception catching
    #executionEpilog* : ProcessExitHook   # epilog
    stackBottom* : int
    customValue* : uint
    
  ProcControlBlock* = object  # task control block
    isSys : bool = true
    pId* : ProcessID # processId
    res1 : uint8 # unused
    res2 : uint8 # unused
    faultBuff* : CPUException # TODO: handle dataAbort and determine between aligmentfault, translationfault, permissionfault
    faultType* : CPUFault
    runtimeFault* : RuntimeException
    pState* : PState
    pType* : PType
    pPriority* : PUserPri
    stackPtr* : StackPointer
    memSlot* : MemPoolSlot
    stackSentinelPtr* : ptr uint
    startupParameter* : ProcStartupParams
    waitingEvents* : CBuffer[10,EventMsg]  #TODO: no circular buffer - slotted event store
    #waitingFutures* : CBuffer[10,RFuture]
    waitingOnResource* : bool
    resourceRequestResult* : ResourceHandle
    resultVal* : cint
    cyclesActive* : uint  # experimental: count cycles of proc in running queue
    cyclesTotal : uint64        
    cycles_start : uint32
    cyclesStartup : uint32

  ProcControlBlockDS* = object  # deadline scheduler
    isSys : bool = false
    pId* : ProcessID # processId
    res1 : uint8 # unused
    res2 : uint8 # unused
    faultBuff* : CPUException # TODO: handle dataAbort and determine between aligmentfault, translationfault, permissionfault
    faultType* : CPUFault
    runtimeFault* : RuntimeException
    pState* : PState
    pType* : PType
    stackPtr* : StackPointer
    memSlot* : MemPoolSlot
    stackSentinelPtr* : ptr uint
    startupParameter* : ProcStartupParams
    waitingEvents* : CBuffer[10,EventMsg]  #TODO: no circular buffer - slotted event store
    #waitingFutures* : CBuffer[10,RFuture]
    waitingOnResource* : bool
    resourceRequestResult* : ResourceHandle
    resultVal* : cint
    cyclesActive* : uint  # experimental: count cycles of proc in running queue
    #cyclesTotal : uint64    # accumulated runtime      
    #cyclesStartup : uint64 # val of  PMCCNTR at start
    #cyclesLastDuration : uint32 # last duration
    #cyclesExecEstimate : uint32
    #dlPri : enum
    #cyclesAbsDeadline : uint32   # abs deadline in PMCCNTR-ticks
    # todo: measure worst case runtime of glue-code (with irq_cycles). this is the min abs dl val
    #deadlineMissesCntr : uint32  # debug
 

  ProcControlBlockPtr* = ptr ProcControlBlock  

  SysContext* = object  # newlib and heap is shared between the context
    stackPool* : MemPool 
    sysTimerPool* : TimerPool
    sysSP* : StackPointer
    runningPID : ProcessID
    processes* : array[MaxUserProcessCount,ProcControlBlock]
    running* : CBuffer[MaxUserProcessCount,ProcessID]
    allocatedResources* : array[ResourceCount,Resource]
    resourceContention* : array[ResourceCount,CBuffer[DefaultRuntimeQueueSize,ProcessID]]
    resourceRequestQueue* : CBuffer[DefaultRuntimeQueueSize,ResourceRequest]
    deadlineProcesses* : array[4,ProcControlBlockDS]
    priorizedProcesses* : array[MaxUserProcessCount,ProcControlBlock]
    cyclesSinceStart* : uint64
    cyclesInterrupt* : uint
    registeredDevices* : HwDevice[6]

template `[]`*(ctx: var SysContext, idx: ProcessID): var ProcControlBlock =
  ctx.processes[cast[int](idx)]

template `[]`*(ctx: var SysContext, idx: ResourceID): var Resource =
  ctx.allocatedResources[cast[int](idx)]  

template `[]`*(ctx: var SysContext, idx: DeviceType): var DeviceEntry =
  ctx.registeredDevices.devices[idx.ord]  

const PID_SYS* : ProcessID = 99

proc `$`*(f: var ProcStartupParams): string =
  "startupparams: xhook: " & $toHex(cast[uint](f.executionHook),8) & " wrapper:" & toHex(cast[uint](f.wrapperHook)) &
    "stack_bottom " & toHex(f.stackBottom,8)

template toPID*(pid : int) : ProcessID =
  cast[ProcessID](pid)

template toRID*(resourceId : int) : ResourceID =
  cast[ResourceID](resourceId)  

proc `$`*(f: var ProcControlBlock): string =
  "ProcessControlBlock: pid " & $f.pId 

proc `=copy`(a:var ProcControlBlock, b:ProcControlBlock){.error.}  
proc `=copy`(a:var SysContext, b:SysContext){.error.}
#proc `=destroy`(a:var SysContext) =
#  discard

var nextPID* : ProcessID = 1
var environmentContext*{.exportc.} : SysContext

template getActivePID*() : ProcessID =
  volatileLoad(addr environmentContext.runningPID)

template setActivePID*(val : ProcessID) =
  volatileStore(addr environmentContext.runningPID,val)

proc `$`*(f: var SysContext): string =
  "active pid: " & $getActivePID()    

template isValidPID*(val :  ProcessID) : bool = # deprecate
  val >= 0

proc launchProc(savedSp : StackPointer, newstack : StackPointer){.cdecl,noreturn,importc:"_launchproc_entry"}

proc switchContext(savedSp :StackPointer, newstack : StackPointer){.cdecl,noreturn,importc:"_switch_context"}

template startProcess*(pid : ProcessID) =
  setActivePID(pid)  # TODO: active pid und state running erst im wrapper setzen
  environmentContext[pid].pState = PState.Running
  launchProc(cast[StackPointer](addr environmentContext.sysSP),(environmentContext[pid].stackPtr))
  setActivePID(PID_SYS)
  return 0

template restartProcess*(pid : ProcessID) =
  setActivePID(pid)
  environmentContext[pid].pState = PState.Running
  environmentContext[pid].stackPtr = (initUsrStack(pid,environmentContext.processes[pid].startupParameter))
  launchProc(cast[StackPointer](addr environmentContext.sysSP),(environmentContext.processes[pid].stackPtr)) 
  setActivePID(PID_SYS)
  return 0  

template switchCTXTo*(targetPID : ProcessID) =
  let cpid = getActivePID()
  setActivePID(targetPID)   
  if targetPID == PID_SYS:
    switchContext(cast[StackPointer](addr environmentContext[cpid].stackPtr),(environmentContext.sysSP)) # from usr to sys
  else:
    switchContext(cast[StackPointer](addr environmentContext.sysSP),(environmentContext[targetPID].stackPtr)) # from sys to usr
    setActivePID(PID_SYS)

template isUnused*(p : ProcControlBlock) : bool =
  p.pState == PState.Free

template isSys*(pid : ProcessID) : bool =
  pid == cast[ProcessID](PID_SYS)


var timerBuffer* : CBuffer[TimerTickBufferSize,uint]
# collects the slow timer ticks






