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

# unfortunately arm free running counter not implemented - see BCM2835 "datasheet"
type 
    TimerRegNano = uint32
    TimerPtrNano = ptr array[7,TimerRegNano]
    TimerPrescalerNano = enum P1 = 0, P16 = 1, P256 = 2  # only P256 working
const 
    BasePtrNano : TimerPtrNano = cast[TimerPtrNano](0x2000B400)
    TimerLoadNano : TimerRegNano = 0x0
    TimerValNano : TimerRegNano = 0x1
    TimerCtrlNano : TImerRegNano = 0x2
    TimerIRQClrNano : TimerRegNano = 0x3

const
  ENABLE_BASIC = cast[ptr uint](0x2000B218) # basic irq reg 
  
template hal_armnanotimer_enableIRQ =
   hal_cpu_storeDword(ENABLE_BASIC,1)  

template hal_armnanotimer_getRegVal(idx : TimerRegnano) : uint =
    hal_cpu_getDWord(cast[ptr uint](addr BasePtrNano[idx]))


template hal_armnanotimer_setRegVal(idx : TimerRegnano, val : uint) =
    hal_cpu_storeDword(cast[ptr uint](addr BasePtrNano[idx]) ,val) 

template hal_armnanotimer_hasFired(pendingVal : uint32) : bool =
 ( pendingVal and 1.uint ) != 0 

template hal_armnanotimer_getCounter*() : uint =
  hal_armnanotimer_getRegVal(TimerValNano)

template hal_armnanotimer_setPrescaler(pval : TimerPrescalerNano) =
  let mask : uint = not (0b11 shl 1).uint
  hal_armnanotimer_setRegVal(TimerCtrlNano,(hal_armnanotimer_getRegVal(TimerCtrlNano) and mask) or (pval shl 2))

template hal_armnanotimer_setCompareVal(comp : uint) =
  # directly linked to the VC-clock - see `hal_armtimerTickNanos` for minimal value
  hal_armnanotimer_setRegVal(TimerLoadNano,comp)

template hal_armnanotimer_initTimerAndEnableIrq() = 
   hal_armnanotimer_setRegVal(TimerCtrlNano,hal_armnanotimer_getRegVal(TimerCtrlNano) or ((1 shl 7) or (1 shl 5) or 1 ))
   hal_armnanotimer_setRegVal(TimerCtrlNano,hal_armnanotimer_getRegVal(TimerCtrlNano) and ( not (1 shl 3).uint))
   # hal_armnanotimer_setRegVal(TimerCtrlNano,hal_armnanotimer_getRegVal(TimerCtrlNano) or ( (1 shl 6).uint)) ## freerunning not working

template hal_armnanotimer_disableTimer() = 
     hal_armnanotimer_setRegVal(TimerCtrlNano,hal_armnanotimer_getRegVal(TimerCtrlNano) and (not((1 shl 7).uint or (1 shl 5).uint) ))

template hal_armnanotimer_clearIRQ*() =
  hal_armnanotimer_setRegVal(TimerIRQClrNano,0.uint)

template hal_armnanotimer_init(cval : uint) = 
  hal_armnanotimer_setCompareVal(cval)
  hal_armnanotimer_setPrescaler(P256) # 2Mhz at 500Mhz src clock gives 500ns min resolution / prescaler 1/16 not possible
  hal_armnanotimer_clearIRQ()
  hal_armnanotimer_initTimerAndEnableIRQ()
  hal_armnanotimer_enableIRQ()
  