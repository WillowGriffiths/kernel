fn sbiDebugConsoleWrite(text: []const u8) void {
    _ = asm volatile ("ecall"
        : [ret] "={a0}" (-> usize),
        : [len] "{a0}" (text.len),
          [addr_lo] "{a1}" (text.ptr),
          [addr_hi] "{a2}" (0),
          [fid] "{a6}" (0),
          [edid] "{a7}" (0x4442434E),
    );
}

export fn entry() void {}

fn main() void {
    sbiDebugConsoleWrite("Hello world!\n");
}
