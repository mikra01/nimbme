# nimbme
Nim bare-metal environment for embedded targets. headless mode

Actual implemented target: raspberry pi1 / pi zero (bcm2835)

General target requirements:
- at least 4KiB ram
- at least 20KiB flash
- 1 UART for terminal
- 1 hardware timer
- [cycle counter]

### features
- cooperative scheduler (actual simple round-robin implemented / deadline-scheduler planned)
- code runs under system-mode (armv6)
- async programming model (requirement: do not block the event loop)
- easy portable / most of the stuff is in nim - only a 'few' lines of asm

### project rationale
- bare-metal playground and research
- no vendor specific API's - just Nim
- having fun

### Dependencies
- [GNU-ARM](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- a terminal for uploading files (yat, realterm or something else)
- usb to serial adapter [3.3V only!!!] (ftdi, CH340..)

### Remarks
- tested with Nim compiler devel / GNU-ARM toolchain 13.3Rel1 with windows11 host 
- older toolchains will work but not 14.2Rel1 which is actually not investigated
- current baudrate is fixed to 3000000 - changeable in envconfig.nim [config_uartBaudRate] 

### Installation (raspberry pi1 or pi zero 1)
- checkout project and compile the demo with "nim build_rp1 project.nims" 
- copy kernel.img to raspberrys sd-card (consecutive builds are uploadable via terminal (Motorola SRecord format used))
- wire gpio14 (TxD0) to adapter's rx-line
- wire gpio15 (RxD0) to adapter's tx-line
- wire ground (I always use pin39) to adapter ground
- power target on
- follow the instructions on terminal :-)

### next steps
- more targets (Cortex-M0 planned)
- in memory-app mode for flash targets with ram > 48kiB (compile and run your prototype in ram without flashing)
- better GPIO handling (RP1)
- generic driver layer
- get ethernet running / usb gadget mode for raspberry pi zero
- spi and i2c examples
- ...



