const std = @import("std");

const Rgba8 = @import("../color.zig").Rgba8;
const state = @import("../state.zig");

pub const Texture = struct {
    pub const opener: u8 = 0xE0;

    pub const Kind = enum(u8) {
        pc,
        ps2,

        pub fn get_bpp(self: Kind) usize {
            return switch (self) {
                .pc => 4,
                .ps2 => 1,
            };
        }
    };

    /// Width of the texture.
    width: u32,
    /// Height of the texture.
    height: u32,

    data: union(Kind) {
        pc: struct {
            /// Pixel data. Encoded as BGRA with 8 bits per channel (therefore
            /// 4 bytes per pixel). Pixels are ordered left to right, top to
            /// bottom.
            pixels: []u8,
        },
        ps2: struct {
            /// Pixel data. Each pixel is represented by one byte specifying an
            /// index of the color inside `palette`. The pixels are swizzled
            /// with PSMT8.
            pixels: []u8,
            /// Color palette for indexed images. Colors are encoded as RGBA8,
            /// with maximum alpha value being 127.
            palette: []Rgba8,
        },
    },

    pub fn deinit(self: *Texture, alloc: std.mem.Allocator) void {
        switch (self.data) {
            .pc => |data| {
                alloc.free(data.pixels);
            },
            .ps2 => |data| {
                alloc.free(data.pixels);
                alloc.free(data.palette);
            },
        }
    }

    /// For internal use only.
    pub fn read_internal(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) !Texture {
        if (try reader.takeInt(u8, .little) != 1) {
            try state.push_error(s, reader, alloc, "Expected u8(1)", .{});
        }

        // Empirical disambiguation value
        const v = try reader.peekInt(u32, .little);

        return switch (v) {
            // TODO: Documents with zero in this position might be valid
            //       documents, but need further investigation.
            0 => return error.InvalidDocument,
            1 => parse_ps2(reader, alloc, s),
            else => parse_pc(reader, alloc, s),
        };
    }

    fn parse_pc(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) !Texture {
        // TODO: need to further research the behaviour of these fields.
        const viewbox_width = try reader.takeInt(u32, .little);
        const viewbox_height = try reader.takeInt(u32, .little);

        if (try reader.takeInt(u32, .little) != 0) {
            try state.push_error(s, reader, alloc, "Expected u32(0)", .{});
        }

        if (try reader.takeInt(u8, .little) != 1) {
            try state.push_error(s, reader, alloc, "Expected u8(1)", .{});
        }

        const width = try reader.takeInt(u32, .little);
        if (viewbox_width != width) {
            try state.push_error(
                s,
                reader,
                alloc,
                "Unmatched width. Expected: {}, found: {}",
                .{ viewbox_width, width },
            );
        }
        const stride = try reader.takeInt(u32, .little);
        if (stride != width *% 4) {
            try state.push_error(s, reader, alloc, "Stride is not equal to width * 4", .{});
        }
        const height = try reader.takeInt(u32, .little);
        if (viewbox_height != height) {
            try state.push_error(
                s,
                reader,
                alloc,
                "Unmatched height. Expected: {}, found: {}",
                .{ viewbox_height, height },
            );
        }

        const result = @mulWithOverflow(stride, height);
        if (result[1] != 0) return error.TextureTooBig;
        const pixel_data = try reader.readAlloc(alloc, result[0]);

        return Texture{
            .width = width,
            .height = height,
            .data = .{ .pc = .{ .pixels = pixel_data } },
        };
    }

    fn parse_ps2(
        reader: *std.Io.Reader,
        alloc: std.mem.Allocator,
        s: *state.ReadState,
    ) !Texture {
        if (try reader.takeInt(u32, .little) != 1) {
            try state.push_error(s, reader, alloc, "Expected u32(1)", .{});
        }

        const width = try reader.takeInt(u32, .little);
        const height = try reader.takeInt(u32, .little);

        // TODO: unknown fields
        try reader.discardAll(3);

        // NOTE: There are textures (particularly, embedded inside other files),
        //       that have very small palettes with this value still being 256.
        //       Yet, the palette in other textures may be less than 256 colors and
        //       be padded with zero bytes.
        const num_colors = try reader.takeInt(u32, .little);

        if (try reader.takeInt(u8, .little) != 0) {
            try state.push_error(s, reader, alloc, "Expected u8(0)", .{});
        }

        const palette = try alloc.alloc(Rgba8, num_colors);
        errdefer alloc.free(palette);
        try reader.readSliceAll(std.mem.sliceAsBytes(palette));

        if (try reader.takeInt(u32, .little) != 3) {
            try state.push_error(s, reader, alloc, "Expected u32(3)", .{});
        }
        // RESEARCH: These seem to be always twice smaller than a dimension of the texture
        if (try reader.takeInt(u32, .little) != width / 2) {
            try state.push_error(s, reader, alloc, "Expected half of width", .{});
        }
        if (try reader.takeInt(u32, .little) != height / 2) {
            try state.push_error(s, reader, alloc, "Expected half of height", .{});
        }

        const indexes = try reader.takeInt(u32, .little);
        if (indexes != width *% height) {
            try state.push_error(
                s,
                reader,
                alloc,
                "Number of indexes != width * height",
                .{},
            );
        }
        const pixel_data = try reader.readAlloc(alloc, indexes);

        return Texture{
            .width = width,
            .height = height,
            .data = .{ .ps2 = .{
                .pixels = pixel_data,
                .palette = palette,
            } },
        };
    }

    /// Validates the data before saving.
    pub fn validate(self: Texture) bool {
        switch (self.data) {
            .ps2 => |data| {
                if (data.palette.len > 256) return false;
            },
        }
        const bpp = self.data.get_bpp();
        return self.pixel_data.len == self.width *% self.height *% bpp;
    }

    /// Gets the size of the section in bytes (excluding the opener byte).
    pub fn size(self: Texture) u32 {
        return 1 + switch (self.data) {
            .pc => |data| 25 + @as(u32, @intCast(data.pixels.len)),
            .ps2 => |data| 1060 + @as(u32, @intCast(data.pixels.len)),
        };
    }

    /// For internal use only.
    pub fn write_internal(self: Texture, writer: *std.Io.Writer) !void {
        try writer.writeByte(1);
        return switch (self.data) {
            .pc => self.write_pc(writer),
            .ps2 => self.write_ps2(writer),
        };
    }

    fn write_pc(self: Texture, writer: *std.Io.Writer) !void {
        try writer.writeInt(u32, self.width, .little);
        try writer.writeInt(u32, self.height, .little);
        try writer.writeInt(u32, 0, .little);
        try writer.writeByte(1);
        try writer.writeInt(u32, self.width, .little);
        try writer.writeInt(u32, self.width *% 4, .little);
        try writer.writeInt(u32, self.height, .little);
        try writer.writeAll(self.data.pc.pixels);
    }

    fn write_ps2(self: Texture, writer: *std.Io.Writer) !void {
        try writer.writeInt(u32, 1, .little);
        try writer.writeInt(u32, self.width, .little);
        try writer.writeInt(u32, self.height, .little);
        // NOTE: Not sure what this is yet. Transferred from bloom.stx.
        try writer.writeAll(&[_]u8{ 0x32, 0x46, 0x04 });
        try writer.writeInt(u32, 256, .little);
        try writer.writeByte(0);

        try writer.writeAll(std.mem.sliceAsBytes(self.data.ps2.palette));
        const pad = (256 - self.data.ps2.palette.len) * 4;
        for (0..pad) |_| {
            try writer.writeByte(0);
        }

        try writer.writeInt(u32, 3, .little);
        try writer.writeInt(u32, self.width / 2, .little);
        try writer.writeInt(u32, self.height / 2, .little);
        try writer.writeInt(u32, @intCast(self.data.ps2.pixels.len), .little);

        try writer.writeAll(self.data.ps2.pixels);
    }
};
