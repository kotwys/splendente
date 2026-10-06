const std = @import("std");

const StxError = @import("../error.zig").Error;
const state = @import("../state.zig");

pub const SECTION_START_SIZE = 5; // opener + size

pub inline fn read_section(
    comptime T: type,
    reader: *std.Io.Reader,
    alloc: std.mem.Allocator,
    s: *state.ReadState,
) StxError!T {
    const actual_opener = try reader.takeInt(u8, .little);
    if (actual_opener != T.opener) {
        try state.push_error(
            s,
            reader,
            alloc,
            "Unexpected section opener. Expected: 0x{x:02}, got: 0x{x:02}",
            .{ T.opener, actual_opener },
        );
        return StxError.OpenerMismatch;
    }

    // Skip section size since it is known
    try reader.discardAll(4);

    return T.read_internal(reader, alloc, s);
}

pub inline fn write_section(
    section: anytype,
    writer: *std.Io.Writer,
) !void {
    try writer.writeByte(@TypeOf(section).opener);
    try writer.writeInt(u32, section.size(), .little);
    try section.write_internal(writer);
}
