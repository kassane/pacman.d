const std = @import("std");
const abs = @import("abs");
const sokol_build = @import("sokol");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    // ldc2/ldmd2 not have mingw-support
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows)
            try std.Target.Query.parse(.{
                .arch_os_abi = "native-windows-msvc",
            })
        else
            .{},
    });
    const optimize = b.standardOptimizeOption(.{});
    const sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    // get libsokol
    b.installArtifact(sokol.artifact("sokol"));

    try buildD(b, .{
        .name = "pacman-d",
        .target = target,
        .optimize = optimize,
        .betterC = true, // disable D runtimeGC
        .artifact = sokol.artifact("sokol"),
        .sources = &.{"source/app.d"},
        .dflags = &.{
            "-w",
            "-Isource",
        },
    });
}
fn buildD(b: *std.Build, options: abs.DCompileStep) !void {
    const exe = try abs.ldcBuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}