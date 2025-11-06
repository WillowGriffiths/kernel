const root = @import("root");

export fn _start() linksection(".text.boot") callconv(.naked) void {
    asm volatile (
        \\    la sp, __stack_start
        \\    call entry
        \\1:  wfi
        \\    j 1b
    );
}

export fn entry() linksection(".text.boot") void {
    root.main();
}
