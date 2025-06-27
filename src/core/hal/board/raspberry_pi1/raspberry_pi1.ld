/*
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
*/

OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm",
              "elf32-littlearm")
OUTPUT_ARCH(arm)
MEMORY
{        
  flash      (arx)  : ORIGIN = 0x0020000, LENGTH = 0x00080000  
  ldr (arwx) : ORIGIN = 0x00200, LENGTH = 0x1600
  pt (arw) : ORIGIN = 0x4000, LENGTH = 0x1000
  boot(arx) : ORIGIN = 0x00008000, LENGTH = 0x00000800
  ram      (arwx) : ORIGIN = 0x00010000, LENGTH = 0x0000F000 
  nvram      (arw)  : ORIGIN = 0x0000F000, LENGTH = 0x0000F800  
}

STACK_SIZE = 0x1AA8; 
 /* undef/abort/fiq unused */
UNDEF_STACK_SIZE = 0xA8; /* undef/abort/fiq unused */
ABORT_STACK_SIZE = 0x58;
FIQ_STACK_SIZE = 0x28;
IRQ_STACK_SIZE = 0x148;    
SUPV_STACK_SIZE = 0x1C8;   
SYS_STACK_SIZE = 0x1688; 

IRQ_SENTINEL_OFFSET = 0x10;    /* should not exceed stacksize  */
SUPV_SENTINEL_OFFSET = 0x10;
SYS_SENTINEL_OFFSET = 0x10;

PAGE_TABLE_START = ORIGIN(pt);
PAGE_TABLE_LEN = LENGTH(pt);

HEAP_SIZE =  0x6000; 
IRQ_VECT_START = ORIGIN(boot);      
IRQ_VECT_DEST = 0x0;
IRQ_VECT_COUNT = 0x16;
LD_BAD_FUNCTION = 0xDEFDBEEF;

RAM_ABS_START = ORIGIN(ram);
_ldr_sect_start = ORIGIN(ldr);


SECTIONS
{

.boot           : ALIGN(8)
  { KEEP(startup.o)
  } > boot

    .text : ALIGN(8)
    {
        *(.text .text.*)
        *(.rodata*)
       
    } > flash
  
    .stack (NOLOAD):
    {   . = ALIGN(8);
        _stack_bottom = .;               
          . = . + UNDEF_STACK_SIZE;
        _undef_stack = .;
        . = . + ABORT_STACK_SIZE;
        _abort_stack = .;
        . = . + SYS_STACK_SIZE;
        _sys_stack = . ;
        . = . + FIQ_STACK_SIZE;
        _fiq_stack = .;   
        . = . + SUPV_STACK_SIZE;
        _supv_stack = .;
        . = . + IRQ_STACK_SIZE;
        _irq_stack = . ;
         /* . = . + STACK_SIZE;  fiq unused*/
         _stack_top = .; 
    } > ram

    .bss (NOLOAD) : ALIGN(8)
    {
        *(.bss .bss.*)
        *(COMMON)
    } > ram

    .nvram (NOLOAD) : ALIGN(8)
    {
    KEEP(*(.nvram))
    . = ALIGN(8);
    } > nvram

    .data :  ALIGN(8)
    {  
        *(.data .data.*)
    } > ram AT >flash

    /* section needed for != -exceptions:goto */
    /* .ARM.exidx : { __exidx_start = .; *(.ARM.exidx* .gnu.linkonce.armexidx.*) __exidx_end = .; } > ram */

    . = ALIGN(8);
   _end = .; 
  . = . + HEAP_SIZE; 
  _heap_end = .;

_bss_start = ADDR(.bss);
_bss_end = _bss_start + SIZEOF(.bss);
_data_start = ADDR(.data);
_data_end = _data_start + SIZEOF(.data);
_flash_data_start = LOADADDR(.data);

_nvram_start = ORIGIN(nvram);
_nvram_end = _nvram_start + LENGTH(nvram);
   
    /DISCARD/ : {  *(*)  } 

}