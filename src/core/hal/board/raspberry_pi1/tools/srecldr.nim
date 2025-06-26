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

# inspired by https://github.com/dwelch67/raspberrypi/tree/master/bootloader07
# to prevent you playing discjokey - srecord version

import system/platforms
import std/[volatile]
# import ../../../../../envconfig
import ../../../../../core/utils/charbuffer


# dummy stubs 
var uartOutputBuffer : CharBuffer[1]
var uartInputBuffer : CharBuffer[1]

const UserDebugEchoPID* : bool = false
template getActivePID() : uint16 =
  99

type
  ArmCpuState* {.exportc, packed.}  = object
   r*: array[13, uint]  # contains r0-r12 
   sp*: uint # r13
   lr*: uint # r14
   pc*: uint # r15
   cpsr*: uint # used to load spsr (feature not implemented)

template hal_cpu_doSoftwareIRQ*(trapNum : static cint) =
  discard 

# end dummy stubs

include ../../../generic/consts
include ../../../cpu/armv6/b32/cpu
include ../gpioaux

include ../miniuart
include ../timer
include ../uart

include ../../../generic/charutils

template getNumDigit( c : char) : byte =
  cast[byte](c) - 0x30

template getHexDigit( c : char ) : byte =
  cast[byte](c) - 0x37

template char2Nibble( nb : char ) : byte =
  if nb > 0x39.char:
    getHexDigit(nb)
  else:
    getNumDigit(nb)   

template char2Byte(hsb : char, lsb : char) : byte =
  var hn = 0.byte
  var ln = 0.byte

  if hsb > 0x39.char:
    hn = getHexDigit(hsb)
  else:
    hn = getNumDigit(hsb)
  if lsb > 0x39.char:
    ln = getHexDigit(lsb)
  else:
    ln = getNumDigit(lsb)

  (hn shl 4) or ln 

template buildDwordAndCkSum (hsb : byte, b2 : byte, b3: byte, lsb : byte) : uint =
  var res = 0.uint 
  checksum = checksum + hsb + b2 + b3 + lsb
  res = res or hsb
  res = (res shl 8)
  res = res or b2 
  res = (res shl 8)
  res = res or b3
  res = (res shl 8)
  res = res or lsb
  res

template receiveNibble() : byte =
  var ca : char = 0x0.char 
  var cacount = 0
  while cacount == 0:
    if hal_uart_0_RxHasPayload:
      ca = hal_uart_0_get_char
      inc cacount
  char2Nibble(ca)    

template receiveByte() : byte =
  var ca : array[2,char] = [0x0.char,0x0.char]
  var cacount = 1
  while cacount <= 2:
    if ca[cacount-1] == 0x0.char:
       if hal_uart_0_RxHasPayload:
         ca[cacount-1] = hal_uart_0_get_char
         inc cacount
  char2Byte(ca[0],ca[1])

template receiveData(numpad : int) : uint = 
  var bp : array[4,byte] = [0x0.byte,0x0.byte,0x0.byte,0x0.byte]
  var idx = 1
  var cnt = 4
  if numpad > 0:
    cnt.dec(numpad)
  while idx <= cnt:
    bp[idx-1] = receiveByte()
    inc idx 
  buildDwordAndCkSum(bp[3],bp[2],bp[1],bp[0]) 

template receiveLoadAddr(numpad : int) : uint = 
  var bp : array[4,byte] = [0x0.byte,0x0.byte,0x0.byte,0x0.byte]
  var idx = 1
  var cnt = 4
  if numpad > 0:
    cnt.dec(numpad)
  while idx <= cnt:
    bp[idx-1] = receiveByte()
    inc idx 
  buildDwordAndCkSum(bp[0],bp[1],bp[2],bp[3])   


type
  SrecResult = tuple[moreRecs : bool, statusCode : int]


proc processSrec() : SrecResult  {.used,inline.} =
  var iChar : char 
  var moreRecs : bool = true
  var statusCode : int = 0
  while true:
    if hal_uart_0_RxHasPayload:
      iChar = hal_uart_0_get_char     

      if iChar == 0xd.char or iChar == 0xa.char:
        continue
      if iChar == 'S':

        var bytecount,bytes2pad,datacount : int = 0
        var checksum : byte
        var loadaddr : uint

        let stype = receiveNibble() 
        case stype:
          of 0:
           statusCode = -2 
           break
          of 3:           
           byteCount = cast[int](receiveByte())
          of 7:
           moreRecs = false
           break # end detected
          else:
           statusCode = 2 # invalid record type
           break
        
        loadAddr = receiveLoadAddr(0)
        bytes2pad = 0
        if byteCount >= 6 and byteCount <= 255:
          # valid
          datacount = byteCount - 5 # data and checksum still processed
          checksum = checksum + cast[byte](bytecount)
        else:
          statusCode = 6
          break
        if loadAddr mod 4 != 0:
          statusCode = 3
          break

        bytes2pad = 4 - (datacount mod 4)
        if bytes2pad != 4:
          datacount.inc(bytes2pad)
        else:
          bytes2pad = 0  
       
        var dwordcount = datacount shr 2
        var dwordidx = 0
        while dwordidx < dwordcount:
          if dwordidx == dwordcount-1:
            cast[ptr uint](loadAddr)[] = receiveData(bytes2pad)
          else:
            cast[ptr uint](loadAddr)[] = receiveData(0)      
          inc dwordidx
          #cast[ptr uint](loadAddr)[] = dwordBuff[dwordidx-1]
          loadAddr.inc(4)
        var cs = receiveByte() # checksum
        if cs == (0xff - checksum):
          break   
        else:
          statusCode = 5
          break  
       
  return (moreRecs,statusCode)  



const errno2str : array[9,cstring] = [" \n all records loaded. no errors so far..\n","abort - invalid token!", "abort - invalid record type - only S3 types accepted",
  "abort - invalid loadaddr - not 4-byte aligned","", "abort - invalid srecord checksum!","abort - invalid bytecount","abort - invalid dword-bytecount",
  "payload abort - no S0 Header detected. please retry with fixed dataset! "]
const helloMsg : cstring = "memory-loader-mode active. exit by hardreset / complete env upload only. awaiting S3-records now..\n"
const finishMsg : cstring = " now booting into new version  \n"
const retryMsg : cstring = "ready to retry upload. please send file again \n"

proc hal_doboot {.importc:"_env_entry",noreturn,used,cdecl.}


hal_uart_0_strout_blocking(helloMsg,helloMsg.len)

var headerDetect : bool = false
var abort : bool = false
var lastErrMsg : cstring

while true:
  var mr : bool
  var statusCode: int
  (mr, statusCode) = processSrec()

  if mr == false and not abort and statusCode == 0:
    if headerDetect:
      hal_uart_0_strout_blocking(errno2str[statusCode],errno2str[statusCode].len)
      hal_uart_0_strout_blocking(finishMsg,finishMsg.len)
      hal_doboot()
    else:
      hal_uart_0_strout_blocking(errno2str[8],errno2str[8].len)
      hal_uart_0_strout_blocking(retryMsg,retryMsg.len)
  elif mr == true:
    if statusCode == -2:
      headerDetect = true
    if statusCode > 0:
      lastErrMsg = errno2str[statusCode]
      abort = true
    else:
      if abort:
        hal_uart_0_chrout '!'
      else:  
        hal_uart_0_chrout '.'            
  else:
      hal_uart_0_strout_blocking(lastErrMsg,lastErrMsg.len)
      hal_uart_0_strout_blocking(retryMsg,retryMsg.len)
      abort = false
      headerDetect = false        
    


