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

# retargeted syscalls 
# contain board/platform dependent code (references some linkerscript variables/memory)
# todo: recompile newlib for non-reeentrant mode
# wip

import ../../env


# _fwrite_r
type sizeT {.importc: "size_t", header:"<stddef.h>", final, pure.} = object
var errno {.importc, header: "<errno.h>".}: cint
let EBADF {.importc:"EBADF",nodecl.} : cint

proc write( filedesc : cint, data : cstring, size : cint) : cint {.exportc:"_write",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # hal_uart_0_strout "wg"
  errno = 0.cint
  # retarget newlib's write 
  # file: stdin = 0 / stdout = 1 / stderr = 2
  # let p = $data
  if filedesc >= 0 and filedesc <= 2:
    #when uartUseBufferedOut:
    #  when UserDebugEchoPID:
    #    let pid = getActivePID()
    #    if pid < 99:
    #      uartOutputBuffer.putVal(cast[char](pid+0x30))
    #      uartOutputBuffer.putVal(':')
    #  
    #  for i in 0 .. size-1:
    #    uartOutputBuffer.putVal(data[i])
    #else:
      when UserDebugEchoPID:
        let pid = getActivePID()
        if pid < 99:
          hal_uart_0_chrout_blocking(cast[char](pid+0x30))
          hal_uart_0_chrout_blocking(':')

      for i in 0 .. size-1:
        hal_uart_0_chrout_blocking(data[i])
        
    
  else:
    errno = EBADF
    return -1
  return size

  #size_t fwrite(const void *<[buf]>, size_t <[size]>,
  #	      size_t <[count]>, FILE *<[fp]>);

#proc fWrite( arr : pointer, arrsize: size_t, elemcount : size_t , fp : pointer ) : size_t {.exportc:"fwrite",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} = 
#  return elemcount


proc newlibRaise( signum : cint ) : cint {.exportc:"_raise",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =  
  hal_cpu_resetBoard()
  

proc newlibExit(status : cint) {.exportc:"_exit",codegenDecl: "$# __attribute__((used)) $#$#",cdecl,noreturn.} =
  # hal_uart_0_echo_sync(toHex(status,5),5)
  hal_cpu_resetBoard()


{.emit: """ 
  #include <errno.h>
  #include <sys/stat.h>

  char *__env[1] = {0};
  char **environ = __env;
                                                                      	         
""".}  

const CLOCK_THREAD_CPUTIME_ID = 3  


# todo: eval if import extern values as procs occupies no ram

let EINVAL {.importc:"EINVAL",nodecl.}:cint
let ENOMEN {.importc:"ENOMEM",nodecl.}:cint


var myHeapPtr : clong = 0
var myStackPtr : clong = 0

# fixme: move 2 stats section
var newlib_bytesMalloc* : uint = 0
var newlib_freecounter* : uint = 0
var newlib_malloccounter* : uint = 0
var newlib_bytesRealloc* : uint = 0
var sys_total_heapsize* : uint = 0
var sys_total_stacksize* : uint = 0

type
 Mallinfo* {.importc: "struct mallinfo", header:"<malloc.h>", final, pure.} = object
   arena : cint    # /* total space allocated from system */
   ordblks : cint  # /* number of non-inuse chunks */
   smblks : cint   # /* unused -- always zero */
   hblks : cint    # /* number of mmapped regions */
   hblkhd : cint   # /* total space in mmapped regions */
   usmblks : cint  # /* unused -- always zero */
   fsmblks : cint  # /* unused -- always zero */
   uordblks : cint # /* total allocated space */
   fordblks : cint # /* total non-inuse space */
   keepcost : cint # /* top-most, releasable (via malloc_trim) space */


proc newlibMalloc_stats*(){.cdecl,used,importc:"malloc_stats".}
proc newlibMall_info*() : Mallinfo {.cdecl,used,importc:"mallinfo".}


proc newlibPrintSysvals() = 
  echo "sysvals"
  echo "heap_abs_start:" & toHex(cast[uint](initialFreememPtr.addr))
  echo "stack_abs_end:" & toHex(cast[uint](initialStackPtr.addr))
  echo "myh "  & $myHeapPtr
  echo "mystk " & $myStackPtr
  echo "sys_total_heapsize: " & toHex(sys_total_heapsize)
  echo "sys_total_stacksize: " & toHex(sys_total_stacksize)
  echo "heap_used " & toHex(myHeapPtr - cast[clong](initialFreememPtr.addr))
  echo "malloc_count: ",$newlib_malloccounter
  echo "free_count: ",$newlib_freecounter
  

proc setup_heap(){.exportc:"_setup_heap",cdecl.} =
     myHeapPtr = cast[cint](initialFreememPtr.addr)
     myStackPtr = cast[cint](initialStackPtr.addr)
     sys_total_heapsize = cast[uint](freememEndPtr.addr) - (cast[uint](initialFreememPtr.addr))
     sys_total_stacksize = cast[uint](stackTopPtr.addr) - (cast[uint](initialStackPtr.addr))


proc newlibSbrk( nbytes : cint ) : cint {.exportc:"_sbrk",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
  ## called when the heap needs to grow number of nbytes  
  if (myHeapPtr + nbytes) < cast[cint](freememEndPtr.addr):
    result = myHeapPtr
    myHeapPtr = myHeapPtr + nbytes
  else:
     errno = ENOMEN 
     result = -1.cint

# char *fgets(char *restrict <[buf]>, int <[n]>, FILE *restrict <[fp]>);
# fgets symbol is pointing to garbage so we implement it here
#proc newlibFgets(buf : ptr char, len : cint, fileptr : pointer) : pointer{.exportc:"fgets",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
#  # blocking read till '\n' received
#  hal_uart_0_echo_sync("fgets",5)
#  return cast[pointer](buf)
 
#proc mallocLock( nbytes : cint ) : cint {.exportc:"__malloc_lock",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
#  ## todo: implement for reentrant malloc
#  discard

#proc mallocUnlock( nbytes : cint ) : cint {.exportc:"__malloc_unlock",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
#  ## todo: implement for reentrant malloc
#  discard

#proc envLock( nbytes : cint ) : cint {.exportc:"__env_lock",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
#  ## todo: implement for reentrant variable pool
#  discard

#proc envUnlock( nbytes : cint ) : cint {.exportc:"__env_unlock",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
#  ## todo: implement hook for reentrant variable pool
#  discard

#proc sysFork( nbytes : cint ) : cint {.exportc:"_fork",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
#  ## todo: implement if system() or fork() called. todo: check posix spawn
#  discard
  
proc newlibGetPid() : cint {.exportc:"_getpid",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  return cast[cint](getActivePID())

proc newlibIsatty(filedesc : cint) : cint {.exportc:"_isatty",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # hal_uart_0_echo_sync("isatty_called",7)
  #if filedesc >= 0 and filedesc <= 2:
  #      return 1.cint
  return 1.cint

proc newlibKill( pid : cint, sig : cint ):cint {.exportc:"_kill",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =  
  errno = EINVAL
  return -1.cint

let EMLINK {.importc:"EMLINK",nodecl.} : cint

# following file handling impl is the minimal uart-version

proc newlibLink( charptr_old : pointer,charptr_new : pointer, ):cint {.exportc:"_link",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =  
  # rename existing file
  errno = EMLINK
  return -1.cint

proc newlibLseek( filedesc , offset, whence : cint) : cint {.exportc:"_lseek",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =  
  return 0 # stdout is always at begin

let EAGAIN {.importc:"EAGAIN",nodecl.} : cint
let EACCES {.importc:"EACCES",nodecl.} : cint
let ENOSYS {.importc:"ENOSYS",nodecl.} : cint
let ENOENT {.importc:"ENOENT",nodecl.} : cint

proc newlibClose( filedesc : cint) : cint {.exportc:"_close",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} = 
  errno = EBADF
  return -1.cint # error - no filesys present 
  
proc newlibOpen( charptr_name : pointer, flags, mode : cint) : cint {.exportc:"_open",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} = 
  hal_uart_0_strout_blocking "open called",10
  errno = ENOSYS
  return 0.cint # error 


proc newlibRead(filedesc : cint, charptr : pointer, len : cint) : cint {.exportc:"_read",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # blocking call - only usable for demo purposes

  while not ( uartInputBuffer.seek(CR) > 0 or uartInputBuffer.seek(0x0.char) > 0 or 
    uartInputBuffer.seek(config_consoleNewlineChar) > 0):  # blocking variant for testing only
    discard

  var istr = uartInputBuffer.toString()

  var cp : ptr char = cast[ptr char](charptr)
  var incp : uint = cast[uint](cp)

  for i in 0 .. istr.len-1:
    cp[] = cast[char](istr[i])
    inc incp
    cp = cast[ptr char](incp)

  when uartEchoOnInput:
    hal_uart_0_writestr(istr.cstring,istr.len.cint)  

  return (istr.len).cint 


type modeT {.importc: "mode_t", header:"<stddef.h>", final, pure.} = object
let SIFCHR {.importc:"S_IFCHR",nodecl.} : modeT
let NOBUF {.importc:"_IONBF",header:"<stdio.h>".} : cint
type devT {.importc: "dev_t", header:"<stddef.h>", final, pure.} = object
type inoT {.importc: "ino_t", header:"<stddef.h>", final, pure.} = object
type nlinkT {.importc: "nlink_t", header:"<stddef.h>", final, pure.} = object
type uidT {.importc: "uid_t", header:"<stddef.h>", final, pure.} = object
type gidT {.importc: "gid_t", header:"<stddef.h>", final, pure.} = object
type offT {.importc: "off_t", header:"<stddef.h>", final, pure.} = object

type Stat{.importc:"struct stat",header:"<sys/stat.h>",final,pure.} = object
   st_dev : devT
   st_ino : inoT
   st_mode : modeT
   st_nlink : nlinkT
   st_uid : uidT
   st_gid : gidT
   st_rdev : devT
   st_size : offT


proc newlibStat(charptr_file : pointer, stat : ptr Stat) : cint {.exportc:"_stat",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  hal_uart_0_strout_blocking "stat called",10
  stat.st_mode = SIFCHR
  return 0
 
proc newlibfini() : cint {.exportc:"_fini",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  errno = EAGAIN
  return -1

proc newlibFork() : cint {.exportc:"_fork",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  errno = EAGAIN
  return -1

proc newlibExecve( charptr_name : pointer, charptrptr_argv : pointer, charptrptr_env : pointer) : cint {.exportc:"_execve",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # transfer control to a new process
  errno = ENOMEN
  return -1


proc newlibFStat( filedesc : cint, st : ptr Stat) : cint {.exportc:"_fstat",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  hal_uart_0_strout_blocking "fstat called",12
  errno = 0
  st.st_mode = SIFCHR # 

  #if newlibIsatty(filedesc) == 1.cint:
  #  return 0.cint

  return 0.cint #char device

#proc newlibUnlink( charptr_name : pointer ) : cint {.exportc:"_unlink",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
#  # remove files directory entry
#  errno = ENOENT
#  return -1 

let ECHILD {.importc:"ECHILD",nodecl.} : cint

#proc newlibWait( intptr_status : pointer ) : cint {.exportc:"_wait",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
#  # remove files directory entry
#  errno = ECHILD
#  return -1 

proc newlibAbort()  =  # see boardapi.nim
  # todo: raise(SIGABRT)
  hal_cpu_resetBoard()

type
 ClockT{.importc:"clock_t", header:"",final,pure} = object
 Tm* {.importc: "struct tm", header: "<time.h>", final, pure.} = object
      tm_sec*: cint   ## Seconds [0,60].
      tm_min*: cint   ## Minutes [0,59].
      tm_hour*: cint  ## Hour [0,23].
      tm_mday*: cint  ## Day of month [1,31].
      tm_mon*: cint   ## Month of year [0,11].
      tm_year*: cint  ## Years since 1900.
      tm_wday*: cint  ## Day of week [0,6] (Sunday =0).
      tm_yday*: cint  ## Day of year [0,365].
      tm_isdst*: cint ## Daylight Savings flag.

 Tms {.importc: "struct tms", header: "<time.h>", final, pure.} = object
   tms_utime* : ClockT
   tms_stime*:  ClockT
   tms_cutime* : ClockT
   tms_cstime* : ClockT


 Timespec{.importc:"struct timespec",header:"<time.h>",final,pure.}  = object 
    tv_sec : int64    # seconds
    tv_nsec : int64   # nanoseconds

proc `$`*(f: ptr Timespec): string =
  "timespec tv_sec: " & $f.tv_sec & " tv_nsec "  & $f.tv_nsec  


type ClockIdT {.importc: "clockid_t", header:"<time.h>", final, pure.} = object
type UseConds {.importc: "useconds_t", header:"<sys/types.h>",final,pure.} = object

#const 
#  ClockRealTime : ClockIdT = 0          # changeable clock 
#  ClockMonotonic : ClockIdT = 1         # unresettable clock - implemented
#  ClockProcessCpuTimeId : ClockIdT = 2  # setable per process clock
#  ClockThreadCpuTimeId : ClockIdT = 3

# workaround for const import
proc ClockRealTimex(){.importc:"CLOCK_REALTIME",header:"<time.h>".}
proc ClockMonotonicx(){.importc:"CLOCK_MONOTONIC_RAW",header:"<time.h>".}
proc ClockProcessCpuTimeIdx(){.importc:"CLOCK_PROCESS_CPU_TIME_ID",header:"<time.h>".} # category high precision timing
proc ClockThreadCpuTimeIdx(){.importc:"CLOCK_THREAD_CPU_TIME_ID",header:"<time.h>".} # category high precision timing

# TODO: make it more generic # timerresolution of 1us assumed here
proc newlibClockGetTime(cid : ClockIdT , ts : ptr Timespec) : cint {.exportc:"clock_gettime",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # impl for clockid_t = 1 CLOCK_REALTIME
  if cid == cast[ClockIdT](ClockRealTimex):
    ts.tv_sec = cast[int64](hal_rtc_GetTime() div 1000) 
  elif cid == cast[ClockIdT](ClockMonotonicx):
    ts.tv_sec = (cast[int64](hal_systemtimer_getTStamp64())) div (boardcfg_systemtimerTimerResolution_millis * 1000).int64
  
  return 0 

proc newlibClockSetTime(cid : ClockIdT , ts : ptr Timespec) : cint {.exportc:"clock_settime",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # impl for clockid_t = 1 CLOCK_REALTIME
  if cid == cast[ClockIdT](ClockRealTimex):
    hal_rtc_SetTime(ts.tv_sec * 1000)
 
  return 0 


proc usleep(useconds : UseConds) : cint {.exportc,codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  = 
  echo "usleep called"
  return 0

proc sleep(seconds : cuint) : cint {.exportc,codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  =
  echo "sleep called"
  return 0

#int nanosleep(const struct timespec *req, struct timespec *rem)

proc nanosleep(rqtp : ptr Timespec, rmtp : ptr Timespec) : cint {.exportc,codegenDecl: "$# __attribute__((used)) $#$#",cdecl.}  = 
  if not isSys(getActivePID()): # sys never sleeps
    waitAndResume(cast[uint](rqtp.tv_nsec div 1000000)) #rqtp.tv_nsec div 1000000
  return 0

proc clock_nanosleep(clockId: ClockIdT, flags : int, rqtp : ptr Timespec, rmtp : ptr Timespec) : cint {.exportc,codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} = 
  echo "clock_nanosleep called with " & $rqtp & " and " & $rmtp
  return 0


# TODO: impl
#int _EXFUN(clock_settime, (clockid_t clock_id, const struct timespec *tp));
#int _EXFUN(clock_gettime, (clockid_t clock_id, struct timespec *tp));
#int _EXFUN(clock_getres,  (clockid_t clock_id, struct timespec *res));

# when board == "raspberry_pi1":
# todo: hint on tls
# arm11 is A-Profile, so TPIDRURW should be present
# hint on mc
# per core: own scheduler, heap, tls / proc is always pinned (no mig) 

proc newlibTimes( tms: ptr Tms) : cint {.importc:"_times",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  errno = EACCES
  return -1

proc setvBuf*(f : File, buf : ptr char, mode : cint, s : sizeT ){.cdecl,used,importc:"malloc_stats".}

proc disableStdioBuffs()=
  setvBuf(stdout, nil, NOBUF, cast[sizeT](0));
  setvBuf(stdin, nil, NOBUF, cast[sizeT](0));
  setvBuf(stderr, nil, NOBUF, cast[sizeT](0));


# FIXME: impl posix realtime signal handling
type SIGNAL = enum SIGABRT,SIGFPE,SIGILL,SIGINT,SIGSEGV,SIGTERM

type Sighandler = proc (a: cint) {.noconv, cdecl.}
# at the moment no proper signal handling is implemented
proc newlibSignal( sigNum : cint , hdlr : Sighandler ) : cint {.exportc:"_signal",codegenDecl: "$# __attribute__((used)) $#$#",cdecl.} =
  # discard
  ## mandatory signals
  ## SIGABRT
  ##  Abnormal termination of a program; raised by the <<abort>> function.
  ## SIGFPE
  ##  A domain error in arithmetic, such as overflow, or division by zero.
  ## SIGILL
  ##  Attempt to execute as a function data that is not executable.
  ## SIGINT
  ## Interrupt; an interactive attention signal.
  ## SIGSEGV
  ## An attempt to access a memory location that is not available.
  ## SIGTERM    
  ## A request that your program end execution.
  # should return the previous handler
  # hal_uart0_strout $sigNum
  # registers a signal-handler for specified signum
  #hal_uart_0_echo_sync(t,t.len)  
  #hal_uart_0_echo_sync(signo,signo.len)    
  return cast[cint](hdlr) 


# newlib wrapped function hooks
#void *malloc(size_t nbytes);
#void *realloc(void *aptr, size_t nbytes);
#void *reallocf(void *aptr, size_t nbytes);
#void free(void *aptr); 

proc real_malloc(nbytes : sizeT) : pointer {.importc:"__real_malloc", cdecl.} # defined by the linker
proc real_free(aptr : pointer) {.importc:"__real_free", cdecl.} # defined by the linker
proc real_realloc(aptr : pointer, nbytes : sizeT) : pointer {.importc:"__real_realloc", cdecl.} # defined by the linker

# todo: track malloc_ptr with map to calculate freed memory for processes
proc malloc_nim(nbytes : sizeT) : pointer {.exportc:"__wrap_malloc", cdecl.} =
  newlib_bytesMalloc = newlib_bytesMalloc + cast[uint32](nbytes)
  inc newlib_malloccounter
  # todo: check isSysContext to track mem
  return real_malloc(nbytes)

proc free_nim(aptr : pointer)  {.exportc:"__wrap_free", cdecl.} =
  inc newlib_freecounter
  # TODO: check isSysContext to track mem
  real_free(aptr)

proc realloc_nim(aptr : pointer, nbytes : sizeT) : pointer {.exportc:"__wrap_realloc", cdecl.} =
  newlib_bytesRealloc = newlib_bytesRealloc + cast[uint32](nbytes)
  # TODO: check isSysContext to track mem


  return real_realloc(aptr,nbytes)


