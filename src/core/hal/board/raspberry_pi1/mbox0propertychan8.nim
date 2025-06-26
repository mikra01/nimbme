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

# mailbox property channel
# all properitary codes are from: https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
# and all others from : https://bitbanged.com/posts/understanding-rpi/the-mailbox/
# this code is more or less hardcoded and bound to the "magic" VC firmware 

type 
    MBoxReg* =  uint32
    MBoxPtr = ptr array[24,MBoxReg]
    MBoxConst = uint32
    MboxTag = uint32
    MboxPropertyReq* = tuple[pid: ProcessId , target: PropertyTarget, mboxNum : int, reserved:uint32 ]
    MboxPropertyResp* = tuple[pid: ProcessId, mboxNum: int, val1 : uint32, val2: uint32]

    PropertyTarget*  = enum MacAddr = 0, SysThrottled = 1, CoreFrequencyMeasured = 2, ArmFrequencyMeasured = 3, 
      CoreTemp, CoreVoltage, MemoryArm, MemoryVC, FirmwareRevision, BoardModel, BoardRevision, BoardSerial
    RequestType = enum br8,br4  
    VCRawResponse* = tuple[res1 : uint32,res2:uint32]  


const 
    MBox0Base : MBoxPtr = cast[MBoxPtr](0x2000b880)
    #MBox1Base : MBoxPtr = cast[MBoxPtr](0x2000b8a0)

    MBOX_READ : MBoxReg = 0.uint32
    MBOX_WRITE : MBoxReg = 8.uint32
    MBOX_STATUS : MBoxReg = 6.uint32
    statMBox_full   = (1 shl 31).uint32
    statMBox_empty  = (1 shl 30).uint32
    chan8Prop : MBoxConst = 0x8.uint32
    REQUEST_CODE = 0x00000000.uint32
    RESPONSE_OK  = 0x80000000.uint32

var pendingMboxPropertyRequests : CBuffer[2,MboxPropertyReq]
var queuedMboxPropertyRequests : CBuffer[8,MboxPropertyReq]

type 
  EightByteRequest* {.packed.} = object
  # todo: better names
    size: uint32 = 32 
    code: uint32
    tag: MboxTag
    bufsize: uint32
    tagreq: uint32
    rvals* : array[2,uint32]
    endtag: uint32

  FourByteRequest* {.packed.} = object  # deprecate. same layout than EightByteRequest
  # todo: better names
    size: uint32 = 28
    code: uint32
    tag: MboxTag
    bufsize: uint32
    tagreq: uint32
    rvals* : array[1,uint32]
    endtag: uint32      



const
  # System Information
  TAG_GET_VC_FIRMWARE_REVISION* : MboxTag = 0x00000001'u32
  TAG_GET_BOARD_MODEL*     : MboxTag      = 0x00010001'u32
  TAG_GET_BOARD_REVISION*  : MboxTag      = 0x00010002'u32
  TAG_GET_MAC_ADDRESS*     : MboxTag      = 0x00010003'u32 
  TAG_GET_BOARD_SERIAL*    : MboxTag      = 0x00010004'u32
  TAG_GET_ARM_MEMORY*      : MboxTag      = 0x00010005'u32
  TAG_GET_VC_MEMORY*       : MboxTag      = 0x00010006'u32

  # Clock / Frequency
  TAG_SET_CLOCK_RATE*      : MboxTag      = 0x00030001'u32
  TAG_GET_CLOCK_RATE*      : MboxTag      = 0x00030002'u32
  TAG_GET_CLOCK_RATE_MEASURED* : MboxTag =  0x00030047'u32
  TAG_GET_MAX_CLOCK_RATE*  : MboxTag      = 0x00030003'u32
  TAG_GET_MIN_CLOCK_RATE*  : MboxTag      = 0x00030004'u32
  TAG_GET_CLOCK_STATE*     : MboxTag      = 0x00030007'u32
  TAG_SET_CLOCK_STATE*     : MboxTag      = 0x00030008'u32

  # Voltage
  TAG_GET_VOLTAGE*         : MboxTag      = 0x00030003'u32
  TAG_SET_VOLTAGE*         : MboxTag      = 0x00038003'u32
  TAG_GET_MAX_VOLTAGE*     : MboxTag      = 0x00030009'u32
  TAG_GET_MIN_VOLTAGE*     : MboxTag      = 0x0003000A'u32

  # Temperature
  TAG_GET_TEMPERATURE*     : MboxTag      = 0x00030006'u32
  TAG_GET_MAX_TEMPERATURE* : MboxTag      = 0x0003000B'u32

  # System Status
  TAG_GET_THROTTLED*       : MboxTag      = 0x00030047'u32

  # Framebuffer
  TAG_ALLOCATE_FRAMEBUFFER* : MboxTag     = 0x00038001'u32
  TAG_SET_PHYSICAL_FB_SIZE* : MboxTag     = 0x00038003'u32
  TAG_SET_VIRTUAL_FB_SIZE*  : MboxTag     = 0x00038004'u32
  TAG_GET_FB_PITCH*         : MboxTag     = 0x00038006'u32
 
  # Clock IDs
  CLOCK_ID_EMMC*            : MboxTag    = 1'u32
  CLOCK_ID_UART*            : MboxTag    = 2'u32
  CLOCK_ID_ARM*             : MboxTag    = 3'u32 
  CLOCK_ID_CORE*            : MboxTag    = 4'u32 
  CLOCK_ID_V3D*             : MboxTag    = 5'u32
  CLOCK_ID_H264*            : MboxTag    = 6'u32
  CLOCK_ID_ISP*             : MboxTag    = 7'u32
  CLOCK_ID_SDRAM*           : MboxTag    = 8'u32
  CLOCK_ID_PIXEL*           : MboxTag    = 9'u32
  CLOCK_ID_PWM*             : MboxTag    = 10'u32

  # Voltage/Temperature IDs
  TEMP_ID_CORE*           : MboxTag     =   1'u32  # Core 
  VOLTAGE_ID_CORE*        : MboxTag     =   1'u32  # Core 
  UNUSED_ID*              : MboxTag     =   0'u32 


var lastResponseCtrVal : uint32 = uint32.high

proc hal_mbox0propertyChan8_getMBoxVal(idx : MBoxReg) : uint32 =
  return  hal_cpu_getDWord(cast[ptr uint](addr MBox0Base[idx]))

proc hal_mbox0propertyChan8_getMboxStatusVal*() : uint32 =
  return hal_mbox0propertyChan8_getMBoxVal(MBOX_STATUS) 

proc hal_mbox0propertyChan8_isMboxFull*() : bool = 
  return (( hal_mbox0propertyChan8_getMBoxVal(MBOX_STATUS) and statMBox_full) == 0x80000000.uint32 )

proc hal_mbox0propertyChan8_isMboxEmpty*() : bool = 
  return (( hal_mbox0propertyChan8_getMBoxVal(MBOX_STATUS) and statMBox_empty) == 0x40000000.uint32 )

proc hal_mbox0propertyChan8_setMBoxVal(idx : MBoxReg, val : uint32) =
    hal_cpu_storeDWord(cast[ptr uint](addr MBox0Base[idx]) ,val)    

var hal_mbox0propertyChan8_8bReq{.align(16).} : EightByteRequest 
var hal_mbox0propertyChan8_4bReq{.align(16).} : FourByteRequest 

var hal_mbox0propertyChan8_slot1{.align(16).} : EightByteRequest 
var hal_mbox0propertyChan8_slot2{.align(16).} : EightByteRequest 

template hal_mbox0propertyChan8_initEightByteRequest(targetTag : MboxTag, subSystem : MboxTag) =
  # message for clockrate
  hal_mbox0propertyChan8_8bReq.size = 32              # total size
  hal_mbox0propertyChan8_8bReq.code = REQUEST_CODE    # 
  hal_mbox0propertyChan8_8bReq.tag = targetTag
  hal_mbox0propertyChan8_8bReq.bufsize = 8           
  hal_mbox0propertyChan8_8bReq.tagreq = REQUEST_CODE  
  hal_mbox0propertyChan8_8bReq.rvals[0] = subsystem      
  hal_mbox0propertyChan8_8bReq.rvals[1] = 0   # fixed?
  hal_mbox0propertyChan8_8bReq.endtag = 0   # fixed

template hal_mbox0propertyChan8_initFourByteRequest(targetTag : MboxTag, subSystem : MboxTag) =
  # message for clockrate
  # TODO: 4 and 8 byte req is the same. 
  hal_mbox0propertyChan8_4bReq.size = 28              # total size
  hal_mbox0propertyChan8_4bReq.code = REQUEST_CODE    # 
  hal_mbox0propertyChan8_4bReq.tag = targetTag
  hal_mbox0propertyChan8_4bReq.bufsize = 4           
  hal_mbox0propertyChan8_4bReq.tagreq = REQUEST_CODE  
  hal_mbox0propertyChan8_4bReq.rvals[0] = subsystem      
  hal_mbox0propertyChan8_4bReq.endtag = 0   # fixed

template hal_mbox0propertyChan8_maskVCResponseChannelProp( resp : uint32) : uint32 =
  resp and 0xF.uint2

template hal_mbox0propertyChan8_maskVCResponseAddr( resp : uint32) : uint32 =
  resp and (not 0xF.uint32)  

template hal_mbox0propertyChan8_sendEightByteRequest() =   
  let msgAddr = cast[uint32](addr hal_mbox0propertyChan8_8bReq)
  let msgWithChan = msgAddr or chan8Prop # and 0xF.uint32)
  hal_mbox0propertyChan8_setMBoxVal(MBOX_WRITE,msgWithChan.uint32)

template hal_mbox0propertyChan8_sendFourByteRequest() =   
  let msgAddr = cast[uint32](addr hal_mbox0propertyChan8_4bReq)
  let msgWithChan = msgAddr or chan8Prop # and 0xF.uint32)
  hal_mbox0propertyChan8_setMBoxVal(MBOX_WRITE,msgWithChan.uint32)  

template hal_mbox0propertyChan8_hasVCResponse*() : bool =
  (hal_mbox0propertyChan8_getMBoxVal(MBOX_STATUS) and 0xf.uint32) > lastResponseCtrVal # == 1 

template hal_mbox0propertyChan8_getVCResponse*() : uint32 =
  hal_mbox0propertyChan8_getMBoxVal(MBOX_READ)




proc hal_mbox0propertyChan8_isResponseOK*(propTarget : PropertyTarget) : bool =
   result = case propTarget:
    of MacAddr,ArmFrequencyMeasured,CoreFrequencyMeasured,CoreTemp,CoreVoltage,MemoryVC,MemoryArm,BoardSerial:
      hal_mbox0propertyChan8_8bReq.code == RESPONSE_OK
    of FirmwareRevision,BoardModel,BoardRevision:
      hal_mbox0propertyChan8_4bReq.code == RESPONSE_OK        
    else:
      false


proc hal_mbox0propertyChan8_sendVCRequest*(propTarget : PropertyTarget) =
  lastResponseCtrVal = (hal_mbox0propertyChan8_getMBoxVal(MBOX_STATUS) and 0xf.uint32)
  case propTarget:
    of PropertyTarget.MacAddr:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_MAC_ADDRESS,UNUSED_ID)
      hal_mbox0propertyChan8_sendEightByteRequest          
    of PropertyTarget.ArmFrequencyMeasured:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_CLOCK_RATE_MEASURED,CLOCK_ID_ARM)
      hal_mbox0propertyChan8_sendEightByteRequest      
    of PropertyTarget.CoreFrequencyMeasured:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_CLOCK_RATE_MEASURED,CLOCK_ID_CORE)
      hal_mbox0propertyChan8_sendEightByteRequest
    of PropertyTarget.CoreTemp:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_TEMPERATURE,TEMP_ID_CORE)
      hal_mbox0propertyChan8_sendEightByteRequest
    of PropertyTarget.CoreVoltage:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_VOLTAGE,VOLTAGE_ID_CORE)
      hal_mbox0propertyChan8_sendEightByteRequest   
    of PropertyTarget.MemoryVC:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_VC_MEMORY,UNUSED_ID)
      hal_mbox0propertyChan8_sendEightByteRequest     
    of PropertyTarget.MemoryArm:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_ARM_MEMORY,UNUSED_ID)
      hal_mbox0propertyChan8_sendEightByteRequest    
    of PropertyTarget.BoardSerial:
      hal_mbox0propertyChan8_initEightByteRequest(TAG_GET_BOARD_SERIAL,UNUSED_ID)
      hal_mbox0propertyChan8_sendEightByteRequest
    of PropertyTarget.FirmwareRevision:
      hal_mbox0propertyChan8_initFourByteRequest(TAG_GET_VC_FIRMWARE_REVISION,UNUSED_ID)
      hal_mbox0propertyChan8_sendFourByteRequest 
    of PropertyTarget.BoardRevision:
      hal_mbox0propertyChan8_initFourByteRequest(TAG_GET_BOARD_REVISION,UNUSED_ID)
      hal_mbox0propertyChan8_sendFourByteRequest
    of PropertyTarget.BoardModel:
      hal_mbox0propertyChan8_initFourByteRequest(TAG_GET_BOARD_MODEL,UNUSED_ID)
      hal_mbox0propertyChan8_sendFourByteRequest         
    else:
      discard

proc hal_mbox0propertyChan8_getRawValueFor*(propTarget : PropertyTarget) : VCRawResponse =
  result = case propTarget:
    of FirmwareRevision,BoardRevision,BoardModel:
      discard hal_mbox0propertyChan8_getVCResponse
      (hal_mbox0propertyChan8_4bReq.rvals[0],0)
    of MacAddr,MemoryArm,MemoryVC,BoardSerial:
      discard hal_mbox0propertyChan8_getVCResponse
      (hal_mbox0propertyChan8_8bReq.rvals[0],hal_mbox0propertyChan8_8bReq.rvals[1])
    of ArmFrequencyMeasured,CoreFrequencyMeasured,CoreTemp,CoreVoltage:
      discard hal_mbox0propertyChan8_getVCResponse
      ( hal_mbox0propertyChan8_8bReq.rvals[1] , 0 )
    else:
      (0,0)


proc processMboxRequests*() = 
  discard