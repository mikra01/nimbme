@/*
@ * This file is part of nimbme (Nim bare-metal environment)
@ * Copyright (c) 2025 Michael Krauter <michakr@atomicmail.io>
@ *
@ * This program is free software: you can redistribute it and/or modify
@ * it under the terms of the GNU General Public License as published by
@ * the Free Software Foundation, version 3.
@ *
@ * This program is distributed in the hope that it will be useful,
@ * but WITHOUT ANY WARRANTY; without even the implied warranty of
@ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
@ * GNU General Public License for more details.
@ *
@ * You should have received a copy of the GNU General Public License
@ * along with this program. If not, see <https://www.gnu.org/licenses/>.
@ */
@
@ armv6 mem-loader prolog
.section "blc","ax" 
.text
.code 32
.extern NimMain

_start:
 mov r2,#0 
 mcr p15, 0, r2, c7, c5, #4 
 sub sp, pc, #16
 BL NimMain
_hlt:
 b _hlt 