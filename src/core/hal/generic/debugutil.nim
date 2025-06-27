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
proc debugutil_dumpMem2StdOut*(memstart : ptr uint, numberOfDWords : int) {.inline.}=
    usePtr[uint]:
      var memptr : ptr uint = memstart
      var charbuff : array[9,char]
      for i in 0 .. numberOfDWords - 1:
        strutil_hex2CharL(cast[uint32](memptr+i),charbuff)
        hal_uart_0_strout_blocking addr charbuff ,8
        hal_uart_0_strout_blocking ": ",2
        strutil_hex2CharL(cast[uint32](memptr[i]),charbuff)
        hal_uart_0_strout_blocking addr charbuff ,8
        hal_uart_0_chrout_blocking config_consoleNewlineChar

