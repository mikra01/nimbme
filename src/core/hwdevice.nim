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
# flow-control: stream, continues / request,resp
# type: char / bin

# each hw device is registered and processed in global irq handler
import stdtypes, envtypes

const 
      ErrCodeDeviceInUse* : int = 1 


template hasError*(res : RegResult)=
    res.errorCode > 0

proc defaultCb*() =
    discard

proc initializeHwDevice*(dev : ptr HwDevice) =
   # dev.used = 0
   # dev.free = dev.devices.len - 1
    for i in DeviceType:
        dev.devices[i.ord] = DeviceEntry(isrCallback : defaultCb, serviceCall : defaultCb, ownerPid : 99.toPid , free : true )

proc serviceUsbHostIsr*(dev : ptr HwDevice){.inline.}=
    if not dev.devices[USB_host.ord].free:
        dev.devices[USB_host.ord].isrCallback() 

proc serviceUsbDevIsr*(dev : ptr HwDevice){.inline.}=
    if not dev.devices[USB_dev.ord].free:
        dev.devices[USB_dev.ord].isrCallback()

proc serviceSpiIsr*(dev : ptr HwDevice){.inline.}=
    if not dev.devices[SPI.ord].free:
        dev.devices[SPI.ord].isrCallback()

proc serviceI2cIsr*(dev : ptr HwDevice){.inline.}=
    if not dev.devices[I2C.ord].free:
        dev.devices[I2C.ord].isrCallback()

proc serviceNetIsr*(dev : ptr HwDevice){.inline.}=
    if not dev.devices[NET.ord].free:
        dev.devices[NET.ord].isrCallback()


proc registerDevice*[n,EventEntry](devType : DeviceType, isrcallb : DeviceIsrCallback, sCall : DeviceServiceCallback) : RegResult =
  if environmentContext[devType].free:
    environmentContext[devType].free = false
    environmentContext[devType].ownerPid = getActivePID()
    environmentContext[devType].callback = isrcallb
    environmentContext[devType].serviceCall = sCall   
    environmentContext[devType].isrService = false       
    result.errorCode = 0
    result.DeviceId = devType.ord.byte
  else:
    result.errorCode = ErrCodeDeviceInUse