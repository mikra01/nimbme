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

# defs and helper for the raspberry pi1 gpio blocks
# 26 io pins on 40 pin hdr
# each pin can have another alt-config
# wip

type 
    GPIOREG* =  uint32
    AUXREG* =  uint32
    GPIOPTR* = ptr array[256,GPIOREG]
    AUXPTR* = ptr array[512,AUXREG]
    
const 
    GPIOBASE* : GPIOPTR = cast[GPIOPTR](0x20200000)
    AUXBASE* : AUXPTR = cast[AUXPTR](0x20215000)
    GPFSEL1* : GPIOREG = 1.uint32
    GPSET0*  : GPIOREG = 7.uint32
    GPCLR0*  : GPIOREG = 0xa.uint32  
    GPPUD* : GPIOREG = 0x25.uint32
    GPPUDCLK0* : GPIOREG = 0x26.uint32
    # AUX controls two SPI masters and the mini-uart
    AUX_IRQ* : AUXREG = 0x0.uint32 # Auxiliary Interrupt
    AUX_ENABLES* : AUXREG = 0x1.uint32
    AUX_MU_IO_REG* : AUXREG = 0x10.uint32
    AUX_MU_IER_REG* : AUXREG = 0x11.uint32
    AUX_MU_IIR_REG* : AUXREG = 0x12.uint32
    AUX_MU_LCR_REG* : AUXREG = 0x13.uint32
    AUX_MU_MCR_REG* : AUXREG = 0x14.uint32
    AUX_MU_LSR_REG* : AUXREG = 0x15.uint32
    AUX_MU_MSR_REG* : AUXREG = 0x16.uint32
    AUX_MU_SCRATCH_REG* : AUXREG = 0x17.uint32
    AUX_MU_CNTL_REG* : AUXREG = 0x18.uint32     # mini uart
    AUX_MU_STAT_REG* : AUXREG = 0x19.uint32     # mini uart
    AUX_MU_BAUD_REG* : AUXREG = 0x1a.uint32     # mini uart


#0x7E21 5000 AUX_IRQ Auxiliary Interrupt status 3
#0x7E21 5004 AUX_ENABLES Auxiliary enables 3
#0x7E21 5040 AUX_MU_IO_REG Mini Uart I/O Data 8
#0x7E21 5044 AUX_MU_IER_REG Mini Uart Interrupt Enable 8
#0x7E21 5048 AUX_MU_IIR_REG Mini Uart Interrupt Identify 8
#0x7E21 504C AUX_MU_LCR_REG Mini Uart Line Control 8
#0x7E21 5050 AUX_MU_MCR_REG Mini Uart Modem Control 8
#0x7E21 5054 AUX_MU_LSR_REG Mini Uart Line Status 8
#0x7E21 5058 AUX_MU_MSR_REG Mini Uart Modem Status 8
#0x7E21 505C AUX_MU_SCRATCH Mini Uart Scratch 8
#0x7E21 5060 AUX_MU_CNTL_REG Mini Uart Extra Control 8
#0x7E21 5064 AUX_MU_STAT_REG Mini Uart Extra Status 32
#0x7E21 5068 AUX_MU_BAUD_REG Mini Uart Baudrate 16
#0x7E21 5080 AUX_SPI0_CNTL0_REG SPI 1 Control register 0 32
#0x7E21 5084 AUX_SPI0_CNTL1_REG SPI 1 Control register 1 8
#0x7E21 5088 AUX_SPI0_STAT_REG SPI 1 Status 32
#0x7E21 5090 AUX_SPI0_IO_REG SPI 1 Data 32
#0x7E21 5094 AUX_SPI0_PEEK_REG SPI 1 Peek 16
#0x7E21 50C0 AUX_SPI1_CNTL0_REG SPI 2 Control register 0 32
#0x7E21 50C4 AUX_SPI1_CNTL1_REG SPI 2 Control register 1 8
#0x7E21 50C8 AUX_SPI1_STAT_REG SPI 2 Status 32
#0x7E21 50D0 AUX_SPI1_IO_REG SPI 2 Data 32
#0x7E21 50D4 AUX_SPI1_PEEK_REG SPI 2 Peek 16 

template hal_gpioaux_enableAux*() =
    AUX_ENABLES.hal_gpioaux_setAuxVal 1.uint32

template hal_gpioaux_getAuxVal*(idx : AUXREG) : uint =
    hal_cpu_getDWord(cast[ptr uint](addr AUXBASE[idx]))

template hal_gpioaux_setAuxVal*(idx : AUXREG, val : uint) =
    hal_cpu_storeDWord(cast[ptr uint](addr AUXBASE[idx]) ,val)

template hal_gpioaux_getGpVal*(idx : GPIOREG) : uint =
    hal_cpu_getDWord( cast[ptr uint](addr GPIOBASE[idx]) )

template hal_gpioaux_setGpVal*(idx : GPIOREG, val : uint) =
    hal_cpu_storeDWord( cast[ptr uint](addr GPIOBASE[idx]), val )

#template `[]`*(ap : AUXPTR, idx : AUXREG): uint32 = 
#    getAuxVal(idx)

#template `[]=`*(ap : AUXPTR,idx : AUXREG, val: uint32) = 
#    setAuxVal(idx,val)

#template `[]`*(ap : GPIOPTR, idx : GPIOREG): uint32 = 
#    getGpVal(idx)

#template `[]=`*(ap : GPIOPTR,idx : GPIOREG, val: uint32) = 
#    setGpVal(idx,val)


#define GPFSEL1 0x20200004               1
#define GPSET0  0x2020001C               7
#define GPCLR0  0x20200028               a
#define GPPUD       0x20200094          25
#define GPPUDCLK0   0x20200098          26

#define AUX_ENABLES     0x20215004    5401
#define AUX_MU_IO_REG   0x20215040    5410
#define AUX_MU_IER_REG  0x20215044    5411
#define AUX_MU_IIR_REG  0x20215048    5412
#define AUX_MU_LCR_REG  0x2021504C    5413
#define AUX_MU_MCR_REG  0x20215050    5414
#define AUX_MU_LSR_REG  0x20215054    5415
#define AUX_MU_MSR_REG  0x20215058    5416
#define AUX_MU_SCRATCH  0x2021505C    5417
#define AUX_MU_CNTL_REG 0x20215060    5418
#define AUX_MU_STAT_REG 0x20215064    5419
#define AUX_MU_BAUD_REG 0x20215068    541a

# template getRegForPIN(1-)