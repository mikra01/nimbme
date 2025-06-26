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

import ../../envconfig
import ptrutils

const constBitmasks : array[0..7,uint8] = [0:0b10000000.uint8,
                                           1:0b01000000.uint8,
                                           2:0b00100000.uint8,
                                           3:0b00010000.uint8,
                                           4:0b00001000.uint8,
                                           5:0b00000100.uint8,
                                           6:0b00000010.uint8,
                                           7:0b00000001.uint8]

const InvalidPointer : pointer = cast[pointer](0.int)

type 
  MemPoolErrno* = enum slotNotOccupied = -9.int8, offsetOutOfRange = -8,
                             reservedErrno = -7, slotInUse = -6, invalidSlot = -5 
                             outOfBuffer = -4, waitLimitExceed = -3,
                             threadNotObjectsOwner= -2, genericError= -1

  MemPoolBufferSize*{.size: sizeof(cuint), pure}  = enum b08 = 8, b16 = 16,b32=32,b64=64,b128=128,
                                   b256=256,b512=512,k1=1024,k2=2048,
                                   k4=4096,k8=8192,k16=16348,
                                   k32=32768,k64=65536
  
  MemPoolSlot* = range[slotNotOccupied.int..128.int]
    ## returntype which indicates error or contains the allocated slotnumber

  MemPoolBufferHandle* = tuple[pooledBufferPtr : pointer, 
                              slotidOrErrno : MemPoolSlot ]
 
  SBitContainer = array[4,uint32] # 128 slots

  MemPool* = object 
    memBase* : pointer                    # pointer to the membase of sharedMem
    contentionCount* : int                # count over entire obj-lifetime
    maxBuffers* : MemPoolSlot             # applval
    bufferSize* : MemPoolBufferSize       # applval 
    bufferUsed*  : int                    # calculated at runtime
    bitbuffer :  SBitContainer            # each set bit represents an allocated buffer


proc `=copy`(a:var MemPool, b:MemPool){.error.}  
proc `=destroy`(a:var MemPool) =
  dealloc(a.memBase)

const membufsize* = MemPoolBufferSize(UserProcessStackSize_bytes)      

proc getBitval(c: SBitContainer,bitnum:MemPoolSlot) : bool =
  usePtr[uint8]:
    var bptr : ptr uint8 = cast[ptr uint8](addr c)
    bptr += ( (bitnum shr 5) shl 2)   # /32 * 4
    result = ((bptr[bitnum shr 3] and constBitmasks[bitnum mod 8]) != 0 ) 

proc setBitval(c: var SBitContainer,bitnum:MemPoolSlot) = 
  usePtr[uint8]:
    var bptr : ptr uint8 = cast[ptr uint8](addr c)
    bptr += ( (bitnum shr 5) shl 2)   # /32 * 4 # bitmaskwidth 4byte
    let byteidx = bitnum shr 3 # / 8
    bptr[byteidx] = bptr[byteidx] or constBitmasks[bitnum mod 8]  
 

proc clearBitval(c: var SBitContainer,bitnum:MemPoolSlot)=
  usePtr[uint8]:
    var bptr : ptr uint8 = cast[ptr uint8](addr c)
    bptr += ( (bitnum shr 5) shl 2)   # (/32) * 8
    let byteidx = bitnum shr 3 # /8
    bptr[byteidx] = bptr[byteidx] and not(constBitmasks[bitnum mod 8]) 

# todo: alloc continous buffer space    
proc getEmptySlotIdx(c: SBitContainer, 
                     maxslots : MemPoolSlot) : MemPoolSlot =
  # checks for an empty slot by simply iterating over all bits
  # it returns outOfBuffer if all slots occupied
  result = MemPoolErrNo.outOfBuffer.int 
  var bitnum : MemPoolSlot = 0
  block zerobitsearch:
    usePtr[uint8]:
      let bptr : ptr uint8 = cast[ptr uint8](addr(c))
      var wordbase : int = 0
      var bytebase : int = 0
      var bitbase : int = 0
      # TODO: check dword and byte if completely occupied (speedup)
      for i32_idx in c.low..c.high:
        wordbase =  i32_idx shr 5    
        for i in 0 .. 3:          
          bytebase = i shl 3      
          bitbase = wordbase + bytebase # startbit
          if bptr[i] < 255:
            for x_idx in constBitmasks.low..constBitmasks.high:
              bitnum = bitbase + x_idx
              if bitnum < maxslots:
                if (bptr[i] and constBitmasks[x_idx]) == 0:  
                  result = bitnum        
                  break zerobitsearch
              else:
                break zerobitsearch           


template isValid*(slotnum : MemPoolSlot) : bool =
  slotnum.int >= 0

template isValid*(hdl : MemPoolBufferHandle) : bool =
  hdl.slotIdOrErrno.int >= 0 and hdl.pooledBufferPtr != InvalidPointer

proc calculateMemBufferSize*(buffersize : MemPoolBufferSize, 
                             buffercount : MemPoolSlot) : int =
  ## helper proc to get the total memory size needed 
  if buffercount.isValid:   
    return (buffersize.int * buffercount.int) 
  else:
    return -1

proc newMemPool*(buffersize : MemPoolBufferSize, 
                       buffercount : MemPoolSlot, 
                       memBufferBasePtr : pointer,
                       ) : MemPool =  
  result.contentionCount = 0   
  if buffercount.isValid:
    result.maxBuffers = buffercount
  else:
    result.maxBuffers = 1.int

  result.bufferSize = buffersize
  result.bufferUsed = 0
  result.bitbuffer = [0.uint32,0,0,0] # todo: feature: adjust size according to maxval
  
  # memorybase provided by the caller plus object size
  result.memBase = memBufferBasePtr 

proc getMemBufferBasePtr*(pool: MemPool) : pointer {.inline.} =
  ## convenience proc to obtain the ptr of the memory buffer (dealloc)
  return cast[pointer](pool.memBase)
  
proc getContentionCount*(pool : MemPool) : int  {.inline.} =
  ## retrieves the contention count within the overall pool´s lifetime
  pool.contentionCount
  
proc getUsedBufferCount*(pool : MemPool) : int {.inline.} =
  ## returns the count of the currently allocated buffers (ptr version)
  pool.bufferUsed  


proc clearMem(hdl: MemPoolBufferHandle,bsize : MemPoolBufferSize, clearVal : int) =
     # determine integer width to wipe the buffers memory with the given preset pattern
     var loopval : int =  bsize.int shr 2  
     var tp : ptr int = cast[ptr int](hdl.pooledBufferPtr)

     usePtr[int]: 
       for i in 0..loopval-1:
         tp[i] = clearVal 


template slotnum2BufferPointer(pool: MemPool, 
                                slotnum : MemPoolSlot, 
                                offset : int = 0) : pointer =                             
  if offset < pool.bufferSize.int and offset >= 0 and slotnum.isValid:
    cast[pointer]( cast[int](pool.memBase) + 
                  (pool.bufferSize.int * slotnum.int) + 
                   offset)         
  else:
    InvalidPointer


template allocSlot(pool : var MemPool, 
                            slotnum: MemPoolSlot, 
                            result : MemPoolBufferHandle) =
  setBitval(pool.bitbuffer,slotnum); # alloc slot
  result.slotidOrErrno = slotnum
  result.pooledBufferPtr = slotnum2BufferPointer(pool,slotnum)
  
  
proc requestBuffer*( pool: var MemPool, 
                     fillval : int = 0, 
                     wipeBufferMem : bool = true ) : MemPoolBufferHandle =

  result.slotidOrErrno = cast[MemPoolSlot](genericError)
  result.pooledBufferPtr = InvalidPointer
  
  result.slotidOrErrno = getEmptySlotIdx(pool.bitbuffer,pool.maxBuffers)

  if not result.slotidOrErrno.isValid:
      # out of buffer condition
      inc pool.contentionCount     

      
  allocSlot(pool,result.slotidOrErrno,result)
  inc pool.bufferUsed

  if wipeBufferMem:
    result.clearMem(pool.bufferSize,fillval)


proc requestBufferBySlotNum*(pool: var MemPool, 
                             slotnum: MemPoolSlot, 
                             fillval : int = 0, 
                             clearBufferMem : bool = false): MemPoolBufferHandle =
  ## requests a buffer by fixed slotnum. only suitable for memory mapped access  
  result.slotidOrErrno = cast[MemPoolSlot](MemPoolErrno.slotInUse)
  result.pooledBufferPtr = InvalidPointer

  if not slotnum.isValid or slotnum > pool.maxBuffers - 1 :
    result.slotidOrErrno = cast[MemPoolSlot](MemPoolErrno.invalidSlot)
    return
  
  if getBitval(pool.bitbuffer,slotnum) :
    # slot already allocated
     result.slotidOrErrno = cast[MemPoolSlot](MemPoolErrno.slotInUse)
     inc pool.contentionCount
     return 

  allocSlot(pool,slotnum,result)
  inc pool.bufferUsed
  
  if clearBufferMem:
    result.clearMem(pool.bufferSize,fillval)
  
   
proc releaseBuffer*( pool: var MemPool, slotnum: MemPoolSlot )  =
  ## marks the specified buffer as unused. 
  if slotnum.isValid or slotnum <= pool.maxBuffers-1:    
      if getBitval(pool.bitbuffer,slotnum):
        clearBitval(pool.bitbuffer,slotnum)
        dec pool.bufferUsed
