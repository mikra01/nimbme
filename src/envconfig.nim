
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
# TODO: move envconfig into hal folder
const InputMsgBufferElemSize* : int = 20
const OutputMsgBufferElemSize* : int = 20
const UartBufferInCharSize* : int = 5 * 10
const UartBufferOutCharSize* : int = 80 * 80 # 80 chars per 80 lines - buffer should be big enough for all chars needed to send
const DiagBufferOutElemSize* : int = 20 # diagnostics buffer element size

const GlobalStackSentinelVal* = 0xCFFFEEBA.uint   # depends on arch reg width
# for stackpointer alignment see
# https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/using-the-stack-in-aarch32-and-aarch64
const UserProcessStackSize_bytes* : uint = 1024 #  # valid vals are: 256,512,1024(minimum if d:danger is omitted),2048,4096,8192,16348
const UserProcessEventSlots* : int = 5  # num of events a process can wait for simultaneously
const UserProcessStackSentinelPos* : int = 5 # number dwords from stack bottom
const UserDebugEchoPID* : bool = true
const MaxUserProcessCount* : int = 10
const DefaultRuntimeQueueSize* : int = 12   
const AuditTrailEntrySize* : int = 16 # size of the audit trail log
const SoftTimerPoolSize* : int = 40 # if set to 0 timerpool is disabled
const SoftTimerPool_millis_correctionFactor* : uint = 1000  # inc is each us with systemtimer
const TimerTickBufferSize* : int = 4
const config_ArmTimerLoadVal* : uint = 0 # gives 500ns rate at 2Mhz - 0 disables it
const SysUARTNum* : int = 0
const ResourceCount* : int = 2
const CycleCounterPrescalerActive* : bool = false # 64
const config_uartXon* : char = 17.char
const config_uartXoff* : char = 19.char
const config_uartBaudRate* : uint = 3000000
const uartUseBufferedOut* : bool = false # set UartBufferOutCharSize = 1 if this flag is: false
const uartOutBuffer_flush_blocking* : bool = true # only sync out supported for now  
const uartUseBufferedRxIRQ* : bool = true # buffered receive with IRQ, this is the only supported variant at the moment 
const uartEchoOnInput* : bool = true
const config_consoleNewlineChar* : char = '\n'
const enableMMU* : bool = false # true is wip
# const usr_watchdog_period_ms* : int = 100 # watchdog fires if user-code takes longer than 100ms


