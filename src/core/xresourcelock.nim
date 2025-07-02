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

import utils/circularbuffer
import stdtypes, envtypes

# exclusive generic resource lock

template isFreeRequest*(rq: ResourceRequest) : bool =
  rq.rqtype == ResourceRequestType.RRFree
# implement waiting queue for alloc requests & test.
# 
# check what happens if waiting is performed on resource and timer  

proc xLockResource*(rId : ResourceID) : ResourceHandle {.cdecl,exportc.}  =
    var mypid : ProcessID = getActivePID()
    if isValidPID(mypid):
      environmentContext.resourceRequestQueue.putVal( (resourceId: rId,pid: mypid, rqtype:ResourceRequestType.Alloc))
      switchCTXTo(PID_SYS)
      #switchContext(cast[StackPointer](addr environmentContext[mypid].stackPtr),cast[int](environmentContext.sysSP))
      # FIXME: if you allocate an resource which is blocked, result is: INIT. result should be: BLOCKED with blocking pid
      result = environmentContext[mypid].resourceRequestResult

proc xLockResourceWithWait(rId : ResourceID, timeout_ms : int) : ResourceHandle  =
    # alloc resource with wait / blocking call
    discard

proc freeResource*(rId : ResourceID ) =
    let mypid = getActivePID()
    if isValidPID(mypid):
      environmentContext.resourceRequestQueue.putVal( (resourceId: rId, pid:mypid, rqtype: RRFree) )

