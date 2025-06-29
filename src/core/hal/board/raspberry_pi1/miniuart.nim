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

# TODO: move to pl011 / miniuart more or less unusable without polling

template miniuart_isDataReady*() : bool =
  (AUX_MU_LSR_REG.hal_gpioaux_getAuxVal() and 0x01.uint) > 0

template miniuart_isTxFifoAcceptByte*() : bool = 
  (AUX_MU_LSR_REG. hal_gpioaux_getAuxVal() and 0x20.uint) > 0  

# fixme: remove blocking and introduce 7 char buff
template miniuart_put_char_blocking*( c : char) =
  # deprecate 
    while not miniuart_isTxFifoAcceptByte():
      discard
    AUX_MU_IO_REG.hal_gpioaux_setAuxVal(cast[uint](c)) 

template miniuart_put_char*( c : char ) =
   AUX_MU_IO_REG.hal_gpioaux_setAuxVal(cast[uint](c))

template miniuart_get_char*() : char = 
  cast[char](AUX_MU_IO_REG.hal_gpioaux_getAuxVal() and 0xFF.uint)

template miniuart_get_char_blocking*() : char =
    while not miniuart_isDataReady:
      discard
    cast[char](AUX_MU_IO_REG.hal_gpioaux_getAuxVal() and 0xFF.uint)


template miniuart_write_str_blocking*(val : cstring,len : int) =
    for i in 0..len-1:
        miniuart_put_char_blocking(cast[char](val[i]))        

template miniuart_enable_tx_irq*() =
  AUX_MU_IER_REG.hal_gpioaux_setAuxVal(AUX_MU_IER_REG.hal_gpioaux_getAuxVal() or 0x2.uint)  

template miniuart_disable_tx_irq*() =
  AUX_MU_IER_REG.hal_gpioaux_setAuxVal(AUX_MU_IER_REG.hal_gpioaux_getAuxVal() and (not 0x2.uint))  
  
template miniuart_enable_rx_irq*() =
  AUX_MU_IER_REG.hal_gpioaux_setAuxVal(AUX_MU_IER_REG.hal_gpioaux_getAuxVal() or 0x1.uint) 

template miniuart_disable_rx_irq*() =
   AUX_MU_IER_REG.hal_gpioaux_setAuxVal(AUX_MU_IER_REG.hal_gpioaux_getAuxVal() and (not 0x1.uint))  


proc miniuart_process_irq*(){.inline.} =
  var stat : uint = AUX_IRQ.hal_gpioaux_getAuxVal and 0x1
  if(stat > 0): # miniuart irq pending
    
    if uartOutputBuffer.hasVal():
        let txChars = 8 - (AUX_MU_STAT_REG.hal_gpioaux_getAuxVal() shr 24) and 0xF
        for i in 0..txChars - 1:
          if uartOutputBuffer.hasVal():
            miniuart_put_char(uartOutputBuffer.fetchVal())
          else:
            break
    else:
        miniuart_disable_tx_irq    

    for i in 0..10:  
      ## seems that the miniuart not generating consecutive irqs.. TODO: move to pl011
      if miniuart_isDataReady:
          uartInputBuffer.putVal(miniuart_get_char())
    

proc rcall*(v : int){.importc:"_ret_call",cdecl.}

template setupPullUpResistorTxRx() =
  # TODO: move2gpioaux
  GPPUD.hal_gpioaux_setGpVal 2 # 2: pullup 1:pulldown 0:off
  for i in 0..150: 
    rcall(i)
  GPPUDCLK0.hal_gpioaux_setGpVal (1.uint shl 14) or (1.uint shl 15) # attach clock for gpio14/15
  for i in 0..150: 
    rcall(i)
  GPPUDCLK0.hal_gpioaux_setGpVal 0 # remove clock

proc hal_miniuart_init(coreFrequency : uint, baudRate : uint) = 
 
  AUX_MU_IER_REG.hal_gpioaux_setAuxVal 0.uint
  AUX_MU_CNTL_REG.hal_gpioaux_setAuxVal 0.uint
  AUX_MU_LCR_REG.hal_gpioaux_setAuxVal 3.uint
  AUX_MU_MCR_REG.hal_gpioaux_setAuxVal 0.uint
  AUX_MU_IER_REG.hal_gpioaux_setAuxVal 0x00.uint   
  AUX_MU_IIR_REG.hal_gpioaux_setAuxVal 0x06.uint  
  AUX_MU_BAUD_REG.hal_gpioaux_setAuxVal (coreFrequency div (baudrate shl 3) - 1).uint32 

  var t = GPFSEL1.hal_gpioaux_getGpVal

  t = t and (not(7.uint shl 12)) # gpio14
  t = t or (2.uint shl 12) # alt5
  t = t and (not(7.uint shl 15))
  t = t or (2.uint shl 15) # alt5
  GPFSEL1.hal_gpioaux_setGpVal t
  setupPullUpResistorTxRx()
  AUX_MU_CNTL_REG.hal_gpioaux_setAuxVal 3