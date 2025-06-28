# nimbme
Nim bare-metal environment for embedded targets. headless mode

Actual implemented target: raspberry pi1 / pi zero (bcm2835)

General target requirements:
- at least 4KiB ram
- at least 20KiB flash
- 1 UART for terminal
- 1 hardware timer
- [cycle counter]
- software interrupt mechanism

### features
- cooperative scheduler (actual simple round-robin scheme / deadline-scheduler planned)
- code runs under system-mode (armv6)
- async programming model (requirement: do not block the event loop)
- easy portable / most of the stuff is in nim - only a 'few' lines of asm

### project rationale
- bare-metal playground and research
- no vendor specific API's - just Nim and direct hardware access
- having fun

### Dependencies
- [GNU-ARM](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- a terminal for uploading files (CoolTerm, yat(supports 3000000baud) , realterm or something else)
- usb to serial adapter [!!! 3.3Vmax on the line !!!] (ftdi, CH340..)

### Remarks
- tested with Nim compiler devel / GNU-ARM toolchain 13.3Rel1 with windows11 host 
- older toolchains are also fine but not 14.2Rel1 (actually not investigated)
- current baudrate is set to 3000000 / highest one for 250mHz core clock - changeable in envconfig.nim [config_uartBaudRate] 

### Installation (raspberry pi1 or pi zero 1)
- checkout project and compile the demo with "nim build_rp1 project.nims" 
- configure host terminal (EOL is linefeed)
- copy kernel.img to raspberry´s sd-card (consecutive builds are uploadable via terminal (Motorola SRecord format used))
- wire gpio14 (TxD0) to adapter's rx-line
- wire gpio15 (RxD0) to adapter's tx-line
- Rx/Tx wires should be short as possible (10cm jumper wired will work) / the ftdi runs fine with 3000000baud (other vendors not tested)
- wire ground (I always use pin39) to adapter ground
![connect tx/rx uart lines](../assets/pi_zero_wiring.png)
- power target on
- follow the instructions on terminal :-)

### whats implemented so far..
- stdio is retargeted to UART
- the demo spawns up to 10 'processes' (at the moment no posix api)
- the complete runtime in cycles (per process) is collected (irq cycles are also collected but at the moment not related to the actual active process)
- total ram is limited to 64kiB / shared-heap around 24kiB but you can change that in the main linker file subdir 'hal/_boardname_/_boardname_.ld'
- process stacksize is 1kiB (adjustable in envconfig.nim)
- race conditions are trapped and the cause is printed out to UART (same for uncaught exceptions)
- you can do snapshots of the entire register set (cpsr/spsr not implemented)
- in memory image uploadable (the loader is invoked if a race condition occurs or the demo is finished)
- the ARM is configured to prevent unaligned access

### remark on the build size and experiments
the build size is heavily influenced by libraries and functions you are using. For instance printf and friends occupies whooping >20kiB program space.
I faced some runtime problems (spurious exceptions) with newlib-nano so it is not used. The default newlib build delivered with the toolchain has reent-support and that stuff needs also much program-space.
If you experiment keep in mind that the stack needs to be 8byte aligned in most cases. When you face race conditions this could be the culprit (or your stack is corrupted due to overflows). Experimenting with SBC´s is great because your hardware is not brickable. 
Unfortunately the provided bcm2835 datasheet is everything but not a datasheet (seriously). If you look at the PI4/PI5 nothing changed. There are other vendors with superior documentation if you like to start with that topic. I simply choosed this target because I recently found one onto my desk ( I remembered Linux was awful slow on this target (10yrs ago) )... and now there is something better :-) --- and yes I was not aware how 'detailed' the BCM-datasheet is.

#### overclocking (use at your own risk)
I did some overclocking experiments (core-clock 500mHz / arm-clock 1gHz) and I found no issues if you do not utilize the VC. This setup is working fine and the chip temp levels out at around 40 degrees celsius (around 50 degrees celsius for the pi zero). I refer to some community efforts to find the correct settings in config.txt and/or consult [config.txt properties](https://www.raspberrypi.com/documentation/computers/config_txt.html)

#### debugging techniques
thanks to Nim you literally do not need a jtag debugger (this project was completely done without one). If you like to invest some money go for a scope and utilize gpio for tackling rt problems.
If you like to monitor specific code parts use intro and outro public procs with exported symbols (to find the codepart of interest) and consult the .lss output. Join state information (print out register- and/or memory snapshots) if needed. For latency measurements take snapshots of the 64bit free running counter (clocked at 1mHz fixed - see 'systemtimer.nim' within hal/ subdir ). Unfortunately the free running arm counter option is not implemented (bcm2835) and the prescaler only works with 256 so there is now way to get a better resolution than around 512ns (500mHz core clock divided by 256). Fine granuled measurement is only possible with the arm cycle counter (roundabout 4 seconds max. without prescaler) 

### next steps
- alloc fixed size memblocks (stackspace) while compiletime and not runtime (done)
- GPIO handling helper (RP1)
- more targets (Cortex-M0 / Sitara AM3358 / risc-v /.. planned)
- in memory-app mode for flash targets with ram > 32kiB (compile and run your prototype in ram without flashing)
- generic driver layer
- get ethernet running / usb gadget mode for raspberry pi zero
- sdcard I/O
- signal handling
- spi and i2c examples
- ...

### credits
David Welch´s experiments years ago saved me some time in figuring out 'bcm2835-details' in cases the datasheet lacks some information or was simply wrong (no official erratasheet out there...). If you like to look into the datasheet consult this before: [bcm2835 errata](https://elinux.org/BCM2835_datasheet_errata)