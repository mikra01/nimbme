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

proc IRQHandler( )  {.cdecl,exportc:"irq_handler_nim",codegenDecl: "__attribute__ ((interrupt(\"IRQ\"))) $# $#$#"}=
  # no pl190 used
  # dmb needed because the periperal runs at different clock
  let cyStart = hal_armcc_readCycleCounter()
  (irqCycleStats.executionCountSinceStartup).inc
  let pendingVal = hal_cpu_getDWord(cast[ptr uint](0x2000B204))    # irq pending1 

  if hal_systemtimer_1_Fired(pendingVal):    
    timerBuffer.putVal(cast[uint](hal_systemtimer_getTStamp32())) 
    hal_systemtimer_1_setCompareVal(boardcfg_systemtimerTimerResolution_millis)
    volatileStore(addr softRtc, volatileLoad(addr softRtc) + 1)
    hal_cpu_dmb()
    hal_systemtimer_1_clearIRQ()

  let pendingVal2 = hal_cpu_getDWord(cast[ptr uint](0x2000B200))   # basic pending

  if hal_armnanotimer_hasFired(pendingVal2):
    #TODO: impl. wait nanos
    hal_armnanotimer_clearIRQ()


  miniuart_process_irq()

  irqCycleStats.cyclesLastRun = hal_armcc_getCyclesDiff(cyStart)
  (irqCycleStats.cummulatedCyclesSinceStartup).inc(irqCycleStats.cyclesLastRun)  
  #if hal_uart_0_hasRXIRQ(): 
  #  hal_uart_0_ClearReceiveInterrupt # todo: queue till fifo empty
  #  uartInputBuffer.putVal(hal_uart_0_ReadChar())
    

  #if hal_uart_0_hasTXIRQ(): 
  #  hal_uart_0_ClearTransmitInterrupt
  #  if uartOutputBuffer.hasVal(): # todo: queue till fifo full
  #     hal_uart_0_WriteChar(uartOutputBuffer.fetchVal())
  #  else: 
  #    hal_uart_0_DisableTxIRQ # no more 2 send
  #hal_cpu_dmb()

#var testglob : int = 0

proc triggerUart0Tx(){.cdecl,exportc:"_trigger_uart_0_tx"} =
  # if not hal_uart_0_isTxIRQEnabled:
  hal_uart_0_EnableTxIRQ
  hal_uart_0_chrout_blocking(uartOutputBuffer.fetchVal()) # initiate transmission



proc unknownSWI(num : uint, ysp : uint,ylr : uint){.cdecl,exportc:"_other_num"}=
  hal_uart_0_writestr "unknownSWI num ",16
  hal_uart_0_writestr num2Hex(num),8 
  hal_uart_0_writestr " lr:",4
  hal_uart_0_writestr num2Hex(ylr),8 
  hal_uart_0_writestr " and sp ",8 
  hal_uart_0_writestr num2Hex(ysp),8

proc SWIExceptionHandler() 
  {.cdecl,exportc:"swi_handler_nim", asmnostackframe.} =
  asm """
    push {r0-r3}
    sub r0,lr, #4
    ldr r0, [r0]
    and r0,r0, #0xFF
    CMP r0, #0xa
    beq prepcall
    CMP r0, #0x1
    beq _prep_memldr
    // push {lr} 
    mov r1,sp
    mov r2,lr
    bl _other_num
    // pop {lr}
    pop {r0-r3}
    movs pc,lr

_prep_memldr:
    // push {lr}
    mov r0,sp
    mov r1,lr
    bl _enter_sys_ldr   
    // pop {lr}      
    mrs r0, spsr              
    msr cpsr_cxsf, r0
    pop {r0-r3}
    movs pc,lr
   
prepcall:
    // push {r4,lr}
    bl _trigger_uart_0_tx
    // pop {r4,lr}
    mrs r0, spsr              @ Lade SPSR (vom SWI-Mode) in r0
    msr cpsr_cxsf, r0
    pop {r0-r3}
    movs pc,lr
    :
    :
    :  
  """


proc FIQExceptionHandler( ) 
  {.cdecl,exportc:"fiq_handler_nim",codegenDecl: "__attribute__ ((interrupt(\"FIQ\"))) $# $#$#".}=
  # gcc further reading: https://gcc.gnu.org/onlinedocs/gcc/ARM-Function-Attributes.html
  # works at the moment only with double indirection (asm-wrapper)
  # compiler dependent 
  # from the doc https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/swi-handlers-in-c-and-assembly-language
  # we can now access the sp values
  # echo " fiq-handler called"
  discard 


proc undefExceptionHandler_nim(faddr : uint, finstr : uint){.cdecl,exportc.}=
  hal_uart_0_writestr "undef_instruction was ",22
  hal_uart_0_writestr num2Hex(finstr),8
  hal_uart_0_writestr " at addr: ",10
  hal_uart_0_writestr num2Hex(faddr),8


proc UndefExceptionHandler() 
  {.cdecl,exportc:"undef_handler_nim",asmNoStackFrame.}=
  # gcc further reading: https://gcc.gnu.org/onlinedocs/gcc/ARM-Function-Attributes.html
  # works at the moment only with double indirection (asm-wrapper)
  # compiler dependent 
  # from the doc https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/swi-handlers-in-c-and-assembly-language
  # we can now access the sp values
  # glue code seems to preset r0 with the faulty instruction
  asm """
    push {r0,r1,r2,lr}
    sub lr, lr, #4          
    mov r0, lr             // fault addr              
    ldr r1, [r0]           // fault instr
    bl undefExceptionHandler_nim
    pop {r0,r1,r2,lr}
    subs pc, lr, #0        // fixme: do not jump back to fault
    :
    : 
    : 
  """

proc prefetchAbortExceptionHandler_nim(faddr : uint, finstr : uint){.cdecl,exportc.}=
  hal_uart_0_writestr "prefetchAbort_instruction was ",30
  hal_uart_0_writestr num2Hex(finstr),8 
  hal_uart_0_writestr " at addr: ",10
  hal_uart_0_writestr num2Hex(faddr),8

proc PrefetchAbortExceptionHandler() 
  {.cdecl,exportc:"prefetch_abort_handler_nim",asmNoStackFrame.} =
  # gcc further reading: https://gcc.gnu.org/onlinedocs/gcc/ARM-Function-Attributes.html
  # works at the moment only with double indirection (asm-wrapper)
  # compiler dependent 
  # from the doc https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/swi-handlers-in-c-and-assembly-language
  # we can now access the sp values
  asm """
    push {r0,r1,r2,lr}
    sub lr, lr, #4         // get faulted addr  
    mov r0, lr             // fault addr              
    ldr r1, [r0]           // fault instr
    bl prefetchAbortExceptionHandler_nim
    pop {r0,r1,r2,lr}
    subs pc, lr, #0
    :
    : 
    : 
  """

proc HypTrapExceptionHandler( ) 
  {.cdecl,exportc:"hypertrap_handler_nim",codegenDecl: "__attribute__ ((interrupt(\"TRAP\")))  $# $#$#".} =
  # not supported by present arm arch
  # gcc further reading: https://gcc.gnu.org/onlinedocs/gcc/ARM-Function-Attributes.html
  # works at the moment only with double indirection (asm-wrapper)
  # compiler dependent 
  # from the doc https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/swi-handlers-in-c-and-assembly-language
  # we can now access the sp values
  discard


proc aligmentFault(faultAddr : uint, faultInstrAddr : uint, spsr : uint){.cdecl,exportc:"alignment_fault_nim".} =
  # todo: introduce hal_logging
  hal_uart_0_writestr("alignment_fault  ".cstring,17)
  hal_uart_0_writestr("fault_addr:",11)
  hal_uart_0_writestr(num2Hex(faultAddr),8)
  hal_uart_0_writestr("fault_instr_addr:",17)
  hal_uart_0_writestr(num2Hex(faultInstrAddr),8)
  hal_uart_0_chrout_blocking 0xd.char
  hal_uart_0_chrout_blocking 0xa.char
  hal_cpu_resetBoard()

proc genericDataAbort(faultAddr : uint, faultInstrAddr : uint, spsr : uint){.cdecl,noreturn,exportc:"generic_data_abort_nim".} =
  hal_uart_0_writestr("generic_data_abort".cstring,18)
  hal_uart_0_writestr("fault_addr:",11)
  hal_uart_0_writestr(num2Hex(faultAddr),8)
  hal_uart_0_writestr("fault_instr_addr:",17)
  hal_uart_0_writestr(num2Hex(faultInstrAddr),8)
  hal_uart_0_chrout_blocking 0xd.char
  hal_uart_0_chrout_blocking 0xa.char
  hal_cpu_resetBoard()


proc DataAbortHandler( ) 
  {.cdecl,exportc:"dataabort_handler_nim",codegenDecl: "__attribute__ ((interrupt(\"ABORT\")))  $# $#$#".} =
  # gcc further reading: https://gcc.gnu.org/onlinedocs/gcc/ARM-Function-Attributes.html
  # works at the moment only with double indirection (asm-wrapper)
  # compiler dependent 
  # from the doc https://developer.arm.com/documentation/dui0056/d/handling-processor-exceptions/swi-handlers/swi-handlers-in-c-and-assembly-language
  # we can now access the sp values
  asm """
    //todo: implement software-breakpoint svc instr dump AllRegs
    sub lr, lr, #4               // sub lr, #8 is the faulted addr / in case of aligment fault execute next instr
    stmfd sp!, {r0-r4, lr}       // regs2stack
    mrc p15, 0, r4, c5, c0, 0    // read DFSR  → r0 fault type
    mrc p15, 0, r0, c6, c0, 0    // read DFAR  → r1 fault addr
     
    mov     r1, lr
    sub     r1, r1, #4              // r1 = faulted iaddr

    mrs     r3, spsr                // r3 = faulted spsr_abt

    //0b00001: Alignment Fault
    //0b00101: Translation Fault (Section)
    //0b01101: Permission Fault

    // @ fault type (bit 0–3 DFSR)
    and     r4, r4, #0xF           
    cmp     r4, #0x01               // Alignment-Fault = 0b00001
    bne generic 
    bl alignment_fault_nim
    ldmfd sp!, {r0-r4, lr}
    subs pc, lr, #0              // ret with SPSR_abt / fixme: do not jump back
generic:
    bl generic_data_abort_nim
    ldmfd sp!, {r0-r4, lr}
    subs pc, lr, #0              // ret with SPSR_abt / fixme: do not jump back
    :
    :
    :
     """

proc resethandlernim() {.exportc, used, asmNoStackFrame.} =
  asm """
  .set  MODE_USR, 0x10            		
  .set  MODE_FIQ, 0x11            		
  .set  MODE_IRQ, 0x12             		
  .set  MODE_SVC, 0x13            		
  .set  MODE_ABT, 0x17            		/* mem fault 						*/
  .set  MODE_UND, 0x1B            		/* undefined instr 		*/
  .set  MODE_SYS, 0x1F            		/* current main context */
  .set  I_BIT, 0x80               		/* irq disable bit */
  .set  F_BIT, 0x40               		/* fiq disable bit */
     NOP     
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     NOP
     ldr   r0, =_undef_stack
    			msr   CPSR_c, #MODE_UND|I_BIT|F_BIT 	
    			mov   sp, r0
    			msr   CPSR_c, #MODE_ABT|I_BIT|F_BIT 	
                ldr   r0, =_abort_stack
    			mov   sp, r0
    			msr   CPSR_c, #MODE_FIQ|I_BIT|F_BIT 	
    			ldr r0, =_fiq_stack
                mov   sp, r0
    			msr   CPSR_c, #MODE_IRQ|I_BIT|F_BIT 	
    			ldr r0, =_irq_stack
                mov   sp, r0     
    			msr   CPSR_c, #MODE_SVC|I_BIT|F_BIT 	
    			ldr r0, =_supv_stack
          mov   sp, r0
          bl _bootup_setup_pll
          bl _bootup_init_cpu   
    			msr   CPSR_c, #MODE_SYS|I_BIT|F_BIT 	
    			ldr r0, = _sys_stack
                mov   sp, r0
                nop
                nop
                nop
 bl _enable_fp                          
 bl _bootup_copy_vec_and_reloc_data_nim
 BL _setup_heap
 BL _hal_initialize_board
 BL NimMain
 LDR  r0,=_reset_board 
 BX r0  

  """

