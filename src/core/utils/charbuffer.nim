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
import circularbuffer
export circularbuffer


const CR* : char = 0x0d.char
const LF* : char = 0x0a.char

type
  CharBuffer*[n : static[int]] = CBuffer[n,char]

proc emitCR*(buf : var CharBuffer)=
  buf.putVal(CR)

proc emitCRLF*(buf : var CharBuffer)=
  buf.putVal(CR)
  buf.putVal(LF)

proc emitLF*(buf : var CharBuffer)=
  buf.putVal(LF)


template hasNewline*(buf : var CharBuffer) : int =
  buf.seek(config_consoleNewlineChar) 


proc toString*(buf : var CharBuffer) : string = 
    let idx = hasNewline(buf)
    if idx > -1:
      var charCnt : int = buf.getItemCount()
      
      if idx >= 0 and charCnt >= 0:
        charCnt = idx

      result = newStringOfCap(charCnt) 
    
      for i in 0..charCnt-1:
        result.add(buf.fetchVal())


proc getNextLine*(buf : var CharBuffer) : string = 
    # returns string till end of line or empty string if buffer is empty or contains no end marker (CR) 
      # seek for first CR 
      let idx = buf.seek(config_consoleNewlineChar)
      if idx >= 0: 
        var charCnt = buf.getItemsUpTo(idx)  
        result = newStringOfCap(charCnt) # in case of no cr we extract all bufferchars # check if feasible  
        for i in 0 .. idx-1:
          result.add(buf.fetchVal())
