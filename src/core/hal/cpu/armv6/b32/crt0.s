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
@ armv6 startup
.section "boot","ax" 
.text
.code 32
.global _start
.global vectors_end
.extern GlobalStackSentinel
.global _launchproc_entry
.global _switch_context
.global _ret_call
.global _update_env
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
push {r4-r12,lr}                     // syscontext
str sp,[r0]
movs sp,r1
mov r0,#0
mcr p15, 0, r0, c7, c10, #5          // dmb
pop {r0,r1,pc}

_switch_context:                     
push {r4-r12,lr}  
str sp,[r0]          
movs sp,r1 
mov r0,#0
mcr p15, 0, r0, c7, c10, #5         // dmb  
pop {r4-r12,pc}	


_ret_call:
    bx lr

_el:
 bl _enter_sys_ldr  @for safety reasons