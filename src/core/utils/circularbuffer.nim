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

import volatile
import ../../envconfig

type
  CBuffer*[n : static[int], T] = object
    readidx  : int = 0
    writeidx : int = 0
    ofcount : int = 0
    maxSkew : int = 0  # tracks the maximum skew between read and write
    buffer : array[n,T]

  SkipCountAndLastVal[T] = tuple[skipcount : int, lastval : T ]

proc `$`*(f: var CBuffer): string =
  "CBuffer: ridx " & $f.readidx & " widx:" & $f.writeidx & " overflow " & $f.ofcount &
  " bufflen: " & $f.buffer.len & " buff: " & $f.buffer

proc calcNextIndex[n : static[int],T](b : CBuffer[ n , T], idx : int) : int {.inline.}  = 
 result = idx 
 inc result
 if result > b.buffer.len-1:  
  result = 0.int 

template getReadIndex[n : static[int],T](b : CBuffer[ n , T]) : int =
  volatileLoad(addr b.readidx)
  
template getWriteIndex*[n : static[int],T](b : CBuffer[ n , T]) : int =
  volatileLoad(addr b.writeidx)

proc calcPrevWriteIndex[n : static[int],T](b : CBuffer[ n , T]) : int  = 
 result = b.getWriteIndex()
 dec result
 if result < 0:  
  result = b.buffer.len-1
 

template hasOverflowed*[n : static[int],T](b : CBuffer[ n , T]) : int   = 
  b.ofh

proc getItemsUpTo*[n : static[int],T]( b : CBuffer[ n , T],idx : int) : int  {.inline.} =
  let res : int = volatileLoad(addr b.readidx)
  result = idx - res
  if idx < res:
    result.inc(b.buffer.len)  
 

proc seek*[n : static[int],T](b : CBuffer[ n , T], seekVal : T) : int {.inline.} = 
  result = -1  # preset error
  if b.hasVal():
    let items : int = b.getItemCount()
    var index : int = b.getReadIndex()
    for i in 0..items-1:
      if b.peekValReadPos(index) == seekVal:  # evaluate if and how this works with more complex types
        result = index
        break
      else: 
        index = b.calcNextIndex(index)
     

template hasVal*[n : static[int],T](b : CBuffer[ n , T] ) : bool =
  ## returns true if there is data ready to read
  volatileLoad(addr b.writeidx) != volatileLoad(addr b.readidx)

proc is50pWatermark*[n : static[int],T](b : CBuffer[ n , T] ) : bool =
  # true if the buffer is 50p full
  if b.hasVal:
    if b.getItemCount() >= ( b.buffer.len shr 1):
       return true
  return false

proc getItemCount*[n : static[int],T](b : CBuffer[ n , T] ) : int {.inline.} =
  let ri = volatileLoad(b.readidx.addr)
  let wi = volatileLoad(b.writeidx.addr)
  result = wi - ri
  if ri > wi:
     result.inc(b.buffer.len)
      
    
template peekValReadPos*[n : static[int],T](b : CBuffer[n,T], idx : int = b.getReadIndex) : T =
  ## reads the value without removing it from the buffer
  b.buffer[idx]

template peekValWritePos*[n : static[int],T](b : CBuffer[n,T]) : T =
  ## reads the value at previous write position
  let i = b.calcPrevWriteIndex()
  b.buffer[i]

template reset*[n : static[int],T](b : CBuffer[n,T]) =
  volatileStore(addr b.readidx ,0)
  volatileStore(addr b.writeidx, 0)

proc fetchVal*[n : static[int],T](b : var CBuffer[n,T] ) : T {.inline.}=
  ## reads the value with removing
  let widx = volatileLoad(addr b.writeidx)  
  let ridx = volatileLoad(addr b.readidx)
  result = b.buffer[ridx]
  if ridx != widx:
    volatileStore(addr b.readidx , b.calcNextIndex(ridx)) 

proc skipAndfetchLastVal*[n : static[int],T](b : var CBuffer[n,T] ) : SkipCountAndLastVal[T] {.inline.}=
  ## reads last entry and removes all others. if last char is \n its ignored
  var ic = b.getItemCount()
  var lastCharNl = false
  if b.peekValWritePos() == config_consoleNewlineChar:
    lastCharNl = true

  if ic > 0:
    dec ic

  result.skipcount = ic  

  if lastCharNl:
    dec ic

  for i in 0 .. ic:
    result.lastval = b.fetchVal()
  
  if lastCharNl:
    discard b.fetchVal()

  return result  

proc putVal*[n : static[int],T](b : var CBuffer[n,T], val : sink T ){.inline.} =
  var idx : int = volatileLoad(addr b.writeidx)
  b.buffer[idx] = val 
  idx = b.calcNextIndex(idx)
  volatileStore(addr b.writeidx,idx)
  let ridx = volatileLoad(b.readIdx.addr)
  if idx == ridx:
    inc b.ofcount
    b.maxSkew = b.buffer.len
  else:
    # fixme: impl
    discard # buflen - (buflen-itemcount)  
    
  