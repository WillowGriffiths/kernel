ENTRY(_start)

SECTIONS
{
    . = 0x81000000;

    .text : {
        KEEP(*(.text.boot))
        *(.text.boot) 
        *(.text*) 
    }

    .rodata : {
        . = ALIGN(8);
        *(.rodata*)
        . = ALIGN(8);
    }
    .data : { 
        . = ALIGN(8);
        *(.data*)
        . = ALIGN(8);
    } 
    .bss : {
        . = ALIGN(8);
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    }

    .kstack : {
        . = ALIGN(16);
        . += 4K;
        __stack_start = .;
    }

    /DISCARD/ : { *(.comment .note .eh_frame) }
}
