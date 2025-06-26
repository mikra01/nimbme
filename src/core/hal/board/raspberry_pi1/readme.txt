# howto detect board:
# https://wiki.osdev.org/Detecting_Raspberry_Pi_Board

# this layer targets BCM2835 
# single-core Armv6 (https://developer.arm.com/documentation/ddi0301/latest/) ARM1176JZF-S - with 256/512MB of RAM 
# todo: implement dynamic mmiobase to extend this layer for the pi2