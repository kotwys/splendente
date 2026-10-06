const color = @import("color.zig");
pub const Rgba8 = color.Rgba8;

pub const Error = @import("error.zig").Error;

const state = @import("state.zig");
pub const ReadState = state.ReadState;
pub const ValidationError = state.ValidationError;

pub const Document = @import("document.zig").Document;
pub const Metadata = @import("sections/metadata.zig").Metadata;
pub const Surface = @import("sections/surface.zig").Surface;
pub const Texture = @import("sections/texture.zig").Texture;
