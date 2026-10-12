<h1 align="center">✨ Splendente 🔌</h1>

Tools and libraries for working with assets from Sparkplug engine games (e.g.
*Winx Club* (2006) for Windows and PlayStation® 2).

Currently, includes a [library `stx`](#stx) for working with Sparkplug textures.

## Usage

The library can be used either as a Zig module or as a static library in
languages such as C. Headers are provided as `<splendente/stx.h>`, etc.

### Through Zig build system

```zig
const splendente = b.dependency("splendente", .{
  .target = target,
  .optimize = optimize,
});

// Import as a Zig module
module.addImport("stx", splendente.module("stx"));

// For linking with other languages.
module.linkLibrary(splendente.artifact("splendente-stx"));
```

### Linking manually

When using other build tools, you need to prepare a *prefix* where library
files would reside. You need to have Zig (0.16+) installed and run the following
command:

```shell
zig build
```

(You may specify additional parameters such as optimization level, refer to `zig
build --help` for details.)

A directory named `zig-out` will be created, and it will contain common folders
such as `lib` and `include`. Then, given the path to the `zig-out` folder is
`${SPLENDENTE_PREFIX}`, the following C compiler arguments would need to be
used. On Windows, you may need to also link against `ntdll`.

```
-I${SPLENDENTE_PREFIX}/include -L${SPLENDENTE_PREFIX}/lib -lsplendente-stx
```

## Libraries

### stx

🖼️ A library for parsing Sparkplug textures (standalone .stx files, textures
embedded inside models and fonts).

Not all textures are correctly handled for now, but majority of them (especially
the ones from the PC version) would be.

> [!NOTE]
> Interpretation of pixel data is left to the user application (see
> [STX GIMP plug-in][stx-gimp-plugin], for example). Beware that PS2 textures
> are swizzled with PSMT8, so an unswizzling algorithm would be
> required.

The library includes optional validation for conformance against currently
researched structure. To use it, call `collect_errors` on `ReadState` before
reading.

```zig
const std = @import("std");
const stx = @import("stx");

var state: stx.ReadState = .{};
// Create a buffer for at most 32 errors
try state.collect_errors(32, alloc);
defer state.deinit(alloc);
const maybe_doc = stx.Document.read(reader, alloc, &state);
for (state.get_errors()) |err| {
  std.debug.print("0x{x:04}: {s}\n", .{ err.pos, err.message });
}
if (maybe_doc) |doc| {
  const tx = doc.surface.texture;
  // `data` is a union with branches for PC and PS2
  draw_texture(tx.data, tx.width, tx.height);
} else |err| {
  std.debug.print("Error: {}", .{ err });
}
```

## Programs using Splendente

[![GIMP plugin for working with STX files](https://raw.githubusercontent.com/kotwys/stx-gimp-plugin/master/assets/banner.jpg)][stx-gimp-plugin]

## Acknowledgements

I would like to thank AnDi~SD for his [extensive documentation on the Sparkplug
engine][sparkplug-research] and D:\Games\Winx, a Russian community of *Winx
Club* video games, for valuable input on different stages of development.

[stx-gimp-plugin]: https://github.com/kotwys/stx-gimp-plugin
[sparkplug-research]: https://github.com/AnDi-SD/SparkplugEngineResearch
