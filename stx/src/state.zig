const std = @import("std");

pub const ValidationError = extern struct {
    /// Position in the file where the error ocurred.
    pos: usize,
    /// Message.
    message: [*:0]const u8,
};

pub const ReadState = struct {
    version: u32 = 0,
    errors: ?[]ValidationError = null,
    error_count: usize = 0,

    /// Initializes an error buffer that will be used for collecting validation
    /// errors during parsing. No more than `capacity` errors will be
    /// collected.
    ///
    /// If you called this function, you would need to also `deinit` the state.
    pub fn collect_errors(
        self: *ReadState,
        capacity: usize,
        alloc: std.mem.Allocator,
    ) !void {
        self.*.errors = try alloc.alloc(ValidationError, capacity);
        self.*.error_count = 0;
    }

    pub fn get_errors(self: ReadState) []ValidationError {
        if (self.errors) |errors| {
            return errors[0..self.error_count];
        } else return &.{};
    }

    pub fn deinit(self: ReadState, alloc: std.mem.Allocator) void {
        if (self.errors) |errors| {
            for (errors[0..self.error_count]) |err| {
                alloc.free(std.mem.span(err.message));
            }
            alloc.free(errors);
        }
    }
};

pub fn push_error(
    s: *ReadState,
    reader: *std.Io.Reader,
    alloc: std.mem.Allocator,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    if (s.errors) |errors| {
        if (errors.len >= s.error_count)
            return;

        const message = try std.fmt.allocPrintSentinel(alloc, fmt, args, 0);
        errors[s.error_count] = ValidationError{
            .pos = reader.seek,
            .message = message,
        };
        s.error_count += 1;
    }
}
