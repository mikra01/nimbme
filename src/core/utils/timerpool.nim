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

import ../../envconfig

type 
  TimerPool* = object
    millisCorrectionVal: uint 
    allTimers : array[SoftTimerPoolSize,Timer]
    lastTickVal : uint
    allocTimersCount: int = 0
    freeTimersCount: int = 0
    poolIdle: bool
    skewInfo : uint = 0

  TimerPoolEventCallback* = proc (tp : var TimerPool, idx : int){.cdecl.}
 
  Timer = object
    # the timer is active if alarmctr > 0 and not freed
    alarmctr: uint # countdown field
    isFree: bool # true if the owner of this timer is the pool
    callback : TimerPoolEventCallback
    udval : uint
    udval2 : uint

proc `$`*(f: Timer): string {.inline.} =
  "Timer: alarmctr " & $f.alarmctr & " isFree:" & $f.isFree & " udval " & $f.udval 

proc `$`*(f: TimerPool): string {.inline.} =
  "TimerPool: timebase" & $f.millisCorrectionVal & " lastTickVal " & $f.lastTickVal & 
  " alloc: " & $f.allocTimersCount & 
  " free: " & $f.freeTimersCount & 
  " skewInfo:" & $f.skewInfo & $f.allTimers

proc `=copy`*(a: var TimerPool, b: TimerPool){.error.} 

# timer_state templates
proc isTimerRunning( tp: var TimerPool, idx : int): bool=
  if idx >= 0:
    return (not tp.allTimers[idx].isFree) and tp.allTimers[idx].alarmctr > 0
  return false

proc findFreeTimerIdx(tp : var TimerPool ): int {.inline.} =
  # searches for an unused timerhdl (isFreed)
  # -1 is returned if no unused timerhdl present
  result = -1
  for i in 0 .. tp.allTimers.len - 1:
    if tp.allTimers[i].isFree:
      result = i 
      break
  return result

proc periodicTimebasedWorkLoop*( tp : var TimerPool, tickVal : uint) =
  # called each time a new event happens
  #var ctrUpdateSkew : uint = 1
  var lastTickval = tp.lastTickval
  if lastTickval == 0:
    tp.lastTickval = tickVal
    return
  tp.lastTickval = tickVal
 
  var diff : uint = 0
  
  if tickVal < lastTickval:
    diff = uint32.high - lastTickval + tickVal
  else:
    diff =  tickVal - lastTickVal

  diff = diff div tp.millisCorrectionVal

  if diff == 0:
    diff = 1

  for i in 0 .. tp.allTimers.len - 1:
    if tp.isTimerRunning(i):
      tp.allTimers[i].alarmctr.dec diff
      if tp.allTimers[i].alarmctr <= 0:
        if not tp.allTimers[i].callback.isNil:
          tp.allTimers[i].callback(tp,i)
     

type
  PoolStats* = tuple[runningCount: int,
                      freeCount: int]

type
  Tickval* = range[1..int.high]
  MinTimerval* = range[1..int.high]
    
proc initTimerPool*(tp : var TimerPool, tbase_ms: uint) =
  tp.millisCorrectionVal = tbase_ms 
  tp.poolIdle = true 
  tp.lastTickVal = 0
  tp.freeTimersCount = tp.allTimers.len-1

  for i in 0 .. tp.allTimers.len - 1:
    tp.allTimers[i].isFree = true

     
proc setAlarmMillis*(tpool : var TimerPool, timerNum : int, millisec : uint) =
  if timerNum >= 0:
    tpool.allTimers[timerNum].alarmctr = millisec

proc setUdVal*(tpool : var TimerPool, timerNum : int, val : uint) =
  if timerNum >= 0:
    tpool.allTimers[timerNum].udval = val

proc getUdVal*(tpool : var TimerPool, timerNum : int) : uint =
  if timerNum >= 0:
    return tpool.allTimers[timerNum].udval


proc defaultRestartCallback(tp : var TimerPool, timerNum : int){.cdecl.} =
  if tp.getUdVal(timerNum) > 0:
    tp.setAlarmMillis(timerNum,(tp.getUdVal(timernum)))


proc allocTimer*(tp: var TimerPool, userVal : uint): int =
  # timernumber or -1 (in case of no timers free) returned
  tp.poolIdle = false
  let idx = tp.findFreeTimerIdx()
  if idx >= 0:
    inc tp.allocTimersCount
    dec tp.freeTimersCount
    tp.allTimers[idx].isFree = false
    tp.allTimers[idx].alarmctr = 0   
    tp.allTimers[idx].udval = userVal
    tp.allTimers[idx].callback = defaultRestartCallback

  return idx
  

proc allocTimer*(tp: var TimerPool, cb : TimerPoolEventCallback, userVal : uint): int =
  # timernumber or -1 (in case of no timers free) returned
  tp.poolIdle = false
  let idx = tp.findFreeTimerIdx()
  if idx >= 0:
    inc tp.allocTimersCount
    dec tp.freeTimersCount
    tp.allTimers[idx].isFree = false
    tp.allTimers[idx].alarmctr = 0   
    tp.allTimers[idx].udval = userVal
    tp.allTimers[idx].callback = cb

  return idx


proc deallocTimer*(tpool : var TimerPool, timerNum: int) =
  if timerNum >= 0:
    if not tpool.allTimers[timerNum].isFree:
      inc tpool.freeTimersCount 
      dec tpool.allocTimersCount
      tpool.allTimers[timerNum].isFree = true


proc getPoolStats*(tp: var TimerPool): PoolStats =
  result.runningCount = tp.allocTimersCount
  result.freeCount = tp.freeTimersCount

