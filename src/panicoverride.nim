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

import core/runtime


#proc exit(code: int) {.importc:"_exit", cdecl.}

{.push stack_trace: off, profiler:off.}

proc rawoutput(s: string) =
  hal_uart_0_echo_sync(s,s.len)

proc panic(s: string) =
  hal_uart_0_echo_sync("panic",5)
  hal_uart_0_echo_sync(s,s.len)
  reset_board()
  #exit(1)

{.pop.}