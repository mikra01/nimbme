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

proc hal_uart_0_writestr*( p1: cstring, len: cint) =
  #when uartUseBufferedOut:
  #  when UserDebugEchoPID:
  #    let pid = getActivePID()
  #    if pid < 99:
  #      uartOutputBuffer.putVal(cast[char](pid+0x30))
  #      uartOutputBuffer.putVal(':')
  #    
  #  for i in 0 .. len-1:
  #    uartOutputBuffer.putVal(p1[i])
  #else:
  miniuart_write_str_blocking(p1,len)
        
  #when not uartOutBuffer_flush_blocking:
  #  # fixme: check if transmission running. if so, do nothing
  #  hal_cpu_doSoftwareIRQ(HALAPI_SVC_UART_0_TX)    


proc hal_flush_uart_0_async*(){.inline.} =
  discard
  #hal_uart_0_EnableTxIRQ
  #hal_cpu_doSoftwareIRQ(HALAPI_SVC_UART_0_TX)   

#template hal_uart_0_WriteChar*(v : char) =
#  discard
#  #volatileStore(HALUart0BASE,v)

template hal_uart_0_TransmitFifoFull : bool =
  false
  #(volatileLoad(HALUartFR) and HALUartFR_TXFF) > 0


proc hal_uart_0_strout_blocking*( p1: cstring, size : int ) =
  miniuart_write_str_blocking(p1,size)
  #discard
  #let strl = p1.len
  #for i in 0..strl-1:
  #  while hal_uart0TransmitFifoFull:
  #    discard
  #  volatileStore(HALUart0BASE,p1[i])

proc hal_uart_0_chrout_blocking*(c1 :char){.inline.}=
  miniuart_put_char_blocking(c1)

proc hal_uart_0_chrout*(c1 : char) =
  # fixme: change to noneblocking variant
  miniuart_put_char_blocking(c1)
  # discard
  #while hal_uart0TransmitFifoFull:
  #  discard 
  #volatileStore(HALUart0BASE,v)

proc hal_uart_flush_0_sync*(){.inline.} =
  discard
  #while uartOutputBuffer.hasVal(): 
  #  let x = uartOutputBuffer.fetchVal()
  #  hal_uart_0_chrout(x)  



template hal_uart_0_EnableRxIRQ() = 
  discard
  #volatileStore(HALUartIMSC,volatileLoad(HALUARTIMSC) or 0x10) #    

template hal_uart_0_EnableTxIRQ() = 
 discard # used

template hal_uart_0_DisableTxIRQ() = 
  discard
  #volatileStore(HALUartIMSC,volatileLoad(HALUARTIMSC) and (not 0x20.uint)) #   

template hal_uart_0_DisableRxIRQ() = 
  discard
  #volatileStore(HALUartIMSC,volatileLoad(HALUARTIMSC) and (not 0x10.uint)) #   

template hal_uart_0_ClearReceiveInterrupt* =  
  discard
  #volatileStore(HALUartICR, HALUARTICR_RXIC)

template hal_uart_0_ClearTransmitInterrupt* =  
  discard
  # volatileStore(HALUartICR,HALUARTICR_TXIC)

template hal_uart_0_hasRXIRQ : bool = 
  false  

template hal_uart_0_hasTXIRQ : bool = 
  false

template hal_uart_0_RxHasPayload* : bool =
  miniuart_isDataReady() 

template hal_uart_0_ReceiverFifoEmpty* : bool =
  false

template hal_uart_0_get_char_blocking* : char =
  # deprecate
  miniuart_get_char_blocking()
  # cast[char](volatileLoad(HALUart0BASE))

template hal_uart_0_get_char* : char =
  miniuart_get_char()

proc hal_uart_0_init() = 
  discard
  #volatileStore(HALUartCR,0x301) # enable pl011 uart rx/tx side
  #volatileStore(HALpicINTEnable,volatileLoad(HALpicINTEnable) or (1 shl 12)) 
  #hal_uart_0_DisableTxIRQ

  #when uartUseBufferedRxIRQ:
  #  hal_uart_0_EnableRxIRQ


# TODO: implement tx-overflow fifo helper