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
# simple stream impl - based on memorypool
# write bytes or blocks to memory 
# if current space exceeds, a new memory block is allocated if possible

# utilization of the memorypool 
# max 8 bookmarks can be set per buffer. user can wind back or forth to each mark 
# given memory ptr to the mark must be aligned according to the underlying arch

import circularbuffer
import mempool
import std/lists


type                                
  BlockMarker* = distinct CBuffer[8,uint32]
  MemoryStreamErrno* = enum MemPoolOutOfBuffer = -4, NoErr = 0             

  MemoryStream*[uint] = object
    marker : BlockMarker  
    blockSize : MemPoolBuffersize
    bufferHandles : seq[MemPoolBufferHandle]
    memPool :  MemPool
    pad : uint8 # unused
    itemSize* : uint8    # 8 on 64bit machines
    entryCount : uint16  # max 65535 items allowed 
    writeHandleNum : uint8 # buffer handle number which is written
    handleWriteIdx : uint8  # byte-offset within the buffer handle - mode write
    readHandleNum : uint8 # buffer handle number which is currently read out 
    handleReadIdx : uint8 # byte-offset within the buffer handle - mode read
    
proc `=copy`*[T](a: var MemoryStream[T]; b: MemoryStream[T]){.error.} 

template hasError*(rc : MemoryStreamErrno) : bool =
  rc.ord < 0

proc initMemoryStream*(memstream : var MemoryStream, mempool : sink MemPool) : MemoryStreamErrno =
    result = MemoryStreamErrno.NoErr
    memstream.itemSize = cast[uint8](sizeof(uint))
    memstream.bufferHandles.add(mempool.requestBuffer())     
    if memstream.bufferHandles[0].isValid:
      memstream.blockSize = mempool.bufferSize
      memstream.memPool = mempool                           
      memstream.handleWriteIdx = 0
      memstream.entryCount = 0
      memstream.writeHandleNum = 0 
      memstream.handleReadIdx = 0  
      memstream.readHandleNum = 0
    else:
      result = MemoryStreamErrno.MemPoolOutOfBuffer

proc `$`*(f: MemoryStream): string =
  "MemoryStream: bufferSize " & $f.blockSize & " maxBuffers:" & $f.mempool.maxBuffers & " entryCount:" & $f.entryCount & " bufferHandles: " & $f.bufferHandles.len

template `[]`(x:  MemoryStream; i: uint16): MemPoolBufferHandle =
  x.bufferHandles[i]

template `[]`(x: MemPoolBufferHandle; i: uint8): ptr uint32 =
  x.pooledBufferPtr[i]

proc bytesLeft(memstream : MemoryStream) : uint {.inline.} =
  cast[uint](memstream.blockSize.ord) - memstream.handleWriteIdx

proc allocBuffer(memstream : var MemoryStream) : MemPoolBufferHandle  {.inline.} =
  result  = memstream.memPool.requestBuffer()
  if result.isValid:
    memstream.bufferHandles.add(result)
    memstream.handleWriteIdx = 0
    memstream.writeHandleNum.inc

  
proc append*[n]( memstream: var MemoryStream, arr : array[n,uint]) : MemoryStreamErrno = 
  # probe if current buffer matches len
  result = MemoryStreamErrno.NoErr
  var buffptr : uint = cast[uint](memstream[memstream.writeHandleNum].pooledBufferPtr)

  if arr.len-1 >= 0:
    for i in 0 .. arr.len-1:
      if memstream.bytesLeft == 0:
        let mbh : MemPoolBufferHandle = memstream.allocBuffer()
        if mbh.isValid:
          buffptr = cast[uint](mbh.pooledBufferPtr)
        else:
          result = MemoryStreamErrno.MemPoolOutOfBuffer
          break
      (cast[ptr uint](buffptr))[] = arr[i]
      buffptr.inc(memstream.itemSize)
      memstream.handleWriteIdx.inc(memstream.itemSize)
      memstream.entryCount.inc 

proc resetReadIdx(memstream : var MemoryStream) {.inline.} = 
  memstream.handleReadIdx = 0
  memstream.readHandleNum = 0

proc calculateItemCount(memstream :  MemoryStream) : uint =
    let itemPerBlock = memstream.blocksize div memstream.itemSize
    for i in 0.. memstream.bufferHandles.len -1 :
      discard
      
iterator items*(memstream : var MemoryStream): uint =
     memstream.resetReadIdx()
     var i : uint = 0
     var bufhdlId : uint16 = 0
     var memptr : uint = cast[uint](memstream[bufhdlId].pooledBufferPtr)
     var relBufCount = 0
     while i < memstream.entryCount:
       yield (cast[ptr uint](memptr))[]
       inc i
       relBufCount.inc(memstream.itemSize)
       if relBufCount < memstream.blockSize.ord:
         memptr.inc(memstream.itemSize)
       else:
         bufhdlId.inc
         relBufCount = 0
         memptr = cast[uint](memstream[bufhdlId].pooledBufferPtr) 

proc reset(str : var MemoryStream) = 
  # frees all internal buffers except one
  if str.bufferHandles.size > 1:
    var first = true
    for x in str.bufferHandles:
      if not first:
        str.mempool.releaseBuffer(x.slotidOrErrno)
        str.bufferHandles.remove(x)
      else:
        first = false
        continue  




  
                        
