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

const hexChars : array[16,char] = ['0','1','2','3','4','5','6','7','8','9'
                                   ,'A','B','C','D','E','F']

  
template strutil_hex2CharB*(par : uint8, res : var array[3,byte]) =
  res[0] = hexChars[par shr 4 ].byte                               
  res[1] = hexChars[par and 0x0F].byte  
  res[2] = 0.byte

template strutil_hex2CharW*(par : uint16, res : var array[5,byte]) =
  res[0] = hexChars[ (par shr 12) and 0x0F.uint16 ].byte                                       
  res[1] = hexChars[ (par shr 8) and 0x0F.uint16 ].byte     
  res[2] = hexChars[ (par shr 4) and 0x0F.uint16 ].byte                                       
  res[3] = hexChars[par and 0x0F.uint16 ].byte  
  res[4] = 0.byte

template strutil_hex2CharL*(par : uint32, res : var array[9,char]) =
  res[0] = hexChars[par shr 28 and 0x0F]    # process hs nibble                                   
  res[1] = hexChars[par shr 24 and 0x0F] 
  res[2] = hexChars[par shr 20 and 0x0F]                                       
  res[3] = hexChars[par shr 16 and 0x0F ]  
  res[4] = hexChars[par shr 12 and 0x0F ]                                      
  res[5] = hexChars[par shr 8 and 0x0F]  
  res[6] = hexChars[par shr 4 and 0x0F ]                                       
  res[7] = hexChars[par and 0x0F]  # process ls nibble
  res[8] = 0.char

template strutil_hex2CharL(par : uint32, res : var cstring) =
  res[0] = hexChars[par shr 28 and 0x0F]    # process hs nibble                                   
  res[1] = hexChars[par shr 24 and 0x0F] 
  res[2] = hexChars[par shr 20 and 0x0F]                                       
  res[3] = hexChars[par shr 16 and 0x0F ]  
  res[4] = hexChars[par shr 12 and 0x0F ]                                      
  res[5] = hexChars[par shr 8 and 0x0F]  
  res[6] = hexChars[par shr 4 and 0x0F ]                                       
  res[7] = hexChars[par and 0x0F]  # process ls nibble
  res[8] = 0.char

proc num2Hex*(n : uint32): cstring {.inline.}  =
    var v : cstring = "        "
    strutil_hex2CharL(n,v)
    return v

