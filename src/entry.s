.section .text.boot

.global _start
.type _start, @function
_start:
    la sp, __stack_start
    call zmain
1:  wfi
    j 1b
