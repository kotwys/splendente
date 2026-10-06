const std = @import("std");

pub const Error = error{
    WrongHeader,
    OpenerMismatch,
    TextureTooBig,
    NoSurface,
    InvalidDocument,
} || std.Io.Reader.Error || std.Io.Writer.Error || std.mem.Allocator.Error;
