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
# most examples are from the nimdocs

import std/[os,strutils,times,volatile,macros,lists,math,streams,typetraits,syncio]
import core/hal/hal
import core/[env,nvram,event,xresourcelock,gpio]
import core/utils/[charbuffer,memorystream]

from std/fenv import epsilon
from std/random import rand


type
  TextException = object of CatchableError

template toHex(mptr : ptr uint) : string =
  toHex(cast[uint](mptr),8)

template toHex(mptr : pointer) : string =
  toHex(cast[uint](mptr),8)  

var dingdongstack : uint = 0

proc raiseEx() =
  # just throw an exception 
  echo "before_raise_ex"
  raise newException(TextException, "ding-dong-exception")

proc doRaiseEx()=
  raiseEx()

proc generateGaussianNoise(mu: float = 0.0, sigma: float = 1.0): (float, float) =
  # Generates values from a normal distribution.
  # Translated from https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform#Implementation.
  var u1: float
  var u2: float
  while true:
    u1 = rand(1.0)
    u2 = rand(1.0)
    if u1 > epsilon(float): break
  let mag = sigma * sqrt(-2 * ln(u1))
  let z0 = mag * cos(2 * PI * u2) + mu
  let z1 = mag * sin(2 * PI * u2) + mu
  (z0, z1)



proc halRegDumpAndStackDumpTest() = 
  var srcrd : ArmCpuState
  hal_cpu_saveAllRegisters(addr srcrd.r)
  hal_cpu_saveSP(addr srcrd)
  hal_cpu_saveLR(addr srcrd)
  hal_cpu_saveCPSR(addr srcrd)

  let sptr = hal_cpu_readSP()

  echo "==BEGIN register-dump ====="
  echo $(srcrd.addr)
  echo "==END register-dump ===="
  echo "==BEGIN stackdump ==="
  debugutil_dumpMem2StdOut(sptr,20)
  echo "==END stackdump ==="

proc usrProcess( pid : ProcessID, customVal : uint ) : int  =
  var loopctr : int = 0

  echo "enter loop"
  hal_uart_0_strout_blocking "process entered",14
  while loopctr < 10+pid :
    inc loopctr
    echo "loopctr " & $loopctr
    if loopctr == 6 and pid == 1:
       raise newException(TextException, "unhandled_hello_exception")
    if loopctr > 3 and loopctr < 7 and pid == 5:
      resume()
    elif pid == 4 and loopctr == 2:
        let rh = xLockResource(1)
        echo "I alloceded a resource " & $rh
    elif pid == 4 and loopctr == 11:
        freeResource(1)    
    elif pid == 6 and loopctr == 5:
      echo "resource allocated " & $xLockResource(1)
    elif pid == 6 and loopctr == 13:
      freeResource(1)  
    elif pid == 2 and loopctr == 5:
      halRegDumpAndStackDumpTest()  
    else:
      sleep 800

  echo "exit loop"
  21

proc raiseAndCatchExTest() : int =
  echo " barebone example with Nim"
  try:
    doRaiseEx() 
  except: 
    echo "caught exception "  & getCurrentExceptionMsg()   
    echo getCurrentException().getStackTrace()   # todo: seems not to work. eval.
  finally:
    echo "finally block entered"


type Animal = ref object of RootObj
  name: string
  age: int
method vocalize(self: Animal): string {.base.} = "..."
method ageHumanYrs(self: Animal): int {.base.} = self.age

type Dog = ref object of Animal
method vocalize(self: Dog): string = "woof"
method ageHumanYrs(self: Dog): int = self.age * 7

type Cat = ref object of Animal
method vocalize(self: Cat): string = "meow"

proc testOOP() =
  
  var animals: seq[Animal] = @[]
  animals.add(Dog(name: "Sparky", age: 10))
  animals.add(Cat(name: "Mitten", age: 17))

  for a in animals:
    echo a.vocalize()
    echo a.ageHumanYrs()


proc streamsTest() = 
  
  var x = "test"
  echo x

  var strm = newStringStream("""The first line
  the second line
  the third line""")

  var line = ""
  
  while strm.readLine(line):
    echo line

  strm.close()



proc stackSentinelTest() = 
  echo "isIRQStackTampered: ",$isIRQStackSentinelTampered()
  echo "isSUPVStackTampered: ",$isSupvStackSentinelTampered()
  echo "isSYSStackTampered: ",$isSysStackSentinelTampered()

proc miscMathTest() = 
  echo "eulers number is ", $E
  echo generateGaussianNoise()
  echo "sqrt(144): ",  $sqrt(144.float)


####################################################################

proc initBoard*(){.exportc:"_initialize_custom",cdecl.} =
  # called before NimMain - the heap is initialized but not the runtime
  # irqs are disabled per default
  echo " init-board: called "
                

proc doTestAll()=
  discard raiseAndCatchExTest()
  # seems ex ends in global ex-handler. eval why

  halRegDumpAndStackDumpTest()

  miscMathTest()
  testOOP()
  streamsTest()

  newlibMalloc_stats()
  echo $newlibMall_info()

  echo "armtimertick_resolution_nanos: " & $hal_armTimerTickResolutionNanos

  echo "stack_after_tests is:",toHex(hal_cpu_readSP()) 
  echo "pc at ",toHex(hal_cpu_readPC())

  stackSentinelTest()

  
  echo "type 'P' to spawn new process - after that the pid to start (0-9) - 'x' to exit demo"

  runtimeDispatcherDemoWithExit('x',usrProcess)


  echo "current armtimer resolution is (nanos) " & $hal_armtimerTickResolutionNanos

  echo "softrtc-counter is: " & $volatileLoad( addr softRtc)

try:
  deployExceptionHandlerHooks()
  initializeEnvironment()

  doTestAll()
  
except Defect:
  # Catches the assert in `panics:off` mode, shows "uncaught defect" warning in `panics:on` mode (no change)
  echo "defect"
except:
  hal_uart_0_strout_blocking("global_ex:",10)
finally:
  stackSentinelTest()
  while uartOutputBuffer.hasVal(): # flush buffer blocking variant
    let x = uartOutputBuffer.fetchVal()
    hal_uart_0_putc_blocking(x)
  when board == "raspberry_pi1":    
    enterMemLoader()   
