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
        try dflags.append("--preview=all");

        try buildD(b, .{
            .name = "pacman-d",
            .target = target,
            .optimize = optimize,
            .betterC = true, // disable D runtimeGC
            .artifact = sokol.artifact("sokol"),
            .sources = &.{"source/app.d"},
            .dflags = dflags.items,
        });
    }
}
fn buildD(b: *std.Build, options: abs.DCompileStep) !void {
    const exe = try abs.ldcBuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}
