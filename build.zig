const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const stx = b.addModule("stx", .{
        .root_source_file = b.path("stx/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const libstx = b.addLibrary(.{
        .name = "splendente-stx",
        .root_module = b.createModule(.{
            .root_source_file = b.path("stx/src/c-api.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    libstx.installHeadersDirectory(b.path("stx/include"), "splendente", .{});
    b.installArtifact(libstx);

    const stx_read = b.addExecutable(.{
        .name = "stx-read",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/stx-read.zig"),
            .target = target,
        }),
    });
    stx_read.root_module.addImport("stx", stx);
    b.installArtifact(stx_read);
}
