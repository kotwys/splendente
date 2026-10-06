const std = @import("std");

const state = @import("../state.zig");

pub const Metadata = struct {
    pub const opener: u8 = 0xE6;

    version: u32,

    // This struct does not need manual deinitialization, but it is provided
    // as part of a common interface.
    pub fn deinit(self: *Metadata, alloc: std.mem.Allocator) void {
        _ = self;
        _ = alloc;
    }

    /// For internal use only.
    pub fn read_internal(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) !Metadata {
        _ = alloc;
        _ = s;
        const version = try reader.takeInt(u32, .little);
        return Metadata{ .version = version };
    }

    /// Validates the data before saving.
    pub fn validate(self: Metadata) bool {
        _ = self;
        return true;
    }

    /// Gets the size of the section in bytes (excluding the opener byte).
    pub fn size(self: Metadata) u32 {
        _ = self;
        return 4;
    }

    /// For internal use only.
    pub fn write_internal(self: Metadata, writer: *std.Io.Writer) !void {
        try writer.writeInt(u32, self.version, .little);
    }
};
