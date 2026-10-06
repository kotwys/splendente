const std = @import("std");

const Rgba8 = @import("color.zig").Rgba8;
const StxError = @import("error.zig").Error;
const ReadState = @import("state.zig").ReadState;
const ValidationError = @import("state.zig").ValidationError;
const Document = @import("document.zig").Document;
const Texture = @import("sections/texture.zig").Texture;

const alloc = std.heap.c_allocator;

pub export fn stx_error_string(errno: u16) [*:0]const u8 {
    const e = @errorFromInt(errno);
    return switch (e) {
        StxError.EndOfStream => "End of stream",
        StxError.NoSurface => "No surface (E1)",
        StxError.OpenerMismatch => "Incorrect section opener",
        StxError.OutOfMemory => "Out of memory",
        StxError.ReadFailed => "Read failed",
        StxError.TextureTooBig => "Texture is too big",
        StxError.WrongHeader => "Wrong signature",
        StxError.InvalidDocument => "Invalid document",
        else => "Unknown error",
    };
}

// ===
// ReadState
// ===

pub export fn stx_read_state_init() ?*ReadState {
    const ptr = alloc.create(ReadState) catch return null;
    ptr.* = .{};
    return ptr;
}

pub export fn stx_read_state_collect_errors(
    state: *ReadState,
    capacity: usize,
) bool {
    state.collect_errors(capacity, alloc) catch return false;
    return true;
}

pub export fn stx_read_state_errors(state: *ReadState) ?[*]ValidationError {
    if (state.errors) |errors| {
        return errors.ptr;
    } else return null;
}

pub export fn stx_read_state_error_count(state: *ReadState) usize {
    return state.error_count;
}

pub export fn stx_read_state_free(state: *ReadState) void {
    state.deinit(alloc);
    alloc.destroy(state);
}

// ===
// Document
// ===

const StxDocumentInit = extern struct {
    version: u32,

    width: u32,
    height: u32,

    kind: c_int,

    pixels: [*c]u8,
    palette: [*c]Rgba8,
    color_count: u16,
};

pub export fn stx_document_create(init: *const StxDocumentInit) ?*Document {
    const kind: Texture.Kind = @enumFromInt(init.kind);
    if (init.pixels == null) {
        return null;
    }
    if (kind == .ps2 and init.palette == null) {
        return null;
    }
    if (init.color_count < 1 and init.color_count > 256) {
        return null;
    }

    const bpp = kind.get_bpp();
    const pixels_length = init.width *% init.height *% bpp;
    const pixels = init.pixels[0..pixels_length];

    const ptr = alloc.create(Document) catch return null;
    ptr.* = .{
        .metadata = if (init.version != 0)
            .{ .version = init.version }
        else
            null,
        .surface = .{
            .texture = .{
                .width = init.width,
                .height = init.height,
                .data = switch (kind) {
                    .pc => .{ .pc = .{ .pixels = pixels } },
                    .ps2 => .{ .ps2 = .{
                        .pixels = pixels,
                        .palette = init.palette[0..init.color_count],
                    } },
                },
            },
        },
    };
    return ptr;
}

pub export fn stx_document_free(ptr: ?*Document) void {
    if (ptr) |self| {
        self.deinit(alloc);
        alloc.destroy(self);
    }
}

pub export fn stx_document_get_version(doc: *const Document) u32 {
    if (doc.metadata) |m| {
        return m.version;
    } else return 0;
}

fn stx_document_read_internal(
    reader: *std.Io.Reader,
    state: *ReadState,
) StxError!*Document {
    const mem = try alloc.create(Document);
    errdefer alloc.destroy(mem);
    mem.* = try Document.read(reader, alloc, state);
    return mem;
}

pub export fn stx_document_read(
    buf: [*]const u8,
    length: usize,
    state: *ReadState,
    err: *u16,
) ?*Document {
    const slice = buf[0..length];
    var reader = std.Io.Reader.fixed(slice);
    if (stx_document_read_internal(&reader, state)) |res| {
        return res;
    } else |e| {
        err.* = @intFromError(e);
        return null;
    }
}

pub export fn stx_document_estimate_size(doc: *Document) usize {
    return doc.estimate_size();
}

pub export fn stx_document_write_buffer(
    doc: *Document,
    buf: [*c]u8,
    capacity: usize,
    length: [*c]usize,
) bool {
    var writer = std.Io.Writer.fixed(buf[0..capacity]);
    if (doc.write(&writer)) |_| {
        length.* = writer.end;
        return true;
    } else |_| {
        return false;
    }
}

pub export fn stx_document_get_texture(doc: *Document) *Texture {
    return &doc.surface.texture;
}

// ===
// Texture
// ===

pub export fn stx_texture_kind(tx: *Texture) c_int {
    return @intFromEnum(tx.data);
}

pub export fn stx_texture_get_data(
    tx: *Texture,
    ptr_width: *usize,
    ptr_height: *usize,
) [*]u8 {
    ptr_width.* = tx.width;
    ptr_height.* = tx.height;
    return switch (tx.data) {
        .pc => |data| data.pixels.ptr,
        .ps2 => |data| data.pixels.ptr,
    };
}

pub export fn stx_texture_get_palette(
    tx: *Texture,
    ptr_color_count: ?*usize,
) ?[*]u32 {
    return switch (tx.data) {
        .pc => null,
        .ps2 => |data| {
            if (ptr_color_count) |ptr| ptr.* = data.palette.len;
            return @ptrCast(data.palette.ptr);
        },
    };
}
