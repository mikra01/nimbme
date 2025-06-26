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

# BCM2835s system-timer
# timer0 and 2 are VC reserved. 
# also accessing the timer3 regs let my cpu hang up.
# clocked with 1Mhz, so 1 tick is 1us fixed

type 
    TimerReg = uint32
    TimerPtr = ptr array[7,TimerReg]
    
const 
    BasePtr : TimerPtr = cast[TimerPtr](0x20003000)
    TStatus : TimerReg = 0x0
    CounterLow* : TimerReg = 0x1
    CounterHigh* : TImerReg = 0x2
    TCompare0* : TimerReg = 0x3 # reserved for vc
    TCompare1* : TimerReg = 0x4 # working
    TCompare2* : TimerReg = 0x5 # reserved for vc
    TCompare3* : TimerReg = 0x6 # ? not working - arm-core hangup

const
  ENABLE_IRQS_1 = cast[ptr uint](0x2000B210)

template hal_systemtimer_getRegVal*(idx : TimerReg) : uint =
    hal_cpu_getDWord(cast[ptr uint](addr BasePtr[idx]))

template hal_systemtimer_setRegVal(idx : TimerReg, val : uint) =
    hal_cpu_storeDword(cast[ptr uint](addr BasePtr[idx]) ,val)

template hal_systemtimer_getTStamp32*() : Micros32 =
    cast[Micros32](hal_systemtimer_getRegVal(CounterLow))

proc hal_systemtimer_getTStamp64*(): Micros64 =
  var hi1, lo, hi2: uint32
  for i in 0..2:
    hi1 = hal_systemtimer_getRegVal(CounterHigh)
    lo  = hal_systemtimer_getRegVal(CounterLow)
    hi2 = hal_systemtimer_getRegVal(CounterHigh)
    if hi1 == hi2: break
  return cast[Micros64](( cast[uint64](hi1) shl 32) or cast[uint64](lo))


#const
#  ENABLE_IRQS_1 = cast[ptr uint](0x2000B210) # basic irq reg 
  
template hal_systemtimer_1_enableIRQ =
   hal_cpu_storeDword(ENABLE_IRQS_1,2)  # Bit 1 = Timer Compare 1

template hal_systemtimer_1_clearIRQ =  
  hal_systemtimer_setRegVal(TStatus,2) # write2clear reg

template hal_systemtimer_1_Fired(pendingVal : uint32) : bool = 
 ( pendingVal and 2.uint ) != 0 #  pending1 (bit 0-3 timer)

template hal_systemtimer_1_setCompareVal(offset : Micros32) =
  hal_systemtimer_setRegVal(TCompare1, cast[uint](hal_systemtimer_getTStamp32()) + cast[uint](offset)) # each us / minval: 2

template hal_systemtimer_1_init = 
  hal_systemtimer_1_setCompareVal(boardcfg_systemtimerTimerResolution_millis)  # irq each ms
  hal_systemtimer_1_clearIRQ()
  hal_systemtimer_1_enableIRQ()
  