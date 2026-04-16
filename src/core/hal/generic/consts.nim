const hal_consts_SVC_UART_0_TX* {.exportc.}: int8 = 0x0A
const hal_consts_EnterMemLdr* {.exportc.}: int8 = 0x01
const hal_consts_DumpAllRegs* {.exportc.}: int8 = 0x02


# DFSR fault status codes
# todo: move 2 cpuConsts
const dfsr_aligmentFault : byte =  0x01 #Alignment Fault	bit A set
const dfsr_debugEventMonitor : byte =  0x03 #Debug Event	
const dfsr_translationFault_Section : byte = 0x05 #Translation Fault (Section)	vaddr acc without mapping
const dfsr_translationFault_Page : byte =  0x07 #Translation Fault (Page)	same
const dfsr_permissionFault_Section : byte = 0x0D #Permission Fault (Section) # example AP[2:0] with PTE
const dfsr_permissionFault_Page  : byte =  0x0F #Permission Fault (Page)
const dfsr_domainFault_Section : byte =  0x09 #Domain Fault (Section)	
const dfsr_domainFault_Page : byte =  0x0B #Domain Fault (Page)	dito
const dfsr_externalAbort_nonCacheable : byte =  0x19 #External Abort (non-cacheable)	bus fault
const dfsr_externalAbort_onTranslation : byte =  0x15 #External Abort on Translation	
const dfsr_impreciseExternalAbort : byte =  0x00 #Imprecise External Abort	