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
import stdtypes, envtypes

# event handling impl
proc initializeEvents*(evts : ptr Events) =
  for i in 0..evts.elist.len-1:
    evts.elist[i].free = true
    evts.elist[i].triggered = false

template isEventTriggered*(evts : var Events, src : EventSource  ) : bool =
  evts.elist[src.ord].triggered

template isWaiting*(evts : var Events, src : EventSource  ) : bool =
  not evts.elist[src.ord].free

proc defaultEventCallback*()=
  discard

template registerEvent*(el : var Events, eventType : EventSource, ecb : EventCallback = defaultEventCallback, cVal : uint = 0)  =
  el.elist[eventType.ord].free = false
  el.elist[eventType.ord].cb = ecb
  el.elist[eventType.ord].customVal = cval
  
template freeEntry*(el : var Events, eventType : EventSource) =
  el.elist[eventType.ord].free = true

