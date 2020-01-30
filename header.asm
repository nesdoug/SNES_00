;header for SNES

.segment "SNESHEADER"
;$00FFC0-$00FFFF

.byte "ABCDEFGHIJKLMNOPQRSTU" ;rom name 21 chars
.byte $30  ;LoROM FastROM
.byte $00  ; extra chips in cartridge, 00: no extra RAM; 02: RAM with battery
.byte $08  ; ROM size (08-0C typical)
.byte $00  ; backup RAM size (01,03,05 typical; Dezaemon has 07)
.byte $01  ;US
.byte $33  ; publisher id, 'just use 00'
.byte $00  ; ROM revision number
.word $0000  ; checksum of all bytes
.word $0000  ; $FFFF minus checksum

;7fe0 not used
.word $0000
.word $0000

;7fe4 - native mode vectors
.addr IRQ_end  ;cop native **
.addr IRQ_end  ;brk native **
.addr $0000  ;abort native not used *
.addr NMI ;nmi native 
.addr RESET ;RESET native
.addr IRQ ;irq native


;7ff0 not used
.word $0000
.word $0000

;7ff4 - emulation mode vectors
.addr IRQ_end  ;cop emulation **
.addr $0000 ; not used
.addr $0000  ;abort not used *
.addr IRQ_end ;nmi emulation
.addr RESET ;RESET emulation
.addr IRQ_end ;irq/brk emulation **

;* the SNES doesn't use the ABORT vector
;**the programmer could insert COP or BRK as debugging tools
;The SNES boots up in emulation mode, but then immediately
;  will be set in software to native mode
;IRQ_end is just an RTI
;the vectors here needs to be in bank 0 (mirror bank 80)
;The SNES never looks at the checksum. Some emulators
;will give a warning message, if the checksum is wrong, 
;but it shouldn't matter. It will still run.