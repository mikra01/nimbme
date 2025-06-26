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
{.emit"""
   __asm__(".section .rodata\n"
        ".balign 4\n"
        ".global _loader_bin\n"
        "_loader_bin:\n"
        ".incbin \"loader.bin\"\n"
        ".global _loader_bin_end\n"
        "_loader_bin_end:\n");
     extern const uint8_t loader_bin[];
     extern const uint8_t loader_bin_end[];
  """.}

proc loaderBinStart {.importc:"_loader_bin", cdecl.}
proc loaderBinEnd {.importc:"_loader_bin_end", cdecl.}
  
proc hal_bootup_ldrSectStart*() {.importc:"_ldr_sect_start",noreturn, cdecl.} 
  
proc enterLdr*(){.exportc:"_enter_sys_ldr" , used, cdecl, noreturn.} =
    hal_cpu_disableIRQ()

    bootup_cpuCopy(getPtr(hal_bootup_ldrSectStart),getPtr( cast[uint](hal_bootup_ldrSectStart) + cast[uint](loaderBinEnd) - cast[uint](loaderBinStart)),
      getPtr(loaderBinStart))
    hal_bootup_ldrSectStart()