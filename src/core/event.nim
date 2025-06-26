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

import ../envconfig

# event handling impl
type
  #EventSrc* = enum IRQ_hw = 0,IRQ_sw,Device_sw,Process_sw
  #EventPri* = enum High=0, Medium, Low

  EventType* = enum
    TIMEROVERFLOW = 1.uint8, 
    RESET_STATE = 2 # calls init and clears all events
    HWDEVICE= 3     # hardware dependent generic event
    SOFTDEVICE = 4  # event triggered through sw
    TIMER_WAIT = 5
    TIMER_FINISHED = 6
    BufferIn
    BufferOut
  
  EventMsg* = tuple[evt : EventType, customVal : int]
  EventEntry = tuple[msg:EventMsg, free: bool]

type
  EventStore*[n : static[int], EventEntry] = object
    used  : uint16 = 0
    free  : uint16 = 0
    events : array[UserProcessEventSlots,EventEntry]


proc registerEntry[n,EventEntry](eventStore : EventStore[n,EventEntry], eventType : EventType) : int =
  discard

template freeEntry[n,EventEntry](eventStore : EventStore[n,EventEntry], id : int) =
  eventStore[id].free = true


# distinquish between hw generated events, sw events, low prio and high prio
proc newWaitEventMicrosec*(durationMicrosec : int) = 
  discard

proc newWaitEventNanosec*(durationNanosec : int) = 
  discard
