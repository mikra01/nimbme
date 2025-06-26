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
import ../envconfig

const err1_proc_unable_to_execute* : string = "proc with type:free is not runnable"
const err2_proc_all_slots_occupied* : string = "no processes free "
const err3_proc_stackpool_outOfSlots* : string = "no free stackbuffer slots"
const err4_proc_invalid_id* : string = "process id invalid"
const err5_proc_unable_to_restart* : string = "unable to restart. process is not in state: Suspended"

const errIDs : array[5,string] = [err1_proc_unable_to_execute,
  err2_proc_all_slots_occupied,err3_proc_stackpool_outOfSlots,err4_proc_invalid_id,err5_proc_unable_to_restart]

type
    AuditSrc* = enum  Runtime = 0, Event = 1, Monitor = 3, CPU = 4 
    ErrorKind* = enum Exception, Error, Warning, Info
    AuditTrailLogEntry* = tuple[source : AuditSrc, errKind: ErrorKind, msg : string]

var auditTrailQueue* : CBuffer[AuditTrailEntrySize,AuditTrailLogEntry]

# TODO: find solution on very small envs / log only err-ids?

proc logEnvAuditTrail*(src : AuditSrc, errorKind : ErrorKind, errId : int ) =
  auditTrailQueue.putVal( (source:src,errKind : errorKind, msg: errIDs[errId]) )
  echo errIDs[errId]

proc logCpuAuditTrail*(msg : string)=
  discard  