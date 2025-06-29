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

import ospaths, strutils

# TODO: too much params
proc compileAndLink(cpuArch: string ,board :  string, buildVers : string, linkscript : string, crt0 : string , 
    asmFlags : string, compilerFlags : string, boardAndArchTune : string, modname : string, outname : string, outdir : string, optLibPassL : string) = 
  exec "arm-none-eabi-as --keep-locals " & asmFlags & crt0 & " -o " & outdir & "/startup.o" 
  writeFile(outdir & "/startup.sym",staticExec("arm-none-eabi-nm -n " & outdir & "/startup.o"))
  echo "using linkerscript: " & linkscript                 
  # mfloat-abi=hard does not compile
  let outnamedir = outdir & "/" & outname & ".elf" 
  let passl = "--passL:-o" & outnamedir & " --passL:-L" & outdir & optLibPassL & " --passL:-Wl,-Map," & outnamedir & ".map,--cref --passL:-T" & linkscript
  exec "nim c  " & passl & compilerFlags & boardAndArchTune & " -d:release --define:cpuArch=" & cpuArch & " --define:board=" & board & " --define:buildVers=" & buildVers & " --listCmd --hint:cc --hint:link  --nimcache:" & outdir & "/nimcache src/" & modname
  writeFile(outdir & "/section_hdr.txt",staticExec("arm-none-eabi-readelf -S " & outnamedir))
  exec "arm-none-eabi-objcopy -O binary -S " & outdir & "/" & outname & ".elf" & " " & outdir & "/" & outname & ".bin"
  writeFile(outdir & "/" & outname & ".sym",staticExec("arm-none-eabi-nm -n " & outnamedir))
  writeFile(outdir & "/" & outname & ".lss",staticExec("arm-none-eabi-objdump -h -S -C " & outnamedir)) 


template constrLinkerScript(board : string) : string =
  "src/core/hal/board/" & board & "/" & board & ".ld" 

template constrLinkerScriptTools(board : string) : string =
  "src/core/hal/board/" & board & "/tools/" & board & ".ld" 

template constrCrt0(board : string, cpuArch : string) : string =
  "src/core/hal/cpu/" & cpuArch & "/crt0.S" 

template constrCrt0Tools(board : string) : string =
  "src/core/hal/board/" & board & "/tools/crt0.S"   

# also usable for the pi zero (BCM2835)
task build_rp1, " compile and link with arm-none-eabi-gcc toolchain ":
  let board  = "raspberry_pi1"
  let cpuArch = "armv6/b32/"
  let buildVers  = "v0.01" # 
  let outdir = "out_" & board
  mkdir(outdir)

  var linkscript  = constrLinkerScript(board)
  var linkscripttools = constrLinkerScriptTools(board)
  var crt0  = constrCrt0(board,cpuArch)
  let asmFlags = " -march=armv6zk "
  let compilerFlags = " --cpu:arm --passC:-mfpu=vfp --passC:-mfloat-abi=soft --passC:-marm --passC:-mno-unaligned-access  --passC:-mcpu=arm1176jzf-s " 
  let boardAndArchTune = " --os:any --mm:arc -d:useMalloc -d:posix  -d:noSignalHandler --passC:-Iout_raspberry_pi1/ "
  let boardAndArchTuneLdrApp = " --os:standalone --mm:none -d:useMalloc -d:noSignalHandler "
  let outname = "kernel"
  let prec = " --passL:-Lout_raspberry_pi1 --passL:-o" & outdir & "/" & "loader.elf " &  compilerFlags & boardAndArchTuneLdrApp & " -d:release -d:danger --define:board=" & board & " --define:buildVers=" & buildVers &  " --passL:-T" & linkscripttools & " --listCmd --hint:cc --nimcache:" & outdir & "/nimc src/" & 
    "core/hal/board/raspberry_pi1/tools/srecldr.nim"

  # compile loader entry
  exec "arm-none-eabi-as --keep-locals " & asmFlags & constrCrt0Tools(board) & " -o " & outdir & "/ldr.o" 
  # compile loader app
  exec "nim c " & prec
  # create loader.bin which is included in the environment-build
  exec "arm-none-eabi-objcopy -O binary -S " & outdir & "/" & "loader.elf" & " " & outdir & "/" & "loader.bin"
  # create loader syms for debugging
  writeFile(outdir & "/loader.sym",staticExec("arm-none-eabi-nm -n " & outdir & "/loader.elf"))
  
  let sourcefilename = "demo.nim" # change this for your needs

  compileAndLink(cpuArch,board,buildVers,linkscript,crt0,asmFlags,compilerFlags,boardAndArchTune,sourcefilename,outname, outdir,"")
  exec "arm-none-eabi-objcopy -O srec -S  --srec-forceS3 " & outdir & "/" & outname & ".elf" & " " & outdir & "/" & outname & ".srec" 
  if fileExists(outdir & "/" & "kernel.img"):
    rmFile(outdir & "/" & "kernel.img")
  mvFile(outdir & "/" & "kernel.bin",outdir & "/" & "kernel.img")  
 