// raylib-zig (c) Nikolas Wipper 2020-2024

const std = @import("std");
const rl = @This();

pub const emcc = @import("emcc.zig");

pub const Options = struct {
    raudio: bool = true,
    rmodels: bool = true,
    rshapes: bool = true,
    rtext: bool = true,
    rtextures: bool = true,
    platform_drm: bool = false,
    linux_display_backend: LinuxDisplayBackend = .X11,
    opengl_version: OpenglVersion = .auto,
};

pub const OpenglVersion = enum {
    auto,
    gl_1_1,
    gl_2_1,
    gl_3_3,
    gl_4_3,
    gles_2,
    gles_3,
};

pub const LinuxDisplayBackend = enum {
    X11,
    Wayland,
};

const Program = struct {
    name: []const u8,
    path: []const u8,
    desc: []const u8,
};

fn link(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Mode,
    options: Options
) void {
    const lib = getRaylib(b, target, optimize, options);

    const target_os = exe.rootModuleTarget().os.tag;
    switch (target_os) {
        .windows => {
            exe.linkSystemLibrary("winmm");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");
        },
        .macos => {
            exe.linkFramework("OpenGL");
            exe.linkFramework("Cocoa");
            exe.linkFramework("IOKit");
            exe.linkFramework("CoreAudio");
            exe.linkFramework("CoreVideo");
        },
        .freebsd, .openbsd, .netbsd, .dragonfly => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("rt");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xrandr");
            exe.linkSystemLibrary("Xinerama");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xxf86vm");
            exe.linkSystemLibrary("Xcursor");
        },
        .emscripten, .wasi => {
            // When using emscripten, the libries don't need to be linked
            // because emscripten is going to do that later.
        },
        else => { // Linux and possibly others.
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("rt");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("m");
            exe.linkSystemLibrary("X11");
        },
    }

    exe.linkLibrary(lib);
}

var _raylib_lib_cache: ?*std.Build.Step.Compile = null;
fn getRaylib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode, options: Options) *std.Build.Step.Compile {
    if (_raylib_lib_cache) |lib| return lib else {
        const raylib = b.dependency("raylib", .{
            .target = target,
            .optimize = optimize,
            .raudio = options.raudio,
            .rmodels = options.rmodels,
            .rshapes = options.rshapes,
            .rtext = options.rtext,
            .rtextures = options.rtextures,
            .platform_drm = options.platform_drm,
            .shared = false,
            .linux_display_backend = options.linux_display_backend,
        });

        const lib = raylib.artifact("raylib");
        b.installArtifact(lib);
        _raylib_lib_cache = lib;
        return lib;
    }
}

fn getModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Module {
    if (b.modules.contains("raylib")) {
        return b.modules.get("raylib").?;
    }
    return b.addModule("raylib", .{
        .root_source_file = b.path("lib/raylib.zig"),
        .target = target,
        .optimize = optimize,
    });
}

const math = struct {
    fn getModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Module {
        const raylib = rl.getModule(b, target, optimize);
        return b.addModule("raylib-math", .{
            .root_source_file = b.path("lib/raymath.zig"),
            .imports = &.{.{ .name = "raylib-zig", .module = raylib }},
            .target = target,
            .optimize = optimize,
        });
    }
};

const gl = struct {
    fn getModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Module {
        const raylib = rl.getModule(b, target, optimize);
        return b.addModule("rlgl", .{
            .root_source_file = b.path("lib/rlgl.zig"),
            .imports = &.{.{ .name = "raylib-zig", .module = raylib }},
            .target = target,
            .optimize = optimize,
        });
    }
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const defaults = Options{};
    const options = Options{
        .platform_drm = b.option(bool, "platform_drm", "Compile raylib in native mode (no X11)") orelse defaults.platform_drm,
        .raudio = b.option(bool, "raudio", "Compile with audio support") orelse defaults.raudio,
        .rmodels = b.option(bool, "rmodels", "Compile with models support") orelse defaults.rmodels,
        .rtext = b.option(bool, "rtext", "Compile with text support") orelse defaults.rtext,
        .rtextures = b.option(bool, "rtextures", "Compile with textures support") orelse defaults.rtextures,
        .rshapes = b.option(bool, "rshapes", "Compile with shapes support") orelse defaults.rshapes,
        .linux_display_backend = b.option(LinuxDisplayBackend, "linux_display_backend", "Linux display backend to use") orelse defaults.linux_display_backend,
        .opengl_version = b.option(OpenglVersion, "opengl_version", "OpenGL version to use") orelse defaults.opengl_version,
    };

    const examples = [_]Program{
        .{
            .name = "basic_screen_manager",
            .path = "examples/core/basic_screen_manager.zig",
            .desc = "Illustrates simple screen manager based on a state machine",
        },
        .{
            .name = "basic_window",
            .path = "examples/core/basic_window.zig",
            .desc = "Creates a basic window with text",
        },
        .{
            .name = "input_keys",
            .path = "examples/core/input_keys.zig",
            .desc = "Simple keyboard input",
        },
        .{
            .name = "input_mouse",
            .path = "examples/core/input_mouse.zig",
            .desc = "Simple mouse input",
        },
        .{
            .name = "input_mouse_wheel",
            .path = "examples/core/input_mouse_wheel.zig",
            .desc = "Mouse wheel input",
        },
        .{
            .name = "input_multitouch",
            .path = "examples/core/input_multitouch.zig",
            .desc = "Multitouch input",
        },
        .{
            .name = "2d_camera",
            .path = "examples/core/2d_camera.zig",
            .desc = "Shows the functionality of a 2D camera",
        },
        .{
            .name = "3d_camera_first_person",
            .path = "examples/core/3d_camera_first_person.zig",
            .desc = "Simple first person demo",
        },
        .{
            .name = "window_flags",
            .path = "examples/core/window_flags.zig",
            .desc = "Demonstrates various flags used during and after window creation",
        },
        .{
            .name = "texture_outline",
            .path = "examples/shaders/texture_outline.zig",
            .desc = "Uses a shader to create an outline around a sprite",
        },
        .{
            .name = "logo_raylib",
            .path = "examples/shapes/logo_raylib.zig",
            .desc = "Renders the raylib-zig logo",
        },
        .{
            .name = "sprite_anim",
            .path = "examples/textures/sprite_anim.zig",
            .desc = "Animate a sprite",
        },
        .{
            .name = "textures_background_scrolling",
            .path = "examples/textures/textures_background_scrolling.zig",
            .desc = "Background scrolling & parallax demo",
        },
        // .{
        //     .name = "models_loading",
        //     .path = "examples/models/models_loading.zig",
        //     .desc = "Loads a model and renders it",
        // },
        // .{
        //     .name = "shaders_basic_lighting",
        //     .path = "examples/shaders/shaders_basic_lighting.zig",
        //     .desc = "Loads a model and renders it",
        // },
    };

    const raylib = rl.getModule(b, target, optimize);
    const raylib_math = rl.math.getModule(b, target, optimize);
    const rlgl = rl.gl.getModule(b, target, optimize);

    const raylib_test = b.addTest(.{
        .root_source_file = b.path("lib/raylib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_math_test = b.addTest(.{
        .root_source_file = b.path("lib/raymath.zig"),
        .target = target,
        .optimize = optimize,
    });
    raylib_math_test.root_module.addImport("raylib-zig", raylib);

    const rlgl_test = b.addTest(.{
        .root_source_file = b.path("lib/rlgl.zig"),
        .target = target,
        .optimize = optimize,
    });
    rlgl_test.root_module.addImport("raylib-zig", raylib);

    const test_step = b.step("test", "Check for library compilation errors");
    test_step.dependOn(&raylib_test.step);
    test_step.dependOn(&raylib_math_test.step);
    test_step.dependOn(&rlgl_test.step);

    const examples_step = b.step("examples", "Builds all the examples");

    for (examples) |ex| {
        if (target.query.os_tag == .emscripten) {
            const exe_lib = emcc.compileForEmscripten(b, ex.name, ex.path, target, optimize);
            exe_lib.root_module.addImport("raylib", raylib);
            exe_lib.root_module.addImport("raylib-math", raylib_math);
            exe_lib.root_module.addImport("rlgl", rlgl);
            const raylib_lib = getRaylib(b, target, optimize, options);

            // Note that raylib itself isn't actually added to the exe_lib
            // output file, so it also needs to be linked with emscripten.
            exe_lib.linkLibrary(raylib_lib);
            const link_step = try emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_lib });
            link_step.addArg("--embed-file");
            link_step.addArg("resources/");

            const run_step = try emcc.emscriptenRunStep(b);
            run_step.step.dependOn(&link_step.step);
            const run_option = b.step(ex.name, ex.desc);

            run_option.dependOn(&run_step.step);
            examples_step.dependOn(&exe_lib.step);
        } else {
            const exe = b.addExecutable(.{
                .name = ex.name,
                .root_source_file = b.path(ex.path),
                .optimize = optimize,
                .target = target,
            });
            rl.link(b, exe, target, optimize, options);
            exe.root_module.addImport("raylib", raylib);
            exe.root_module.addImport("raylib-math", raylib_math);
            exe.root_module.addImport("rlgl", rlgl);

            const run_cmd = b.addRunArtifact(exe);
            const run_step = b.step(ex.name, ex.desc);

            run_step.dependOn(&run_cmd.step);
            examples_step.dependOn(&exe.step);
        }
    }
}
