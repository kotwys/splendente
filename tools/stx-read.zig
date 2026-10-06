const std = @import("std");
const stx = @import("stx");

fn to_ppm(tx: stx.Texture, writer: *std.Io.Writer) !void {
    try writer.print("P6\n{d} {d}\n255\n", .{ tx.width, tx.height });

    var i: usize = 0;
    const bpp: usize, const buffer, const palette = switch (tx.data) {
        .pc => |data| .{ 4, data.pixels, null },
        .ps2 => |data| .{ 1, data.pixels, data.palette },
    };
    while (i < buffer.len) {
        var c: stx.Rgba8 = undefined;
        if (palette) |p| {
            c = p[buffer[i]];
        } else {
            c = stx.Rgba8{
                .b = buffer[i],
                .g = buffer[i + 1],
                .r = buffer[i + 2],
                .a = 0,
            };
        }
        try writer.writeAll(&[3]u8{ c.r, c.g, c.b });
        i += bpp;
    }
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 2) {
        std.debug.print("Not enough args", .{});
        return error.NotEnoughArgs;
    }

    var buffer: [1024]u8 = undefined;

    const file = try std.Io.Dir.cwd().openFile(init.io, args[1], .{});
    defer file.close(init.io);
    var reader_impl = file.reader(init.io, &buffer);
    const reader = &reader_impl.interface;

    var state: stx.ReadState = .{};
    try state.collect_errors(32, alloc);
    const maybe_doc = stx.Document.read(reader, alloc, &state);
    for (state.get_errors()) |err| {
        std.debug.print("ERROR@0x{x:04}: {s}\n", .{ err.pos, err.message });
    }
    state.deinit(alloc);
    const doc = try maybe_doc;
    std.debug.print("STX Document", .{});
    if (doc.metadata) |meta| {
        std.debug.print(" (version {x:02})", .{meta.version});
    }
    std.debug.print(":\n", .{});
    std.debug.print("  Texture:\n", .{});
    const tx = doc.surface.texture;
    std.debug.print(
        "    Kind: {s}\n",
        .{switch (tx.data) {
            .pc => "PC (BGRA8)",
            .ps2 => "PS2 (Indexed)",
        }},
    );
    std.debug.print("    Dimensions: {d}x{d}\n", .{ tx.width, tx.height });

    var writer_impl = std.Io.File.stdout().writer(init.io, &buffer);
    const writer = &writer_impl.interface;
    try to_ppm(tx, writer);
    try writer_impl.flush();
}
