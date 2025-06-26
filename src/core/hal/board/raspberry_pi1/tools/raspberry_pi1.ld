/*
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
*/

OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm",
              "elf32-littlearm")
OUTPUT_ARCH(arm)
MEMORY
{              
  ldr (arwx) : ORIGIN = 0x0200, LENGTH = 0x1600
}


SECTIONS
{
.blc : ALIGN(8) { KEEP(ldr.o)  KEEP(*(.text .text.*))  KEEP(*(.rodata .rodata*))   }  > ldr 
.bld (NOLOAD) : ALIGN(8) {  KEEP( *(.bss .bss.*) )   }  > ldr  
.bldd  : ALIGN(8) {  KEEP( *(.data .data.*))   }  > ldr  

_env_entry = 0x8000; 

/DISCARD/ : {  *(*)  } 

}