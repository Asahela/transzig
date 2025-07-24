const std = @import("std");

pub fn build(b: *std.Build) void {
    const module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .optimize = .ReleaseSafe,
        .target = b.graph.host,
    });

    const exe = b.addExecutable(.{
        .name = "transzig",
        .root_module = module,
    });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
