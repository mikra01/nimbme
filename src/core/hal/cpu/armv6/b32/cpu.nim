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

# utilities regarding cpu / arm1176JZF-S
# we do not utilize the secondary interrupt controller - only the global irq handler (addr 0x18) is used 

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

proc hal_cpu_readPC*() : uint {.inline.} = 
  asm """
       mov %0,pc 
       : "=r"(`result`)
       :
       : """  

proc hal_cpu_readSP*() : uint {.inline.} =
# get the current SP value (the full memory loc)   
 asm """
    mov %0,SP
    : "=r"(`result`)
    :
    : 
    """

proc hal_cpu_disableIRQ*() {.inline.} = 
# only works if in privileged mode (not USR)   
 asm """
    mrs r0, cpsr       
    orr r0, r0, #0x80   
    msr cpsr_c, r0      
    : 
    :
    : "r0"
    """     

proc hal_cpu_enableIRQ*() {.inline.} = 
# only works if in privileged mode (not USR)   
 asm """
    mrs r0, cpsr
    bic r0, r0, #0x80   // 
    msr cpsr_c, r0
    : 
    :
    : "r0" 
    """     

proc hal_cpu_irqDisabledCall*(callee : proc() {.cdecl,inline.}){.inline.} =
  # experimental
  asm """
    mrs r0, cpsr       
    orr r0, r0, #0x80   
    msr cpsr_c, r0 
    : 
    :
    : "r0" 
    """     
  callee()
  asm """
    mrs r0, cpsr
    bic r0, r0, #0x80   // enable irq
    msr cpsr_c, r0
    : 
    :
    : "r0" 
    """    

proc hal_cpu_enableAligmentFault*()=
  asm """ 
    mrc p15, 0, r0, c1, c0, 0   
    orr r0, r0, #(1 << 1)       
    mcr p15, 0, r0, c1, c0, 0   
    :
    :
    : "r0"
  """

proc xhal_cpu_initMMU*(){.cdecl,exportc:"xhal_cpu_initMMU".}=
  discard

proc hal_cpu_undef_instruction*(){.cdecl,inline.} =
  # test helper
  asm """
     .word 0xE7F123F4 // reserved instr
     :
     :
     : 
  """

proc hal_cpu_bad_jump*()=
   # test helper
   asm """
      ldr r0, =0xC0FEFEE0
      bx r0              
        :
        :
        : "r0", "lr"               
   """

# TODO: move to board specific section  
proc hal_cpu_resetBoard*(){.cdecl,inline.}=
  hal_cpu_doSoftwareIRQ(hal_consts_EnterMemLdr) 

proc hal_cpu_rBoard(){.cdecl, used, noreturn, exportc:"_reset_board".}=
  hal_cpu_doSoftwareIRQ(hal_consts_EnterMemLdr)

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
    asm """
      mrs r0, cpsr // _cxsf
      str r0, [%[ptr], #0]
      :
      : [ptr] "r" (`rd`)
      : "r0"
    """

# see blurry chapt 1.3 of the bcm2835 datasheet 
template hal_cpu_dmb()= # data memory barrier make sure following accesses are ordered
  {.emit""" 
  __asm volatile("mov r0,#0\n mcr p15, 0, r0, c7, c10, #5\n" : : : "r0");
  """.}

template hal_cpu_atomicAdd*(memptr: ptr uint32, val: uint32) =
  # to use this: mmu must be activated with Inner/Outer Write-back Shareable
  # emit only if mmu enabled. else do nothing
  {.emit:"""
    __asm__ volatile (
        "_1:                 \n"
        "ldrex   r1, [%0]   \n"
        "add     r1, r1, %1 \n"
        "strex   r2, r1, [%0]\n"
        "cmp     r2, #0     \n"
        "bne     _1         \n"
        :
        : "r" (`memptr`), "r" (`val`)
        : "r1", "r2", "memory"
    );
  """.}

template hal_cpu_disable_MMU*() =
  asm """
    mrc p15, 0, r0, c1, c0, 0   // read SCTLR 
    bic r0, r0, #(1 << 0)       // clear mmu enable bit 0
    mcr p15, 0, r0, c1, c0, 0   // write sctlr
    mov pc,pc                   // flush pipeline
    :
    :
    : "r0"
  """


proc hal_cpu_drain_WriteBuffer*() =
 asm """
    mov r0, #0
    mcr p15, 0, r0, c7, c10, 4  
    :
    :
    : "r0"
  """
proc hal_cpu_tbld_invalidate*()=
  asm """
    mov r0, #0
    mcr p15, 0, r0, c8, c7, 0   
    mov pc,pc
    :
    :
    : "r0"
  """
proc hal_cpu_invalidate_InstrCACHE*()=
  asm """
    mov r0, #0
    mcr p15, 0, r0, c7, c5, 0  
    :
    :
    : "r0"
  """
proc hal_cpu_invalidate_DataCACHE*()=
  asm """
    mov r0, #0
    mcr p15, 0, r0, c7, c6, 0   
    :
    :
    : "r0"
  """

proc hal_cpu_cleanAndInvalidateDCache*() =
  asm """
    MOV r0, #0
    MCR p15, 0, r0, c7, c10, 0   
    MCR p15, 0, r0, c7, c6, 0   
    :
    :
    : "r0"
  """  
proc hal_cpu_disableDCache*() =
  asm """
    MRC p15, 0, r0, c1, c0, 0    // Read System Control Register
    BIC r0, r0, #(1 << 2)        // Clear bit 2: disable data cache
    MCR p15, 0, r0, c1, c0, 0    // Write back
    :
    :
    : "r0"    
  """  

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
    );
  """.}