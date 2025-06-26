const hal_consts_SVC_UART_0_TX* {.exportc.}: int8 = 0x0A
const hal_consts_EnterMemLdr* {.exportc.}: int8 = 0x01
const hal_consts_DumpAllRegs* {.exportc.}: int8 = 0x02


# DFSR fault status codes
# todo: move 2 cpuConsts
const dfsr_aligmentFault : byte =  0x01 #Alignment Fault	Zugriff auf unaligned Adresse bei gesetztem Bit A
const dfsr_debugEventMonitor : byte =  0x03 #Debug Event	Debug Monitor (nicht typischerweise ausgelöst)
const dfsr_translationFault_Section : byte = 0x05 #Translation Fault (Section)	Zugriff auf virtuelle Adresse ohne Mapping
const dfsr_translationFault_Page : byte =  0x07 #Translation Fault (Page)	wie oben, bei kleinerem Page-TLB
const dfsr_permissionFault_Section : byte = 0x0D #Permission Fault (Section)	Zugriff verboten (z. B. per AP[2:0] im PTE)
const dfsr_permissionFault_Page  : byte =  0x0F #Permission Fault (Page)	wie oben
const dfsr_domainFault_Section : byte =  0x09 #Domain Fault (Section)	Domänenrechte verletzt
const dfsr_domainFault_Page : byte =  0x0B #Domain Fault (Page)	dito
const dfsr_externalAbort_nonCacheable : byte =  0x19 #External Abort (non-cacheable)	Fehler vom Bus (z. B. Gerät reagiert nicht)
const dfsr_externalAbort_onTranslation : byte =  0x15 #External Abort on Translation	Abbruch während Tabellen-Translation
const dfsr_impreciseExternalAbort : byte =  0x00 #Imprecise External Abort	Nur bei späterem, nicht direkt zuordenbarem Fehl