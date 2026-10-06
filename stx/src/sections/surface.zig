const std = @import("std");

const state = @import("../state.zig");
const common = @import("common.zig");
const Texture = @import("texture.zig").Texture;

pub const Surface = struct {
    pub const opener: u8 = 0xE1;

    texture: Texture,

    pub fn deinit(self: *Surface, alloc: std.mem.Allocator) void {
        self.texture.deinit(alloc);
    }

    /// For internal use only.
    pub fn read_internal(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) !Surface {
        const texture = try common.read_section(Texture, reader, alloc, s);
        if (try reader.takeInt(u8, .little) != 0) {
            try state.push_error(s, reader, alloc, "Expected u8(0)", .{});
        }
        return Surface{ .texture = texture };
    }

    /// Validates the data before saving.
    pub fn validate(self: Surface) bool {
        return self.texture.validate();
    }

    /// Gets the size of the section in bytes (excluding the opener byte).
    pub fn size(self: Surface) u32 {
        return common.SECTION_START_SIZE + self.texture.size() + 1;
    }

    /// For internal use only.
    pub fn write_internal(self: Surface, writer: *std.Io.Writer) !void {
        try common.write_section(self.texture, writer);
        try writer.writeByte(0);
    }
};
