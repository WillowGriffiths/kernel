ENTRY(_start)

SECTIONS
{
    . = 0x81000000;

    . = ALIGN(4K);
    __boot_start = .;

    .boot : {
        *entry.o

        . = ALIGN(16);
        . += 4K;
        __boot_stack_start = .;

        . = ALIGN(4K);
        __boot_page_tables = .;
        . += 4K * 10;
    }

    __boot_end = .;
    . = 0xffffffff80000000;
    __kernel_start = . - DIFF;
    __virtual_start = .;

    DIFF = . - __boot_end;

    .text : AT(. - DIFF) {
        *(.text*) 
    }

    .rodata : AT(. - DIFF) {
        . = ALIGN(8);
        *(.rodata*)
        . = ALIGN(8);
    }
    .data : AT(. - DIFF) { 
        . = ALIGN(8);
        *(.data*)
        . = ALIGN(8);
    } 
    .bss : AT(. - DIFF) {
        . = ALIGN(8);
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    }

    .kstack : AT(. - DIFF) {
        . = ALIGN(16);
        . += 4K * 8;
        __stack_start = .;
    }

    __kernel_end = . - DIFF;

    /DISCARD/ : { *(.comment .note .eh_frame) }
}
