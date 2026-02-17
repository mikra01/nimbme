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
# utilities regarding cpu / arm-m0plus
# MSP is only used in handler-mode / PSP is used for the entire kernel

import ../../../../../core/utils/ptrutils

type 
  HWREVISION_CODE = uint16
 
# model to code mapping
# B rev1 256mb 0002
# B rev1 256mb 0003 # ECN0001 (no fuses, d14 removed)
# B rev2 256mb 0004/0005/0006
# A      256mb 0007/0008/0009
# B rev2 512mb 000d/000e/000f
# uart is pin8&10(gpio14/15) regardles of model/rev

template hal_cpu_doSoftwareIRQ*(trapNum : static cint) = 
  {.emit: """ 				
      #define doSoftwareIRQ(trapNum) asm  ( "svc %0"  : : "I" (trapNum) );
       // 0 to 224–1 (a 24-bit value) in an ARM instruction.
       // further reading (svc with register does not work for older cores)
       // https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/calling-swis-from-an-application?lang=en
  """.} # quirky but svc <number> is a literal - reg is not supported in armv4/5/6
  {.emit: ["doSoftwareIRQ(",astToStr(trapNum), ");"].}

proc hal_cpu_readPC*() : ptr uint {.inline.} = 
  asm """
       mov %0,pc 
       : "=r"(`result`)
       :
       : """  

proc hal_cpu_readSP*() : ptr uint {.inline.} =
# get the current SP value (the full memory loc)   
 asm """
    mov %0,SP
    : "=r"(`result`)
    :
    : 
    """

proc hal_cpu_disableIRQ*() {.inline.} = 
 asm """
    cpsid i       
    : 
    :
    : 
    """     

proc hal_cpu_enableIRQ*() {.inline.} =   
 asm """
    cpsie i
    : 
    :
    :  
    """     

proc hal_cpu_irqDisabledCall*(callee : proc() {.cdecl,inline.}){.inline.} =
  # experimental
  asm """
    cpsid i
    : 
    :
    : 
    """     
  callee()
  asm """
    cpsie i
    : 
    :
    :  
    """    

proc hal_cpu_enableAligmentFault*()=
  discard

proc xhal_cpu_initMMU*(){.cdecl,exportc:"xhal_cpu_initMMU".}=
  discard
 
proc hal_cpu_undef_instruction*(){.cdecl,inline.} =
  discard

proc hal_cpu_bad_jump*()=
   discard

# TODO: move to board specific section and implement  
proc hal_cpu_resetBoard*(){.cdecl,noreturn,inline.}=
  discard
  # hal_cpu_doSoftwareIRQ(hal_consts_EnterMemLdr) 

# TODO: move to board specific section and implement
proc hal_cpu_rBoard(){.cdecl, used, noreturn, exportc:"_reset_board".}=
  discard
  #hal_cpu_doSoftwareIRQ(hal_consts_EnterMemLdr)


# TODO: implement dumping regs with lr,pc at once
proc hal_cpu_saveAllRegisters*(ptr_dest : ptr array[13,uint]){.inline.} = 
  asm """
    stmia %[dst], {r0-r12}
    :
    : [dst] "r" (`ptr_dest`)
    : "memory"
  """  

proc hal_cpu_saveSP*(rd : ptr ArmCpuState){.inline.} =
    let rrd = addr rd.sp
    asm """
      str sp, [%[ptr], #0]
      :
      : [ptr] "r" (`rrd`)
      : 
    """
proc hal_cpu_saveLR*(rd : ptr ArmCpuState){.inline.} =
    let rrd = addr rd.lr
    asm """
      str lr, [%[ptr], #0]
      :
      : [ptr] "r" (`rrd`)
      : 
    """
proc hal_cpu_saveCPSR*(rd : ptr ArmCpuState){.inline.} =
    # not present 
    discard



proc hal_cpu_getDWord*(memptr: ptr uint) : uint {.inline.}  =
  {.emit:"""
    __asm__ volatile (
    "ldr %[res], [%[addr]]\n"
    : [res] "=r" (`result`)
    : [addr] "r" (`memptr`)
    :
    );
  """.}

proc hal_cpu_storeDWord*(memptr: ptr uint, val : uint){.inline.}  =
  {.emit:"""
    __asm__ volatile (
    "str %[val], [%[addr]]\n"
    :
    : [addr] "r" (`memptr`), [val] "r" (`val`)
    :
    );
  """.}

proc readControlRegister*(): uint8 {.inline.} =
  asm """
    mrs %[res], control  
  : [res] "=r"(`result`)
  :
  :  
  """

proc writeControlRegister*(val: uint8) {.inline.} =
  asm """
    msr control, %[val]
  : 
  : [val] "r"(val)
  :
  """ 