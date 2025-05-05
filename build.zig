const std = @import("std");
const ldc2 = @import("abs").ldc2;
const zcc = @import("abs").zcc;
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
        .artifact = true,
    });
    const dub_artifact = b.option(bool, "dub-artifact", "enable dub artifact") orelse false;

    if (dub_artifact) {
        // get libsokol
        b.installArtifact(sokol.artifact("sokol"));
    } else {
        var dflags = std.ArrayList([]const u8).init(b.allocator);
        defer dflags.deinit();

        // local includedir
        try dflags.append("-Isource");
        // sokol-package includedir
        try dflags.append(b.fmt("-I{s}", .{sokol.path("src").getPath(b)}));

        if (optimize == .Debug) {
            try dflags.append("--d-version=DbgSkipIntro");
            try dflags.append("--d-version=DbgSkipPrelude");
            try dflags.append("--d-version=DbgEscape");
            try dflags.append("--d-version=DbgMarkers");
            try dflags.append("--d-version=DbgGodMode");
        }

        // common flags
        try dflags.append("-w");
        try dflags.appendSlice(&.{
            "-preview=dip1008",
            "-preview=dip1000",
            "-preview=dip1021",
            "-preview=in",
            "-preview=rvaluerefparam",
        });

        try buildD(b, .{
            .name = "pacman-d",
            .target = target,
            .optimize = optimize,
            .betterC = true, // disable D runtimeGC
            .artifact = sokol.artifact("sokol"),
            .sources = &.{"source/app.d"},
            .dflags = dflags.items,
            .use_zigcc = true,
        });
    }
}
fn buildD(b: *std.Build, options: ldc2.DCompileStep) !void {
    const exe = try ldc2.BuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}
