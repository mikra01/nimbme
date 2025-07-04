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

# intention of the nim-runtime:
# experimental embedded playground
# lean api - no os-vendor API´s - just Nim
# cooperative tasking -> no need for reentrant newlib 
# focus on low-energy support with hard-rt-requirements 
# one instance for each cpu
# easy portable (minimum asm-footprint)
# hardware-requirements: 
# - free running counter (could be emulated)
# - cpu softirq mechanism
# - at least one UART without flow control
# - at least 10KB ram (os:any)
# - around 20Kib flash ( depends which parts of stdlib you are using / for instance Date and friends are consuming > 20KiB! )

# root hal api
import system/platforms
import std/[volatile,strutils,macros]

import ../../envconfig

import cpu/armcpustate
export armcpustate

import ../../core/utils/CharBuffer

import ../../core/[envtypes, stdtypes,hwdevice,perfstats]
export stdtypes,envtypes

const board* {.define.}: string = "raspberry_pi1" # default
const cpuArch* {.define.}: string = "armv6" # default
const runtimeVersion* {.define.} : string = "0.00"

const ENV_DWORD_SIZE = cast[uint](sizeof(uint))

macro makeIncludeStrLit(
  arg: static[string]): untyped =
  newTree(nnkIncludeStmt, newLit(arg) )

proc newlibPrintSysvals*()

proc hal_uart_0_strout_blocking*(p1 : cstring,size : int){.inline.}
proc hal_uart_0_putc_blocking*(c1 : char){.inline.}
proc hal_uart_0_getc_blocking*() : char {.inline.}
# blocking variants for debug purpose (usage inside interrupt/exception/ possible)

include generic/consts
include generic/charutils
include ../utils/ptrutils
include generic/debugutil

 
makeIncludeStrLit("board/" & board & "/boardcfg")
makeIncludeStrLit("/cpu/" & cpuArch & "/cpu" )

when board == "raspberry_pi1":
  var hal_coreFrequency* : uint
  var hal_armtimerTickResolutionNanos* : uint
  makeIncludeStrLit("board/" & board & "/armcc")
  makeIncludeStrLit("board/" & board & "/gpioaux")
  makeIncludeStrLit("board/" & board & "/armnanotimer")
  makeIncludeStrLit("board/" & board & "/clocksrc")
  makeIncludeStrLit("board/" & board & "/miniuart") 
  makeIncludeStrLit("board/" & board & "/mbox0propertyChan8")
  makeIncludeStrLit("board/" & board & "/systemtimer")

makeIncludeStrLit("board/" & board & "/timer")
makeIncludeStrLit("board/" & board & "/uart")
makeIncludeStrLit("board/" & board & "/rtc")
makeIncludeStrLit("board/" & board & "/irq_handler")

  
proc IRQStackLoc(){.importc:"_irq_stack", cdecl.}
proc SupVStackLoc(){.importc:"_supv_stack", cdecl.}
proc SysStackLoc*(){.importc:"_sys_stack", cdecl.}  # rename: _sys_stack_top

proc IRQStackSize(){.importc:"IRQ_STACK_SIZE", cdecl.}
proc SupVStackSize(){.importc:"SUPV_STACK_SIZE", cdecl.}
proc SysStackSize(){.importc:"SYS_STACK_SIZE", cdecl.}

proc IRQSentinelOffset(){.importc:"IRQ_SENTINEL_OFFSET",cdecl.}
proc SupVSentinelOffset(){.importc:"SUPV_SENTINEL_OFFSET",cdecl.}
proc SysSentinelOffset(){.importc:"SYS_SENTINEL_OFFSET",cdecl.}

{.emit: """ 
   extern int _end , _stack_bottom, _stack_top, _heap_end;                                                                      	         
""".}  

let initialFreememPtr* {.importc:"_end", used, nodecl.}: uint   
let freememEndPtr*{.importc:"_heap_end",used, nodecl.} : uint
let initialStackPtr* {.importc:"_stack_bottom", used, nodecl.} : uint  
let stackTopPtr*{.importc:"_stack_top",used,nodecl.} : uint

include generic/bootup
include generic/stdlibwrapper 


template isSysStackInRange*(stackPtr : uint) : bool =
  let max = cast[uint](SysStackLoc)
  let min = cast[uint](SysStackLoc) - cast[uint](SysStackSize)
  max >= stackPtr and min <= stackPtr
  
template calcSentinelLoc(location: proc, size : proc, offset : proc) : ptr uint =
  cast[ptr uint](cast[uint](location) - cast[uint](size) + ( cast[uint](offset)))

template isStackSentinelTampered(location : proc, size: proc, offset : proc) : bool = 
  (cast[ptr uint](calcSentinelLoc(location,size,offset)))[] != GlobalStackSentinelVal

template isIRQStackSentinelTampered*() : bool  =
  isStackSentinelTampered(IRQStackLoc,IRQStackSize,IRQSentinelOffset)

template isSysStackSentinelTampered*() : bool =
  isStackSentinelTampered(SysStackLoc,SysStackSize,SysSentinelOffset)

template isSupvStackSentinelTampered*() : bool =
  isStackSentinelTampered(SupvStackLoc,SupvStackSize,SupVSentinelOffset)

template setupStackSentinel() = 
  calcSentinelLoc(IRQStackLoc,IRQStackSize,IRQSentinelOffset)[] = GlobalStackSentinelVal
  calcSentinelLoc(SupVStackLoc,SupVStackSize,SysSentinelOffset)[] = GlobalStackSentinelVal
  calcSentinelLoc(SysStackLoc,SysStackSize,SupVSentinelOffset)[] = GlobalStackSentinelVal


proc globalRaiseHookExHandler(e : ref Exception ) : bool {.gcsafe.} = 
  let pid = getActivePID()
  hal_uart_0_strout_blocking "global_ex_hook_triggered ",25
  if not isSys(pid):
    environmentContext[pid].runtimeFault =  (error : e.msg, unused : 0)
    setFaulted(getActivePID())
    switchCTXTo(cast[ProcessID](PID_SYS)) 
    # switchContext(cast[StackPointer](addr environmentContext.processes[pid].stackPtr),cast[int](environmentContext.sysSP))
  else:
    let msglen = e.msg.len
    hal_uart_0_strout_blocking e.msg,msglen
    hal_uart_0_strout_blocking "   ",3
    let stracelen = e.getStackTrace.len    
    hal_uart_0_strout_blocking e.getStackTrace(),stracelen
  false

proc localExHook(e: ref Exception) : bool =
  hal_uart_0_strout_blocking "local_ex_hook_triggered",23 
  false # do not propagate further

proc unhandledExceptionHandler(errorMsg: string){.gcsafe.} =
  let pid = getActivePID()
  if not isSys(pid):
    hal_uart_0_strout_blocking "uh_exhook_triggered_nosys",24
    environmentContext[pid].runtimeFault =  (error : errorMsg, unused : 0)
    setFaulted(getActivePID())
    switchCTXTo(cast[ProcessID](PID_SYS)) 
    # switchContext(cast[StackPointer](addr environmentContext[pid].stackPtr),cast[int](environmentContext.sysSP))
  else:
    hal_uart_0_strout_blocking "uh_ex_triggered",15
    hal_uart_0_strout_blocking errorMsg,errorMsg.len 
    hal_cpu_resetBoard()


proc unhandledExceptionHook(e : ref Exception)  =
  let pid = getActivePID()
  if not isSys(pid):
    hal_uart_0_strout_blocking "uh_exhook_triggered_nosys",24
    environmentContext[pid].runtimeFault =  (error : e.msg, unused : 0)
    setFaulted(getActivePID())
    switchCTXTo(cast[ProcessID](PID_SYS)) 
    # switchContext(cast[StackPointer](addr environmentContext[pid].stackPtr),cast[int](environmentContext.sysSP))
  else:
    hal_uart_0_strout_blocking "uh_exhook_triggered",19 
    hal_uart_0_strout_blocking e.msg,e.msg.len
    hal_cpu_resetBoard()
  
proc outOfMemHook() =
  # todo: check isSysContext and process further
  # FIXME: check lr to get last subr call
  # FIXME: check context. user code? if so we can continue by switching context back to sys
  hal_uart_0_strout_blocking "oom_ex_triggered",16
  hal_cpu_resetBoard()


proc deployExceptionHandlerHooks*() =
  system.globalRaiseHook = globalRaiseHookExHandler
  system.onUnhandledException = unhandledExceptionHandler
  system.outOfMemHook = outOfMemHook
  system.unhandledExceptionHook = unhandledExceptionHook # required by os:any


proc initBoard*(){.importc:"_initialize_custom",cdecl.}

proc enterMemLoader*(){.noreturn.} =
  hal_cpu_doSoftwareIRQ(hal_consts_EnterMemLdr)




proc stdlibwrapper_initialize_board(){.exportc:"_hal_initialize_board",cdecl.}  = 
  setupStackSentinel()
  # called at startup for chip and hw init
  uartInputBuffer.reset()
  uartOutputBuffer.reset()
  timerBuffer.reset()
  disableStdioBuffs()

  when board == "raspberry_pi1":
    # hard read core freq
    if not hal_mbox0propertyChan8_isMboxFull():
      hal_mbox0propertyChan8_sendVCRequest(CoreFrequency)
      for i in 0..100000:
        rCall(i)
      if hal_mbox0propertyChan8_isResponseOK(CoreFrequency):
        (hal_coreFrequency, _ ) = hal_mbox0propertyChan8_getRawValueFor(CoreFrequency)
    # simply assume 250MHz if mailbox-call unsuccessful
    if hal_coreFrequency == 0:
      hal_coreFrequency = 250000000
      # TODO: write audit entry in case of this error  
    hal_mbox0propertyChan8_sendClockSetRequest(CLOCK_ID_UART,config_uartPl11Clock)
    for i in 0..100000:
        rCall(i)

    hal_armtimerTickResolutionNanos = ( 0x3b9aca00.uint div hal_corefrequency ) * 256 # only this divider is supported by bcm2835 
    hal_gpioaux_enableAux()
    hal_uart_0_init(config_uartPl11IBRD,config_uartPl11FBRD) 
    hal_systemtimer_1_init()


    when config_ArmTimerLoadVal > 0:
      hal_armnanotimer_init(config_ArmTimerLoadVal)
    else:
      hal_armnanotimer_disableTimer  
  else:
    hal_uart_0_init()   
    hal_timer_0_init()  
    hal_rtc_initRtc()     
    hal_timer_0_enableIRQ() 


  hal_cpu_enableIRQ()
  initBoard()


