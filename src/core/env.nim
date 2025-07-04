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
import utils/[circularbuffer,memorystream,mempool,timerpool,ptrutils]
import ../envconfig
export envconfig
import ../core/hal/hal
import xresourcelock, perfstats

import stdtypes,event,audittrail,hwdevice

proc initializeEnvironment*() =
  setActivePID(PID_SYS)
  environmentContext.stackPool = newMemPool(MemPoolBufferSize(UserProcessStackSize_bytes),MaxUserProcessCount,cast[pointer](addr fixedStackSpace))

  environmentContext.sysTimerPool.initTimerPool(SoftTimerPool_millis_correctionFactor)
  environmentContext.running.reset()
  environmentContext.resourceRequestQueue.reset()

  # todo: inject watchpoint
  for i in 0..MaxUserProcessCount-1 :
    environmentContext[i.toPID].pState = PState.Free 
   
  for i in 0..environmentContext.allocatedResources.len-1:
    environmentContext.allocatedResources[i].state = ResourceState.Free
    environmentContext.allocatedResources[i].resourcePointer = addr environmentContext # artificial
    environmentContext.resourceContention[i].reset()

   # set default device entries
  hwdevice.initializeHwDevice(addr environmentContext.registeredDevices)

  hal_armcc_resetCycleCounter()  
    
const sentinelWatermark = cast[uint](UserProcessStackSentinelPos * sizeOf(int))

proc isProcessStackSentinelTampered(pid : ProcessID) : bool =
  if pid <= PID_SYS:
    return environmentContext[pid].stackSentinelPtr[] != GlobalStackSentinelVal
  return false

template isValidState*(pid : ProcessID) : bool =
  environmentContext[pid].pState == PState.Running or 
    environmentContext[pid].pState == PState.Waiting or 
      #environmentContext[pid].pState != PState.Faulted 
      environmentContext[pid].pState == PState.Suspended
      
template setFaulted*(pid : ProcessID) =
  if pid <  PID_SYS:
    environmentContext[pid].pState = PState.Faulted  

template setRunning(pid : ProcessID) =
  if isValidState(pid):
    environmentContext[pid].pState = PState.Running

template setWaiting(pid : ProcessID) =
  if isValidState(pid):
    environmentContext[pid].pState = PState.Waiting

template setSuspended(pid : ProcessID) =
  if isValidState(pid):
    environmentContext[pid].pState = PState.Suspended

proc taskLaunchWrapper(pid : cint, customVal: uint) {.cdecl.} =
   let ppid = cast[ProcessId](pid)
   # TODO: start measurement here
   environmentContext[ppid].resultVal = environmentContext[ppid].startupParameter.executionHook(ppid,customVal) 

   # TODO: end measurement here
   if isValidState(ppid):
    echo "collected_cycles: "  
    when CycleCounterPrescalerActive:
      echo  $(environmentContext[ppid].cyclesActive shl 6)
    else:
      echo $(environmentContext[ppid].cyclesActive)
   
    echo "proc about to exit. stack_exceeded: " & $isProcessStackSentinelTampered(ppid)
    environmentContext[ppid].cyclesActive = 0
    environmentContext[ppid].pState = PState.Suspended
 
   switchCtxTo(PID_SYS)

proc initUsrStack(initialPid : ProcessID,params : ProcStartupParams) : StackPointer =
    let sentinelp = cast[ptr uint]( cast[uint](params.stackBottom) + sentinelWatermark)
    environmentContext[initialPid].stackSentinelPtr = sentinelp
    sentinelp[] = GlobalStackSentinelVal
    let stackTop : uint = (cast[uint](params.stackBottom)+UserProcessStackSize_bytes)
    let regstart : StackPointer = cast[StackPointer](stacktop - ArmCpuStateFastLoadSize)
    let stateptr = cast[ptr ArmCpuStateFastLoad](regstart)
    stateptr.pc = cast[uint](params.wrapperHook)    
    stateptr.r[0] = cast[uint](initialPid) # r0
    stateptr.r[1] = params.customValue
    return regstart

#template getSoftTickBase*() : culong = 
#  volatileLoad(addr halapi_sys_microsec_timerticks)

template collectCycles(pid : ProcessID, body : untyped) =
  let cystart = hal_armcc_readCycleCounter()
  body
  environmentContext[pid].cyclesActive.inc(hal_armcc_getCyclesDiff(cystart)) 


proc executeProcess(pid : ProcessID) : int {.inline.} =
    # TODO: eval result handling
  result = -1  
  if getActivePID() >= PID_SYS:  
    if environmentContext[pid].isUnused:
      logEnvAuditTrail(AUditSrc.Runtime,ErrorKind.Error,0) # err1_proc_unable_to_execute
      return -1
    elif environmentContext[pid].pState == PState.Created:
      collectCycles(pid):
        startProcess(pid)
    elif environmentContext[pid].pState == PState.Suspended and environmentContext[pid].pType == PType.Restartable:
      collectCycles(pid):
        restartProcess(pid)
    else:
      if not environmentContext[pid].waitingEvents.hasVal() and 
        isValidState(pid):  
          environmentContext[pid].pState = PState.Running
          collectCycles(pid):
            switchCtxTO(pid)
          return 0
      else:
         if UserDebugEchoPID:
            echo "unable to restart process in faulted state: " & $environmentContext[pid].runtimeFault
         return -1 
  return result

proc initStartupParamAndStack( pId : ProcessID,bufferHdl : MemPoolBufferHandle,  entryHook : ProcessHook, customVal : uint) =
  environmentContext[pId].memSlot = bufferHdl.slotIdOrErrno
  environmentContext[pId].pState = PState.Created
  environmentContext[pid].pType = PType.Restartable # default
  environmentContext[pId].startupParameter.stackBottom =cast[int](bufferHdl.pooledBufferPtr) # fix: 2tuple
  environmentContext[pId].startupParameter.wrapperHook = taskLaunchWrapper
  environmentContext[pId].startupParameter.executionHook = entryHook
  environmentContext[pId].startupParameter.customValue = customVal
  environmentContext[pid].stackPtr = initUsrStack(pid,environmentContext[pId].startupParameter)
  environmentContext[pid].cyclesActive = 0
 
proc killProcess(pId : ProcessID) =
  if pId.isValidPID:
    environmentContext[pId].pState = PState.Free
    environmentContext.stackPool.releaseBuffer(environmentContext[pId].memSlot)
  else:
   logEnvAuditTrail(AUditSrc.Runtime,ErrorKind.Error,3) #  err4_proc_invalid_id

proc newPID() : ProcessId =
  result = -1
  for i in 0..MaxUserProcessCount-1:
    if environmentContext[i.toPID].isUnused:
      result = cast[int16](i)  
      break
  if result == -1:
    logEnvAuditTrail(AUditSrc.Runtime,ErrorKind.Error,1) # err2_proc_all_slots_occupied
  return result

proc createProcess(tmpProcEntryHook : ProcessHook) : ProcessId =
  # find empty slot
  result = newPID()

  if result.isValidPID:
    let bufferHandle = environmentContext.stackPool.requestBuffer()
    if bufferHandle.isValid:
      initStartupParamAndStack(result,bufferHandle,tmpProcEntryHook,12345)
    else:
       logEnvAuditTrail(AUditSrc.Runtime,ErrorKind.Error,2) # err3_proc_stackpool_outOfSlots   
  else:
    logEnvAuditTrail(AUditSrc.Runtime,ErrorKind.Error,3) #  err4_proc_invalid_id
    return -1


proc oneShotTimedWaitProcessCallback(tp : var TimerPool, timerNum : int){.cdecl.} =
  let processid = cast[ProcessID](tp.getUdVal(timerNum)) # instable API
  tp.deallocTimer(timerNum)
  discard environmentContext[processid].waitingEvents.fetchVal()
  setRunning processid

proc waitAndResume*(durationMillisec : uint){.cdecl,exportc.} =
  let pid = getActivePID()
  let t1 = environmentContext.sysTimerPool.allocTimer(oneShotTimedWaitProcessCallback,cast[uint](pid))
  environmentContext.sysTimerPool.setAlarmMillis(t1,durationMillisec) # ms
  environmentContext[pid].waitingEvents.putVal((TIMER_WAIT,t1))
  # TODO: implement generic future callback
  setWaiting(pid)
  # TODO: impl cycle measurement start
  switchCtxTo PID_SYS

proc resume*(){.cdecl,exportc.} =
  if not isSys(getActivePID()):
    switchCtxTo PID_SYS

proc processDevices(){.inline.} =
  for i in DeviceType:
    if not environmentContext[i].free:
      # TODO: check context and switch if needed
      environmentContext[i].serviceCall()


proc processXLockRequests(){.inline.} =
# TODO: impl bankers algorythm or something suitable if needed
    # process resource requests: dealloc
    var rrequestcount = 0
    if environmentContext.resourceRequestQueue.hasVal():
      rrequestcount = environmentContext.resourceRequestQueue.getItemCount()
      for i in 0..rrequestcount-1:
        let rq = environmentContext.resourceRequestQueue.fetchVal()
        if rq.isFreeRequest:
          dec rrequestCount
          environmentContext[rq.resourceId].state = ResourceState.Free  
        else:
          environmentContext.resourceRequestQueue.putVal(rq)
      
    # process resource contention queue: preAlloc
    # todo: incr waiting count for these items
    for i in 0..environmentContext.resourceContention.len-1:
      if environmentContext[i.toRID].state == ResourceState.Free:
        if environmentContext.resourceContention[i].hasVal():
          let procId : ProcessID = environmentContext.resourceContention[i].fetchVal()
          environmentContext[i.toRID].state = ResourceState.Allocated
          environmentContext[procId].resourceRequestResult = 
            (resourcePointer:environmentContext[i.toRID].resourcePointer,rc : ResourceResultCode.Valid )
          # todo: gather stats   
           

    # process resource request: alloc if resources free
    if rrequestCount > 0:
      # if resource free: process alloc - else: put waiter into contention queue
       for i in 0..rrequestCount-1:
         let rq : ResourceRequest = environmentContext.resourceRequestQueue.fetchVal()
         if not rq.isFreeRequest:
           if environmentContext[rq.resourceId].state == ResourceState.Free:
             environmentContext[rq.resourceId].state = ResourceState.Allocated
             environmentContext[rq.resourceId].allocatedPID = rq.pid
             environmentContext[rq.pid].resourceRequestResult = 
              (resourcePointer:environmentContext[rq.resourceId].resourcePointer,rc : ResourceResultCode.Valid )    
           else:
             environmentContext.resourceContention[rq.resourceId].putVal(rq.pid)
         else:
           discard # todo: dealloc - log possible rt-error (alloc in interrupt called)


proc runtimeDispatcherDemoWithExit*(exitChar : char, usrProc : ProcessHook)=
  var c : char = '.'
  var createdPid : seq[ProcessId]

  var absCycles : uint
  var cyclesCurr = hal_armcc_readCycleCounter()

  while true:    
    # read cycle counter
  

    if uartOutputBuffer.hasVal(): # flush buffer blocking variant
       let x = uartOutputBuffer.fetchVal()
       hal_uart_0_putc_blocking(x)

    processXLockRequests()
    processMboxRequests() 
    processDevices()    

    
    # non-priority basic round robin scheduling
    environmentContext.running.reset()

    for i in 0..MaxUserProcessCount-1:
      if environmentContext[i.toPID].pState == PState.Running:
        # todo: crosscheck for waiting resources
        environmentContext.running.putVal(i.toPID)

    absCycles.inc(hal_armcc_getCyclesDiff(cyclesCurr)) # snapshot

    while environmentContext.running.hasVal():
      absCycles.inc(hal_armcc_getCyclesDiff(cyclesCurr))
      discard executeProcess(environmentContext.running.fetchVal())
      cyclesCurr = hal_armcc_readCycleCounter()
              
    cyclesCurr = hal_armcc_readCycleCounter()

    if timerBuffer.hasVal():
      environmentContext.sysTimerPool.periodicTimebasedWorkLoop(cast[uint](timerBuffer.fetchVal()))
   
      if uartOutputBuffer.hasVal(): 
        hal_uart_0_startTx()    

      if uartInputBuffer.hasVal():
        c = uartInputBuffer.skipAndfetchLastVal().lastVal # peekValWritePos() 
        
        if c == exitChar:
          for i in 0..createdPid.len-1:
            echo "killing p with id: " & $createdPid[i]
            killProcess(createdPid[i])

          absCycles.inc(hal_armcc_getCyclesDiff(cyclesCurr))  # snapshot
          break

        if c == 'P':
          let p = createProcess(usrProc)
          if p.isValidPID:
            createdPid.add(p)
            echo "new process created. " & $createdPid
            echo "press " & $createdPid & " to run. " & exitChar & " to exit demo. "
          else:
            echo "unable to create new process"
        elif c == 'T':
            echo $environmentContext.sysTimerPool
        else:  
          hal_uart_0_putc_blocking(c)    
       
        if c.isDigit():
          let cnum : ProcessID = (cast[int](c)-0x30).toPID
          if createdPid.contains(cnum):
            if environmentContext[cnum].pState != PState.Running and
              environmentContext[cnum].pState != PState.Waiting:
              absCycles.inc(hal_armcc_getCyclesDiff(cyclesCurr))  # snapshot
              discard executeProcess(cnum)
              cyclesCurr = hal_armcc_readCycleCounter()

  # TODO: relate the irq-cycles to a specific process
  echo "cycles_total_running " &  $absCycles
  echo "cycles _ interrupt " & $irqCycleStats
  for i in 0..environmentContext.processes.len-1:
    if environmentContext.processes[i].cyclesActive > 0:
      echo "pid " & $i & " cyclesActive " & $environmentContext.processes[i].cyclesActive
         
 

