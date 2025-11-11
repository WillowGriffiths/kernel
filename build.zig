const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const entry = b.addObject(.{
        .name = "entry",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/entry.zig"),
            .target = target,
            .code_model = .medany,
        }),
    });

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .code_model = .medany,
        }),
    });
    exe.root_module.addObject(entry);
    exe.setLinkerScript(b.path("linker.ld"));

    b.installArtifact(exe);

    const run_command = b.addSystemCommand(&.{ "qemu-system-riscv64", "-s", "-machine", "virt", "-bios", "fw_dynamic.bin", "-serial", "stdio", "-kernel" });
    run_command.addArtifactArg(exe);

    if (b.args) |args| {
        run_command.addArgs(args);
    }

    const debug_command = b.addSystemCommand(&.{ "gdb", "-ex", "target rem :1234" });
    debug_command.addArtifactArg(exe);

    if (b.args) |args| {
        debug_command.addArgs(args);
    }

    const run_step = b.step("run", "Run the kernel in a VM");
    run_step.dependOn(&run_command.step);
    run_step.dependOn(b.getInstallStep());

    const debug_step = b.step("debug", "Attach to the running kernel to debug it");
    debug_step.dependOn(&debug_command.step);
}
