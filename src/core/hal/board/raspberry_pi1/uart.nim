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

type 
    UARTREG* =  int
    UARTPTR* = ptr array[18,UARTREG]
    
const 
    UART0BASE* : UARTPTR = cast[UARTPTR](0x20201000)
    UartDR* : UARTREG = 0x0 # datareq
    UartFR* : UARTREG = 0x6
    UartIBRD* : UARTREG = 0x9  # integer baud rate divisor
    UartFBRD* : UARTREG = 0xa # fractional baudrate reg
    UartMIS* : UARTREG = 0x10 # mask interrupt status
    UartICR* : UARTREG = 0x11 # interrupt clear register
    UartLCRH* : UARTREG = 0xb
    UartCR* : UARTREG = 0xc
    UartIMSC* : UARTREG = 0xe # 0x38


const
  IRQ_ENABLE2 = 0x2000B214.uint32 # 218
  IRQ_DISABLE2 = 0x2000B220.uint32
  IRQ_PEND2* =   0x2000B208.uint32
  IRQ_PENDBASIC* = 0x2000B200.uint32


template hal_uart_getVal*(idx : UARTREG) : uint =
    hal_cpu_getDWord(cast[ptr uint](addr UART0BASE[idx]))

template hal_uart_setVal*(idx : UARTREG, val : uint) =
    hal_cpu_storeDWord(cast[ptr uint](addr UART0BASE[idx]) ,val)


template setupUartPullUpResistorTxRx(val : uint) =
  # TODO: move2gpioaux
  GPPUD.hal_gpioaux_setGpVal val # 2: pullup 1:pulldown 0:off
  for i in 0..150: 
    rcall(i)
  GPPUDCLK0.hal_gpioaux_setGpVal (1.uint shl 14) or (1.uint shl 15) # attach clock for gpio14/15
  for i in 0..150: 
    rcall(i)
  GPPUDCLK0.hal_gpioaux_setGpVal 0 # remove clock


template hal_uart_0_EnableRxIRQ() = 
  UartIMSC.hal_uart_setVal(UartIMSC.hal_uart_getVal() or (1 shl 4) )

template hal_uart_0_EnableRxTimeoutIRQ() = 
  UartIMSC.hal_uart_setVal(UartIMSC.hal_uart_getVal() or (1 shl 6) )  

template hal_uart_0_EnableTxIRQ*() = 
   UartIMSC.hal_uart_setVal(UartIMSC.hal_uart_getVal() or  (1 shl 5).uint )

template hal_uart_0_DisableTxIRQ() = 
    UartIMSC.hal_uart_setVal(UartIMSC.hal_uart_getVal() and not (1 shl 5).uint )
  #volatileStore(HALUartIMSC,volatileLoad(HALUARTIMSC) and (not 0x20.uint)) #   

template hal_uart_0_DisableRxIRQ() = 
  UartIMSC.hal_uart_setVal( UartIMSC.hal_uart_getVal() and (not (1 shl 4).uint) )
  #volatileStore(HALUartIMSC,volatileLoad(HALUARTIMSC) and (not 0x10.uint)) #   

template hal_uart_0_DisableRxTimeoutIRQ() = 
  UartIMSC.hal_uart_setVal( UartIMSC.hal_uart_getVal() and (not (1 shl 6).uint) )

template hal_uart_0_ClearReceiveInterrupt =  
  UartICR.hal_uart_setVal  (1 shl 4).uint

template hal_uart_0_ClearReceiveTimeoutInterrupt =  
  UartICR.hal_uart_setVal  (1 shl 6).uint

template hal_uart_0_ClearTransmitInterrupt =  
  UartICR.hal_uart_setVal  (1 shl 5).uint

template hal_uart_0_hasRxIRQ(misVal : uint) : bool = 
  (misVal  and 0x10) > 0

template hal_uart_0_hasRxTimeoutIRQ(misVal : uint) : bool = 
  (misVal and 0x40) > 0  

template hal_uart_0_hasTxIRQ(misVal : uint) : bool = 
 (misVal and 0x20) > 0

template hal_uart_0_ReceiverFifoEmpty* : bool =
  (UartFR.hal_uart_getVal() and 0x10.uint) > 0

template hal_uart_0_TransmitFifoFull : bool =
  (UartFR.hal_uart_getVal() and (1 shl 5).uint) > 0

template hal_uart_0_TransmitFifoEmpty : bool =
  (UartFR.hal_uart_getVal() and (1 shl 7).uint) > 0

template hal_uart_0_putc(c1 : char) =
  UartDR.hal_uart_setVal(c1.uint)

proc hal_uart_0_putc_blocking*(c1 : char) =
  while hal_uart_0_TransmitFifoFull:
      discard
  hal_uart_0_putc(c1)

template hal_uart_0_getc : char =
   cast[char](UartDR.hal_uart_getVal())

proc hal_uart_0_getc_blocking*() : char =
  while true:
    if not hal_uart_0_ReceiverFifoEmpty:
      break
  hal_uart_0_getc    

proc hal_uart_0_strout_blocking*( p1: cstring, size : int ) =
  for i in 0..size-1:
    while hal_uart_0_TransmitFifoFull:
      discard
    hal_uart_0_putc(p1[i])


template hal_uart_0_enableUartIRQ() =
   hal_cpu_storeDWord(cast[ptr uint](IRQ_ENABLE2),(1 shl (57 - 32)).uint32 )

template hal_uart_0_disableUartIRQ() =
   hal_cpu_storeDWord(cast[ptr uint](IRQ_DISABLE2),(1 shl (57 - 32)).uint32 )

template hal_uart_0_isUartIrqPending() : bool =
   (hal_cpu_getDWord(cast[ptr uint](IRQ_PEND2)) and (1 shl (57 - 32)).uint32) > 0


proc hal_uart_0_init(ibrd : uint, fbrd:uint) = 
  # Disable UART0
  UartCR.hal_uart_setVal 0
  UartIMSC.hal_uart_setVal 0
  UartLCRH.hal_uart_setVal (0) 
  # GPIO14/15 ALT0 (Function Select 1)
  var t = GPFSEL1.hal_gpioaux_getGpVal
  t = t and (not(7.uint shl 12)) # gpio14
  t = t or (4.uint shl 12) 
  t = t and (not(7.uint shl 15))
  t = t or (4.uint shl 15) 
  GPFSEL1.hal_gpioaux_setGpVal t

  setupUartPullUpResistorTxRx(2)

  # Clear interrupts
  UartICR.hal_uart_setVal 0x7FF.uint

  UartIBRD.hal_uart_setVal ibrd 
  UartFBRD.hal_uart_setVal fbrd  # fraction
  UartLCRH.hal_uart_setVal ((1 shl 4) or (3 shl 5)) # 8N1 / enable fifo
  UartCR.hal_uart_setVal ((1 shl 0) or (1 shl 8) or (1 shl 9)) # enable uart / rx,tx
  hal_uart_0_EnableRxIRQ
  hal_uart_0_EnableRxTimeoutIRQ
  hal_uart_0_enableUartIRQ

template hal_uart_0_startTx*() =
   hal_uart_0_EnableTxIRQ
   while  uartOutputBuffer.hasVal() and (not hal_uart_0_TransmitFifoFull()):
     hal_uart_0_putc(uartOutputBuffer.fetchVal())

proc uart_process_irq*(){.inline.} =
  if hal_uart_0_isUartIrqPending():
    let irqmask = UartMIS.hal_uart_getVal()
    if hal_uart_0_hasTXIRQ(irqmask):
        while  uartOutputBuffer.hasVal() and (not hal_uart_0_TransmitFifoFull()):
          hal_uart_0_putc(uartOutputBuffer.fetchVal())
        if not uartOutputBuffer.hasVal():
          hal_uart_0_DisableTxIRQ
        hal_uart_0_ClearTransmitInterrupt
    if hal_uart_0_hasRXIRQ(irqmask):
      while not hal_uart_0_ReceiverFifoEmpty:
         uartInputBuffer.putVal(hal_uart_0_getc())
      hal_uart_0_ClearReceiveInterrupt
    if hal_uart_0_hasRxTimeoutIRQ(irqmask):   
      while not hal_uart_0_ReceiverFifoEmpty:
         uartInputBuffer.putVal(hal_uart_0_getc())
      hal_uart_0_ClearReceiveTimeoutInterrupt
      
