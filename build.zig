const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = optimize, .code_model = .medany }),
    });
    exe.setLinkerScript(b.path("linker.ld"));
    exe.root_module.addAssemblyFile(b.path("./src/entry.s"));

    const run_command = b.addSystemCommand(&.{ "qemu-system-riscv64", "-s", "-machine", "virt", "-bios", "fw_dynamic.bin", "-serial", "stdio", "-kernel" });
    run_command.addArtifactArg(exe);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the kernel in a VM");
    run_step.dependOn(&run_command.step);
}
