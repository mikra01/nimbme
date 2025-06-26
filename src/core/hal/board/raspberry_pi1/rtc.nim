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

{.emit"""
__attribute__((section(".nvram")))
extern unsigned long long _soft_rtc_counter = 0;
""".}

var softRtc*{.importc:"_soft_rtc_counter".} : culonglong

# rtc not precent
proc hal_rtc_regRead(ad: uint): uint {.inline.} =
  0

proc hal_rtc_regWrite(ad: uint, value: uint) {.inline.} =
  discard

proc hal_rtc_enableRtcInterrupt() =
  discard

proc hal_rtc_setRtcAlarm(seconds: int64) =
  discard
 
proc hal_rtc_setAlarm(epoch : int64, callback : proc()) = 
    discard

template hal_rtc_GetTime*(): int64 =
   cast[int64](volatileLoad(addr softRtc))

template hal_rtc_SetTime*(epoch: int64) =
  volatileStore(addr softRtc,cast[culonglong](epoch))

proc hal_rtc_initRtc*() = 
  discard

template hal_rtc_isRtcSet*() =
  if hal_rtc_GetTime() > 1750180617:
    true
  false