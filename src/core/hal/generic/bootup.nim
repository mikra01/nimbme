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

proc bssStart() {.importc: "_bss_start", cdecl.}
proc bssEnd() {.importc: "_bss_end", cdecl.}
proc dataStart() {.importc: "_data_start", cdecl.}
proc dataEnd() {.importc: "_data_end", cdecl.}
proc romDataStart() {.importc: "_flash_data_start", cdecl.}
proc IRQVectStart(){.importc:"IRQ_VECT_START", cdecl.}
proc IRQVectDest(){.importc:"IRQ_VECT_DEST",cdecl.}
proc IRQVectCount(){.importc:"IRQ_VECT_COUNT", cdecl.}

type CopyPtr = ptr uint

proc chipConfiguration(){.cdecl.} =
  # TODO: establish external sym
  discard

template getPtr(val : proc (){.cdecl.}) : CopyPtr =
  cast[CopyPtr](val)

template getPtr(val : uint) : CopyPtr =
  cast[CopyPtr](val)

template incPtr(val : var CopyPtr) =
  val = cast[CopyPtr](cast[uint](val) + ENV_DWORD_SIZE)


proc bootup_cpuCopy(dstart : CopyPtr , dEnd : CopyPtr, src : CopyPtr){.inline.} =
    var relocStart  = cast[uint](dstart)
    let relocEnd  = cast[uint](dend)
    var relocSource  = cast[uint](src)
    var dest : CopyPtr
    var src : CopyPtr

    while relocStart <= relocEnd  :
      src = relocSource.getPtr
      dest = relocStart.getPtr
      dest[] = src[]
      relocStart.inc sizeof(int)
      relocSource.inc sizeof(int)

proc copyVecAndRelocData_nim(){.exportc : "_bootup_copy_vec_and_reloc_data_nim" ,used, cdecl.} = 
  # setup of irq-vector table, bss segment and reloc data segment   
  var src : CopyPtr = getPtr IRQVectStart  
  var dest : CopyPtr = getPtr IRQVectDest
  let wordsize = sizeof(uint).uint
  let vectCount = cast[int](IRQVectCount) - 1

  for i in 0..vectCount: 
    dest[] = src[]
    incPtr src 
    incPtr dest  

  var bs = cast[uint](bssStart)
  let bsEnd =cast[uint](bssEnd)
  src  = bs.getPtr

  while bs <= bsEnd :
     src[] = 0.uint
     bs.inc wordsize
     src = bs.getPtr

  bootup_cpuCopy(dataStart.getPtr,dataEnd.getPtr,romDataStart.getPtr)


  #when enableMMU:
  #  xhal_cpu_initMMU()
  #  hal_cpu_enableAlignmentFault()

  chipConfiguration()

proc bootup_setupPll(){.exportc : "_bootup_setup_pll" ,used, cdecl.} = 
  asm """
      NOP 
      NOP 
      :
      :
      :
  """

proc bootup_initCPU(){.exportc : "_bootup_init_cpu ", used, cdecl.}=
  when board == "raspberry_pi1":
    hal_cpu_cleanAndInvalidateDCache()
    hal_cpu_disableDCache()
    # DCache only useable together with MMU to disable caching while accessing memory mapped I/O regions


when board == "raspberry_pi1":
  include ../board/raspberry_pi1/tools/inmemoryloader
  

       

    

