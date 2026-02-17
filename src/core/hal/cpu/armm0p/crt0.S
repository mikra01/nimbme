@
@  This file is part of nimbme (nim bare-metal environment)
@  Copyright (c) 2025 Michael Krauter <michakr@atomicmail.io>
@ 
@  This program is free software: you can redistribute it and/or modify
@  it under the terms of the GNU General Public License as published by
@  the Free Software Foundation, version 3.
@ 
@  This program is distributed in the hope that it will be useful,
@  but WITHOUT ANY WARRANTY; without even the implied warranty of
@  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@  GNU General Public License for more details.
@ 
@  You should have received a copy of the GNU General Public License
@  along with this program. If not, see <https://www.gnu.org/licenses/>.
@ 
@ arm-m0plus startup
.section "boot","ax" 
.text
.cpu cortex-m0plus
.thumb

.global _start
.global vectors_end
.extern GlobalStackSentinel
.global _launchproc_entry
.global _switch_context
.global _ret_call
.global _update_env
.global _enable_fp
.extern _enter_sys_ldr


_start:
 LDR PC, reset_handler_addr
 LDR PC, undef_handler_addr
 LDR PC, swi_handler_addr
 LDR PC, prefetch_abort_handler_addr
 LDR PC, data_abort_handler_addr
 LDR PC, hyp_trap_addr
 LDR PC, irq_handler_addr
 LDR PC, fiq_handler_addr
 
reset_handler_addr: .word resethandlernim
undef_handler_addr: .word undef_handler_nim
swi_handler_addr: .word  swi_handler_nim 
prefetch_abort_handler_addr: .word prefetch_abort_handler_nim
data_abort_handler_addr: .word dataabort_handler_nim
hyp_trap_addr: .word hypertrap_handler_nim    // only in armvv7 and above
irq_handler_addr: .word irq_handler_nim 
fiq_handler_addr: .word fiq_handler_nim  
vectors_end:

_launchproc_entry: 
    push {r4-r7, lr}        @ callee-saved (low regs)

    mov  r2, r8             @ high regs manuell sichern
    push {r2}
    mov  r2, r9
    push {r2}
    mov  r2, r10
    push {r2}
    mov  r2, r11
    push {r2}
    mov  r2, r12
    push {r2}

    str  sp, [r0]           @ store old sp
    mov  sp, r1             @ set new sp

    @ dmb  not needed here                     

    pop  {r2}               @ r12
    mov  r12, r2
    pop  {r2}               @ r11
    mov  r11, r2
    pop  {r2}               @ r10
    mov  r10, r2
    pop  {r2}               @ r9
    mov  r9, r2
    pop  {r2}               @ r8
    mov  r8, r2

    pop  {r4-r7, lr}
    bx   lr

_switch_context:                     
push {r4-r7, lr}

    mov  r2, r8
    push {r2}
    mov  r2, r9
    push {r2}
    mov  r2, r10
    push {r2}
    mov  r2, r11
    push {r2}
    mov  r2, r12
    push {r2}

    str  sp, [r0]        @ save present sp
    mov  sp, r1          @ set new sp

    @ dmb  not needed here

    pop  {r2}            @ r12
    mov  r12, r2
    pop  {r2}            @ r11
    mov  r11, r2
    pop  {r2}            @ r10
    mov  r10, r2
    pop  {r2}            @ r9
    mov  r9, r2
    pop  {r2}            @ r8
    mov  r8, r2

    pop  {r4-r7, lr}
    bx   lr


_ret_call:
    bx lr

_el:
 bl _enter_sys_ldr  @for safety reasons


_enable_fp:
  @ no fpu in this context 
  nop
  