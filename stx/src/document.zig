const std = @import("std");

const StxError = @import("error.zig").Error;
const state = @import("state.zig");

const common = @import("sections/common.zig");
const Metadata = @import("sections/metadata.zig").Metadata;
const Surface = @import("sections/surface.zig").Surface;

pub const Document = struct {
    const STX_MAGIC = "\x22\x00\x00";

    metadata: ?Metadata,
    surface: Surface,

    pub fn deinit(self: *Document, alloc: std.mem.Allocator) void {
        self.surface.deinit(alloc);
    }

    pub fn read(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) StxError!Document {
        const magic = try reader.take(3);
        if (!std.mem.eql(u8, magic, STX_MAGIC)) {
            try state.push_error(s, reader, alloc, "Magic does not match: 0x{x}", .{magic});
            return StxError.WrongHeader;
        }

        var metadata: ?Metadata = null;
        var surface: ?Surface = null;
        errdefer {
            if (surface) |*inner| inner.*.deinit(alloc);
        }

        while (true) {
            const opener = reader.peekInt(u8, .little) catch break;
            switch (opener) {
                0 => {
                    reader.toss(1);
                    break;
                },
                Metadata.opener => {
                    metadata = try common.read_section(Metadata, reader, alloc, s);
                    s.version = metadata.?.version;
                    if (s.version != 6 and s.version != 8) {
                        try state.push_error(s, reader, alloc, "Unknown STX version: {x}", .{s.version});
                    }
                },
                Surface.opener => {
                    surface = try common.read_section(Surface, reader, alloc, s);
                },
                else => {
                    try state.push_error(s, reader, alloc, "Unknown section", .{});
                    try reader.discardAll(1);
                    const size = try reader.takeInt(u32, .little);
                    try reader.discardAll(size);
                },
            }
        }

        return Document{
            .metadata = metadata,
            .surface = surface orelse return StxError.NoSurface,
        };
    }

    /// Validates the document before writing out.
    pub fn validate(self: Document) bool {
        return self.surface.validate();
    }

    /// Gets the estimate size of the document in bytes.
    pub fn estimate_size(self: Document) usize {
        var size: usize = STX_MAGIC.len;
        if (self.metadata) |m|
            size += common.SECTION_START_SIZE + m.size();
        size += common.SECTION_START_SIZE + self.surface.size();
        size += 1;
        return size;
    }

    pub fn write(self: Document, writer: *std.Io.Writer) !void {
        try writer.writeAll(STX_MAGIC);
        if (self.metadata) |m| {
            try common.write_section(m, writer);
        }
        try common.write_section(self.surface, writer);
        try writer.writeByte(0);
    }
};
